import Foundation
import Testing
@testable import ElvisKit

@Suite struct ClaudeHooksTests {
    private func event(_ json: String) -> WorkEvent? {
        ClaudeHooks.event(fromPayload: Data(json.utf8))
    }

    @Test func lifecycleEventsMapAcross() {
        #expect(event(#"{"hook_event_name":"SessionStart","session_id":"s","source":"startup"}"#) == WorkEvent(.sessionStarted, session: "s"))
        #expect(event(#"{"hook_event_name":"UserPromptSubmit","session_id":"s","prompt":"secret plans"}"#) == WorkEvent(.taskStarted, session: "s"))
        #expect(event(#"{"hook_event_name":"Stop","session_id":"s"}"#) == WorkEvent(.taskFinished, session: "s"))
        #expect(event(#"{"hook_event_name":"StopFailure","session_id":"s","error":"rate_limit"}"#) == WorkEvent(.taskStumbled, session: "s"))
        #expect(event(#"{"hook_event_name":"SessionEnd","session_id":"s","reason":"other"}"#) == WorkEvent(.sessionEnded, session: "s"))
        #expect(event(#"{"hook_event_name":"PreCompact","session_id":"s"}"#) == nil)
        #expect(event("not json") == nil)
    }

    @Test func toolsCarryAFlavourAndNothingPrivate() throws {
        let started = try #require(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"Edit","tool_input":{"file_path":"/secret/path.swift","old_string":"a","new_string":"b"}}"#))
        #expect(started.kind == .toolStarted)
        #expect(started.flavour == .edit)
        let wire = String(decoding: started.encodedLine(), as: UTF8.self)
        #expect(!wire.contains("secret"))
        let fields = try #require(JSONSerialization.jsonObject(with: started.encodedLine()) as? [String: Any])
        #expect(Set(fields.keys) == ["kind", "session", "flavour", "subject"])
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"Grep","tool_input":{}}"#)?.flavour == .read)
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"ls"}}"#)?.flavour == .shell)
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"WebSearch","tool_input":{}}"#)?.flavour == .web)
    }

    @Test func permissionRequestsPairWithTheirToolCall() throws {
        let request = try #require(event(#"{"hook_event_name":"PermissionRequest","session_id":"s","tool_name":"Bash","tool_input":{"command":"rm x","description":"d"}}"#))
        let finished = try #require(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"description":"d","command":"rm x"},"tool_response":{"stdout":"","stderr":""}}"#))
        let other = try #require(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{"stdout":""}}"#))
        #expect(request.kind == .needsYou)
        #expect(request.subject != nil)
        #expect(request.subject == finished.subject)
        #expect(request.subject != other.subject)
    }

    @Test func waitingNotificationsAndQuestionsNeedYou() {
        #expect(event(#"{"hook_event_name":"Notification","session_id":"s","notification_type":"permission_prompt","message":"m"}"#)?.kind == .needsYou)
        #expect(event(#"{"hook_event_name":"Notification","session_id":"s","notification_type":"idle_prompt","message":"m"}"#)?.kind == .sessionIdle)
        #expect(event(#"{"hook_event_name":"Notification","session_id":"s","notification_type":"auth_success","message":"m"}"#) == nil)
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"AskUserQuestion","tool_input":{}}"#)?.kind == .needsYou)
        #expect(event(#"{"hook_event_name":"ElicitationResult","session_id":"s"}"#)?.kind == .youAnswered)
    }

    @Test func testRunsBecomeVerdicts() {
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{"stdout":"ok","stderr":"","interrupted":false}}"#)?.kind == .testsPassed)
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"Exit code 1\n1 failing"}"#)?.kind == .testsFailed)
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test | tail -5"},"tool_response":{"stdout":"Tests: 2 failed, 1 passed","stderr":""}}"#)?.kind == .testsFailed)
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{"stdout":""}}"#)?.kind == .toolFinished)
    }

    @Test func onlyAFreshOrResumedSessionCountsAsStarting() {
        #expect(event(#"{"hook_event_name":"SessionStart","session_id":"s","source":"resume"}"#)?.kind == .sessionStarted)
        #expect(event(#"{"hook_event_name":"SessionStart","session_id":"s","source":"compact"}"#) == nil)
        #expect(event(#"{"hook_event_name":"SessionStart","session_id":"s","source":"clear"}"#) == nil)
    }

    @Test func subagentToolCallsAreMarked() {
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","agent_id":"a1","tool_name":"Read","tool_input":{}}"#)?.agent == "a1")
        #expect(event(#"{"hook_event_name":"PreToolUse","session_id":"s","tool_name":"Read","tool_input":{}}"#)?.agent == nil)
    }

    @Test func aRunCutShortIsNotAPass() {
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{"stdout":"","stderr":"","interrupted":true}}"#)?.kind == .toolFinished)
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{"stdout":"","backgroundTaskId":"b1"}}"#)?.kind == .toolFinished)
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"Exit code 127\nnpm: command not found"}"#)?.kind == .toolFinished)
    }

    @Test func aTestRunThatNeverRanSaysNothingAboutTheTests() {
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"The user doesn't want to proceed"}"#)?.kind == .toolFinished)
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"Exit code 130","is_interrupt":true}"#)?.kind == .toolFinished)
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s","tool_name":"Bash","tool_input":{"command":"npm test","run_in_background":true},"tool_response":{"stdout":""}}"#)?.kind == .toolFinished)
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"cd missing && npm test"},"error":"Exit code 1\n(eval):cd:1: no such file or directory: missing"}"#)?.kind == .toolFinished)
    }

    @Test func failingTestsAreStillReportedAfterAChangeOfDirectory() {
        #expect(event(#"{"hook_event_name":"PostToolUseFailure","session_id":"s","tool_name":"Bash","tool_input":{"command":"cd app && npm test"},"error":"Exit code 1\nTests: 1 failed, 12 passed, 13 total"}"#)?.kind == .testsFailed)
    }
}
