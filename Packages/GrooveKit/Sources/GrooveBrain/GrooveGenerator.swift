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

        var events = groove(from: template, spec: spec, barIndex: index)

        let phraseStart = index % 4 == 0 && index > 0
        if barAfterFill {
            // Land the fill: crash + solid kick on the downbeat, and skip the first timekeeper hit.
            events.removeAll { $0.position < 0.26 && $0.voice == template.timekeeper }
            events.append(GrooveEvent(voice: .crash, position: 0, velocity: 0.65 + 0.3 * spec.intensity))
            events.append(GrooveEvent(voice: .kick, position: 0, velocity: 0.95))
        } else if phraseStart, spec.intensity > 0.82, rng.unit() < 0.7 {
            // Big arrival into a new 4-bar phrase: a chorus needs a crash (or,
            // for a jazz drummer, a ride-bell accent instead of a wash).
            events.removeAll { $0.position < 0.26 && $0.voice == template.timekeeper }
            let arrival: DrumVoice = spec.style == .jazz ? .rideBell : .crash
            events.append(GrooveEvent(voice: arrival, position: 0, velocity: 0.6 + 0.35 * spec.intensity))
            events.append(GrooveEvent(voice: .kick, position: 0, velocity: 0.9))
        }

        if isFillBar {
            let phrase = pickFillPhrase(spec: spec)
            let fillStart = spec.beatsPerBar - phrase.beats
            events.removeAll { $0.position >= fillStart - 0.01 }
            events.append(contentsOf: playFill(phrase, from: fillStart, spec: spec))
        }

        events = swing(events, template: template, spec: spec)
        events = humanize(events, spec: spec)

        return BarPerformance(events: events, beatsPerBar: spec.beatsPerBar, isFill: isFillBar)
    }

    // MARK: - Groove body

    private mutating func groove(from template: GrooveTemplate, spec: GrooveSpec, barIndex: Int) -> [GrooveEvent] {
        var out: [GrooveEvent] = []
        // At full throttle a hat-timekeeping drummer starts barking accents
        // instead of just closing louder — a real pattern change, not just volume.
        let barks = spec.intensity > 0.8 && template.timekeeper == .hatClosed
        // A quiet ride player leans on the bell for accents once the energy climbs.
        let ridesBell = spec.intensity > 0.75 && template.timekeeper == .ride
        // Rimshot cracks the backbeat once the drummer commits to playing hard;
        // a section-wide choice, not a per-note coin flip.
        let rimshots = spec.intensity > 0.72 && spec.style != .jazz
        // Drummers phrase in fours: the last bar of the phrase lifts a little.
        let phraseEnd = barIndex % 4 == 3
        // Correlated dynamics: the whole bar breathes together, not note by note.
        let barDrift = rng.gaussian() * 0.03

        for e in template.events {
            guard spec.complexity >= e.minComplexity, spec.complexity <= e.maxComplexity else { continue }
            guard spec.intensity >= e.minIntensity, spec.intensity <= e.maxIntensity else { continue }
            if e.probability < 1 {
                // Busier drummers take their optional ornaments more often,
                // and everyone ornaments more at the end of a phrase.
                var p = e.probability * (0.6 + 0.8 * spec.complexity)
                if phraseEnd { p *= 1.4 }
                guard rng.unit() < min(p, 1) else { continue }
            }

            var voice = e.voice
            if barks, voice == .hatClosed {
                voice = e.accent || e.position.truncatingRemainder(dividingBy: 1) == 0 ? .hatHalfOpen : .hatClosed
            } else if ridesBell, voice == .ride, e.accent {
                voice = .rideBell
            } else if rimshots, voice == .snare, e.accent {
                voice = .snareRim
            }

            let velocity = min(max(shapedVelocity(e, spec: spec) * (1 + barDrift), 0.05), 1)
            out.append(GrooveEvent(voice: voice, position: e.position, velocity: velocity))
        }

        // Phrase-end lift: a hat bark into bar 1, even without a fill scheduled.
        if phraseEnd, spec.complexity > 0.35, spec.style != .jazz,
           !out.contains(where: { ($0.voice == .hatOpen || $0.voice == .hatHalfOpen) && $0.position >= 3.4 }),
           rng.unit() < 0.5 {
            out.append(GrooveEvent(voice: .hatHalfOpen, position: 3.5, velocity: 0.5 + 0.2 * spec.intensity))
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

    /// A fill is a phrase, not a ladder: authored gestures with accents, rests
    /// and direction, so no two fill bars feel stamped from the same die.
    struct FillPhrase {
        /// Length in beats, counted back from the end of the bar.
        var beats: Double
        var minComplexity: Double
        /// Prefer this phrase when the groove is swung.
        var swung: Bool
        /// (offset from fill start, voice, velocity, probability)
        var strokes: [(Double, DrumVoice, Double, Double)]
    }

    private static let fillPhrases: [FillPhrase] = [
        // Two quick hits into the downbeat — barely a fill, all attitude.
        FillPhrase(beats: 0.5, minComplexity: 0, swung: false, strokes: [
            (0.0, .snare, 0.7, 1), (0.25, .tomLow, 0.9, 1),
        ]),
        // Classic snare drag: ghost-ghost-ACCENT.
        FillPhrase(beats: 0.5, minComplexity: 0, swung: false, strokes: [
            (0.0, .snareGhost, 0.3, 1), (0.125, .snareGhost, 0.35, 1), (0.25, .snare, 0.95, 1),
        ]),
        // One-beat single-stroke run with a syncopated hole before the last note.
        FillPhrase(beats: 1, minComplexity: 0.2, swung: false, strokes: [
            (0.0, .snare, 0.8, 1), (0.25, .snare, 0.55, 0.8), (0.5, .tomMid, 0.75, 1), (0.75, .tomLow, 0.95, 1),
        ]),
        // "Down the stairs, skip a step": snare pair, rest, tom answer.
        FillPhrase(beats: 1, minComplexity: 0.25, swung: false, strokes: [
            (0.0, .snare, 0.85, 1), (0.25, .tomHigh, 0.6, 0.85), (0.625, .tomMid, 0.7, 1), (0.75, .tomLow, 0.9, 1),
        ]),
        // Kick-snare conversation, funk vocabulary.
        FillPhrase(beats: 1, minComplexity: 0.35, swung: false, strokes: [
            (0.0, .snare, 0.8, 1), (0.25, .kick, 0.75, 1), (0.375, .snareGhost, 0.35, 0.7),
            (0.5, .snare, 0.6, 1), (0.75, .kick, 0.8, 1), (0.875, .snare, 0.9, 1),
        ]),
        // Two-beat build: rest first, then a rising run that lands hard.
        FillPhrase(beats: 2, minComplexity: 0.45, swung: false, strokes: [
            (0.5, .snareGhost, 0.35, 0.8), (0.75, .snare, 0.6, 1),
            (1.0, .snare, 0.75, 1), (1.25, .tomHigh, 0.7, 1),
            (1.5, .tomMid, 0.8, 1), (1.625, .tomMid, 0.55, 0.6), (1.75, .tomLow, 0.98, 1),
        ]),
        // Two-beat 16ths around the kit with accents on the moves, not every note.
        FillPhrase(beats: 2, minComplexity: 0.6, swung: false, strokes: [
            (0.0, .snare, 0.9, 1), (0.25, .snareGhost, 0.4, 0.9), (0.5, .snare, 0.6, 1), (0.75, .snare, 0.5, 0.8),
            (1.0, .tomHigh, 0.85, 1), (1.25, .tomHigh, 0.5, 0.7), (1.5, .tomLow, 0.8, 1), (1.75, .tomLow, 0.95, 1),
        ]),
        // Triplet roll — the swung/blues answer.
        FillPhrase(beats: 1, minComplexity: 0.2, swung: true, strokes: [
            (0.0, .snare, 0.8, 1), (1.0 / 3, .snare, 0.6, 1), (2.0 / 3, .tomMid, 0.75, 1),
        ]),
        // Two-beat triplet tumble around the kit.
        FillPhrase(beats: 2, minComplexity: 0.45, swung: true, strokes: [
            (0.0, .snare, 0.85, 1), (1.0 / 3, .snareGhost, 0.4, 0.8), (2.0 / 3, .snare, 0.65, 1),
            (1.0, .tomHigh, 0.8, 1), (4.0 / 3, .tomMid, 0.7, 1), (5.0 / 3, .tomLow, 0.95, 1),
        ]),
    ]

    private var lastFillIndex = -1

    private mutating func pickFillPhrase(spec: GrooveSpec) -> FillPhrase {
        let swung = spec.swing > 0.45
        var candidates = Self.fillPhrases.indices.filter { i in
            let p = Self.fillPhrases[i]
            guard spec.complexity >= p.minComplexity else { return false }
            // Swung grooves prefer triplet phrases but can borrow straight ones; straight grooves never borrow triplets.
            return swung || !p.swung
        }
        // Don't play the same fill twice in a row if there's any alternative.
        if candidates.count > 1 {
            candidates.removeAll { $0 == lastFillIndex }
        }
        var index = candidates[Int(rng.unit() * Double(candidates.count)) % candidates.count]
        // Swung grooves lean into their triplet vocabulary.
        if swung, rng.unit() < 0.6, let tripIndex = candidates.first(where: { Self.fillPhrases[$0].swung }) {
            index = tripIndex
        }
        lastFillIndex = index
        return Self.fillPhrases[index]
    }

    private mutating func playFill(_ phrase: FillPhrase, from start: Double, spec: GrooveSpec) -> [GrooveEvent] {
        var out: [GrooveEvent] = []
        for (offset, voice, velocity, probability) in phrase.strokes {
            if probability < 1, rng.unit() > probability { continue }
            let progress = offset / max(phrase.beats, 0.001)
            // Drummers push through fills: a hair ahead as the phrase develops.
            let rush = -progress * 0.018 * (1 - spec.tightness * 0.5)
            let vel = velocity * (0.8 + 0.35 * spec.intensity) + rng.gaussian() * 0.04
            out.append(GrooveEvent(
                voice: voice,
                position: start + offset + rush,
                velocity: min(max(vel, 0.1), 1)
            ))
        }
        // Keep the kick anchored under longer fills so the bottom never drops out.
        if phrase.beats >= 1, !phrase.strokes.contains(where: { $0.1 == .kick }) {
            out.append(GrooveEvent(voice: .kick, position: start, velocity: 0.8))
        }
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
