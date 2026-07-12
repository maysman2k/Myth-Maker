import Foundation
import Observation

enum MainTab: String, CaseIterable, Identifiable {
    case today
    case news
    case create
    case shop
    case brickBar
    case games

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .news: return "News"
        case .create: return "Mosiac Maker"
        case .shop: return "Shop"
        case .brickBar: return "Brick Bar"
        case .games: return "Games"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .news: return "newspaper"
        case .create: return "square.grid.3x3"
        case .shop: return "bag"
        case .brickBar: return "wrench.and.screwdriver"
        case .games: return "gamecontroller"
        }
    }
}

struct Toast: Equatable {
    var message: String
    var symbol: String
}

struct AdminStats {
    var totalUsers = 0
    var articlesPublished = 0
    var commentsPosted = 0
    var pendingDrafts = 0
    var pendingComments = 0
    var openRequests = 0
    var mosaicsCreated = 0
    var openReports = 0
}

@Observable
final class AppModel {
    // MARK: Persisted state
    var accounts: [UserAccount]
    var currentUserID: UUID?
    var articles: [Article]
    var reviews: [Review]
    var products: [Product]
    var lessons: [Lesson]
    var comments: [Comment]
    var commentReports: [CommentReport]
    var likes: [LikeRecord]
    var savedItems: [SavedItem]
    var userRatings: [ReviewUserRating]
    var notifications: [NotificationItem]
    var mosaics: [MosaicProject]
    var brickBarRequests: [BrickBarRequest]
    var aiDrafts: [AIDraft]
    var submittedStories: [SubmittedStory]
    var recentSearches: [String]
    var hasCompletedOnboarding: Bool

    // MARK: Session-only UI state
    var selectedTab: MainTab = .today
    var toast: Toast?
    var isShowingAuth = false
    /// True while a manually triggered scanner run is in flight (dispatch +
    /// waiting for its drafts to land in the feed).
    var isScannerRunning = false

    init(snapshot: AppSnapshot? = nil) {
        let snap = snapshot ?? LocalStore.load() ?? SeedFactory.makeSnapshot()
        accounts = snap.accounts
        currentUserID = snap.currentUserID
        articles = snap.articles
        reviews = snap.reviews
        products = snap.products
        lessons = snap.lessons
        comments = snap.comments
        commentReports = snap.commentReports
        likes = snap.likes
        savedItems = snap.savedItems
        userRatings = snap.userRatings
        notifications = snap.notifications
        mosaics = snap.mosaics
        brickBarRequests = snap.brickBarRequests
        aiDrafts = snap.aiDrafts
        submittedStories = snap.submittedStories
        recentSearches = snap.recentSearches
        hasCompletedOnboarding = snap.hasCompletedOnboarding
    }

    var snapshot: AppSnapshot {
        AppSnapshot(
            accounts: accounts,
            currentUserID: currentUserID,
            articles: articles,
            reviews: reviews,
            products: products,
            lessons: lessons,
            comments: comments,
            commentReports: commentReports,
            likes: likes,
            savedItems: savedItems,
            userRatings: userRatings,
            notifications: notifications,
            mosaics: mosaics,
            brickBarRequests: brickBarRequests,
            aiDrafts: aiDrafts,
            submittedStories: submittedStories,
            recentSearches: recentSearches,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    func persist() {
        LocalStore.save(snapshot)
    }

    // MARK: Accounts

    var currentUser: UserAccount? {
        accounts.first { $0.id == currentUserID }
    }

    var isSignedIn: Bool { currentUser != nil }

    func account(id: UUID?) -> UserAccount? {
        accounts.first { $0.id == id }
    }

    func displayName(for userID: UUID) -> String {
        account(id: userID)?.displayName ?? "Former member"
    }

    // MARK: Published content

    var publishedArticles: [Article] {
        articles
            .filter { $0.status == .published }
            .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    var publishedReviews: [Review] {
        reviews
            .filter { $0.status == .published }
            .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    var activeProducts: [Product] {
        products
            .filter { $0.status == .active || $0.status == .soldOut }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var publishedLessons: [Lesson] {
        lessons
            .filter { $0.status == .published }
            .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    // MARK: Comments

    /// Comments a given viewer should see: everything visible, plus their own
    /// posts that are awaiting moderation.
    func viewableComments(for type: ContentType, contentID: UUID) -> [Comment] {
        comments.filter {
            $0.contentType == type && $0.contentID == contentID &&
            ($0.status == .visible || ($0.status == .pendingReview && $0.userID == currentUserID))
        }
    }

    func topLevelComments(for type: ContentType, contentID: UUID, sort: CommentSort) -> [Comment] {
        let items = viewableComments(for: type, contentID: contentID).filter { $0.parentCommentID == nil }
        switch sort {
        case .newest: return items.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return items.sorted { $0.createdAt < $1.createdAt }
        case .mostLiked: return items.sorted { $0.likeCount != $1.likeCount ? $0.likeCount > $1.likeCount : $0.createdAt > $1.createdAt }
        }
    }

    func replies(to commentID: UUID, type: ContentType, contentID: UUID) -> [Comment] {
        viewableComments(for: type, contentID: contentID)
            .filter { $0.parentCommentID == commentID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func commentCount(for type: ContentType, contentID: UUID) -> Int {
        comments.filter { $0.contentType == type && $0.contentID == contentID && $0.status == .visible }.count
    }

    // MARK: Engagement lookups

    func isLiked(_ type: ContentType, _ contentID: UUID) -> Bool {
        guard let currentUserID else { return false }
        return likes.contains { $0.userID == currentUserID && $0.contentType == type && $0.contentID == contentID }
    }

    func isBookmarked(_ type: ContentType, _ contentID: UUID) -> Bool {
        guard let currentUserID else { return false }
        return savedItems.contains { $0.userID == currentUserID && $0.contentType == type && $0.contentID == contentID }
    }

    func mySavedItems(of type: ContentType? = nil) -> [SavedItem] {
        guard let currentUserID else { return [] }
        return savedItems
            .filter { $0.userID == currentUserID && (type == nil || $0.contentType == type) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func myRating(for reviewID: UUID) -> ReviewUserRating? {
        guard let currentUserID else { return nil }
        return userRatings.first { $0.reviewID == reviewID && $0.userID == currentUserID }
    }

    func communityRatings(for reviewID: UUID) -> [ReviewUserRating] {
        userRatings.filter { $0.reviewID == reviewID }
    }

    // MARK: My content

    var myNotifications: [NotificationItem] {
        guard let currentUserID else { return [] }
        return notifications
            .filter { $0.userID == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var unreadNotificationCount: Int {
        myNotifications.filter { $0.readAt == nil }.count
    }

    var mySubmittedStories: [SubmittedStory] {
        guard let currentUserID else { return [] }
        return submittedStories
            .filter { $0.userID == currentUserID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var pendingSubmittedStories: [SubmittedStory] {
        submittedStories
            .filter { $0.status == .pendingReview }
            .sorted { $0.submittedAt < $1.submittedAt }
    }

    var myMosaics: [MosaicProject] {
        guard let currentUserID else { return [] }
        return mosaics
            .filter { $0.userID == currentUserID && $0.status != .archived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var myBrickBarRequests: [BrickBarRequest] {
        guard let currentUserID else { return [] }
        return brickBarRequests
            .filter { $0.userID == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var myComments: [Comment] {
        guard let currentUserID else { return [] }
        return comments
            .filter { $0.userID == currentUserID && $0.status != .deleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Today feed helpers

    /// Articles and reviews with the liveliest comment threads (§8.11).
    var trendingDiscussions: [(type: ContentType, id: UUID, title: String, commentCount: Int, latest: Date)] {
        var items: [(ContentType, UUID, String, Int, Date)] = []
        for article in publishedArticles {
            let thread = comments.filter { $0.contentType == .article && $0.contentID == article.id && $0.status == .visible }
            guard let latest = thread.map(\.createdAt).max() else { continue }
            items.append((.article, article.id, article.title, thread.count, latest))
        }
        for review in publishedReviews {
            let thread = comments.filter { $0.contentType == .review && $0.contentID == review.id && $0.status == .visible }
            guard let latest = thread.map(\.createdAt).max() else { continue }
            items.append((.review, review.id, review.title, thread.count, latest))
        }
        return items
            .sorted { $0.3 != $1.3 ? $0.3 > $1.3 : $0.4 > $1.4 }
            .prefix(4)
            .map { (type: $0.0, id: $0.1, title: $0.2, commentCount: $0.3, latest: $0.4) }
    }

    // MARK: Search

    var searchDocuments: [SearchDocument] {
        var documents: [SearchDocument] = []
        documents += publishedArticles.map {
            SearchDocument(id: $0.id, contentType: .article, title: $0.title, summary: $0.summary, tags: $0.tags)
        }
        documents += publishedReviews.map {
            SearchDocument(id: $0.id, contentType: .review, title: $0.title, summary: $0.summary, tags: [$0.brand, $0.category.rawValue])
        }
        documents += activeProducts.map {
            SearchDocument(id: $0.id, contentType: .product, title: $0.name, summary: $0.shortDescription, tags: $0.tags + [$0.category.rawValue])
        }
        documents += publishedLessons.map {
            SearchDocument(id: $0.id, contentType: .lesson, title: $0.title, summary: $0.summary, tags: $0.tags + [$0.category.rawValue])
        }
        return documents
    }

    // MARK: Admin

    var adminStats: AdminStats {
        AdminStats(
            totalUsers: accounts.count,
            articlesPublished: articles.filter { $0.status == .published }.count,
            commentsPosted: comments.filter { $0.status != .deleted }.count,
            pendingDrafts: aiDrafts.filter { $0.status == .needsReview }.count,
            pendingComments: comments.filter { $0.status == .pendingReview }.count,
            openRequests: brickBarRequests.filter { $0.status.isOpen && $0.status != .draft }.count,
            mosaicsCreated: mosaics.count,
            openReports: commentReports.count
        )
    }
}
