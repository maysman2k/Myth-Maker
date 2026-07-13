import Foundation

/// Community layer: build posts, brick reactions, follows, blocking,
/// the Weekly Build Challenge, polls, My Shelf and game leaderboards.
extension AppModel {
    // MARK: - Blocking (App Store UGC requirement alongside reporting)

    var myBlockedUserIDs: Set<UUID> {
        guard let currentUserID else { return [] }
        return Set(blocks.filter { $0.blockerID == currentUserID }.map(\.blockedID))
    }

    func isBlocked(_ userID: UUID) -> Bool {
        myBlockedUserIDs.contains(userID)
    }

    func blockUser(_ userID: UUID) {
        guard requireAccount(), let currentUserID, userID != currentUserID else { return }
        guard !isBlocked(userID) else { return }
        blocks.append(BlockRecord(id: UUID(), blockerID: currentUserID, blockedID: userID, createdAt: Date()))
        // Blocking is mutual silence: also stop following in both directions.
        follows.removeAll {
            ($0.followerID == currentUserID && $0.followedID == userID) ||
            ($0.followerID == userID && $0.followedID == currentUserID)
        }
        showToast("Blocked \(displayName(for: userID)). You won't see their posts or comments.", symbol: "hand.raised.fill")
        persist()
    }

    func unblockUser(_ userID: UUID) {
        guard let currentUserID else { return }
        blocks.removeAll { $0.blockerID == currentUserID && $0.blockedID == userID }
        showToast("Unblocked \(displayName(for: userID))")
        persist()
    }

    func reportUser(_ userID: UUID, postID: UUID?, reason: ReportReason, details: String) {
        guard requireAccount(), let currentUserID else { return }
        userReports.append(UserReport(
            id: UUID(),
            reporterID: currentUserID,
            reportedUserID: userID,
            reportedPostID: postID,
            reason: reason,
            details: details,
            createdAt: Date()
        ))
        if let postID, let index = communityPosts.firstIndex(where: { $0.id == postID }) {
            communityPosts[index].reportCount += 1
            if communityPosts[index].reportCount >= CommentPolicy.reportThreshold,
               communityPosts[index].status == .visible {
                communityPosts[index].status = .pendingReview
            }
        }
        showToast("Thanks — our moderators will take a look.", symbol: "flag.fill")
        persist()
    }

    // MARK: - Follows

    func isFollowing(_ userID: UUID) -> Bool {
        guard let currentUserID else { return false }
        return follows.contains { $0.followerID == currentUserID && $0.followedID == userID }
    }

    func toggleFollow(_ userID: UUID) {
        guard requireAccount(), let user = currentUser, userID != user.id else { return }
        if let index = follows.firstIndex(where: { $0.followerID == user.id && $0.followedID == userID }) {
            follows.remove(at: index)
        } else {
            follows.append(Follow(id: UUID(), followerID: user.id, followedID: userID, createdAt: Date()))
            notify(
                userID: userID,
                kind: .general,
                title: "\(user.displayName) followed you",
                body: "They'll see your builds first in their feed."
            )
            showToast("Following \(displayName(for: userID))", symbol: "person.badge.plus")
        }
        persist()
    }

    func followerCount(for userID: UUID) -> Int {
        follows.filter { $0.followedID == userID }.count
    }

    // MARK: - Community posts

    /// Everything the current viewer should see: visible posts (plus their
    /// own pending ones), minus anyone they've blocked.
    var visibleCommunityPosts: [CommunityPost] {
        let blocked = myBlockedUserIDs
        return communityPosts
            .filter { post in
                !blocked.contains(post.userID) &&
                (post.status == .visible || (post.status == .pendingReview && post.userID == currentUserID))
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var followedCommunityPosts: [CommunityPost] {
        guard let currentUserID else { return [] }
        let followed = Set(follows.filter { $0.followerID == currentUserID }.map(\.followedID))
        return visibleCommunityPosts.filter { followed.contains($0.userID) }
    }

    func communityPost(_ id: UUID) -> CommunityPost? {
        communityPosts.first { $0.id == id }
    }

    /// Other posts in the same WIP thread, oldest first.
    func threadPosts(for post: CommunityPost) -> [CommunityPost] {
        guard let threadID = post.threadID else { return [post] }
        return visibleCommunityPosts
            .filter { $0.threadID == threadID }
            .sorted { ($0.threadDay ?? 0, $0.createdAt) < ($1.threadDay ?? 0, $1.createdAt) }
    }

    /// The signed-in user's WIP threads they could continue (latest post per thread).
    var myOpenThreads: [CommunityPost] {
        guard let currentUserID else { return [] }
        let mine = communityPosts.filter { $0.userID == currentUserID && $0.threadID != nil && $0.status != .removed }
        var latestByThread: [UUID: CommunityPost] = [:]
        for post in mine {
            guard let threadID = post.threadID else { continue }
            if let existing = latestByThread[threadID] {
                if (post.threadDay ?? 0) > (existing.threadDay ?? 0) { latestByThread[threadID] = post }
            } else {
                latestByThread[threadID] = post
            }
        }
        return latestByThread.values.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func createCommunityPost(caption: String, imageReferences: [String], challengeID: UUID? = nil, continueThread existingThreadID: UUID? = nil, startThread: Bool = false) -> CommunityPost? {
        guard requireAccount(), let user = currentUser else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !imageReferences.isEmpty else { return nil }

        var threadID: UUID?
        var threadDay: Int?
        if let existingThreadID {
            threadID = existingThreadID
            let previousDays = communityPosts
                .filter { $0.threadID == existingThreadID }
                .compactMap(\.threadDay)
            threadDay = (previousDays.max() ?? 0) + 1
        } else if startThread {
            threadID = UUID()
            threadDay = 1
        }

        // Same pre-check as comments: flagged wording goes to the queue.
        let flagged = CommentPolicy.initialStatus(for: trimmed, accountCreatedAt: user.createdAt) == .pendingReview
        let post = CommunityPost(
            id: UUID(),
            userID: user.id,
            caption: trimmed,
            imageReferences: imageReferences,
            challengeID: challengeID,
            threadID: threadID,
            threadDay: threadDay,
            status: flagged ? .pendingReview : .visible,
            reportCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        communityPosts.append(post)
        showToast(flagged ? "Post sent for review" : (challengeID != nil ? "You're in the challenge!" : "Posted"), symbol: challengeID != nil ? "trophy.fill" : "checkmark.circle.fill")
        persist()
        syncCommunityPost(post)
        return post
    }

    func deleteCommunityPost(_ postID: UUID) {
        guard let index = communityPosts.firstIndex(where: { $0.id == postID }) else { return }
        let post = communityPosts[index]
        guard post.userID == currentUserID || currentUser?.role.canModerate == true else { return }
        communityPosts[index].status = .removed
        communityPosts[index].updatedAt = Date()
        showToast("Post removed", symbol: "trash")
        persist()
        syncCommunityPost(communityPosts[index])
    }

    func setCommunityPostStatus(_ postID: UUID, status: CommunityPostStatus) {
        guard currentUser?.role.canModerate == true,
              let index = communityPosts.firstIndex(where: { $0.id == postID }) else { return }
        communityPosts[index].status = status
        communityPosts[index].updatedAt = Date()
        if status == .visible {
            userReports.removeAll { $0.reportedPostID == postID }
            communityPosts[index].reportCount = 0
        }
        showToast("Post updated")
        persist()
        syncCommunityPost(communityPosts[index])
    }

    var postsAwaitingModeration: [CommunityPost] {
        communityPosts
            .filter { $0.status == .pendingReview || $0.status == .hidden }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Brick reactions

    func myReaction(to postID: UUID) -> BrickReaction? {
        guard let currentUserID else { return nil }
        return reactions.first { $0.postID == postID && $0.userID == currentUserID }?.reaction
    }

    func reactionCounts(for postID: UUID) -> [BrickReaction: Int] {
        var counts: [BrickReaction: Int] = [:]
        for record in reactions where record.postID == postID {
            counts[record.reaction, default: 0] += 1
        }
        return counts
    }

    /// One reaction per user per post: tapping the same one removes it,
    /// tapping a different one switches.
    func react(to postID: UUID, with reaction: BrickReaction) {
        guard requireAccount(), let user = currentUser else { return }
        if let index = reactions.firstIndex(where: { $0.postID == postID && $0.userID == user.id }) {
            let wasSame = reactions[index].reaction == reaction
            reactions.remove(at: index)
            if wasSame {
                persist()
                return
            }
        }
        reactions.append(ReactionRecord(id: UUID(), userID: user.id, postID: postID, reaction: reaction, createdAt: Date()))
        if let post = communityPost(postID), post.userID != user.id {
            notify(
                userID: post.userID,
                kind: .commentLike,
                title: "\(reaction.emoji) \(user.displayName): \(reaction.label)",
                body: String(post.caption.prefix(80)),
                targetType: .communityPost,
                targetID: postID
            )
        }
        persist()
    }

    // MARK: - Weekly Build Challenge

    var activeChallenge: BuildChallenge? {
        challenges.first { $0.status == .open }
    }

    var votingChallenge: BuildChallenge? {
        challenges.first { $0.status == .voting }
    }

    func challenge(_ id: UUID) -> BuildChallenge? {
        challenges.first { $0.id == id }
    }

    func entries(for challengeID: UUID) -> [CommunityPost] {
        visibleCommunityPosts.filter { $0.challengeID == challengeID }
    }

    func voteCount(for postID: UUID, in challengeID: UUID) -> Int {
        challengeVotes.filter { $0.challengeID == challengeID && $0.postID == postID }.count
    }

    func myChallengeVote(in challengeID: UUID) -> UUID? {
        guard let currentUserID else { return nil }
        return challengeVotes.first { $0.challengeID == challengeID && $0.userID == currentUserID }?.postID
    }

    /// One vote per builder per challenge; you can move it, and you can't
    /// vote for your own entry.
    func voteForEntry(_ postID: UUID, in challengeID: UUID) {
        guard requireAccount(), let currentUserID else { return }
        guard let target = communityPost(postID), target.userID != currentUserID else {
            showToast("Nice try — you can't vote for your own build.", symbol: "hand.raised")
            return
        }
        guard challenge(challengeID)?.status == .voting else {
            showToast("Voting isn't open on this challenge yet.", symbol: "clock")
            return
        }
        challengeVotes.removeAll { $0.challengeID == challengeID && $0.userID == currentUserID }
        challengeVotes.append(ChallengeVote(id: UUID(), challengeID: challengeID, postID: postID, userID: currentUserID, createdAt: Date()))
        showToast("Vote counted", symbol: "checkmark.seal.fill")
        persist()
    }

    /// Challenges a builder has won — their crown badge.
    func challengeWins(for userID: UUID) -> Int {
        challenges.filter { challengeEntry in
            guard let winnerID = challengeEntry.winnerPostID,
                  let winner = communityPosts.first(where: { $0.id == winnerID }) else { return false }
            return winner.userID == userID
        }.count
    }

    // MARK: Challenge admin

    func createChallenge(title: String, prompt: String, daysOpen: Int, votingDays: Int) {
        guard currentUser?.role.canEditContent == true else { return }
        let now = Date()
        let challenge = BuildChallenge(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .open,
            startsAt: now,
            votingAt: now.addingTimeInterval(Double(max(1, daysOpen)) * 86_400),
            endsAt: now.addingTimeInterval(Double(max(1, daysOpen) + max(1, votingDays)) * 86_400),
            winnerPostID: nil,
            createdAt: now
        )
        challenges.append(challenge)
        showToast("Challenge is live", symbol: "trophy.fill")
        persist()
    }

    func advanceChallenge(_ challengeID: UUID) {
        guard currentUser?.role.canEditContent == true,
              let index = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        switch challenges[index].status {
        case .upcoming:
            challenges[index].status = .open
        case .open:
            challenges[index].status = .voting
            showToast("Voting is open", symbol: "checkmark.seal")
        case .voting:
            finishChallenge(at: index)
        case .finished:
            return
        }
        persist()
    }

    private func finishChallenge(at index: Int) {
        let challengeID = challenges[index].id
        let tally = entries(for: challengeID)
            .map { ($0, voteCount(for: $0.id, in: challengeID)) }
            .sorted { lhs, rhs in
                lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.createdAt < rhs.0.createdAt
            }
        challenges[index].status = .finished
        guard let winner = tally.first, winner.1 > 0 || tally.count == 1 else {
            showToast("Challenge closed — no votes were cast.", symbol: "trophy")
            return
        }
        challenges[index].winnerPostID = winner.0.id
        notify(
            userID: winner.0.userID,
            kind: .general,
            title: "👑 You won \(challenges[index].title)!",
            body: "Your build takes the crown this week — it's featured on Today.",
            targetType: .communityPost,
            targetID: winner.0.id
        )
        showToast("Winner crowned: \(displayName(for: winner.0.userID))", symbol: "crown.fill")
    }

    // MARK: - Polls

    var openPolls: [Poll] {
        polls.filter { $0.status == .open }.sorted { $0.createdAt > $1.createdAt }
    }

    func myPollVote(_ pollID: UUID) -> UUID? {
        guard let currentUserID else { return nil }
        return pollVotes.first { $0.pollID == pollID && $0.userID == currentUserID }?.optionID
    }

    func pollResults(_ poll: Poll) -> [(option: PollOption, votes: Int, share: Double)] {
        let votes = pollVotes.filter { $0.pollID == poll.id }
        let total = max(1, votes.count)
        return poll.options.map { option in
            let count = votes.filter { $0.optionID == option.id }.count
            return (option, count, Double(count) / Double(total))
        }
    }

    func votePoll(_ pollID: UUID, optionID: UUID) {
        guard requireAccount(), let currentUserID else { return }
        guard polls.first(where: { $0.id == pollID })?.status == .open else { return }
        pollVotes.removeAll { $0.pollID == pollID && $0.userID == currentUserID }
        pollVotes.append(PollVote(id: UUID(), pollID: pollID, optionID: optionID, userID: currentUserID, createdAt: Date()))
        persist()
    }

    func createPoll(question: String, optionLabels: [String]) {
        guard currentUser?.role.canEditContent == true else { return }
        let cleaned = optionLabels.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard cleaned.count >= 2 else { return }
        polls.append(Poll(
            id: UUID(),
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            options: cleaned.map { PollOption(id: UUID(), label: $0) },
            status: .open,
            createdAt: Date()
        ))
        showToast("Poll is live", symbol: "chart.bar.fill")
        persist()
    }

    func closePoll(_ pollID: UUID) {
        guard currentUser?.role.canEditContent == true,
              let index = polls.firstIndex(where: { $0.id == pollID }) else { return }
        polls[index].status = .closed
        showToast("Poll closed")
        persist()
    }

    // MARK: - My Shelf

    func shelf(for userID: UUID) -> [ShelfItem] {
        shelfItems.filter { $0.userID == userID }.sorted { $0.createdAt > $1.createdAt }
    }

    func addShelfItem(imageReference: String, caption: String) {
        guard requireAccount(), let currentUserID else { return }
        shelfItems.append(ShelfItem(
            id: UUID(),
            userID: currentUserID,
            imageReference: imageReference,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        ))
        showToast("Added to your shelf", symbol: "square.grid.2x2.fill")
        persist()
    }

    func removeShelfItem(_ itemID: UUID) {
        guard let index = shelfItems.firstIndex(where: { $0.id == itemID }),
              shelfItems[index].userID == currentUserID else { return }
        shelfItems.remove(at: index)
        persist()
    }

    // MARK: - Game leaderboard

    /// Records a new personal best for this week and pushes it to the
    /// community board when the backend is configured.
    func submitGameScore(_ game: GameKind, score: Int) {
        guard score > 0, let user = currentUser else { return }
        let weekKey = GameScoreEntry.currentWeekKey()
        if let index = gameScores.firstIndex(where: { $0.userID == user.id && $0.game == game && $0.weekKey == weekKey }) {
            guard score > gameScores[index].score else { return }
            gameScores[index].score = score
            gameScores[index].displayName = user.displayName
            gameScores[index].updatedAt = Date()
        } else {
            gameScores.append(GameScoreEntry(
                id: UUID(),
                userID: user.id,
                displayName: user.displayName,
                game: game,
                score: score,
                weekKey: weekKey,
                updatedAt: Date()
            ))
        }
        persist()
        if SupabaseService.isConfigured,
           let entry = gameScores.first(where: { $0.userID == user.id && $0.game == game && $0.weekKey == weekKey }) {
            Task {
                try? await SupabaseService.upsertGameScore(entry)
            }
        }
    }

    func weeklyLeaderboard(for game: GameKind, limit: Int = 10) -> [GameScoreEntry] {
        let weekKey = GameScoreEntry.currentWeekKey()
        return gameScores
            .filter { $0.game == game && $0.weekKey == weekKey }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.updatedAt < $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// This week's single stand-out score across all games, for Today.
    var weeklyChampion: GameScoreEntry? {
        let weekKey = GameScoreEntry.currentWeekKey()
        return gameScores
            .filter { $0.weekKey == weekKey }
            .max { $0.score < $1.score }
    }

    // MARK: - Backend sync

    private func syncCommunityPost(_ post: CommunityPost) {
        guard SupabaseService.isConfigured else { return }
        Task {
            do {
                var remote = post
                remote.imageReferences = try await SupabaseService.uploadStoryMediaReferences(post.imageReferences)
                try await SupabaseService.upsertCommunityPost(remote)
            } catch {
                await MainActor.run {
                    showToast(error.localizedDescription, symbol: "exclamationmark.triangle")
                }
            }
        }
    }

    /// Pulls community content from the backend, merging by ID. Local
    /// moderation state wins for posts the viewer authored.
    @MainActor
    func refreshCommunityContent() async {
        guard SupabaseService.isConfigured else { return }
        do {
            let remotePosts = try await SupabaseService.fetchCommunityPosts()
            let localIDs = Set(communityPosts.map(\.id))
            communityPosts.append(contentsOf: remotePosts.filter { !localIDs.contains($0.id) })
            for remote in remotePosts {
                if let index = communityPosts.firstIndex(where: { $0.id == remote.id && $0.userID != currentUserID }) {
                    communityPosts[index] = remote
                }
            }
            let remoteScores = try await SupabaseService.fetchGameScores(weekKey: GameScoreEntry.currentWeekKey())
            let localScoreIDs = Set(gameScores.map(\.id))
            gameScores.append(contentsOf: remoteScores.filter { !localScoreIDs.contains($0.id) })
            persist()
        } catch {
            // Quiet: community sync is additive; the local feed still works.
        }
    }
}
