import SwiftUI

// MARK: - Semantic colour tokens

enum PlanrColor {
    /// Warm cream in light mode, deep night in dark mode.
    static let backgroundPrimary = Color(light: .init(red: 0.97, green: 0.95, blue: 0.92),
                                         dark: .init(red: 0.08, green: 0.08, blue: 0.11))
    static let surfacePrimary = Color(light: .white,
                                      dark: .init(red: 0.13, green: 0.13, blue: 0.17))
    /// Solid stand-in for glass surfaces when Reduce Transparency is on.
    static let surfaceGlassFallback = Color(light: .init(white: 1.0),
                                            dark: .init(red: 0.16, green: 0.16, blue: 0.20))

    static let ember = Color(light: .init(red: 1.00, green: 0.42, blue: 0.38),
                             dark: .init(red: 1.00, green: 0.48, blue: 0.45))

    static let statusSuccess = Color(light: .init(red: 0.18, green: 0.62, blue: 0.40),
                                     dark: .init(red: 0.30, green: 0.78, blue: 0.52))
    static let statusWarning = Color(light: .init(red: 0.85, green: 0.52, blue: 0.10),
                                     dark: .init(red: 0.98, green: 0.65, blue: 0.22))
    static let statusDanger = Color(light: .init(red: 0.80, green: 0.22, blue: 0.20),
                                    dark: .init(red: 0.95, green: 0.38, blue: 0.36))
    static let statusLocked = Color(light: .init(red: 0.32, green: 0.30, blue: 0.72),
                                    dark: .init(red: 0.55, green: 0.53, blue: 0.95))

    static func phaseColor(_ phase: EventPhase) -> Color {
        switch phase {
        case .draft: return .secondary
        case .planning: return Color(light: .init(red: 0.15, green: 0.45, blue: 0.80),
                                     dark: .init(red: 0.40, green: 0.65, blue: 0.95))
        case .lockdown, .detailedPlanning: return statusLocked
        case .live: return statusSuccess
        case .completed, .archived: return statusWarning
        }
    }
}

extension Color {
    /// Adaptive colour that resolves differently in light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Spacing and radius tokens

enum PlanrSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let cardPadding: CGFloat = 16
    static let screenMargin: CGFloat = 20
}

enum PlanrRadius {
    static let chip: CGFloat = 12
    static let card: CGFloat = 20
    static let largeCard: CGFloat = 28
}

// MARK: - Typography
// Rounded headings keep the tone warm; body text stays system-standard
// so Dynamic Type behaves exactly as users expect.

enum PlanrFont {
    static let heroTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let screenTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let cardTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption)
    static let numeric = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
}

// MARK: - Cover palettes
// Events use generated gradient covers instead of forcing a photo upload.

enum CoverPalette {
    static let palettes: [[Color]] = [
        [Color(red: 1.00, green: 0.45, blue: 0.40), Color(red: 0.85, green: 0.25, blue: 0.55)], // sunset
        [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.45, green: 0.25, blue: 0.75)], // night sky
        [Color(red: 0.10, green: 0.65, blue: 0.55), Color(red: 0.05, green: 0.40, blue: 0.60)], // sea
        [Color(red: 0.95, green: 0.65, blue: 0.20), Color(red: 0.90, green: 0.35, blue: 0.25)], // ember
        [Color(red: 0.55, green: 0.30, blue: 0.85), Color(red: 0.90, green: 0.35, blue: 0.65)], // disco
        [Color(red: 0.20, green: 0.55, blue: 0.35), Color(red: 0.55, green: 0.75, blue: 0.30)], // field
    ]

    static func colors(at index: Int) -> [Color] {
        palettes[abs(index) % palettes.count]
    }
}
