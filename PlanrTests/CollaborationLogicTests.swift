import XCTest
@testable import Planr

final class CollaborationLogicTests: XCTestCase {

    // MARK: Lockdown rules

    func testLockdownRequiresLeaderAndDate() {
        var event = Event(title: "Trip", phase: .planning, leaderID: "leader",
                          participantIDs: ["leader", "u2"])
        XCTAssertFalse(LockdownPolicy.canLockdown(event, userID: "leader"), "No date yet")

        event.startDate = .now.addingTimeInterval(86_400 * 30)
        XCTAssertTrue(LockdownPolicy.canLockdown(event, userID: "leader"))
        XCTAssertFalse(LockdownPolicy.canLockdown(event, userID: "u2"), "Participants can't lock")

        event.phase = .lockdown
        XCTAssertFalse(LockdownPolicy.canLockdown(event, userID: "leader"), "Already locked")
    }

    func testLockedCoreDetailsNeedLeaderOverride() {
        let event = Event(title: "Trip", phase: .lockdown, leaderID: "leader",
                          coLeaderIDs: ["co"], participantIDs: ["leader", "co", "u2"])
        XCTAssertTrue(LockdownPolicy.canEditCoreDetails(of: event, userID: "leader"))
        XCTAssertFalse(LockdownPolicy.canEditCoreDetails(of: event, userID: "co"),
                       "Co-leaders need a reopen vote after lockdown")
        XCTAssertTrue(LockdownPolicy.requiresReopenVote(event: event, userID: "co"))
        XCTAssertFalse(LockdownPolicy.requiresReopenVote(event: event, userID: "leader"))
    }

    func testCoLeaderCanEditBeforeLockdown() {
        let event = Event(title: "Trip", phase: .planning, leaderID: "leader",
                          coLeaderIDs: ["co"], participantIDs: ["leader", "co", "u2"])
        XCTAssertTrue(LockdownPolicy.canEditCoreDetails(of: event, userID: "co"))
        XCTAssertFalse(LockdownPolicy.canEditCoreDetails(of: event, userID: "u2"))
    }

    func testLiveModeOpensTheDayBefore() {
        let calendar = Calendar.current
        var event = Event(title: "Trip", phase: .lockdown, leaderID: "leader",
                          participantIDs: ["leader"],
                          startDate: calendar.date(byAdding: .day, value: 10, to: .now))
        XCTAssertFalse(LockdownPolicy.canStartLiveMode(event, userID: "leader"))

        event.startDate = calendar.date(byAdding: .hour, value: 20, to: .now)
        XCTAssertTrue(LockdownPolicy.canStartLiveMode(event, userID: "leader"))
    }

    // MARK: Task overdue

    func testTaskOverdueOnlyWhenPastDueAndIncomplete() {
        let yesterday = Date.now.addingTimeInterval(-86_400)
        var task = EventTask(eventID: "e", title: "Book", assigneeID: "u1",
                             createdByID: "leader", dueDate: yesterday)
        XCTAssertTrue(task.isOverdue())

        task.status = .complete
        XCTAssertFalse(task.isOverdue())

        task.status = .open
        task.dueDate = nil
        XCTAssertFalse(task.isOverdue())
    }

    // MARK: Payment status

    func testPaymentOverdueAndOutstandingCounts() {
        let yesterday = Date.now.addingTimeInterval(-86_400)
        var payment = Payment(eventID: "e", title: "Deposit", amountPerPerson: 50,
                              paidByID: "leader",
                              shares: [PaymentShare(userID: "u1", state: .owed),
                                       PaymentShare(userID: "u2", state: .confirmed)],
                              dueDate: yesterday)
        XCTAssertTrue(payment.isOverdue())
        XCTAssertEqual(payment.outstandingCount, 1)

        payment.shares[0].state = .confirmed
        XCTAssertFalse(payment.isOverdue(), "Fully confirmed payments are never overdue")
        XCTAssertEqual(payment.outstandingCount, 0)
    }

    // MARK: Shame board safety

    func testHiddenUsersNeverAppearOnShameBoard() {
        let hidden = UserProfile(displayName: "Gary", hiddenFromShameBoard: true)
        let visible = UserProfile(displayName: "Sarah")
        let payments = [
            Payment(eventID: "e", title: "Deposit", amountPerPerson: 50, paidByID: "x",
                    shares: [PaymentShare(userID: hidden.id, state: .owed),
                             PaymentShare(userID: visible.id, state: .confirmed,
                                          markedPaidAt: .now, confirmedAt: .now)]),
        ]
        let entries = ShameBoardCalculator.entries(participants: [hidden, visible],
                                                   tasks: [], payments: payments)
        XCTAssertFalse(entries.contains { $0.userID == hidden.id })
    }

    // MARK: Event wrap

    func testWrapBuildsAwardsFromData() {
        let leader = UserProfile(displayName: "Pete Donnelly")
        let friend = UserProfile(displayName: "Dave Hutton")
        let event = Event(title: "Night out", phase: .completed, leaderID: leader.id,
                          participantIDs: [leader.id, friend.id], startDate: .now)
        let tasks = [EventTask(eventID: event.id, title: "Book", assigneeID: friend.id,
                               createdByID: leader.id, status: .complete)]
        let messages = [ChatMessage(eventID: event.id, senderID: leader.id,
                                    text: "Legendary", reactions: ["❤️": [friend.id]])]
        let wrap = EventWrapBuilder.build(event: event,
                                          participants: [leader, friend],
                                          votes: [], tasks: tasks, payments: [],
                                          messages: messages, photos: [], bingo: nil)

        XCTAssertEqual(wrap.awards.first { $0.title == "Event MVP" }?.userID, friend.id)
        XCTAssertEqual(wrap.topMessageID, messages[0].id)
        XCTAssertFalse(wrap.stats.isEmpty)
    }
}
