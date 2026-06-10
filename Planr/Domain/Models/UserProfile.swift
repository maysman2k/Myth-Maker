import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    /// SF Symbol used as the avatar glyph — keeps profiles fun without photo uploads.
    var avatarSymbol: String
    var avatarColorIndex: Int
    var email: String?
    var notificationsEnabled: Bool
    var calendarSyncEnabled: Bool
    /// Safety setting: excluded from all shame-board features when true.
    var hiddenFromShameBoard: Bool

    init(id: String = UUID().uuidString,
         displayName: String,
         avatarSymbol: String = "face.smiling",
         avatarColorIndex: Int = 0,
         email: String? = nil,
         notificationsEnabled: Bool = true,
         calendarSyncEnabled: Bool = false,
         hiddenFromShameBoard: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
        self.avatarColorIndex = avatarColorIndex
        self.email = email
        self.notificationsEnabled = notificationsEnabled
        self.calendarSyncEnabled = calendarSyncEnabled
        self.hiddenFromShameBoard = hiddenFromShameBoard
    }

    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }
}

enum AvatarStyle {
    static let symbols = ["face.smiling", "star.fill", "bolt.fill", "flame.fill",
                          "crown.fill", "music.note", "gamecontroller.fill", "heart.fill",
                          "sun.max.fill", "moon.stars.fill", "pawprint.fill", "airplane"]
}
