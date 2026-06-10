import Foundation
import UserNotifications

/// Local notifications for the moments that matter: vote deadlines and
/// event kick-off. Push (FCM/APNs) plugs in behind the same call sites
/// once the sync backend lands.
final class NotificationScheduler {

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// "Event starting soon" — fires the morning before kick-off.
    func scheduleEventReminder(for event: Event) {
        guard let start = event.startDate,
              let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: start),
              fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Kicks off tomorrow. \(event.moodEmoji) Check the plan."
        content.sound = .default
        schedule(content, id: "event-reminder-\(event.id)", at: fireDate)
    }

    /// Nudge three hours before a vote deadline.
    func scheduleVoteDeadline(for vote: Vote, eventTitle: String) {
        guard let deadline = vote.deadline,
              let fireDate = Calendar.current.date(byAdding: .hour, value: -3, to: deadline),
              fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = eventTitle
        content.body = "\"\(vote.title)\" closes soon. Get your vote in."
        content.sound = .default
        schedule(content, id: "vote-deadline-\(vote.id)", at: fireDate)
    }

    func cancelReminders(withIDs ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(_ content: UNMutableNotificationContent, id: String, at date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                         from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
