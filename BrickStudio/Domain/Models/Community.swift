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

/// What a feed post is: a standard build post, an event, or a LEGO® Ideas
/// campaign the community can track.
enum CommunityPostKind: String, Codable, CaseIterable, Identifiable {
    case standard
    case event
    case ideas = "lego_ideas"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Post"
        case .event: return "Event"
        case .ideas: return "LEGO® Ideas"
        }
    }

    var pickerTitle: String {
        switch self {
        case .standard: return "Standard post"
        case .event: return "Event"
        case .ideas: return "LEGO® Ideas post"
        }
    }

    var pickerDetail: String {
        switch self {
        case .standard: return "A build, a thought, a photo — share it with the community."
        case .event: return "A show, meet-up or launch with a date people can plan around."
        case .ideas: return "Track a LEGO® Ideas campaign: end date and live backer count."
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "hammer"
        case .event: return "calendar"
        case .ideas: return "lightbulb"
        }
    }
}

struct CommunityPost: Identifiable, Hashable {
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
    // Post types (kept optional/defaulted so existing data still decodes).
    var title: String = ""
    var kind: CommunityPostKind = .standard
    /// Event posts: when it happens (and optionally where).
    var eventDate: Date? = nil
    var eventLocation: String? = nil
    /// LEGO® Ideas posts: campaign end date and the creator-maintained
    /// backer counter.
    var ideasEndDate: Date? = nil
    var backerCount: Int? = nil
}

extension CommunityPost: Codable {
    enum CodingKeys: String, CodingKey {
        case id, userID, caption, imageReferences, challengeID, threadID,
             threadDay, status, reportCount, createdAt, updatedAt,
             title, kind, eventDate, eventLocation, ideasEndDate, backerCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        caption = try container.decode(String.self, forKey: .caption)
        imageReferences = try container.decode([String].self, forKey: .imageReferences)
        challengeID = try container.decodeIfPresent(UUID.self, forKey: .challengeID)
        threadID = try container.decodeIfPresent(UUID.self, forKey: .threadID)
        threadDay = try container.decodeIfPresent(Int.self, forKey: .threadDay)
        status = try container.decode(CommunityPostStatus.self, forKey: .status)
        reportCount = try container.decode(Int.self, forKey: .reportCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        kind = try container.decodeIfPresent(CommunityPostKind.self, forKey: .kind) ?? .standard
        eventDate = try container.decodeIfPresent(Date.self, forKey: .eventDate)
        eventLocation = try container.decodeIfPresent(String.self, forKey: .eventLocation)
        ideasEndDate = try container.decodeIfPresent(Date.self, forKey: .ideasEndDate)
        backerCount = try container.decodeIfPresent(Int.self, forKey: .backerCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(caption, forKey: .caption)
        try container.encode(imageReferences, forKey: .imageReferences)
        try container.encodeIfPresent(challengeID, forKey: .challengeID)
        try container.encodeIfPresent(threadID, forKey: .threadID)
        try container.encodeIfPresent(threadDay, forKey: .threadDay)
        try container.encode(status, forKey: .status)
        try container.encode(reportCount, forKey: .reportCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(eventDate, forKey: .eventDate)
        try container.encodeIfPresent(eventLocation, forKey: .eventLocation)
        try container.encodeIfPresent(ideasEndDate, forKey: .ideasEndDate)
        try container.encodeIfPresent(backerCount, forKey: .backerCount)
    }
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
