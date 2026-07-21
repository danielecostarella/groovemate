import XCTest
@testable import GrooveBrain
import GrooveModel

final class PracticeProgressionTests: XCTestCase {

    func testHoldsSteadyWhenNoStep() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 70, stepBPM: 0, stepInterval: 60
        )
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 0), 70)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 500), 70)
    }

    func testStepsUpAtEachInterval() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 80, stepBPM: 2, stepInterval: 90
        )
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 0), 70)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 89), 70)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 90), 72)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 181), 74)
    }

    func testNeverExceedsTarget() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 80, stepBPM: 2, stepInterval: 90
        )
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 10_000), 80)
    }

    func testDescendingStepNeverGoesBelowTarget() {
        // Not a real plan shape today, but the math should still hold if one
        // were authored (e.g. cooling down from a fast warmup).
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 120, targetBPM: 100, stepBPM: -5, stepInterval: 60
        )
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 0), 120)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 60), 115)
        XCTAssertEqual(PracticeProgression.bpm(for: plan, elapsed: 10_000), 100)
    }

    func testProgressReflectsDistanceToTarget() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 80, stepBPM: 2, stepInterval: 90
        )
        XCTAssertEqual(PracticeProgression.progress(for: plan, elapsed: 0), 0, accuracy: 0.001)
        XCTAssertEqual(PracticeProgression.progress(for: plan, elapsed: 10_000), 1, accuracy: 0.001)
    }

    func testProgressIsFullWhenPlanHasNoRange() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 70, stepBPM: 0, stepInterval: 60
        )
        XCTAssertEqual(PracticeProgression.progress(for: plan, elapsed: 0), 1)
    }

    func testSessionCompletionAtPlannedDuration() {
        let plan = PracticePlan(
            id: "t", title: "t", subtitle: "t", style: .rock,
            startBPM: 70, targetBPM: 70, stepBPM: 0, stepInterval: 60, sessionMinutes: 10
        )
        XCTAssertFalse(PracticeProgression.isComplete(for: plan, elapsed: 599))
        XCTAssertTrue(PracticeProgression.isComplete(for: plan, elapsed: 600))
    }

    func testBuiltInPlansAreWellFormed() {
        for plan in PracticePlan.builtIn {
            XCTAssertGreaterThan(plan.startBPM, 0, plan.id)
            XCTAssertGreaterThan(plan.sessionMinutes, 0, plan.id)
            XCTAssertGreaterThanOrEqual(plan.targetBPM, plan.startBPM, "\(plan.id): target shouldn't be below start for an ascending plan")
        }
    }
}
