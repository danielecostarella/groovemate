import Foundation
import GrooveModel

/// The result of interpreting a natural-language instruction.
public struct ParsedCommand: Sendable {
    public var spec: GrooveSpec
    /// Human-readable descriptions of what changed, for UI acknowledgement.
    public var changes: [String]
    /// The user asked to start playing ("suona", "play"...).
    public var wantsPlay: Bool
    /// The user asked to stop ("fermati", "stop"...).
    public var wantsStop: Bool

    public init(spec: GrooveSpec, changes: [String], wantsPlay: Bool = false, wantsStop: Bool = false) {
        self.spec = spec
        self.changes = changes
        self.wantsPlay = wantsPlay
        self.wantsStop = wantsStop
    }

    public var acknowledgement: String {
        if changes.isEmpty {
            if wantsPlay { return "Okay — playing." }
            if wantsStop { return "Okay — stopping." }
            return "I didn't catch that — try style, tempo, or feel words."
        }
        return "Okay — " + changes.joined(separator: ", ") + "."
    }
}

/// Offline, rule-based musical language parser (English + Italian). Maps phrases
/// like "play a 90 bpm funky groove with a relaxed pocket" or
/// "suona un ritmo rock a 120" onto GrooveSpec deltas.
public struct CommandParser: Sendable {
    public init() {}

    public func apply(_ text: String, to current: GrooveSpec) -> ParsedCommand {
        var spec = current
        var changes: [String] = []
        let t = " " + text.lowercased() + " "

        func has(_ words: String...) -> Bool {
            words.contains { t.contains($0) }
        }

        // Transport intent.
        let wantsPlay = has("play", "suona", "parti", "attacca", "vai ", "fai partire", "start")
        let wantsStop = has("stop", "fermati", "ferma ", "basta", "silenzio")

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

        // Style (the genre words are shared between English and Italian).
        let styleWords: [(Style, [String])] = [
            (.funk, ["funk", "funky"]),
            (.jazz, ["jazz", "bebop", "swing feel"]),
            (.blues, ["blues", "bluesy", "shuffle"]),
            (.rock, ["rock"]),
            (.pop, ["pop"]),
        ]
        for (style, words) in styleWords where words.contains(where: t.contains) {
            if spec.style != style {
                spec.style = style
                changes.append("switching to \(style.displayName.lowercased())")
            }
            if style == .blues || has("shuffle") { spec.swing = max(spec.swing, 0.6) }
            break
        }

        // Tempo: explicit BPM ("120 bpm", "at 120", "a 120").
        if let bpm = firstNumber(in: t, pattern: #"(\d{2,3})\s*(bpm|beats|battiti)"#) {
            spec.bpm = bpm
            changes.append("\(Int(bpm)) BPM")
        } else if let bpm = firstNumber(in: t, pattern: #"\b(?:at|a)\s+(\d{2,3})\b"#) {
            spec.bpm = bpm
            changes.append("\(Int(bpm)) BPM")
        } else if has("faster", "speed up", "quicker", "più veloce", "veloce", "accelera") {
            spec.bpm += has("much", "a lot", "way", "molto") ? 20 : 8
            changes.append("faster (\(Int(spec.bpm.rounded())) BPM)")
        } else if has("slower", "slow down", "più lento", "lento", "rallenta") {
            spec.bpm -= has("much", "a lot", "way", "molto") ? 20 : 8
            changes.append("slower (\(Int(spec.bpm.rounded())) BPM)")
        }

        // Feel: pocket & tightness.
        if has("relaxed", "laid back", "laid-back", "lazy", "behind the beat", "rilassato", "tranquillo", "dietro al beat", "dietro il beat") {
            spec.tightness = min(spec.tightness, 0.55)
            spec.pocketOffset = 0.025
            changes.append("relaxed pocket")
        }
        if has("tight", "precise", "on the grid", "punchy", "preciso", "tirato", "chirurgico") {
            spec.tightness = max(spec.tightness, 0.9)
            spec.pocketOffset = 0
            changes.append("tighter")
        }
        if has("loose", "human", "sloppy", "sciolto", "umano", "sporco") {
            spec.tightness = min(spec.tightness, 0.4)
            changes.append("looser")
        }
        if has("push", "ahead of the beat", "on top of the beat", "spingi", "avanti al beat") {
            spec.pocketOffset = -0.02
            changes.append("pushing ahead")
        }

        // Complexity.
        if has("simpler", "simple", "basic", "for practice", "strip it down", "less busy",
               "semplice", "essenziale", "facile", "per esercitarmi", "di base") {
            spec.complexity = max(spec.complexity - 0.25, 0.05)
            changes.append("simpler")
        }
        if has("busier", "more complex", "fancier", "more going on", "spice it up",
               "complesso", "ricco", "elaborato", "più roba", "arricchisci") {
            spec.complexity = min(spec.complexity + 0.25, 1)
            changes.append("busier")
        }
        if has("ghost note", "ghost notes") {
            spec.complexity = max(spec.complexity, 0.6)
            changes.append("more ghost notes")
        }

        // Intensity / energy.
        if has("more energy", "energetic", "chorus", "bigger", "louder", "powerful", "harder",
               "più energia", "energia", "energico", "ritornello", "più forte", "forte", "potente", "carica", "picchia") {
            spec.intensity = min(spec.intensity + 0.25, 1)
            changes.append("more energy")
        }
        if has("less energy", "quieter", "softer", "verse", "calm", "gentle", "bring it down",
               "meno energia", "più piano", "piano ", "dolce", "leggero", "strofa", "calmo", "abbassa") {
            spec.intensity = max(spec.intensity - 0.25, 0.05)
            changes.append("softer")
        }

        // Swing.
        if has("swung", "swing it", "more swing", "shuffled", "più swing", "swingato", "terzinato") {
            spec.swing = min(spec.swing + 0.3, 1)
            changes.append("more swing")
        }
        if has("straight", "no swing", "straighten", "dritto", "senza swing") {
            spec.swing = 0
            changes.append("straight time")
        }

        // Fills ("fill every 8 bars", "stacco ogni 8 battute").
        if let bars = firstNumber(in: t, pattern: #"(?:fill every|fill ogni|stacco ogni|stacchi ogni)\s+(\d{1,2})"#) {
            spec.fillEveryBars = Int(bars)
            changes.append("fill every \(Int(bars)) bars")
        } else if has("no fills", "without fills", "skip the fills", "senza stacchi", "niente stacchi", "senza fill", "niente fill") {
            spec.fillEveryBars = 0
            changes.append("no fills")
        } else if has("more fills", "più stacchi", "più fill") {
            spec.fillEveryBars = max(spec.fillEveryBars / 2, 2)
            changes.append("more fills (every \(spec.fillEveryBars) bars)")
        } else if has("fewer fills", "less fills", "meno stacchi", "meno fill") {
            spec.fillEveryBars = spec.fillEveryBars == 0 ? 0 : min(spec.fillEveryBars * 2, 16)
            changes.append(spec.fillEveryBars == 0 ? "no fills" : "fewer fills (every \(spec.fillEveryBars) bars)")
        }

        return ParsedCommand(
            spec: spec.clamped(),
            changes: changes,
            wantsPlay: wantsPlay && !wantsStop,
            wantsStop: wantsStop
        )
    }

    private func firstNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[range])
    }
}
