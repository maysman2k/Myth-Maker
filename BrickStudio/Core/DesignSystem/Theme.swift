import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }

    static func brickAdaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Brick Studio palette — a warm "sunrise" identity (sunny yellow → tangerine)
/// with soft neutral surfaces, tuned for both light and dark.
enum BrickColor {
    static let background = Color.brickAdaptive(light: 0xFBF7EF, dark: 0x121212)
    static let card = Color.brickAdaptive(light: 0xFFFFFF, dark: 0x1E1E20)
    static let elevatedCard = Color.brickAdaptive(light: 0xFFFFFF, dark: 0x2A2A2E)
    static let primaryText = Color.brickAdaptive(light: 0x1A1712, dark: 0xF7F3E8)
    static let secondaryText = Color.brickAdaptive(light: 0x8A8378, dark: 0xA7A7A7)
    static let border = Color.brickAdaptive(light: 0xEDE7DA, dark: 0x343438)

    // Sunrise accent ramp (from the snapee-inspired direction).
    static let sunYellow = Color(hex: 0xFFD23F)
    static let gold = Color(hex: 0xF7B733)
    static let amber = Color(hex: 0xF79E30)
    static let tangerine = Color(hex: 0xF57C1F)
    static let coral = Color(hex: 0xF2662E)

    // Semantic accents.
    static let brickRed = Color(hex: 0xD24B2A)
    static let stadiumGreen = Color(hex: 0x2E9D6B)
    /// Text/icon colour that sits on top of the gold accent.
    static let accentText = Color(hex: 0x1A1712)
}

/// Reusable gradients. `sunrise` is the signature brand fill.
enum BrickGradient {
    static let sunrise = LinearGradient(
        colors: [BrickColor.sunYellow, BrickColor.amber, BrickColor.tangerine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunriseSoft = LinearGradient(
        colors: [BrickColor.sunYellow.opacity(0.9), BrickColor.tangerine.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// A gentle warm wash for full-screen backgrounds behind content.
    static let warmSurface = LinearGradient(
        colors: [
            Color.brickAdaptive(light: 0xFFF6E4, dark: 0x181410),
            Color.brickAdaptive(light: 0xFBF7EF, dark: 0x121212)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum BrickFont {
    static let pageTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 21, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16)
    static let meta = Font.system(size: 13)
}

enum BrickSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum BrickRadius {
    static let card: CGFloat = 22
    static let control: CGFloat = 16
}

/// Shared motion vocabulary so animations feel like one system.
enum BrickMotion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.34, dampingFraction: 0.6)
    static let smooth = Animation.easeInOut(duration: 0.28)
}

// MARK: - Shadows & glows

extension View {
    /// Soft ambient card shadow — warm-tinted, layered for depth.
    func softShadow(_ strength: Double = 1) -> some View {
        self
            .shadow(color: Color(hex: 0x6B4E1F).opacity(0.06 * strength), radius: 3, y: 1)
            .shadow(color: Color(hex: 0x6B4E1F).opacity(0.10 * strength), radius: 16, y: 10)
    }

    /// Coloured glow, e.g. behind accent buttons and active chips.
    func brickGlow(_ color: Color = BrickColor.amber, radius: CGFloat = 18, strength: Double = 0.5) -> some View {
        shadow(color: color.opacity(strength), radius: radius, y: 6)
    }
}

// MARK: - Liquid Glass

/// Applies iOS 26 Liquid Glass when available, with a tasteful blurred
/// material fallback on earlier systems so the look is consistent.
struct LiquidGlassBackground<S: Shape>: ViewModifier {
    var shape: S
    var tinted: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                )
                .overlay(shape.fill(tinted ? BrickColor.gold.opacity(0.10) : Color.clear))
        }
    }
}

extension View {
    func liquidGlass<S: Shape>(in shape: S = Capsule(), tinted: Bool = false) -> some View {
        modifier(LiquidGlassBackground(shape: shape, tinted: tinted))
    }
}

// MARK: - Cards

struct BrickCardStyle: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? BrickColor.elevatedCard : BrickColor.card)
            .clipShape(RoundedRectangle(cornerRadius: BrickRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BrickRadius.card, style: .continuous)
                    .strokeBorder(BrickColor.border.opacity(0.7), lineWidth: 1)
            )
            .softShadow()
    }
}

extension View {
    func brickCard(elevated: Bool = false) -> some View { modifier(BrickCardStyle(elevated: elevated)) }
}

// MARK: - Buttons

/// Filled sunrise-gradient capsule (prominent) or soft tinted capsule.
struct StudButtonStyle: ButtonStyle {
    var tint: Color = BrickColor.gold
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, BrickSpacing.l)
            .frame(minHeight: 48)
            .background {
                if prominent {
                    Capsule().fill(gradient)
                } else {
                    Capsule().fill(tint.opacity(0.14))
                }
            }
            .foregroundStyle(prominent ? BrickColor.accentText : tint)
            .clipShape(Capsule())
            .brickGlow(tint, radius: prominent ? 16 : 0, strength: prominent ? 0.35 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(BrickMotion.bouncy, value: configuration.isPressed)
    }

    private var gradient: LinearGradient {
        // Gold keeps the full sunrise ramp; other tints get a subtle self-blend.
        if tint == BrickColor.gold {
            return BrickGradient.sunrise
        }
        return LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Springy scale-down for tappable cards and tiles.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(BrickMotion.bouncy, value: configuration.isPressed)
    }
}
