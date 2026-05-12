import AudioKit
import SoundpipeAudioKit
import AVFoundation
import SwiftUI

@MainActor
final class AudioService: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var memos: [Memo] = Memo.samples
    @Published var bufferEnabled: Bool = true
    @Published var currentLevels: [Float] = Array(repeating: 0.05, count: 20)

    // Engine and nodes are created once and reused across recording sessions.
    // Re-creating PitchTap each session causes "nullptr == Tap()" because the
    // underlying AVAudioNode tap isn't released before the new one is installed.
    private let engine = AudioEngine()
    private var mic: AudioEngine.InputNode?
    private var pitchTap: PitchTap?
    private var recorder: NodeRecorder?
    private var player: AVAudioPlayer?
    private var engineSetUp = false

    private var collectedPitches: [Float] = []
    private var onsetTimes: [TimeInterval] = []
    private var lastAmplitude: Float = 0
    private var recordingStartTime: Date?

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
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Engine setup (once)

    private func setupEngineIfNeeded() throws {
        guard !engineSetUp else { return }

        guard let input = engine.input else {
            print("Microphone input unavailable")
            return
        }

        mic = input
        engine.output = Mixer(input)

        // PitchTap is created once and lives for the app session.
        pitchTap = PitchTap(input) { [weak self] pitches, amplitudes in
            Task { @MainActor [weak self] in
                self?.processPitchData(pitches: pitches, amplitudes: amplitudes)
            }
        }

        engineSetUp = true
    }

    // MARK: - Recording

    func startRecording() async {
        guard await requestMicrophonePermission() else { return }

        collectedPitches = []
        onsetTimes = []
        lastAmplitude = 0
        recordingStartTime = Date()

        Task { await TranscriptionService.requestPermission() }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord, mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        do {
            try setupEngineIfNeeded()
            guard let mic else { return }

            recorder = try NodeRecorder(node: mic)
            pitchTap?.start()
            try engine.start()
            try recorder?.record()
            recordingState = .recording(startedAt: Date())
        } catch {
            print("Recording start error: \(error)")
            pitchTap?.stop()
            engine.stop()
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        recorder?.stop()
        pitchTap?.stop()
        engine.stop()
        currentLevels = Array(repeating: 0.05, count: 20)
        recordingState = .processing
        Task { await processRecording() }
    }

    // MARK: - Analysis pipeline

    private func processRecording() async {
        defer { recordingState = .idle }

        guard let audioFile = recorder?.audioFile else { return }
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        let destURL = recordingsDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        try? FileManager.default.copyItem(at: audioFile.url, to: destURL)

        let key = KeyFinder.detect(from: collectedPitches)
        let bpm = estimateBPM()

        async let classifyTask: Memo.ContentType = Task.detached(priority: .userInitiated) {
            ContentClassifier.classify(audioFileURL: destURL)
        }.value

        async let transcribeTask: String? = Task.detached(priority: .userInitiated) {
            await TranscriptionService.transcribe(audioFileURL: destURL)
        }.value

        let (contentType, transcript) = await (classifyTask, transcribeTask)
        let title = TitleGenerator.generate(key: key, bpm: bpm, contentType: contentType, transcript: transcript)

        let memo = Memo(
            fileURL: destURL,
            duration: duration,
            title: title,
            key: key,
            bpm: bpm,
            contentType: contentType,
            transcript: transcript
        )
        memos.insert(memo, at: 0)
    }

    // MARK: - Pitch processing

    private func processPitchData(pitches: [AUValue], amplitudes: [AUValue]) {
        let elapsed = Date().timeIntervalSince(recordingStartTime ?? Date())

        for (pitch, amp) in zip(pitches, amplitudes) {
            if amp > 0.02, pitch > 80, pitch < 1400 {
                collectedPitches.append(pitch)
            }
            if amp - lastAmplitude > 0.12 {
                onsetTimes.append(elapsed)
            }
            lastAmplitude = amp
        }

        let amp = amplitudes.first ?? 0
        let norm = min(1.0, max(0.0, amp * 3.0))
        currentLevels = (0..<20).map { _ in
            Float.random(in: max(0.05, norm - 0.15)...min(1.0, norm + 0.15))
        }
    }

    // MARK: - BPM estimation

    private func estimateBPM() -> Int? {
        guard onsetTimes.count >= 4 else { return nil }
        let intervals = zip(onsetTimes, onsetTimes.dropFirst()).map { $1 - $0 }
        let musical   = intervals.filter { $0 > 0.25 && $0 < 2.0 }
        guard musical.count >= 3 else { return nil }
        let avg = musical.reduce(0, +) / Double(musical.count)
        let bpm = Int((60.0 / avg).rounded())
        return (40...240).contains(bpm) ? bpm : nil
    }

    // MARK: - Playback

    func play(memo: Memo) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: memo.fileURL) else { return }
        player = p
        player?.play()
    }

    // MARK: - Storage

    private var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
