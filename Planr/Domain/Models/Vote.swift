import Foundation

enum VoteKind: String, Codable, CaseIterable {
    case dateAvailability
    case location
    case freeform

    var label: String {
        switch self {
        case .dateAvailability: return "Dates"
        case .location: return "Location"
        case .freeform: return "Question"
        }
    }

    var symbol: String {
        switch self {
        case .dateAvailability: return "calendar"
        case .location: return "mappin.and.ellipse"
        case .freeform: return "questionmark.bubble"
        }
    }
}

enum VoteStatus: String, Codable {
    case open
    case confirmed
}

struct VoteOption: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var subtitle: String?
    /// Set for date-availability options; drives calendar-style display.
    var date: Date?

    init(id: String = UUID().uuidString, label: String, subtitle: String? = nil, date: Date? = nil) {
        self.id = id
        self.label = label
        self.subtitle = subtitle
        self.date = date
    }
}

struct VoteResponse: Identifiable, Codable, Hashable {
    var id: String
    var userID: String
    var optionIDs: [String]
    var respondedAt: Date

    init(id: String = UUID().uuidString, userID: String, optionIDs: [String], respondedAt: Date = .now) {
        self.id = id
        self.userID = userID
        self.optionIDs = optionIDs
        self.respondedAt = respondedAt
    }
}

struct Vote: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    var createdByID: String
    var title: String
    var detail: String?
    var kind: VoteKind
    var options: [VoteOption]
    var allowsMultipleSelection: Bool
    var deadline: Date?
    var status: VoteStatus
    var winningOptionID: String?
    var responses: [VoteResponse]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         createdByID: String,
         title: String,
         detail: String? = nil,
         kind: VoteKind,
         options: [VoteOption],
         allowsMultipleSelection: Bool = false,
         deadline: Date? = nil,
         status: VoteStatus = .open,
         winningOptionID: String? = nil,
         responses: [VoteResponse] = [],
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.createdByID = createdByID
        self.title = title
        self.detail = detail
        self.kind = kind
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection || kind == .dateAvailability
        self.deadline = deadline
        self.status = status
        self.winningOptionID = winningOptionID
        self.responses = responses
        self.createdAt = createdAt
    }

    var isOpen: Bool { status == .open }

    func isPastDeadline(now: Date = .now) -> Bool {
        guard let deadline else { return false }
        return deadline < now
    }

    func response(from userID: String) -> VoteResponse? {
        responses.first { $0.userID == userID }
    }

    var winningOption: VoteOption? {
        options.first { $0.id == winningOptionID }
    }
}
