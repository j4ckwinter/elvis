import Foundation

public enum Voice {
    public static let sampleRate = 44100.0

    public static func samples(for cue: Brain.Cue) -> [Float] {
        switch cue {
        case .whine: return whine()
        case .bark: return []
        }
    }

    private static func whine() -> [Float] {
        let length = 0.95
        var phase = 0.0
        return (0..<Int(sampleRate * length)).map { i in
            let t = Double(i) / sampleRate
            let part = t / length
            let rise = min(1, part / 0.22)
            let pitch = 690 + 250 * rise - 330 * max(0, part - 0.22) / 0.78 + 14 * sin(t * 2 * .pi * 6.5)
            phase += 2 * .pi * pitch / sampleRate
            let envelope = min(1, t / 0.07) * pow(max(0, 1 - part), 1.4)
            let voice = sin(phase) + 0.28 * sin(2 * phase) + 0.1 * sin(3 * phase)
            return Float(voice * envelope * 0.055)
        }
    }
}
