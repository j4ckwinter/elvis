import CoreGraphics
import Foundation

extension Choreography {
    static func sit(elapsed t: Double) -> Pose {
        var p = Pose.sit
        breathe(&p, t, depth: 0.25, rate: 1.8)
        p.tail = -0.12 + 0.18 * abs(sin(t * 3.2))
        p.tongue = 0.5
        p.mouth = 0.3
        p.look = CGPoint(x: 0.3, y: 0)
        return p
    }

    static func lookAround(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func wagAtYou(elapsed t: Double) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        happy(&p, t)
        p.tail = -0.05 + 0.6 * abs(sin(t * 7.5))
        p.hip.x += sin(t * 15) * 0.5
        p.tilt = 0.08 * sin(t * 2.1)
        return p
    }

    static func scratch(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.sit
        let k = swell(t, d, attack: 0.3, release: 0.3)
        p.head = p.head.mixed(CGPoint(x: 8.5, y: 25), k)
        p.pitch = 0.2 * k
        p.paws[2] = p.paws[2].mixed(CGPoint(x: 4.5 + sin(t * 44) * 1.3, y: 19.5 + cos(t * 44) * 1.6), k)
        p.eyes = 1 - 0.7 * k
        p.earFling = sin(t * 44) * 0.5 * k
        p.shoulder.x += sin(t * 44) * 0.25 * k
        return p
    }

    static func sneeze(elapsed t: Double) -> Pose {
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
    }

    static func stretch(elapsed t: Double, length d: Double) -> Pose {
        let k = swell(t, d, attack: 0.5, release: 0.5)
        var p = Pose.stand.mixed(with: .bow, k)
        p.tail += 0.3 * sin(t * 9) * k
        p.mouth = 0.8 * swell(t, d, attack: 0.9, release: 0.7)
        p.eyes = 1 - 0.8 * k
        p.pitch = 0.25 * k
        return p
    }

    static func circle(elapsed t: Double, length d: Double) -> Pose {
        var p = gait(.walk, t)
        let angle = t / d * tau * 2
        p.turn = cos(angle)
        p.head.y -= 3
        p.pitch = -0.3
        return p.mixed(with: .lie, ease((t - d + 0.35) / 0.35))
    }

    static func chaseTail(elapsed t: Double) -> Pose {
        var p = gait(.trot, t * 1.4)
        p.turn = cos(t * tau * 2.3)
        p.head = CGPoint(x: 12.5, y: 21)
        p.pitch = -0.35
        p.mouth = 0.7
        p.tail = 0.4 + 0.4 * sin(t * 12)
        p.lift = abs(sin(t * 9)) * 1.5
        return p
    }

    static func dizzy(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.sit
        faceYou(&p)
        let k = 1 - ease(t / d)
        p.tilt = 0.3 * sin(t * 5.2) * k
        p.head.x += sin(t * 5.2) * 1.6 * k
        p.look = CGPoint(x: cos(t * 9), y: sin(t * 9)) * k
        p.tongue = 0.8
        p.mouth = 0.5
        return p
    }

    static func shake(elapsed t: Double, length d: Double) -> Pose {
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
    }

    static func petted(elapsed t: Double) -> Pose {
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
    }

    static func nudgeBall(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.noseDown
        p.head.x += 2.5 * sin(min(1, t / d) * .pi)
        p.tail = 0.9 + 0.3 * sin(t * 14)
        return p
    }
}
