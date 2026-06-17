import UIKit
import UserNotifications

/// Handles Apple Push Notification registration. On launch it asks for
/// notification permission and, if granted, registers for remote pushes;
/// the resulting device token is handed to the server via PushService so the
/// backend can deliver alarm alerts even when the app is closed.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                     [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushService.shared.updateDeviceToken(token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push registration can fail in the simulator or without the capability;
        // local alarms still work as a fallback.
        print("Remote notification registration failed: \(error.localizedDescription)")
    }
}
