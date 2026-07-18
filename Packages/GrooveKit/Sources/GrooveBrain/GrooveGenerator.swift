import Foundation
import GrooveModel

/// Turns a `GrooveSpec` into performed bars: complexity gating, intensity shaping,
/// swing, humanization, and periodic fills. Deterministic for a given seed.
public struct GrooveGenerator: Sendable {
    private var rng: SeededRandom

    public init(seed: UInt64) {
        self.rng = SeededRandom(seed: seed)
    }

    /// Generate bar `index` (0-based) of a performance.
    public mutating func bar(index: Int, spec rawSpec: GrooveSpec) -> BarPerformance {
        let spec = rawSpec.clamped()
        let template = PatternLibrary.template(for: spec.style)

        let isFillBar = spec.fillEveryBars > 0 && (index + 1) % spec.fillEveryBars == 0 && index > 0
        let barAfterFill = spec.fillEveryBars > 0 && index > 0 && index % spec.fillEveryBars == 0

        var events = groove(from: template, spec: spec)

        if barAfterFill {
            // Land the fill: crash + solid kick on the downbeat, and skip the first timekeeper hit.
            events.removeAll { $0.position < 0.26 && $0.voice == template.timekeeper }
            events.append(GrooveEvent(voice: .crash, position: 0, velocity: 0.65 + 0.3 * spec.intensity))
            events.append(GrooveEvent(voice: .kick, position: 0, velocity: 0.95))
        }

        if isFillBar {
            let fillStart = fillStartBeat(spec: spec)
            events.removeAll { $0.position >= fillStart - 0.01 }
            events.append(contentsOf: makeFill(from: fillStart, spec: spec))
        }

        events = swing(events, template: template, spec: spec)
        events = humanize(events, spec: spec)

        return BarPerformance(events: events, beatsPerBar: spec.beatsPerBar, isFill: isFillBar)
    }

    // MARK: - Groove body

    private mutating func groove(from template: GrooveTemplate, spec: GrooveSpec) -> [GrooveEvent] {
        var out: [GrooveEvent] = []
        let escalate = spec.intensity > 0.8 && (spec.style == .rock || spec.style == .pop)

        for e in template.events {
            guard spec.complexity >= e.minComplexity else { continue }
            if e.probability < 1 {
                // Busier drummers take their optional ornaments more often.
                let p = e.probability * (0.6 + 0.8 * spec.complexity)
                guard rng.unit() < min(p, 1) else { continue }
            }

            var voice = e.voice
            // At full throttle the rock/pop timekeeper opens up.
            if escalate, voice == .hatClosed {
                voice = e.accent || e.position.truncatingRemainder(dividingBy: 1) == 0 ? .hatOpen : .hatClosed
            }

            out.append(GrooveEvent(voice: voice, position: e.position, velocity: shapedVelocity(e, spec: spec)))
        }
        return out
    }

    private func shapedVelocity(_ e: TemplateEvent, spec: GrooveSpec) -> Double {
        // Intensity scales unaccented notes strongly, accents (backbeats) mildly.
        let floorGain = e.accent ? 0.75 : 0.45
        let gain = floorGain + (1 - floorGain) * (0.35 + 0.65 * spec.intensity) / 1.0
        return min(e.velocity * gain * (0.75 + 0.5 * spec.intensity), 1)
    }

    // MARK: - Fills

    private func fillStartBeat(spec: GrooveSpec) -> Double {
        // Bigger, busier drummers start fills earlier.
        if spec.complexity > 0.75 && spec.intensity > 0.6 { return spec.beatsPerBar - 2 }
        if spec.complexity < 0.3 { return spec.beatsPerBar - 0.5 }
        return spec.beatsPerBar - 1
    }

    private mutating func makeFill(from start: Double, spec: GrooveSpec) -> [GrooveEvent] {
        let end = spec.beatsPerBar
        var out: [GrooveEvent] = []
        // Descending voice ladder: snare → toms, weighted by how far into the fill we are.
        let ladder: [DrumVoice] = [.snare, .tomHigh, .tomMid, .tomLow]
        let triplet = spec.swing > 0.5
        let step = triplet ? 1.0 / 3.0 : (spec.complexity > 0.5 ? 0.25 : 0.5)

        var pos = start
        while pos < end - 0.001 {
            let progress = (pos - start) / max(end - start, 0.001)
            let voiceIndex = min(Int(progress * Double(ladder.count)), ladder.count - 1)
            // Sparse fills drop some strokes; dense fills play through.
            let keep = spec.complexity > 0.6 || rng.unit() < 0.85
            if keep {
                let vel = 0.55 + 0.35 * progress + 0.15 * spec.intensity
                out.append(GrooveEvent(voice: ladder[voiceIndex], position: pos, velocity: min(vel, 1)))
            }
            pos += step
        }
        // Keep the kick anchored under the fill.
        out.append(GrooveEvent(voice: .kick, position: start == 0 ? 0 : start, velocity: 0.85))
        return out
    }

    // MARK: - Feel

    private func swing(_ events: [GrooveEvent], template: GrooveTemplate, spec: GrooveSpec) -> [GrooveEvent] {
        guard spec.swing > 0.01 else { return events }
        let sub = template.swingSubdivision
        return events.map { e in
            var e = e
            let phase = e.position.truncatingRemainder(dividingBy: sub * 2)
            // Offbeat of the swung subdivision: delay toward the triplet position.
            if abs(phase - sub) < 0.01 {
                e.position += spec.swing * sub / 3.0
            }
            return e
        }
    }

    private mutating func humanize(_ events: [GrooveEvent], spec: GrooveSpec) -> [GrooveEvent] {
        let timingSigma = (1 - spec.tightness) * 0.022 // beats
        let velocitySigma = 0.03 + (1 - spec.tightness) * 0.05
        return events.map { e in
            var e = e
            var offset = rng.gaussian() * timingSigma
            // The pocket: snare and hats sit behind/ahead; kick stays anchored.
            if e.voice != .kick && e.voice != .crash {
                offset += spec.pocketOffset
            }
            e.position = max(e.position + offset, 0)
            if e.position >= spec.beatsPerBar { e.position = spec.beatsPerBar - 0.01 }
            e.velocity = min(max(e.velocity + rng.gaussian() * velocitySigma, 0.05), 1)
            return e
        }
    }
}
