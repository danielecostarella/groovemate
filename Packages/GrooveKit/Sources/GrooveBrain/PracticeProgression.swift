import Foundation
import GrooveModel

/// Computes where a practice plan's tempo should be at a given elapsed time —
/// a pure function so the progression logic is testable without timers,
/// clocks, or the app's UI at all.
public enum PracticeProgression {
    /// The BPM a plan should be playing at after `elapsed` seconds, stepping
    /// by `stepBPM` every `stepInterval` seconds until `targetBPM` is reached.
    public static func bpm(for plan: PracticePlan, elapsed: TimeInterval) -> Double {
        guard plan.stepInterval > 0, plan.stepBPM != 0 else { return plan.startBPM }
        let steps = floor(max(elapsed, 0) / plan.stepInterval)
        let raw = plan.startBPM + steps * plan.stepBPM
        return plan.stepBPM > 0
            ? min(raw, max(plan.startBPM, plan.targetBPM))
            : max(raw, min(plan.startBPM, plan.targetBPM))
    }

    /// 0...1 progress toward the target tempo (1 once it's reached and held).
    public static func progress(for plan: PracticePlan, elapsed: TimeInterval) -> Double {
        guard plan.targetBPM != plan.startBPM else { return 1 }
        let current = bpm(for: plan, elapsed: elapsed)
        return min(max((current - plan.startBPM) / (plan.targetBPM - plan.startBPM), 0), 1)
    }

    /// True once the session has run its planned duration.
    public static func isComplete(for plan: PracticePlan, elapsed: TimeInterval) -> Bool {
        elapsed >= Double(plan.sessionMinutes) * 60
    }
}
