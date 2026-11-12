import Testing
@testable import ElvisKit

@Suite struct VoiceTests {
    @Test(arguments: [Brain.Cue.whine, .bark, .yip])
    func everySoundIsShortAndQuietAndStartsAndEndsInSilence(cue: Brain.Cue) throws {
        let samples = Voice.samples(for: cue)
        let seconds = Double(samples.count) / Voice.sampleRate
        let loudest = try #require(samples.map(abs).max())
        #expect(samples.allSatisfy { $0.isFinite })
        #expect(seconds > 0.1 && seconds < 1.5)
        #expect(loudest > 0.03 && loudest < 0.15)
        #expect(abs(samples[0]) < 0.005 && abs(samples[samples.count - 1]) < 0.005)
    }

    @Test func theBarkSoundsWhenHisMouthOpens() {
        let samples = Voice.samples(for: .bark)
        func loudness(around time: Double) -> Float {
            let middle = Int(Voice.sampleRate * time)
            return samples[(middle - 400)..<(middle + 400)].map(abs).max() ?? 0
        }
        for woof in Choreography.barkTimes {
            #expect(loudness(around: woof + 0.02) > 0.03)
        }
        #expect(loudness(around: 0.1) == 0)
        #expect(loudness(around: 0.5) < 0.005, "there is a gap between the two woofs")
    }
}
