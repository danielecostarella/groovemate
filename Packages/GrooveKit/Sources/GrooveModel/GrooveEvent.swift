/// A single drum hit inside a bar, in musical time.
public struct GrooveEvent: Codable, Sendable, Hashable {
    /// Which articulation to play.
    public var voice: DrumVoice
    /// Position in beats from the start of the bar (0 ..< beatsPerBar). May carry
    /// humanization offsets, so it is not required to sit on a grid line.
    public var position: Double
    /// Loudness 0...1.
    public var velocity: Double

    public init(voice: DrumVoice, position: Double, velocity: Double) {
        self.voice = voice
        self.position = position
        self.velocity = velocity
    }
}

/// One bar of performed drums, ready for scheduling.
public struct BarPerformance: Sendable {
    /// Events sorted by position.
    public var events: [GrooveEvent]
    /// Number of beats in this bar (4 for 4/4).
    public var beatsPerBar: Double
    /// True when this bar is a fill.
    public var isFill: Bool

    public init(events: [GrooveEvent], beatsPerBar: Double = 4, isFill: Bool = false) {
        self.events = events.sorted { $0.position < $1.position }
        self.beatsPerBar = beatsPerBar
        self.isFill = isFill
    }
}
