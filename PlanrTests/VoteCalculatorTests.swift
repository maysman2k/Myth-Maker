import XCTest
@testable import Planr

final class VoteCalculatorTests: XCTestCase {

    private func makeVote(options: [VoteOption], responses: [VoteResponse]) -> Vote {
        Vote(eventID: "event", createdByID: "leader", title: "Test vote",
             kind: .freeform, options: options, responses: responses)
    }

    func testTalliesCountAndSortByVotes() {
        let optionA = VoteOption(label: "A")
        let optionB = VoteOption(label: "B")
        let vote = makeVote(options: [optionA, optionB], responses: [
            VoteResponse(userID: "u1", optionIDs: [optionB.id]),
            VoteResponse(userID: "u2", optionIDs: [optionB.id]),
            VoteResponse(userID: "u3", optionIDs: [optionA.id]),
        ])

        let tallies = VoteCalculator.tallies(for: vote, participantCount: 4)
        XCTAssertEqual(tallies.first?.option.id, optionB.id)
        XCTAssertEqual(tallies.first?.count, 2)
        XCTAssertEqual(tallies.first?.share, 0.5)
        XCTAssertEqual(tallies.last?.count, 1)
    }

    func testTiesBreakByOptionOrder() {
        let optionA = VoteOption(label: "A")
        let optionB = VoteOption(label: "B")
        let vote = makeVote(options: [optionA, optionB], responses: [
            VoteResponse(userID: "u1", optionIDs: [optionB.id]),
            VoteResponse(userID: "u2", optionIDs: [optionA.id]),
        ])

        let tallies = VoteCalculator.tallies(for: vote, participantCount: 2)
        XCTAssertEqual(tallies.first?.option.id, optionA.id, "Ties resolve to earlier option")
    }

    func testDateAvailabilityScoringFindsBestAttendedDate() {
        let saturday = VoteOption(label: "Sat", date: .now.addingTimeInterval(86_400 * 7))
        let sunday = VoteOption(label: "Sun", date: .now.addingTimeInterval(86_400 * 8))
        let vote = Vote(eventID: "event", createdByID: "leader", title: "Dates",
                        kind: .dateAvailability, options: [saturday, sunday],
                        responses: [
                            VoteResponse(userID: "u1", optionIDs: [saturday.id, sunday.id]),
                            VoteResponse(userID: "u2", optionIDs: [saturday.id]),
                            VoteResponse(userID: "u3", optionIDs: [saturday.id]),
                        ])

        let leading = VoteCalculator.leadingTally(for: vote, participantCount: 3)
        XCTAssertEqual(leading?.option.id, saturday.id)
        XCTAssertEqual(VoteCalculator.consensus(count: leading?.count ?? 0, participantCount: 3),
                       .unanimous)
    }

    func testConsensusLevels() {
        XCTAssertEqual(VoteCalculator.consensus(count: 4, participantCount: 4), .unanimous)
        XCTAssertEqual(VoteCalculator.consensus(count: 3, participantCount: 4), .strongMajority)
        XCTAssertEqual(VoteCalculator.consensus(count: 2, participantCount: 4), .bestAvailable)
        XCTAssertEqual(VoteCalculator.consensus(count: 0, participantCount: 4), .none)
        XCTAssertEqual(VoteCalculator.consensus(count: 1, participantCount: 0), .none)
    }

    func testResponseRateAndNonResponders() {
        let option = VoteOption(label: "A")
        let vote = makeVote(options: [option], responses: [
            VoteResponse(userID: "u1", optionIDs: [option.id]),
        ])

        XCTAssertEqual(VoteCalculator.responseRate(for: vote, participantCount: 4), 0.25)
        XCTAssertEqual(VoteCalculator.nonResponders(for: vote, participantIDs: ["u1", "u2", "u3"]),
                       ["u2", "u3"])
    }

    func testLeadingTallyIsNilWithNoVotes() {
        let vote = makeVote(options: [VoteOption(label: "A")], responses: [])
        XCTAssertNil(VoteCalculator.leadingTally(for: vote, participantCount: 3))
    }
}
