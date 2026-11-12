import CoreGraphics
import Foundation

extension Choreography {
    static func watchBall(elapsed t: Double) -> Pose {
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
    }

    static func skid(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func grabBall(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.noseDown
        let k = sin(min(1, t / d) * .pi)
        p.head = CGPoint(x: 15.5, y: 6.2 - 1.2 * k)
        p.pitch = -0.85
        p.mouth = 0.7 * k
        p.tail = 1.0 + sin(t * 18) * 0.4
        return p
    }

    static func dropBall(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.stand
        let k = ease(t / d)
        p.head = p.head.mixed(CGPoint(x: 16.5, y: 8), sin(k * .pi))
        p.pitch = -0.7 * sin(k * .pi)
        p.mouth = 0.7 * k
        p.tail = 1.0 + sin(t * 16) * 0.45
        return p
    }

    static func proudSit(elapsed t: Double) -> Pose {
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
    }
}
