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
}
