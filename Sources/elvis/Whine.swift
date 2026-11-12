import AVFoundation

final class Whine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private lazy var buffer = Whine.render(format: format)
    private var attached = false
    private var stopWork: DispatchWorkItem?

    func play() {
        if !attached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            attached = true
        }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.player.stop()
            self?.engine.stop()
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private static func render(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let length = 0.95
        let frames = AVAudioFrameCount(rate * length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        var phase = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            let part = t / length
            let rise = min(1, part / 0.22)
            let pitch = 690 + 250 * rise - 330 * max(0, part - 0.22) / 0.78 + 14 * sin(t * 2 * .pi * 6.5)
            phase += 2 * .pi * pitch / rate
            let envelope = min(1, t / 0.07) * pow(max(0, 1 - part), 1.4)
            let voice = sin(phase) + 0.28 * sin(2 * phase) + 0.1 * sin(3 * phase)
            samples[i] = Float(voice * envelope * 0.055)
        }
        return buffer
    }
}
