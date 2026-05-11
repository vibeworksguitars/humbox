import Foundation

enum TitleGenerator {
    static func generate(key: String?, bpm: Int?, contentType: Memo.ContentType) -> String {
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
}
