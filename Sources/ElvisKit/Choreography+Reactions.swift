import CoreGraphics
import Foundation

extension Choreography {
    static func startle(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.lie.mixed(with: .stand, ease(t / d) * 0.6)
        p.head.y += 3
        p.eyes = 1.35
        p.earLift = 1
        p.brow = 0.8
        p.lift = sin(min(1, t / d) * .pi) * 3.5
        return p
    }

    static func boundUp(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func droop(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func spin(elapsed t: Double, length d: Double) -> Pose {
        var p = gait(.trot, t)
        p.turn = cos(t / d * tau * 2)
        p.lift = abs(sin(t * 8)) * 4
        happy(&p, t)
        p.tail = 1.0 + sin(t * 16) * 0.5
        return p
    }

    static func confused(elapsed t: Double) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        let side = sin(t * 2.4) >= 0 ? 1.0 : -1.0
        p.tilt = 0.4 * side * ease(abs(sin(t * 2.4)) * 3)
        p.earLift = 0.5
        p.eyes = 1.15
        return p
    }

    static func flop(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func relief(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.stand
        p.lift = sin(min(1, t / d) * .pi) * 8
        p.turn = cos(ease(t / d) * tau)
        for i in 0..<4 { p.paws[i].y += sin(min(1, t / d) * .pi) * 2 }
        happy(&p, t)
        p.tail = 1.0 + sin(t * 18) * 0.5
        return p
    }
}
