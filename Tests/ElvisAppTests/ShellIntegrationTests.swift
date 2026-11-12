import Foundation
import Testing

@Suite struct ShellIntegrationTests {
    private let elvis: IsolatedElvis

    init() throws {
        elvis = try IsolatedElvis()
    }

    private static let pretendTests = "npm() { [[ $2 != fail ]]; }"

    private func setUp(for shell: String) -> String {
        "eval \"$('\(elvis.binary)' shell-init \(shell))\""
    }

    @Test func zshReportsTheTestRunsYouTypeAndNothingForAnEmptyLine() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.type([setUp(for: "zsh"), Self.pretendTests, "npm test", "", "npm test fail", "cd /tmp && npm test", "ls > /dev/null"], into: "/bin/zsh", "-f", "-i")
        #expect(listener.kindsDeliveredInAnyOrder(expecting: 3) == ["tests-failed", "tests-passed", "tests-passed"])
    }

    @Test func bashReportsTheTestRunsYouTypeAndNothingForAnEmptyLine() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.type([setUp(for: "bash"), Self.pretendTests, "npm test", "", "npm test fail", "cd /tmp && npm test", "ls > /dev/null"], into: "/bin/bash", "--noprofile", "--norc", "-i")
        #expect(listener.kindsDeliveredInAnyOrder(expecting: 3) == ["tests-failed", "tests-passed", "tests-passed"])
    }

    @Test func bashCreditsNothingToACommandItsHistoryDidNotRecord() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        let typed = [setUp(for: "bash"), Self.pretendTests, "HISTCONTROL=ignoreboth", "npm test", "npm test", " npm test fail", " npm", "npm test"]
        try elvis.type(typed, into: "/bin/bash", "--noprofile", "--norc", "-i")
        #expect(listener.kindsDeliveredInAnyOrder(expecting: 3) == ["tests-passed", "tests-passed", "tests-passed"])
    }

    @Test func bashKeepsYourExitStatusAndLastArgumentAsTheyWere() throws {
        let typed = [setUp(for: "bash"), "false", "echo \"status $?\"", "echo one two", "echo \"last $_\""]
        let session = try elvis.type(typed, into: "/bin/bash", "--noprofile", "--norc", "-i")
        #expect(session.output.contains("status 1"))
        #expect(session.output.contains("last two"))
    }

    @Test func bashLeavesAnotherToolsDebugTrapAloneAndSaysSo() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        let typed = ["trap 'true' DEBUG", setUp(for: "bash"), Self.pretendTests, "npm test", "trap -p DEBUG"]
        let session = try elvis.type(typed, into: "/bin/bash", "--noprofile", "--norc", "-i")
        #expect(session.errors.contains("another tool already uses bash's DEBUG trap"))
        #expect(session.output.contains("trap -- 'true' DEBUG"))
        #expect(listener.kindsDeliveredInAnyOrder(expecting: 0).isEmpty)
    }

    @Test func settingBashUpTwiceReportsEachCommandOnce() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.type([setUp(for: "bash"), setUp(for: "bash"), Self.pretendTests, "npm test"], into: "/bin/bash", "--noprofile", "--norc", "-i")
        #expect(listener.kindsDeliveredInAnyOrder(expecting: 1) == ["tests-passed"])
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
