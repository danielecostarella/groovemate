import GrooveModel

/// One notated hit in a groove template, with the conditions under which the drummer plays it.
public struct TemplateEvent: Sendable {
    public var voice: DrumVoice
    public var position: Double
    /// Base velocity before intensity shaping, 0...1.
    public var velocity: Double
    /// The event is only played when spec.complexity >= this.
    public var minComplexity: Double
    /// The event disappears above this complexity (simple backbones give way to busier ones).
    public var maxComplexity: Double
    /// The event only plays at or above this energy — a chorus-only addition.
    public var minIntensity: Double
    /// The event disappears above this energy — a verse-only restraint.
    public var maxIntensity: Double
    /// Chance the drummer plays it on any given bar (ornaments < 1).
    public var probability: Double
    /// Accented notes resist the intensity curve (backbeats stay strong even when quiet).
    public var accent: Bool

    public init(
        _ voice: DrumVoice, at position: Double, velocity: Double,
        minComplexity: Double = 0, maxComplexity: Double = 1,
        minIntensity: Double = 0, maxIntensity: Double = 1,
        probability: Double = 1, accent: Bool = false
    ) {
        self.voice = voice
        self.position = position
        self.velocity = velocity
        self.minComplexity = minComplexity
        self.maxComplexity = maxComplexity
        self.minIntensity = minIntensity
        self.maxIntensity = maxIntensity
        self.probability = probability
        self.accent = accent
    }
}

/// A style's core groove: the grid the generator humanizes and develops.
public struct GrooveTemplate: Sendable {
    public var style: Style
    public var beatsPerBar: Double
    /// The subdivision (in beats) whose offbeats get swung: 0.5 = swung 8ths, 0.25 = swung 16ths.
    public var swingSubdivision: Double
    /// Timekeeping voice, replaced by ride at high intensity for rock-family styles.
    public var timekeeper: DrumVoice
    public var events: [TemplateEvent]

    public init(style: Style, beatsPerBar: Double = 4, swingSubdivision: Double, timekeeper: DrumVoice, events: [TemplateEvent]) {
        self.style = style
        self.beatsPerBar = beatsPerBar
        self.swingSubdivision = swingSubdivision
        self.timekeeper = timekeeper
        self.events = events
    }
}

/// Hand-authored groove vocabulary for each style.
public enum PatternLibrary {
    public static func template(for style: Style) -> GrooveTemplate {
        switch style {
        case .rock: return rock
        case .funk: return funk
        case .jazz: return jazz
        case .blues: return blues
        case .pop: return pop
        }
    }

    /// Straight-8s rock: kick 1 & 3(+), backbeat 2 & 4, 8th hats.
    /// High complexity brings a 16th-note hat feel, barks and syncopated kicks.
    static let rock = GrooveTemplate(
        style: .rock, swingSubdivision: 0.5, timekeeper: .hatClosed,
        events: eighthHats(accentQuarters: true) + sixteenthUpgrade(velocity: 0.28) + [
            TemplateEvent(.kick, at: 0.0, velocity: 0.95, accent: true),
            TemplateEvent(.kick, at: 2.0, velocity: 0.9, accent: true),
            TemplateEvent(.kick, at: 2.5, velocity: 0.75, minComplexity: 0.3),
            TemplateEvent(.kick, at: 3.5, velocity: 0.7, minComplexity: 0.55, probability: 0.7),
            TemplateEvent(.kick, at: 1.75, velocity: 0.65, minComplexity: 0.75, probability: 0.55),
            TemplateEvent(.snare, at: 1.0, velocity: 0.95, accent: true),
            TemplateEvent(.snare, at: 3.0, velocity: 0.95, accent: true),
            TemplateEvent(.snareGhost, at: 1.75, velocity: 0.25, minComplexity: 0.6, probability: 0.5),
            TemplateEvent(.snareGhost, at: 3.75, velocity: 0.3, minComplexity: 0.7, probability: 0.4),
            // Hat bark lifting into the next bar — the classic "spice" move.
            TemplateEvent(.hatHalfOpen, at: 3.5, velocity: 0.55, minComplexity: 0.65, probability: 0.45),
            // Chorus: an extra pickup kick pushes into beat 1.
            TemplateEvent(.kick, at: 0.75, velocity: 0.6, minIntensity: 0.75, probability: 0.55),
        ]
    )

    /// 16th-feel funk: syncopated kick, ghosted snare around 2 & 4.
    static let funk = GrooveTemplate(
        style: .funk, swingSubdivision: 0.25, timekeeper: .hatClosed,
        events: sixteenthHats() + [
            TemplateEvent(.kick, at: 0.0, velocity: 0.95, accent: true),
            TemplateEvent(.kick, at: 0.75, velocity: 0.8, minComplexity: 0.25),
            TemplateEvent(.kick, at: 1.5, velocity: 0.7, minComplexity: 0.45, probability: 0.8),
            TemplateEvent(.kick, at: 2.25, velocity: 0.85, minComplexity: 0.2),
            TemplateEvent(.kick, at: 3.5, velocity: 0.75, minComplexity: 0.5, probability: 0.7),
            TemplateEvent(.snare, at: 1.0, velocity: 0.95, accent: true),
            TemplateEvent(.snare, at: 3.0, velocity: 0.95, accent: true),
            TemplateEvent(.snareGhost, at: 0.5, velocity: 0.2, minComplexity: 0.35, probability: 0.6),
            TemplateEvent(.snareGhost, at: 1.25, velocity: 0.22, minComplexity: 0.3, probability: 0.7),
            TemplateEvent(.snareGhost, at: 1.75, velocity: 0.2, minComplexity: 0.45, probability: 0.6),
            TemplateEvent(.snareGhost, at: 2.5, velocity: 0.25, minComplexity: 0.4, probability: 0.65),
            TemplateEvent(.snareGhost, at: 3.25, velocity: 0.2, minComplexity: 0.5, probability: 0.6),
            TemplateEvent(.snare, at: 3.75, velocity: 0.5, minComplexity: 0.75, probability: 0.4),
            TemplateEvent(.hatOpen, at: 2.5, velocity: 0.6, minComplexity: 0.55, probability: 0.55),
            // Chorus: one more syncopated kick, verse restraint keeps it out at low energy.
            TemplateEvent(.kick, at: 3.25, velocity: 0.6, minComplexity: 0.4, minIntensity: 0.7, probability: 0.6),
        ]
    )

    /// Swung ride pattern, feathered kick, comping snare.
    static let jazz = GrooveTemplate(
        style: .jazz, swingSubdivision: 0.5, timekeeper: .ride,
        events: [
            TemplateEvent(.ride, at: 0.0, velocity: 0.75, accent: true),
            TemplateEvent(.ride, at: 1.0, velocity: 0.85, accent: true),
            TemplateEvent(.ride, at: 1.5, velocity: 0.55),
            TemplateEvent(.ride, at: 2.0, velocity: 0.75),
            TemplateEvent(.ride, at: 3.0, velocity: 0.85, accent: true),
            TemplateEvent(.ride, at: 3.5, velocity: 0.55),
            TemplateEvent(.hatPedal, at: 1.0, velocity: 0.6),
            TemplateEvent(.hatPedal, at: 3.0, velocity: 0.6),
            TemplateEvent(.kick, at: 0.0, velocity: 0.25, minComplexity: 0.2, probability: 0.7),
            TemplateEvent(.kick, at: 2.0, velocity: 0.22, minComplexity: 0.3, probability: 0.6),
            TemplateEvent(.snareGhost, at: 0.5, velocity: 0.3, minComplexity: 0.35, probability: 0.45),
            TemplateEvent(.snare, at: 1.5, velocity: 0.45, minComplexity: 0.45, probability: 0.5),
            TemplateEvent(.snareGhost, at: 2.5, velocity: 0.3, minComplexity: 0.4, probability: 0.5),
            TemplateEvent(.snare, at: 3.5, velocity: 0.4, minComplexity: 0.6, probability: 0.35),
            TemplateEvent(.kick, at: 3.5, velocity: 0.5, minComplexity: 0.7, probability: 0.3),
            // Chorus: a bebop "bomb" — an unexpected accented kick.
            TemplateEvent(.kick, at: 2.5, velocity: 0.55, minIntensity: 0.7, probability: 0.5),
        ]
    )

    /// Slow 12/8-feel shuffle written in 4/4 with heavy swing applied by spec.
    static let blues = GrooveTemplate(
        style: .blues, swingSubdivision: 0.5, timekeeper: .hatClosed,
        events: eighthHats(accentQuarters: true) + [
            TemplateEvent(.kick, at: 0.0, velocity: 0.9, accent: true),
            TemplateEvent(.kick, at: 2.0, velocity: 0.85, accent: true),
            TemplateEvent(.kick, at: 2.5, velocity: 0.6, minComplexity: 0.4, probability: 0.6),
            TemplateEvent(.snare, at: 1.0, velocity: 0.9, accent: true),
            TemplateEvent(.snare, at: 3.0, velocity: 0.9, accent: true),
            TemplateEvent(.snareGhost, at: 0.5, velocity: 0.25, minComplexity: 0.5, probability: 0.4),
            TemplateEvent(.snareGhost, at: 2.5, velocity: 0.25, minComplexity: 0.55, probability: 0.4),
            // Chorus: extra shuffle kick pushing the turnaround.
            TemplateEvent(.kick, at: 1.25, velocity: 0.55, minIntensity: 0.75, probability: 0.55),
        ]
    )

    /// Modern pop: tight 8th hats, four-ish kick, 16th color as it opens up.
    static let pop = GrooveTemplate(
        style: .pop, swingSubdivision: 0.25, timekeeper: .hatClosed,
        events: eighthHats(accentQuarters: false) + sixteenthUpgrade(velocity: 0.24) + [
            TemplateEvent(.kick, at: 0.0, velocity: 0.95, accent: true),
            TemplateEvent(.kick, at: 1.5, velocity: 0.8, minComplexity: 0.25),
            TemplateEvent(.kick, at: 2.0, velocity: 0.9, accent: true),
            TemplateEvent(.kick, at: 3.5, velocity: 0.7, minComplexity: 0.5, probability: 0.6),
            TemplateEvent(.kick, at: 2.75, velocity: 0.6, minComplexity: 0.8, probability: 0.5),
            TemplateEvent(.snare, at: 1.0, velocity: 0.9, accent: true),
            TemplateEvent(.snare, at: 3.0, velocity: 0.9, accent: true),
            TemplateEvent(.hatOpen, at: 3.5, velocity: 0.55, minComplexity: 0.6, probability: 0.5),
            TemplateEvent(.snareGhost, at: 2.75, velocity: 0.2, minComplexity: 0.65, probability: 0.4),
            // Chorus: a pickup 8th into beat 1.
            TemplateEvent(.kick, at: 3.75, velocity: 0.55, minIntensity: 0.75, probability: 0.5),
        ]
    )

    private static func eighthHats(accentQuarters: Bool) -> [TemplateEvent] {
        stride(from: 0.0, to: 4.0, by: 0.5).map { pos in
            let onQuarter = pos.truncatingRemainder(dividingBy: 1.0) == 0
            return TemplateEvent(
                .hatClosed, at: pos,
                velocity: onQuarter && accentQuarters ? 0.7 : 0.5
            )
        }
    }

    /// The "e" and "a" 16ths that turn an 8th-note hat pattern into a 16th feel
    /// once the drummer gets busy (played softer, like the weak hand).
    private static func sixteenthUpgrade(velocity: Double) -> [TemplateEvent] {
        stride(from: 0.25, to: 4.0, by: 0.5).map { pos in
            TemplateEvent(.hatClosed, at: pos, velocity: velocity, minComplexity: 0.7, probability: 0.9)
        }
    }

    private static func sixteenthHats() -> [TemplateEvent] {
        stride(from: 0.0, to: 4.0, by: 0.25).map { pos in
            let onQuarter = pos.truncatingRemainder(dividingBy: 1.0) == 0
            let onEighth = pos.truncatingRemainder(dividingBy: 0.5) == 0
            let minC: Double = onEighth ? 0 : 0.3
            return TemplateEvent(
                .hatClosed, at: pos,
                velocity: onQuarter ? 0.65 : (onEighth ? 0.5 : 0.35),
                minComplexity: minC
            )
        }
    }
}
