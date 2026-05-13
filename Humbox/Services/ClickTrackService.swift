import AVFoundation

// Generates and plays a programmatic woodblock click track.
// Beat 1 uses a higher-pitched, louder accent click; other beats use a softer click.
// Plays through whatever the current audio output route is (headphones during overdub).
@MainActor
final class ClickTrackService: ObservableObject {

    enum TimeSignature: String, CaseIterable {
        case fourFour = "4/4"
        case threeFour = "3/4"

        var beatsPerBar: Int {
            switch self {
            case .fourFour:  return 4
            case .threeFour: return 3
            }
        }
    }

    @Published var isPlaying = false
    @Published var bpm: Int = 120
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var currentBeat: Int = 0   // 0-based, 0 = downbeat

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var timer: Task<Void, Never>?

    private let sampleRate: Double = 44100

    // MARK: - Public

    func start(bpm: Int, timeSignature: TimeSignature) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        currentBeat = 0

        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()
        eng.attach(player)

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        eng.connect(player, to: eng.mainMixerNode, format: format)

        do {
            try eng.start()
        } catch {
            print("ClickTrackService engine error: \(error)")
            return
        }

        engine = eng
        playerNode = player
        player.play()
        isPlaying = true

        let beatInterval = 60.0 / Double(bpm)
        let beats = timeSignature.beatsPerBar

        timer = Task { [weak self] in
            var beat = 0
            while !Task.isCancelled {
                guard let self else { return }
                let isDownbeat = (beat % beats == 0)
                await self.scheduleClick(isDownbeat: isDownbeat)
                await MainActor.run { self.currentBeat = beat % beats }
                beat += 1
                try? await Task.sleep(for: .seconds(beatInterval))
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
        currentBeat = 0
    }

    // MARK: - Click generation

    // Woodblock approximation: short sine burst at ~800Hz (normal) or ~1200Hz (downbeat)
    // with a fast exponential decay envelope
    private func scheduleClick(isDownbeat: Bool) async {
        guard let player = playerNode,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { return }

        let freq: Double   = isDownbeat ? 1200 : 800
        let amplitude: Float = isDownbeat ? 0.9  : 0.55
        let durationSecs   = 0.025   // 25ms click

        let frameCount = AVAudioFrameCount(sampleRate * durationSecs)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t / 0.008)   // sharp woodblock decay
            data[i] = Float(sin(2 * .pi * freq * t) * envelope) * amplitude
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
