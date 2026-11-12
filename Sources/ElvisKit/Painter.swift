import CoreGraphics
import Foundation

/// Draws a frame. The context's origin is the yard's bottom-left corner with y pointing up, in points.
public enum Painter {
    /// Space below ground level, in dog units, for shadows and trailing ears.
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

    /// The part of the yard this frame touches, in dog units with the ground at y = 0. Everything `draw` paints
    /// lies inside it, so a caller can repaint only this patch.
    public static func bounds(of frame: Frame) -> CGRect {
        var area = CGRect(x: frame.x - 40, y: -groundMargin, width: 80, height: groundMargin + 52 + max(0, frame.pose.lift))
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

    static func rgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
        CGColor(
            srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
    }

    enum Coat {
        static let body = rgb(0x18181D)
        static let far = rgb(0x0E0E12)
        static let ear = rgb(0x2A2220)
        static let earEdge = rgb(0x4E413D)
        static let curl = rgb(0x5E4B44)
        static let sheen = rgb(0x30323D)
        static let muzzle = rgb(0x25252D)
        static let nose = rgb(0x3B3B46)
        static let noseShine = rgb(0x9A9AA8)
        static let line = rgb(0x5C5C6A)
        static let lid = rgb(0x8B8B99)
        static let amber = rgb(0xE0872A)
        static let amberDeep = rgb(0xA8581A)
        static let pupil = rgb(0x0A0A0C)
        static let tongue = rgb(0xF27F95)
        static let tongueLine = rgb(0xD45E78)
        static let mouth = rgb(0x4A1822)
        static let mud = rgb(0x8E6E45)
        static let mudDry = rgb(0xAD9165)
        static let rim = rgb(0x8E8F96)
    }

    private static func drawShadow(_ ctx: CGContext, _ frame: Frame) {
        let pose = frame.pose
        let xs = pose.paws.map(\.x) + [pose.hip.x - 6, pose.shoulder.x + 6]
        let low = (xs.min() ?? -12) * abs(frame.facing), high = (xs.max() ?? 12) * abs(frame.facing)
        let fade = max(0.25, 1 - pose.lift / 16)
        let left = frame.facing >= 0 ? frame.x + low : frame.x - high
        ctx.setFillColor(rgb(0x000000, 0.2 * fade))
        ctx.fillEllipse(in: CGRect(x: left - 2, y: -1.8, width: (high - low) + 4, height: 3.6))
    }

    private static func drawTrail(_ ctx: CGContext, from: Double, to: Double, time: Double) {
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

    private static func drawDoor(_ ctx: CGContext, alpha: Double) {
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

    private static func drawExtras(_ ctx: CGContext, _ frame: Frame) {
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

    private static func draw(_ p: Particle, _ ctx: CGContext) {
        let life = p.age / p.life
        let alpha = min(1, min(life * 6, (1 - life) * 2.5))
        let at = CGPoint(x: p.x, y: p.y)
        switch p.kind {
        case .zzz:
            let s = p.size * (0.7 + life * 0.8)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: at.x, y: at.y + s))
            path.addLine(to: CGPoint(x: at.x + s, y: at.y + s))
            path.addLine(to: at)
            path.addLine(to: CGPoint(x: at.x + s, y: at.y))
            outlined(ctx, path, colour: rgb(0xFFFFFF, alpha), width: 0.6, alpha: alpha)
        case .heart:
            sticker(ctx, heart(at: at, size: p.size * (0.6 + min(1, life * 3) * 0.4)), fill: rgb(0xFF6B8B, alpha), alpha: alpha)
        case .drop:
            ctx.setFillColor(p.muddy ? rgb(0x9A7A4E, alpha) : rgb(0xBFE3F5, alpha))
            ctx.fillEllipse(in: CGRect(x: at.x - p.size, y: at.y - p.size, width: p.size * 2, height: p.size * 2))
        case .dirt:
            ctx.setFillColor(rgb(0x8A6A42, alpha))
            ctx.fillEllipse(in: CGRect(x: at.x - p.size, y: at.y - p.size, width: p.size * 2, height: p.size * 2))
        case .puff:
            ctx.setFillColor(rgb(0xE8E8EE, alpha * 0.55))
            ctx.fillEllipse(in: CGRect(x: at.x - p.size, y: at.y - p.size, width: p.size * 2, height: p.size * 2))
        case .whine:
            let path = CGMutablePath()
            let s = p.size
            path.move(to: at)
            path.addCurve(to: CGPoint(x: at.x + s * 1.6, y: at.y), control1: CGPoint(x: at.x + s * 0.4, y: at.y + s * 0.9), control2: CGPoint(x: at.x + s * 1.2, y: at.y - s * 0.9))
            outlined(ctx, path, colour: rgb(0xBFD9FF, alpha), width: 0.6, alpha: alpha)
        case .bang:
            let s = p.size
            let path = CGMutablePath()
            path.move(to: CGPoint(x: at.x, y: at.y + s))
            path.addLine(to: CGPoint(x: at.x, y: at.y + s * 0.35))
            path.move(to: CGPoint(x: at.x, y: at.y))
            path.addLine(to: CGPoint(x: at.x, y: at.y + 0.01))
            outlined(ctx, path, colour: rgb(0xFFD23F, alpha), width: 1.0, alpha: alpha)
        case .query:
            let s = p.size
            let path = CGMutablePath()
            path.move(to: CGPoint(x: at.x - s * 0.3, y: at.y + s * 0.85))
            path.addCurve(to: CGPoint(x: at.x, y: at.y + s * 0.35), control1: CGPoint(x: at.x - s * 0.1, y: at.y + s * 1.25), control2: CGPoint(x: at.x + s * 0.7, y: at.y + s * 0.8))
            path.move(to: CGPoint(x: at.x, y: at.y))
            path.addLine(to: CGPoint(x: at.x, y: at.y + 0.01))
            outlined(ctx, path, colour: rgb(0xFFD23F, alpha), width: 0.9, alpha: alpha)
        }
    }

    private static func sticker(_ ctx: CGContext, _ path: CGPath, fill: CGColor, alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0x000000, 0.4 * alpha))
        ctx.setLineWidth(0.9)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setFillColor(fill)
        ctx.fillPath()
    }

    private static func outlined(_ ctx: CGContext, _ path: CGPath, colour: CGColor, width: Double, alpha: Double) {
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0x000000, 0.45 * alpha))
        ctx.setLineWidth(width + 0.8)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(colour)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }

    private static func heart(at c: CGPoint, size s: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: c.x, y: c.y - s * 0.8))
        path.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.5), control1: CGPoint(x: c.x - s * 1.7, y: c.y + s * 0.3), control2: CGPoint(x: c.x - s * 0.7, y: c.y + s * 1.4))
        path.addCurve(to: CGPoint(x: c.x, y: c.y - s * 0.8), control1: CGPoint(x: c.x + s * 0.7, y: c.y + s * 1.4), control2: CGPoint(x: c.x + s * 1.7, y: c.y + s * 0.3))
        path.closeSubpath()
        return path
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
