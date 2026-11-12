import CoreGraphics
import ElvisKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Sheets {
    struct Cell {
        var label: String
        var action: Action
        var at: Double
        var length: Double
        var world = World()
    }

    static func write(to directory: String) throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        var muddy = World()
        muddy.mud = 0.9
        var glum = World()
        glum.glum = 1
        var carrying = World()
        carrying.ball = Ball(x: 0, y: 0, vx: 0, vy: 0, state: .carried)
        var door = World()
        door.x = Yard.doorSpot
        door.doorOpen = true

        let postures: [Cell] = [
            Cell(label: "sit", action: .sit, at: 1.0, length: 3),
            Cell(label: "wagAtYou", action: .wagAtYou, at: 1.0, length: 3),
            Cell(label: "walk", action: .go(to: 400, gait: .walk), at: 0.5, length: 9),
            Cell(label: "sniff", action: .go(to: 400, gait: .sniff), at: 0.7, length: 9),
            Cell(label: "trot", action: .go(to: 400, gait: .trot), at: 0.4, length: 9),
            Cell(label: "run", action: .go(to: 400, gait: .run), at: 0.33, length: 9),
            Cell(label: "prance", action: .go(to: 400, gait: .prance), at: 0.5, length: 9, world: carrying),
            Cell(label: "slink", action: .go(to: 400, gait: .slink), at: 0.6, length: 9, world: glum),
            Cell(label: "rest", action: .rest, at: 1.0, length: 6),
            Cell(label: "doze", action: .doze, at: 2.0, length: 6),
            Cell(label: "sleep", action: .sleep, at: 4.0, length: 12),
            Cell(label: "dream", action: .dream, at: 2.5, length: 5.5),
            Cell(label: "flop", action: .flop, at: 3.0, length: 14),
            Cell(label: "boundUp", action: .boundUp, at: 0.21, length: 1.3),
            Cell(label: "droop", action: .droop, at: 1.0, length: 4.4, world: glum),
            Cell(label: "proudSit", action: .proudSit, at: 1.2, length: 4.2),
            Cell(label: "stare", action: .stare, at: 2.0, length: 5, world: door),
            Cell(label: "tiltHead", action: .tiltHead, at: 0.9, length: 1.8, world: door),
            Cell(label: "pawDoor", action: .pawDoor, at: 0.6, length: 1.9, world: door),
            Cell(label: "lieByDoor", action: .lieByDoor, at: 2.0, length: 9, world: door),
            Cell(label: "dig", action: .dig, at: 1.2, length: 2.6),
            Cell(label: "point", action: .point, at: 1.5, length: 3),
            Cell(label: "sniffAir", action: .sniffAir, at: 1.2, length: 2.4),
            Cell(label: "sniffSpot", action: .sniffSpot, at: 1.2, length: 2.4),
            Cell(label: "shake", action: .shake, at: 0.8, length: 1.7, world: muddy),
            Cell(label: "muddy sit", action: .sit, at: 1.0, length: 3, world: muddy),
            Cell(label: "muddy trot", action: .go(to: 400, gait: .trot), at: 0.55, length: 9, world: muddy),
            Cell(label: "scratch", action: .scratch, at: 1.2, length: 2.3),
            Cell(label: "stretch", action: .stretch, at: 1.1, length: 2.2),
            Cell(label: "yawn", action: .yawn, at: 1.0, length: 2.0),
            Cell(label: "petted", action: .petted, at: 1.2, length: 2.2),
            Cell(label: "checkIn", action: .checkIn, at: 1.0, length: 1.9),
            Cell(label: "watchBall", action: .watchBall, at: 0.3, length: 0.6),
            Cell(label: "grabBall", action: .grabBall, at: 0.22, length: 0.45),
            Cell(label: "skid", action: .skid, at: 0.1, length: 0.55),
            Cell(label: "confused", action: .confused, at: 0.5, length: 2.6),
            Cell(label: "dizzy", action: .dizzy, at: 0.4, length: 1.6),
            Cell(label: "pant", action: .pant, at: 1.0, length: 4),
            Cell(label: "startle", action: .startle, at: 0.25, length: 0.45),
            Cell(label: "sneeze", action: .sneeze, at: 0.5, length: 1.0),
            Cell(label: "sigh", action: .sigh, at: 1.0, length: 2.0),
            Cell(label: "chaseTail", action: .chaseTail, at: 0.48, length: 2.2),
            Cell(label: "held", action: .held, at: 0.1, length: 60),
            Cell(label: "held, settled", action: .held, at: 2.0, length: 60),
            Cell(label: "landed", action: .landed, at: 0.3, length: 0.6),
        ]
        for (name, background) in [("dark", 0x1E1F26 as UInt32), ("light", 0xF2F0EA as UInt32)] {
            try render(postures, columns: 6, background: background, to: "\(directory)/poses-\(name).png")
        }
    }

    static func frame(for cell: Cell) -> Frame {
        var stage = Stage(seed: 7)
        var frame = Frame()
        let dt = 1.0 / 30
        var t = max(0, cell.at - 1.2)
        var world = cell.world
        if world.x == Yard.home { world.x = 40 }
        while t <= cell.at {
            frame = stage.advance(Moment(action: cell.action, elapsed: t, length: cell.length, serial: 1, world: world), dt: dt)
            t += dt
        }
        return frame
    }

    static func render(_ cells: [Cell], columns: Int, background: UInt32, to path: String) throws {
        let unit = 4.0
        let cellWidth = 80.0, cellHeight = 62.0
        let rows = (cells.count + columns - 1) / columns
        let width = Int(cellWidth * unit) * columns, height = Int(cellHeight * unit) * rows
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        ctx.setFillColor(CGColor(
            srgbRed: Double((background >> 16) & 0xFF) / 255, green: Double((background >> 8) & 0xFF) / 255,
            blue: Double(background & 0xFF) / 255, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (index, cell) in cells.enumerated() {
            let column = index % columns, row = index / columns
            var frame = frame(for: cell)
            let shift = 40 - frame.x
            frame.x += shift
            frame.particles = frame.particles.map { var p = $0; p.x += shift; return p }
            if var ball = frame.ball { ball.x += shift; frame.ball = ball }
            ctx.saveGState()
            ctx.translateBy(x: Double(column) * cellWidth * unit, y: Double(rows - 1 - row) * cellHeight * unit)
            ctx.clip(to: CGRect(x: 0, y: 0, width: cellWidth * unit, height: cellHeight * unit))
            if cell.world.doorOpen { ctx.translateBy(x: -(Yard.door - 62) * unit, y: 0); frame.x -= shift; frame.particles = [] }
            Painter.draw(frame, in: ctx, unit: unit)
            ctx.restoreGState()
        }
        guard let image = ctx.makeImage(),
              let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        print(path)
    }
}
