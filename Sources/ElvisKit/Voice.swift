import Foundation

public enum Voice {
    public static let sampleRate = 44100.0

    public static func samples(for cue: Brain.Cue) -> [Float] {
        switch cue {
        case .whine: return whine()
        case .bark: return bark()
        case .yip: return yip()
        }
    }

    private static func bark() -> [Float] {
        let woofLength = 0.19
        let lastWoof = Choreography.barkTimes.max() ?? 0
        var samples = [Float](repeating: 0, count: Int(sampleRate * (lastWoof + woofLength + 0.1)))
        var breath = SplitMix(seed: 7)
        for start in Choreography.barkTimes {
            var phase = 0.0
            for i in 0..<Int(sampleRate * woofLength) {
                let t = Double(i) / sampleRate
                phase += 2 * .pi * (250 + 260 * exp(-t * 22)) / sampleRate
                let growl = (1...5).reduce(0.0) { $0 + sin(Double($1) * phase) / Double($1) }
                let hiss = Double.random(in: -1...1, using: &breath) * 0.35
                let envelope = min(1, t / 0.008) * pow(1 - t / woofLength, 1.6)
                samples[Int(sampleRate * start) + i] += Float((growl + hiss) * envelope * 0.05)
            }
        }
        return samples
    }

    private static func yip() -> [Float] {
        let length = 0.14
        var phase = 0.0
        return (0..<Int(sampleRate * length)).map { i in
            let t = Double(i) / sampleRate
            let part = t / length
            phase += 2 * .pi * (760 + 490 * part) / sampleRate
            let envelope = min(1, t / 0.01) * pow(1 - part, 1.2)
            return Float((sin(phase) + 0.3 * sin(2 * phase)) * envelope * 0.05)
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
