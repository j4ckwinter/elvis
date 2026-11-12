import Foundation

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
        case committed
        case pushed
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
    public var session: String
    public var flavour: Flavour?
    public var subject: String?
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
