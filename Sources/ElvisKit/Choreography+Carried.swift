import CoreGraphics
import Foundation

extension Choreography {
    static func held(elapsed t: Double) -> Pose {
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
    }

    static func landed(elapsed t: Double) -> Pose {
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
    }
}
