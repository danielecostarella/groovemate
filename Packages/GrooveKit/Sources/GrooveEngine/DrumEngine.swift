import AVFoundation
import GrooveModel

/// Realtime drum playback: an `AVAudioSourceNode` fed by a lookahead scheduler.
/// Musical decisions stay outside — the engine asks `barProvider` for each bar
/// just in time, so feel/tempo changes apply at the next bar like a real drummer.
public final class DrumEngine: @unchecked Sendable {
    public struct PlaybackPosition: Sendable, Equatable {
        public var barIndex: Int
        /// 0 ..< beatsPerBar
        public var beat: Double
        public var isPlaying: Bool
    }

    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode!
    private let state = RenderState()
    private let schedulerQueue = DispatchQueue(label: "com.groovemate.scheduler", qos: .userInitiated)
    private var timer: DispatchSourceTimer?

    public let sampleRate: Double
    private var factory: TriggerFactory

    // Musical clock — scheduler queue only.
    private var barIndex = 0
    private var nextBarStart: Int64 = 0
    private let lookaheadSeconds = 0.3

    // Last scheduled bar info for UI position — guarded by posLock.
    private var posLock = NSLock()
    private var currentBarInfo: (index: Int, start: Int64, samplesPerBeat: Double, beatsPerBar: Double)?
    private var barInfoQueue: [(index: Int, start: Int64, samplesPerBeat: Double, beatsPerBar: Double)] = []

    /// Supplies bar `index` and the bpm it should be played at. Called on the scheduler queue.
    public var barProvider: (@Sendable (Int) -> (bar: BarPerformance, bpm: Double))?

    public private(set) var isPlaying = false

    public init(kit: DrumKit) {
        self.sampleRate = kit.sampleRate
        self.factory = TriggerFactory(kit: kit)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let state = self.state
        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let l = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let r = abl[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }
            state.render(frameCount: Int(frameCount), outL: l, outR: r)
            return noErr
        }

        engine.attach(sourceNode)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 18
        engine.connect(sourceNode, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    /// Swap the kit (e.g. persona change). Applies from the next scheduled bar.
    public func setKit(_ kit: DrumKit) {
        schedulerQueue.async { [self] in
            factory = TriggerFactory(kit: kit)
        }
    }

    /// 0...1 room amount.
    public func setRoom(_ room: Double) {
        reverb.wetDryMix = Float(min(max(room, 0), 1)) * 55
    }

    public func start() throws {
        guard !isPlaying else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        #endif

        state.reset()
        engine.prepare()
        try engine.start()
        isPlaying = true

        schedulerQueue.sync { [self] in
            barIndex = 0
            nextBarStart = Int64(0.06 * sampleRate) // tiny preroll
            posLock.lock()
            currentBarInfo = nil
            barInfoQueue = []
            posLock.unlock()
        }

        let t = DispatchSource.makeTimerSource(queue: schedulerQueue)
        t.schedule(deadline: .now(), repeating: .milliseconds(30))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    public func stop() {
        guard isPlaying else { return }
        timer?.cancel()
        timer = nil
        engine.stop()
        state.reset()
        isPlaying = false
        posLock.lock()
        currentBarInfo = nil
        barInfoQueue = []
        posLock.unlock()
    }

    /// Where the drummer is right now, for UI animation.
    public func position() -> PlaybackPosition {
        guard isPlaying else { return PlaybackPosition(barIndex: 0, beat: 0, isPlaying: false) }
        let now = state.now()
        posLock.lock()
        // Promote queued bars whose start has passed.
        while let next = barInfoQueue.first, next.start <= now {
            currentBarInfo = next
            barInfoQueue.removeFirst()
        }
        let info = currentBarInfo
        posLock.unlock()
        guard let info else { return PlaybackPosition(barIndex: 0, beat: 0, isPlaying: true) }
        let beat = Double(now - info.start) / info.samplesPerBeat
        return PlaybackPosition(
            barIndex: info.index,
            beat: min(max(beat, 0), info.beatsPerBar - 0.0001),
            isPlaying: true
        )
    }

    // MARK: - Scheduler

    private func tick() {
        guard let provider = barProvider else { return }
        let horizon = state.now() + Int64(lookaheadSeconds * sampleRate)
        while nextBarStart < horizon {
            let (bar, bpm) = provider(barIndex)
            let samplesPerBeat = sampleRate * 60.0 / max(bpm, 20)
            let triggers = factory.triggers(for: bar, barStart: nextBarStart, samplesPerBeat: samplesPerBeat)
            state.push(triggers)

            posLock.lock()
            barInfoQueue.append((barIndex, nextBarStart, samplesPerBeat, bar.beatsPerBar))
            posLock.unlock()

            nextBarStart += Int64(bar.beatsPerBar * samplesPerBeat)
            barIndex += 1
        }
    }
}
