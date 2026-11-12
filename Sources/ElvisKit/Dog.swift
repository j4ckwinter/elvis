import CoreGraphics
import Foundation

struct Dog {
    var pose: Pose
    var ears: [Double]
    var mud: Double
    var carrying: Bool

    enum Item {
        case coat(CGPath, CGColor)
        case limb(CGPoint, CGPoint, Double, CGColor)
        case disc(CGPoint, Double, Double, CGColor)
        case fill(CGPath, CGColor)
        case stroke(CGPath, CGColor, Double)
        case ball(CGPoint)
    }

    typealias Coat = Painter.Coat
    private static let boneLength = 8.6

    func draw(_ ctx: CGContext) {
        var items: [Item] = []
        build(&items)

        let rim = 0.75
        ctx.setStrokeColor(Coat.rim)
        ctx.setFillColor(Coat.rim)
        for item in items {
            switch item {
            case .coat(let path, _):
                ctx.addPath(path)
                ctx.setLineWidth(rim * 2)
                ctx.strokePath()
            case .limb(let a, let b, let width, _):
                ctx.move(to: a)
                ctx.addLine(to: b)
                ctx.setLineWidth(width + rim * 2)
                ctx.strokePath()
            case .disc(let centre, let rx, let ry, _):
                ctx.fillEllipse(in: CGRect(x: centre.x - rx - rim, y: centre.y - ry - rim, width: (rx + rim) * 2, height: (ry + rim) * 2))
            case .fill, .stroke, .ball:
                break
            }
        }

        for item in items {
            switch item {
            case .coat(let path, let colour), .fill(let path, let colour):
                ctx.addPath(path)
                ctx.setFillColor(colour)
                ctx.fillPath()
            case .limb(let a, let b, let width, let colour):
                ctx.move(to: a)
                ctx.addLine(to: b)
                ctx.setStrokeColor(colour)
                ctx.setLineWidth(width)
                ctx.strokePath()
            case .disc(let centre, let rx, let ry, let colour):
                ctx.setFillColor(colour)
                ctx.fillEllipse(in: CGRect(x: centre.x - rx, y: centre.y - ry, width: rx * 2, height: ry * 2))
            case .stroke(let path, let colour, let width):
                ctx.addPath(path)
                ctx.setStrokeColor(colour)
                ctx.setLineWidth(width)
                ctx.strokePath()
            case .ball(let centre):
                Painter.drawBall(ctx, at: centre, spin: 0.6)
            }
        }
    }

    private func build(_ items: inout [Item]) {
        let p = pose
        let frontJoint = p.shoulder + CGPoint(x: 0.5, y: -3.5)
        let rearJoint = p.hip + CGPoint(x: -0.5, y: -2.5)
        let spine = p.shoulder - p.hip
        let bodyAngle = atan2(spine.y, spine.x)
        let up = CGPoint(x: -sin(bodyAngle), y: cos(bodyAngle))

        leg(&items, joint: frontJoint + CGPoint(x: -1.2, y: 0), paw: p.paws[1], bend: -1, colour: Coat.far)
        leg(&items, joint: rearJoint + CGPoint(x: 1.2, y: 0), paw: p.paws[3], bend: p.rearBend, colour: Coat.far)
        tail(&items, base: p.hip + CGPoint(x: -4.8, y: 2.4).rotated(bodyAngle))

        items.append(.limb(p.hip, p.shoulder, 12.0, Coat.body))
        items.append(.disc(p.hip, 6.3, 6.3, Coat.body))
        items.append(.disc(p.shoulder, 6.9, 6.9, Coat.body))
        chestFluff(&items, at: p.shoulder, bodyAngle: bodyAngle)

        let sheen = CGMutablePath()
        sheen.move(to: p.hip + up * 4.4 + CGPoint(x: 1.5, y: 0))
        sheen.addQuadCurve(to: p.shoulder + up * 4.8 + CGPoint(x: -3, y: 0), control: (p.hip + p.shoulder) * 0.5 + up * 5.4)
        items.append(.stroke(sheen, Coat.sheen, 0.7))

        let nearFront = leg(&items, joint: frontJoint, paw: p.paws[0], bend: -1, colour: Coat.body, feathered: true)
        let nearRear = leg(&items, joint: rearJoint, paw: p.paws[2], bend: p.rearBend, colour: Coat.body)
        mudOnBody(&items, up: up, ankles: [nearFront, nearRear])

        if p.front > 0.5 {
            frontHead(&items)
        } else {
            profileHead(&items)
        }
    }

    @discardableResult
    private func leg(_ items: inout [Item], joint: CGPoint, paw: CGPoint, bend: Double, colour: CGColor, feathered: Bool = false) -> CGPoint {
        let knee = Dog.knee(joint: joint, paw: paw, bend: bend)
        let ankle = paw + CGPoint(x: 0, y: 1.3)
        items.append(.limb(joint, knee, 4.8, colour))
        items.append(.limb(knee, ankle, 3.3, colour))
        if feathered {
            let along = ankle - knee
            let length = max(along.length, 0.01)
            let back = CGPoint(x: -abs(along.y) / length, y: -abs(along.x) / length * 0.2)
            let fringe = CGMutablePath()
            fringe.move(to: knee + along * 0.05)
            fringe.addQuadCurve(to: knee + along * 0.45 + back * 2.4, control: knee + along * 0.2 + back * 3.8)
            fringe.addQuadCurve(to: knee + along * 0.8 + back * 1.4, control: knee + along * 0.62 + back * 3.6)
            fringe.addLine(to: knee + along * 0.85)
            fringe.closeSubpath()
            items.append(.coat(fringe, colour))
        }
        let sideways = abs(paw.x - knee.x) > abs(paw.y - knee.y) * 1.5
        let forward = sideways && paw.x < knee.x ? -1.0 : 1.0
        let centre = paw + CGPoint(x: forward * 1.1, y: 1.3)
        items.append(.disc(centre, 2.7, 1.6, colour))
        if mud > 0.08 {
            let amount = min(1, (mud - 0.08) * 6)
            items.append(.fill(Dog.ellipse(centre + CGPoint(x: 0, y: -0.4), 2.5, 1.0), Painter.rgb(0x8E6E45, amount)))
        }
        return ankle
    }

    private func tail(_ items: inout [Item], base: CGPoint) {
        let a = pose.tail
        let frame = CGAffineTransform(a: -cos(a), b: sin(a), c: sin(a), d: cos(a), tx: base.x, ty: base.y)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1, y: 1.6), transform: frame)
        path.addQuadCurve(to: CGPoint(x: 13, y: 1.0), control: CGPoint(x: 6.5, y: 3.0), transform: frame)
        path.addQuadCurve(to: CGPoint(x: 11.4, y: -2.6), control: CGPoint(x: 14.0, y: -1.4), transform: frame)
        path.addQuadCurve(to: CGPoint(x: 8.6, y: -2.3), control: CGPoint(x: 9.9, y: -3.9), transform: frame)
        path.addQuadCurve(to: CGPoint(x: 5.9, y: -3.6), control: CGPoint(x: 7.3, y: -4.7), transform: frame)
        path.addQuadCurve(to: CGPoint(x: 3.2, y: -2.9), control: CGPoint(x: 4.5, y: -4.6), transform: frame)
        path.addQuadCurve(to: CGPoint(x: -1, y: -2.0), control: CGPoint(x: 1.2, y: -3.8), transform: frame)
        path.closeSubpath()
        items.append(.coat(path, Coat.body))
        let shine = CGMutablePath()
        shine.move(to: CGPoint(x: 2, y: 1.0), transform: frame)
        shine.addQuadCurve(to: CGPoint(x: 10.5, y: 0.6), control: CGPoint(x: 6.5, y: 2.0), transform: frame)
        items.append(.stroke(shine, Coat.sheen, 0.6))
    }

    private func chestFluff(_ items: inout [Item], at shoulder: CGPoint, bodyAngle: Double) {
        let frame = CGAffineTransform(translationX: shoulder.x, y: shoulder.y).rotated(by: bodyAngle * 0.6)
        let fluff = CGMutablePath()
        fluff.move(to: CGPoint(x: 6.6, y: 1.5), transform: frame)
        fluff.addQuadCurve(to: CGPoint(x: 6.6, y: -3.2), control: CGPoint(x: 9.2, y: -1.2), transform: frame)
        fluff.addQuadCurve(to: CGPoint(x: 4.2, y: -6.6), control: CGPoint(x: 7.4, y: -6.2), transform: frame)
        fluff.addQuadCurve(to: CGPoint(x: 0.5, y: -7.8), control: CGPoint(x: 3.0, y: -9.2), transform: frame)
        fluff.addLine(to: CGPoint(x: 0, y: 0), transform: frame)
        fluff.closeSubpath()
        items.append(.coat(fluff, Coat.body))
    }

    private func mudOnBody(_ items: inout [Item], up: CGPoint, ankles: [CGPoint]) {
        func splat(_ centre: CGPoint, _ radius: Double, from threshold: Double, dry: Bool = false) {
            guard mud > threshold else { return }
            let amount = min(1, (mud - threshold) * 5)
            items.append(.fill(Dog.ellipse(centre, radius, radius * 0.8), Painter.rgb(dry ? 0xAD9165 : 0x8E6E45, amount)))
        }
        for ankle in ankles {
            splat(ankle + CGPoint(x: 0.3, y: 2.4), 1.25, from: 0.25)
            splat(ankle + CGPoint(x: -0.5, y: 4.8), 0.8, from: 0.32, dry: true)
        }
        let belly = [0.25, 0.5, 0.78].map { pose.hip.mixed(pose.shoulder, $0) - up * 5.4 }
        splat(belly[0], 1.7, from: 0.45)
        splat(belly[1], 1.2, from: 0.5, dry: true)
        splat(belly[2], 1.5, from: 0.55)
        let flank = pose.hip.mixed(pose.shoulder, 0.4)
        splat(flank + up * 1.0, 1.1, from: 0.7)
        splat(flank + CGPoint(x: 4, y: -1.5), 0.8, from: 0.76, dry: true)
        splat(flank + CGPoint(x: -4.5, y: 0.5), 0.7, from: 0.82)
    }

    static func knee(joint: CGPoint, paw: CGPoint, bend: Double) -> CGPoint {
        let reach = paw - joint
        let distance = reach.length
        let middle = joint + reach * 0.5
        guard distance > 0.01, distance < boneLength * 2 else { return middle }
        let height = (boneLength * boneLength - distance * distance / 4).squareRoot()
        let backward = CGPoint(x: reach.y / distance, y: -reach.x / distance)
        var knee = middle + backward * (height * -bend)
        knee.y = max(knee.y, 1.0)
        return knee
    }

    static func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        return path
    }

    static func circle(_ centre: CGPoint, _ radius: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    static func ellipse(_ centre: CGPoint, _ rx: Double, _ ry: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: centre.x - rx, y: centre.y - ry, width: rx * 2, height: ry * 2), transform: nil)
    }
}
