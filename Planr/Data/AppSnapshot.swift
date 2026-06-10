import Foundation

/// Everything the app persists, in one Codable value. Maps one-to-one onto
/// the Firestore collection design in the build brief, so swapping the
/// local store for a cloud repository is a data-layer change only.
struct AppSnapshot: Codable {
    var schemaVersion: Int = 1
    var currentUserID: String?
    var people: [UserProfile] = []
    var events: [Event] = []
    var votes: [Vote] = []
    var tasks: [EventTask] = []
    var payments: [Payment] = []
    var messages: [ChatMessage] = []
    var photos: [EventPhoto] = []
    var bingoGames: [BingoGame] = []
}
