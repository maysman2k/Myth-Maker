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
    var submittedStories: [SubmittedStory] = []
    var recentSearches: [String] = []
    var hasCompletedOnboarding = false

    init(
        accounts: [UserAccount] = [],
        currentUserID: UUID? = nil,
        articles: [Article] = [],
        reviews: [Review] = [],
        products: [Product] = [],
        lessons: [Lesson] = [],
        comments: [Comment] = [],
        commentReports: [CommentReport] = [],
        likes: [LikeRecord] = [],
        savedItems: [SavedItem] = [],
        userRatings: [ReviewUserRating] = [],
        notifications: [NotificationItem] = [],
        mosaics: [MosaicProject] = [],
        brickBarRequests: [BrickBarRequest] = [],
        aiDrafts: [AIDraft] = [],
        submittedStories: [SubmittedStory] = [],
        recentSearches: [String] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.accounts = accounts
        self.currentUserID = currentUserID
        self.articles = articles
        self.reviews = reviews
        self.products = products
        self.lessons = lessons
        self.comments = comments
        self.commentReports = commentReports
        self.likes = likes
        self.savedItems = savedItems
        self.userRatings = userRatings
        self.notifications = notifications
        self.mosaics = mosaics
        self.brickBarRequests = brickBarRequests
        self.aiDrafts = aiDrafts
        self.submittedStories = submittedStories
        self.recentSearches = recentSearches
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([UserAccount].self, forKey: .accounts) ?? []
        currentUserID = try container.decodeIfPresent(UUID.self, forKey: .currentUserID)
        articles = try container.decodeIfPresent([Article].self, forKey: .articles) ?? []
        reviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        lessons = try container.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
        commentReports = try container.decodeIfPresent([CommentReport].self, forKey: .commentReports) ?? []
        likes = try container.decodeIfPresent([LikeRecord].self, forKey: .likes) ?? []
        savedItems = try container.decodeIfPresent([SavedItem].self, forKey: .savedItems) ?? []
        userRatings = try container.decodeIfPresent([ReviewUserRating].self, forKey: .userRatings) ?? []
        notifications = try container.decodeIfPresent([NotificationItem].self, forKey: .notifications) ?? []
        mosaics = try container.decodeIfPresent([MosaicProject].self, forKey: .mosaics) ?? []
        brickBarRequests = try container.decodeIfPresent([BrickBarRequest].self, forKey: .brickBarRequests) ?? []
        aiDrafts = try container.decodeIfPresent([AIDraft].self, forKey: .aiDrafts) ?? []
        submittedStories = try container.decodeIfPresent([SubmittedStory].self, forKey: .submittedStories) ?? []
        recentSearches = try container.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}
