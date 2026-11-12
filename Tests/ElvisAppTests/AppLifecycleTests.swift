import CoreGraphics
import Foundation
import Testing

@Suite struct AppLifecycleTests {
    private static let sessionStart = #"{"hook_event_name":"SessionStart","session_id":"s-1","source":"startup"}"#
    private let elvis: IsolatedElvis

    init() throws {
        elvis = try IsolatedElvis()
    }

    @Test func listensOnHisSocketOnceStarted() throws {
        try elvis.startApp()
        #expect(eventually { elvis.isListening })
    }

    @Test func opensNoWindowWhenHeadless() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        let everyWindow = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let his = everyWindow.filter { $0[kCGWindowOwnerPID as String] as? Int32 == app.processIdentifier }
        #expect(his.isEmpty)
    }

    @Test func aSecondElvisInTheSameHomeBowsOutAndLeavesTheFirstRunning() throws {
        let first = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        let second = try elvis.run("run")
        #expect(second.status == 0)
        #expect(second.output.contains("Elvis is already here"))
        #expect(first.isRunning)
        #expect(elvis.isListening)
    }

    @Test func quitSendsHimToBedAndClearsHisSocketAway() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        let quit = try elvis.run("quit")
        #expect(quit.status == 0)
        #expect(eventually { !app.isRunning })
        #expect(!FileManager.default.fileExists(atPath: elvis.socket))
    }

    @Test func aSessionStartWakesHimWhenNobodyIsListening() throws {
        let hook = try elvis.run("hook", input: Self.sessionStart, autostart: true)
        #expect(hook.status == 0)
        #expect(hook.wasSilent)
        try #require(eventually { elvis.isListening })
        let app = try #require(elvis.listeningProcess)
        try elvis.run("quit")
        #expect(eventually { kill(app, 0) != 0 })
    }

    @Test func aSessionStartLeavesHimAsleepWhenAutostartIsOff() throws {
        let hook = try elvis.run("hook", input: Self.sessionStart)
        #expect(hook.status == 0)
        #expect(hook.wasSilent)
        #expect(!elvis.isListening)
        #expect(elvis.homeIsEmpty)
    }
}
