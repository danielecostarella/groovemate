import AVFoundation
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
    private var _persona: DrummerPersona?

    init(spec: GrooveSpec, seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)) {
        self.generator = GrooveGenerator(seed: seed)
        self._spec = spec
    }

    var spec: GrooveSpec {
        get { lock.withLock { _spec } }
        set { lock.withLock { _spec = newValue } }
    }

    var persona: DrummerPersona? {
        get { lock.withLock { _persona } }
        set { lock.withLock { _persona = newValue } }
    }

    func bar(index: Int) -> (bar: BarPerformance, bpm: Double) {
        lock.withLock {
            // The drummer's character filters whatever was dialed in.
            let effective = _persona?.interpret(_spec) ?? _spec
            return (generator.bar(index: index, spec: effective), effective.bpm)
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
    /// Distinct from `persona != nil`: Practice Mode also drives a persona
    /// through this session (to reuse the same engine) but must stay on its
    /// own screen — RootView's auto-navigation to GrooveScreen watches this,
    /// not `persona`, so borrowing the engine for practice can't yank the
    /// user out of the practice screen.
    private(set) var shouldShowGrooveScreen = false
    private(set) var engineState: EngineState = .warmingUp
    private(set) var isPlaying = false
    private(set) var position = DrumEngine.PlaybackPosition(barIndex: 0, beat: 0, isPlaying: false)
    /// Transient acknowledgement from the command parser.
    private(set) var acknowledgement: String?

    /// The stored, `@Observable`-tracked source of truth for the UI. `core`
    /// (below) is a plain, lock-based mirror the audio scheduler reads from
    /// its own thread — writing straight to `core.spec` would update playback
    /// correctly but never notify SwiftUI, since Observation only tracks this
    /// object's own stored properties, not state living inside another
    /// reference type. Every mutation must go through this setter.
    private var _spec: GrooveSpec
    var spec: GrooveSpec {
        get { _spec }
        set {
            _spec = newValue.clamped()
            core.spec = _spec
            if isPlaying {
                liveActivity.update(personaName: persona?.name ?? "GrooveMate", spec: _spec, isPlaying: true)
            }
        }
    }

    private let core: DrummerCore
    private var engine: DrumEngine?
    private let interpreter = CommandInterpreter()
    private let liveActivity = GrooveLiveActivityController()
    let voice = VoiceCommandListener()
    private var positionTimer: Timer?
    private var ackTask: Task<Void, Never>?
    private var tapTimes: [Date] = []
    // Set once in init and only read in deinit (both single-threaded relative
    // to this instance's lifecycle); NotificationCenter's removeObserver is
    // safe to call from any thread, so this doesn't need actor isolation.
    private nonisolated(unsafe) var interruptionObservers: [NSObjectProtocol] = []

    init() {
        let initial = DrummerPersona.all[0].spec
        _spec = initial
        core = DrummerCore(spec: initial)
        observeAudioSession()
    }

    deinit {
        interruptionObservers.forEach(NotificationCenter.default.removeObserver)
    }

    /// A phone call, Siri, or another app taking the mic/speaker should pause
    /// the drummer cleanly rather than glitch or keep a Live Activity showing
    /// "playing" while nothing is actually audible. We don't auto-resume —
    /// jumping back into a full-band groove right after a call ends would be
    /// jarring; the user taps play when they're ready.
    private func observeAudioSession() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue
            else { return }
            Task { @MainActor in self?.stop() }
        }
        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            else { return }
            Task { @MainActor in self?.stop() }
        }
        interruptionObservers = [interruption, routeChange]
    }

    /// The acoustic kit is shared across personas (only the room changes);
    /// load it once and keep it.
    private var cachedKit: (any DrumKit)?

    func select(_ persona: DrummerPersona, applying spec: GrooveSpec? = nil, autoplay: Bool = false, navigate: Bool = true) {
        let resume = isPlaying || autoplay
        stop()
        self.persona = persona
        shouldShowGrooveScreen = navigate
        core.persona = persona
        self.spec = spec ?? persona.spec
        if let kit = cachedKit {
            installKit(kit, room: persona.tone.room, resume: resume)
            return
        }
        engineState = .warmingUp
        let tone = persona.tone
        Task.detached(priority: .userInitiated) { [weak self] in
            let (kit, warning) = Self.loadKit(fallbackTone: tone)
            await self?.installKit(kit, room: tone.room, resume: resume, warning: warning)
        }
    }

    /// Real recorded drums (MuldjordKit, CC-BY 4.0) bundled with the app. The
    /// synthesized kit is a safety net, never a silent one — if we ever fall
    /// back to it, the caller surfaces why instead of quietly serving a sound
    /// the user has explicitly said they don't want.
    private nonisolated static func loadKit(fallbackTone: KitTone) -> (kit: any DrumKit, warning: String?) {
        guard let base = Bundle.main.resourceURL else {
            return (SynthDrumKit(tone: fallbackTone), "Couldn't find the drum kit bundle — using a backup sound.")
        }
        let url = base.appendingPathComponent("DrumKits/MuldjordKit")
        do {
            let kit = try SampledDrumKit(directory: url)
            return (kit, nil)
        } catch {
            return (SynthDrumKit(tone: fallbackTone), "The acoustic kit failed to load (\(error)) — using a backup sound.")
        }
    }

    private func installKit(_ kit: any DrumKit, room: Double, resume: Bool, warning: String? = nil) {
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
        if let warning {
            show(ack: warning, seconds: 8)
        }
        if resume { play() }
    }

    func deselect() {
        stop()
        persona = nil
        shouldShowGrooveScreen = false
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
        liveActivity.start(
            personaName: persona?.name ?? "GrooveMate",
            kitName: (cachedKit as? SampledDrumKit)?.name ?? "GrooveMate",
            spec: _spec
        )
    }

    func stop() {
        positionTimer?.invalidate()
        positionTimer = nil
        engine?.stop()
        isPlaying = false
        position = DrumEngine.PlaybackPosition(barIndex: 0, beat: 0, isPlaying: false)
        liveActivity.stop()
    }

    // MARK: - Commands

    func send(command text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { [interpreter] in
            let result = await interpreter.apply(text, to: self.spec)
            if persona == nil {
                // First prompt from the opening screen: hire the drummer whose
                // repertoire fits, hand them the request, and count it in.
                let match = DrummerPersona.bestMatch(for: result.spec.style)
                select(match, applying: result.spec, autoplay: true)
            } else {
                self.spec = result.spec
                if result.wantsStop {
                    stop()
                } else if result.wantsPlay {
                    play()
                }
            }
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

    private func show(ack: String, seconds: Double = 4) {
        acknowledgement = ack
        ackTask?.cancel()
        ackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
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
