import GrooveModel

/// A rendered, ready-to-play articulation. Mono samples; panned at mix time.
public final class KitSample: @unchecked Sendable {
    public let samples: [Float]
    public init(samples: [Float]) {
        self.samples = samples
    }
}

/// Anything that can hand the engine a buffer for a hit. `SynthDrumKit` today,
/// sampled acoustic kits tomorrow — same contract.
public protocol DrumKit: Sendable {
    var sampleRate: Double { get }
    /// Number of round-robin variants per articulation.
    var roundRobinCount: Int { get }
    /// The buffer for a hit. `velocity` selects the dynamic layer; the returned
    /// gain completes the velocity curve between layers.
    func sample(for voice: DrumVoice, velocity: Double, roundRobin: Int) -> (sample: KitSample, gain: Float)
}

/// Static per-voice mix placement, drummer's perspective.
public enum VoiceMix {
    public static func pan(_ voice: DrumVoice) -> Float {
        switch voice {
        case .kick: return 0
        case .snare, .snareGhost, .snareRim: return 0.05
        case .hatClosed, .hatOpen, .hatPedal: return -0.35
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
        case .tomHigh, .tomMid, .tomLow: return 0.9
        case .ride: return 0.5
        case .rideBell: return 0.65
        case .crash: return 0.75
        }
    }
}
