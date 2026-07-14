import SwiftUI

// MARK: - Screen background

/// Ambient screen backdrop: the warm surface gradient with a soft sunrise
/// glow bleeding in from the top corner — gives every screen gentle depth
/// without competing with content.
struct BrickScreenBackground: View {
    var body: some View {
        ZStack {
            BrickGradient.warmSurface

            // Sunrise bloom, top-leading; purely decorative.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [BrickColor.amber.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: -140, y: -260)
                .blur(radius: 40)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [BrickColor.tangerine.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: 180, y: 320)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Card entrance

/// Staggered fade-and-rise for cards as a screen appears. Honours the
/// system Reduce Motion setting (content just appears, no movement).
struct CardAppearModifier: ViewModifier {
    var index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 22)
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.97)
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(BrickMotion.spring.delay(Double(min(index, 8)) * 0.06)) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    /// Staggered entrance for the Nth card in a list (capped so long lists
    /// don't feel sluggish).
    func cardAppear(_ index: Int = 0) -> some View {
        modifier(CardAppearModifier(index: index))
    }
}
