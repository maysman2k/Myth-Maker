import Foundation

/// App-wide constants shared between the SwiftUI app and the App Intents
/// extension (which can't reach the SwiftUI environment).
enum AppConfig {
    /// The deployed BODS-backed backend.
    static let serverURL = URL(string: "https://waitless.bricksinabag.com")!
}
