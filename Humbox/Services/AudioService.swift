import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AudioService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var memos: [Memo] = Memo.samples
    @Published var bufferEnabled: Bool = true
    @Published var currentLevels: [Float] = Array(repeating: 0, count: 20)

    private var audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var levelTimer: Timer?

    enum RecordingState {
        case idle
        case recording(startedAt: Date)
        case processing
    }

    var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording() async {
        guard await requestMicrophonePermission() else { return }

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        let filename = "\(UUID().uuidString).m4a"
        let url = recordingsDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            recordingState = .recording(startedAt: Date())
            startLevelPolling()
        } catch {
            print("Recorder error: \(error)")
        }
    }

    func stopRecording() {
        guard let recorder, isRecording else { return }
        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        stopLevelPolling()
        recordingState = .processing

        // Placeholder: real app would run audio analysis here
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let memo = Memo(
                fileURL: url,
                duration: duration,
                title: "New idea — \(Date().formatted(.dateTime.hour().minute()))",
                contentType: .unknown
            )
            memos.insert(memo, at: 0)
            recordingState = .idle
        }
    }

    // MARK: - Playback

    func play(memo: Memo) {
        guard let player = try? AVAudioPlayer(contentsOf: memo.fileURL) else { return }
        self.player = player
        player.play()
    }

    // MARK: - Level metering

    private func startLevelPolling() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLevels()
            }
        }
    }

    private func stopLevelPolling() {
        levelTimer?.invalidate()
        levelTimer = nil
        currentLevels = Array(repeating: 0, count: 20)
    }

    private func updateLevels() {
        recorder?.updateMeters()
        currentLevels = (0..<20).map { _ in
            let raw = recorder?.averagePower(forChannel: 0) ?? -60
            let normalized = max(0, (raw + 60) / 60)
            return Float.random(in: max(0.05, normalized - 0.1)...min(1, normalized + 0.1))
        }
    }

    // MARK: - Storage

    private var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
