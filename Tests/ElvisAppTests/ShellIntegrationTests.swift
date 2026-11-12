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

    @Test func aRunHiddenBehindAPipeIsNotReported() throws {
        let listener = try UnixSocket.Listener(at: elvis.socket)
        try elvis.run("ran", "0", "npm test | tail")
        #expect(listener.linesDelivered().isEmpty)
    }

    @Test func tellingHimWhenHeIsNotRunningFailsAndSaysSo() throws {
        let tell = try elvis.run("tell", "tests-passed")
        #expect(tell.status != 0)
        #expect(tell.errors.contains("Elvis isn't running"))
    }
}
