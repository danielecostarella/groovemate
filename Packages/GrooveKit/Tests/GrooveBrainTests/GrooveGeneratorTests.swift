import XCTest
@testable import GrooveBrain
import GrooveModel

final class GrooveGeneratorTests: XCTestCase {

    func testEventsStayWithinBar() {
        for style in Style.allCases {
            var gen = GrooveGenerator(seed: 42)
            let spec = GrooveSpec(style: style, tightness: 0, complexity: 1, intensity: 1, swing: 1)
            for i in 0..<16 {
                let bar = gen.bar(index: i, spec: spec)
                for e in bar.events {
                    XCTAssertGreaterThanOrEqual(e.position, 0, "\(style) bar \(i)")
                    XCTAssertLessThan(e.position, spec.beatsPerBar, "\(style) bar \(i)")
                    XCTAssertGreaterThan(e.velocity, 0)
                    XCTAssertLessThanOrEqual(e.velocity, 1)
                }
            }
        }
    }

    func testDeterministicForSeed() {
        var a = GrooveGenerator(seed: 7)
        var b = GrooveGenerator(seed: 7)
        let spec = GrooveSpec(style: .funk)
        for i in 0..<8 {
            XCTAssertEqual(a.bar(index: i, spec: spec).events, b.bar(index: i, spec: spec).events)
        }
    }

    func testFillLandsOnScheduledBars() {
        var gen = GrooveGenerator(seed: 1)
        let spec = GrooveSpec(style: .rock, fillEveryBars: 4)
        for i in 0..<16 {
            let bar = gen.bar(index: i, spec: spec)
            let expected = (i + 1) % 4 == 0 && i > 0
            XCTAssertEqual(bar.isFill, expected, "bar \(i)")
            if expected {
                XCTAssertTrue(bar.events.contains { [.tomHigh, .tomMid, .tomLow, .snare].contains($0.voice) && $0.position >= 2 })
            }
        }
        // Bar after a fill opens with a crash.
        var gen2 = GrooveGenerator(seed: 1)
        _ = (0..<4).map { gen2.bar(index: $0, spec: spec) }
        let after = gen2.bar(index: 4, spec: spec)
        XCTAssertTrue(after.events.contains { $0.voice == .crash && $0.position < 0.1 })
    }

    func testNoFillsWhenDisabled() {
        var gen = GrooveGenerator(seed: 3)
        let spec = GrooveSpec(style: .pop, fillEveryBars: 0)
        for i in 0..<12 {
            XCTAssertFalse(gen.bar(index: i, spec: spec).isFill)
        }
    }

    func testSwingDelaysOffbeats() {
        var gen = GrooveGenerator(seed: 5)
        // Machine tight so the only offset is swing.
        let straight = GrooveSpec(style: .rock, tightness: 1, complexity: 0, swing: 0, fillEveryBars: 0)
        let swung = GrooveSpec(style: .rock, tightness: 1, complexity: 0, swing: 1, fillEveryBars: 0)
        var gen2 = GrooveGenerator(seed: 5)
        let straightHats = gen.bar(index: 0, spec: straight).events.filter { $0.voice == .hatClosed }
        let swungHats = gen2.bar(index: 0, spec: swung).events.filter { $0.voice == .hatClosed }
        let straightOff = straightHats.first { abs($0.position - 0.5) < 0.1 }
        let swungOff = swungHats.first { abs($0.position - 0.5) < 0.3 }
        XCTAssertNotNil(straightOff)
        XCTAssertNotNil(swungOff)
        // Full swing moves the "and" of 1 from 0.5 to ~0.667.
        XCTAssertEqual(swungOff!.position, 0.5 + 0.5 / 3, accuracy: 0.02)
        XCTAssertEqual(straightOff!.position, 0.5, accuracy: 0.02)
    }

    func testComplexityAddsEvents() {
        var simpleGen = GrooveGenerator(seed: 9)
        var busyGen = GrooveGenerator(seed: 9)
        let simple = GrooveSpec(style: .funk, complexity: 0, fillEveryBars: 0)
        let busy = GrooveSpec(style: .funk, complexity: 1, fillEveryBars: 0)
        var simpleCount = 0, busyCount = 0
        for i in 0..<8 {
            simpleCount += simpleGen.bar(index: i, spec: simple).events.count
            busyCount += busyGen.bar(index: i, spec: busy).events.count
        }
        XCTAssertGreaterThan(busyCount, simpleCount)
    }

    func testIntensityRaisesVelocity() {
        var softGen = GrooveGenerator(seed: 11)
        var loudGen = GrooveGenerator(seed: 11)
        let soft = GrooveSpec(style: .rock, intensity: 0.1, fillEveryBars: 0)
        let loud = GrooveSpec(style: .rock, intensity: 1, fillEveryBars: 0)
        let softAvg = average(softGen.bar(index: 0, spec: soft).events.map(\.velocity))
        let loudAvg = average(loudGen.bar(index: 0, spec: loud).events.map(\.velocity))
        XCTAssertGreaterThan(loudAvg, softAvg + 0.1)
    }

    private func average(_ xs: [Double]) -> Double {
        xs.reduce(0, +) / Double(max(xs.count, 1))
    }
}
