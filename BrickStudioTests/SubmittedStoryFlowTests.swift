import XCTest
@testable import BrickStudio

/// The reader story-submission review loop: decline feedback, the
/// three-strikes lock, and role enforcement.
final class SubmittedStoryFlowTests: XCTestCase {
    private var model: AppModel!
    private var admin: UserAccount!
    private var author: UserAccount!
    private var submission: SubmittedStory!

    override func setUp() {
        super.setUp()
        admin = UserAccount.new(displayName: "Pete", email: "admin@test.com", passwordHash: "x", role: .admin)
        author = UserAccount.new(displayName: "Jess", email: "jess@test.com", passwordHash: "x")
        submission = SubmittedStory(
            id: UUID(),
            userID: author.id,
            title: "My stadium build",
            summary: "A summary",
            bodyMarkdown: "Body",
            category: .stadiumBuilds,
            tags: ["moc"],
            imageReferences: [],
            mediaReferences: [],
            links: [],
            isRumour: false,
            aiAssisted: false,
            status: .pendingReview,
            declineCount: 0,
            latestFeedback: nil,
            publishedArticleID: nil,
            createdAt: Date(),
            updatedAt: Date(),
            submittedAt: Date()
        )
        var snapshot = AppSnapshot()
        snapshot.accounts = [admin, author]
        snapshot.submittedStories = [submission]
        model = AppModel(snapshot: snapshot)
    }

    func testDeclineRequestsChangesAndRecordsFeedback() {
        model.currentUserID = admin.id
        model.declineSubmittedStory(submission.id, feedback: "Needs a sharper title.")
        XCTAssertEqual(model.submittedStories[0].status, .changesRequested)
        XCTAssertEqual(model.submittedStories[0].declineCount, 1)
        XCTAssertEqual(model.submittedStories[0].latestFeedback, "Needs a sharper title.")
        // The author gets told.
        XCTAssertTrue(model.notifications.contains { $0.userID == author.id })
    }

    func testThirdDeclineLocksTheSubmission() {
        model.currentUserID = admin.id
        for round in 1...3 {
            model.declineSubmittedStory(submission.id, feedback: "Round \(round) feedback")
        }
        XCTAssertEqual(model.submittedStories[0].status, .locked)
        XCTAssertEqual(model.submittedStories[0].declineCount, 3)
    }

    func testLockedSubmissionCannotBeResubmitted() {
        model.currentUserID = admin.id
        for round in 1...3 {
            model.declineSubmittedStory(submission.id, feedback: "Round \(round)")
        }
        model.currentUserID = author.id
        model.submitStory(
            existingID: submission.id,
            title: "Fourth try",
            summary: "s", bodyMarkdown: "b", category: .stadiumBuilds,
            tags: [], imageReferences: [], mediaReferences: [], links: [], isRumour: false
        )
        XCTAssertEqual(model.submittedStories[0].status, .locked, "A locked story must stay locked")
        XCTAssertNotEqual(model.submittedStories[0].title, "Fourth try")
    }

    func testEmptyFeedbackIsRejected() {
        model.currentUserID = admin.id
        model.declineSubmittedStory(submission.id, feedback: "   ")
        XCTAssertEqual(model.submittedStories[0].status, .pendingReview)
        XCTAssertEqual(model.submittedStories[0].declineCount, 0)
    }

    func testNonAdminCannotDecline() {
        model.currentUserID = author.id
        model.declineSubmittedStory(submission.id, feedback: "Sneaky self-review")
        XCTAssertEqual(model.submittedStories[0].status, .pendingReview)
        XCTAssertEqual(model.submittedStories[0].declineCount, 0)
    }
}
