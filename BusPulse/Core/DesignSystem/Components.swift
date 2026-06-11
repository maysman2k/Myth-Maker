import SwiftUI

extension Color {
    /// "#rrggbb" → Color, or nil for anything else.
    init?(hexString: String?) {
        guard let hexString, let (r, g, b) = LiveryColor.rgb(fromHex: hexString) else {
            return nil
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// Route number pill, coloured to match the real bus livery when known.
struct RoutePill: View {
    let lineName: String
    var backgroundHex: String?
    var foregroundHex: String?

    var body: some View {
        Text(lineName)
            .font(BPFont.routeNumber)
            .lineLimit(1)
            .padding(.horizontal, BPSpacing.sm + 2)
            .padding(.vertical, BPSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: BPRadius.chip, style: .continuous)
                    .fill(Color(hexString: backgroundHex) ?? BPColor.routeFallback)
            )
            .foregroundStyle(Color(hexString: foregroundHex)
                             ?? BPColor.backgroundPrimary)
            .accessibilityLabel("Route \(lineName)")
    }
}

/// Pulsing LIVE indicator. Static when Reduce Motion is on.
struct LiveBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: BPSpacing.xs) {
            Circle()
                .fill(BPColor.live)
                .frame(width: 8, height: 8)
                .opacity(pulsing && !reduceMotion ? 0.3 : 1)
                .animation(reduceMotion ? nil
                           : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                           value: pulsing)
            Text("LIVE")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(BPColor.live)
        }
        .onAppear { pulsing = true }
        .accessibilityLabel("Live data")
    }
}

/// Soft card surface.
struct BPCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(BPSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BPColor.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: BPRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

extension View {
    func bpCard() -> some View {
        modifier(BPCardModifier())
    }
}

struct BPEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: BPSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(BPColor.signal)
            Text(title)
                .font(BPFont.cardTitle)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(BPSpacing.xl)
    }
}

/// Shown when the device is offline — saved timetables still work.
struct OfflineBanner: View {
    var body: some View {
        Label("Offline — showing saved timetables", systemImage: "wifi.slash")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, BPSpacing.md)
            .padding(.vertical, BPSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(BPColor.late.opacity(0.18))
            .foregroundStyle(BPColor.late)
    }
}

/// Punctuality chip for a live vehicle.
struct DelayChip: View {
    let status: DelayStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, BPSpacing.sm)
            .padding(.vertical, BPSpacing.xs)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .onTime: return BPColor.onTime
        case .late: return BPColor.late
        case .early: return BPColor.early
        }
    }
}
