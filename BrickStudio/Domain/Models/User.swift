import Foundation

enum UserRole: String, Codable, CaseIterable {
    case user
    case moderator
    case editor
    case admin

    var displayName: String {
        switch self {
        case .user: return "Member"
        case .moderator: return "Moderator"
        case .editor: return "Editor"
        case .admin: return "Admin"
        }
    }

    var canModerate: Bool { self != .user }
    var canEditContent: Bool { self == .editor || self == .admin }
    var isAdmin: Bool { self == .admin }
}

struct NotificationPreferences: Codable, Hashable {
    var newsAlerts = true
    var commentReplies = true
    var brickBarUpdates = true
    var shopUpdates = false
    var studioLessons = true
    var reviewAlerts = true
}

struct UserAccount: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var email: String
    var passwordHash: String
    var role: UserRole
    var avatarImageReference: String?
    var bio: String
    var favouriteTopics: [String]
    var favouriteClub: String
    var publicProfileEnabled: Bool
    var notificationPreferences: NotificationPreferences
    var completedLessonIDs: Set<UUID>
    var createdAt: Date
    var lastActiveAt: Date

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    static func new(displayName: String, email: String, passwordHash: String, role: UserRole = .user) -> UserAccount {
        UserAccount(
            id: UUID(),
            displayName: displayName,
            email: email.lowercased(),
            passwordHash: passwordHash,
            role: role,
            avatarImageReference: nil,
            bio: "",
            favouriteTopics: [],
            favouriteClub: "",
            publicProfileEnabled: true,
            notificationPreferences: NotificationPreferences(),
            completedLessonIDs: [],
            createdAt: Date(),
            lastActiveAt: Date()
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, email, passwordHash, role, avatarImageReference, bio, favouriteTopics, favouriteClub, publicProfileEnabled, notificationPreferences, completedLessonIDs, createdAt, lastActiveAt
    }

    init(
        id: UUID,
        displayName: String,
        email: String,
        passwordHash: String,
        role: UserRole,
        avatarImageReference: String? = nil,
        bio: String,
        favouriteTopics: [String],
        favouriteClub: String,
        publicProfileEnabled: Bool,
        notificationPreferences: NotificationPreferences,
        completedLessonIDs: Set<UUID>,
        createdAt: Date,
        lastActiveAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.passwordHash = passwordHash
        self.role = role
        self.avatarImageReference = avatarImageReference
        self.bio = bio
        self.favouriteTopics = favouriteTopics
        self.favouriteClub = favouriteClub
        self.publicProfileEnabled = publicProfileEnabled
        self.notificationPreferences = notificationPreferences
        self.completedLessonIDs = completedLessonIDs
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        passwordHash = try container.decode(String.self, forKey: .passwordHash)
        role = try container.decode(UserRole.self, forKey: .role)
        avatarImageReference = try container.decodeIfPresent(String.self, forKey: .avatarImageReference)
        bio = try container.decode(String.self, forKey: .bio)
        favouriteTopics = try container.decode([String].self, forKey: .favouriteTopics)
        favouriteClub = try container.decode(String.self, forKey: .favouriteClub)
        publicProfileEnabled = try container.decode(Bool.self, forKey: .publicProfileEnabled)
        notificationPreferences = try container.decode(NotificationPreferences.self, forKey: .notificationPreferences)
        completedLessonIDs = try container.decode(Set<UUID>.self, forKey: .completedLessonIDs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastActiveAt = try container.decode(Date.self, forKey: .lastActiveAt)
    }
}

/// Topics a user can favourite for personalisation (§28.3).
enum FavouriteTopic {
    static let all = [
        "Stadiums", "LEGO® news", "Compatible brands", "Mosaics", "Football builds",
        "Modulars", "Star Wars", "Architecture", "Display builds", "Retiring sets", "Deals"
    ]
}
