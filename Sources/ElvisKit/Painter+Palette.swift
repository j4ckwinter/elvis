import CoreGraphics

extension Painter {
    static func rgb(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
        CGColor(
            srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
    }

    enum Coat {
        static let body = rgb(0x18181D)
        static let far = rgb(0x0E0E12)
        static let ear = rgb(0x2A2220)
        static let earEdge = rgb(0x4E413D)
        static let curl = rgb(0x5E4B44)
        static let sheen = rgb(0x30323D)
        static let muzzle = rgb(0x25252D)
        static let nose = rgb(0x3B3B46)
        static let noseShine = rgb(0x9A9AA8)
        static let line = rgb(0x5C5C6A)
        static let lid = rgb(0x8B8B99)
        static let amber = rgb(0xE0872A)
        static let amberDeep = rgb(0xA8581A)
        static let pupil = rgb(0x0A0A0C)
        static let tongue = rgb(0xF27F95)
        static let tongueLine = rgb(0xD45E78)
        static let mouth = rgb(0x4A1822)
        static let mud = rgb(0x8E6E45)
        static let mudDry = rgb(0xAD9165)
        static let rim = rgb(0x8E8F96)
    }
}
