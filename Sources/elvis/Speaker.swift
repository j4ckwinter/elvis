import AVFoundation
import ElvisKit

final class Speaker {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Voice.sampleRate, channels: 1)!
    private var buffers: [Brain.Cue: AVAudioPCMBuffer] = [:]
    private var attached = false
    private var stopWork: DispatchWorkItem?

    private static let ringOut = 0.65

    func play(_ cue: Brain.Cue) {
        guard let buffer = buffer(for: cue) else { return }
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
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.player.stop()
            self?.engine.stop()
        }
        stopWork = work
        let length = Double(buffer.frameLength) / Voice.sampleRate
        DispatchQueue.main.asyncAfter(deadline: .now() + length + Speaker.ringOut, execute: work)
    }

    private func buffer(for cue: Brain.Cue) -> AVAudioPCMBuffer? {
        if let made = buffers[cue] { return made }
        let samples = Voice.samples(for: cue)
        guard !samples.isEmpty, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        buffers[cue] = buffer
        return buffer
    }
}
