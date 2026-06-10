import Foundation

struct EventPhoto: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    var uploaderID: String
    var caption: String?
    /// File name inside the local image store. Nil for seeded placeholder art.
    var fileName: String?
    /// Drives a gradient placeholder when there is no file (sample data).
    var placeholderPaletteIndex: Int?
    var placeholderSymbol: String?
    var reactions: [String: [String]]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         uploaderID: String,
         caption: String? = nil,
         fileName: String? = nil,
         placeholderPaletteIndex: Int? = nil,
         placeholderSymbol: String? = nil,
         reactions: [String: [String]] = [:],
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.uploaderID = uploaderID
        self.caption = caption
        self.fileName = fileName
        self.placeholderPaletteIndex = placeholderPaletteIndex
        self.placeholderSymbol = placeholderSymbol
        self.reactions = reactions
        self.createdAt = createdAt
    }

    var reactionCount: Int {
        reactions.values.reduce(0) { $0 + $1.count }
    }
}
