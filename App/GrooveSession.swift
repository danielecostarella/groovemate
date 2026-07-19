import Foundation
import Observation
import GrooveModel
import GrooveBrain
import GrooveEngine

/// Thread-safe bridge between the UI (main actor) and the engine's scheduler
/// queue: owns the live spec and the seeded generator behind one lock.
final class DrummerCore: @unchecked Sendable {
    private let lock = NSLock()
    private var generator: GrooveGenerator
    private var _spec: GrooveSpec

    init(spec: GrooveSpec, seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)) {
        self.generator = GrooveGenerator(seed: seed)
        self._spec = spec
    }

    var spec: GrooveSpec {
        get { lock.withLock { _spec } }
        set { lock.withLock { _spec = newValue } }
    }

    func bar(index: Int) -> (bar: BarPerformance, bpm: Double) {
        lock.withLock {
            (generator.bar(index: index, spec: _spec), _spec.bpm)
        }
    }
}

@MainActor
@Observable
final class GrooveSession {
    enum EngineState {
        case warmingUp
        case ready
    }

    private(set) var persona: DrummerPersona?
    private(set) var engineState: EngineState = .warmingUp
    private(set) var isPlaying = false
    private(set) var position = DrumEngine.PlaybackPosition(barIndex: 0, beat: 0, isPlaying: false)
    /// Transient acknowledgement from the command parser.
    private(set) var acknowledgement: String?

    var spec: GrooveSpec {
        get { core.spec }
        set { core.spec = newValue.clamped() }
    }

    private let core: DrummerCore
    private var engine: DrumEngine?
    private let interpreter = CommandInterpreter()
    let voice = VoiceCommandListener()
    private var positionTimer: Timer?
    private var ackTask: Task<Void, Never>?
    private var tapTimes: [Date] = []

    init() {
        core = DrummerCore(spec: DrummerPersona.all[0].spec)
    }

    /// The acoustic kit is shared across personas (only the room changes);
    /// load it once and keep it.
    private var cachedKit: (any DrumKit)?

    func select(_ persona: DrummerPersona) {
        let wasPlaying = isPlaying
        stop()
        self.persona = persona
        core.spec = persona.spec
        if let kit = cachedKit {
            installKit(kit, room: persona.tone.room, resume: wasPlaying)
            return
        }
        engineState = .warmingUp
        let tone = persona.tone
        Task.detached(priority: .userInitiated) { [weak self] in
            let kit = Self.loadKit(fallbackTone: tone)
            await self?.installKit(kit, room: tone.room, resume: wasPlaying)
        }
    }

    /// Real recorded drums (MuldjordKit, CC-BY 4.0) bundled with the app;
    /// the synthesized kit only exists as a safety net.
    private nonisolated static func loadKit(fallbackTone: KitTone) -> any DrumKit {
        if let base = Bundle.main.resourceURL {
            let url = base.appendingPathComponent("DrumKits/MuldjordKit")
            if let kit = try? SampledDrumKit(directory: url) {
                return kit
            }
        }
        return SynthDrumKit(tone: fallbackTone)
    }

    private func installKit(_ kit: any DrumKit, room: Double, resume: Bool) {
        cachedKit = kit
        if let engine {
            engine.setKit(kit)
            engine.setRoom(room)
        } else {
            let engine = DrumEngine(kit: kit)
            engine.setRoom(room)
            let core = self.core
            engine.barProvider = { index in core.bar(index: index) }
            self.engine = engine
        }
        engineState = .ready
        if resume { play() }
    }

    func deselect() {
        stop()
        persona = nil
    }

    func togglePlayback() {
        isPlaying ? stop() : play()
    }

    func play() {
        guard let engine, engineState == .ready, !isPlaying else { return }
        do {
            try engine.start()
        } catch {
            show(ack: "Audio engine failed to start: \(error.localizedDescription)")
            return
        }
        isPlaying = true
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let engine = self.engine else { return }
                self.position = engine.position()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        positionTimer = timer
    }

    func stop() {
        positionTimer?.invalidate()
        positionTimer = nil
        engine?.stop()
        isPlaying = false
        position = DrumEngine.PlaybackPosition(barIndex: 0, beat: 0, isPlaying: false)
    }

    // MARK: - Commands

    func send(command text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { [interpreter, core] in
            let result = await interpreter.apply(text, to: core.spec)
            core.spec = result.spec
            show(ack: result.acknowledgement)
        }
    }

    /// Tap the mic: first tap starts on-device listening, second tap sends
    /// whatever was heard to the drummer.
    func toggleVoice() {
        Task {
            if let finalText = await voice.toggle() {
                if let problem = voice.problem {
                    show(ack: problem)
                } else if !finalText.trimmingCharacters(in: .whitespaces).isEmpty {
                    send(command: finalText)
                }
            } else if let problem = voice.problem {
                show(ack: problem)
            }
        }
    }

    private func show(ack: String) {
        acknowledgement = ack
        ackTask?.cancel()
        ackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.acknowledgement = nil
        }
    }

    // MARK: - Tap tempo

    func tapTempo() {
        let now = Date()
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 3 } + [now]
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
        let avg = intervals.suffix(4).reduce(0, +) / Double(min(intervals.count, 4))
        guard avg > 0.2, avg < 2.0 else { return }
        var s = spec
        s.bpm = (60.0 / avg).rounded()
        spec = s
    }
}
