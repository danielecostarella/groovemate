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

/// A drummer the user can hire from the opening screen: a default feel plus a kit sound.
public struct DrummerPersona: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var tagline: String
    public var spec: GrooveSpec
    public var tone: KitTone

    public init(id: String, name: String, tagline: String, spec: GrooveSpec, tone: KitTone) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.spec = spec
        self.tone = tone
    }

    public static let all: [DrummerPersona] = [
        DrummerPersona(
            id: "rock", name: "Rock", tagline: "Big backbeat, no nonsense",
            spec: GrooveSpec(style: .rock, tightness: 0.75, complexity: 0.5, intensity: 0.7),
            tone: KitTone(brightness: 0.6, room: 0.45, tuning: 0.4)
        ),
        DrummerPersona(
            id: "funk", name: "Funk", tagline: "Ghost notes for days",
            spec: GrooveSpec(style: .funk, tightness: 0.85, complexity: 0.65, intensity: 0.6, swing: 0.15),
            tone: KitTone(brightness: 0.7, room: 0.25, tuning: 0.65)
        ),
        DrummerPersona(
            id: "jazz", name: "Jazz", tagline: "Ride-led, conversational",
            spec: GrooveSpec(style: .jazz, tightness: 0.55, complexity: 0.6, intensity: 0.4, swing: 0.85),
            tone: KitTone(brightness: 0.5, room: 0.5, tuning: 0.75)
        ),
        DrummerPersona(
            id: "studio", name: "Studio", tagline: "Plays exactly what the song needs",
            spec: GrooveSpec(style: .pop, tightness: 0.9, complexity: 0.4, intensity: 0.55),
            tone: KitTone(brightness: 0.65, room: 0.3, tuning: 0.5)
        ),
        DrummerPersona(
            id: "vintage", name: "Vintage", tagline: "Warm, loose, behind the beat",
            spec: GrooveSpec(style: .blues, tightness: 0.5, complexity: 0.45, intensity: 0.5, swing: 0.35, pocketOffset: 0.02),
            tone: KitTone(brightness: 0.25, room: 0.55, tuning: 0.35)
        ),
        DrummerPersona(
            id: "modern", name: "Modern", tagline: "Tight, punchy, produced",
            spec: GrooveSpec(style: .pop, tightness: 0.95, complexity: 0.55, intensity: 0.75),
            tone: KitTone(brightness: 0.85, room: 0.2, tuning: 0.55)
        ),
    ]
}
