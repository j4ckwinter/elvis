import CoreGraphics
import ElvisKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Sheets {
    private static let storySeed: UInt64 = 48
    private static let story: [(at: Double, event: WorkEvent)] = [
        (0.6, WorkEvent(.taskStarted, session: "story")),
        (1.4, WorkEvent(.toolStarted, session: "story", flavour: .read)),
        (4.0, WorkEvent(.toolStarted, session: "story", flavour: .edit)),
        (9.5, WorkEvent(.testsPassed, session: "story")),
    ]
    private static let storyRuns = (from: 0.3, to: 19.5)
    private static let ticksPerShot = 2
    private static let secondsPerShot = 0.05

    static func writeStory(background: UInt32, to path: String) throws {
        let unit = 3.0
        let width = Int(Yard.width * unit), height = Int((Yard.height + Painter.groundMargin) * unit)
        let shots = Int((storyRuns.to - storyRuns.from) / secondsPerShot)
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let film = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.gif.identifier as CFString, shots, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationSetProperties(film, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let shotProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: secondsPerShot]] as CFDictionary
        let paper = CGColor(
            srgbRed: Double((background >> 16) & 0xFF) / 255, green: Double((background >> 8) & 0xFF) / 255,
            blue: Double(background & 0xFF) / 255, alpha: 1)

        var brain = Brain(seed: storySeed)
        var stage = Stage(seed: storySeed)
        var told = 0
        let dt = secondsPerShot / Double(ticksPerShot)
        func tick() -> Frame {
            while told < story.count, story[told].at <= brain.now {
                brain.handle(story[told].event)
                told += 1
            }
            brain.tick(dt)
            _ = brain.drainCues()
            return stage.advance(brain.moment, dt: dt)
        }
        while brain.now < storyRuns.from { _ = tick() }
        for _ in 0..<shots {
            var frame = Frame()
            for _ in 0..<ticksPerShot { frame = tick() }
            ctx.setFillColor(paper)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            Painter.draw(frame, in: ctx, unit: unit)
            guard let image = ctx.makeImage() else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(film, image, shotProperties)
        }
        guard CGImageDestinationFinalize(film) else { throw CocoaError(.fileWriteUnknown) }
        print(path)
    }
}
