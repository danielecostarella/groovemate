import Foundation

/// A structured practice session: start slow, build tempo over time, like a
/// drum teacher would assign. `stepBPM` of 0 means "hold steady" — useful for
/// a plan built purely around adding complexity rather than speed.
public struct PracticePlan: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var style: Style
    public var startBPM: Double
    public var targetBPM: Double
    public var stepBPM: Double
    /// Seconds between each tempo bump.
    public var stepInterval: TimeInterval
    /// How complex/powerful the groove is — plans can ask for more than a
    /// bare click as the days progress.
    public var complexity: Double
    public var intensity: Double
    public var sessionMinutes: Int

    public init(
        id: String, title: String, subtitle: String, style: Style,
        startBPM: Double, targetBPM: Double, stepBPM: Double, stepInterval: TimeInterval,
        complexity: Double = 0.2, intensity: Double = 0.45, sessionMinutes: Int = 10
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.startBPM = startBPM
        self.targetBPM = targetBPM
        self.stepBPM = stepBPM
        self.stepInterval = stepInterval
        self.complexity = complexity
        self.intensity = intensity
        self.sessionMinutes = sessionMinutes
    }

    /// A drum-teacher-style week: hold a tempo, then push it, then add feel.
    public static let builtIn: [PracticePlan] = [
        PracticePlan(
            id: "day1", title: "Day 1 — Lock the pocket", subtitle: "Rock, 70 BPM, steady",
            style: .rock, startBPM: 70, targetBPM: 70, stepBPM: 0, stepInterval: 60,
            complexity: 0.15, intensity: 0.4, sessionMinutes: 10
        ),
        PracticePlan(
            id: "day2", title: "Day 2 — A little faster", subtitle: "Rock, 70 → 80 BPM",
            style: .rock, startBPM: 70, targetBPM: 80, stepBPM: 2, stepInterval: 90,
            complexity: 0.15, intensity: 0.4, sessionMinutes: 10
        ),
        PracticePlan(
            id: "day3", title: "Day 3 — Add some feel", subtitle: "Funk, 85 BPM, ghost notes",
            style: .funk, startBPM: 85, targetBPM: 85, stepBPM: 0, stepInterval: 60,
            complexity: 0.5, intensity: 0.45, sessionMinutes: 12
        ),
        PracticePlan(
            id: "day4", title: "Day 4 — Shuffle it", subtitle: "Blues, 80 → 95 BPM",
            style: .blues, startBPM: 80, targetBPM: 95, stepBPM: 3, stepInterval: 90,
            complexity: 0.4, intensity: 0.5, sessionMinutes: 12
        ),
        PracticePlan(
            id: "day5", title: "Day 5 — Push the tempo", subtitle: "Rock, 90 → 120 BPM",
            style: .rock, startBPM: 90, targetBPM: 120, stepBPM: 5, stepInterval: 60,
            complexity: 0.45, intensity: 0.6, sessionMinutes: 15
        ),
    ]
}

/// A completed practice session, kept for history/stats.
public struct PracticeRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var date: Date
    public var planTitle: String
    public var style: Style
    public var startBPM: Double
    public var endBPM: Double
    public var duration: TimeInterval

    public init(id: String = UUID().uuidString, date: Date, planTitle: String, style: Style, startBPM: Double, endBPM: Double, duration: TimeInterval) {
        self.id = id
        self.date = date
        self.planTitle = planTitle
        self.style = style
        self.startBPM = startBPM
        self.endBPM = endBPM
        self.duration = duration
    }
}
