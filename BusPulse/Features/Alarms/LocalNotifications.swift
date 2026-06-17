import Foundation
import UserNotifications

/// Thin wrapper over local notifications for bus arrival alarms. Local
/// notifications need only the user's permission — no push entitlement or
/// developer-account setup — so this works today. The server-push upgrade
/// (fires when the app is closed) plugs in later behind the same idea.
///
/// Also acts as the notification-centre delegate so alarms are shown even
/// when the app is in the foreground (v1's main use: app open at the stop).
final class LocalNotifications: NSObject, UNUserNotificationCenterDelegate {

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    /// Fires immediately — the alarm logic decides *when* the bus is close
    /// enough, so the notification itself has no trigger delay.
    func fireBusNearby(lineName: String, destination: String?, distanceLabel: String) {
        let content = UNMutableNotificationContent()
        content.title = "The \(lineName) is close"
        if let destination {
            content.body = "Your \(lineName) to \(destination) is about \(distanceLabel) away. Time to head out."
        } else {
            content.body = "Your \(lineName) is about \(distanceLabel) away. Time to head out."
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: "bus-alarm-\(UUID().uuidString)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fires when a tracked bus reaches the chosen stop.
    func fireBusAtStop(lineName: String, stopName: String) {
        let content = UNMutableNotificationContent()
        content.title = "The \(lineName) has arrived"
        content.body = "The \(lineName) has reached \(stopName)."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "bus-stop-alarm-\(UUID().uuidString)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Show the alarm even if the app is open when it fires.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
