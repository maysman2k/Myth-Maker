import XCTest
@testable import Planr

final class EventPulseCalculatorTests: XCTestCase {

    private func makeEvent(startDate: Date? = nil, location: String? = nil) -> Event {
        Event(title: "Test", leaderID: "leader", participantIDs: ["leader", "u2"],
              startDate: startDate, locationName: location)
    }

    func testEmptyEventWithDateAndLocationScoresFull() {
        let event = makeEvent(startDate: .now, location: "Dublin")
        let pulse = EventPulseCalculator.calculate(event: event, votes: [], tasks: [],
                                                   payments: [], participantCount: 2)
        XCTAssertEqual(pulse.score, 100)
    }

    func testMissingBasicsLowerTheScore() {
        let event = makeEvent()
        let pulse = EventPulseCalculator.calculate(event: event, votes: [], tasks: [],
                                                   payments: [], participantCount: 2)
        // Decisions component is half-weighted by missing date+location.
        XCTAssertLessThan(pulse.score, 100)
        XCTAssertGreaterThan(pulse.score, 50)
    }

    func testIncompleteTasksAndPaymentsReduceScore() {
        let event = makeEvent(startDate: .now, location: "Dublin")
        let tasks = [
            EventTask(eventID: event.id, title: "Done", assigneeID: "u2",
                      createdByID: "leader", status: .complete),
            EventTask(eventID: event.id, title: "Open", assigneeID: "u2", createdByID: "leader"),
        ]
        let payments = [
            Payment(eventID: event.id, title: "Deposit", amountPerPerson: 50, paidByID: "leader",
                    shares: [PaymentShare(userID: "u2", state: .owed)]),
        ]
        let pulse = EventPulseCalculator.calculate(event: event, votes: [], tasks: tasks,
                                                   payments: payments, participantCount: 2)
        // tasks at 50% (-12.5), payments at 0% (-25) => 62-63.
        XCTAssertEqual(pulse.score, 63, accuracy: 1)
        XCTAssertEqual(pulse.components.count, 4)
    }

    func testHeadlineMentionsBlockerWhenNearlyThere() {
        let pulse = EventPulseCalculator.Pulse(score: 82, components: [])
        let headline = EventPulseCalculator.headline(for: pulse, blockerName: "Gary")
        XCTAssertTrue(headline.contains("Gary"))
    }
}

private func XCTAssertEqual(_ value: Int, _ expected: Int, accuracy: Int,
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(abs(value - expected) <= accuracy,
                  "\(value) is not within \(accuracy) of \(expected)", file: file, line: line)
}
