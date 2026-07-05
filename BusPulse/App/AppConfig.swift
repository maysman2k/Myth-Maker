import Foundation

/// App-wide constants shared between the SwiftUI app and the App Intents
/// extension (which can't reach the SwiftUI environment).
enum AppConfig {
    /// The deployed BODS-backed backend.
    static let serverURL = URL(string: "https://waitless.bricksinabag.com")!

    /// Advertising. Deliberately minimal: one small adaptive banner on the
    /// two highest-dwell screens (route detail, journey results) — never on
    /// the live map, departure boards or alarms. Ads are non-personalised,
    /// so there is no App Tracking Transparency popup.
    enum Ads {
        static let enabled = true
        /// Google's public TEST banner unit. Replace with the real AdMob
        /// unit id (and the app id in Info.plist) before App Store release.
        static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    }
}
