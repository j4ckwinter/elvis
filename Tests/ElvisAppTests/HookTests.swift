import Foundation
import Testing

@Suite struct HookTests {
    private let elvis: IsolatedElvis

    init() throws {
        elvis = try IsolatedElvis()
    }

    private func delivery(of payload: String) throws -> Delivery {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        let hook = try elvis.run("hook", input: payload)
        #expect(hook.status == 0)
        #expect(hook.wasSilent)
        return try Delivery(only: listener.linesDelivered())
    }

    @Test(arguments: [
        #"{"hook_event_name":"UserPromptSubmit","session_id":"s-1","prompt":"hello"}"#,
        "not a hook payload {",
        "",
    ])
    func staysSilentAndSucceedsWithNobodyListening(payload: String) throws {
        let hook = try elvis.run("hook", input: payload)
        #expect(hook.status == 0)
        #expect(hook.output == "")
        #expect(hook.errors == "")
    }

    @Test func aPromptCrossesAsItsKindAndSessionOnly() throws {
        let prompt = try delivery(of: #"{"hook_event_name":"UserPromptSubmit","session_id":"s-1","prompt":"rename the hidden launch plan"}"#)
        #expect(prompt.fields == ["kind": "task-started", "session": "s-1"])
        #expect(!prompt.wire.contains("hidden"))
    }

    @Test func anEditCrossesWithoutItsFilePathOrText() throws {
        let edit = try delivery(of: #"{"hook_event_name":"PreToolUse","session_id":"s-1","tool_name":"Edit","tool_input":{"file_path":"/Users/someone/private/ledger.swift","old_string":"salary","new_string":"bonus"}}"#)
        #expect(Set(edit.fields.keys) == ["kind", "session", "flavour", "subject"])
        #expect(edit.fields["kind"] == "tool-started")
        #expect(edit.fields["session"] == "s-1")
        #expect(edit.fields["flavour"] == "edit")
        #expect(edit.fields["subject"]?.wholeMatch(of: /Edit:[0-9a-f]+/) != nil)
        for secret in ["someone", "private", "ledger", "salary", "bonus"] {
            #expect(!edit.wire.contains(secret))
        }
    }

    @Test func aCommandCrossesWithoutItsText() throws {
        let command = try delivery(of: #"{"hook_event_name":"PreToolUse","session_id":"s-1","tool_name":"Bash","tool_input":{"command":"curl internal.example --header token-12345"}}"#)
        #expect(Set(command.fields.keys) == ["kind", "session", "flavour", "subject"])
        #expect(command.fields["kind"] == "tool-started")
        #expect(command.fields["session"] == "s-1")
        #expect(command.fields["flavour"] == "shell")
        #expect(command.fields["subject"]?.wholeMatch(of: /Bash:[0-9a-f]+/) != nil)
        for secret in ["curl", "internal", "token", "12345"] {
            #expect(!command.wire.contains(secret))
        }
    }
}
