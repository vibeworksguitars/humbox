import AVFoundation

enum ExportService {

    enum ExportError: LocalizedError {
        case bufferAllocation
        case formatMismatch
        case conversionFailed(NSError?)

        var errorDescription: String? {
            switch self {
            case .bufferAllocation:        return "Could not allocate audio buffer."
            case .formatMismatch:          return "Incompatible audio formats."
            case .conversionFailed(let e): return e?.localizedDescription ?? "Conversion failed."
            }
        }
    }

    // MARK: - WAV export

    // Converts the memo's CAF recording to a 16-bit/44.1kHz WAV and returns
    // a URL in the temp directory. The caller owns the file — delete it after sharing.
    static func exportWAV(memo: Memo) throws -> URL {
        let sourceFile = try AVAudioFile(forReading: memo.fileURL)

        // Read entire source into memory (voice memos are typically < 10 MB)
        let frameCount = AVAudioFrameCount(sourceFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFile.processingFormat, frameCapacity: frameCount
        ) else { throw ExportError.bufferAllocation }
        try sourceFile.read(into: inputBuffer)

        // 16-bit mono PCM — universally accepted by DAWs
        let wavFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 1,
            interleaved: true
        )!

        guard let converter = AVAudioConverter(
            from: sourceFile.processingFormat, to: wavFormat
        ) else { throw ExportError.formatMismatch }

        let outputCapacity = AVAudioFrameCount(
            Double(frameCount) * wavFormat.sampleRate / sourceFile.processingFormat.sampleRate
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: wavFormat, frameCapacity: outputCapacity
        ) else { throw ExportError.bufferAllocation }

        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        if let e = conversionError { throw ExportError.conversionFailed(e) }
        if status == .error          { throw ExportError.conversionFailed(nil) }

        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(for: memo, ext: "wav"))
        let destFile = try AVAudioFile(forWriting: destURL, settings: [
            AVFormatIDKey:             Int(kAudioFormatLinearPCM),
            AVSampleRateKey:           44100.0,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        try destFile.write(from: outputBuffer)

        return destURL
    }

    // MARK: - Filename

    // e.g. "Dm_92bpm_guitar_20260511.wav"
    static func filename(for memo: Memo, ext: String) -> String {
        var parts: [String] = []
        if let key = memo.key { parts.append(key.replacingOccurrences(of: "#", with: "sharp")) }
        if let bpm = memo.bpm { parts.append("\(bpm)bpm") }
        parts.append(memo.contentType.label)
        let date = memo.createdAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: "")
        parts.append(date)
        return parts.joined(separator: "_") + ".\(ext)"
    }
}
