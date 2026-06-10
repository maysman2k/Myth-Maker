import Foundation

enum BingoStatus: String, Codable {
    case collecting   // gathering predictions before the event
    case playing      // cards dealt, claims open
    case finished
}

struct BingoSubmission: Identifiable, Codable, Hashable {
    var id: String
    var authorID: String
    var text: String
    var approved: Bool

    init(id: String = UUID().uuidString, authorID: String, text: String, approved: Bool = false) {
        self.id = id
        self.authorID = authorID
        self.text = text
        self.approved = approved
    }
}

struct BingoSquare: Identifiable, Codable, Hashable {
    var submissionID: String
    /// Who says it happened — pending until the leader confirms.
    var claimedByID: String?
    var confirmed: Bool

    var id: String { submissionID }

    init(submissionID: String, claimedByID: String? = nil, confirmed: Bool = false) {
        self.submissionID = submissionID
        self.claimedByID = claimedByID
        self.confirmed = confirmed
    }
}

struct BingoCard: Identifiable, Codable, Hashable {
    var id: String
    var ownerID: String
    var squares: [BingoSquare]

    init(id: String = UUID().uuidString, ownerID: String, squares: [BingoSquare]) {
        self.id = id
        self.ownerID = ownerID
        self.squares = squares
    }

    var isComplete: Bool {
        !squares.isEmpty && squares.allSatisfy(\.confirmed)
    }

    var confirmedCount: Int {
        squares.filter(\.confirmed).count
    }
}

struct BingoGame: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    var status: BingoStatus
    var submissions: [BingoSubmission]
    var cards: [BingoCard]
    var winnerID: String?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         status: BingoStatus = .collecting,
         submissions: [BingoSubmission] = [],
         cards: [BingoCard] = [],
         winnerID: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.status = status
        self.submissions = submissions
        self.cards = cards
        self.winnerID = winnerID
        self.createdAt = createdAt
    }

    var approvedSubmissions: [BingoSubmission] {
        submissions.filter(\.approved)
    }

    func card(for userID: String) -> BingoCard? {
        cards.first { $0.ownerID == userID }
    }

    func submission(withID id: String) -> BingoSubmission? {
        submissions.first { $0.id == id }
    }
}
