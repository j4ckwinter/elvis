import Foundation

final class IsolatedElvis {
    struct Outcome {
        let status: Int32
        let output: String
        let errors: String

        var wasSilent: Bool { output.isEmpty && errors.isEmpty }
    }

    struct StillRunning: Error {
        let arguments: [String]
    }

    let home: String
    private var appsStarted: [Process] = []

    init() throws {
        home = NSTemporaryDirectory() + "elv." + UUID().uuidString.prefix(8)
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: false)
    }

    deinit {
        for app in appsStarted where app.isRunning {
            app.terminate()
            app.waitUntilExit()
        }
        if let wokenByAHook = listeningProcess, wokenByAHook != getpid() {
            kill(wokenByAHook, SIGTERM)
            if !eventually(within: 2, { kill(wokenByAHook, 0) != 0 }) { kill(wokenByAHook, SIGKILL) }
        }
        try? FileManager.default.removeItem(atPath: home)
    }

    var socket: String { home + "/elvis.sock" }
    var isListening: Bool { UnixSocket.isAccepting(at: socket) }
    var listeningProcess: pid_t? { UnixSocket.processListening(at: socket) }
    var record: String { (try? String(contentsOfFile: home + "/elvis.lock", encoding: .utf8)) ?? "" }
    var homeIsEmpty: Bool { (try? FileManager.default.contentsOfDirectory(atPath: home))?.isEmpty == true }

    @discardableResult
    func run(_ arguments: String..., input: String = "", autostart: Bool = false) throws -> Outcome {
        let command = command(arguments, autostart: autostart)
        let typed = Pipe(), output = Pipe(), errors = Pipe()
        try typed.fileHandleForWriting.write(contentsOf: Data(input.utf8))
        try typed.fileHandleForWriting.close()
        command.standardInput = typed
        command.standardOutput = output
        command.standardError = errors
        try command.run()
        guard eventually({ !command.isRunning }) else {
            command.terminate()
            command.waitUntilExit()
            throw StillRunning(arguments: arguments)
        }
        return Outcome(status: command.terminationStatus, output: text(from: output), errors: text(from: errors))
    }

    @discardableResult
    func type(_ lines: [String], into shell: String, _ flags: String...) throws -> Outcome {
        let session = Process()
        session.executableURL = URL(fileURLWithPath: shell)
        session.arguments = flags
        session.environment = environment(autostart: false).merging(["HISTFILE": "/dev/null"]) { $1 }
        let typed = Pipe(), output = Pipe(), errors = Pipe()
        try typed.fileHandleForWriting.write(contentsOf: Data((lines + ["exit"]).joined(separator: "\n").appending("\n").utf8))
        try typed.fileHandleForWriting.close()
        session.standardInput = typed
        session.standardOutput = output
        session.standardError = errors
        try session.run()
        guard eventually({ !session.isRunning }) else {
            session.terminate()
            session.waitUntilExit()
            throw StillRunning(arguments: [shell] + flags)
        }
        return Outcome(status: session.terminationStatus, output: text(from: output), errors: text(from: errors))
    }

    var binary: String { Self.builtBinary.path }

    func leave(record: String) throws {
        try record.write(toFile: home + "/elvis.lock", atomically: false, encoding: .utf8)
    }

    @discardableResult
    func startApp() throws -> Process {
        let app = command(["run"], autostart: false)
        app.standardInput = FileHandle.nullDevice
        app.standardOutput = FileHandle.nullDevice
        app.standardError = FileHandle.nullDevice
        try app.run()
        appsStarted.append(app)
        return app
    }

    private func command(_ arguments: [String], autostart: Bool) -> Process {
        let command = Process()
        command.executableURL = Self.builtBinary
        command.arguments = arguments
        command.environment = environment(autostart: autostart)
        return command
    }

    private func environment(autostart: Bool) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("ELVIS_") }
        environment["ELVIS_HOME"] = home
        environment["ELVIS_HEADLESS"] = "1"
        if !autostart { environment["ELVIS_AUTOSTART"] = "0" }
        return environment
    }

    private func text(from pipe: Pipe) -> String {
        String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private static var builtBinary: URL {
        Bundle(for: IsolatedElvis.self).bundleURL.deletingLastPathComponent().appendingPathComponent("elvis")
    }
}
