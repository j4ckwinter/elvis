import ElvisKit
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

func ownPath() -> String {
    let given = CommandLine.arguments[0]
    if given.contains("/") { return URL(fileURLWithPath: given).standardizedFileURL.path }
    return Bundle.main.executablePath ?? given
}

func wake() -> Bool {
    if EventSocket.isSomeoneListening { return true }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ownPath())
    process.arguments = ["run", "--detached"]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return false }
    for _ in 0..<40 {
        usleep(50_000)
        if EventSocket.isSomeoneListening { return true }
    }
    return false
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("elvis: \(message)\n".utf8))
    exit(2)
}

let usage = """
    elvis                 run Elvis in the foreground
    elvis start           wake Elvis in the background
    elvis quit            send him to bed
    elvis restart         swap the running Elvis for this build
    elvis tell <event>    report something by hand: \(WorkEvent.Kind.allCases.map(\.rawValue).joined(separator: ", "))
    elvis demo            walk through his reactions
    elvis shell-init <zsh|bash>  print shell integration for your own test runs, commits, and pushes
    elvis hook            (used by the Claude Code plugin) read a hook payload on stdin
    elvis ran <status> <command>  (used by shell integration)
    elvis sheets [dir]    render pose sheets as PNGs
    """

switch arguments.first {
case nil, "run":
    ElvisApp.run(detached: arguments.contains("--detached"))

case "start":
    if !wake() { fail("could not start") }

case "quit":
    EventSocket.send(WorkEvent(.quit))

case "restart":
    EventSocket.send(WorkEvent(.quit))
    var patience = 40
    while EventSocket.isSomeoneListening, patience > 0 {
        usleep(50_000)
        patience -= 1
    }
    if EventSocket.isSomeoneListening { fail("the running Elvis did not quit") }
    let theOldOneMayStillHoldTheLock = !wake()
    if theOldOneMayStillHoldTheLock, !wake() { fail("could not start") }

case "hook":
    // A hook must never disturb Claude Code: no output, and exit 0 whatever happens.
    let payload = FileHandle.standardInput.readDataToEndOfFile()
    guard let event = ClaudeHooks.event(fromPayload: payload) else { exit(0) }
    if !EventSocket.send(event), event.kind == .sessionStarted, ProcessInfo.processInfo.environment["ELVIS_AUTOSTART"] != "0" {
        if wake() { EventSocket.send(event) }
    }
    exit(0)

case "tell":
    guard arguments.count > 1, let kind = WorkEvent.Kind(rawValue: arguments[1]) else { fail("tell needs one of: \(WorkEvent.Kind.allCases.map(\.rawValue).joined(separator: ", "))") }
    var event = WorkEvent(kind, session: "by-hand")
    if arguments.count > 2 { event.flavour = WorkEvent.Flavour(rawValue: arguments[2]) }
    let needsNoSession: Set<WorkEvent.Kind> = [.testsPassed, .testsFailed, .committed, .pushed, .throwBall]
    if needsNoSession.contains(kind) { event.session = "" }
    if kind == .helperStarted || kind == .helperFinished { event.agent = "by-hand" }
    if !EventSocket.send(event) { fail("Elvis isn't running. Try: elvis start") }

case "ran":
    guard arguments.count > 2, let status = Int(arguments[1]) else { exit(0) }
    let command = arguments[2...].joined(separator: " ")
    if let news = ShellNews.ofYourOwnCommand(command, exitStatus: status) { EventSocket.send(WorkEvent(news)) }

case "shell-init":
    guard let shell = arguments.dropFirst().first.flatMap(ShellIntegration.Shell.init(rawValue:)) else {
        fail("shell-init needs one of: \(ShellIntegration.Shell.allCases.map(\.rawValue).joined(separator: ", "))")
    }
    print(ShellIntegration.script(for: shell, elvis: ownPath()))

case "demo":
    guard wake() else { fail("could not start") }
    let script: [(String, WorkEvent, Double)] = [
        ("You start a session. He notices.", WorkEvent(.sessionStarted, session: "demo"), 4),
        ("You send a prompt. Up he gets.", WorkEvent(.taskStarted, session: "demo"), 4),
        ("Claude reads files. He follows the trail.", WorkEvent(.toolStarted, session: "demo", flavour: .read), 7),
        ("Claude edits. He helps by digging.", WorkEvent(.toolStarted, session: "demo", flavour: .edit), 7),
        ("Claude runs a command. He points.", WorkEvent(.toolStarted, session: "demo", flavour: .shell), 5),
        ("Claude sends out a helper. He pricks up his ears.", WorkEvent(.helperStarted, session: "demo", agent: "demo-helper"), 4),
        ("The helper comes back.", WorkEvent(.helperFinished, session: "demo", agent: "demo-helper"), 1),
        ("The tests fail.", WorkEvent(.testsFailed, session: "demo"), 7),
        ("Claude needs your approval. He waits by the door.", WorkEvent(.needsYou, session: "demo"), 14),
        ("You answer.", WorkEvent(.youAnswered, session: "demo"), 4),
        ("The tests pass. Fetch.", WorkEvent(.testsPassed, session: "demo"), 13),
        ("Claude commits. He buries a bone.", WorkEvent(.committed, session: "demo"), 5),
        ("Claude pushes. He tells the street.", WorkEvent(.pushed, session: "demo"), 3),
        ("Claude finishes.", WorkEvent(.taskFinished, session: "demo"), 6),
        ("The session ends.", WorkEvent(.sessionEnded, session: "demo"), 0),
    ]
    for (line, event, pause) in script {
        print(line)
        EventSocket.send(event)
        Thread.sleep(forTimeInterval: pause)
    }

case "sheets":
    try Sheets.write(to: arguments.count > 1 ? arguments[1] : "sheets")

default:
    print(usage)
}
