import Foundation

// MARK: - Brick reactions (§20.1's future reactions, made LEGO-native)

enum BrickReaction: String, Codable, CaseIterable, Identifiable {
    case niceBuild = "nice_build"
    case how = "how"
    case instructionsPlease = "instructions_please"
    case wantThis = "want_this"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .niceBuild: return "🧱"
        case .how: return "😮"
        case .instructionsPlease: return "📋"
        case .wantThis: return "💰"
        }
    }

    var label: String {
        switch self {
        case .niceBuild: return "Nice build"
        case .how: return "How?!"
        case .instructionsPlease: return "Instructions please"
        case .wantThis: return "Want this"
        }
    }
}

struct ReactionRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var postID: UUID
    var reaction: BrickReaction
    var createdAt: Date
}

// MARK: - Community build posts (lightweight "brag posts")

enum CommunityPostStatus: String, Codable {
    case visible
    case pendingReview = "pending_review"
    case hidden
    case removed
}

struct CommunityPost: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var caption: String
    /// local-image:// filenames or remote URLs, same convention as articles.
    var imageReferences: [String]
    /// Entry in a build challenge when set.
    var challengeID: UUID?
    /// Posts sharing a threadID form a WIP chain ("Day 1 → Day 5 → done").
    var threadID: UUID?
    var threadDay: Int?
    var status: CommunityPostStatus
    var reportCount: Int
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - Follows & blocking (App Store UGC requirements: report + block)

struct Follow: Identifiable, Codable, Hashable {
    var id: UUID
    var followerID: UUID
    var followedID: UUID
    var createdAt: Date
}

struct BlockRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var blockerID: UUID
    var blockedID: UUID
    var createdAt: Date
}

struct UserReport: Identifiable, Codable, Hashable {
    var id: UUID
    var reporterID: UUID
    /// Either a user or a specific post (or both) can be reported.
    var reportedUserID: UUID?
    var reportedPostID: UUID?
    var reason: ReportReason
    var details: String
    var createdAt: Date
}

// MARK: - Weekly Build Challenge

enum ChallengeStatus: String, Codable {
    case upcoming
    case open
    case voting
    case finished
}

struct BuildChallenge: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var prompt: String
    var status: ChallengeStatus
    var startsAt: Date
    var votingAt: Date
    var endsAt: Date
    var winnerPostID: UUID?
    var createdAt: Date
}

struct ChallengeVote: Identifiable, Codable, Hashable {
    var id: UUID
    var challengeID: UUID
    var postID: UUID
    var userID: UUID
    var createdAt: Date
}

// MARK: - Polls (§28.5)

struct PollOption: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
}

enum PollStatus: String, Codable {
    case open
    case closed
}

struct Poll: Identifiable, Codable, Hashable {
    var id: UUID
    var question: String
    var options: [PollOption]
    var status: PollStatus
    var createdAt: Date
}

struct PollVote: Identifiable, Codable, Hashable {
    var id: UUID
    var pollID: UUID
    var optionID: UUID
    var userID: UUID
    var createdAt: Date
}

// MARK: - My Shelf (collection show-off)

struct ShelfItem: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var imageReference: String
    var caption: String
    var createdAt: Date
}

// MARK: - Community game leaderboard

enum GameKind: String, Codable, CaseIterable, Identifiable {
    case brickStack = "brick_stack"
    case studMatch = "stud_match"
    case buildSprint = "build_sprint"
    case revealStadium = "reveal_stadium"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brickStack: return "Brick Stack"
        case .studMatch: return "Stud Match"
        case .buildSprint: return "Build Sprint"
        case .revealStadium: return "Reveal the Stadium"
        }
    }

    var symbol: String {
        switch self {
        case .brickStack: return "square.stack.3d.up"
        case .studMatch: return "circle.grid.2x2"
        case .buildSprint: return "timer"
        case .revealStadium: return "sportscourt"
        }
    }
}

struct GameScoreEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID
    var displayName: String
    var game: GameKind
    var score: Int
    /// ISO week key like "2026-W28" — leaderboards reset weekly so they
    /// stay winnable.
    var weekKey: String
    var updatedAt: Date

    static func currentWeekKey(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}
