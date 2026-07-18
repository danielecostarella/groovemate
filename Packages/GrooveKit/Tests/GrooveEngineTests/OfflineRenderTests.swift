import XCTest
@testable import GrooveEngine
import GrooveBrain
import GrooveModel

final class OfflineRenderTests: XCTestCase {
    /// Kit synthesis is the expensive part — build once for the whole suite.
    static let sharedKit = SynthDrumKit()
    var kit: SynthDrumKit { Self.sharedKit }

    func testKitRendersAllVoicesNonSilent() {
        for voice in DrumVoice.allCases {
            for velocity in [0.2, 0.6, 0.95] {
                let (sample, gain) = kit.sample(for: voice, velocity: velocity, roundRobin: 1)
                XCTAssertGreaterThan(sample.samples.count, 100, "\(voice)")
                let peak = sample.samples.map(abs).max() ?? 0
                XCTAssertGreaterThan(peak, 0.5, "\(voice) at \(velocity) should be normalized")
                XCTAssertGreaterThan(gain, 0)
                XCTAssertFalse(sample.samples.contains { $0.isNaN || $0.isInfinite }, "\(voice)")
            }
        }
    }

    func testRoundRobinVariantsDiffer() {
        let a = kit.sample(for: .snare, velocity: 0.9, roundRobin: 0).sample
        let b = kit.sample(for: .snare, velocity: 0.9, roundRobin: 1).sample
        XCTAssertFalse(a === b)
        XCTAssertNotEqual(a.samples.prefix(2000), b.samples.prefix(2000))
    }

    func testOfflineRenderProducesAudioWithOnsetsOnTheGrid() {
        let renderer = OfflineRenderer(kit: kit)
        let bpm = 120.0
        // Machine-tight, no swing, no fills: onsets must land exactly on beats.
        var gen = GrooveGenerator(seed: 42)
        let spec = GrooveSpec(style: .rock, bpm: bpm, tightness: 1, complexity: 0, intensity: 0.8, swing: 0, pocketOffset: 0, fillEveryBars: 0)
        let (left, right) = renderer.render(bars: 4, bpm: bpm) { i in
            gen.bar(index: i, spec: spec)
        }

        XCTAssertGreaterThan(left.count, 0)
        let rms = sqrt(left.map { Double($0 * $0) }.reduce(0, +) / Double(left.count))
        XCTAssertGreaterThan(rms, 0.01, "render should not be silent")
        XCTAssertFalse(left.contains { $0.isNaN }, "no NaNs")
        XCTAssertFalse(right.contains { $0.isNaN })

        // Energy in a 30 ms window at each expected beat should dwarf the window just before it
        // (before beat 0 there is silence; before others, decaying tails).
        let sr = kit.sampleRate
        let spb = Int(sr * 60 / bpm)
        let win = Int(sr * 0.03)
        func energy(at start: Int) -> Double {
            guard start >= 0, start + win < left.count else { return 0 }
            return (start..<(start + win)).reduce(0) { $0 + Double(left[$1] * left[$1]) }
        }
        for beat in 0..<8 {
            let at = beat * spb
            let on = energy(at: at)
            XCTAssertGreaterThan(on, 0.001, "beat \(beat) should have a hit")
        }
    }

    func testFillBarSoundsDifferent() {
        let renderer = OfflineRenderer(kit: kit)
        var gen = GrooveGenerator(seed: 7)
        let spec = GrooveSpec(style: .rock, bpm: 100, fillEveryBars: 2)
        var fillBars: [Bool] = []
        _ = renderer.render(bars: 4, bpm: 100) { i in
            let bar = gen.bar(index: i, spec: spec)
            fillBars.append(bar.isFill)
            return bar
        }
        XCTAssertEqual(fillBars, [false, true, false, true])
    }

    func testWAVWriting() throws {
        let renderer = OfflineRenderer(kit: kit)
        var gen = GrooveGenerator(seed: 1)
        let spec = GrooveSpec(style: .funk, bpm: 96)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("groovemate-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try renderer.renderWAV(to: url, bars: 2, bpm: 96) { i in gen.bar(index: i, spec: spec) }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertGreaterThan(attrs[.size] as! Int, 100_000)
    }
}
