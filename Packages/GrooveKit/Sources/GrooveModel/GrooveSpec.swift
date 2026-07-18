import Foundation

/// Musical style of the groove.
public enum Style: String, CaseIterable, Codable, Sendable, Identifiable {
    case rock
    case funk
    case jazz
    case blues
    case pop

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

    /// Sensible tempo range for the style, used to clamp requests.
    public var tempoRange: ClosedRange<Double> {
        switch self {
        case .rock: return 60...200
        case .funk: return 70...130
        case .jazz: return 60...300
        case .blues: return 50...140
        case .pop: return 70...160
        }
    }

    public var defaultTempo: Double {
        switch self {
        case .rock: return 110
        case .funk: return 96
        case .jazz: return 140
        case .blues: return 84
        case .pop: return 108
        }
    }
}

/// Everything the drummer needs to know about how to play right now.
///
/// All feel dimensions are normalized 0...1:
/// - `tightness`: 1 = machine-tight, 0 = very loose/human
/// - `complexity`: 0 = bare-bones timekeeping, 1 = busy, ornamented
/// - `intensity`: 0 = whisper-quiet brushes-level, 1 = full-power chorus
public struct GrooveSpec: Codable, Sendable, Equatable {
    public var style: Style
    public var bpm: Double
    public var tightness: Double
    public var complexity: Double
    public var intensity: Double
    /// 0 = straight, 1 = full triplet swing. Styles apply it to their own subdivision.
    public var swing: Double
    /// Positive = plays behind the beat (laid back), negative = pushes ahead. In beats, small (±0.03 typical).
    public var pocketOffset: Double
    /// A fill is played every N bars. 0 disables fills.
    public var fillEveryBars: Int
    public var beatsPerBar: Double

    public init(
        style: Style = .rock,
        bpm: Double? = nil,
        tightness: Double = 0.7,
        complexity: Double = 0.5,
        intensity: Double = 0.6,
        swing: Double = 0,
        pocketOffset: Double = 0,
        fillEveryBars: Int = 4,
        beatsPerBar: Double = 4
    ) {
        self.style = style
        self.bpm = bpm ?? style.defaultTempo
        self.tightness = tightness
        self.complexity = complexity
        self.intensity = intensity
        self.swing = swing
        self.pocketOffset = pocketOffset
        self.fillEveryBars = fillEveryBars
        self.beatsPerBar = beatsPerBar
    }

    /// Returns a copy with all values clamped to their valid ranges.
    public func clamped() -> GrooveSpec {
        var s = self
        s.bpm = min(max(s.bpm, 30), 300)
        s.tightness = min(max(s.tightness, 0), 1)
        s.complexity = min(max(s.complexity, 0), 1)
        s.intensity = min(max(s.intensity, 0), 1)
        s.swing = min(max(s.swing, 0), 1)
        s.pocketOffset = min(max(s.pocketOffset, -0.06), 0.06)
        s.fillEveryBars = min(max(s.fillEveryBars, 0), 32)
        return s
    }
}
