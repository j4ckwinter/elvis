struct Sessions: Sendable {
    struct Change: Sendable {
        var before: Brain.Mode
        var after: Brain.Mode
        var wasWorking: Bool
        var runFinished: Bool
        var runLength: Double?
        var firstHelperWentOut: Bool
    }

    struct Tally: Equatable, Sendable {
        var working = 0
        var waiting = 0
        var helpers = 0
    }

    private struct Session: Sendable {
        enum State: Sendable { case idle, working, waiting }
        var state = State.idle
        var taskStart: Double?
        var waitingSince = 0.0
        var pending: String?
        var pendingAgent: String?
        var helpers: Set<String> = []
        var lastEvent = 0.0

        mutating func beginWork(at now: Double) {
            guard state == .idle else { return }
            state = .working
            if taskStart == nil { taskStart = now }
        }
    }

    private var live: [String: Session] = [:]
    private var ended: Set<String> = []
    private var lastStaleCheck = 0.0

    var mode: Brain.Mode {
        let states = live.values.map(\.state)
        return states.contains(.waiting) ? .waiting : states.contains(.working) ? .working : .calm
    }

    var tally: Tally {
        live.values.reduce(into: Tally()) { tally, session in
            tally.helpers += session.helpers.count
            switch session.state {
            case .working: tally.working += 1
            case .waiting: tally.waiting += 1
            case .idle: break
            }
        }
    }

    mutating func handle(_ event: WorkEvent, now: Double, tuning: Brain.Tuning) -> Change? {
        let before = mode
        let helpersBefore = tally.helpers
        let wasWorking = live[event.session]?.state == .working

        if ended.contains(event.session) {
            guard event.kind == .sessionStarted || event.kind == .taskStarted else { return nil }
            ended.remove(event.session)
        }
        var runEnd: (finished: Bool, length: Double?) = (false, nil)
        if !event.session.isEmpty {
            var session = live[event.session] ?? Session()
            session.lastEvent = now
            runEnd = update(&session, for: event, now: now, tuning: tuning)
            if session.state != .waiting {
                session.pending = nil
                session.pendingAgent = nil
            }
            live[event.session] = event.kind == .sessionEnded ? nil : session
        }
        return Change(
            before: before, after: mode, wasWorking: wasWorking, runFinished: runEnd.finished, runLength: runEnd.length,
            firstHelperWentOut: helpersBefore == 0 && tally.helpers > 0)
    }

    mutating func expireStale(now: Double, tuning: Brain.Tuning) {
        guard now - lastStaleCheck > 5 else { return }
        lastStaleCheck = now
        for (id, session) in live where session.state != .idle || !session.helpers.isEmpty {
            let limit = session.state == .waiting ? tuning.waitingStaleAfter : tuning.staleAfter
            guard now - session.lastEvent > limit else { continue }
            live[id]?.state = .idle
            live[id]?.taskStart = nil
            live[id]?.helpers = []
        }
    }

    private mutating func update(_ session: inout Session, for event: WorkEvent, now: Double, tuning: Brain.Tuning) -> (finished: Bool, length: Double?) {
        var runEnd: (finished: Bool, length: Double?) = (false, nil)
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
        case .toolFinished, .testsPassed, .testsFailed, .committed, .pushed:
            if session.state == .waiting {
                if session.pending == nil || session.pending == event.subject { session.state = .working }
            } else {
                session.beginWork(at: now)
            }
        case .helperStarted:
            if let helper = event.agent { session.helpers.insert(helper) }
        case .helperFinished:
            if let helper = event.agent { session.helpers.remove(helper) }
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
            runEnd = (true, session.taskStart.map { now - $0 })
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
        return runEnd
    }
}
