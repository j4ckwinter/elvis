import CoreGraphics
import Foundation

public enum Painter {
    public static let groundMargin = 6.0

    public static func draw(_ frame: Frame, in ctx: CGContext, unit: Double) {
        ctx.saveGState()
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: 0, y: groundMargin)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        if frame.doorAlpha > 0.01 { drawDoor(ctx, alpha: frame.doorAlpha) }
        drawShadow(ctx, frame)
        if let target = frame.trailTo { drawTrail(ctx, from: frame.x, to: target, time: frame.time) }
        if let ball = frame.ball, ball.state != .carried { drawBall(ctx, at: CGPoint(x: ball.x, y: ball.y + 3), spin: ball.spin) }

        ctx.saveGState()
        ctx.translateBy(x: frame.x, y: frame.pose.lift)
        ctx.rotate(by: frame.pose.lean * (frame.facing >= 0 ? 1 : -1))
        ctx.scaleBy(x: frame.facing, y: 1)
        Dog(pose: frame.pose, ears: frame.ears, mud: frame.mud, carrying: frame.ball?.state == .carried).draw(ctx)
        ctx.restoreGState()

        drawExtras(ctx, frame)
        for particle in frame.particles where particle.age >= 0 { draw(particle, ctx) }
        ctx.restoreGState()
    }

    public static func bounds(of frame: Frame) -> CGRect {
        var area = CGRect(x: frame.x - 40, y: -groundMargin, width: 80, height: groundMargin + 52 + max(0, frame.pose.lift))
        if frame.action == .held {
            area = area.insetBy(dx: -14, dy: 0)
            area.size.height += 20
        }
        if let ball = frame.ball, ball.state != .carried {
            area = area.union(CGRect(x: ball.x - 4.5, y: ball.y - 1.5, width: 9, height: 9))
        }
        if frame.doorAlpha > 0.01 {
            area = area.union(CGRect(x: Yard.door - 13, y: -4.5, width: 28, height: 51))
        }
        if let target = frame.trailTo {
            area = area.union(CGRect(x: min(frame.x, target) - 5, y: -1, width: abs(target - frame.x) + 10, height: 6))
        }
        for particle in frame.particles where particle.age >= 0 {
            let reach = particle.size * 2.2 + 2.5
            area = area.union(CGRect(x: particle.x - reach, y: particle.y - reach, width: reach * 2, height: reach * 2))
        }
        return area
    }

    public static func body(of frame: Frame) -> CGRect {
        let pose = frame.pose
        let xs = pose.paws.map(\.x) + [pose.hip.x - 7, pose.shoulder.x + 7, pose.head.x - 8, pose.head.x + 8]
        let reach = abs(frame.facing)
        let low = (xs.min() ?? -12) * reach, high = (xs.max() ?? 12) * reach
        let left = frame.facing >= 0 ? frame.x + low : frame.x - high
        let top = max(pose.head.y + 8, pose.shoulder.y + 7, pose.hip.y + 7) + pose.lift
        return CGRect(x: left, y: -1, width: high - low, height: top + 1)
    }
}
