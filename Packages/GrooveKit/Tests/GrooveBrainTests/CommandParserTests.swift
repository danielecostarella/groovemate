import XCTest
@testable import GrooveBrain
import GrooveModel

final class CommandParserTests: XCTestCase {
    let parser = CommandParser()
    let base = GrooveSpec(style: .rock, bpm: 110)

    func testFunkyGrooveWithBPMAndPocket() {
        let r = parser.apply("Play a 90 BPM funky groove with a relaxed pocket.", to: base)
        XCTAssertEqual(r.spec.style, .funk)
        XCTAssertEqual(r.spec.bpm, 90)
        XCTAssertLessThanOrEqual(r.spec.tightness, 0.55)
        XCTAssertGreaterThan(r.spec.pocketOffset, 0)
        XCTAssertFalse(r.changes.isEmpty)
    }

    func testBonham() {
        let r = parser.apply("Give me a John Bonham inspired rock feel.", to: GrooveSpec(style: .pop))
        XCTAssertEqual(r.spec.style, .rock)
        XCTAssertGreaterThanOrEqual(r.spec.intensity, 0.85)
        XCTAssertGreaterThan(r.spec.pocketOffset, 0)
    }

    func testSimplerForPractice() {
        let r = parser.apply("Make it simpler for practice.", to: base)
        XCTAssertLessThan(r.spec.complexity, base.complexity)
    }

    func testEnergyForChorus() {
        let r = parser.apply("Increase the energy for a chorus.", to: base)
        XCTAssertGreaterThan(r.spec.intensity, base.intensity)
    }

    func testFillEveryEightBars() {
        let r = parser.apply("Add a fill every 8 bars.", to: base)
        XCTAssertEqual(r.spec.fillEveryBars, 8)
    }

    func testNoFills() {
        let r = parser.apply("No fills please.", to: base)
        XCTAssertEqual(r.spec.fillEveryBars, 0)
    }

    func testTempoWords() {
        XCTAssertGreaterThan(parser.apply("a bit faster", to: base).spec.bpm, base.bpm)
        XCTAssertLessThan(parser.apply("slower please", to: base).spec.bpm, base.bpm)
        XCTAssertEqual(parser.apply("play it at 128", to: base).spec.bpm, 128)
    }

    func testUnknownTextHasNoChanges() {
        let r = parser.apply("what's the weather like", to: base)
        XCTAssertTrue(r.changes.isEmpty)
        XCTAssertEqual(r.spec, base)
    }

    func testShuffleImpliesSwing() {
        let r = parser.apply("give me a blues shuffle", to: base)
        XCTAssertEqual(r.spec.style, .blues)
        XCTAssertGreaterThanOrEqual(r.spec.swing, 0.6)
    }

    // MARK: - Italian

    func testItalianRockA120() {
        let r = parser.apply("suona un ritmo rock a 120", to: GrooveSpec(style: .pop))
        XCTAssertEqual(r.spec.style, .rock)
        XCTAssertEqual(r.spec.bpm, 120)
        XCTAssertTrue(r.wantsPlay)
    }

    func testItalianSimpler() {
        let r = parser.apply("più semplice per favore", to: base)
        XCTAssertLessThan(r.spec.complexity, base.complexity)
    }

    func testItalianEnergyAndTempo() {
        let r = parser.apply("più forte e più veloce", to: base)
        XCTAssertGreaterThan(r.spec.intensity, base.intensity)
        XCTAssertGreaterThan(r.spec.bpm, base.bpm)
    }

    func testItalianRelaxedPocket() {
        let r = parser.apply("rilassato, dietro al beat", to: base)
        XCTAssertGreaterThan(r.spec.pocketOffset, 0)
    }

    func testItalianFills() {
        XCTAssertEqual(parser.apply("stacco ogni 8 battute", to: base).spec.fillEveryBars, 8)
        XCTAssertEqual(parser.apply("senza stacchi", to: base).spec.fillEveryBars, 0)
    }

    func testItalianStop() {
        let r = parser.apply("fermati", to: base)
        XCTAssertTrue(r.wantsStop)
        XCTAssertFalse(r.wantsPlay)
    }

    func testPlayIntentEnglish() {
        XCTAssertTrue(parser.apply("play a funky groove", to: base).wantsPlay)
    }
}
