import Foundation

/// Rules for the shared comments system (§11).
enum CommentPolicy {
    /// Users can edit their own comment for 15 minutes after posting.
    static let editWindow: TimeInterval = 15 * 60
    /// Threads support replies up to 2 levels deep (comment → reply).
    static let maxDepth = 2
    /// Comments at or past this many reports are hidden pending review.
    static let reportThreshold = 3
    /// New accounts posting links go to the moderation queue.
    static let newAccountAge: TimeInterval = 7 * 24 * 60 * 60

    /// A deliberately simple pre-check list. Real moderation happens in the
    /// admin queue — this only decides what needs a human look first.
    static let flaggedTerms = ["idiot", "stupid", "hate you", "kill", "scam"]

    static func canEdit(_ comment: Comment, by userID: UUID?, at date: Date = Date()) -> Bool {
        guard comment.userID == userID, comment.status == .visible else { return false }
        return date.timeIntervalSince(comment.createdAt) <= editWindow
    }

    static func canDelete(_ comment: Comment, by user: UserAccount?) -> Bool {
        guard let user else { return false }
        return comment.userID == user.id || user.role.canModerate
    }

    static func depth(of comment: Comment, in comments: [Comment]) -> Int {
        var depth = 1
        var current = comment
        while let parentID = current.parentCommentID,
              let parent = comments.first(where: { $0.id == parentID }) {
            depth += 1
            current = parent
        }
        return depth
    }

    static func canReply(to comment: Comment, in comments: [Comment]) -> Bool {
        depth(of: comment, in: comments) < maxDepth
    }

    /// Initial status for a newly posted comment (§11.8).
    static func initialStatus(for body: String, accountCreatedAt: Date, at date: Date = Date()) -> CommentStatus {
        let lowered = body.lowercased()
        if flaggedTerms.contains(where: { lowered.contains($0) }) {
            return .pendingReview
        }
        let containsLink = lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.")
        let isNewAccount = date.timeIntervalSince(accountCreatedAt) < newAccountAge
        if containsLink && isNewAccount {
            return .pendingReview
        }
        return .visible
    }

    static func statusAfterReports(currentStatus: CommentStatus, reportCount: Int) -> CommentStatus {
        guard currentStatus == .visible else { return currentStatus }
        return reportCount >= reportThreshold ? .pendingReview : .visible
    }
}
