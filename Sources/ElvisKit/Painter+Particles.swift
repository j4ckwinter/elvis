import CoreGraphics

extension Painter {
    static func draw(_ p: Particle, _ ctx: CGContext) {
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
        case .woof:
            let towards = p.vx >= 0 ? 0.0 : Double.pi
            let path = CGMutablePath()
            for ring in [1.0, 1.6] {
                let radius = p.size * (0.4 + life * 0.9) * ring
                path.move(to: CGPoint(x: at.x + cos(towards - 0.6) * radius, y: at.y + sin(towards - 0.6) * radius))
                path.addArc(center: at, radius: radius, startAngle: towards - 0.6, endAngle: towards + 0.6, clockwise: false)
            }
            outlined(ctx, path, colour: rgb(0xFFD23F, alpha), width: 0.7, alpha: alpha)
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
}
