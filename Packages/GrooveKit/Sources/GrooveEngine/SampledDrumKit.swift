import AVFoundation
import GrooveModel

/// A real recorded acoustic kit, loaded from a folder of per-voice samples
/// described by a `manifest.json`:
///
/// ```json
/// {
///   "name": "…", "license": "…", "attribution": "…", "sampleRate": 44100,
///   "voices": { "kick": { "layers": [ { "files": ["kick/kick-L0-R0.flac"] } ] } }
/// }
/// ```
///
/// Layers are ordered soft → hard; files inside a layer are round-robin
/// variants. Any Core Audio-readable format works (FLAC, WAV, CAF, …).
public struct SampledDrumKit: DrumKit {
    public let sampleRate: Double
    public let roundRobinCount: Int
    public let usesBakedStereoImage = true
    public let name: String
    public let attribution: String

    private struct Layer {
        var variants: [KitSample]
    }
    private let voices: [DrumVoice: [Layer]]

    private struct Manifest: Decodable {
        struct Voice: Decodable {
            struct Layer: Decodable { var files: [String] }
            var layers: [Layer]
        }
        var name: String
        var license: String
        var attribution: String
        var sampleRate: Double
        var voices: [String: Voice]
    }

    public enum LoadError: Error {
        case missingVoice(String)
        case unreadableSample(String)
    }

    /// Longest tail kept per voice, to bound memory. Cymbals ring; drums don't.
    private static func maxSeconds(for voice: DrumVoice) -> Double {
        switch voice {
        case .ride, .crash: return 6
        case .rideBell: return 4
        case .hatOpen: return 3
        default: return 2.5
        }
    }

    public init(directory: URL) throws {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        self.name = manifest.name
        self.attribution = manifest.attribution
        self.sampleRate = manifest.sampleRate

        var voices: [DrumVoice: [Layer]] = [:]
        var maxRR = 1
        for voice in DrumVoice.allCases {
            guard let v = manifest.voices[voice.rawValue] else {
                throw LoadError.missingVoice(voice.rawValue)
            }
            var layers: [Layer] = []
            for layer in v.layers {
                var variants: [KitSample] = []
                for file in layer.files {
                    let url = directory.appendingPathComponent(file)
                    let sample = try Self.load(
                        url: url,
                        targetRate: manifest.sampleRate,
                        maxSeconds: Self.maxSeconds(for: voice)
                    )
                    variants.append(sample)
                }
                maxRR = max(maxRR, variants.count)
                layers.append(Layer(variants: variants))
            }
            voices[voice] = layers
        }
        self.voices = voices
        self.roundRobinCount = maxRR
    }

    public func sample(for voice: DrumVoice, velocity: Double, roundRobin: Int) -> (sample: KitSample, gain: Float) {
        let layers = voices[voice]!
        let v = min(max(velocity, 0), 1)
        let layerIndex = min(Int(v * Double(layers.count)), layers.count - 1)
        let layer = layers[layerIndex]
        let sample = layer.variants[roundRobin % layer.variants.count]
        // Real layers already carry their natural loudness; the gain curve only
        // smooths dynamics inside a layer band.
        let gain = Float(0.55 + 0.45 * v)
        return (sample, gain)
    }

    // MARK: - Decoding

    private static func load(url: URL, targetRate: Double, maxSeconds: Double) throws -> KitSample {
        guard let file = try? AVAudioFile(forReading: url) else {
            throw LoadError.unreadableSample(url.lastPathComponent)
        }
        let format = file.processingFormat
        let frames = min(AVAudioFrameCount(file.length), AVAudioFrameCount(maxSeconds * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw LoadError.unreadableSample(url.lastPathComponent)
        }
        try file.read(into: buffer, frameCount: frames)

        let n = Int(buffer.frameLength)
        guard n > 0, let ch = buffer.floatChannelData else {
            throw LoadError.unreadableSample(url.lastPathComponent)
        }
        var left = [Float](repeating: 0, count: n)
        var right = [Float](repeating: 0, count: n)
        left.withUnsafeMutableBufferPointer { $0.baseAddress!.update(from: ch[0], count: n) }
        let rightChannel = format.channelCount > 1 ? ch[1] : ch[0]
        right.withUnsafeMutableBufferPointer { $0.baseAddress!.update(from: rightChannel, count: n) }

        // Fade the last 30 ms in case the tail was truncated.
        let fade = min(Int(format.sampleRate * 0.03), n)
        for i in 0..<fade {
            let g = Float(1 - Double(i) / Double(fade))
            left[n - fade + i] *= g
            right[n - fade + i] *= g
        }
        return KitSample(left: left, right: right)
    }
}
