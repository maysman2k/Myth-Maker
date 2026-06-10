import Foundation

enum DateUtilities {
    /// "Sat 18 Jul" — the format used on vote options and itinerary rows.
    static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "18–20 Jul 2026" style range, collapsing when start and end match.
    static func rangeLabel(start: Date?, end: Date?) -> String {
        guard let start else { return "Date to be decided" }
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return start.formatted(date: .abbreviated, time: .omitted)
        }
        return "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }

    /// Friendly countdown copy: "Today!", "Tomorrow", "In 23 days".
    static func countdownLabel(to date: Date, from now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Today!" }
        if date < now { return "Done and dusted" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    static func daysUntil(_ date: Date, from now: Date = .now) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }
}
