import CoreGraphics
import Foundation

/// Everything the animator needs to know about one instant of the brain.
public struct Moment: Sendable {
    public var action: Action
    public var elapsed: Double
    public var length: Double
    public var serial: Int
    public var world: World
    public var mode: Brain.Mode
    public var now: Double

    public init(action: Action, elapsed: Double, length: Double, serial: Int = 0, world: World = World(), mode: Brain.Mode = .calm, now: Double = 0) {
        self.action = action
        self.elapsed = elapsed
        self.length = length
        self.serial = serial
        self.world = world
        self.mode = mode
        self.now = now
    }
}

/// Maps an action and the time spent in it to a pose. Pure, so any frame can be rendered on its own.
public enum Choreography {
    private static let tau = 2 * Double.pi
    /// How far off the ground he dangles while carried, in dog units.
    static let carryHeight = 14.0

    public static func pose(for m: Moment) -> Pose {
        let t = m.elapsed
        let d = max(m.length, 0.01)
        let odd = m.serial % 2 == 1

        switch m.action {
        case .sleep:
            return asleep(t)

        case .sleepTwitch:
            var p = asleep(t)
            let burst = max(0, sin(t * 2.6)) * swell(t, d)
            p.paws[0].x += sin(t * 31) * 1.1 * burst
            p.paws[1].x += sin(t * 27 + 1) * 0.9 * burst
            p.paws[2].x += sin(t * 29 + 2) * 0.8 * burst
            p.earFling = sin(t * 24) * 0.25 * max(0, sin(t * 1.7 + 2))
            return p

        case .dream:
            var p = asleep(t)
            let run = swell(t, d, attack: 0.8, release: 0.8)
            for i in 0..<4 {
                p.paws[i].x += sin(t * 11 + Double(i) * 1.9) * 1.7 * run
                p.paws[i].y += max(0, sin(t * 11 + Double(i) * 1.9 + 1)) * 0.9 * run
            }
            p.tail += max(0, sin(t * 6)) * 0.35 * run
            p.mouth = max(0, sin(t * 4.2)) > 0.92 ? 0.25 : 0
            return p

        case .sleepSigh:
            var p = asleep(t)
            let breath = swell(t, d, attack: 0.9, release: 1.1) * 1.3
            p.shoulder.y += breath
            p.hip.y += breath * 0.6
            return p

        case .sleepWag:
            var p = asleep(t)
            p.tail = -0.1 + abs(sin(t * 5.5)) * 0.55 * swell(t, d)
            return p

        case .doze:
            var p = Pose.chinDown
            breathe(&p, t, depth: 0.35, rate: 1.3)
            p.eyes = 0.12 + 0.4 * max(0, sin(t * 0.55 + 0.4))
            p.look = CGPoint(x: 0.2, y: 0.5)
            p.earFling = sin(t * 26) * 0.2 * max(0, sin(t * 0.9 + 4) - 0.9) * 10
            return p

        case .rest:
            var p = Pose.lie
            breathe(&p, t, depth: 0.3, rate: 1.6)
            p.pitch = 0.05 + 0.08 * sin(t * 0.5)
            p.look = CGPoint(x: sin(t * 0.45), y: 0.1)
            p.tongue = 0.35
            p.mouth = 0.25
            p.tail = -0.1 + max(0, sin(t * 0.8)) * 0.12 * abs(sin(t * 5))
            return p

        case .sigh:
            let down = swell(t, d, attack: 0.6, release: 0.6)
            var p = Pose.lie.mixed(with: .chinDown, down)
            let breath = sin(min(1, t / d) * .pi) * 1.1
            p.shoulder.y += breath
            p.eyes = 1 - 0.6 * down
            p.brow = -0.4 * down
            return p

        case .earFlap:
            var p = Pose.lie
            let k = swell(t, d, attack: 0.1, release: 0.3)
            p.earFling = sin(t * 34) * 1.25 * k
            p.pitch = sin(t * 34) * 0.07 * k
            p.eyes = 1 - 0.9 * k
            return p

        case .yawn:
            var p = Pose.lie
            let k = swell(t, d, attack: 0.7, release: 0.5)
            p.pitch = 0.42 * k
            p.head.y += 2 * k
            p.mouth = k
            p.tongue = 0.5 * k
            p.eyes = 1 - k
            return p

        case .sit:
            var p = Pose.sit
            breathe(&p, t, depth: 0.25, rate: 1.8)
            p.tail = -0.12 + 0.18 * abs(sin(t * 3.2))
            p.tongue = 0.5
            p.mouth = 0.3
            p.look = CGPoint(x: 0.3, y: 0)
            return p

        case .lookAround:
            var p = Pose.sit
            breathe(&p, t, depth: 0.25, rate: 1.8)
            let part = t / d
            if part > 0.38, part < 0.72 {
                faceYou(&p)
                p.tilt = 0.12 * sin(t * 1.3)
                p.tongue = 0.7
                p.mouth = 0.4
            } else {
                p.pitch = part < 0.38 ? 0.22 * ease(part / 0.3) : -0.12
                p.earLift = part < 0.38 ? 0.6 : 0
            }
            p.tail = -0.12 + 0.2 * abs(sin(t * 3.6))
            return p

        case .wagAtYou:
            var p = Pose.sit
            faceYou(&p)
            happy(&p, t)
            p.tail = -0.05 + 0.6 * abs(sin(t * 7.5))
            p.hip.x += sin(t * 15) * 0.5
            p.tilt = 0.08 * sin(t * 2.1)
            return p

        case .scratch:
            var p = Pose.sit
            let k = swell(t, d, attack: 0.3, release: 0.3)
            p.head = p.head.mixed(CGPoint(x: 8.5, y: 25), k)
            p.pitch = 0.2 * k
            p.paws[2] = p.paws[2].mixed(CGPoint(x: 4.5 + sin(t * 44) * 1.3, y: 19.5 + cos(t * 44) * 1.6), k)
            p.eyes = 1 - 0.7 * k
            p.earFling = sin(t * 44) * 0.5 * k
            p.shoulder.x += sin(t * 44) * 0.25 * k
            return p

        case .sneeze:
            var p = Pose.sit
            if t < 0.38 {
                let k = ease(t / 0.38)
                p.pitch = 0.5 * k
                p.head.y += 1.6 * k
                p.eyes = 1 - k
                p.mouth = 0.4 * k
            } else {
                let k = ease((t - 0.38) / 0.1)
                let back = ease((t - 0.62) / 0.3)
                p.pitch = (0.5 - 1.25 * k) * (1 - back)
                p.head = p.head + CGPoint(x: 3.2, y: -5.5) * (k * (1 - back))
                p.eyes = back
                p.mouth = 0.6 * (1 - back)
            }
            return p

        case .stretch:
            let k = swell(t, d, attack: 0.5, release: 0.5)
            var p = Pose.stand.mixed(with: .bow, k)
            p.tail += 0.3 * sin(t * 9) * k
            p.mouth = 0.8 * swell(t, d, attack: 0.9, release: 0.7)
            p.eyes = 1 - 0.8 * k
            p.pitch = 0.25 * k
            return p

        case .circle:
            var p = gait(.walk, t)
            let angle = t / d * tau * 2
            p.turn = cos(angle)
            p.head.y -= 3
            p.pitch = -0.3
            return p.mixed(with: .lie, ease((t - d + 0.35) / 0.35))

        case .chaseTail:
            var p = gait(.trot, t * 1.4)
            p.turn = cos(t * tau * 2.3)
            p.head = CGPoint(x: 12.5, y: 21)
            p.pitch = -0.35
            p.mouth = 0.7
            p.tail = 0.4 + 0.4 * sin(t * 12)
            p.lift = abs(sin(t * 9)) * 1.5
            return p

        case .dizzy:
            var p = Pose.sit
            faceYou(&p)
            let k = 1 - ease(t / d)
            p.tilt = 0.3 * sin(t * 5.2) * k
            p.head.x += sin(t * 5.2) * 1.6 * k
            p.look = CGPoint(x: cos(t * 9), y: sin(t * 9)) * k
            p.tongue = 0.8
            p.mouth = 0.5
            return p

        case .shake:
            var p = Pose.stand
            faceYou(&p)
            let k = swell(t, d, attack: 0.15, release: 0.35)
            let s = sin(t * 38)
            p.earFling = s * 1.5 * k
            p.tilt = s * 0.22 * k
            p.head.x += s * 0.8 * k
            p.shoulder.x += s * 0.9 * k
            p.hip.x -= s * 0.9 * k
            p.tail = 0.5 + s * 0.5 * k
            p.eyes = 1 - k
            return p

        case .petted:
            var p = Pose.sit
            faceYou(&p)
            p.happyEyes = 1
            p.head.y += 1.2 + sin(t * 3.4) * 0.9
            p.tilt = 0.16 * sin(t * 1.7)
            p.tongue = 0.8
            p.mouth = 0.5
            p.tail = -0.05 + 0.65 * abs(sin(t * 8.5))
            p.hip.x += sin(t * 17) * 0.5
            return p

        case .nudgeBall:
            var p = Pose.noseDown
            p.head.x += 2.5 * sin(min(1, t / d) * .pi)
            p.tail = 0.9 + 0.3 * sin(t * 14)
            return p

        case .go(_, let style):
            var p = gait(style, t)
            if m.world.glum > 0.3, style != .slink { droopEars(&p, m.world.glum) }
            if m.world.ball?.state == .carried, style == .prance {
                p.happyEyes = 0.6
            }
            return p

        case .sniffSpot:
            var p = Pose.noseDown
            let found = ease((t - d * 0.45) / 0.3)
            p.head.x += sin(t * 11) * 0.7
            p.head.y += abs(sin(t * 5.5)) * 0.4
            p.tail = 0.85 + sin(t * (6 + 9 * found)) * (0.2 + 0.25 * found)
            p.hip.x += sin(t * 15) * 0.4 * found
            return p

        case .dig:
            var p = Pose.stand.mixed(with: .bow, 0.55)
            let k = swell(t, d, attack: 0.25, release: 0.25)
            p.head = CGPoint(x: 17, y: 9 + sin(t * 13) * 0.6)
            p.pitch = -0.7
            p.paws[0] = CGPoint(x: 15.5 - cos(t * 17) * 3.4 * k, y: max(0, sin(t * 17)) * 3 * k)
            p.paws[1] = CGPoint(x: 13.5 + cos(t * 17) * 3.4 * k, y: max(0, -sin(t * 17)) * 3 * k)
            p.tail = 1.1 + sin(t * 13) * 0.35
            p.hip.x += sin(t * 17) * 0.35 * k
            return p

        case .point:
            var p = Pose.stand
            let k = ease(t / 0.3)
            p.head = p.head.mixed(CGPoint(x: 17.5, y: 25), k)
            p.pitch = -0.04
            p.paws[1] = p.paws[1].mixed(CGPoint(x: 10, y: 8), k)
            p.tail = 0.5 - 0.42 * k + sin(t * 40) * 0.015
            p.earLift = k
            p.eyes = 1.2
            p.brow = 0.6
            p.shoulder.x += 0.8 * k
            return p

        case .sniffAir:
            var p = Pose.stand
            let k = swell(t, d, attack: 0.3, release: 0.3)
            p.pitch = 0.75 * k
            p.head = p.head + CGPoint(x: -0.5, y: 2.2) * k
            p.head.y += sin(t * 12) * 0.35 * k
            p.eyes = 1 - 0.6 * k
            p.tail = 0.6 + sin(t * 5) * 0.2
            return p

        case .checkIn:
            var p = Pose.stand
            faceYou(&p)
            happy(&p, t)
            p.tilt = odd ? 0.14 : -0.14
            p.tail = 0.7 + sin(t * 13) * 0.45
            p.hip.x += sin(t * 13) * 0.4
            return p

        case .pant:
            var p = Pose.sit
            faceYou(&p)
            breathe(&p, t, depth: 0.5, rate: 9)
            p.tongue = 1
            p.mouth = 0.7
            p.head.y += sin(t * 9) * 0.3
            p.eyes = 0.75
            return p

        case .startle:
            var p = Pose.lie.mixed(with: .stand, ease(t / d) * 0.6)
            p.head.y += 3
            p.eyes = 1.35
            p.earLift = 1
            p.brow = 0.8
            p.lift = sin(min(1, t / d) * .pi) * 3.5
            return p

        case .boundUp:
            var p = Pose.stand
            let hop = abs(sin(t * .pi / 0.42))
            let fade = 1 - 0.45 * ease(t / d)
            p.lift = hop * 9 * fade
            for i in 0..<4 { p.paws[i].y += hop * 2.2 }
            p.paws[0].x += hop * 2
            p.paws[1].x += hop * 2
            p.paws[2].x -= hop * 2
            p.paws[3].x -= hop * 2
            p.pitch = 0.18
            p.mouth = 0.6
            p.tongue = 0.7
            p.earLift = 0.5
            p.tail = 0.9 + sin(t * 16) * 0.5
            p.brow = 0.7
            return p

        case .droop:
            var p = Pose.sit
            faceYou(&p)
            let k = ease(t / 0.5)
            p.head = p.head + CGPoint(x: 0, y: -4.2) * k
            p.shoulder.y -= 1.2 * k
            p.earDroop = k
            p.brow = -k
            p.eyes = 0.85
            p.look = CGPoint(x: 0, y: t < d * 0.45 ? -0.7 * k : 0.55)
            p.tail = -0.3
            if t < 1.4 {
                p.mouth = 0.18
                p.head.x += sin(t * 46) * 0.12
            }
            return p

        case .spin:
            var p = gait(.trot, t)
            p.turn = cos(t / d * tau * 2)
            p.lift = abs(sin(t * 8)) * 4
            happy(&p, t)
            p.tail = 1.0 + sin(t * 16) * 0.5
            return p

        case .confused:
            var p = Pose.sit
            faceYou(&p)
            let side = sin(t * 2.4) >= 0 ? 1.0 : -1.0
            p.tilt = 0.4 * side * ease(abs(sin(t * 2.4)) * 3)
            p.earLift = 0.5
            p.eyes = 1.15
            return p

        case .watchBall:
            var p = Pose.stand
            p.hip.y -= 2
            p.shoulder.y -= 1.2
            p.pitch = 0.5
            p.head.y += 1
            p.earLift = 1
            p.eyes = 1.3
            p.brow = 0.8
            p.tail = 0.9 + sin(t * 22) * 0.5
            p.hip.x += sin(t * 22) * 0.6
            return p

        case .chaseBall:
            return gait(.run, t)

        case .skid:
            var p = Pose.stand
            let k = 1 - ease(t / d)
            p.lean = -0.22 * k
            p.paws[0].x += 5 * k
            p.paws[1].x += 5 * k
            p.paws[2].x += 4 * k
            p.paws[3].x += 4 * k
            p.hip.y -= 4 * k
            p.eyes = 1.35
            p.earLift = 0.6
            p.mouth = 0.4
            return p

        case .grabBall:
            var p = Pose.noseDown
            let k = sin(min(1, t / d) * .pi)
            p.head = CGPoint(x: 15.5, y: 6.2 - 1.2 * k)
            p.pitch = -0.85
            p.mouth = 0.7 * k
            p.tail = 1.0 + sin(t * 18) * 0.4
            return p

        case .dropBall:
            var p = Pose.stand
            let k = ease(t / d)
            p.head = p.head.mixed(CGPoint(x: 16.5, y: 8), sin(k * .pi))
            p.pitch = -0.7 * sin(k * .pi)
            p.mouth = 0.7 * k
            p.tail = 1.0 + sin(t * 16) * 0.45
            return p

        case .proudSit:
            var p = Pose.sit
            faceYou(&p)
            happy(&p, t)
            p.shoulder.y += 1
            p.head.y += 1.2
            p.tail = -0.05 + 0.7 * abs(sin(t * 8))
            p.hip.x += sin(t * 16) * 0.5
            let glance = sin(t * 1.9)
            p.look = CGPoint(x: glance > 0.6 ? 0.9 : 0, y: glance > 0.6 ? -0.5 : 0)
            p.happyEyes = glance < -0.5 ? 1 : 0
            return p

        case .flop:
            let down = ease(t / 0.55)
            var p = Pose.stand.mixed(with: .sploot, down)
            p.lift = sin(min(1, t / 0.55) * .pi) * 1.2 + max(0, sin((t - 0.55) * 12)) * exp(-(max(0, t - 0.55)) * 6) * 1.2
            let puff = 9 - 6 * ease(t / d)
            breathe(&p, t, depth: 0.55, rate: puff)
            p.tongue = down
            p.mouth = 0.7 * down
            p.happyEyes = sin(t * 0.9) > -0.2 ? down : 0
            p.eyes = 0.8
            p.look = CGPoint(x: -0.2, y: 0.6)
            p.tail = -0.05 + abs(sin(t * 4.2)) * 0.5 * down
            return p

        case .stare:
            var p = Pose.sit
            faceYou(&p)
            p.eyes = 1.3
            p.brow = 0.35
            p.head = p.head + CGPoint(x: 0, y: -0.8)
            p.tail = -0.12 + max(0, sin(t * 1.1)) * 0.25 * abs(sin(t * 6))
            p.shoulder.y += sin(t * 1.9) * 0.2
            return p

        case .tiltHead:
            var p = Pose.sit
            faceYou(&p)
            p.eyes = 1.3
            p.brow = 0.5
            p.tilt = (odd ? 0.42 : -0.42) * swell(t, d, attack: 0.25, release: 0.3)
            p.earLift = 0.5
            return p

        case .pawDoor:
            var p = Pose.sit
            let part = t / d
            if part < 0.7 {
                let k = swell(t, d * 0.7, attack: 0.2, release: 0.2)
                p.paws[0] = p.paws[0].mixed(CGPoint(x: 17.5 + sin(t * 15) * 1.2, y: 10 + sin(t * 15 + 1.5) * 3.4), k)
                p.pitch = 0.1
                p.head.x += 1.5 * k
                p.earLift = 0.4
            } else {
                faceYou(&p)
                p.eyes = 1.3
                p.brow = -0.3
            }
            return p

        case .glanceDoor:
            var p = Pose.sit
            let part = t / d
            if part > 0.15, part < 0.7 {
                p.pitch = 0.12
                p.earLift = 0.7
                p.eyes = 1.15
            } else {
                faceYou(&p)
                p.eyes = 1.3
                p.brow = 0.35
            }
            return p

        case .lieByDoor:
            var p = Pose.chinDown
            faceYou(&p)
            p.head = CGPoint(x: 15.5, y: 7.2)
            breathe(&p, t, depth: 0.35, rate: 1.4)
            p.brow = -0.6
            p.eyes = 1.1
            p.look = CGPoint(x: 0, y: 0.75)
            p.earDroop = 0.5
            p.tail = -0.1 + max(0, sin(t * 0.7) - 0.6) * abs(sin(t * 5)) * 0.6
            return p

        case .held:
            var p = Pose()
            let scrabble = swell(t, 1.2, attack: 0.1, release: 0.9) * sin(t * 19) * 1.5
            let calm = ease((t - 0.8) / 0.6)
            p.shoulder = CGPoint(x: 3, y: 30)
            p.hip = CGPoint(x: -5, y: 16.5)
            p.paws = [
                CGPoint(x: 7 + sin(t * 3.1) * 0.9 + scrabble, y: 12.5),
                CGPoint(x: 4.5 + sin(t * 3.1 + 1) * 0.9 - scrabble, y: 13.5),
                CGPoint(x: -3.5 + sin(t * 2.7 + 2) * 1.1 + scrabble, y: 1.0),
                CGPoint(x: -6 + sin(t * 2.7 + 3) * 1.1 - scrabble, y: 1.8),
            ]
            p.head = CGPoint(x: 6.5, y: 39)
            p.front = 1
            p.lift = Choreography.carryHeight * ease(t / 0.18)
            p.tail = -1.0 + 0.3 * sin(t * 5) * calm
            p.eyes = 1.35 - 0.35 * calm
            p.earLift = 0.6 * (1 - calm)
            p.brow = 0.6 * (1 - calm)
            p.tongue = 0.8 * calm
            p.mouth = 0.5 * calm
            return p

        case .landed:
            var p = Pose.stand
            let fall = min(1, t / 0.16)
            let squash = sin(min(1, max(0, (t - 0.16) / 0.3)) * .pi)
            p.lift = Choreography.carryHeight * (1 - fall * fall)
            p.hip.y -= 3.5 * squash
            p.shoulder.y -= 3 * squash
            p.head.y -= 4 * squash
            p.paws[0].x += 1.5 * squash
            p.paws[2].x -= 1.5 * squash
            p.eyes = 1.25
            p.tail = 0.3 + 0.5 * squash
            return p

        case .relief:
            var p = Pose.stand
            p.lift = sin(min(1, t / d) * .pi) * 8
            p.turn = cos(ease(t / d) * tau)
            for i in 0..<4 { p.paws[i].y += sin(min(1, t / d) * .pi) * 2 }
            happy(&p, t)
            p.tail = 1.0 + sin(t * 18) * 0.5
            return p
        }
    }

    static func gait(_ style: Gait, _ t: Double) -> Pose {
        var p: Pose
        var rate: Double, stride: Double, stepHeight: Double, bob: Double
        var phases = [0.0, Double.pi, Double.pi, 0.0]
        switch style {
        case .walk:
            p = .stand
            (rate, stride, stepHeight, bob) = (1.7, 3.2, 2.2, 0.5)
            p.tail = 0.55 + sin(t * 6) * 0.2
        case .sniff:
            p = .noseDown
            (rate, stride, stepHeight, bob) = (1.5, 2.6, 1.8, 0.3)
            p.head.x += sin(t * 10) * 0.6
            p.tail = 0.85 + sin(t * 9) * 0.28
        case .trot:
            p = .stand
            (rate, stride, stepHeight, bob) = (2.7, 4.4, 3.2, 1.3)
            p.pitch = 0.06
            p.mouth = 0.4
            p.tongue = 0.5
            p.tail = 0.7 + sin(t * 10) * 0.3
        case .prance:
            p = .stand
            (rate, stride, stepHeight, bob) = (2.5, 3.6, 5.0, 2.0)
            p.head = CGPoint(x: 14.5, y: 30.5)
            p.pitch = 0.3
            p.shoulder.y += 0.8
            p.tail = 1.25 + sin(t * 13) * 0.4
            p.brow = 0.5
        case .run:
            p = .stand
            (rate, stride, stepHeight, bob) = (3.3, 7.2, 3.6, 0)
            phases = [0, 0.7, Double.pi * 0.95, Double.pi * 0.95 + 0.7]
            let rock = sin(t * rate * tau)
            p.shoulder.y += rock * 1.6
            p.hip.y -= rock * 1.6
            p.lift = max(0, sin(t * rate * tau + 0.6)) * 3.2
            p.head = CGPoint(x: 17.5, y: 26 + rock * 1.2)
            p.mouth = 0.7
            p.tongue = 0.8
            p.tail = 0.25 + rock * 0.15
            p.brow = 0.7
        case .slink:
            p = .stand
            (rate, stride, stepHeight, bob) = (1.2, 2.2, 1.4, 0.2)
            p.head = CGPoint(x: 16.5, y: 21)
            p.pitch = -0.3
            p.tail = -0.55
            p.earDroop = 1
            p.brow = -1
            p.eyes = 0.8
        case .trudge:
            p = .stand
            (rate, stride, stepHeight, bob) = (1.2, 2.4, 1.5, 0.3)
            p.head = CGPoint(x: 16.5, y: 22.5)
            p.pitch = -0.2
            p.tail = 0.1
            p.tongue = 0.9
            p.mouth = 0.6
        }
        let cycle = t * rate * tau
        for i in 0..<4 {
            let phase = cycle + phases[i]
            p.paws[i].x -= stride * cos(phase)
            p.paws[i].y += max(0, sin(phase)) * stepHeight
        }
        p.lift += abs(sin(cycle)) * bob
        return p
    }

    private static func asleep(_ t: Double) -> Pose {
        var p = Pose.chinDown
        breathe(&p, t, depth: 0.5, rate: 1.05)
        p.eyes = 0
        p.tail = -0.1
        return p
    }

    private static func breathe(_ p: inout Pose, _ t: Double, depth: Double, rate: Double) {
        let breath = sin(t * rate) * depth
        p.shoulder.y += breath
        p.hip.y += breath * 0.6
    }

    private static func faceYou(_ p: inout Pose) {
        p.front = 1
        p.head.x -= 1.6
        p.pitch = 0
    }

    private static func happy(_ p: inout Pose, _ t: Double) {
        p.tongue = 0.85 + sin(t * 9) * 0.12
        p.mouth = 0.6
        p.brow = 0.5
    }

    private static func droopEars(_ p: inout Pose, _ amount: Double) {
        p.earDroop = max(p.earDroop, amount)
        p.brow = min(p.brow, -amount)
    }
}
