import CoreGraphics
import Foundation

extension Painter {
    static func drawShadow(_ ctx: CGContext, _ frame: Frame) {
        if frame.action == .held { return }
        let pose = frame.pose
        let xs = pose.paws.map(\.x) + [pose.hip.x - 6, pose.shoulder.x + 6]
        let low = (xs.min() ?? -12) * abs(frame.facing), high = (xs.max() ?? 12) * abs(frame.facing)
        let fade = max(0.25, 1 - pose.lift / 16)
        let left = frame.facing >= 0 ? frame.x + low : frame.x - high
        ctx.setFillColor(rgb(0x000000, 0.2 * fade))
        ctx.fillEllipse(in: CGRect(x: left - 2, y: -1.8, width: (high - low) + 4, height: 3.6))
    }

    static func drawTrail(_ ctx: CGContext, from: Double, to: Double, time: Double) {
        let direction = to > from ? 1.0 : -1.0
        var x = from + direction * 26
        var index = 0
        while (to - x) * direction > -4 {
            let wobble = sin(x * 0.35) * 1.4
            let pulse = 0.35 + 0.25 * sin(time * 4 - Double(index) * 0.9)
            ctx.setFillColor(rgb(0xB9E8A0, pulse))
            ctx.fillEllipse(in: CGRect(x: x - 0.7, y: 1.2 + wobble, width: 1.4, height: 1.4))
            x += direction * 6
            index += 1
        }
    }

    static func drawBall(_ ctx: CGContext, at centre: CGPoint, spin: Double) {
        let r = 3.0
        ctx.saveGState()
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.setFillColor(rgb(0x000000, 0.35))
        ctx.fillEllipse(in: CGRect(x: -r - 0.4, y: -r - 0.4, width: 2 * r + 0.8, height: 2 * r + 0.8))
        ctx.setFillColor(rgb(0xD2E34B))
        ctx.fillEllipse(in: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
        ctx.rotate(by: -spin)
        ctx.addEllipse(in: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
        ctx.clip()
        ctx.setStrokeColor(rgb(0xFBFBF0))
        ctx.setLineWidth(0.55)
        ctx.addArc(center: CGPoint(x: -3.6, y: 0), radius: 3.1, startAngle: -1.1, endAngle: 1.1, clockwise: false)
        ctx.strokePath()
        ctx.addArc(center: CGPoint(x: 3.6, y: 0), radius: 3.1, startAngle: .pi - 1.1, endAngle: .pi + 1.1, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func drawDoor(_ ctx: CGContext, alpha: Double) {
        let x = Yard.door - 11.0, width = 24.0, height = 44.0
        func arch(inset: Double) -> CGPath {
            let path = CGMutablePath()
            let left = x + inset, right = x + width - inset, top = height - inset
            let radius = (right - left) / 2
            path.move(to: CGPoint(x: left, y: 0))
            path.addLine(to: CGPoint(x: left, y: top - radius))
            path.addArc(center: CGPoint(x: left + radius, y: top - radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: right, y: 0))
            path.closeSubpath()
            return path
        }
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.translateBy(x: 0, y: -(1 - alpha) * 3)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.addPath(arch(inset: -0.7))
        ctx.setFillColor(rgb(0xFFFFFF, 0.55))
        ctx.fillPath()
        ctx.addPath(arch(inset: 0))
        ctx.setFillColor(rgb(0x5E3F26))
        ctx.fillPath()
        ctx.addPath(arch(inset: 2))
        ctx.setFillColor(rgb(0xB07A42))
        ctx.fillPath()
        ctx.setFillColor(rgb(0x94612F))
        ctx.fill(CGRect(x: x + 4.5, y: 3, width: 15, height: 12))
        ctx.setFillColor(rgb(0xFFE7A0))
        ctx.addArc(center: CGPoint(x: x + 12, y: 31), radius: 5.5, startAngle: 0, endAngle: .pi, clockwise: false)
        ctx.closePath()
        ctx.fillPath()
        ctx.setStrokeColor(rgb(0x5E3F26))
        ctx.setLineWidth(0.8)
        ctx.move(to: CGPoint(x: x + 12, y: 31))
        ctx.addLine(to: CGPoint(x: x + 12, y: 36.5))
        ctx.strokePath()
        ctx.setFillColor(rgb(0xF0C64F))
        ctx.fillEllipse(in: CGRect(x: x + 4, y: 19, width: 2.8, height: 2.8))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    static func drawExtras(_ ctx: CGContext, _ frame: Frame) {
        let side = frame.facing >= 0 ? 1.0 : -1.0
        let head = CGPoint(x: frame.x + frame.facing * frame.pose.head.x, y: frame.pose.head.y + frame.pose.lift)
        switch frame.action {
        case .dream:
            let show = min(ease(frame.elapsed / 0.6), ease((5.2 - frame.elapsed) / 0.6))
            guard show > 0.01 else { return }
            ctx.saveGState()
            ctx.setAlpha(show)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            let bubble = CGPoint(x: head.x - side * 4, y: head.y + 22 + sin(frame.time * 1.5) * 0.6)
            for (offset, radius) in [(CGPoint(x: -side * 1, y: 7), 1.0), (CGPoint(x: -side * 2.2, y: 11), 1.6)] {
                sticker(ctx, CGPath(ellipseIn: CGRect(x: head.x + offset.x - radius, y: head.y + offset.y - radius, width: radius * 2, height: radius * 2), transform: nil), fill: rgb(0xFFFFFF, 0.95))
            }
            sticker(ctx, CGPath(ellipseIn: CGRect(x: bubble.x - 8.5, y: bubble.y - 6.5, width: 17, height: 13), transform: nil), fill: rgb(0xFFFFFF, 0.95))
            drawBall(ctx, at: CGPoint(x: bubble.x + sin(frame.time * 5) * 2.5, y: bubble.y + abs(sin(frame.time * 5)) * 2 - 1), spin: frame.time * 6)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        case .dizzy:
            let fade = 1 - ease(frame.elapsed / 1.5)
            for i in 0..<3 {
                let angle = frame.time * 7 + Double(i) * 2.1
                let centre = CGPoint(x: head.x + cos(angle) * 8, y: head.y + 9 + sin(angle) * 2)
                sticker(ctx, star(at: centre, size: 1.5), fill: rgb(0xFFE066, fade))
            }
        default:
            break
        }
    }

    static func sticker(_ ctx: CGContext, _ path: CGPath, fill: CGColor, alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0x000000, 0.4 * alpha))
        ctx.setLineWidth(0.9)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setFillColor(fill)
        ctx.fillPath()
    }

    private static func star(at c: CGPoint, size s: Double) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<8 {
            let radius = i % 2 == 0 ? s : s * 0.42
            let angle = Double(i) * .pi / 4
            let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
