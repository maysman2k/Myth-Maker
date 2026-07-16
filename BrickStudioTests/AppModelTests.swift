import XCTest
@testable import BrickStudio

final class AppModelTests: XCTestCase {
    private var model: AppModel!
    private var user: UserAccount!
    private var secondUser: UserAccount!
    private var thirdUser: UserAccount!
    private var editor: UserAccount!
    private var article: Article!
    private var draft: AIDraft!

    override func setUp() {
        super.setUp()
        user = UserAccount.new(displayName: "Jess", email: "jess@example.com", passwordHash: "")
        user.createdAt = Date().addingTimeInterval(-90 * 86_400)
        secondUser = UserAccount.new(displayName: "Tom", email: "tom@example.com", passwordHash: "x")
        thirdUser = UserAccount.new(displayName: "Mags", email: "mags@example.com", passwordHash: "x")
        editor = UserAccount.new(displayName: "Sasha", email: "sasha@example.com", passwordHash: "x", role: .editor)

        article = Article(
            id: UUID(), title: "Test article", slug: "test-article", summary: "Summary",
            bodyMarkdown: "Body", category: .newSets, tags: [], authorName: "Sasha",
            sources: [], isRumour: false, aiAssisted: false, commentsEnabled: true,
            status: .published, likeCount: 0, viewCount: 0, readTimeMinutes: 1,
            publishedAt: Date(), createdAt: Date(), updatedAt: Date()
        )
        draft = AIDraft(
            id: UUID(), title: "Draft story", summary: "Summary", bodyMarkdown: "Body",
            category: .rumours, tags: ["rumour"], sourceLinks: [], isRumour: true,
            relevanceScore: 80, riskNotes: "None", status: .needsReview, foundAt: Date()
        )

        var snapshot = AppSnapshot()
        snapshot.accounts = [user, secondUser, thirdUser, editor]
        snapshot.articles = [article]
        snapshot.aiDrafts = [draft]
        snapshot.hasCompletedOnboarding = true
        model = AppModel(snapshot: snapshot)
    }

    // MARK: Guest gating (§7.3)

    func testGuestCannotPostCommentAndIsPromptedToSignIn() {
        model.currentUserID = nil
        let posted = model.postComment(type: .article, contentID: article.id, body: "Hello")
        XCTAssertFalse(posted)
        XCTAssertTrue(model.isShowingAuth)
        XCTAssertEqual(model.commentCount(for: .article, contentID: article.id), 0)
    }

    func testSignedInUserCanPostComment() {
        model.currentUserID = user.id
        let posted = model.postComment(type: .article, contentID: article.id, body: "Great reveal!")
        XCTAssertTrue(posted)
        XCTAssertEqual(model.commentCount(for: .article, contentID: article.id), 1)
    }

    // MARK: Threading (§11.4)

    func testRepliesStopAtTwoLevels() {
        model.currentUserID = user.id
        XCTAssertTrue(model.postComment(type: .article, contentID: article.id, body: "Top level"))
        let top = model.comments[0]
        XCTAssertTrue(model.postComment(type: .article, contentID: article.id, body: "Reply", parentCommentID: top.id))
        let reply = model.comments[1]
        XCTAssertFalse(model.postComment(type: .article, contentID: article.id, body: "Too deep", parentCommentID: reply.id))
        XCTAssertEqual(model.comments.count, 2)
    }

    // MARK: Likes (§20.2 — no duplicates)

    func testToggleLikeIsIdempotentPerUser() {
        model.currentUserID = user.id
        model.toggleLike(.article, article.id)
        XCTAssertEqual(model.articles[0].likeCount, 1)
        XCTAssertTrue(model.isLiked(.article, article.id))
        model.toggleLike(.article, article.id)
        XCTAssertEqual(model.articles[0].likeCount, 0)
        XCTAssertFalse(model.isLiked(.article, article.id))
        XCTAssertEqual(model.likes.count, 0)
    }

    // MARK: Reports hide comments at the threshold (§11.10)

    func testThreeReportsSendCommentToReview() {
        model.currentUserID = user.id
        model.postComment(type: .article, contentID: article.id, body: "Contentious take")
        let commentID = model.comments[0].id

        for reporter in [secondUser!, thirdUser!, editor!] {
            model.currentUserID = reporter.id
            model.reportComment(commentID, reason: .abuse, details: "")
        }
        XCTAssertEqual(model.comments[0].reportCount, 3)
        XCTAssertEqual(model.comments[0].status, .pendingReview)
    }

    func testDuplicateReportsFromSameUserAreIgnored() {
        model.currentUserID = user.id
        model.postComment(type: .article, contentID: article.id, body: "Fine comment")
        let commentID = model.comments[0].id
        model.currentUserID = secondUser.id
        model.reportComment(commentID, reason: .spam, details: "")
        model.reportComment(commentID, reason: .spam, details: "")
        XCTAssertEqual(model.comments[0].reportCount, 1)
    }

    // MARK: AI drafts never publish without approval (§10.1)

    func testDraftIsNotPublicBeforeApproval() {
        XCTAssertEqual(model.publishedArticles.count, 1)
        XCTAssertFalse(model.publishedArticles.contains { $0.title == draft.title })
    }

    func testEditorApprovalPublishesDraftAsAIAssistedArticle() {
        model.currentUserID = editor.id
        model.approveAIDraft(draft.id)
        XCTAssertEqual(model.aiDrafts[0].status, .approved)
        let published = model.publishedArticles.first { $0.title == draft.title }
        XCTAssertNotNil(published)
        XCTAssertTrue(published?.aiAssisted == true)
        XCTAssertTrue(published?.isRumour == true)
    }

    func testNormalUserCannotApproveDrafts() {
        model.currentUserID = user.id
        model.approveAIDraft(draft.id)
        XCTAssertEqual(model.aiDrafts[0].status, .needsReview)
        XCTAssertEqual(model.publishedArticles.count, 1)
    }

    // MARK: Auth
    // Credential flows live in Supabase Auth now; what's testable locally is
    // the validation logic that gates them.

    func testHandleValidation() {
        XCTAssertTrue(AppModel.isValidHandle("brick_builder99"))
        XCTAssertTrue(AppModel.isValidHandle("abc"))
        XCTAssertFalse(AppModel.isValidHandle("ab"), "Too short")
        XCTAssertFalse(AppModel.isValidHandle("9starts_with_digit"))
        XCTAssertFalse(AppModel.isValidHandle("Has_Capitals"))
        XCTAssertFalse(AppModel.isValidHandle("way_too_long_for_a_handle_here"))
        XCTAssertFalse(AppModel.isValidHandle("admin"), "Reserved")
        XCTAssertFalse(AppModel.isValidHandle("with space"))
    }

    func testSignOutClearsCurrentUser() {
        model.currentUserID = user.id
        model.signOut()
        XCTAssertNil(model.currentUserID)
        XCTAssertFalse(model.isSignedIn)
    }

    // MARK: Bookmarks stay private per user

    func testBookmarksAreScopedToUser() {
        model.currentUserID = user.id
        model.toggleBookmark(.article, article.id)
        XCTAssertTrue(model.isBookmarked(.article, article.id))
        model.currentUserID = secondUser.id
        XCTAssertFalse(model.isBookmarked(.article, article.id))
        XCTAssertTrue(model.mySavedItems().isEmpty)
    }
}
