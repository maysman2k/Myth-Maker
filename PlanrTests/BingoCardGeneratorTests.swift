import XCTest
@testable import Planr

final class BingoCardGeneratorTests: XCTestCase {

    private func submissions(_ count: Int, author: String = "author") -> [BingoSubmission] {
        (0..<count).map { BingoSubmission(authorID: author, text: "Prediction \($0)", approved: true) }
    }

    func testDealsOneCardPerParticipantWithCorrectSize() {
        let cards = BingoCardGenerator.deal(submissions: submissions(8),
                                            to: ["u1", "u2", "u3"], seed: 7)
        XCTAssertEqual(cards.count, 3)
        XCTAssertTrue(cards.allSatisfy { $0.squares.count == 5 })
    }

    func testDealIsDeterministicForSeed() {
        let pool = submissions(10)
        let first = BingoCardGenerator.deal(submissions: pool, to: ["u1", "u2"], seed: 99)
        let second = BingoCardGenerator.deal(submissions: pool, to: ["u1", "u2"], seed: 99)
        XCTAssertEqual(first.map { $0.squares.map(\.submissionID) },
                       second.map { $0.squares.map(\.submissionID) })
    }

    func testTooFewApprovedSubmissionsDealsNothing() {
        let cards = BingoCardGenerator.deal(submissions: submissions(4), to: ["u1"], seed: 1)
        XCTAssertTrue(cards.isEmpty)
    }

    func testUnapprovedSubmissionsAreExcluded() {
        var pool = submissions(5)
        pool.append(BingoSubmission(authorID: "x", text: "Not approved", approved: false))
        let cards = BingoCardGenerator.deal(submissions: pool, to: ["u1"], seed: 3)
        XCTAssertFalse(cards[0].squares.contains { square in
            pool.first(where: { $0.id == square.submissionID })?.approved == false
        })
    }

    func testPlayersAvoidOwnSubmissionsWhenPoolAllows() {
        let mine = submissions(3, author: "me")
        let others = submissions(6, author: "someone")
        let cards = BingoCardGenerator.deal(submissions: mine + others, to: ["me"], seed: 11)
        let dealtAuthors = cards[0].squares.compactMap { square in
            (mine + others).first { $0.id == square.submissionID }?.authorID
        }
        XCTAssertFalse(dealtAuthors.contains("me"))
    }

    func testWinnerIsFirstCompleteCard() {
        let pool = submissions(6)
        var cards = BingoCardGenerator.deal(submissions: pool, to: ["u1", "u2"], seed: 5)
        XCTAssertNil(BingoCardGenerator.winnerID(in: cards))
        cards[1].squares = cards[1].squares.map {
            BingoSquare(submissionID: $0.submissionID, claimedByID: "u2", confirmed: true)
        }
        XCTAssertEqual(BingoCardGenerator.winnerID(in: cards), "u2")
    }
}
