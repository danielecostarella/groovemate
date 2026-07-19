# GrooveMate

**Your drummer, whenever you need one.**

GrooveMate is a native iOS app (iPhone-first, iPad-optimized) that gives musicians a
*virtual drummer* — not a drum machine, not a loop player. You tell it what you want,
in plain words or with your voice, and it plays like a session musician: real sampled
drums, human timing, dynamics that breathe, fills that land where a drummer would put
them.

> "Play a 90 BPM funky groove with a relaxed pocket." — and it does.

## What it does

- **Six drummer personas** (Rock, Funk, Jazz, Studio, Vintage, Modern), each a
  different default feel and kit sound.
- **Feel controls, not engineer knobs**: Tight ↔ Loose, Simple ↔ Complex,
  Soft ↔ Powerful, Straight ↔ Swung — plus tempo with tap-tempo, five styles
  (rock, funk, jazz, blues, pop) and fills every 2/4/8 bars.
- **Talk to your drummer**: a natural-language command bar ("make it simpler",
  "Bonham feel", "add a fill every 8 bars") and a microphone button with fully
  **on-device speech recognition** — nothing leaves the phone.
- **Live musical response**: changes apply at the next bar, the way a real drummer
  reacts, never by cutting the groove.

## What makes it powerful

1. **Real drums, really played.** The sound is a curated multi-velocity,
   round-robin subset of an acoustically recorded kit (see license below), driven by
   a sample-accurate mixer built on `AVAudioSourceNode` — no MIDI quantization, no
   synthetic timbre. Ghost notes, cross-stick, hat chokes, cymbal bleed: it's all in
   the recordings and the engine preserves it.
2. **A drummer brain, not a pattern bank.** Grooves are *generated*, not looped:
   hand-authored style templates are developed in real time through complexity
   gating, intensity-driven dynamics, swing, Gaussian micro-timing scaled by
   "tightness", pocket offset (behind/ahead of the beat) and a fill generator with
   a tom ladder that resolves onto a crash — deterministic per seed, different every
   session.
3. **100% offline intelligence.** The command parser is rule-based and instant. On
   devices with Apple Intelligence, free-form phrases are interpreted by Apple's
   **on-device foundation model** (structured generation, temperature 0.1) with
   automatic fallback to the parser — local either way, by design.
4. **An architecture built to grow.** Three Swift packages with strict boundaries —
   `GrooveModel` (domain), `GrooveBrain` (musical intelligence), `GrooveEngine`
   (audio) — behind a `DrumKit` protocol that makes kits swappable and a
   26-test suite that verifies everything from parser mappings to onset timing in
   offline-rendered audio. The same engine renders WAVs offline
   (`swift run groovemate-render`), the seed of future track export.

## Tech

- **Swift / SwiftUI**, iOS 17+, dark-stage visual language, HIG-first layout
- **AVAudioEngine** with a custom `AVAudioSourceNode` render callback:
  lock-free-ish trigger queue, sample-stamped events, ~100 ms lookahead scheduler,
  equal-power panning, room reverb per persona
- **Speech**: `SFSpeechRecognizer` with `requiresOnDeviceRecognition`
- **FoundationModels** (`@Generable` guided generation) where available
- **XcodeGen** project (`xcodegen generate` after editing `project.yml`)
- Tests: `cd Packages/GrooveKit && swift test`

## Drum kit license

The bundled acoustic drum samples are a curated subset of **MuldjordKit** by
**Lars Muldjord** ([drumgizmo.org](https://drumgizmo.org)), stereo edition assembled
by **Roberto Gordo Saez** for the
[FreePats project](https://freepats.zenvoid.org/Percussion/acoustic-drum-kit.html),
licensed under the
**[Creative Commons Attribution 4.0 International](http://creativecommons.org/licenses/by/4.0/)**
license (full text in `Resources/DrumKits/MuldjordKit/LICENSE.txt`). Samples are
unmodified apart from file re-organization and load-time tail truncation. See
`CREDITS.md`.

## Roadmap

Practice mode (smart metronome, progressive BPM plans, stats), Play mode with song
sections (intro → verse → chorus → outro), more styles (metal, latin, reggae, R&B,
fusion, country), more kits, Mac and plugin versions.
