import XCTest
@testable import GrooveBrain
import GrooveModel

final class PersonaAndDepthTests: XCTestCase {

    // MARK: - Drummer character

    func testPersonaClampsCharacter() {
        let vintage = DrummerPersona.all.first { $0.id == "vintage" }!
        var asked = GrooveSpec(style: .rock, tightness: 1.0, intensity: 1.0)
        var played = vintage.interpret(asked)
        XCTAssertLessThanOrEqual(played.tightness, 0.65, "Vintage physically can't play machine-tight")
        XCTAssertGreaterThan(played.pocketOffset, 0, "Vintage sits behind the beat")

        let modern = DrummerPersona.all.first { $0.id == "modern" }!
        asked = GrooveSpec(style: .pop, tightness: 0.2)
        played = modern.interpret(asked)
        XCTAssertGreaterThanOrEqual(played.tightness, 0.75, "Modern never gets sloppy")
    }

    func testPersonaRepertoireLimitsStyle() {
        let jazz = DrummerPersona.all.first { $0.id == "jazz" }!
        let played = jazz.interpret(GrooveSpec(style: .pop))
        XCTAssertTrue(jazz.repertoire.contains(played.style))
    }

    func testBestMatchCoversAllStyles() {
        for style in Style.allCases {
            let persona = DrummerPersona.bestMatch(for: style)
            XCTAssertTrue(persona.repertoire.contains(style), "\(style) → \(persona.id)")
        }
    }

    // MARK: - Audible complexity

    func testComplexityChangesHatSubdivision() {
        var simpleGen = GrooveGenerator(seed: 21)
        var busyGen = GrooveGenerator(seed: 21)
        let simple = GrooveSpec(style: .rock, complexity: 0.4, fillEveryBars: 0)
        let busy = GrooveSpec(style: .rock, complexity: 0.9, fillEveryBars: 0)
        var simpleHats = 0, busyHats = 0
        for i in 0..<8 {
            simpleHats += simpleGen.bar(index: i, spec: simple).events.filter { $0.voice == .hatClosed }.count
            busyHats += busyGen.bar(index: i, spec: busy).events.filter { $0.voice == .hatClosed }.count
        }
        // 16th-note upgrade should add roughly half again as many hat strokes.
        XCTAssertGreaterThan(Double(busyHats), Double(simpleHats) * 1.4,
                             "high complexity should move the hats to a 16th feel (\(simpleHats) → \(busyHats))")
    }

    // MARK: - Fills are phrases, not ladders

    func testFillsVary() {
        var gen = GrooveGenerator(seed: 33)
        let spec = GrooveSpec(style: .rock, complexity: 0.7, fillEveryBars: 2)
        var signatures = Set<String>()
        for i in 0..<32 {
            let bar = gen.bar(index: i, spec: spec)
            if bar.isFill {
                let fillEvents = bar.events.filter { $0.position >= 1.9 }
                let sig = fillEvents.map { "\($0.voice.rawValue)@\(Int($0.position * 8))" }.joined(separator: ",")
                signatures.insert(sig)
            }
        }
        XCTAssertGreaterThanOrEqual(signatures.count, 4,
                                    "16 fills should produce several distinct phrases, got \(signatures.count)")
    }

    func testFillsRespectComplexityGate() {
        var gen = GrooveGenerator(seed: 5)
        let spec = GrooveSpec(style: .pop, complexity: 0.1, fillEveryBars: 2)
        for i in 0..<16 {
            let bar = gen.bar(index: i, spec: spec)
            if bar.isFill {
                // Low complexity: fills stay short (start in the last beat of the bar).
                let fillEvents = bar.events.filter { [DrumVoice.tomHigh, .tomMid, .tomLow].contains($0.voice) }
                for e in fillEvents {
                    XCTAssertGreaterThanOrEqual(e.position, 2.9, "simple drummers play short fills")
                }
            }
        }
    }
}
