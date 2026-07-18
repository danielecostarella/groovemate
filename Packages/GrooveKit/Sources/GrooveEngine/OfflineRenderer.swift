import AVFoundation
import GrooveModel

/// Renders a performance to PCM without touching the audio hardware.
/// Used for verification today; the seed of track export tomorrow.
public struct OfflineRenderer {
    public let kit: DrumKit

    public init(kit: DrumKit) {
        self.kit = kit
    }

    /// Renders `bars` bars supplied by `barProvider` at the given bpm.
    /// Returns non-interleaved stereo channels.
    public func render(
        bars: Int,
        bpm: Double,
        barProvider: (Int) -> BarPerformance
    ) -> (left: [Float], right: [Float]) {
        let sr = kit.sampleRate
        let samplesPerBeat = sr * 60.0 / bpm
        var factory = TriggerFactory(kit: kit)
        let state = RenderState()

        var barStart: Int64 = 0
        var totalFrames: Int64 = 0
        for i in 0..<bars {
            let bar = barProvider(i)
            state.push(factory.triggers(for: bar, barStart: barStart, samplesPerBeat: samplesPerBeat))
            barStart += Int64(bar.beatsPerBar * samplesPerBeat)
            totalFrames = barStart
        }
        totalFrames += Int64(sr) // ring-out tail

        var left = [Float](repeating: 0, count: Int(totalFrames))
        var right = [Float](repeating: 0, count: Int(totalFrames))
        let block = 4096
        var frame = 0
        left.withUnsafeMutableBufferPointer { lp in
            right.withUnsafeMutableBufferPointer { rp in
                while frame < Int(totalFrames) {
                    let n = min(block, Int(totalFrames) - frame)
                    state.render(frameCount: n, outL: lp.baseAddress! + frame, outR: rp.baseAddress! + frame)
                    frame += n
                }
            }
        }
        return (left, right)
    }

    /// Renders and writes a WAV file.
    @discardableResult
    public func renderWAV(
        to url: URL,
        bars: Int,
        bpm: Double,
        barProvider: (Int) -> BarPerformance
    ) throws -> URL {
        let (left, right) = render(bars: bars, bpm: bpm, barProvider: barProvider)
        let format = AVAudioFormat(standardFormatWithSampleRate: kit.sampleRate, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(left.count))!
        buffer.frameLength = AVAudioFrameCount(left.count)
        left.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: left.count) }
        right.withUnsafeBufferPointer { buffer.floatChannelData![1].update(from: $0.baseAddress!, count: right.count) }
        try file.write(from: buffer)
        return url
    }
}
