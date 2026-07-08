import Foundation

enum ContentType: String, Codable, CaseIterable {
    case article
    case review
    case lesson
    case product
    case comment
    case mosaic
    case brickBarRequest

    var displayName: String {
        switch self {
        case .article: return "News"
        case .review: return "Review"
        case .lesson: return "Lesson"
        case .product: return "Shop"
        case .comment: return "Comment"
        case .mosaic: return "Design"
        case .brickBarRequest: return "Brick Bar"
        }
    }
}

struct LikeRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var contentType: ContentType
    var contentID: UUID
    var createdAt: Date
}

struct SavedItem: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var contentType: ContentType
    var contentID: UUID
    var createdAt: Date
}

enum NotificationKind: String, Codable {
    case news
    case commentReply
    case commentLike
    case brickBarUpdate
    case quoteSent
    case newLesson
    case mosaicReady
    case general

    var symbol: String {
        switch self {
        case .news: return "newspaper"
        case .commentReply: return "bubble.left.and.bubble.right"
        case .commentLike: return "heart"
        case .brickBarUpdate: return "wrench.and.screwdriver"
        case .quoteSent: return "sterlingsign.circle"
        case .newLesson: return "graduationcap"
        case .mosaicReady: return "square.grid.3x3"
        case .general: return "bell"
        }
    }
}

struct NotificationItem: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var kind: NotificationKind
    var title: String
    var body: String
    var targetType: ContentType?
    var targetID: UUID?
    var readAt: Date?
    var createdAt: Date
}
