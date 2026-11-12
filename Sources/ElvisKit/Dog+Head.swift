import CoreGraphics
import Foundation

extension Dog {
    private static let earLength = 14.2

    func profileHead(_ items: inout [Item]) {
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

    func frontHead(_ items: inout [Item]) {
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
}
