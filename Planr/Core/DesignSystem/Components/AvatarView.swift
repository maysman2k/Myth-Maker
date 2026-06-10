import SwiftUI

enum AvatarPalette {
    static let colors: [Color] = [
        Color(red: 0.95, green: 0.45, blue: 0.40),
        Color(red: 0.35, green: 0.50, blue: 0.90),
        Color(red: 0.20, green: 0.65, blue: 0.55),
        Color(red: 0.90, green: 0.60, blue: 0.20),
        Color(red: 0.65, green: 0.40, blue: 0.85),
        Color(red: 0.85, green: 0.35, blue: 0.60),
    ]

    static func color(at index: Int) -> Color {
        colors[abs(index) % colors.count]
    }
}

struct AvatarView: View {
    let profile: UserProfile?
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(AvatarPalette.color(at: profile?.avatarColorIndex ?? 0).gradient)
            Image(systemName: profile?.avatarSymbol ?? "person.fill")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(profile?.displayName ?? "Unknown person")
    }
}

/// Overlapping avatar stack for participant previews.
struct AvatarStack: View {
    let profiles: [UserProfile]
    var size: CGFloat = 28
    var maxShown = 5

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(profiles.prefix(maxShown)) { profile in
                AvatarView(profile: profile, size: size)
                    .overlay(Circle().strokeBorder(PlanrColor.surfacePrimary, lineWidth: 2))
            }
            if profiles.count > maxShown {
                Text("+\(profiles.count - maxShown)")
                    .font(.caption2.bold())
                    .frame(width: size, height: size)
                    .background(Circle().fill(.secondary.opacity(0.25)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profiles.count) people")
    }
}
