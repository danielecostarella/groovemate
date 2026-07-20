import Foundation
import GrooveModel
import GrooveBrain
import GrooveEngine

// Dev listening tool: bounce grooves to WAV from the terminal.
//   groovemate-render <output-dir> [personaId] [bars] [bpm]
//   groovemate-render <output-dir> --versechorus   (8 verse bars -> 8 chorus bars, per style)
// With no persona, renders an 8-bar demo for every persona.

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: groovemate-render <output-dir> [personaId] [bars] [bpm]")
    print("       groovemate-render <output-dir> --versechorus")
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let verseChorusMode = args.count >= 3 && args[2] == "--versechorus"

let personas: [DrummerPersona]
if args.count >= 3, !verseChorusMode {
    guard let p = DrummerPersona.all.first(where: { $0.id == args[2] }) else {
        print("unknown persona '\(args[2])' — available: \(DrummerPersona.all.map(\.id).joined(separator: ", "))")
        exit(1)
    }
    personas = [p]
} else {
    personas = DrummerPersona.all
}
let bars = args.count >= 4 ? Int(args[3]) ?? 8 : 8
let bpmOverride = args.count >= 5 ? Double(args[4]) : nil

// Prefer the real sampled kit (repo-relative or $GROOVEMATE_KIT); synth as fallback.
func resolveKit() -> any DrumKit {
    var candidates: [URL] = []
    if let env = ProcessInfo.processInfo.environment["GROOVEMATE_KIT"] {
        candidates.append(URL(fileURLWithPath: env))
    }
    let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    candidates.append(here.appendingPathComponent("Resources/DrumKits/MuldjordKit"))
    candidates.append(here.appendingPathComponent("../../Resources/DrumKits/MuldjordKit"))
    for url in candidates {
        if let kit = try? SampledDrumKit(directory: url) {
            print("using sampled kit: \(kit.name)")
            return kit
        }
    }
    print("sampled kit not found, falling back to synth")
    return SynthDrumKit()
}
let kit = resolveKit()

if verseChorusMode {
    // 8 low-energy bars, then 8 high-energy bars, same seed: proves energy
    // changes the actual pattern (extra kicks, rimshot, hat barks, ride bell,
    // phrase-arrival crash) and not just velocity.
    let renderer = OfflineRenderer(kit: kit)
    for style in Style.allCases {
        var gen = GrooveGenerator(seed: 20260720)
        let verse = GrooveSpec(style: style, bpm: style.defaultTempo, complexity: 0.5, intensity: 0.3, fillEveryBars: 4)
        var chorus = verse
        chorus.intensity = 0.92
        let url = outDir.appendingPathComponent("versechorus-\(style.rawValue).wav")
        try renderer.renderWAV(to: url, bars: 16, bpm: verse.bpm) { i in
            gen.bar(index: i, spec: i < 8 ? verse : chorus)
        }
        print("wrote \(url.path)")
    }
    exit(0)
}

for persona in personas {
    var spec = persona.spec
    if let bpmOverride { spec.bpm = bpmOverride }
    let renderer = OfflineRenderer(kit: kit)
    var gen = GrooveGenerator(seed: 20260718)
    let url = outDir.appendingPathComponent("groovemate-\(persona.id)-\(Int(spec.bpm))bpm.wav")
    try renderer.renderWAV(to: url, bars: bars, bpm: spec.bpm) { i in
        gen.bar(index: i, spec: spec)
    }
    print("wrote \(url.path)")
}
