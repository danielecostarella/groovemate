import Foundation
import Observation
import GrooveModel
import GrooveBrain

/// Runs a practice plan on top of an existing `GrooveSession`: picks the
/// right drummer, starts the groove, and bumps tempo on a schedule — no
/// separate audio engine, just orchestration over what already exists.
@MainActor
@Observable
final class PracticeController {
    private(set) var activePlan: PracticePlan?
    private(set) var elapsed: TimeInterval = 0
    private(set) var isRunning = false
    /// Set right after a session ends (early stop or natural completion) so
    /// the UI can show a summary even once `activePlan` has cleared.
    private(set) var lastCompletedRecord: PracticeRecord?

    private var startedAt: Date?
    private var timer: Timer?
    private var lastAppliedBPM: Double = 0
    private let history = PracticeHistoryStore()

    var recentSessions: [PracticeRecord] { history.all() }

    var currentBPM: Double { lastAppliedBPM }
    var progress: Double {
        guard let plan = activePlan else { return 0 }
        return PracticeProgression.progress(for: plan, elapsed: elapsed)
    }
    var remainingSeconds: TimeInterval {
        guard let plan = activePlan else { return 0 }
        return max(Double(plan.sessionMinutes) * 60 - elapsed, 0)
    }

    func start(_ plan: PracticePlan, using session: GrooveSession) {
        lastCompletedRecord = nil
        activePlan = plan
        startedAt = Date()
        elapsed = 0
        lastAppliedBPM = plan.startBPM

        let persona = DrummerPersona.bestMatch(for: plan.style)
        let spec = GrooveSpec(
            style: plan.style, bpm: plan.startBPM,
            tightness: 0.85, complexity: plan.complexity, intensity: plan.intensity,
            fillEveryBars: 0
        )
        session.select(persona, applying: spec, autoplay: true, navigate: false)
        isRunning = true

        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick(session: session) }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Ends the session before its planned duration; still logs the partial
    /// practice — time on the kit counts, finished or not.
    func stopEarly(using session: GrooveSession) {
        guard activePlan != nil else { return }
        logAndTearDown(session: session)
    }

    private func tick(session: GrooveSession) {
        guard let plan = activePlan, let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)

        let target = PracticeProgression.bpm(for: plan, elapsed: elapsed)
        if target != lastAppliedBPM {
            lastAppliedBPM = target
            var s = session.spec
            s.bpm = target
            session.spec = s
        }

        if PracticeProgression.isComplete(for: plan, elapsed: elapsed) {
            logAndTearDown(session: session)
        }
    }

    private func logAndTearDown(session: GrooveSession) {
        guard let plan = activePlan, let startedAt else { return }
        let record = PracticeRecord(
            date: startedAt, planTitle: plan.title, style: plan.style,
            startBPM: plan.startBPM, endBPM: lastAppliedBPM,
            duration: Date().timeIntervalSince(startedAt)
        )
        history.add(record)
        lastCompletedRecord = record

        timer?.invalidate()
        timer = nil
        // Fully hand the session back to neutral: leaving `persona` set to
        // whatever Practice Mode borrowed would confuse the picker's "first
        // prompt hires a drummer" logic the next time the user types a command.
        session.deselect()
        isRunning = false
        activePlan = nil
        self.startedAt = nil
        elapsed = 0
    }
}
