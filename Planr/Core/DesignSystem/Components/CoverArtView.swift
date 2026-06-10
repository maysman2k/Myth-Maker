import SwiftUI

/// Generated gradient cover so every event looks great with zero setup.
struct CoverArtView: View {
    let paletteIndex: Int
    let kind: EventKind
    var moodEmoji: String?
    var height: CGFloat = 160
    var cornerRadius: CGFloat = PlanrRadius.largeCard

    var body: some View {
        let colors = CoverPalette.colors(at: paletteIndex)
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: height * 1.3)
                .offset(x: height * 0.4, y: -height * 0.45)
            Image(systemName: kind.symbol)
                .font(.system(size: height * 0.42, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))
                .padding(PlanrSpacing.lg)
            if let moodEmoji {
                Text(moodEmoji)
                    .font(.system(size: height * 0.22))
                    .padding(PlanrSpacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Small gradient tile used for placeholder photos in sample data.
struct PlaceholderPhotoView: View {
    let paletteIndex: Int
    var symbol: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: CoverPalette.colors(at: paletteIndex),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol ?? "photo")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
