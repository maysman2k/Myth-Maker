import Foundation

enum AppDate {
    static func relative(_ date: Date, to reference: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: reference)
    }

    static func medium(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func greeting(for date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Morning"
        case 12..<18: return "Afternoon"
        default: return "Evening"
        }
    }
}

enum TextUtilities {
    /// Average adult reading speed used to estimate article read time.
    static func readTimeMinutes(for text: String) -> Int {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return max(1, Int((Double(words) / 220.0).rounded(.up)))
    }

    static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let allowed = lowered.map { char -> Character in
            (char.isLetter || char.isNumber) ? char : "-"
        }
        return String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
    }
}
