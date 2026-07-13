import XCTest
@testable import BrickStudio

final class CommunityFeatureTests: XCTestCase {
    private var model: AppModel!
    private var jess: UserAccount!
    private var tom: UserAccount!
    private var mags: UserAccount!
    private var admin: UserAccount!

    override func setUp() {
        super.setUp()
        jess = UserAccount.new(displayName: "Jess", email: "jess@t.com", passwordHash: "x")
        jess.createdAt = Date().addingTimeInterval(-90 * 86_400)
        tom = UserAccount.new(displayName: "Tom", email: "tom@t.com", passwordHash: "x")
        tom.createdAt = Date().addingTimeInterval(-90 * 86_400)
        mags = UserAccount.new(displayName: "Mags", email: "mags@t.com", passwordHash: "x")
        mags.createdAt = Date().addingTimeInterval(-90 * 86_400)
        admin = UserAccount.new(displayName: "Pete", email: "pete@t.com", passwordHash: "x", role: .admin)
        var snapshot = AppSnapshot()
        snapshot.accounts = [jess, tom, mags, admin]
        model = AppModel(snapshot: snapshot)
    }

    // MARK: Reactions — one per user, switchable, removable

    func testReactionsAreOnePerUserAndSwitchable() throws {
        model.currentUserID = jess.id
        let post = try XCTUnwrap(model.createCommunityPost(caption: "My café build", imageReferences: []))
        model.currentUserID = tom.id
        model.react(to: post.id, with: .niceBuild)
        XCTAssertEqual(model.reactionCounts(for: post.id)[.niceBuild], 1)
        // Switching replaces, never stacks.
        model.react(to: post.id, with: .wantThis)
        XCTAssertNil(model.reactionCounts(for: post.id)[.niceBuild])
        XCTAssertEqual(model.reactionCounts(for: post.id)[.wantThis], 1)
        // Tapping the same one removes it.
        model.react(to: post.id, with: .wantThis)
        XCTAssertTrue(model.reactionCounts(for: post.id).isEmpty)
    }

    func testReactionNotifiesAuthorButNotSelf() throws {
        model.currentUserID = jess.id
        let post = try XCTUnwrap(model.createCommunityPost(caption: "Build", imageReferences: []))
        model.react(to: post.id, with: .niceBuild) // own post — no notification
        XCTAssertFalse(model.notifications.contains { $0.userID == jess.id && $0.targetID == post.id })
        model.currentUserID = tom.id
        model.react(to: post.id, with: .niceBuild)
        XCTAssertTrue(model.notifications.contains { $0.userID == jess.id && $0.targetID == post.id })
    }

    // MARK: Blocking hides everything, both content kinds

    func testBlockingHidesPostsAndComments() throws {
        model.currentUserID = tom.id
        let post = try XCTUnwrap(model.createCommunityPost(caption: "Tom's build", imageReferences: []))
        model.postComment(type: .communityPost, contentID: post.id, body: "Also Tom's comment")

        model.currentUserID = jess.id
        XCTAssertTrue(model.visibleCommunityPosts.contains { $0.id == post.id })
        model.blockUser(tom.id)
        XCTAssertFalse(model.visibleCommunityPosts.contains { $0.id == post.id })
        XCTAssertTrue(model.viewableComments(for: .communityPost, contentID: post.id).isEmpty)
        // Other viewers are unaffected.
        model.currentUserID = mags.id
        XCTAssertTrue(model.visibleCommunityPosts.contains { $0.id == post.id })
    }

    func testBlockingRemovesFollowsBothWays() {
        model.currentUserID = jess.id
        model.toggleFollow(tom.id)
        XCTAssertTrue(model.isFollowing(tom.id))
        model.blockUser(tom.id)
        XCTAssertFalse(model.isFollowing(tom.id))
    }

    // MARK: Challenge lifecycle

    func testChallengeVotingAndWinner() throws {
        model.currentUserID = admin.id
        model.createChallenge(title: "Test", prompt: "Build something", daysOpen: 3, votingDays: 2)
        let challenge = try XCTUnwrap(model.activeChallenge)

        model.currentUserID = jess.id
        let jessEntry = try XCTUnwrap(model.createCommunityPost(caption: "Jess entry", imageReferences: [], challengeID: challenge.id))
        model.currentUserID = tom.id
        let tomEntry = try XCTUnwrap(model.createCommunityPost(caption: "Tom entry", imageReferences: [], challengeID: challenge.id))

        // No voting while entries are open.
        model.voteForEntry(jessEntry.id, in: challenge.id)
        XCTAssertEqual(model.voteCount(for: jessEntry.id, in: challenge.id), 0)

        model.currentUserID = admin.id
        model.advanceChallenge(challenge.id) // open -> voting

        // Can't vote for your own entry.
        model.currentUserID = jess.id
        model.voteForEntry(jessEntry.id, in: challenge.id)
        XCTAssertEqual(model.voteCount(for: jessEntry.id, in: challenge.id), 0)

        // One vote per builder, movable.
        model.voteForEntry(tomEntry.id, in: challenge.id)
        model.currentUserID = mags.id
        model.voteForEntry(tomEntry.id, in: challenge.id)
        model.voteForEntry(jessEntry.id, in: challenge.id) // moved
        XCTAssertEqual(model.voteCount(for: tomEntry.id, in: challenge.id), 1)
        XCTAssertEqual(model.voteCount(for: jessEntry.id, in: challenge.id), 1)

        model.currentUserID = admin.id
        model.advanceChallenge(challenge.id) // voting -> finished, tie broken by earliest entry
        let finished = try XCTUnwrap(model.challenge(challenge.id))
        XCTAssertEqual(finished.status, .finished)
        XCTAssertEqual(finished.winnerPostID, jessEntry.id, "Tie breaks to the earliest entry")
        XCTAssertEqual(model.challengeWins(for: jess.id), 1)
        XCTAssertTrue(model.notifications.contains { $0.userID == jess.id && $0.title.contains("won") })
    }

    // MARK: Polls — one vote each, movable

    func testPollSingleVotePerUser() throws {
        model.currentUserID = admin.id
        model.createPoll(question: "Which stadium?", optionLabels: ["Anfield", "Villa Park"])
        let poll = try XCTUnwrap(model.openPolls.first)
        model.currentUserID = jess.id
        model.votePoll(poll.id, optionID: poll.options[0].id)
        model.votePoll(poll.id, optionID: poll.options[1].id)
        let results = model.pollResults(poll)
        XCTAssertEqual(results[0].votes, 0)
        XCTAssertEqual(results[1].votes, 1)
    }

    // MARK: Leaderboard — weekly bests only improve

    func testGameScoreKeepsWeeklyBest() {
        model.currentUserID = jess.id
        model.submitGameScore(.brickStack, score: 10)
        model.submitGameScore(.brickStack, score: 8)   // worse — ignored
        model.submitGameScore(.brickStack, score: 15)  // better — replaces
        let board = model.weeklyLeaderboard(for: .brickStack)
        XCTAssertEqual(board.count, 1)
        XCTAssertEqual(board.first?.score, 15)
    }

    func testGuestScoresAreNotRecorded() {
        model.currentUserID = nil
        model.submitGameScore(.brickStack, score: 99)
        XCTAssertTrue(model.weeklyLeaderboard(for: .brickStack).isEmpty)
    }

    // MARK: WIP threads

    func testThreadDaysIncrement() throws {
        model.currentUserID = tom.id
        let day1 = try XCTUnwrap(model.createCommunityPost(caption: "Day 1", imageReferences: [], startThread: true))
        XCTAssertEqual(day1.threadDay, 1)
        let day2 = try XCTUnwrap(model.createCommunityPost(caption: "More progress", imageReferences: [], continueThread: day1.threadID))
        XCTAssertEqual(day2.threadDay, 2)
        XCTAssertEqual(model.threadPosts(for: day1).count, 2)
    }

    // MARK: Post types — events and LEGO® Ideas

    func testEventPostCarriesDateAndLocation() throws {
        model.currentUserID = jess.id
        let when = Date().addingTimeInterval(5 * 86_400)
        let post = try XCTUnwrap(model.createCommunityPost(
            title: "Brick Show", caption: "Come along!", imageReferences: [],
            kind: .event, eventDate: when, eventLocation: "Leeds"
        ))
        XCTAssertEqual(post.kind, .event)
        XCTAssertEqual(post.title, "Brick Show")
        XCTAssertEqual(post.eventDate, when)
        XCTAssertEqual(post.eventLocation, "Leeds")
        XCTAssertNil(post.backerCount, "Event posts must not carry Ideas fields")
        XCTAssertTrue(model.upcomingEvents.contains { $0.id == post.id })
    }

    func testIdeasPostBackersEditableByCreatorOnly() throws {
        model.currentUserID = jess.id
        let post = try XCTUnwrap(model.createCommunityPost(
            title: "Pier Arcade", caption: "Back it!", imageReferences: [],
            kind: .ideas, ideasEndDate: Date().addingTimeInterval(30 * 86_400), backerCount: 100
        ))
        XCTAssertEqual(post.backerCount, 100)

        // Someone else can't touch the counter.
        model.currentUserID = tom.id
        model.updateBackerCount(post.id, to: 999)
        XCTAssertEqual(model.communityPost(post.id)?.backerCount, 100)

        // The creator can, and it never goes negative.
        model.currentUserID = jess.id
        model.updateBackerCount(post.id, to: 2500)
        XCTAssertEqual(model.communityPost(post.id)?.backerCount, 2500)
        model.updateBackerCount(post.id, to: -5)
        XCTAssertEqual(model.communityPost(post.id)?.backerCount, 0)
    }

    func testStandardFieldsStrippedFromMismatchedKinds() throws {
        model.currentUserID = jess.id
        // Ideas fields passed to a standard post are discarded.
        let post = try XCTUnwrap(model.createCommunityPost(
            title: "Just a build", caption: "Nice", imageReferences: [],
            kind: .standard, ideasEndDate: Date(), backerCount: 50
        ))
        XCTAssertNil(post.ideasEndDate)
        XCTAssertNil(post.backerCount)
    }

    func testOldPostJSONStillDecodes() throws {
        // Posts saved before titles/kinds existed must decode with defaults.
        let json = """
        {"id":"6639460f-3425-5329-8097-a58f06127860",
         "userID":"6639460f-3425-5329-8097-a58f06127861",
         "caption":"Old post","imageReferences":[],"status":"visible",
         "reportCount":0,"createdAt":700000000,"updatedAt":700000000}
        """
        let post = try JSONDecoder().decode(CommunityPost.self, from: Data(json.utf8))
        XCTAssertEqual(post.title, "")
        XCTAssertEqual(post.kind, .standard)
        XCTAssertNil(post.eventDate)
    }

    // MARK: Reports hide posts at the threshold

    func testPostReportsTriggerReview() throws {
        model.currentUserID = tom.id
        let post = try XCTUnwrap(model.createCommunityPost(caption: "Contentious", imageReferences: []))
        for reporter in [jess!, mags!, admin!] {
            model.currentUserID = reporter.id
            model.reportUser(tom.id, postID: post.id, reason: .spam, details: "")
        }
        XCTAssertEqual(model.communityPost(post.id)?.status, .pendingReview)
        XCTAssertFalse(model.visibleCommunityPosts.contains { $0.id == post.id })
    }
}
