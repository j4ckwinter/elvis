import CoreGraphics
import Testing
@testable import ElvisKit

@Suite struct DrawingTests {
    static let everyAction: [Action] = [
        .sleep, .sleepTwitch, .dream, .sleepSigh, .sleepWag, .doze, .rest, .sigh, .earFlap, .sit, .lookAround, .wagAtYou,
        .scratch, .sneeze, .yawn, .stretch, .circle, .chaseTail, .dizzy, .shake, .petted, .nudgeBall,
        .go(to: 150, gait: .walk), .go(to: 150, gait: .sniff), .go(to: 150, gait: .trot), .go(to: 150, gait: .prance),
        .go(to: 150, gait: .run), .go(to: 150, gait: .slink), .go(to: 150, gait: .trudge),
        .sniffSpot, .dig, .point, .sniffAir, .checkIn, .pant, .startle, .boundUp, .droop, .spin, .confused,
        .watchBall, .chaseBall, .skid, .grabBall, .dropBall, .proudSit, .flop, .stare, .tiltHead, .pawDoor,
        .glanceDoor, .lieByDoor, .relief, .held, .landed, .buryBone, .bark, .listen,
    ]

    @Test(arguments: everyAction)
    func everyPoseIsFiniteAndKeepsPawsOffTheFloorbelow(action: Action) {
        for step in 0..<90 {
            let pose = Choreography.pose(for: Moment(action: action, elapsed: Double(step) / 30, length: 3, serial: step))
            #expect(pose.isFinite)
            #expect(pose.paws.allSatisfy { $0.y >= -0.01 })
        }
    }

    static func paint(_ frame: Frame) throws -> (opaque: Int, strays: Int) {
        let unit = 2.0
        let width = Int(Yard.width * unit), height = Int((Yard.height + Painter.groundMargin) * unit)
        let ctx = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        Painter.draw(frame, in: ctx, unit: unit)
        let pixels = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        let rowBytes = ctx.bytesPerRow
        let area = Painter.bounds(of: frame)
        let patch = CGRect(
            x: area.minX * unit, y: (area.minY + Painter.groundMargin) * unit, width: area.width * unit, height: area.height * unit
        ).insetBy(dx: -1, dy: -1)
        var opaque = 0, strays = 0
        for row in 0..<height {
            for column in 0..<width where pixels[row * rowBytes + column * 4 + 3] > 0 {
                if pixels[row * rowBytes + column * 4 + 3] > 200 { opaque += 1 }
                if !patch.contains(CGPoint(x: Double(column) + 0.5, y: Double(height - 1 - row) + 0.5)) { strays += 1 }
            }
        }
        return (opaque, strays)
    }

    @Test func thePointerBoxFollowsHisPose() {
        var standing = Frame()
        standing.pose = .stand
        var lying = Frame()
        lying.pose = .chinDown
        let tall = Painter.body(of: standing), low = Painter.body(of: lying)
        #expect(tall.contains(CGPoint(x: standing.x + 15, y: 30)), "his head counts")
        #expect(!low.contains(CGPoint(x: lying.x, y: 30)), "the air above a lying dog does not")
        #expect(low.contains(CGPoint(x: lying.x + 20, y: 2)), "his outstretched paws do")
    }

    @Test func theYardSettlesOnScreenWithElvisWhereHeWasDropped() {
        let screen = CGRect(x: 0, y: 77, width: 1512, height: 870)
        let inside = Placement.settle(window: CGRect(x: 400, y: 300, width: 460, height: 180), dogX: 100, unit: 2, within: screen)
        #expect(inside.origin == CGPoint(x: 400, y: 300))
        #expect(inside.dogX == 100)

        let pastTheRight = Placement.settle(window: CGRect(x: 1300, y: 300, width: 460, height: 180), dogX: 60, unit: 2, within: screen)
        #expect(pastTheRight.origin.x == 1052.0)
        #expect(pastTheRight.origin.x + pastTheRight.dogX * 2 == 1420.0, "he stays under the pointer")

        let belowTheFloor = Placement.settle(window: CGRect(x: 400, y: -500, width: 460, height: 180), dogX: 100, unit: 2, within: screen)
        #expect(belowTheFloor.origin.y == 77)

        let offTheLeft = Placement.settle(window: CGRect(x: -900, y: 300, width: 460, height: 180), dogX: 100, unit: 2, within: screen)
        #expect(offTheLeft.origin.x == 0)
        #expect(offTheLeft.dogX == Yard.leftEdge)
    }

    @Test func carryingHimSwingsHisBodyAndKeepsItInsideThePaintedPatch() throws {
        var brain = Brain(seed: 6)
        var stage = Stage(seed: 6)
        brain.pickUp()
        var widestSwing = 0.0
        for step in 0..<120 {
            brain.tick(1.0 / 30)
            let yardOrigin = CGPoint(x: 180 + 180 * sin(Double(step) * 0.35), y: 40 + 30 * sin(Double(step) * 0.5))
            let frame = stage.advance(brain.moment, dt: 1.0 / 30, yardOrigin: yardOrigin)
            #expect(frame.pose.isFinite)
            let hang = frame.pose.hip.x - frame.pose.shoulder.x
            let restingHang = -8.0
            if step > 15 { widestSwing = max(widestSwing, abs(hang - restingHang)) }
            if step % 5 == 0 {
                let painted = try DrawingTests.paint(frame)
                #expect(painted.strays == 0, "carried frame \(step) painted \(painted.strays) pixels outside its declared bounds")
            }
        }
        #expect(widestSwing > 2, "dragging the yard sideways should swing him")
    }

    @Test func aWholeBusyStretchDrawsWithoutTrouble() throws {
        var brain = Brain(seed: 11)
        var stage = Stage(seed: 11)
        let script: [(Int, WorkEvent)] = [
            (30, WorkEvent(.taskStarted, session: "s")), (200, WorkEvent(.toolStarted, session: "s", flavour: .edit)),
            (400, WorkEvent(.testsFailed, session: "s")), (600, WorkEvent(.needsYou, session: "s")),
            (900, WorkEvent(.youAnswered, session: "s")), (1000, WorkEvent(.testsPassed, session: "s")),
            (1500, WorkEvent(.taskFinished, session: "s")),
        ]
        var inked = 0
        for step in 0..<2400 {
            for (at, event) in script where at == step { brain.handle(event) }
            if step == 1900 { brain.pickUp() }
            if step == 2000 { brain.putDown(at: 90) }
            brain.tick(1.0 / 30)
            let frame = stage.advance(brain.moment, dt: 1.0 / 30)
            #expect(frame.pose.isFinite)
            #expect(frame.ears.allSatisfy { $0.isFinite })
            guard step % 20 == 0 else { continue }
            let painted = try DrawingTests.paint(frame)
            #expect(painted.opaque > 300, "frame \(step) drew almost nothing")
            #expect(painted.strays == 0, "frame \(step) (\(frame.action)) painted \(painted.strays) pixels outside its declared bounds")
            inked += 1
        }
        #expect(inked == 120)
    }
}
