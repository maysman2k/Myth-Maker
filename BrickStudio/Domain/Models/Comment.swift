import Foundation

enum CommentStatus: String, Codable {
    case visible
    case hidden
    case deleted
    case pendingReview = "pending_review"
}

enum CommentSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case mostLiked = "Most liked"

    var id: String { rawValue }
}

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "Spam"
    case abuse = "Abuse"
    case hateOrHarassment = "Hate or harassment"
    case personalInformation = "Personal information"
    case misinformation = "Misinformation"
    case other = "Other"

    var id: String { rawValue }
}

struct Comment: Identifiable, Codable, Hashable {
    var id: UUID
    var contentType: ContentType
    var contentID: UUID
    var parentCommentID: UUID?
    var userID: UUID
    var body: String
    var status: CommentStatus
    var likeCount: Int
    var reportCount: Int
    var createdAt: Date
    var editedAt: Date?
}

struct CommentReport: Identifiable, Codable, Hashable {
    var id: UUID
    var commentID: UUID
    var reporterUserID: UUID
    var reason: ReportReason
    var details: String
    var createdAt: Date
}
