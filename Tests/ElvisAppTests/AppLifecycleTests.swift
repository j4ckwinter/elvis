import CoreGraphics
import Foundation
import Testing

@Suite struct AppLifecycleTests {
    private static let sessionStart = #"{"hook_event_name":"SessionStart","session_id":"s-1","source":"startup"}"#
    private static let prompt = #"{"hook_event_name":"UserPromptSubmit","session_id":"s-1","prompt":"hello"}"#
    private static let pluginManifest = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("plugin/.claude-plugin/plugin.json")
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

    @Test func restartSwapsTheRunningElvisForANewOne() throws {
        let old = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        let restart = try elvis.run("restart")
        #expect(restart.status == 0)
        #expect(eventually { !old.isRunning })
        try #require(eventually { elvis.isListening })
        #expect(elvis.listeningProcess != old.processIdentifier)
    }

    @Test func restartStartsHimWhenHeWasNotRunning() throws {
        #expect(try elvis.run("restart").status == 0)
        #expect(eventually { elvis.isListening })
    }

    @Test func twoStartsAtOnceBothFindHimAwake() throws {
        let oneAtATime = NSLock()
        nonisolated(unsafe) var statuses: [Int32] = []
        DispatchQueue.concurrentPerform(iterations: 2) { _ in
            let status = (try? elvis.run("start").status) ?? -1
            oneAtATime.withLock { statuses.append(status) }
        }
        #expect(statuses == [0, 0])
        #expect(elvis.isListening)
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

    @Test func saysTheVersionThePluginCarries() throws {
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.pluginManifest)) as? [String: Any]
        let carried = try #require(manifest?["version"] as? String)
        let version = try elvis.run("version")
        #expect(version.status == 0)
        #expect(version.output == carried + "\n")
    }

    @Test func putsHisVersionAndProcessOnRecordOnceStarted() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        #expect(try elvis.record == "\(version()) \(app.processIdentifier)")
    }

    @Test func aSessionStartSwapsAnOlderElvisForTheHooksBuild() throws {
        let old = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: "0.0.1 \(old.processIdentifier)")
        try expectASessionStartToSwap(old)
    }

    @Test(arguments: ["", "999.0.0 1", "999.0.0"])
    func anElvisWithNoRecordOfHisOwnCountsAsOlder(leftByAnother: String) throws {
        let old = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: leftByAnother)
        try expectASessionStartToSwap(old)
    }

    @Test func aSessionStartLeavesAnElvisOfTheSameVersionRunning() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try expectAHookToLeaveRunning(app, payload: Self.sessionStart, autostart: true)
    }

    @Test func aSessionStartLeavesANewerElvisRunning() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: "999.0.0 \(app.processIdentifier)")
        try expectAHookToLeaveRunning(app, payload: Self.sessionStart, autostart: true)
    }

    @Test func anOlderElvisIsLeftRunningWhenAutostartIsOff() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: "0.0.1 \(app.processIdentifier)")
        try expectAHookToLeaveRunning(app, payload: Self.sessionStart, autostart: false)
    }

    @Test func onlyASessionStartSwapsAnOlderElvis() throws {
        let app = try elvis.startApp()
        try #require(eventually { elvis.isListening })
        try elvis.leave(record: "0.0.1 \(app.processIdentifier)")
        try expectAHookToLeaveRunning(app, payload: Self.prompt, autostart: true)
    }

    private func version() throws -> String {
        try elvis.run("version").output.trimmingCharacters(in: .newlines)
    }

    private func expectASessionStartToSwap(_ old: Process) throws {
        let hook = try elvis.run("hook", input: Self.sessionStart, autostart: true)
        #expect(hook.status == 0)
        #expect(hook.wasSilent)
        #expect(eventually { !old.isRunning })
        try #require(eventually { elvis.isListening })
        let new = try #require(elvis.listeningProcess)
        #expect(new != old.processIdentifier)
        #expect(try elvis.record == "\(version()) \(new)")
    }

    private func expectAHookToLeaveRunning(_ app: Process, payload: String, autostart: Bool) throws {
        let hook = try elvis.run("hook", input: payload, autostart: autostart)
        #expect(hook.status == 0)
        #expect(hook.wasSilent)
        #expect(app.isRunning)
        #expect(elvis.listeningProcess == app.processIdentifier)
    }
}
