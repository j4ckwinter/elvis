import Foundation

public struct Brain: Sendable {
    public enum Mode: Equatable, Sendable { case calm, working, waiting }
    public enum Cue: Equatable, Sendable { case whine, bark, yip }

    public struct Tuning: Sendable {
        public var longRun = 120.0
        public var shortRun = 20.0
        public var awakeFor = 20.0
        public var restUntil = 100.0
        public var dozeUntil = 240.0
        public var fetchEvery = 45.0
        public var whineEvery = 90.0
        public var buryEvery = 20.0
        public var barkEvery = 60.0
        public var staleAfter = 15.0 * 60
        public var waitingStaleAfter = 2.0 * 60 * 60
        public var siblingWindow = 3.0
        public init() {}
    }

    struct Step: Equatable, Sendable {
        var action: Action
        var duration: Double
        init(_ action: Action, _ duration: Double = 60) {
            self.action = action
            self.duration = duration
        }
    }

    public var tuning = Tuning()
    public internal(set) var world = World()
    public private(set) var action = Action.sit
    public private(set) var elapsed = 0.0
    public private(set) var actionSerial = 0
    public private(set) var now = 0.0

    public private(set) var duration = 2.0
    private var queue: [Step] = []
    private var reacting = false
    private var sessions = Sessions()
    var rng: SplitMix
    private var cues: [Cue] = []

    private(set) var modeSince = 0.0
    private(set) var settledSince = 0.0
    private var lastFetch = -1e9
    private var lastWhine = -1e9
    private var lastBurial = -1e9
    private var lastBark = -1e9
    private var lastFail = -1e9
    var flavour: WorkEvent.Flavour?
    private(set) var flavourAt = -1e9
    private(set) var hovering = false
    private var hoverTime = 0.0
    private(set) var pettedThisHover = false
    private var cursorMovedAt = -1e9

    public init(seed: UInt64) {
        rng = SplitMix(seed: seed)
        start(Step(.wagAtYou, 2.2))
    }

    public var mode: Mode { sessions.mode }
    var tally: Sessions.Tally { sessions.tally }

    public var moment: Moment {
        Moment(action: action, elapsed: elapsed, length: duration, serial: actionSerial, world: world, mode: mode, now: now)
    }

    public mutating func handle(_ event: WorkEvent) {
        guard let change = sessions.handle(event, now: now, tuning: tuning) else { return }
        let before = change.before
        let after = change.after
        if let kind = event.flavour, event.kind == .toolStarted {
            flavour = kind
            flavourAt = now
        }

        markModeChange(from: before)
        let failedAgain = event.kind == .testsFailed && now - lastFail < 60
        let redToGreen = event.kind == .testsPassed && world.glum > 0.25
        if event.kind == .testsFailed {
            lastFail = now
            world.glum = 1
        } else if event.kind == .testsPassed {
            world.glum = 0
        }
        if action == .held { return }

        if after == .waiting, before != .waiting {
            world.doorOpen = true
            react([])
            return
        }
        if before == .waiting, after != .waiting {
            world.doorOpen = false
            react([Step(.relief, 0.9)])
        }

        switch event.kind {
        case .testsFailed:
            if !failedAgain { whine() }
            if after == .waiting { return }
            react([Step(.droop, failedAgain ? 2.2 : 4.4)])
        case .testsPassed:
            if after == .waiting { return }
            if isFetching { return }
            if now - lastFetch >= tuning.fetchEvery {
                startFetch(celebrate: redToGreen)
            } else {
                react([Step(.wagAtYou, 2.0)])
            }
        case .committed:
            guard after != .waiting, now - lastBurial >= tuning.buryEvery else { break }
            lastBurial = now
            react([Step(.buryBone, 3.4)], append: reacting)
        case .pushed:
            guard after != .waiting else { break }
            let barkedLately = now - lastBark < tuning.barkEvery
            if !barkedLately { lastBark = now }
            react([barkedLately ? Step(.wagAtYou, 2.0) : Step(.bark, 1.2)], append: reacting)
        case .throwBall:
            if after != .waiting, !isFetching { startFetch(celebrate: false) }
        case .sessionStarted:
            if after == .calm, !reacting {
                react(action.isAsleep ? [Step(.sleepWag, 2.4)] : [Step(.wagAtYou, 2.4)])
            }
        case .taskStarted, .toolStarted, .toolFinished, .youAnswered:
            if before == .calm, after == .working, !reacting {
                react(action.isLyingDown ? [Step(.startle, 0.45), Step(.boundUp, 1.3)] : [Step(.boundUp, 1.1)])
            }
        case .taskFinished:
            guard after == .calm, change.wasWorking || before != .calm, change.runFinished else { break }
            finish(after: change.runLength)
        case .taskStumbled:
            if after == .calm { react([Step(.confused, 2.6)], append: reacting) }
        case .helperStarted:
            if change.firstHelperWentOut, after == .working, !reacting { react([Step(.listen, 1.8)]) }
        case .helperFinished, .needsYou, .sessionIdle, .sessionEnded, .quit:
            break
        }
    }

    public mutating func tick(_ dt: Double) {
        now += dt
        elapsed += dt
        world.glum = max(0, world.glum - dt / 50)
        if mode == .working { world.mud = min(1, world.mud + dt * 0.00007) }
        moveBall(dt)
        expireStaleSessions()

        if hovering {
            hoverTime += dt
            if hoverTime > 0.35, !pettedThisHover, !reacting, !isMoving {
                pettedThisHover = true
                queue = []
                start(Step(action.isAsleep ? .sleepWag : .petted, 2.2))
                return
            }
        }

        switch action {
        case .go(let target, let gait):
            if step(toward: target, speed: gait.speed, dt: dt) { advance() }
        case .chaseBall:
            guard let ball = world.ball else { advance(); break }
            let side = world.x <= ball.x ? -1.0 : 1.0
            let arrived = step(toward: ball.x + side * 14, speed: Gait.run.speed, dt: dt)
            if arrived, ball.state == .resting {
                world.facing = -side
                advance()
            } else if elapsed > duration {
                advance()
            }
        default:
            if elapsed >= duration { advance() }
        }
    }

    public mutating func cursor(at point: (x: Double, y: Double)?) {
        if let point, let last = world.cursor, abs(point.x - last.x) + abs(point.y - last.y) > 0.5 {
            cursorMovedAt = now
        }
        world.cursor = point
        let near = point.map { abs($0.x - world.x) < 24 && $0.y > -4 && $0.y < 36 } ?? false
        let over = near && now - cursorMovedAt < 1.5
        if over != hovering {
            hovering = over
            hoverTime = 0
            pettedThisHover = false
        }
    }

    public mutating func pat() {
        guard !reacting, !isMoving else { return }
        queue = []
        start(Step(action.isAsleep ? .sleepWag : .petted, 1.8))
    }

    public mutating func pickUp() {
        guard action != .held else { return }
        dropBallIfCarried()
        queue = []
        reacting = true
        start(Step(.held, .greatestFiniteMagnitude))
    }

    public mutating func putDown(at x: Double) {
        guard action == .held else { return }
        world.x = min(Yard.rightEdge, max(Yard.leftEdge, x))
        settledSince = now
        queue = chance(0.6) ? [Step(.landed, 0.6), Step(.shake, 1.4)] : [Step(.landed, 0.6)]
        reacting = true
        start(queue.removeFirst())
    }

    public mutating func drainCues() -> [Cue] {
        defer { cues = [] }
        return cues
    }

    public mutating func startNewDay() {
        world.mud = 0
    }

    public mutating func restore(mud: Double) {
        world.mud = min(1, max(0, mud))
    }

    public var isFetching: Bool {
        switch action {
        case .watchBall, .chaseBall, .skid, .grabBall, .dropBall: return true
        case .go(_, let gait): return gait == .prance || (gait == .run && world.ball != nil && reacting)
        default: return false
        }
    }

    private mutating func expireStaleSessions() {
        let before = mode
        sessions.expireStale(now: now, tuning: tuning)
        markModeChange(from: before)
    }

    private mutating func markModeChange(from before: Mode) {
        guard mode != before else { return }
        modeSince = now
        if mode == .calm { settledSince = now }
        world.doorOpen = mode == .waiting
    }

    private mutating func react(_ steps: [Step], append: Bool = false) {
        if append, reacting {
            queue.append(contentsOf: steps)
            return
        }
        dropBallIfCarried()
        queue = steps
        reacting = !steps.isEmpty
        advance()
    }

    private mutating func whine() {
        guard now - lastWhine >= tuning.whineEvery else { return }
        lastWhine = now
        cues.append(.whine)
    }

    private mutating func finish(after ran: Double?) {
        let steps: [Step]
        if let ran, ran >= tuning.longRun {
            steps = [Step(.flop, 14)]
            settledSince = now - tuning.awakeFor
        } else if let ran, ran >= tuning.shortRun {
            steps = [Step(.go(to: nearHome(), gait: .trot)), Step(.wagAtYou, 3.4)]
            settledSince = now
        } else {
            steps = [Step(.wagAtYou, 1.8)]
            settledSince = now
        }
        react(steps, append: reacting)
    }

    private mutating func startFetch(celebrate: Bool) {
        lastFetch = now
        settledSince = now
        let goLeft = world.x > Yard.home - 10
        let landing = goLeft ? Double.random(in: 30...52, using: &rng) : Double.random(in: 150...172, using: &rng)
        let startX = Yard.home
        let startY = Yard.height + 8
        let rise = 30.0
        let flight = (rise + (rise * rise + 2 * Yard.gravity * startY).squareRoot()) / Yard.gravity
        world.ball = Ball(x: startX, y: startY, vx: (landing - startX) / flight, vy: rise, state: .flying)

        var steps: [Step] = []
        if celebrate { steps.append(Step(.spin, 1.0)) }
        steps.append(Step(.watchBall, 0.6))
        if Double.random(in: 0...1, using: &rng) < 0.25 {
            let past = goLeft ? max(Yard.leftEdge - 8, landing - 30) : min(Yard.rightEdge + 8, landing + 30)
            steps += [Step(.go(to: past, gait: .run)), Step(.skid, 0.55)]
        }
        steps += [
            Step(.chaseBall, 6), Step(.grabBall, 0.45), Step(.go(to: nearHome(), gait: .prance)),
            Step(.dropBall, 0.5), Step(.proudSit, 4.2),
        ]
        react(steps)
    }

    private mutating func dropBallIfCarried() {
        guard var ball = world.ball, ball.state == .carried else { return }
        ball.state = .resting
        ball.x = min(Yard.width - 6, max(6, world.x + world.facing * 14))
        ball.y = 0
        ball.vx = 0
        ball.vy = 0
        ball.restedFor = 0
        world.ball = ball
    }

    private mutating func moveBall(_ dt: Double) {
        guard var ball = world.ball else { return }
        switch ball.state {
        case .carried:
            ball.x = world.x + world.facing * 14
            ball.y = 0
        case .resting:
            ball.restedFor += dt
            if ball.restedFor > 900, !isFetching {
                world.ball = nil
                return
            }
        case .flying:
            ball.fly(dt)
        }
        world.ball = ball
    }

    private var isMoving: Bool {
        switch action {
        case .go, .chaseBall: return true
        default: return false
        }
    }

    private mutating func step(toward target: Double, speed: Double, dt: Double) -> Bool {
        let gap = target - world.x
        if abs(gap) > 0.01 { world.facing = gap > 0 ? 1 : -1 }
        let stride = speed * dt
        if abs(gap) <= stride {
            world.x = target
            return true
        }
        world.x += gap > 0 ? stride : -stride
        return false
    }

    private mutating func advance() {
        finishCurrent()
        if queue.isEmpty {
            reacting = false
            queue = chooseNext()
        }
        start(queue.removeFirst())
    }

    private mutating func finishCurrent() {
        switch action {
        case .grabBall:
            world.ball?.state = .carried
        case .dropBall:
            dropBallIfCarried()
        case .dig, .buryBone:
            world.mud = min(1, world.mud + 0.03)
        case .shake:
            world.mud *= 0.4
        case .nudgeBall:
            if var ball = world.ball, ball.state == .resting {
                ball.state = .flying
                ball.vx = world.facing * 26
                ball.vy = 34
                world.ball = ball
            }
        default:
            break
        }
    }

    private mutating func start(_ step: Step) {
        action = step.action
        duration = step.duration
        elapsed = 0
        actionSerial += 1
        if let cue = Brain.cue(startedBy: step.action) { cues.append(cue) }
        if case .go(let target, _) = step.action, abs(target - world.x) > 0.01 {
            world.facing = target > world.x ? 1 : -1
        }
    }

    private static func cue(startedBy action: Action) -> Cue? {
        if action == .bark { return .bark }
        return action == .spin ? .yip : nil
    }

    mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0...1, using: &rng) < probability
    }

    private func nearHome() -> Double {
        let spot = Yard.home + (world.x < Yard.home ? -6 : 6)
        guard let ball = world.ball, ball.state == .resting, abs(ball.x - spot) < 14 else { return spot }
        return ball.x + (world.x < ball.x ? -18 : 18)
    }
}
