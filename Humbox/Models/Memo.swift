import Foundation

struct Memo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileURL: URL
    var createdAt: Date = Date()
    var duration: TimeInterval

    // Auto-analysis results
    var title: String
    var key: String?
    var bpm: Int?
    var contentType: ContentType
    var transcript: String?

    // User-editable
    var tags: [String] = []
    var projectID: UUID?
    var playCount: Int = 0
    var lastPlayedAt: Date?
    var isDeveloped: Bool = false

    enum ContentType: String, Codable, CaseIterable {
        case humming
        case lyrics
        case guitar
        case piano
        case percussion
        case mixed
        case unknown

        var label: String {
            switch self {
            case .humming:   return "humming"
            case .lyrics:    return "lyrics"
            case .guitar:    return "guitar"
            case .piano:     return "piano"
            case .percussion: return "percussion"
            case .mixed:     return "mixed"
            case .unknown:   return "audio"
            }
        }

        var icon: String {
            switch self {
            case .humming:   return "waveform.and.mic"
            case .lyrics:    return "text.bubble"
            case .guitar:    return "guitars"
            case .piano:     return "pianokeys.inverse"
            case .percussion: return "music.note"
            case .mixed:     return "waveform"
            case .unknown:   return "waveform"
            }
        }
    }

    var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "0:\(String(format: "%02d", secs))"
    }

    var metaSummary: String {
        var parts: [String] = []
        if let key { parts.append(key) }
        if let bpm { parts.append("\(bpm) BPM") }
        parts.append(contentType.label)
        parts.append(formattedDuration)
        return parts.joined(separator: " · ")
    }
}

// MARK: - Sample data for previews

extension Memo {
    static let samples: [Memo] = [
        Memo(
            fileURL: URL(fileURLWithPath: "/tmp/memo1.m4a"),
            duration: 18,
            title: "Mellow descending riff in Dm",
            key: "Dm", bpm: 92,
            contentType: .guitar
        ),
        Memo(
            fileURL: URL(fileURLWithPath: "/tmp/memo2.m4a"),
            duration: 32,
            title: "Hummed chorus, ascending",
            key: "A", bpm: 104,
            contentType: .humming,
            playCount: 0
        ),
        Memo(
            fileURL: URL(fileURLWithPath: "/tmp/memo3.m4a"),
            duration: 24,
            title: "Verse lyric — \"city in the rain\"",
            contentType: .lyrics,
            transcript: "city in the rain, nobody knows my name"
        ),
        Memo(
            fileURL: URL(fileURLWithPath: "/tmp/memo4.m4a"),
            duration: 41,
            title: "Spooky drop-D groove",
            key: "Dm", bpm: 78,
            contentType: .guitar,
            playCount: 3
        ),
    ]
}
