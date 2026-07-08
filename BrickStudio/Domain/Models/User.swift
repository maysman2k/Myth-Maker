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
}

/// Topics a user can favourite for personalisation (§28.3).
enum FavouriteTopic {
    static let all = [
        "Stadiums", "LEGO® news", "Compatible brands", "Mosaics", "Football builds",
        "Modulars", "Star Wars", "Architecture", "Display builds", "Retiring sets", "Deals"
    ]
}
