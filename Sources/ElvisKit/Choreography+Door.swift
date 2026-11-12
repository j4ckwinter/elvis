import CoreGraphics
import Foundation

extension Choreography {
    static func stare(elapsed t: Double) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        p.eyes = 1.3
        p.brow = 0.35
        p.head = p.head + CGPoint(x: 0, y: -0.8)
        p.tail = -0.12 + max(0, sin(t * 1.1)) * 0.25 * abs(sin(t * 6))
        p.shoulder.y += sin(t * 1.9) * 0.2
        return p
    }

    static func tiltHead(elapsed t: Double, length d: Double, oddSerial odd: Bool) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        p.eyes = 1.3
        p.brow = 0.5
        p.tilt = (odd ? 0.42 : -0.42) * swell(t, d, attack: 0.25, release: 0.3)
        p.earLift = 0.5
        return p
    }

    static func pawDoor(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func glanceDoor(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func lieByDoor(elapsed t: Double) -> Pose {
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
    }
}
