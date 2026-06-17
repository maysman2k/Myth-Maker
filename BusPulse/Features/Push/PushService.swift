import Foundation
import Observation
import UIKit

/// Bridges the push device token from the app delegate to the backend, and
/// triggers remote-notification registration once the user has granted
/// notification permission. Server push (alarms that fire with the app
/// closed) needs the backend to know this device's token.
@MainActor
@Observable
final class PushService {
    static let shared = PushService()

    /// Push registration always targets the live server (the one holding the
    /// APNs key), regardless of the data base URL used in DEBUG builds.
    private let serverURL = URL(string: "https://waitless.bricksinabag.com")!

    private(set) var deviceToken: String?

    private init() {}

    /// Called by the app delegate when APNs returns a token.
    func updateDeviceToken(_ token: String) {
        deviceToken = token
        Task { await registerWithServer(token) }
    }

    /// Ask the system to fetch a push token. Safe to call repeatedly; only
    /// does anything once notifications are authorised.
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func registerWithServer(_ token: String) async {
        var request = URLRequest(url: serverURL.appendingPathComponent("devices"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["token": token])
        _ = try? await URLSession.shared.data(for: request)
    }
}
