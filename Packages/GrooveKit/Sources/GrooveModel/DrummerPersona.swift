/// Tone shaping for the kit, per persona. All values 0...1.
public struct KitTone: Codable, Sendable, Equatable {
    /// Dark vintage thud ↔ bright modern crack.
    public var brightness: Double
    /// Dry close-mic ↔ big room.
    public var room: Double
    /// Low drum tuning ↔ high tuning.
    public var tuning: Double

    public init(brightness: Double = 0.5, room: Double = 0.35, tuning: Double = 0.5) {
        self.brightness = brightness
        self.room = room
        self.tuning = tuning
    }
}

/// A drummer the user can hire: not a preset but a musician with a persistent
/// personality. They have a repertoire (styles they play), a character that
/// colors *any* style they're asked to play, and their own kit sound.
public struct DrummerPersona: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var tagline: String
    /// Styles this drummer knows how to play. The UI offers only these.
    public var repertoire: [Style]
    /// Starting point when hired.
    public var spec: GrooveSpec
    public var tone: KitTone

    // Character: persistent coloring applied to whatever the user dials in.
    /// The drummer physically can't play tighter/looser than this.
    public var tightnessRange: ClosedRange<Double>
    /// Dynamic identity: a whisper-quiet Bonham still hits harder than a jazz brush player.
    public var intensityRange: ClosedRange<Double>
    /// Where they naturally sit relative to the beat (added to the spec's pocket).
    public var pocketBias: Double
    /// Their natural relationship with swing (added to the spec's swing).
    public var swingBias: Double

    public init(
        id: String, name: String, tagline: String,
        repertoire: [Style], spec: GrooveSpec, tone: KitTone,
        tightnessRange: ClosedRange<Double> = 0...1,
        intensityRange: ClosedRange<Double> = 0...1,
        pocketBias: Double = 0,
        swingBias: Double = 0
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.repertoire = repertoire
        self.spec = spec
        self.tone = tone
        self.tightnessRange = tightnessRange
        self.intensityRange = intensityRange
        self.pocketBias = pocketBias
        self.swingBias = swingBias
    }

    /// How this drummer actually plays what was asked: the user's spec filtered
    /// through the player's character. Applied at generation time so the
    /// personality persists across every style and slider change.
    public func interpret(_ requested: GrooveSpec) -> GrooveSpec {
        var s = requested
        if !repertoire.contains(s.style) {
            s.style = repertoire.first ?? s.style
        }
        s.tightness = min(max(s.tightness, tightnessRange.lowerBound), tightnessRange.upperBound)
        s.intensity = min(max(s.intensity, intensityRange.lowerBound), intensityRange.upperBound)
        s.pocketOffset += pocketBias
        s.swing = min(max(s.swing + swingBias, 0), 1)
        return s.clamped()
    }

    /// The drummer whose repertoire and character best fit a style.
    public static func bestMatch(for style: Style) -> DrummerPersona {
        switch style {
        case .rock: return all[0]
        case .funk: return all[1]
        case .jazz: return all[2]
        case .blues: return all[4] // Vintage
        case .pop: return all[3] // Studio
        }
    }

    public static let all: [DrummerPersona] = [
        DrummerPersona(
            id: "rock", name: "Rock", tagline: "Big backbeat, no nonsense",
            repertoire: [.rock, .blues, .pop],
            spec: GrooveSpec(style: .rock, tightness: 0.75, complexity: 0.5, intensity: 0.7),
            tone: KitTone(brightness: 0.6, room: 0.45, tuning: 0.4),
            tightnessRange: 0.35...0.85,
            intensityRange: 0.35...1.0,
            pocketBias: 0.008
        ),
        DrummerPersona(
            id: "funk", name: "Funk", tagline: "Ghost notes for days",
            repertoire: [.funk, .pop, .blues],
            spec: GrooveSpec(style: .funk, tightness: 0.85, complexity: 0.65, intensity: 0.6, swing: 0.15),
            tone: KitTone(brightness: 0.7, room: 0.25, tuning: 0.65),
            tightnessRange: 0.6...0.95,
            intensityRange: 0.2...0.9,
            swingBias: 0.08
        ),
        DrummerPersona(
            id: "jazz", name: "Jazz", tagline: "Ride-led, conversational",
            repertoire: [.jazz, .blues],
            spec: GrooveSpec(style: .jazz, tightness: 0.55, complexity: 0.6, intensity: 0.4, swing: 0.85),
            tone: KitTone(brightness: 0.5, room: 0.5, tuning: 0.75),
            tightnessRange: 0.3...0.75,
            intensityRange: 0.1...0.75,
            swingBias: 0.15
        ),
        DrummerPersona(
            id: "studio", name: "Studio", tagline: "Plays exactly what the song needs",
            repertoire: Style.allCases,
            spec: GrooveSpec(style: .pop, tightness: 0.9, complexity: 0.4, intensity: 0.55),
            tone: KitTone(brightness: 0.65, room: 0.3, tuning: 0.5),
            tightnessRange: 0.55...1.0,
            intensityRange: 0.15...0.95
        ),
        DrummerPersona(
            id: "vintage", name: "Vintage", tagline: "Warm, loose, behind the beat",
            repertoire: [.blues, .rock, .pop],
            spec: GrooveSpec(style: .blues, tightness: 0.5, complexity: 0.45, intensity: 0.5, swing: 0.35, pocketOffset: 0.02),
            tone: KitTone(brightness: 0.25, room: 0.55, tuning: 0.35),
            tightnessRange: 0.25...0.65,
            intensityRange: 0.2...0.85,
            pocketBias: 0.018,
            swingBias: 0.1
        ),
        DrummerPersona(
            id: "modern", name: "Modern", tagline: "Tight, punchy, produced",
            repertoire: [.pop, .rock, .funk],
            spec: GrooveSpec(style: .pop, tightness: 0.95, complexity: 0.55, intensity: 0.75),
            tone: KitTone(brightness: 0.85, room: 0.2, tuning: 0.55),
            tightnessRange: 0.75...1.0,
            intensityRange: 0.4...1.0,
            pocketBias: -0.004
        ),
    ]
}
