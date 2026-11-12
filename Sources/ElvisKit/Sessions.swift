/// What Claude Code's sessions are doing, worked out from the events they send.
struct Sessions: Sendable {
    /// What one event did, for `Brain` to react to.
    struct Change: Sendable {
        var before: Brain.Mode
        var after: Brain.Mode
        /// Whether the event's own session was working when it arrived.
        var wasWorking: Bool
        /// Set when the event ended a run. The length inside is nil when the run's start was never seen.
        var finishedRun: Double??
    }

    private struct Session: Sendable {
        enum State: Sendable { case idle, working, waiting }
        var state = State.idle
        var taskStart: Double?
        var waitingSince = 0.0
        var pending: String?
        var pendingAgent: String?
        var lastEvent = 0.0

        mutating func beginWork(at now: Double) {
            guard state == .idle else { return }
            state = .working
            if taskStart == nil { taskStart = now }
        }
    }

    private var live: [String: Session] = [:]
    /// Hooks are asynchronous, so a straggler can arrive after its session has ended.
    private var ended: Set<String> = []
    private var lastStaleCheck = 0.0

    var mode: Brain.Mode {
        let states = live.values.map(\.state)
        return states.contains(.waiting) ? .waiting : states.contains(.working) ? .working : .calm
    }

    /// Returns nil for a straggler from an ended session, which changes nothing.
    mutating func handle(_ event: WorkEvent, now: Double, tuning: Brain.Tuning) -> Change? {
        let before = mode
        let wasWorking = live[event.session]?.state == .working

        if ended.contains(event.session) {
            guard event.kind == .sessionStarted || event.kind == .taskStarted else { return nil }
            ended.remove(event.session)
        }
        var finishedRun: Double??
        if !event.session.isEmpty {
            var session = live[event.session] ?? Session()
            session.lastEvent = now
            finishedRun = update(&session, for: event, now: now, tuning: tuning)
            if session.state != .waiting {
                session.pending = nil
                session.pendingAgent = nil
            }
            live[event.session] = event.kind == .sessionEnded ? nil : session
        }
        return Change(before: before, after: mode, wasWorking: wasWorking, finishedRun: finishedRun)
    }

    mutating func expireStale(now: Double, tuning: Brain.Tuning) {
        guard now - lastStaleCheck > 5 else { return }
        lastStaleCheck = now
        for (id, session) in live where session.state != .idle {
            let limit = session.state == .waiting ? tuning.waitingStaleAfter : tuning.staleAfter
            guard now - session.lastEvent > limit else { continue }
            live[id]?.state = .idle
            live[id]?.taskStart = nil
        }
    }

    /// Returns the value for `Change.finishedRun`.
    private mutating func update(_ session: inout Session, for event: WorkEvent, now: Double, tuning: Brain.Tuning) -> Double?? {
        var finishedRun: Double??
        switch event.kind {
        case .sessionStarted, .throwBall, .quit:
            break
        case .taskStarted:
            session.state = .working
            session.taskStart = now
            session.pending = nil
        case .toolStarted:
            if session.state == .waiting {
                if now - session.waitingSince >= tuning.siblingWindow, event.agent == session.pendingAgent { session.state = .working }
            } else {
                session.beginWork(at: now)
            }
        case .toolFinished, .testsPassed, .testsFailed:
            if session.state == .waiting {
                if session.pending == nil || session.pending == event.subject { session.state = .working }
            } else {
                session.beginWork(at: now)
            }
        case .needsYou:
            if session.state != .waiting {
                session.beginWork(at: now)
                session.state = .waiting
                session.waitingSince = now
                session.pending = nil
                session.pendingAgent = event.agent
            }
            if let subject = event.subject {
                session.pending = subject
                session.pendingAgent = event.agent
            }
        case .youAnswered:
            if session.state == .waiting { session.state = .working }
        case .taskFinished, .taskStumbled:
            finishedRun = .some(session.taskStart.map { now - $0 })
            session.state = .idle
            session.taskStart = nil
        case .sessionIdle:
            if session.state == .working {
                session.state = .idle
                session.taskStart = nil
            }
        case .sessionEnded:
            if ended.count > 500 { ended.removeAll() }
            ended.insert(event.session)
        }
        return finishedRun
    }
}
