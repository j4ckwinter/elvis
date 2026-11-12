import CoreGraphics
import ElvisKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Sheets {
    /// Collects live frames into contact sheets. Enabled with ELVIS_FILM=<directory>, for checking the running app
    /// without screen-recording permission.
    final class Film {
        private let directory: String
        private var frames: [Frame] = []
        private var reel = 0
        private let columns = 6, rows = 4

        init(directory: String) {
            self.directory = directory
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        func add(_ frame: Frame) {
            frames.append(frame)
            if frames.count == columns * rows { flush() }
        }

        func flush() {
            guard !frames.isEmpty else { return }
            let unit = 1.5
            let cellWidth = Yard.width * unit, cellHeight = (Yard.height + Painter.groundMargin) * unit
            let width = Int(cellWidth) * columns, height = Int(cellHeight) * rows
            guard let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            for (index, frame) in frames.enumerated() {
                let column = index % columns, row = index / columns
                let cell = CGRect(x: Double(column) * cellWidth, y: Double(rows - 1 - row) * cellHeight, width: cellWidth, height: cellHeight)
                ctx.saveGState()
                ctx.clip(to: cell)
                ctx.setFillColor(CGColor(srgbRed: (index + row) % 2 == 0 ? 0.16 : 0.2, green: 0.17, blue: 0.21, alpha: 1))
                ctx.fill(cell)
                ctx.translateBy(x: cell.minX, y: cell.minY)
                Painter.draw(frame, in: ctx, unit: unit)
                ctx.restoreGState()
            }
            reel += 1
            let path = "\(directory)/reel-\(String(format: "%02d", reel)).png"
            if let image = ctx.makeImage(),
               let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
            frames = []
        }
    }
}
