import Foundation

/// Decides what Elvis does. It owns no clock and no randomness of its own, so a seed and a
/// sequence of `handle` and `tick` calls fully determine his behaviour.
public struct Brain: Sendable {
    public enum Mode: Equatable, Sendable { case calm, working, waiting }
    public enum Cue: Equatable, Sendable { case whine }

    public struct Tuning: Sendable {
        public var longRun = 120.0
        public var shortRun = 20.0
        public var awakeFor = 20.0
        public var restUntil = 100.0
        public var dozeUntil = 240.0
        public var fetchEvery = 45.0
        public var whineEvery = 90.0
        /// Longer than any single tool call is allowed to run, so silence this long means the session has gone.
        public var staleAfter = 15.0 * 60
        public var waitingStaleAfter = 2.0 * 60 * 60
        /// A tool that starts this soon after a permission request is a sibling call, not proof the user answered.
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
    public private(set) var world = World()
    public private(set) var action = Action.sit
    public private(set) var elapsed = 0.0
    /// Changes every time a new action starts, including a repeat of the same one.
    public private(set) var actionSerial = 0
    public private(set) var now = 0.0

    public private(set) var duration = 2.0
    private var queue: [Step] = []
    private var reacting = false
    private var sessions = Sessions()
    private var rng: SplitMix
    private var cues: [Cue] = []

    private var modeSince = 0.0
    private var settledSince = 0.0
    private var lastFetch = -1e9
    private var lastWhine = -1e9
    private var lastFail = -1e9
    private var flavour: WorkEvent.Flavour?
    private var flavourAt = -1e9
    private var hovering = false
    private var hoverTime = 0.0
    private var pettedThisHover = false
    private var cursorMovedAt = -1e9

    public init(seed: UInt64) {
        rng = SplitMix(seed: seed)
        start(Step(.wagAtYou, 2.2))
    }

    public var mode: Mode { sessions.mode }

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
            guard after == .calm, change.wasWorking || before != .calm, let ran = change.finishedRun else { break }
            finish(after: ran)
        case .taskStumbled:
            if after == .calm { react([Step(.confused, 2.6)], append: reacting) }
        case .needsYou, .sessionIdle, .sessionEnded, .quit:
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

    /// Tells Elvis where the pointer is, in yard units, or nil when it is nowhere near him.
    /// A pointer that is merely parked on top of him is not a stroke, so only a moving one counts.
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

    /// A click on him: a quick fuss, unless he is in the middle of something.
    public mutating func pat() {
        guard !reacting, !isMoving else { return }
        queue = []
        start(Step(action.isAsleep ? .sleepWag : .petted, 1.8))
    }

    /// Lifts him off the ground. He stays held, whatever Claude does, until `putDown`.
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

    /// Moves toward `target` and reports arrival.
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
        case .dig:
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
        if case .go(let target, _) = step.action, abs(target - world.x) > 0.01 {
            world.facing = target > world.x ? 1 : -1
        }
    }

    private mutating func chooseNext() -> [Step] {
        if hovering, pettedThisHover, mode != .waiting || abs(world.x - Yard.doorSpot) < 2 {
            return [Step(action.isAsleep ? .sleep : .petted, action.isAsleep ? 4 : 1.8)]
        }
        switch mode {
        case .waiting: return nextWhileWaiting()
        case .working: return nextWhileWorking()
        case .calm: return nextWhileCalm()
        }
    }

    private mutating func nextWhileWaiting() -> [Step] {
        if abs(world.x - Yard.doorSpot) > 1 {
            return [Step(.go(to: Yard.doorSpot, gait: .trot))]
        }
        world.facing = 1
        // No sound here: Claude Code reports nothing at the moment of approval, so a long approved command
        // looks the same as an unanswered prompt, and whining at someone who already answered would be wrong.
        if now - modeSince > 150 {
            return [Step(.lieByDoor, random(8, 14))]
        }
        if action != .stare { return [Step(.stare, random(3, 6))] }
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: return [Step(.tiltHead, 1.8)]
        case 1: return [Step(.pawDoor, 1.9)]
        default: return [Step(.glanceDoor, 1.5)]
        }
    }

    private mutating func nextWhileWorking() -> [Step] {
        let gait: Gait = world.glum > 0.3 ? .slink : .sniff
        let recent = now - flavourAt < 8 ? flavour : nil
        flavour = nil
        let roll = Double.random(in: 0...1, using: &rng)

        if world.glum < 0.3 {
            if roll < 0.04 { return [Step(.chaseTail, 2.2), Step(.startle, 0.5)] }
            if roll < 0.13 { return [Step(.checkIn, 1.9)] }
            if now - modeSince > 25 * 60, roll < 0.2 { return [Step(.pant, 4)] }
        }
        switch recent {
        case .edit:
            return [Step(.go(to: spot(within: 26), gait: gait)), Step(.dig, 2.6)]
        case .shell:
            if roll < 0.6 { return [Step(.point, random(2.4, 3.8))] }
        case .web:
            return [Step(.sniffAir, 2.4)]
        case .read, .other, nil:
            break
        }
        let trail: Gait = world.glum > 0.3 ? .slink : (roll > 0.8 ? .trot : gait)
        return [Step(.go(to: spot(within: 90), gait: trail)), Step(.sniffSpot, random(1.4, 2.8))]
    }

    private mutating func nextWhileCalm() -> [Step] {
        let settled = now - max(settledSince, modeSince)
        let lying = action.isLyingDown

        if world.mud > 0.5, !action.isAsleep, action != .shake, chance(0.5) {
            return lying ? [Step(.sit, 0.8), Step(.shake, 1.7)] : [Step(.shake, 1.7)]
        }
        if settled < tuning.awakeFor {
            switch Int.random(in: 0..<12, using: &rng) {
            case 0, 1: return [Step(.sit, random(2.5, 4.5))]
            case 2, 3: return [Step(.lookAround, random(2.5, 4))]
            case 4: return [Step(.wagAtYou, 2.2)]
            case 5: return [Step(.scratch, 2.3)]
            case 6: return [Step(.sneeze, 1.0), Step(.sit, 1.2)]
            case 7: return [Step(.chaseTail, 2.6), Step(.dizzy, 1.6)]
            case 8:
                if let ball = world.ball, ball.state == .resting {
                    let side = world.x <= ball.x ? -1.0 : 1.0
                    return [Step(.go(to: ball.x + side * 14, gait: .trot)), Step(.nudgeBall, 0.7), Step(.wagAtYou, 2.4)]
                }
                return [Step(.stretch, 2.2)]
            case 9: return [Step(.go(to: spot(within: 40), gait: .walk)), Step(.sniffSpot, 1.6)]
            default: return [Step(.sit, random(2, 3.5))]
            }
        }
        if settled < tuning.restUntil {
            if !lying { return [Step(.circle, 1.7), Step(.rest, random(5, 8))] }
            switch Int.random(in: 0..<8, using: &rng) {
            case 0: return [Step(.earFlap, 1.0)]
            case 1: return [Step(.sigh, 2.0)]
            case 2: return [Step(.yawn, 2.0)]
            default: return [Step(.rest, random(5, 9))]
            }
        }
        if settled < tuning.dozeUntil {
            if !lying { return [Step(.circle, 1.7), Step(.doze, random(8, 12))] }
            return [Step(.doze, random(8, 12))]
        }
        if !lying { return [Step(.circle, 1.7), Step(.doze, 6)] }
        if action == .sleep {
            switch Int.random(in: 0..<5, using: &rng) {
            case 0: return [Step(.dream, 5.5)]
            case 1: return [Step(.sleepSigh, 2.4)]
            case 2: return [Step(.sleepWag, 2.2)]
            default: return [Step(.sleepTwitch, 2.6)]
            }
        }
        return [Step(.sleep, random(12, 28))]
    }

    private mutating func random(_ low: Double, _ high: Double) -> Double {
        Double.random(in: low...high, using: &rng)
    }

    private mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0...1, using: &rng) < probability
    }

    private mutating func spot(within reach: Double) -> Double {
        let low = max(Yard.leftEdge, world.x - reach)
        let high = min(Yard.rightEdge, world.x + reach)
        guard low < high else { return min(Yard.rightEdge, max(Yard.leftEdge, world.x)) }
        for _ in 0..<4 {
            let candidate = random(low, high)
            if abs(candidate - world.x) > min(12, reach / 2) { return candidate }
        }
        return random(low, high)
    }

    private func nearHome() -> Double {
        let spot = Yard.home + (world.x < Yard.home ? -6 : 6)
        guard let ball = world.ball, ball.state == .resting, abs(ball.x - spot) < 14 else { return spot }
        return ball.x + (world.x < ball.x ? -18 : 18)
    }
}

extension Brain {
    /// A line for the menu: what Elvis thinks he is doing.
    public var caption: String {
        switch action {
        case .sleep, .sleepSigh: return "fast asleep"
        case .sleepTwitch: return "asleep, paws going"
        case .dream: return "dreaming about a tennis ball"
        case .sleepWag: return "asleep, but pleased about something"
        case .doze: return "dozing with one ear on you"
        case .rest, .sigh, .earFlap, .yawn: return "having a lie down"
        case .sit, .lookAround: return "keeping an eye on things"
        case .wagAtYou, .checkIn: return "checking you still like him"
        case .scratch: return "dealing with an itch"
        case .sneeze: return "surprised by his own sneeze"
        case .stretch: return "having a big stretch"
        case .circle: return "choosing the exact right spot"
        case .chaseTail: return "has spotted his tail again"
        case .dizzy: return "regretting the tail thing"
        case .shake: return "sharing the mud around"
        case .petted: return "being a very good boy"
        case .nudgeBall: return "wondering if you saw the ball"
        case .go(_, let gait):
            switch gait {
            case .sniff: return "following a very important smell"
            case .slink, .trudge: return "carrying on, bravely"
            case .prance: return "bringing it back, look, look"
            case .run: return "going as fast as he can"
            case .walk, .trot: return world.doorOpen ? "off to the door" : "on his way somewhere"
            }
        case .sniffSpot: return "sure there's something right here"
        case .dig: return "helping with the edits"
        case .point: return "pointing at the terminal"
        case .sniffAir: return "smelling the internet"
        case .pant: return "catching his breath"
        case .startle: return "awake! awake"
        case .boundUp: return "ready, so ready"
        case .droop: return "sorry about the tests"
        case .spin: return "they pass, they pass"
        case .confused: return "not sure what just happened"
        case .watchBall, .chaseBall, .skid, .grabBall: return "ball ball ball"
        case .dropBall, .proudSit: return "brought you this"
        case .flop: return "done in, and delighted"
        case .stare, .tiltHead, .pawDoor, .glanceDoor: return "waiting by the door for you"
        case .lieByDoor: return "still waiting by the door"
        case .relief: return "you answered"
        case .held: return "being carried, legs going"
        case .landed: return "back on solid ground"
        }
    }
}
