import Foundation

enum PublishStatus: String, Codable, CaseIterable {
    case draft
    case scheduled
    case published
    case archived

    var displayName: String { rawValue.capitalized }
}

enum ArticleCategory: String, Codable, CaseIterable, Identifiable {
    case newSets = "New Sets"
    case rumours = "Rumours"
    case officialReveals = "Official Reveals"
    case retiringSoon = "Retiring Soon"
    case deals = "Deals"
    case events = "Events"
    case ideas = "Ideas"
    case stadiumBuilds = "Stadium Builds"
    case brickCulture = "Brick Culture"
    case bricksInABagUpdates = "Bricks in a Bag Updates"
    case compatibleBrands = "Compatible Brick Brands"
    case collectors = "Collectors"
    case displayBuilds = "Display Builds"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .newSets: return "sparkles"
        case .rumours: return "bubble.left.and.exclamationmark.bubble.right"
        case .officialReveals: return "megaphone"
        case .retiringSoon: return "clock.badge.exclamationmark"
        case .deals: return "tag"
        case .events: return "calendar"
        case .ideas: return "lightbulb"
        case .stadiumBuilds: return "sportscourt"
        case .brickCulture: return "person.3"
        case .bricksInABagUpdates: return "bag"
        case .compatibleBrands: return "square.grid.2x2"
        case .collectors: return "archivebox"
        case .displayBuilds: return "cube.transparent"
        }
    }
}

struct ArticleSource: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var url: String
}

struct Article: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var slug: String
    var summary: String
    var bodyMarkdown: String
    var category: ArticleCategory
    var tags: [String]
    var authorName: String
    var sources: [ArticleSource]
    var isRumour: Bool
    var aiAssisted: Bool
    var commentsEnabled: Bool
    var status: PublishStatus
    var likeCount: Int
    var viewCount: Int
    var readTimeMinutes: Int
    var publishedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    /// Remote hero image chosen by an editor at approval time. When nil the
    /// app shows its branded procedural artwork instead.
    var heroImageURL: String? = nil
    /// All editor-approved images for this article (the hero is the first).
    /// Rendered as an in-article photo gallery.
    var galleryImageURLs: [String]? = nil
}
