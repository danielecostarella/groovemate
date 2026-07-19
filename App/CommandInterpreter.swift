import Foundation
import GrooveModel
import GrooveBrain
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns free text into a `GrooveSpec` change. On devices with Apple
/// Intelligence the on-device foundation model interprets the phrase (still
/// 100% local); everywhere else — and whenever the model is unavailable or
/// fails — the deterministic rule parser answers instantly.
struct CommandInterpreter {
    private let parser = CommandParser()

    func apply(_ text: String, to spec: GrooveSpec) async -> ParsedCommand {
        // The rule parser always runs: it's instant and owns transport intent
        // ("suona", "stop") in both languages.
        let ruleResult = parser.apply(text, to: spec)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if var fmResult = await applyWithFoundationModel(text, to: spec) {
                fmResult.wantsPlay = ruleResult.wantsPlay
                fmResult.wantsStop = ruleResult.wantsStop
                return fmResult
            }
        }
        #endif
        return ruleResult
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct DrummerDirective {
    @Guide(description: "Musical style to switch to, only if the user asked for one", .anyOf(["rock", "funk", "jazz", "blues", "pop"]))
    var style: String?
    @Guide(description: "Absolute tempo in BPM (40-220), only if the user named or implied a tempo change")
    var bpm: Int?
    @Guide(description: "Timing precision: 0 = very loose and human, 1 = machine tight")
    var tightness: Double?
    @Guide(description: "Busyness: 0 = minimal timekeeping, 1 = heavily ornamented with ghost notes")
    var complexity: Double?
    @Guide(description: "Energy: 0 = whisper quiet, 1 = full-power chorus")
    var intensity: Double?
    @Guide(description: "Swing: 0 = straight, 1 = full triplet shuffle")
    var swing: Double?
    @Guide(description: "Pocket: 0.03 = laid back behind the beat, 0 = on the grid, -0.02 = pushing ahead")
    var pocketOffset: Double?
    @Guide(description: "Play a fill every N bars; 0 disables fills")
    var fillEveryBars: Int?
}

@available(iOS 26.0, macOS 26.0, *)
extension CommandInterpreter {
    fileprivate func applyWithFoundationModel(_ text: String, to spec: GrooveSpec) async -> ParsedCommand? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: """
        You are a world-class session drummer taking musical direction. \
        Interpret the user's request and set ONLY the fields they asked to change, \
        leaving everything else nil. Current groove: style \(spec.style.rawValue), \
        \(Int(spec.bpm)) BPM, tightness \(spec.tightness), complexity \(spec.complexity), \
        intensity \(spec.intensity), swing \(spec.swing), fill every \(spec.fillEveryBars) bars. \
        Drummer references imply their feel (e.g. Bonham: rock, powerful, behind the beat; \
        Purdie: funk shuffle, ghost notes). "Simpler" lowers complexity, "for a chorus" raises intensity.
        """)

        do {
            let directive = try await session.respond(
                to: text,
                generating: DrummerDirective.self,
                options: GenerationOptions(temperature: 0.1)
            ).content

            var s = spec
            var changes: [String] = []
            if let style = directive.style, let parsed = Style(rawValue: style), parsed != s.style {
                s.style = parsed
                changes.append("switching to \(parsed.displayName.lowercased())")
            }
            if let bpm = directive.bpm {
                s.bpm = Double(bpm)
                changes.append("\(bpm) BPM")
            }
            if let v = directive.tightness {
                s.tightness = v
                changes.append(v > spec.tightness ? "tighter" : "looser")
            }
            if let v = directive.complexity {
                s.complexity = v
                changes.append(v > spec.complexity ? "busier" : "simpler")
            }
            if let v = directive.intensity {
                s.intensity = v
                changes.append(v > spec.intensity ? "more energy" : "softer")
            }
            if let v = directive.swing {
                s.swing = v
                changes.append(v > spec.swing ? "more swing" : "straighter")
            }
            if let v = directive.pocketOffset {
                s.pocketOffset = v
                if v > 0.005 { changes.append("laid back") } else if v < -0.005 { changes.append("pushing ahead") }
            }
            if let v = directive.fillEveryBars {
                s.fillEveryBars = v
                changes.append(v == 0 ? "no fills" : "fill every \(v) bars")
            }
            guard !changes.isEmpty else { return nil } // nothing understood — let the parser try
            return ParsedCommand(spec: s.clamped(), changes: changes)
        } catch {
            return nil
        }
    }
}

#endif
