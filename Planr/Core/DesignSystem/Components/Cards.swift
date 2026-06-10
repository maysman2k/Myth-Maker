import SwiftUI

/// Glass surface that degrades gracefully when Reduce Transparency is on.
struct GlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = PlanrRadius.card
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(PlanrSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    shape.fill(PlanrColor.surfaceGlassFallback)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.12))
            }
    }
}

/// Standard soft card on the warm background.
struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(PlanrSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanrColor.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: PlanrRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func softCard() -> some View {
        modifier(SoftCardModifier())
    }
}

/// Friendly empty state used across feature screens.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: PlanrSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(PlanrColor.ember)
            Text(title)
                .font(PlanrFont.cardTitle)
            Text(message)
                .font(PlanrFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, PlanrSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PlanrSpacing.xxl)
    }
}
