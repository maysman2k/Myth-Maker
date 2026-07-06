import Foundation

enum BuildType: String, Codable, CaseIterable, Identifiable {
    case footballStadium = "Football stadium"
    case houseBuilding = "House or building"
    case shopfront = "Shopfront or business"
    case mosaic = "Mosaic"
    case gift = "Gift"
    case landmark = "Landmark"
    case displayModel = "Display model"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .footballStadium: return "sportscourt"
        case .houseBuilding: return "house"
        case .shopfront: return "storefront"
        case .mosaic: return "square.grid.3x3"
        case .gift: return "gift"
        case .landmark: return "building.columns"
        case .displayModel: return "cube.transparent"
        case .other: return "sparkles"
        }
    }
}

enum BudgetRange: String, Codable, CaseIterable, Identifiable {
    case under100 = "Under £100"
    case from100to250 = "£100–£250"
    case from250to500 = "£250–£500"
    case from500to1000 = "£500–£1,000"
    case over1000 = "£1,000+"
    case notSure = "Not sure yet"

    var id: String { rawValue }
}

enum DeadlineType: String, Codable, CaseIterable, Identifiable {
    case noRush = "No rush"
    case withinOneMonth = "Within 1 month"
    case oneToThreeMonths = "1–3 months"
    case threePlusMonths = "3+ months"
    case specificDate = "Specific date"

    var id: String { rawValue }
}

enum SizePreference: String, Codable, CaseIterable, Identifiable {
    case small = "Small — shelf display"
    case medium = "Medium — statement piece"
    case large = "Large — showcase build"
    case notSure = "Not sure — advise me"

    var id: String { rawValue }
}

enum RequestStatus: String, Codable, CaseIterable {
    case draft
    case submitted
    case reviewing
    case needMoreInfo = "need_more_info"
    case quoted
    case accepted
    case inProgress = "in_progress"
    case completed
    case cancelled
    case rejected

    var displayName: String {
        switch self {
        case .needMoreInfo: return "Needs more info"
        case .inProgress: return "In progress"
        default: return rawValue.capitalized
        }
    }

    var isOpen: Bool {
        switch self {
        case .completed, .cancelled, .rejected: return false
        default: return true
        }
    }
}

enum QuoteStatus: String, Codable {
    case notQuoted = "not_quoted"
    case quotePending = "quote_pending"
    case quoteSent = "quote_sent"
    case quoteAccepted = "quote_accepted"
    case quoteDeclined = "quote_declined"
}

struct BrickBarRequest: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var buildType: BuildType
    var title: String
    var description: String
    var referenceImageFilenames: [String]
    var sizePreference: SizePreference
    var budgetRange: BudgetRange
    var deadlineType: DeadlineType
    var deadlineDate: Date?
    var contactEmail: String
    var contactPhone: String
    var status: RequestStatus
    var adminNotes: String
    var quotedPrice: Double?
    var quoteStatus: QuoteStatus
    var createdAt: Date
    var updatedAt: Date
}
