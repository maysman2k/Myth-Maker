import XCTest
@testable import BrickStudio

final class CommentPolicyTests: XCTestCase {
    private func makeComment(
        userID: UUID = UUID(),
        parentID: UUID? = nil,
        status: CommentStatus = .visible,
        createdAt: Date = Date()
    ) -> Comment {
        Comment(
            id: UUID(),
            contentType: .article,
            contentID: UUID(),
            parentCommentID: parentID,
            userID: userID,
            body: "A perfectly reasonable comment.",
            status: status,
            likeCount: 0,
            reportCount: 0,
            createdAt: createdAt,
            editedAt: nil
        )
    }

    private func makeUser(role: UserRole = .user, createdAt: Date = Date().addingTimeInterval(-90 * 86_400)) -> UserAccount {
        var user = UserAccount.new(displayName: "Test", email: "test@example.com", passwordHash: "x", role: role)
        user.createdAt = createdAt
        return user
    }

    // MARK: Edit window (§11.3 — 15 minutes)

    func testAuthorCanEditWithinFifteenMinutes() {
        let userID = UUID()
        let comment = makeComment(userID: userID, createdAt: Date().addingTimeInterval(-10 * 60))
        XCTAssertTrue(CommentPolicy.canEdit(comment, by: userID))
    }

    func testAuthorCannotEditAfterFifteenMinutes() {
        let userID = UUID()
        let comment = makeComment(userID: userID, createdAt: Date().addingTimeInterval(-16 * 60))
        XCTAssertFalse(CommentPolicy.canEdit(comment, by: userID))
    }

    func testOtherUsersCannotEdit() {
        let comment = makeComment()
        XCTAssertFalse(CommentPolicy.canEdit(comment, by: UUID()))
        XCTAssertFalse(CommentPolicy.canEdit(comment, by: nil))
    }

    // MARK: Deletion

    func testAuthorAndModeratorCanDelete() {
        let author = makeUser()
        let moderator = makeUser(role: .moderator)
        let stranger = makeUser()
        let comment = makeComment(userID: author.id)
        XCTAssertTrue(CommentPolicy.canDelete(comment, by: author))
        XCTAssertTrue(CommentPolicy.canDelete(comment, by: moderator))
        XCTAssertFalse(CommentPolicy.canDelete(comment, by: stranger))
        XCTAssertFalse(CommentPolicy.canDelete(comment, by: nil))
    }

    // MARK: Threading depth (§11.4 — two levels max)

    func testReplyDepthLimitedToTwoLevels() {
        let top = makeComment()
        let reply = makeComment(parentID: top.id)
        let all = [top, reply]
        XCTAssertEqual(CommentPolicy.depth(of: top, in: all), 1)
        XCTAssertEqual(CommentPolicy.depth(of: reply, in: all), 2)
        XCTAssertTrue(CommentPolicy.canReply(to: top, in: all))
        XCTAssertFalse(CommentPolicy.canReply(to: reply, in: all))
    }

    // MARK: Moderation pre-checks (§11.8)

    func testFlaggedTermsGoToReview() {
        let oldAccount = Date().addingTimeInterval(-90 * 86_400)
        let status = CommentPolicy.initialStatus(for: "This is a total scam", accountCreatedAt: oldAccount)
        XCTAssertEqual(status, .pendingReview)
    }

    func testLinksFromNewAccountsGoToReview() {
        let newAccount = Date().addingTimeInterval(-1 * 86_400)
        let status = CommentPolicy.initialStatus(for: "Buy here https://example.com", accountCreatedAt: newAccount)
        XCTAssertEqual(status, .pendingReview)
    }

    func testLinksFromEstablishedAccountsAreVisible() {
        let oldAccount = Date().addingTimeInterval(-90 * 86_400)
        let status = CommentPolicy.initialStatus(for: "Source: https://example.com", accountCreatedAt: oldAccount)
        XCTAssertEqual(status, .visible)
    }

    func testCleanCommentIsVisible() {
        let status = CommentPolicy.initialStatus(for: "Lovely build!", accountCreatedAt: Date())
        XCTAssertEqual(status, .visible)
    }

    // MARK: Report threshold (§11.10 — default 3)

    func testReportThresholdHidesComment() {
        XCTAssertEqual(CommentPolicy.statusAfterReports(currentStatus: .visible, reportCount: 2), .visible)
        XCTAssertEqual(CommentPolicy.statusAfterReports(currentStatus: .visible, reportCount: 3), .pendingReview)
        // Already-moderated comments keep their status.
        XCTAssertEqual(CommentPolicy.statusAfterReports(currentStatus: .hidden, reportCount: 5), .hidden)
    }
}
