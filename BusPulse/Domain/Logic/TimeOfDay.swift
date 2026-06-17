import Foundation

/// Timetable time-of-day handling. UK timetables represent trips that run
/// past midnight as 24:xx / 25:xx, so values are seconds after midnight of
/// the *operating day* and may exceed 86,400.
enum TimeOfDay {

    /// Parses "HH:MM" or "HH:MM:SS" (hours may exceed 23) into seconds
    /// after midnight. Returns nil for anything malformed.
    static func seconds(from string: String?) -> Int? {
        guard let string, !string.isEmpty else { return nil }
        let parts = string.split(separator: ":").map(String.init)
        guard parts.count >= 2, parts.count <= 3,
              let hours = Int(parts[0]), hours >= 0,
              let minutes = Int(parts[1]), (0..<60).contains(minutes) else { return nil }
        let secondsPart = parts.count == 3 ? Int(parts[2]) : 0
        guard let secs = secondsPart, (0..<60).contains(secs) else { return nil }
        return hours * 3600 + minutes * 60 + secs
    }

    /// "07:05", or "00:15 (night)" style display for past-midnight times.
    static func label(forSeconds seconds: Int) -> String {
        let wrapped = seconds % 86_400
        let hours = wrapped / 3600
        let minutes = (wrapped % 3600) / 60
        let base = String(format: "%02d:%02d", hours, minutes)
        return seconds >= 86_400 ? "\(base) (night)" : base
    }

    /// Compact "HH:mm" with no night suffix — for tight timetable grid cells.
    static func clock(forSeconds seconds: Int) -> String {
        let wrapped = seconds % 86_400
        return String(format: "%02d:%02d", wrapped / 3600, (wrapped % 3600) / 60)
    }

    /// Resolves seconds-after-midnight against the start of an operating day
    /// into an absolute Date. Handles >24h values naturally.
    static func date(forSeconds seconds: Int, onDayStarting dayStart: Date) -> Date {
        dayStart.addingTimeInterval(TimeInterval(seconds))
    }
}
