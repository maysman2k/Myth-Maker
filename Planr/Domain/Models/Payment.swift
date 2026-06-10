import Foundation

/// Per-person state of a tracked payment. Planr never holds money —
/// it only tracks who has settled up.
enum PaymentShareState: String, Codable {
    case owed
    case markedPaid
    case confirmed

    var label: String {
        switch self {
        case .owed: return "Owes"
        case .markedPaid: return "Says it's paid"
        case .confirmed: return "Paid"
        }
    }
}

struct PaymentShare: Identifiable, Codable, Hashable {
    var userID: String
    var state: PaymentShareState
    var markedPaidAt: Date?
    var confirmedAt: Date?

    var id: String { userID }

    init(userID: String, state: PaymentShareState = .owed,
         markedPaidAt: Date? = nil, confirmedAt: Date? = nil) {
        self.userID = userID
        self.state = state
        self.markedPaidAt = markedPaidAt
        self.confirmedAt = confirmedAt
    }
}

struct Payment: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    var title: String
    /// Amount each person owes (not the pot total).
    var amountPerPerson: Decimal
    var currencyCode: String
    var paidByID: String
    var shares: [PaymentShare]
    var dueDate: Date?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         title: String,
         amountPerPerson: Decimal,
         currencyCode: String = "GBP",
         paidByID: String,
         shares: [PaymentShare],
         dueDate: Date? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.title = title
        self.amountPerPerson = amountPerPerson
        self.currencyCode = currencyCode
        self.paidByID = paidByID
        self.shares = shares
        self.dueDate = dueDate
        self.createdAt = createdAt
    }

    func share(for userID: String) -> PaymentShare? {
        shares.first { $0.userID == userID }
    }

    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate else { return false }
        return dueDate < now && shares.contains { $0.state != .confirmed }
    }

    var outstandingCount: Int {
        shares.filter { $0.state != .confirmed }.count
    }

    var formattedAmount: String {
        amountPerPerson.formatted(.currency(code: currencyCode))
    }
}
