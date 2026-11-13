import Foundation
import Testing

@Suite struct StatusTests {
    private static let sessionStart = #"{"hook_event_name":"SessionStart","session_id":"s-1","source":"startup"}"#
    private static let prompt = #"{"hook_event_name":"UserPromptSubmit","session_id":"s-1","prompt":"rename the hidden launch plan"}"#
    private let elvis: IsolatedElvis

    init() throws {
        elvis = try IsolatedElvis()
    }

    @Test func saysHisVersionAndThatHeHasHeardNothingYet() throws {
        try elvis.startApp()
        try #require(eventually { elvis.isListening })
        let status = try elvis.run("status")
        #expect(status.status == 0)
        #expect(status.errors == "")
        #expect(try status.output.hasPrefix("Elvis \(elvis.run("version").output.trimmingCharacters(in: .newlines)): "))
        #expect(status.output.hasSuffix("Has heard nothing from Claude Code since he woke\n"))
    }

    @Test func saysWhatClaudeIsUpToOnceAHookHasToldHim() throws {
        try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.run("hook", input: Self.prompt)
        let status = try elvis.run("status")
        #expect(status.output.contains("\nClaude: 1 session working\n"))
        #expect(status.output.contains("\nLast heard from Claude Code "))
        #expect(!status.output.contains("hidden"))
    }

    @Test func theSessionStartThatSwappedHimReachesTheNewElvis() throws {
        let old = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: "0.0.1 \(old.processIdentifier)")
        try elvis.run("hook", input: Self.sessionStart, autostart: true)
        try #require(eventually { elvis.listeningProcess != nil && elvis.listeningProcess != old.processIdentifier })
        #expect(try elvis.run("status").output.contains("\nLast heard from Claude Code "))
    }

    @Test func saysSoWhenHeIsNotRunning() throws {
        let status = try elvis.run("status")
        #expect(status.status == 2)
        #expect(status.output == "")
        #expect(status.errors.contains("isn't running"))
    }

    @Test func saysSoWhenTheRunningElvisDoesNotAnswer() throws {
        let deafToQuestions = try UnixSocket.Listener(at: elvis.socket)
        let status = try elvis.run("status")
        #expect(status.status == 2)
        #expect(status.output == "")
        #expect(status.errors.contains("did not answer"))
        _ = deafToQuestions
    }
}
