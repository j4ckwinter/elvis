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
        .glanceDoor, .lieByDoor, .relief,
    ]

    @Test(arguments: everyAction)
    func everyPoseIsFiniteAndKeepsPawsOffTheFloorbelow(action: Action) {
        for step in 0..<90 {
            let pose = Choreography.pose(for: Moment(action: action, elapsed: Double(step) / 30, length: 3, serial: step))
            #expect(pose.isFinite)
            #expect(pose.paws.allSatisfy { $0.y >= -0.01 })
        }
    }

    @Test func aWholeBusyStretchDrawsWithoutTrouble() throws {
        let unit = 2.0
        let width = Int(Yard.width * unit), height = Int((Yard.height + Painter.groundMargin) * unit)
        let ctx = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
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
            brain.tick(1.0 / 30)
            let frame = stage.advance(brain.moment, dt: 1.0 / 30)
            #expect(frame.pose.isFinite)
            #expect(frame.ears.allSatisfy { $0.isFinite })
            guard step % 20 == 0 else { continue }
            ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
            Painter.draw(frame, in: ctx, unit: unit)
            let pixels = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
            let stride = ctx.bytesPerRow
            let area = Painter.bounds(of: frame)
            let patch = CGRect(
                x: area.minX * unit, y: (area.minY + Painter.groundMargin) * unit, width: area.width * unit, height: area.height * unit
            ).insetBy(dx: -1, dy: -1)
            var opaque = 0, strays = 0
            for row in 0..<height {
                for column in 0..<width where pixels[row * stride + column * 4 + 3] > 0 {
                    if pixels[row * stride + column * 4 + 3] > 200 { opaque += 1 }
                    if !patch.contains(CGPoint(x: Double(column) + 0.5, y: Double(height - 1 - row) + 0.5)) { strays += 1 }
                }
            }
            #expect(opaque > 300, "frame \(step) drew almost nothing")
            #expect(strays == 0, "frame \(step) (\(frame.action)) painted \(strays) pixels outside its declared bounds")
            inked += 1
        }
        #expect(inked == 120)
    }
}
