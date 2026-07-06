import Foundation

/// Everything the app persists between launches.
struct AppSnapshot: Codable {
    var accounts: [UserAccount] = []
    var currentUserID: UUID?
    var articles: [Article] = []
    var reviews: [Review] = []
    var products: [Product] = []
    var lessons: [Lesson] = []
    var comments: [Comment] = []
    var commentReports: [CommentReport] = []
    var likes: [LikeRecord] = []
    var savedItems: [SavedItem] = []
    var userRatings: [ReviewUserRating] = []
    var notifications: [NotificationItem] = []
    var mosaics: [MosaicProject] = []
    var brickBarRequests: [BrickBarRequest] = []
    var aiDrafts: [AIDraft] = []
    var recentSearches: [String] = []
    var hasCompletedOnboarding = false
}
