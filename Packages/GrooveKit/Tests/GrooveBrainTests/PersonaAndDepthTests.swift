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

    // MARK: - Verse/chorus: energy changes the actual pattern

    func testHighIntensityAddsRimshotOnBackbeat() {
        var softGen = GrooveGenerator(seed: 12)
        var loudGen = GrooveGenerator(seed: 12)
        let soft = GrooveSpec(style: .rock, intensity: 0.4, fillEveryBars: 0)
        let loud = GrooveSpec(style: .rock, intensity: 0.9, fillEveryBars: 0)
        let softBar = softGen.bar(index: 0, spec: soft)
        let loudBar = loudGen.bar(index: 0, spec: loud)
        XCTAssertTrue(softBar.events.contains { $0.voice == .snare && abs($0.position - 1.0) < 0.05 })
        XCTAssertFalse(softBar.events.contains { $0.voice == .snareRim })
        XCTAssertTrue(loudBar.events.contains { $0.voice == .snareRim }, "loud backbeats should crack as a rimshot")
    }

    func testJazzNeverGetsRimshot() {
        var gen = GrooveGenerator(seed: 8)
        let spec = GrooveSpec(style: .jazz, intensity: 0.95, fillEveryBars: 0)
        for i in 0..<8 {
            XCTAssertFalse(gen.bar(index: i, spec: spec).events.contains { $0.voice == .snareRim })
        }
    }

    func testHighIntensityRockBarksInsteadOfOpening() {
        var gen = GrooveGenerator(seed: 14)
        let spec = GrooveSpec(style: .rock, complexity: 0.5, intensity: 0.9, fillEveryBars: 0)
        var sawBark = false
        for i in 0..<8 {
            let bar = gen.bar(index: i, spec: spec)
            XCTAssertFalse(bar.events.contains { $0.voice == .hatOpen }, "full throttle should bark, not sustain open")
            if bar.events.contains(where: { $0.voice == .hatHalfOpen }) { sawBark = true }
        }
        XCTAssertTrue(sawBark)
    }

    func testJazzLeansOnRideBellWhenLoud() {
        var quietGen = GrooveGenerator(seed: 9)
        var loudGen = GrooveGenerator(seed: 9)
        let quiet = GrooveSpec(style: .jazz, intensity: 0.3, fillEveryBars: 0)
        let loud = GrooveSpec(style: .jazz, intensity: 0.9, fillEveryBars: 0)
        var quietBell = 0, loudBell = 0
        for i in 0..<8 {
            quietBell += quietGen.bar(index: i, spec: quiet).events.filter { $0.voice == .rideBell }.count
            loudBell += loudGen.bar(index: i, spec: loud).events.filter { $0.voice == .rideBell }.count
        }
        XCTAssertGreaterThan(loudBell, quietBell)
    }

    func testChorusAddsExtraKicksNotJustLouderNotes() {
        var verseGen = GrooveGenerator(seed: 17)
        var chorusGen = GrooveGenerator(seed: 17)
        let verse = GrooveSpec(style: .funk, complexity: 0.5, intensity: 0.3, fillEveryBars: 0)
        let chorus = GrooveSpec(style: .funk, complexity: 0.5, intensity: 0.9, fillEveryBars: 0)
        var verseKicks = 0, chorusKicks = 0
        for i in 0..<8 {
            verseKicks += verseGen.bar(index: i, spec: verse).events.filter { $0.voice == .kick }.count
            chorusKicks += chorusGen.bar(index: i, spec: chorus).events.filter { $0.voice == .kick }.count
        }
        XCTAssertGreaterThan(chorusKicks, verseKicks, "the chorus should add real kick hits, not just play louder")
    }

    func testLoudArrivalIntoNewPhraseCrashes() {
        var gen = GrooveGenerator(seed: 3)
        let spec = GrooveSpec(style: .rock, intensity: 0.95, fillEveryBars: 0)
        var sawArrivalCrash = false
        for i in 0..<12 {
            let bar = gen.bar(index: i, spec: spec)
            if i % 4 == 0, i > 0, bar.events.contains(where: { $0.voice == .crash && $0.position < 0.1 }) {
                sawArrivalCrash = true
            }
        }
        XCTAssertTrue(sawArrivalCrash, "a loud drummer should crash into a new 4-bar phrase")
    }
}
