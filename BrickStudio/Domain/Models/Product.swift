import Foundation

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case stadiumBuilds = "Stadium Builds"
    case footballStadiums = "Football Stadiums"
    case customStadiums = "Custom Stadiums"
    case mosaics = "Mosaics"
    case displayBuilds = "Display Builds"
    case gifts = "Gifts"
    case limitedRuns = "Limited Runs"
    case newReleases = "New Releases"
    case accessories = "Accessories"

    var id: String { rawValue }
}

enum ProductStatus: String, Codable, CaseIterable {
    case draft
    case active
    case soldOut = "sold_out"
    case retired
    case hidden

    var displayName: String {
        switch self {
        case .soldOut: return "Sold out"
        default: return rawValue.capitalized
        }
    }
}

struct Product: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var slug: String
    var shortDescription: String
    var description: String
    var category: ProductCategory
    var price: Double?
    var fromPrice: Double?
    var currency: String
    var status: ProductStatus
    var availability: String
    var externalShopURL: String
    var pieceCountEstimate: Int?
    var dimensions: String
    var leadTime: String
    var deliveryInfo: String
    var tags: [String]
    var viewCount: Int
    var saveCount: Int
    var createdAt: Date
    var updatedAt: Date

    var priceLabel: String {
        if let price {
            return price.formatted(.currency(code: currency).precision(.fractionLength(0...2)))
        }
        if let fromPrice {
            return "From " + fromPrice.formatted(.currency(code: currency).precision(.fractionLength(0...2)))
        }
        return "Price on request"
    }
}
