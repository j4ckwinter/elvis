import CoreGraphics
import Foundation

extension Choreography {
    static func sniffSpot(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.noseDown
        let found = ease((t - d * 0.45) / 0.3)
        p.head.x += sin(t * 11) * 0.7
        p.head.y += abs(sin(t * 5.5)) * 0.4
        p.tail = 0.85 + sin(t * (6 + 9 * found)) * (0.2 + 0.25 * found)
        p.hip.x += sin(t * 15) * 0.4 * found
        return p
    }

    static func dig(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.stand.mixed(with: .bow, 0.55)
        let k = swell(t, d, attack: 0.25, release: 0.25)
        p.head = CGPoint(x: 17, y: 9 + sin(t * 13) * 0.6)
        p.pitch = -0.7
        p.paws[0] = CGPoint(x: 15.5 - cos(t * 17) * 3.4 * k, y: max(0, sin(t * 17)) * 3 * k)
        p.paws[1] = CGPoint(x: 13.5 + cos(t * 17) * 3.4 * k, y: max(0, -sin(t * 17)) * 3 * k)
        p.tail = 1.1 + sin(t * 13) * 0.35
        p.hip.x += sin(t * 17) * 0.35 * k
        return p
    }

    static func point(elapsed t: Double) -> Pose {
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
    }

    static func sniffAir(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.stand
        let k = swell(t, d, attack: 0.3, release: 0.3)
        p.pitch = 0.75 * k
        p.head = p.head + CGPoint(x: -0.5, y: 2.2) * k
        p.head.y += sin(t * 12) * 0.35 * k
        p.eyes = 1 - 0.6 * k
        p.tail = 0.6 + sin(t * 5) * 0.2
        return p
    }

    static func checkIn(elapsed t: Double, oddSerial odd: Bool) -> Pose {
        var p = Pose.stand
        faceYou(&p)
        happy(&p, t)
        p.tilt = odd ? 0.14 : -0.14
        p.tail = 0.7 + sin(t * 13) * 0.45
        p.hip.x += sin(t * 13) * 0.4
        return p
    }

    static func listen(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.stand
        faceYou(&p)
        let cocked = ease(t / 0.25) - 2 * ease((t - d / 2) / 0.3)
        p.tilt = 0.34 * cocked
        p.head.y += 1.2
        p.earLift = 1
        p.eyes = 1.2
        p.brow = 0.5
        p.tail = 0.55
        return p
    }

    static func pant(elapsed t: Double) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        breathe(&p, t, depth: 0.5, rate: 9)
        p.tongue = 1
        p.mouth = 0.7
        p.head.y += sin(t * 9) * 0.3
        p.eyes = 0.75
        return p
    }
}
