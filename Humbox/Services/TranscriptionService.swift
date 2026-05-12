import Speech

struct TranscriptionService {

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Transcription

    // Transcribes an audio file on-device. Returns nil if recognition is
    // unavailable, unauthorized, or produces no speech (e.g. purely instrumental).
    // Safe to call from a background Task — the continuation resumes exactly once.
    static func transcribe(audioFileURL: URL) async -> String? {
        guard isAuthorized else { return nil }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.addsPunctuation = true
        request.taskHint = .dictation

        return await withCheckedContinuation { continuation in
            var resumed = false

            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }

                if let result, result.isFinal {
                    resumed = true
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: text.isEmpty ? nil : text)
                } else if error != nil {
                    // Non-speech audio (instrumental, percussion) commonly triggers
                    // a "no speech detected" error — treat as nil, not a failure.
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
