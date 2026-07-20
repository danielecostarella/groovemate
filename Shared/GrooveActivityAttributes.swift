import ActivityKit
import Foundation

/// What the Dynamic Island / Lock Screen shows while the drummer plays in
/// the background. Lives in `Shared/` because both the app (which starts and
/// updates the Activity) and the widget extension (which renders it) need
/// this exact type.
struct GrooveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var personaName: String
        var styleName: String
        var bpm: Int
        var isPlaying: Bool
        var startedAt: Date
    }

    /// Fixed for the life of the activity.
    var kitName: String
}
