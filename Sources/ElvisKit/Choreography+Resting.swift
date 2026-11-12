import CoreGraphics
import Foundation

extension Choreography {
    static func sleepTwitch(elapsed t: Double, length d: Double) -> Pose {
        var p = asleep(t)
        let burst = max(0, sin(t * 2.6)) * swell(t, d)
        p.paws[0].x += sin(t * 31) * 1.1 * burst
        p.paws[1].x += sin(t * 27 + 1) * 0.9 * burst
        p.paws[2].x += sin(t * 29 + 2) * 0.8 * burst
        p.earFling = sin(t * 24) * 0.25 * max(0, sin(t * 1.7 + 2))
        return p
    }

    static func dream(elapsed t: Double, length d: Double) -> Pose {
        var p = asleep(t)
        let run = swell(t, d, attack: 0.8, release: 0.8)
        for i in 0..<4 {
            p.paws[i].x += sin(t * 11 + Double(i) * 1.9) * 1.7 * run
            p.paws[i].y += max(0, sin(t * 11 + Double(i) * 1.9 + 1)) * 0.9 * run
        }
        p.tail += max(0, sin(t * 6)) * 0.35 * run
        p.mouth = max(0, sin(t * 4.2)) > 0.92 ? 0.25 : 0
        return p
    }

    static func sleepSigh(elapsed t: Double, length d: Double) -> Pose {
        var p = asleep(t)
        let breath = swell(t, d, attack: 0.9, release: 1.1) * 1.3
        p.shoulder.y += breath
        p.hip.y += breath * 0.6
        return p
    }

    static func sleepWag(elapsed t: Double, length d: Double) -> Pose {
        var p = asleep(t)
        p.tail = -0.1 + abs(sin(t * 5.5)) * 0.55 * swell(t, d)
        return p
    }

    static func doze(elapsed t: Double) -> Pose {
        var p = Pose.chinDown
        breathe(&p, t, depth: 0.35, rate: 1.3)
        p.eyes = 0.12 + 0.4 * max(0, sin(t * 0.55 + 0.4))
        p.look = CGPoint(x: 0.2, y: 0.5)
        p.earFling = sin(t * 26) * 0.2 * max(0, sin(t * 0.9 + 4) - 0.9) * 10
        return p
    }

    static func rest(elapsed t: Double) -> Pose {
        var p = Pose.lie
        breathe(&p, t, depth: 0.3, rate: 1.6)
        p.pitch = 0.05 + 0.08 * sin(t * 0.5)
        p.look = CGPoint(x: sin(t * 0.45), y: 0.1)
        p.tongue = 0.35
        p.mouth = 0.25
        p.tail = -0.1 + max(0, sin(t * 0.8)) * 0.12 * abs(sin(t * 5))
        return p
    }

    static func sigh(elapsed t: Double, length d: Double) -> Pose {
        let down = swell(t, d, attack: 0.6, release: 0.6)
        var p = Pose.lie.mixed(with: .chinDown, down)
        let breath = sin(min(1, t / d) * .pi) * 1.1
        p.shoulder.y += breath
        p.eyes = 1 - 0.6 * down
        p.brow = -0.4 * down
        return p
    }

    static func earFlap(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.lie
        let k = swell(t, d, attack: 0.1, release: 0.3)
        p.earFling = sin(t * 34) * 1.25 * k
        p.pitch = sin(t * 34) * 0.07 * k
        p.eyes = 1 - 0.9 * k
        return p
    }

    static func yawn(elapsed t: Double, length d: Double) -> Pose {
        var p = Pose.lie
        let k = swell(t, d, attack: 0.7, release: 0.5)
        p.pitch = 0.42 * k
        p.head.y += 2 * k
        p.mouth = k
        p.tongue = 0.5 * k
        p.eyes = 1 - k
        return p
    }
}
