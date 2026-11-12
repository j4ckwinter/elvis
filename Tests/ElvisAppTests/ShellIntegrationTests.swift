import Foundation
import Testing

@Suite struct ShellIntegrationTests {
    private let elvis: IsolatedElvis

    init() throws {
        elvis = try IsolatedElvis()
    }

    @Test func aPassingTestRunIsReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "0", "npm test")
        #expect(try Delivery(only: listener.linesDelivered()).fields == ["kind": "tests-passed", "session": ""])
    }

    @Test func aFailingTestRunIsReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "1", "npm test")
        #expect(try Delivery(only: listener.linesDelivered()).fields == ["kind": "tests-failed", "session": ""])
    }

    @Test func yourOwnCommitAndPushAreReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "0", "git commit -m \"rename the hidden launch plan\"")
        let commit = try Delivery(only: listener.linesDelivered())
        #expect(commit.fields == ["kind": "committed", "session": ""])
        #expect(!commit.wire.contains("hidden"))
        try elvis.run("ran", "0", "git push")
        #expect(try Delivery(only: listener.linesDelivered()).fields == ["kind": "pushed", "session": ""])
    }

    @Test func aCommitThatFailedIsNotReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "1", "git commit -m x")
        #expect(listener.linesDelivered().isEmpty)
    }

    @Test func aRunHiddenBehindAPipeIsNotReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "0", "npm test | tail")
        #expect(listener.linesDelivered().isEmpty)
    }

    @Test func aChainThatFailedBeforeTheRunnerStartedIsNotReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "1", "cd missing && npm test")
        #expect(listener.linesDelivered().isEmpty)
    }

    @Test func aHelperReportedByHandIsOneHeCanCount() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("tell", "helper-started")
        #expect(try Delivery(only: listener.linesDelivered()).fields == ["kind": "helper-started", "session": "by-hand", "agent": "by-hand"])
    }

    @Test func tellingHimWhenHeIsNotRunningFailsAndSaysSo() throws {
        let tell = try elvis.run("tell", "tests-passed")
        #expect(tell.status != 0)
        #expect(tell.errors.contains("Elvis isn't running"))
    }
}
