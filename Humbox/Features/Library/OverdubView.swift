import SwiftUI
import AVFoundation

struct OverdubView: View {
    let memo: Memo
    let onComplete: (Memo) -> Void

    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var overdub = OverdubService()
    @StateObject private var click = ClickTrackService()

    @State private var phase: Phase = .countdown(3)
    @State private var errorMessage: String?
    @State private var levels: [Float] = Array(repeating: 0.05, count: 20)
    @State private var clickEnabled: Bool = false
    @State private var clickTimeSig: ClickTrackService.TimeSignature = .fourFour

    enum Phase {
        case countdown(Int)
        case recording
        case processing
        case failed(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                Text("Add Layer")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\"\(memo.title)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                switch phase {
                case .countdown(let n):
                    // 3-2-1 countdown
                    VStack(spacing: 12) {
                        Text("\(n)")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(Brand.crimson)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: n)
                        Text("Get ready…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                case .recording:
                    VStack(spacing: 24) {
                        // Live waveform
                        WaveformBars(levels: levels, color: Brand.crimson)
                            .frame(height: 60)
                            .padding(.horizontal, 40)

                        Text("Recording new layer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Stop button
                        Button {
                            stopAndProcess()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Brand.crimson)
                                    .frame(width: 72, height: 72)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                case .processing:
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                        Text("Mixing tracks…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                case .failed(let msg):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Brand.crimson)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Dismiss") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }
                }

                Spacer()

                if case .recording = phase {
                    VStack(spacing: 4) {
                        Text("Playing original in headphones")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if clickEnabled {
                            Text("Click: \(memo.bpm ?? 120) BPM · \(clickTimeSig.rawValue)")
                                .font(.caption)
                                .foregroundStyle(Brand.crimson)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Click toggle (only shown before recording starts)
                if case .countdown = phase {
                    VStack(spacing: 8) {
                        Toggle(isOn: $clickEnabled) {
                            Label("Click track", systemImage: "metronome")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .tint(Brand.crimson)
                        .padding(.horizontal)

                        if clickEnabled {
                            HStack(spacing: 8) {
                                ForEach(ClickTrackService.TimeSignature.allCases, id: \.self) { sig in
                                    Button(sig.rawValue) { clickTimeSig = sig }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(clickTimeSig == sig ? Brand.crimson : Color(.secondarySystemBackground))
                                        .foregroundStyle(clickTimeSig == sig ? Color.white : Color.secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                if let bpm = memo.bpm {
                                    Text("\(bpm) BPM (detected)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding()
        }
        .task { await runCountdown() }
        .onChange(of: overdub.isRecording) { _, recording in
            if recording { startLevelUpdates() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    // MARK: - Flow

    private func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            phase = .countdown(n)
            try? await Task.sleep(for: .seconds(1))
        }
        await beginRecording()
    }

    private func beginRecording() async {
        do {
            try await overdub.start(playing: memo.fileURL)
            if clickEnabled {
                click.start(bpm: memo.bpm ?? 120, timeSignature: clickTimeSig)
            }
            phase = .recording
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func stopAndProcess() {
        click.stop()
        guard let newLayerURL = overdub.stop() else {
            phase = .failed("No audio was recorded.")
            return
        }
        phase = .processing
        Task { await mixdown(newLayerURL: newLayerURL) }
    }

    private func mixdown(newLayerURL: URL) async {
        let destURL = recordingsDirectory
            .appendingPathComponent("\(UUID().uuidString).caf")

        do {
            try await Task.detached(priority: .userInitiated) {
                try OverdubService.mixdown(
                    original: memo.fileURL,
                    newLayer: newLayerURL,
                    outputURL: destURL
                )
            }.value
        } catch {
            phase = .failed("Mixdown failed: \(error.localizedDescription)")
            return
        }

        // Run the same analysis pipeline as a normal recording
        let pitches = overdub.collectedPitches
        let onsets  = overdub.onsetTimes
        let key     = KeyFinder.detect(from: pitches)
        let bpm: Int? = {
            guard onsets.count >= 4 else { return memo.bpm }
            let intervals = zip(onsets, onsets.dropFirst()).map { $1 - $0 }
            let musical   = intervals.filter { $0 > 0.25 && $0 < 2.0 }
            guard musical.count >= 3 else { return memo.bpm }
            let avg = musical.reduce(0, +) / Double(musical.count)
            let b   = Int((60.0 / avg).rounded())
            return (40...240).contains(b) ? b : memo.bpm
        }()

        async let classifyTask: Memo.ContentType = Task.detached(priority: .userInitiated) {
            ContentClassifier.classify(audioFileURL: destURL)
        }.value

        async let transcribeTask: String? = Task.detached(priority: .userInitiated) {
            await TranscriptionService.transcribe(audioFileURL: destURL)
        }.value

        var (contentType, transcript) = await (classifyTask, transcribeTask)
        if transcript != nil { contentType = .lyrics }

        let duration = (try? AVAudioFile(forReading: destURL))
            .map { Double($0.length) / $0.fileFormat.sampleRate } ?? memo.duration

        let title = TitleGenerator.generate(
            key: key ?? memo.key, bpm: bpm, contentType: contentType, transcript: transcript)

        let layeredMemo = Memo(
            fileURL: destURL,
            duration: duration,
            title: title,
            key: key ?? memo.key,
            bpm: bpm,
            contentType: contentType,
            transcript: transcript
        )

        onComplete(layeredMemo)
        dismiss()
    }

    private func startLevelUpdates() {
        Task {
            while case .recording = phase {
                levels = (0..<20).map { _ in Float.random(in: 0.05...0.7) }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
