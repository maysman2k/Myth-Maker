import Foundation

/// Deals randomised bingo cards from the approved prediction pool.
enum BingoCardGenerator {

    static let defaultCardSize = 5
    /// Need at least one spare so cards aren't all identical.
    static func minimumSubmissions(cardSize: Int = defaultCardSize) -> Int { cardSize + 1 }

    /// Deals one card per participant. Deterministic for a given seed.
    /// Avoids giving a player their own submissions when the pool allows it.
    static func deal(submissions: [BingoSubmission],
                     to participantIDs: [String],
                     cardSize: Int = defaultCardSize,
                     seed: UInt64 = UInt64.random(in: .min ... .max)) -> [BingoCard] {
        let approved = submissions.filter(\.approved)
        guard approved.count >= cardSize else { return [] }

        var generator = SeededRandomGenerator(seed: seed)
        return participantIDs.map { ownerID in
            let othersFirst = approved.filter { $0.authorID != ownerID }
            let pool = othersFirst.count >= cardSize ? othersFirst : approved
            let picked = pool.shuffled(using: &generator).prefix(cardSize)
            return BingoCard(ownerID: ownerID,
                             squares: picked.map { BingoSquare(submissionID: $0.id) })
        }
    }

    /// First card with every square confirmed wins.
    static func winnerID(in cards: [BingoCard]) -> String? {
        cards.first { $0.isComplete }?.ownerID
    }
}
