import Foundation

enum MessageKind: String, Codable {
    case text
    /// App-generated moments: "Pete locked in Dublin as the destination."
    case system
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    /// Nil for system messages.
    var senderID: String?
    var kind: MessageKind
    var text: String
    /// emoji -> user IDs who reacted with it
    var reactions: [String: [String]]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         senderID: String?,
         kind: MessageKind = .text,
         text: String,
         reactions: [String: [String]] = [:],
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.senderID = senderID
        self.kind = kind
        self.text = text
        self.reactions = reactions
        self.createdAt = createdAt
    }

    var reactionCount: Int {
        reactions.values.reduce(0) { $0 + $1.count }
    }
}
