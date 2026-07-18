import Foundation
import GrooveModel

/// A fully synthesized acoustic-style kit. Every articulation is rendered to PCM
/// at init — 3 velocity layers × round-robin variants — so playback is pure mixing.
/// License-free and offline; a sampled kit can replace it behind `DrumKit`.
public struct SynthDrumKit: DrumKit {
    public let sampleRate: Double
    public let roundRobinCount = 3
    public let tone: KitTone

    /// [voice: [layer][roundRobin]]
    private let bank: [DrumVoice: [[KitSample]]]

    private static let layerCount = 3

    public init(tone: KitTone = KitTone(), sampleRate: Double = 48000) {
        self.tone = tone
        self.sampleRate = sampleRate
        let voices = DrumVoice.allCases
        let rrCount = roundRobinCount
        var results = [[[KitSample]]](repeating: [], count: voices.count)
        results.withUnsafeMutableBufferPointer { buf in
            let ptr = UnsafeMutableBufferPointer(rebasing: buf[...])
            DispatchQueue.concurrentPerform(iterations: voices.count) { v in
                let voice = voices[v]
                var layers: [[KitSample]] = []
                for layer in 0..<Self.layerCount {
                    var rrs: [KitSample] = []
                    for rr in 0..<rrCount {
                        var rng = SynthRandom(seed: Self.seed(voice: voice, layer: layer, rr: rr))
                        let samples = Self.render(voice: voice, layer: layer, tone: tone, sr: sampleRate, rng: &rng)
                        rrs.append(KitSample(samples: samples))
                    }
                    layers.append(rrs)
                }
                ptr[v] = layers
            }
        }
        var bank: [DrumVoice: [[KitSample]]] = [:]
        for (v, voice) in voices.enumerated() {
            bank[voice] = results[v]
        }
        self.bank = bank
    }

    public func sample(for voice: DrumVoice, velocity: Double, roundRobin: Int) -> (sample: KitSample, gain: Float) {
        let v = min(max(velocity, 0), 1)
        let layer = v < 0.4 ? 0 : (v < 0.75 ? 1 : 2)
        let layers = bank[voice]!
        let s = layers[layer][roundRobin % roundRobinCount]
        // Perceptual velocity curve on top of the timbral layers.
        let gain = Float(0.2 + 0.8 * pow(v, 1.3))
        return (s, gain)
    }

    private static func seed(voice: DrumVoice, layer: Int, rr: Int) -> UInt64 {
        var h: UInt64 = 0xCAFEBABE
        for b in voice.rawValue.utf8 { h = h &* 31 &+ UInt64(b) }
        return h &+ UInt64(layer * 977) &+ UInt64(rr * 7919)
    }

    // MARK: - Synthesis

    private static func render(voice: DrumVoice, layer: Int, tone: KitTone, sr: Double, rng: inout SynthRandom) -> [Float] {
        // Tuning shifts fundamentals ±25%; brightness opens filters and transients.
        let tune = pow(2.0, (tone.tuning - 0.5) * 0.6)
        let bright = 0.35 + 0.65 * tone.brightness
        let hard = 0.5 + 0.5 * Double(layer) / 2.0 // harder strokes: brighter, longer

        switch voice {
        case .kick:
            return kick(sr: sr, tune: tune, bright: bright, hard: hard, rng: &rng)
        case .snare:
            return snare(sr: sr, tune: tune, bright: bright, hard: hard, ghost: false, rng: &rng)
        case .snareGhost:
            return snare(sr: sr, tune: tune, bright: bright * 0.6, hard: hard * 0.6, ghost: true, rng: &rng)
        case .snareRim:
            return rim(sr: sr, tune: tune, bright: bright, rng: &rng)
        case .hatClosed:
            return hat(sr: sr, decay: 0.05 + 0.02 * hard, bright: bright, openness: 0, rng: &rng)
        case .hatOpen:
            return hat(sr: sr, decay: 0.35 + 0.25 * hard, bright: bright, openness: 1, rng: &rng)
        case .hatPedal:
            return hat(sr: sr, decay: 0.035, bright: bright * 0.7, openness: 0, rng: &rng)
        case .tomHigh:
            return tom(sr: sr, f: 190 * tune, decay: 0.28, hard: hard, rng: &rng)
        case .tomMid:
            return tom(sr: sr, f: 140 * tune, decay: 0.34, hard: hard, rng: &rng)
        case .tomLow:
            return tom(sr: sr, f: 100 * tune, decay: 0.42, hard: hard, rng: &rng)
        case .ride:
            return cymbal(sr: sr, decay: 1.3, bright: bright * 0.8, density: 0.35, hard: hard, rng: &rng)
        case .rideBell:
            return bell(sr: sr, tune: tune, hard: hard, rng: &rng)
        case .crash:
            return cymbal(sr: sr, decay: 1.6 + 0.4 * hard, bright: bright, density: 1.0, hard: hard, rng: &rng)
        }
    }

    private static func kick(sr: Double, tune: Double, bright: Double, hard: Double, rng: inout SynthRandom) -> [Float] {
        let dur = 0.5
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        let f0 = (120 + 60 * hard) * tune * rng.jitter(0.02)
        let f1 = 46.0 * tune
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            // Exponential pitch glide, fast at the attack.
            let f = f1 + (f0 - f1) * exp(-t / 0.045)
            phase += 2 * .pi * f / sr
            let body = sin(phase) * exp(-t / (0.11 + 0.05 * hard))
            // Beater click.
            let click = t < 0.004 ? rng.bipolar() * (0.5 + 0.8 * bright) * hard * exp(-t / 0.0012) : 0
            out[i] = Float(tanh((body * 1.35 + click) * 1.5))
        }
        return finished(out, sr: sr)
    }

    private static func snare(sr: Double, tune: Double, bright: Double, hard: Double, ghost: Bool, rng: inout SynthRandom) -> [Float] {
        let dur = ghost ? 0.14 : 0.24
        let n = Int(dur * sr)
        let modes: [(Double, Double)] = [(186 * tune, 1.0), (332 * tune, 0.6), (446 * tune, 0.35)]
        var oscs = modes.enumerated().map { SineOsc(freq: $1.0 * rng.staticDetune($0), sr: sr) }
        // Snare wires: band-limited noise.
        var noise = [Double](repeating: 0, count: n)
        for i in 0..<n { noise[i] = rng.bipolar() }
        lowpass(&noise, cutoff: (3000 + 6500 * bright) * (ghost ? 0.6 : 1), sr: sr)
        highpass(&noise, cutoff: 800, sr: sr)

        var out = [Float](repeating: 0, count: n)
        let bodyTau = ghost ? 0.03 : 0.045
        let wireTau = ghost ? 0.045 : 0.075 + 0.02 * hard
        let wireMix = ghost ? 0.55 : 0.75 + 0.15 * hard
        for i in 0..<n {
            let t = Double(i) / sr
            var body = 0.0
            for m in 0..<oscs.count {
                body += oscs[m].next() * modes[m].1
            }
            body *= exp(-t / bodyTau) * 0.5
            let wires = noise[i] * exp(-t / wireTau) * wireMix
            out[i] = Float(tanh((body + wires) * (ghost ? 1.1 : 1.6)))
        }
        return finished(out, sr: sr)
    }

    private static func rim(sr: Double, tune: Double, bright: Double, rng: inout SynthRandom) -> [Float] {
        let n = Int(0.09 * sr)
        var out = [Float](repeating: 0, count: n)
        var o1 = SineOsc(freq: 730 * tune, sr: sr)
        var o2 = SineOsc(freq: 1930 * tune, sr: sr)
        for i in 0..<n {
            let t = Double(i) / sr
            let ping = (o1.next() * 0.8 + o2.next() * 0.5) * exp(-t / 0.025)
            let click = t < 0.002 ? rng.bipolar() * bright : 0
            out[i] = Float(tanh(ping + click))
        }
        return finished(out, sr: sr)
    }

    private static func hat(sr: Double, decay: Double, bright: Double, openness: Double, rng: inout SynthRandom) -> [Float] {
        let dur = decay * 3
        let n = Int(dur * sr)
        // Inharmonic metallic partial stack (classic cymbal recipe).
        let baseFreqs = [3113.0, 4160, 5430, 6788, 8210, 9480]
        var oscs = baseFreqs.enumerated().map { SineOsc(freq: $1 * rng.staticDetune($0), sr: sr) }
        var noise = [Double](repeating: 0, count: n)
        for i in 0..<n { noise[i] = rng.bipolar() }
        highpass(&noise, cutoff: 6500 - 1500 * openness, sr: sr)

        var out = [Float](repeating: 0, count: n)
        let partialScale = 1.0 / Double(baseFreqs.count)
        for i in 0..<n {
            let t = Double(i) / sr
            var metal = 0.0
            for k in 0..<oscs.count { metal += oscs[k].next() }
            metal *= partialScale
            let env = exp(-t / decay)
            let sizzle = noise[i] * (0.5 + 0.5 * openness)
            out[i] = Float((metal * 0.6 + sizzle) * env * (0.5 + 0.5 * bright))
        }
        return finished(out, sr: sr)
    }

    private static func tom(sr: Double, f: Double, decay: Double, hard: Double, rng: inout SynthRandom) -> [Float] {
        let n = Int(decay * 3.5 * sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        var phase2 = 0.0
        let f0 = f * (1.4 + 0.2 * hard) * rng.jitter(0.015)
        for i in 0..<n {
            let t = Double(i) / sr
            let freq = f + (f0 - f) * exp(-t / 0.06)
            phase += 2 * .pi * freq / sr
            phase2 += 2 * .pi * freq * 1.59 / sr
            let body = sin(phase) + sin(phase2) * 0.25 * exp(-t / 0.05)
            let attack = t < 0.003 ? rng.bipolar() * 0.4 * hard : 0
            out[i] = Float(tanh((body * exp(-t / decay) + attack) * 1.3))
        }
        return finished(out, sr: sr)
    }

    private static func cymbal(sr: Double, decay: Double, bright: Double, density: Double, hard: Double, rng: inout SynthRandom) -> [Float] {
        let dur = decay * 1.5
        let n = Int(dur * sr)
        let baseFreqs = [1247.0, 1790, 2453, 3113, 4160, 5430, 6788, 8210]
        var oscs = baseFreqs.enumerated().map { SineOsc(freq: $1 * rng.staticDetune($0), sr: sr) }
        var noise = [Double](repeating: 0, count: n)
        for i in 0..<n { noise[i] = rng.bipolar() }
        highpass(&noise, cutoff: 3200, sr: sr)
        lowpass(&noise, cutoff: 4000 + 9000 * bright, sr: sr)

        var out = [Float](repeating: 0, count: n)
        let partialScale = 1.0 / Double(baseFreqs.count)
        for i in 0..<n {
            let t = Double(i) / sr
            var metal = 0.0
            for k in 0..<oscs.count { metal += oscs[k].next() }
            metal *= partialScale
            // Crash wash blooms slightly after the strike.
            let bloom = min(t / 0.02, 1.0)
            let env = exp(-t / decay) * bloom
            let wash = noise[i] * (0.6 + 0.7 * density)
            out[i] = Float(tanh((metal * 0.5 + wash) * env * (0.6 + 0.6 * hard)))
        }
        return finished(out, sr: sr)
    }

    private static func bell(sr: Double, tune: Double, hard: Double, rng: inout SynthRandom) -> [Float] {
        let n = Int(0.9 * sr)
        let freqs = [842.0 * tune, 1272 * tune, 2015 * tune, 3310 * tune]
        var oscs = freqs.enumerated().map { SineOsc(freq: $1 * rng.staticDetune($0), sr: sr) }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sr
            var s = 0.0
            for k in 0..<oscs.count {
                s += oscs[k].next() * (1.0 / Double(k + 1))
            }
            let strike = t < 0.002 ? rng.bipolar() * 0.3 * hard : 0
            out[i] = Float(tanh((s * 0.6 * exp(-t / 0.28) + strike) * 1.2))
        }
        return finished(out, sr: sr)
    }

    // MARK: - DSP helpers

    private static func lowpass(_ x: inout [Double], cutoff: Double, sr: Double) {
        let a = 1 - exp(-2 * .pi * cutoff / sr)
        var y = 0.0
        for i in 0..<x.count {
            y += a * (x[i] - y)
            x[i] = y
        }
    }

    private static func highpass(_ x: inout [Double], cutoff: Double, sr: Double) {
        let a = 1 - exp(-2 * .pi * cutoff / sr)
        var lp = 0.0
        for i in 0..<x.count {
            lp += a * (x[i] - lp)
            x[i] -= lp
        }
    }

    /// Normalize to a consistent peak and fade the last 40 ms so truncated tails never click.
    private static func finished(_ x: [Float], sr: Double) -> [Float] {
        var x = x
        let peak = x.map(abs).max() ?? 1
        if peak > 0.0001 {
            let g = 0.95 / peak
            for i in 0..<x.count { x[i] *= g }
        }
        let fade = min(Int(sr * 0.04), x.count)
        for i in 0..<fade {
            x[x.count - fade + i] *= Float(1 - Double(i) / Double(fade))
        }
        return x
    }
}

/// Fixed-frequency sine via the 2-multiply recurrence y[n] = k·y[n-1] − y[n-2].
/// ~10× cheaper than calling sin() per sample; used for all partial stacks.
struct SineOsc {
    private var y1: Double
    private var y2: Double
    private let k: Double

    init(freq: Double, sr: Double) {
        let w = 2 * .pi * freq / sr
        k = 2 * cos(w)
        y1 = sin(-w)
        y2 = sin(-2 * w)
    }

    mutating func next() -> Double {
        let y = k * y1 - y2
        y2 = y1
        y1 = y
        return y
    }
}

/// Deterministic per-articulation randomness: white noise, detune, and jitter.
struct SynthRandom {
    private var state: UInt64
    private var detunes: [Double] = []

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
        // Fixed per-variant partial detunes (round-robin character).
        for _ in 0..<12 {
            detunes.append(1.0 + (unitNext() - 0.5) * 0.012)
        }
    }

    private mutating func unitNext() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) * (1.0 / 9007199254740992.0)
    }

    /// White noise in [-1, 1].
    mutating func bipolar() -> Double {
        unitNext() * 2 - 1
    }

    /// Multiplier near 1 for per-variant pitch character.
    mutating func jitter(_ amount: Double) -> Double {
        1.0 + (unitNext() - 0.5) * 2 * amount
    }

    /// Stable detune for partial `k` — constant across the whole render.
    func staticDetune(_ k: Int) -> Double {
        detunes[k % detunes.count]
    }
}
