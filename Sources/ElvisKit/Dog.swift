import CoreGraphics
import Foundation

/// Elvis himself: a black sprocker drawn from a pose, facing right, in dog units.
struct Dog {
    var pose: Pose
    var ears: [Double]
    var mud: Double
    var carrying: Bool

    /// The silhouette cases get the pale rim that keeps a black dog visible on a dark desktop. Limbs and discs
    /// are kept as primitives because stroking a line is far cheaper than outlining and filling its shape.
    private enum Item {
        case coat(CGPath, CGColor)
        case limb(CGPoint, CGPoint, Double, CGColor)
        case disc(CGPoint, Double, Double, CGColor)
        case fill(CGPath, CGColor)
        case stroke(CGPath, CGColor, Double)
        case ball(CGPoint)
    }

    private typealias Coat = Painter.Coat
    private static let earLength = 14.2
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

    private func profileHead(_ items: inout [Item]) {
        let p = pose
        let head = CGAffineTransform(translationX: p.head.x, y: p.head.y).rotated(by: p.pitch)
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y).applying(head) }

        items.append(.limb(p.shoulder + CGPoint(x: 1.5, y: 2.5), at(-2, -2), 7.8, Coat.body))

        if p.tongue > 0.05 {
            let tip = at(8.8, -3.8 - 4.4 * p.tongue)
            items.append(.stroke(Dog.line(at(8.0, -3.6), tip), Coat.tongue, 2.3))
        }
        if p.mouth > 0.08 {
            let chin = at(8.6, -4.0 - 2.8 * p.mouth)
            let inside = CGMutablePath()
            inside.move(to: at(4.8, -3.4))
            inside.addLine(to: at(9.8, -3.8))
            inside.addLine(to: chin)
            inside.closeSubpath()
            items.append(.limb(at(4.2, -3.8), chin, 2.4, Coat.body))
            items.append(.fill(inside, Coat.mouth))
        }
        if carrying { items.append(.ball(at(10.4, -4.6))) }

        items.append(.disc(p.head, 6.2, 6.2, Coat.body))
        items.append(.limb(at(3.2, -1.9), at(8.2, -2.2), 6.0, Coat.body))
        topknot(&items, head)
        items.append(.fill(Dog.ellipse(at(10.6, -0.3), 1.6, 1.4), Coat.nose))
        items.append(.fill(Dog.ellipse(at(10.4, 0.3), 0.5, 0.3), Coat.noseShine))
        if p.mouth <= 0.08 {
            let line = CGMutablePath()
            line.move(to: at(11.0, -3.4))
            line.addQuadCurve(to: at(5.6, -3.6), control: at(8.4, -4.5))
            items.append(.stroke(line, Coat.line, 0.45))
        }
        eye(&items, at(3.2, 1.3), radius: 1.4, look: p.look.rotated(p.pitch))
        if abs(p.brow) > 0.2 {
            let brow = CGMutablePath()
            brow.move(to: at(1.6, 3.2 + 0.2 * p.brow))
            brow.addLine(to: at(4.6, 3.3 + 0.9 * p.brow))
            items.append(.stroke(brow, Coat.line, 0.5))
        }
        let shine = CGMutablePath()
        shine.move(to: at(-3.6, 4.2))
        shine.addQuadCurve(to: at(1.0, 5.6), control: at(-1.6, 5.9))
        items.append(.stroke(shine, Coat.sheen, 0.7))

        let root = at(-3.4, 2.0 + 1.3 * p.earLift - 0.8 * p.earDroop)
        ear(&items, root: root, angle: ears[0] + 0.18 * p.earLift, mirrored: false)
    }

    private func frontHead(_ items: inout [Item]) {
        let p = pose
        let head = CGAffineTransform(translationX: p.head.x, y: p.head.y).rotated(by: p.tilt)
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y).applying(head) }
        func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> CGPath {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2), transform: head)
            return path
        }

        items.append(.limb(p.shoulder + CGPoint(x: 0.5, y: 3), at(0, -3), 8.2, Coat.body))
        items.append(.coat(ellipse(0, 0, 7.0, 6.4), Coat.body))
        topknot(&items, head)

        let splay = 0.1 + 0.25 * p.earLift - 0.08 * p.earDroop
        let rootY = 2.2 + 1.2 * p.earLift - 0.9 * p.earDroop
        ear(&items, root: at(-5.6, rootY), angle: ears[1] - splay, mirrored: true)
        ear(&items, root: at(5.6, rootY), angle: ears[0] + splay, mirrored: false)

        items.append(.fill(ellipse(0, -2.7, 4.0, 3.1), Coat.muzzle))
        if p.mouth > 0.1 {
            items.append(.fill(ellipse(0, -4.4, 1.8, 0.5 + 1.2 * p.mouth), Coat.mouth))
        }
        if p.tongue > 0.05 {
            let tip = at(0, -4.2 - 3.8 * p.tongue)
            items.append(.stroke(Dog.line(at(0, -4.0), tip), Coat.tongue, 2.6))
            items.append(.stroke(Dog.line(at(0, -4.2), at(0, -4.0 - 2.6 * p.tongue)), Coat.tongueLine, 0.3))
        }
        items.append(.fill(ellipse(0, -1.5, 1.8, 1.3), Coat.nose))
        items.append(.fill(ellipse(-0.5, -1.1, 0.55, 0.3), Coat.noseShine))
        let lips = CGMutablePath()
        lips.move(to: at(-2.0, -3.6))
        lips.addQuadCurve(to: at(0, -2.8), control: at(-0.7, -4.1))
        lips.addQuadCurve(to: at(2.0, -3.6), control: at(0.7, -4.1))
        items.append(.stroke(lips, Coat.line, 0.45))

        let look = p.look.rotated(p.tilt)
        eye(&items, at(-3.0, 1.4), radius: 1.55, look: look)
        eye(&items, at(3.0, 1.4), radius: 1.55, look: look)
        if abs(p.brow) > 0.2 {
            for side in [-1.0, 1.0] {
                let inner = at(side * 1.7, 3.7 + max(0, -p.brow) * 1.0 + max(0, p.brow) * 0.3)
                let outer = at(side * 4.3, 3.6 + max(0, p.brow) * 0.5 - max(0, -p.brow) * 0.3)
                items.append(.stroke(Dog.line(inner, outer), Coat.line, 0.5))
            }
        }
    }

    private func topknot(_ items: inout [Item], _ head: CGAffineTransform) {
        let tuft = CGMutablePath()
        tuft.move(to: CGPoint(x: -3.2, y: 4.6), transform: head)
        tuft.addCurve(to: CGPoint(x: -1.6, y: 7.2), control1: CGPoint(x: -3.6, y: 6.2), control2: CGPoint(x: -3.0, y: 7.6), transform: head)
        tuft.addCurve(to: CGPoint(x: 0.3, y: 7.9), control1: CGPoint(x: -1.4, y: 8.2), control2: CGPoint(x: -0.3, y: 8.6), transform: head)
        tuft.addCurve(to: CGPoint(x: 2.0, y: 7.0), control1: CGPoint(x: 1.0, y: 8.4), control2: CGPoint(x: 1.9, y: 7.9), transform: head)
        tuft.addCurve(to: CGPoint(x: 3.2, y: 4.6), control1: CGPoint(x: 3.2, y: 7.0), control2: CGPoint(x: 3.5, y: 5.6), transform: head)
        tuft.closeSubpath()
        items.append(.coat(tuft, Coat.body))
    }

    private func ear(_ items: inout [Item], root: CGPoint, angle: Double, mirrored: Bool) {
        var swing = max(-2.3, min(2.3, angle))
        let droop = 1 + 0.06 * pose.earDroop
        let reach = Dog.earLength * droop
        let clearance = root.y - 0.6
        if clearance < reach * cos(swing) {
            let needed = clearance <= 0 ? 1.5 : min(1.5, acos(min(1, clearance / reach)))
            swing = abs(swing) > 0.05 ? (swing > 0 ? needed : -needed) : -needed
        }
        var frame = CGAffineTransform(translationX: root.x, y: root.y).rotated(by: swing)
        frame = frame.scaledBy(x: mirrored ? -1.14 : 1.14, y: droop * 1.14)

        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: -1.5, y: 0.8), transform: frame)
        shape.addCurve(to: CGPoint(x: -3.9, y: -7.4), control1: CGPoint(x: -3.2, y: -1.2), control2: CGPoint(x: -4.7, y: -4.4), transform: frame)
        shape.addCurve(to: CGPoint(x: -2.0, y: -11.5), control1: CGPoint(x: -3.6, y: -9.5), control2: CGPoint(x: -3.5, y: -11.3), transform: frame)
        shape.addCurve(to: CGPoint(x: 0.3, y: -12.5), control1: CGPoint(x: -1.6, y: -12.9), control2: CGPoint(x: -0.5, y: -12.2), transform: frame)
        shape.addCurve(to: CGPoint(x: 2.5, y: -11.1), control1: CGPoint(x: 1.1, y: -13.1), control2: CGPoint(x: 2.1, y: -12.4), transform: frame)
        shape.addCurve(to: CGPoint(x: 3.8, y: -6.9), control1: CGPoint(x: 3.8, y: -10.6), control2: CGPoint(x: 4.4, y: -8.9), transform: frame)
        shape.addCurve(to: CGPoint(x: 1.7, y: 0.8), control1: CGPoint(x: 3.4, y: -4.0), control2: CGPoint(x: 2.9, y: -0.8), transform: frame)
        shape.closeSubpath()
        items.append(.coat(shape, Coat.ear))
        items.append(.stroke(shape, Coat.earEdge, 0.4))

        for (x, y, width) in [(-1.7, -5.2, 1.3), (0.9, -7.0, 1.2), (-0.9, -8.9, 1.3), (1.3, -10.3, 1.0), (-0.2, -3.0, 1.0)] {
            let curl = CGMutablePath()
            curl.move(to: CGPoint(x: x - width, y: y + 0.5), transform: frame)
            curl.addQuadCurve(to: CGPoint(x: x + width, y: y + 0.5), control: CGPoint(x: x, y: y - 1.3), transform: frame)
            items.append(.stroke(curl, Coat.curl, 0.5))
        }
        if mud > 0.75 {
            let tip = CGPoint(x: 0.3, y: -11.0).applying(frame)
            items.append(.fill(Dog.ellipse(tip, 1.6, 1.1), Painter.rgb(0x8E6E45, min(1, (mud - 0.75) * 5))))
        }
    }

    private func eye(_ items: inout [Item], _ centre: CGPoint, radius: Double, look: CGPoint) {
        let p = pose
        if p.happyEyes > 0.5 {
            let arc = CGMutablePath()
            arc.move(to: centre + CGPoint(x: -radius, y: -0.3))
            arc.addQuadCurve(to: centre + CGPoint(x: radius, y: -0.3), control: centre + CGPoint(x: 0, y: radius * 1.5))
            items.append(.stroke(arc, Coat.lid, 0.6))
            return
        }
        if p.eyes < 0.18 {
            let arc = CGMutablePath()
            arc.move(to: centre + CGPoint(x: -radius, y: 0.2))
            arc.addQuadCurve(to: centre + CGPoint(x: radius, y: 0.2), control: centre + CGPoint(x: 0, y: -radius * 0.9))
            items.append(.stroke(arc, Coat.lid, 0.55))
            return
        }
        let open = min(1, p.eyes)
        let wide = max(0, p.eyes - 1)
        let r = radius * (1 + 0.3 * wide)
        items.append(.fill(Dog.ellipse(centre, r, r * open), Coat.amberDeep))
        items.append(.fill(Dog.ellipse(centre, r * 0.86, r * 0.86 * open), Coat.amber))
        let pupil = r * (0.56 + 0.45 * wide)
        let gaze = centre + CGPoint(x: look.x, y: look.y) * (r * 0.3)
        items.append(.fill(Dog.ellipse(gaze, pupil, min(pupil, r * open)), Coat.pupil))
        if open > 0.5 {
            items.append(.fill(Dog.circle(gaze + CGPoint(x: r * 0.3, y: r * 0.36), r * 0.27), Painter.rgb(0xFFFFFF)))
            if wide > 0.1 {
                items.append(.fill(Dog.circle(gaze + CGPoint(x: -r * 0.3, y: -r * 0.28), r * 0.14), Painter.rgb(0xFFFFFF, 0.9)))
            }
        }
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
