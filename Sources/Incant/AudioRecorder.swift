import AVFoundation
import Foundation

actor AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?

    func start() async {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("incant_\(UUID().uuidString).m4a")

        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )

            tempFileURL = fileURL

            // Install tap to capture audio
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                Task {
                    await self.writeBuffer(buffer)
                }
            }

            engine.prepare()
            try engine.start()
            audioEngine = engine
        } catch {
            // Recording failed - will return nil from stop()
        }
    }

    func stop() async -> Data? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        guard let url = tempFileURL else { return nil }
        defer {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }

        return try? Data(contentsOf: url)
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        try? audioFile?.write(from: buffer)
    }
}
