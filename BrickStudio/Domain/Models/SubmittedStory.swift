import Foundation

enum SubmittedStoryStatus: String, Codable, CaseIterable {
    case pendingReview
    case changesRequested
    case published
    case locked

    var displayName: String {
        switch self {
        case .pendingReview: return "Pending Review"
        case .changesRequested: return "Changes Requested"
        case .published: return "Published"
        case .locked: return "Locked"
        }
    }
}

struct SubmittedStory: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var title: String
    var summary: String
    var bodyMarkdown: String
    var category: ArticleCategory
    var tags: [String]
    var imageReferences: [String]
    var mediaReferences: [String]
    var links: [ArticleSource]
    var isRumour: Bool
    var aiAssisted: Bool
    var status: SubmittedStoryStatus
    var declineCount: Int
    var latestFeedback: String?
    var publishedArticleID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var submittedAt: Date
}
