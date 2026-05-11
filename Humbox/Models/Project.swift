import Foundation

struct MusicProject: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var memoIDs: [UUID] = []
    var color: String = "blue"
}
