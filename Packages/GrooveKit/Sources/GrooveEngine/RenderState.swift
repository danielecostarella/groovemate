import Foundation
import os
import GrooveModel

/// A hit scheduled at an absolute engine sample time, fully resolved to a buffer.
struct Trigger {
    var sampleTime: Int64
    var sample: KitSample
    var gain: Float
    var pan: Float
    /// Choke group this voice belongs to (-1 = none).
    var chokeGroup: Int32
    /// True when this trigger silences other members of its group (closed/pedal hat).
    var chokes: Bool
}

/// The audio-thread heart: consumes sample-stamped triggers, mixes active voices.
/// Shared mutable state (pending queue, clock) is guarded by a briefly-held
/// unfair lock; active voices are touched only by the render thread.
final class RenderState: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var pending: [Trigger] = []
    private var clock: Int64 = 0

    private struct Active {
        var sample: KitSample
        /// Playhead into the sample; negative = starts partway into the current block.
        var pos: Int
        var gainL: Float
        var gainR: Float
        var chokeGroup: Int32
        var choked: Bool
        var fade: Float
    }
    private var active: [Active] = []
    private let maxActive = 64
    /// ~5 ms exponential fade for choked voices at 48 kHz.
    private let chokeFadeStep: Float = 0.971

    func push(_ triggers: [Trigger]) {
        os_unfair_lock_lock(&lock)
        pending.append(contentsOf: triggers)
        os_unfair_lock_unlock(&lock)
    }

    /// Current engine sample time (frames rendered since start/reset).
    func now() -> Int64 {
        os_unfair_lock_lock(&lock)
        let t = clock
        os_unfair_lock_unlock(&lock)
        return t
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        pending.removeAll()
        clock = 0
        os_unfair_lock_unlock(&lock)
        // Render thread will fade naturally; drop actives on next render call via flag.
        os_unfair_lock_lock(&activeResetLock)
        needsActiveReset = true
        os_unfair_lock_unlock(&activeResetLock)
    }

    private var activeResetLock = os_unfair_lock_s()
    private var needsActiveReset = false

    /// Mix one block. `outL`/`outR` must hold `frameCount` floats; they are overwritten.
    func render(frameCount: Int, outL: UnsafeMutablePointer<Float>, outR: UnsafeMutablePointer<Float>) {
        os_unfair_lock_lock(&activeResetLock)
        if needsActiveReset {
            active.removeAll(keepingCapacity: true)
            needsActiveReset = false
        }
        os_unfair_lock_unlock(&activeResetLock)

        // Claim due triggers.
        os_unfair_lock_lock(&lock)
        let blockStart = clock
        let blockEnd = blockStart + Int64(frameCount)
        var due: [Trigger] = []
        if !pending.isEmpty {
            var i = 0
            while i < pending.count {
                if pending[i].sampleTime < blockEnd {
                    due.append(pending[i])
                    pending.remove(at: i)
                } else {
                    i += 1
                }
            }
        }
        clock = blockEnd
        os_unfair_lock_unlock(&lock)

        for t in due {
            if t.chokes {
                for a in active.indices where active[a].chokeGroup == t.chokeGroup {
                    active[a].choked = true
                }
            }
            guard active.count < maxActive else { continue }
            let offset = max(0, Int(t.sampleTime - blockStart))
            // Equal-power pan.
            let angle = (Double(t.pan) + 1) * .pi / 4
            active.append(Active(
                sample: t.sample,
                pos: -offset,
                gainL: t.gain * Float(cos(angle)),
                gainR: t.gain * Float(sin(angle)),
                chokeGroup: t.chokeGroup,
                choked: false,
                fade: 1
            ))
        }

        for i in 0..<frameCount {
            outL[i] = 0
            outR[i] = 0
        }

        var v = 0
        while v < active.count {
            var a = active[v]
            let count = a.sample.frameCount
            var i = 0
            var finished = false
            a.sample.left.withUnsafeBufferPointer { lBuf in
                a.sample.right.withUnsafeBufferPointer { rBuf in
                    while i < frameCount {
                        if a.pos >= 0 {
                            if a.pos >= count || a.fade < 0.001 {
                                finished = true
                                break
                            }
                            outL[i] += lBuf[a.pos] * a.fade * a.gainL
                            outR[i] += rBuf[a.pos] * a.fade * a.gainR
                            if a.choked { a.fade *= chokeFadeStep }
                        }
                        a.pos += 1
                        i += 1
                    }
                }
            }
            if finished || a.pos >= count {
                active.remove(at: v)
            } else {
                active[v] = a
                v += 1
            }
        }

        // Soft protection against hot stacks of hits.
        for i in 0..<frameCount {
            outL[i] = tanhf(outL[i] * 0.9)
            outR[i] = tanhf(outR[i] * 0.9)
        }
    }
}

/// Converts performed bars into sample-stamped triggers. Shared by the realtime
/// scheduler and the offline renderer so both sound identical.
struct TriggerFactory {
    var kit: DrumKit
    private var roundRobin: [DrumVoice: Int] = [:]

    init(kit: DrumKit) {
        self.kit = kit
    }

    mutating func triggers(for bar: BarPerformance, barStart: Int64, samplesPerBeat: Double) -> [Trigger] {
        let baked = kit.usesBakedStereoImage
        return bar.events.map { e in
            let rr = (roundRobin[e.voice] ?? 0) + 1
            roundRobin[e.voice] = rr
            let (sample, gain) = kit.sample(for: e.voice, velocity: e.velocity, roundRobin: rr)
            return Trigger(
                sampleTime: barStart + Int64(e.position * samplesPerBeat),
                sample: sample,
                gain: baked ? gain : gain * VoiceMix.level(e.voice),
                pan: baked ? 0 : VoiceMix.pan(e.voice),
                chokeGroup: Int32(e.voice.chokeGroup ?? -1),
                chokes: e.voice == .hatClosed || e.voice == .hatPedal
            )
        }
    }
}
