import Foundation

enum TitleGenerator {
    static func generate(
        key: String?,
        bpm: Int?,
        contentType: Memo.ContentType,
        transcript: String? = nil
    ) -> String {
        // For lyric memos, lead with the first few words of the transcript —
        // matches the wireframe style: Verse lyric — "city in the rain"
        if contentType == .lyrics || (contentType == .humming && transcript != nil) {
            if let snippet = transcriptSnippet(transcript) {
                return "\(contentType == .lyrics ? "Lyric" : "Vocal idea") — \"\(snippet)\""
            }
        }

        var parts: [String] = []

        switch contentType {
        case .humming:    parts.append("Hummed melody")
        case .lyrics:     parts.append("Lyric idea")
        case .guitar:     parts.append("Guitar idea")
        case .piano:      parts.append("Piano idea")
        case .percussion: parts.append("Beat idea")
        case .mixed:      parts.append("Mixed idea")
        case .unknown:    parts.append("Idea")
        }

        if let key { parts.append("in \(key)") }
        if let bpm  { parts.append("· \(bpm) BPM") }

        return parts.joined(separator: " ")
    }

    // Returns the first 5 words of the transcript, lowercased, or nil if empty.
    private static func transcriptSnippet(_ transcript: String?) -> String? {
        guard let transcript else { return nil }
        let words = transcript
            .split(separator: " ")
            .prefix(5)
            .joined(separator: " ")
            .lowercased()
        return words.isEmpty ? nil : words
    }
}
