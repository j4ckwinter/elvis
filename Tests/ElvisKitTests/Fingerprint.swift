import CoreGraphics
import Foundation
import Testing
@testable import ElvisKit

@Suite(.enabled(if: ProcessInfo.processInfo.environment["ELVIS_FINGERPRINT"] != nil))
struct Fingerprint {
    struct Hash {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        mutating func add(_ byte: UInt8) {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01B3
        }
        mutating func add(_ number: Double) {
            var bits = number.bitPattern
            for _ in 0..<8 {
                add(UInt8(bits & 0xFF))
                bits >>= 8
            }
        }
        mutating func add(_ point: CGPoint) {
            add(Double(point.x))
            add(Double(point.y))
        }
        mutating func add(_ text: String) { for byte in text.utf8 { add(byte) } }
        mutating func add(_ pose: Pose) {
            add(pose.hip); add(pose.shoulder); add(pose.head); add(pose.look)
            for paw in pose.paws { add(paw) }
            for number in [pose.rearBend, pose.front, pose.pitch, pose.tilt, pose.earLift, pose.earDroop, pose.earFling, pose.tail,
                           pose.eyes, pose.happyEyes, pose.brow, pose.mouth, pose.tongue, pose.lift, pose.lean, pose.turn] { add(number) }
        }
    }

    @Test func ofPosesRunsAndPixels() throws {
        var poses = Hash()
        for action in DrawingTests.everyAction {
            for glum in [0.0, 1.0] {
                var world = World()
                world.glum = glum
                world.ball = Ball(x: 0, y: 0, vx: 0, vy: 0, state: .carried)
                for step in 0..<150 {
                    for length in [0.6, 3.0] {
                        poses.add(Choreography.pose(for: Moment(action: action, elapsed: Double(step) / 30, length: length, serial: step, world: world)))
                    }
                }
            }
        }

        let unit = 2.0
        let width = Int(Yard.width * unit), height = Int((Yard.height + Painter.groundMargin) * unit)
        let ctx = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        var runs = Hash(), pixels = Hash()
        for seed in [3, 11, 29] as [UInt64] {
            var brain = Brain(seed: seed)
            var stage = Stage(seed: seed)
            brain.restore(mud: 0.3)
            let script: [(Int, WorkEvent)] = [
                (20, WorkEvent(.sessionStarted, session: "a")), (60, WorkEvent(.taskStarted, session: "a")),
                (150, WorkEvent(.toolStarted, session: "a", flavour: .read, subject: "Read:1")),
                (300, WorkEvent(.toolStarted, session: "a", flavour: .edit, subject: "Edit:1")),
                (520, WorkEvent(.toolStarted, session: "a", flavour: .shell, subject: "Bash:1")),
                (600, WorkEvent(.testsFailed, session: "a", subject: "Bash:1")),
                (800, WorkEvent(.testsFailed, session: "a")), (900, WorkEvent(.toolStarted, session: "a", flavour: .web)),
                (1000, WorkEvent(.needsYou, session: "a", subject: "Bash:2")),
                (1010, WorkEvent(.toolStarted, session: "a", flavour: .read, subject: "Read:2")),
                (1200, WorkEvent(.toolStarted, session: "a", flavour: .read, subject: "Read:3", agent: "helper")),
                (1500, WorkEvent(.toolFinished, session: "a", subject: "Read:9")),
                (1700, WorkEvent(.toolFinished, session: "a", subject: "Bash:2")),
                (1800, WorkEvent(.testsPassed, session: "a")), (2300, WorkEvent(.testsPassed, session: "a")),
                (2400, WorkEvent(.taskStarted, session: "b")), (2600, WorkEvent(.taskFinished, session: "b")),
                (2700, WorkEvent(.needsYou, session: "a")), (2900, WorkEvent(.youAnswered, session: "a")),
                (3900, WorkEvent(.taskFinished, session: "a")), (4300, WorkEvent(.testsPassed)),
                (4900, WorkEvent(.throwBall)), (5400, WorkEvent(.taskStarted, session: "a")),
                (5500, WorkEvent(.taskStumbled, session: "a")), (5700, WorkEvent(.taskStarted, session: "c")),
                (5800, WorkEvent(.sessionIdle, session: "c")), (5900, WorkEvent(.sessionEnded, session: "a")),
                (5910, WorkEvent(.toolFinished, session: "a")), (6000, WorkEvent(.taskStarted, session: "d")),
                (6100, WorkEvent(.needsYou, session: "d")),
            ]
            for step in 0..<9000 {
                for (at, event) in script where at == step { brain.handle(event) }
                if step == 3300 { brain.pickUp() }
                if step == 3420 { brain.putDown(at: 70) }
                if step == 4600 { brain.pat() }
                if (7000..<7200).contains(step) {
                    brain.cursor(at: (brain.world.x + Double(step % 7), 14))
                } else {
                    brain.cursor(at: step % 400 < 200 ? (Double(step % 230), 30) : nil)
                }
                brain.tick(1.0 / 30)
                for cue in brain.drainCues() where cue == .whine {
                    stage.showWhine(at: brain.moment)
                    runs.add(UInt8(1))
                }
                let origin = CGPoint(x: (3300..<3420).contains(step) ? 200 + 150 * sin(Double(step) * 0.3) : 200, y: 40)
                let frame = stage.advance(brain.moment, dt: 1.0 / 30, yardOrigin: origin)
                runs.add(frame.pose)
                runs.add(frame.x); runs.add(frame.facing); runs.add(frame.doorAlpha); runs.add(frame.mud)
                for ear in frame.ears { runs.add(ear) }
                runs.add(Double(frame.particles.count))
                for particle in frame.particles { runs.add(particle.x); runs.add(particle.y); runs.add(particle.size) }
                if let ball = frame.ball { runs.add(ball.x); runs.add(ball.y); runs.add(ball.spin) }
                runs.add(frame.trailTo ?? -1)
                runs.add(brain.caption)
                runs.add("\(brain.mode)\(brain.action)")
                let area = Painter.bounds(of: frame), body = Painter.body(of: frame)
                for number in [area.minX, area.minY, area.width, area.height, body.minX, body.minY, body.width, body.height] { runs.add(Double(number)) }
                guard step % 12 == 0 else { continue }
                ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
                Painter.draw(frame, in: ctx, unit: unit)
                let bytes = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
                for index in 0..<(ctx.bytesPerRow * height) { pixels.add(bytes[index]) }
            }
            var sleeper = Brain(seed: seed &+ 100)
            for _ in 0..<12000 {
                sleeper.tick(0.1)
                runs.add("\(sleeper.action)")
                runs.add(sleeper.world.x)
            }
        }
        print("FINGERPRINT poses=\(String(poses.value, radix: 16)) runs=\(String(runs.value, radix: 16)) pixels=\(String(pixels.value, radix: 16))")
    }
}
