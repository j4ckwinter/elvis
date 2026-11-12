import CoreGraphics
import Foundation

extension Choreography {
    static func go(_ style: Gait, elapsed t: Double, world: World) -> Pose {
        var p = gait(style, t)
        if world.glum > 0.3, style != .slink { droopEars(&p, world.glum) }
        if world.ball?.state == .carried, style == .prance {
            p.happyEyes = 0.6
        }
        return p
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
}
