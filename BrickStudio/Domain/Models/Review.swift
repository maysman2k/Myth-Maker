import Foundation

enum ReviewVerdict: String, Codable, CaseIterable {
    case essential = "Essential"
    case recommended = "Recommended"
    case goodDisplayPiece = "Good Display Piece"
    case greatPartsPack = "Great Parts Pack"
    case overpriced = "Overpriced"
    case betterOnSale = "Better on Sale"
    case collectorFavourite = "Collector Favourite"
    case oneForFans = "One for Fans"
    case skipIt = "Skip It"

    var isPositive: Bool {
        switch self {
        case .overpriced, .betterOnSale, .skipIt: return false
        default: return true
        }
    }
}

enum ReviewCategory: String, Codable, CaseIterable, Identifiable {
    case legoSets = "LEGO® Sets"
    case compatibleSets = "Compatible Brick Sets"
    case stadiumSets = "Stadium Sets"
    case displayModels = "Display Models"
    case modularBuildings = "Modular Buildings"
    case vehicles = "Vehicles"
    case architecture = "Architecture"
    case mosaics = "Mosaics"
    case adultCollector = "Adult Collector Sets"
    case retiredSets = "Retired Sets"
    case valuePicks = "Value Picks"
    case premiumPicks = "Premium Picks"

    var id: String { rawValue }
}

/// 5-star rating breakdown (§12.6).
struct RatingBreakdown: Codable, Hashable {
    var buildExperience: Double
    var displayValue: Double
    var partsSelection: Double
    var accuracyDetail: Double
    var valueForMoney: Double
    var funFactor: Double

    var categories: [(name: String, score: Double)] {
        [
            ("Build experience", buildExperience),
            ("Display value", displayValue),
            ("Parts selection", partsSelection),
            ("Accuracy & detail", accuracyDetail),
            ("Value for money", valueForMoney),
            ("Fun factor", funFactor)
        ]
    }
}

struct Review: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var slug: String
    var brand: String
    var setName: String
    var setNumber: String?
    var pieceCount: Int?
    var ageRange: String?
    var releaseYear: Int?
    var retailPrice: Double?
    var currency: String
    var availability: String
    var category: ReviewCategory
    var summary: String
    var verdict: ReviewVerdict
    var pros: [String]
    var cons: [String]
    var bodyMarkdown: String
    var ratingOverall: Double
    var breakdown: RatingBreakdown
    var buildDifficulty: String
    var status: PublishStatus
    var commentsEnabled: Bool
    var likeCount: Int
    var viewCount: Int
    var publishedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var priceLabel: String {
        guard let retailPrice else { return "Price varies" }
        return retailPrice.formatted(.currency(code: currency).precision(.fractionLength(0...2)))
    }
}

struct ReviewUserRating: Identifiable, Codable, Hashable {
    var id: UUID
    var reviewID: UUID
    var userID: UUID
    var rating: Double
    var comment: String
    var ownsSet: Bool
    var builtSet: Bool
    var createdAt: Date
}

enum BrickBrand {
    /// Neutral wording per §12.3 — never claim unconfirmed official compatibility.
    static let known = ["LEGO®", "Cobi", "CaDA", "Mould King", "Pantasy", "BlueBrixx", "FunWhole"]
}
