import XCTest
@testable import GrooveEngine
import GrooveBrain
import GrooveModel

/// Verifies the "bark" self-choke: a hatHalfOpen hit rings for a short,
/// bounded time regardless of what (if anything) plays after it — the
/// technical difference between a bark and a fully sustained open hat.
final class HatBarkTests: XCTestCase {

    func testHatHalfOpenSelfChokesEvenWithNothingAfter() {
        let kit = SynthDrumKit()
        let renderer = OfflineRenderer(kit: kit)
        // A single bark, nothing else in the bar to choke it.
        let bar = BarPerformance(events: [GrooveEvent(voice: .hatHalfOpen, position: 0, velocity: 0.9)])
        let (left, _) = renderer.render(bars: 1, bpm: 60) { _ in bar }

        let sr = kit.sampleRate
        let barkWindowEnd = Int(sr * 0.09) + Int(sr * 0.06) // self-choke point + generous fade tail
        let farAfter = Int(sr * 0.6) // well past a bark, well within an open hat's natural ring

        let earlyEnergy = rms(left, from: 0, to: barkWindowEnd)
        let lateEnergy = rms(left, from: farAfter, to: farAfter + Int(sr * 0.1))
        XCTAssertGreaterThan(earlyEnergy, 0.001, "the bark should sound at all")
        XCTAssertLessThan(lateEnergy, earlyEnergy * 0.05,
                          "a bark must be inaudible well before an open hat would naturally ring out")
    }

    func testHatOpenRingsPastTheBarkWindow() {
        let kit = SynthDrumKit()
        let renderer = OfflineRenderer(kit: kit)
        let bar = BarPerformance(events: [GrooveEvent(voice: .hatOpen, position: 0, velocity: 0.9)])
        let (left, _) = renderer.render(bars: 1, bpm: 60) { _ in bar }

        let sr = kit.sampleRate
        let pastBarkWindow = Int(sr * 0.15)
        let energy = rms(left, from: pastBarkWindow, to: pastBarkWindow + Int(sr * 0.1))
        XCTAssertGreaterThan(energy, 0.001, "an un-choked open hat should still be ringing past the bark window")
    }

    private func rms(_ x: [Float], from: Int, to: Int) -> Double {
        guard from >= 0, to <= x.count, from < to else { return 0 }
        let slice = x[from..<to]
        return sqrt(slice.reduce(0.0) { $0 + Double($1 * $1) } / Double(slice.count))
    }
}
