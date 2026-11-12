import Foundation

/// What Elvis is told about the outside world. Hooks and shell integration reduce
/// their payloads to this before anything crosses the socket, so prompts, commands
/// and tool output never leave the process that received them.
public struct WorkEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case sessionStarted = "session-started"
        case taskStarted = "task-started"
        case toolStarted = "tool-started"
        case toolFinished = "tool-finished"
        case needsYou = "needs-you"
        case youAnswered = "you-answered"
        case testsPassed = "tests-passed"
        case testsFailed = "tests-failed"
        case taskFinished = "task-finished"
        case taskStumbled = "task-stumbled"
        case sessionIdle = "session-idle"
        case sessionEnded = "session-ended"
        case throwBall = "throw-ball"
        case quit
    }

    public enum Flavour: String, Codable, Sendable {
        case read, edit, shell, web, other
    }

    public var kind: Kind
    /// Empty for events that belong to no Claude Code session, such as a test run in the user's own shell.
    public var session: String
    public var flavour: Flavour?
    /// Opaque fingerprint of one tool call, used to pair a permission request with the call it was for.
    public var subject: String?
    /// Set for events from inside a subagent, so its tool calls are not mistaken for the main thread's.
    public var agent: String?

    public init(_ kind: Kind, session: String = "", flavour: Flavour? = nil, subject: String? = nil, agent: String? = nil) {
        self.kind = kind
        self.session = session
        self.flavour = flavour
        self.subject = subject
        self.agent = agent
    }

    public func encodedLine() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = (try? encoder.encode(self)) ?? Data()
        data.append(0x0A)
        return data
    }

    public static func decode(line: Data) -> WorkEvent? {
        try? JSONDecoder().decode(WorkEvent.self, from: line)
    }
}
