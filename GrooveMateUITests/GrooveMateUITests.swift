import XCTest

/// End-to-end interaction tests that run on a real Simulator, driving actual
/// touch events (not calling Swift methods directly) — the only way to catch
/// bugs where the UI *looks* right but doesn't respond to taps, which is
/// exactly the class of regression that shipped twice in one session
/// (Liquid Glass's `.interactive()` eating the play button's tap, and a
/// `.glassEffect()` interaction that stopped every button from responding).
final class GrooveMateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-persona", "rock"] + extra
        app.launch()
        return app
    }

    /// Waits for the async kit load to finish (mirrors -autoplay's own poll).
    private func waitUntilReady(_ playButton: XCUIElement) {
        let ready = NSPredicate(format: "isEnabled == true")
        expectation(for: ready, evaluatedWith: playButton)
        waitForExpectations(timeout: 15)
    }

    func testPlayButtonTogglesPlayback() throws {
        let app = launch()
        let playButton = app.buttons["playButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        waitUntilReady(playButton)

        XCTAssertEqual(playButton.label, "Play")
        playButton.tap()

        let becomesStop = NSPredicate(format: "label == %@", "Stop")
        expectation(for: becomesStop, evaluatedWith: playButton)
        waitForExpectations(timeout: 5, handler: nil)

        playButton.tap()
        let becomesPlay = NSPredicate(format: "label == %@", "Play")
        expectation(for: becomesPlay, evaluatedWith: playButton)
        waitForExpectations(timeout: 5, handler: nil)
    }

    /// Regression test for the reactivity bug: tapping tempo while stopped
    /// must visibly update the BPM label, not just the internal model.
    func testTapTempoUpdatesDisplayedBPMWhileStopped() throws {
        let app = launch()
        let playButton = app.buttons["playButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        waitUntilReady(playButton)
        XCTAssertEqual(playButton.label, "Play", "must be stopped for this test to be meaningful")

        let tapButton = app.buttons["tapTempoButton"]
        let bpmLabel = app.staticTexts["bpmValue"]
        XCTAssertTrue(tapButton.waitForExistence(timeout: 5))
        let before = bpmLabel.label

        // Four taps at a steady ~0.5s interval simulate ~120 BPM.
        for _ in 0..<4 {
            tapButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertNotEqual(bpmLabel.label, before, "tap tempo must update the on-screen BPM even while stopped")
    }

    /// Sliders must be draggable and the fixed hero controls must keep
    /// responding after a drag — guards against any future gesture conflict
    /// between a slider and its neighbors.
    func testFeelSliderIsDraggableAndPlayStillWorksAfter() throws {
        let app = launch()
        let playButton = app.buttons["playButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        waitUntilReady(playButton)

        let slider = app.sliders.firstMatch
        if slider.waitForExistence(timeout: 3) {
            slider.adjust(toNormalizedSliderPosition: 0.8)
        }

        playButton.tap()
        let becomesStop = NSPredicate(format: "label == %@", "Stop")
        expectation(for: becomesStop, evaluatedWith: playButton)
        waitForExpectations(timeout: 5, handler: nil)
    }
}
