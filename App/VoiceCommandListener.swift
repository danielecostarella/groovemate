import AVFoundation
import Observation
import Speech

/// On-device speech capture for "talk to your drummer": taps the microphone,
/// streams buffers into `SFSpeechRecognizer` (forcing on-device recognition
/// when the model is available), and publishes a live transcript.
@MainActor
@Observable
final class VoiceCommandListener {
    private(set) var isListening = false
    private(set) var transcript = ""
    /// Set when permissions are denied or recognition is unavailable.
    private(set) var problem: String?

    private let captureEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts listening, or stops and returns the final transcript.
    func toggle() async -> String? {
        if isListening {
            return stop()
        }
        await start()
        return nil
    }

    private func start() async {
        problem = nil
        transcript = ""

        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            problem = "Speech recognition permission is off (Settings → GrooveMate)."
            return
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            problem = "Microphone permission is off (Settings → GrooveMate)."
            return
        }

        // Prefer the user's language; fall back to English.
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            problem = "Speech recognition is not available right now."
            return
        }
        self.recognizer = recognizer

        do {
            // Record while the drums keep playing through the speaker.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = captureEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
                request.append(buffer)
            }
            captureEngine.prepare()
            try captureEngine.start()

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil, self.isListening {
                        _ = self.stop()
                    }
                }
            }
            isListening = true
        } catch {
            problem = "Couldn't start listening: \(error.localizedDescription)"
            teardown()
        }
    }

    private func stop() -> String {
        let text = transcript
        teardown()
        return text
    }

    private func teardown() {
        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        // Hand the audio session back to plain playback.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }
}
