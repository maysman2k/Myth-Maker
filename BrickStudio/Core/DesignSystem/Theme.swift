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

/// "The Brick Studio" palette from the product spec (§5.2).
enum BrickColor {
    static let background = Color.brickAdaptive(light: 0xF7F5F0, dark: 0x101010)
    static let card = Color.brickAdaptive(light: 0xFFFFFF, dark: 0x1B1B1B)
    static let primaryText = Color.brickAdaptive(light: 0x111111, dark: 0xF4F4F4)
    static let secondaryText = Color.brickAdaptive(light: 0x6D6D6D, dark: 0x9C9C9C)
    static let gold = Color(hex: 0xC8A45D)
    static let brickRed = Color(hex: 0x9E3D22)
    static let stadiumGreen = Color(hex: 0x2E7D4F)
    static let border = Color.brickAdaptive(light: 0xE7E1D7, dark: 0x2C2C2C)
}

enum BrickFont {
    static let pageTitle = Font.system(size: 30, weight: .bold)
    static let sectionTitle = Font.system(size: 21, weight: .bold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
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

struct BrickCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(BrickColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(BrickColor.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func brickCard() -> some View { modifier(BrickCardStyle()) }
}

/// Stud-inspired filled capsule button (§5.4).
struct StudButtonStyle: ButtonStyle {
    var tint: Color = BrickColor.gold
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, BrickSpacing.l)
            .frame(minHeight: 44)
            .background(prominent ? tint : tint.opacity(0.14))
            .foregroundStyle(prominent ? Color.white : tint)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
