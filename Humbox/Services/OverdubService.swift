import AudioKit
import SoundpipeAudioKit
import AVFoundation

// Manages a single overdub session:
// 1. Checks headphones are connected
// 2. Plays the original memo while simultaneously recording a new layer
// 3. Mixes both tracks into a new CAF file with latency compensation
@MainActor
final class OverdubService: ObservableObject {

    enum OverdubError: LocalizedError {
        case headphonesRequired
        case engineFailed(Error)
        case mixdownFailed(Error)

        var errorDescription: String? {
            switch self {
            case .headphonesRequired:
                return "Headphones required to overdub. Please connect wired or Bluetooth headphones."
            case .engineFailed(let e):
                return "Recording failed: \(e.localizedDescription)"
            case .mixdownFailed(let e):
                return "Mixdown failed: \(e.localizedDescription)"
            }
        }
    }

    @Published var isRecording = false
    @Published var error: OverdubError?

    private let engine = AudioEngine()
    private var player: AudioPlayer?
    private var mixer: Mixer?
    private var pitchTap: PitchTap?
    private var recorder: NodeRecorder?

    private(set) var collectedPitches: [(pitch: Float, amplitude: Float)] = []
    private(set) var onsetTimes: [TimeInterval] = []
    private var lastAmplitude: Float = 0
    private var recordingStartTime: Date?

    // MARK: - Headphone detection

    static func headphonesConnected() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .airPlay]
                .contains($0.portType)
        }
    }

    // MARK: - Session

    func start(playing originalURL: URL) async throws {
        guard Self.headphonesConnected() else { throw OverdubError.headphonesRequired }

        collectedPitches = []
        onsetTimes = []
        lastAmplitude = 0
        recordingStartTime = Date()

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord, mode: .measurement,
                options: [.allowBluetoothHFP]   // no defaultToSpeaker — headphones only
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            throw OverdubError.engineFailed(error)
        }

        do {
            guard let mic = engine.input else { throw OverdubError.engineFailed(
                NSError(domain: "OverdubService", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Microphone unavailable"])) }

            let audioPlayer = AudioPlayer()
            try audioPlayer.load(url: originalURL)
            player = audioPlayer

            let mix = Mixer(audioPlayer, mic)
            mixer = mix
            engine.output = mix

            pitchTap = PitchTap(mic) { [weak self] pitches, amplitudes in
                Task { @MainActor [weak self] in
                    self?.processPitch(pitches: pitches, amplitudes: amplitudes)
                }
            }

            recorder = try NodeRecorder(node: mix)
            try engine.start()
            audioPlayer.play()
            pitchTap?.start()
            try recorder?.record()
            isRecording = true
        } catch {
            throw OverdubError.engineFailed(error)
        }
    }

    // Returns the raw new-layer CAF URL — call mixdown() to combine.
    func stop() -> URL? {
        player?.stop()
        pitchTap?.stop()
        recorder?.stop()
        engine.stop()
        isRecording = false
        return recorder?.audioFile?.url
    }

    // MARK: - Mixdown

    // Combines the original and new layer into a single CAF file.
    // Offsets the new layer by (outputLatency + inputLatency) to compensate for
    // the round-trip delay introduced by AVAudioEngine.
    static func mixdown(original originalURL: URL,
                        newLayer newURL: URL,
                        outputURL: URL) throws {
        let originalFile = try AVAudioFile(forReading: originalURL)
        let newFile      = try AVAudioFile(forReading: newURL)

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: originalFile.fileFormat.sampleRate,
            channels: 1
        ) else { throw NSError(domain: "OverdubService", code: 2,
                               userInfo: [NSLocalizedDescriptionKey: "Invalid format"]) }

        let sampleRate   = format.sampleRate
        let latencySamples = AVAudioSession.sharedInstance().outputLatency +
                             AVAudioSession.sharedInstance().inputLatency
        let offsetFrames = AVAudioFramePosition(latencySamples * sampleRate)

        // Total length = longer of the two tracks
        let totalFrames = max(originalFile.length,
                              newFile.length + offsetFrames)

        let outputSettings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatLinearPCM,
            AVSampleRateKey:       sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey:  true,
        ]
        let outputFile = try AVAudioFile(forWriting: outputURL,
                                         settings: outputSettings)

        let bufSize: AVAudioFrameCount = 4096

        // Read both files into float arrays
        func readAll(_ file: AVAudioFile) throws -> [Float] {
            file.framePosition = 0
            var samples = [Float](repeating: 0, count: Int(file.length))
            let buf = AVAudioPCMBuffer(pcmFormat: format,
                                       frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buf, frameCount: AVAudioFrameCount(file.length))
            guard let ch = buf.floatChannelData?[0] else { return samples }
            samples = Array(UnsafeBufferPointer(start: ch, count: Int(buf.frameLength)))
            return samples
        }

        let origSamples = try readAll(originalFile)
        let newSamples  = try readAll(newFile)

        // Mix with offset
        var mixed = [Float](repeating: 0, count: Int(totalFrames))
        for i in 0..<origSamples.count { mixed[i] += origSamples[i] }
        for i in 0..<newSamples.count {
            let dest = i + Int(offsetFrames)
            if dest < mixed.count { mixed[dest] += newSamples[i] }
        }

        // Normalise to prevent clipping
        let peak = mixed.map { abs($0) }.max() ?? 1
        if peak > 1 { mixed = mixed.map { $0 / peak } }

        // Write in chunks
        var written = 0
        while written < mixed.count {
            let chunk = min(Int(bufSize), mixed.count - written)
            let outBuf = AVAudioPCMBuffer(pcmFormat: format,
                                          frameCapacity: AVAudioFrameCount(chunk))!
            outBuf.frameLength = AVAudioFrameCount(chunk)
            mixed.withUnsafeBufferPointer { ptr in
                outBuf.floatChannelData![0].assign(from: ptr.baseAddress! + written,
                                                   count: chunk)
            }
            try outputFile.write(from: outBuf)
            written += chunk
        }
    }

    // MARK: - Pitch processing

    private func processPitch(pitches: [AUValue], amplitudes: [AUValue]) {
        let elapsed = Date().timeIntervalSince(recordingStartTime ?? Date())
        for (pitch, amp) in zip(pitches, amplitudes) {
            if amp > 0.05, pitch > 80, pitch < 1400 {
                collectedPitches.append((pitch: pitch, amplitude: amp))
            }
            if amp - lastAmplitude > 0.12 { onsetTimes.append(elapsed) }
            lastAmplitude = amp
        }
    }
}
