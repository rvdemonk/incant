import AppKit

enum State {
    case idle
    case recording
    case transcribing
}

enum RecordingMode {
    case copyOnly        // ⌥` — just copy to clipboard
    case autoPaste       // ⌥⇧` — copy + paste
    case autoPasteSend   // ⌥⌃` — copy + paste + enter
}

@MainActor
final class RecordingState {
    private(set) var state: State = .idle
    private let recorder = AudioRecorder()
    private let whisper = WhisperClient()
    private var recordingStartTime: Date?
    private var currentMode: RecordingMode = .copyOnly

    /// Minimum recording duration to send to API (avoids accidental taps)
    private let minimumDuration: TimeInterval = 0.5

    private let onStateChange: (State) -> Void
    private let onTranscript: (String, Double, RecordingMode) -> Void  // text, duration, mode
    private let onError: (String) -> Void
    private let onDiscarded: () -> Void

    init(
        onStateChange: @escaping (State) -> Void,
        onTranscript: @escaping (String, Double, RecordingMode) -> Void,
        onError: @escaping (String) -> Void,
        onDiscarded: @escaping () -> Void
    ) {
        self.onStateChange = onStateChange
        self.onTranscript = onTranscript
        self.onError = onError
        self.onDiscarded = onDiscarded
    }

    /// Start or stop recording with a specific mode
    func toggle(mode: RecordingMode = .copyOnly) async {
        switch state {
        case .idle:
            currentMode = mode
            await startRecording()
        case .recording:
            await stopAndTranscribe()
        case .transcribing:
            // Ignore taps while transcribing
            break
        }
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange(newState)
    }

    private func startRecording() async {
        recordingStartTime = Date()
        setState(.recording)
        SoundEffects.playStart()
        await recorder.start()
    }

    private func stopAndTranscribe() async {
        SoundEffects.playStop()
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartTime = nil

        // Discard recordings that are too short (accidental taps)
        if duration < minimumDuration {
            _ = await recorder.stop() // Clean up but discard
            onDiscarded()
            setState(.idle)
            return
        }

        setState(.transcribing)

        guard let audioData = await recorder.stop() else {
            onError("No audio recorded")
            setState(.idle)
            return
        }

        do {
            let transcript = try await whisper.transcribe(audioData: audioData)
            copyToClipboard(transcript)
            onTranscript(transcript, duration, currentMode)
        } catch {
            onError(error.localizedDescription)
        }

        setState(.idle)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
