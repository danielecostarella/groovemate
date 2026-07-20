import ActivityKit
import Foundation
import GrooveModel

/// Bridges playback state to a Live Activity so the drummer stays visible —
/// name, style, tempo, play/stop — in the Dynamic Island and on the Lock
/// Screen while the app is backgrounded. A nice-to-have: any failure here
/// must never affect playback itself.
@MainActor
final class GrooveLiveActivityController {
    private var activity: Activity<GrooveActivityAttributes>?

    func start(personaName: String, kitName: String, spec: GrooveSpec) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = GrooveActivityAttributes.ContentState(
            personaName: personaName,
            styleName: spec.style.displayName,
            bpm: Int(spec.bpm.rounded()),
            isPlaying: true,
            startedAt: Date()
        )
        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        do {
            activity = try Activity.request(
                attributes: GrooveActivityAttributes(kitName: kitName),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    /// Reflects a tempo/style/persona change while playing.
    func update(personaName: String, spec: GrooveSpec, isPlaying: Bool) {
        guard let activity else { return }
        var state = activity.content.state
        state.personaName = personaName
        state.styleName = spec.style.displayName
        state.bpm = Int(spec.bpm.rounded())
        state.isPlaying = isPlaying
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func stop() {
        guard let activity else { return }
        var state = activity.content.state
        state.isPlaying = false
        self.activity = nil
        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 3))
        }
    }
}
