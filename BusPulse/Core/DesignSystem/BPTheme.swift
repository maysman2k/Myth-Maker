import SwiftUI

// MARK: - Semantic colour tokens
// Transit-app palette: deep slate surfaces, electric teal "signal" accent.

enum BPColor {
    static let backgroundPrimary = Color(light: .init(red: 0.96, green: 0.97, blue: 0.98),
                                         dark: .init(red: 0.07, green: 0.09, blue: 0.11))
    static let surfacePrimary = Color(light: .white,
                                      dark: .init(red: 0.12, green: 0.14, blue: 0.17))
    static let signal = Color(light: .init(red: 0.0, green: 0.62, blue: 0.55),
                              dark: .init(red: 0.10, green: 0.87, blue: 0.76))
    static let live = Color(light: .init(red: 0.85, green: 0.25, blue: 0.30),
                            dark: .init(red: 0.98, green: 0.36, blue: 0.40))
    static let late = Color(light: .init(red: 0.85, green: 0.50, blue: 0.10),
                            dark: .init(red: 0.98, green: 0.64, blue: 0.22))
    static let early = Color(light: .init(red: 0.25, green: 0.45, blue: 0.85),
                             dark: .init(red: 0.45, green: 0.65, blue: 0.98))
    static let onTime = Color(light: .init(red: 0.18, green: 0.62, blue: 0.40),
                              dark: .init(red: 0.30, green: 0.78, blue: 0.52))
    /// Default route-pill colour when a vehicle has no livery information.
    static let routeFallback = Color(light: .init(red: 0.16, green: 0.20, blue: 0.28),
                                     dark: .init(red: 0.85, green: 0.88, blue: 0.92))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum BPSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let screenMargin: CGFloat = 20
}

enum BPRadius {
    static let chip: CGFloat = 10
    static let card: CGFloat = 16
    static let sheet: CGFloat = 24
}

enum BPFont {
    static let screenTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let cardTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    /// Departure times and countdowns — rounded, monospaced digits.
    static let time = Font.system(.title3, design: .rounded, weight: .bold).monospacedDigit()
    static let routeNumber = Font.system(.subheadline, design: .rounded, weight: .heavy)
}
