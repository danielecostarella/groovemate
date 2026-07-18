import Foundation
import GrooveModel

/// The result of interpreting a natural-language instruction.
public struct ParsedCommand: Sendable {
    public var spec: GrooveSpec
    /// Human-readable descriptions of what changed, for UI acknowledgement.
    public var changes: [String]

    public var acknowledgement: String {
        changes.isEmpty ? "I didn't catch that — try style, tempo, or feel words." : "Okay — " + changes.joined(separator: ", ") + "."
    }
}

/// Offline, rule-based musical language parser. Maps phrases like
/// "play a 90 bpm funky groove with a relaxed pocket" onto GrooveSpec deltas.
public struct CommandParser: Sendable {
    public init() {}

    public func apply(_ text: String, to current: GrooveSpec) -> ParsedCommand {
        var spec = current
        var changes: [String] = []
        let t = text.lowercased()

        func has(_ words: String...) -> Bool {
            words.contains { t.contains($0) }
        }

        // Drummer references first — they set a whole vibe, later words can refine it.
        if has("bonham") {
            spec.style = .rock
            spec.intensity = max(spec.intensity, 0.85)
            spec.tightness = 0.55
            spec.pocketOffset = 0.02
            spec.complexity = max(spec.complexity, 0.6)
            spec.swing = max(spec.swing, 0.25)
            changes.append("Bonham-style rock: powerful, behind the beat")
        }
        if has("purdie") {
            spec.style = .funk
            spec.swing = max(spec.swing, 0.55)
            spec.complexity = max(spec.complexity, 0.7)
            changes.append("Purdie shuffle territory: ghosted and swung")
        }
        if has("porcaro") {
            spec.style = .pop
            spec.swing = max(spec.swing, 0.5)
            spec.tightness = 0.9
            changes.append("Porcaro feel: tight half-swung pop")
        }

        // Style.
        let styleWords: [(Style, [String])] = [
            (.funk, ["funk", "funky", "groove thing"]),
            (.jazz, ["jazz", "swing feel", "bebop", "ride pattern"]),
            (.blues, ["blues", "bluesy", "shuffle"]),
            (.rock, ["rock", "driving"]),
            (.pop, ["pop", "straight beat"]),
        ]
        for (style, words) in styleWords where words.contains(where: t.contains) {
            if spec.style != style {
                spec.style = style
                changes.append("switching to \(style.displayName.lowercased())")
            }
            if style == .blues || has("shuffle") { spec.swing = max(spec.swing, 0.6) }
            break
        }

        // Tempo: explicit BPM.
        if let match = t.range(of: #"(\d{2,3})\s*(bpm|beats)"#, options: .regularExpression) {
            let digits = t[match].prefix { $0.isNumber }
            if let bpm = Double(digits) {
                spec.bpm = bpm
                changes.append("\(Int(bpm)) BPM")
            }
        } else if let match = t.range(of: #"at (\d{2,3})\b"#, options: .regularExpression) {
            let digits = t[match].dropFirst(3).prefix { $0.isNumber }
            if let bpm = Double(digits) {
                spec.bpm = bpm
                changes.append("\(Int(bpm)) BPM")
            }
        } else if has("faster", "speed up", "quicker") {
            spec.bpm += has("much", "a lot", "way") ? 20 : 8
            changes.append("faster (\(Int(spec.bpm.rounded())) BPM)")
        } else if has("slower", "slow down", "bring it down a notch") {
            spec.bpm -= has("much", "a lot", "way") ? 20 : 8
            changes.append("slower (\(Int(spec.bpm.rounded())) BPM)")
        }

        // Feel: pocket & tightness.
        if has("relaxed", "laid back", "laid-back", "lazy", "behind the beat") {
            spec.tightness = min(spec.tightness, 0.55)
            spec.pocketOffset = 0.025
            changes.append("relaxed pocket")
        }
        if has("tight", "precise", "on the grid", "punchy") {
            spec.tightness = max(spec.tightness, 0.9)
            spec.pocketOffset = 0
            changes.append("tighter")
        }
        if has("loose", "human", "sloppy") {
            spec.tightness = min(spec.tightness, 0.4)
            changes.append("looser")
        }
        if has("push", "ahead of the beat", "on top of the beat") {
            spec.pocketOffset = -0.02
            changes.append("pushing ahead")
        }

        // Complexity.
        if has("simpler", "simple", "basic", "for practice", "strip it down", "less busy") {
            spec.complexity = max(spec.complexity - 0.25, 0.05)
            changes.append("simpler")
        }
        if has("busier", "more complex", "fancier", "more going on", "spice it up") {
            spec.complexity = min(spec.complexity + 0.25, 1)
            changes.append("busier")
        }
        if has("ghost note") {
            spec.complexity = max(spec.complexity, 0.6)
            changes.append("more ghost notes")
        }

        // Intensity / energy.
        if has("more energy", "energetic", "chorus", "bigger", "louder", "powerful", "harder") {
            spec.intensity = min(spec.intensity + 0.25, 1)
            changes.append("more energy")
        }
        if has("less energy", "quieter", "softer", "verse", "calm", "gentle", "bring it down") {
            spec.intensity = max(spec.intensity - 0.25, 0.05)
            changes.append("softer")
        }

        // Swing.
        if has("swung", "swing it", "more swing", "shuffled") {
            spec.swing = min(spec.swing + 0.3, 1)
            changes.append("more swing")
        }
        if has("straight", "no swing", "straighten") {
            spec.swing = 0
            changes.append("straight time")
        }

        // Fills.
        if let match = t.range(of: #"fill every (\d{1,2})"#, options: .regularExpression) {
            let digits = t[match].dropFirst("fill every ".count).prefix { $0.isNumber }
            if let bars = Int(digits) {
                spec.fillEveryBars = bars
                changes.append("fill every \(bars) bars")
            }
        } else if has("no fills", "without fills", "skip the fills") {
            spec.fillEveryBars = 0
            changes.append("no fills")
        } else if has("more fills") {
            spec.fillEveryBars = max(spec.fillEveryBars / 2, 2)
            changes.append("more fills (every \(spec.fillEveryBars) bars)")
        } else if has("fewer fills", "less fills") {
            spec.fillEveryBars = spec.fillEveryBars == 0 ? 0 : min(spec.fillEveryBars * 2, 16)
            changes.append(spec.fillEveryBars == 0 ? "no fills" : "fewer fills (every \(spec.fillEveryBars) bars)")
        }

        return ParsedCommand(spec: spec.clamped(), changes: changes)
    }
}
