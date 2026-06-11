import Foundation

/// bustimes.org describes vehicle liveries as CSS (solid colours or
/// gradients). Extract a usable colour so route pills can match the
/// real bus livery, falling back gracefully for anything exotic.
enum LiveryColor {

    /// First plausible colour in a CSS value: "#dc0000", "#fff",
    /// "rgb(220, 0, 0)", or one inside "linear-gradient(...)".
    static func firstHex(inCSS css: String?) -> String? {
        guard let css, !css.isEmpty else { return nil }

        if let range = css.range(of: "#[0-9a-fA-F]{6}", options: .regularExpression) {
            return String(css[range])
        }
        if let range = css.range(of: "#[0-9a-fA-F]{3}\\b", options: .regularExpression) {
            // Expand shorthand #abc to #aabbcc.
            let short = css[range].dropFirst()
            return "#" + short.map { "\($0)\($0)" }.joined()
        }
        if let range = css.range(of: "rgb\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*\\)",
                                 options: .regularExpression) {
            let numbers = css[range].split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0) }
            if numbers.count == 3, numbers.allSatisfy({ (0...255).contains($0) }) {
                return String(format: "#%02x%02x%02x", numbers[0], numbers[1], numbers[2])
            }
        }
        return nil
    }

    /// Black or white, whichever reads better on the given background.
    static func contrastingForeground(forHex hex: String) -> String {
        guard let (r, g, b) = rgb(fromHex: hex) else { return "#ffffff" }
        let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        return luminance > 145 ? "#000000" : "#ffffff"
    }

    static func rgb(fromHex hex: String) -> (Int, Int, Int)? {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        return ((number >> 16) & 0xFF, (number >> 8) & 0xFF, number & 0xFF)
    }
}
