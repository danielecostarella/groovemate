import GrooveModel

/// A rendered, ready-to-play articulation, stereo. Synth voices are dual-mono
/// (left === right) and rely on mix-time panning; sampled kits carry their
/// recorded stereo image.
public final class KitSample: @unchecked Sendable {
    public let left: [Float]
    public let right: [Float]
    public var frameCount: Int { left.count }

    public init(left: [Float], right: [Float]) {
        self.left = left
        self.right = right
    }

    /// Dual-mono convenience for synthesized voices.
    public convenience init(samples: [Float]) {
        self.init(left: samples, right: samples)
    }
}

/// Anything that can hand the engine a buffer for a hit. `SampledDrumKit` for
/// real acoustic recordings, `SynthDrumKit` as the dependency-free fallback.
public protocol DrumKit: Sendable {
    var sampleRate: Double { get }
    /// Number of round-robin variants per articulation.
    var roundRobinCount: Int { get }
    /// The buffer for a hit. `velocity` selects the dynamic layer; the returned
    /// gain completes the velocity curve between layers.
    func sample(for voice: DrumVoice, velocity: Double, roundRobin: Int) -> (sample: KitSample, gain: Float)
    /// True when samples carry their own stereo image and per-voice mix-time
    /// panning/levels should be skipped.
    var usesBakedStereoImage: Bool { get }
}

public extension DrumKit {
    var usesBakedStereoImage: Bool { false }
}

/// Static per-voice mix placement, drummer's perspective.
public enum VoiceMix {
    public static func pan(_ voice: DrumVoice) -> Float {
        switch voice {
        case .kick: return 0
        case .snare, .snareGhost, .snareRim: return 0.05
        case .hatClosed, .hatOpen, .hatHalfOpen, .hatPedal: return -0.35
        case .tomHigh: return -0.2
        case .tomMid: return 0.05
        case .tomLow: return 0.3
        case .ride, .rideBell: return 0.35
        case .crash: return -0.25
        }
    }

    public static func level(_ voice: DrumVoice) -> Float {
        switch voice {
        case .kick: return 1.0
        case .snare: return 0.95
        case .snareGhost: return 0.7
        case .snareRim: return 0.8
        case .hatClosed, .hatPedal: return 0.55
        case .hatOpen: return 0.6
        case .hatHalfOpen: return 0.58
        case .tomHigh, .tomMid, .tomLow: return 0.9
        case .ride: return 0.5
        case .rideBell: return 0.65
        case .crash: return 0.75
        }
    }
}
