import XCTest
@testable import GrooveEngine
import GrooveBrain
import GrooveModel

final class SampledDrumKitTests: XCTestCase {
    /// The curated MuldjordKit lives in the repo, outside the package — reach it from this file.
    static let kitURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // file → GrooveEngineTests
        .deletingLastPathComponent() // → Tests
        .deletingLastPathComponent() // → GrooveKit
        .deletingLastPathComponent() // → Packages
        .deletingLastPathComponent() // → repo root
        .appendingPathComponent("Resources/DrumKits/MuldjordKit")

    static var sharedKit: SampledDrumKit!

    override class func setUp() {
        super.setUp()
        sharedKit = try? SampledDrumKit(directory: kitURL)
    }

    private var kit: SampledDrumKit {
        guard let k = Self.sharedKit else {
            XCTFail("MuldjordKit failed to load from \(Self.kitURL.path)")
            fatalError()
        }
        return k
    }

    func testLoadsAllVoices() throws {
        XCTAssertEqual(kit.sampleRate, 44100)
        XCTAssertTrue(kit.usesBakedStereoImage)
        for voice in DrumVoice.allCases {
            for velocity in [0.1, 0.5, 0.95] {
                let (sample, gain) = kit.sample(for: voice, velocity: velocity, roundRobin: 0)
                XCTAssertGreaterThan(sample.frameCount, 1000, "\(voice)")
                XCTAssertGreaterThan(gain, 0)
                let peak = sample.left.map(abs).max() ?? 0
                XCTAssertGreaterThan(peak, 0.005, "\(voice) at v=\(velocity) should not be silent")
                XCTAssertFalse(sample.left.contains { $0.isNaN }, "\(voice)")
            }
        }
    }

    func testVelocityLayersDiffer() {
        let soft = kit.sample(for: .snare, velocity: 0.1, roundRobin: 0).sample
        let hard = kit.sample(for: .snare, velocity: 0.95, roundRobin: 0).sample
        XCTAssertFalse(soft === hard, "soft and hard snare should come from different layers")
        let softPeak = soft.left.map(abs).max() ?? 0
        let hardPeak = hard.left.map(abs).max() ?? 0
        XCTAssertGreaterThan(hardPeak, softPeak, "harder layer should be louder")
    }

    func testRoundRobinDiffers() {
        let a = kit.sample(for: .hatClosed, velocity: 0.6, roundRobin: 0).sample
        let b = kit.sample(for: .hatClosed, velocity: 0.6, roundRobin: 1).sample
        XCTAssertFalse(a === b)
    }

    func testStereoImagePresent() {
        // A real stereo recording: channels must not be identical.
        let s = kit.sample(for: .crash, velocity: 0.9, roundRobin: 0).sample
        XCTAssertNotEqual(s.left.prefix(5000), s.right.prefix(5000))
    }

    func testOfflineRenderWithSampledKit() {
        let renderer = OfflineRenderer(kit: kit)
        var gen = GrooveGenerator(seed: 42)
        let spec = GrooveSpec(style: .rock, bpm: 110)
        let (left, right) = renderer.render(bars: 4, bpm: 110) { i in
            gen.bar(index: i, spec: spec)
        }
        let rms = sqrt(left.map { Double($0 * $0) }.reduce(0, +) / Double(left.count))
        XCTAssertGreaterThan(rms, 0.005)
        XCTAssertFalse(left.contains { $0.isNaN })
        XCTAssertFalse(right.contains { $0.isNaN })
    }

    // MARK: - Round robin depth (the "machine gun" fix)

    func testHeavilyRepeatedVoicesHaveDeepRoundRobin() {
        // The closed hat and ghost-note snare get struck many times per bar;
        // too few variants and the ear catches the repeat within a few bars.
        XCTAssertGreaterThanOrEqual(kit.roundRobinCount, 4)
    }

    // MARK: - Velocity-layer crossfade (no hard timbre cutover)

    func testMidVelocityBlendsTwoLayers() {
        // Snare has 4 layers; a velocity that lands near an internal boundary
        // should blend, not cut over.
        let blended = kit.layeredSamples(for: .snare, velocity: 0.5, roundRobin: 0)
        XCTAssertEqual(blended.count, 2, "a boundary-straddling hit should sound two layers at once")
        for (_, gain) in blended {
            XCTAssertGreaterThan(gain, 0)
        }
    }

    func testDeepInsideALayerDoesNotBlend() {
        // Just above the bottom of the softest snare layer: not near any boundary.
        let single = kit.layeredSamples(for: .snare, velocity: 0.03, roundRobin: 0)
        XCTAssertEqual(single.count, 1)
    }

    func testCrossfadeIsEqualPowerAtMidpoint() {
        // hatClosed has 3 layers (boundary at v=1/3); 0.2833 sits exactly at
        // the midpoint of the blend-up zone (30% of a layer's band, centered
        // on the boundary) — both halves should carry ~equal weight there.
        let blend = kit.layeredSamples(for: .hatClosed, velocity: 0.2833, roundRobin: 0)
        XCTAssertEqual(blend.count, 2)
        XCTAssertEqual(Double(blend[0].gain), Double(blend[1].gain), accuracy: 0.05)
    }

    func testCrossfadeShiftsWeightAcrossTheBoundary() {
        // Just after entering the blend zone, the lower layer should dominate;
        // just before finishing it, the upper layer should.
        let early = kit.layeredSamples(for: .hatClosed, velocity: 0.24, roundRobin: 0)
        let late = kit.layeredSamples(for: .hatClosed, velocity: 0.32, roundRobin: 0)
        XCTAssertEqual(early.count, 2)
        XCTAssertEqual(late.count, 2)
        XCTAssertGreaterThan(early[0].gain, early[1].gain, "early in the blend, the lower layer should lead")
        XCTAssertGreaterThan(late[1].gain, late[0].gain, "late in the blend, the upper layer should lead")
    }

    func testSingleLayerVoiceNeverBlends() {
        // hatPedal has only one layer — nothing to blend into.
        for v in [0.0, 0.3, 0.7, 1.0] {
            XCTAssertEqual(kit.layeredSamples(for: .hatPedal, velocity: v, roundRobin: 0).count, 1)
        }
    }
}
