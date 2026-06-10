import SwiftUI

/// Phase chip shown on event cards and the dashboard.
struct PhaseBadge: View {
    let phase: EventPhase

    var body: some View {
        HStack(spacing: PlanrSpacing.xs) {
            if phase == .lockdown {
                Image(systemName: "lock.fill")
            }
            Text(phase.label)
        }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, PlanrSpacing.sm + 2)
            .padding(.vertical, PlanrSpacing.xs)
            .background(Capsule().fill(PlanrColor.phaseColor(phase).opacity(0.18)))
            .foregroundStyle(PlanrColor.phaseColor(phase))
    }
}

/// The satisfying "Locked in. No more chaos." banner.
struct LockdownStatusBanner: View {
    let event: Event

    var body: some View {
        HStack(spacing: PlanrSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Locked in. No more chaos.")
                    .font(PlanrFont.cardTitle)
                Text(detailLine)
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(PlanrSpacing.cardPadding)
        .background(PlanrColor.statusLocked.gradient,
                    in: RoundedRectangle(cornerRadius: PlanrRadius.card, style: .continuous))
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private var detailLine: String {
        var parts = [DateUtilities.rangeLabel(start: event.startDate, end: event.endDate)]
        if let location = event.locationName { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

/// Event Pulse ring — readiness at a glance.
struct EventPulseRing: View {
    let score: Int
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: size * 0.11)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(ringColor.gradient,
                        style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)%")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Event Pulse \(score) percent ready")
    }

    private var ringColor: Color {
        switch score {
        case 75...: return PlanrColor.statusSuccess
        case 40..<75: return PlanrColor.statusWarning
        default: return PlanrColor.ember
        }
    }
}

/// Horizontal result bar for vote tallies.
struct TallyBar: View {
    let label: String
    var subtitle: String?
    let fraction: Double
    let count: Int
    var isSelected = false
    var isWinner = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                if isWinner {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(PlanrColor.statusSuccess)
                        .font(.subheadline)
                }
                Spacer()
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.15))
                    Capsule()
                        .fill(isWinner ? PlanrColor.statusSuccess : PlanrColor.ember)
                        .frame(width: max(8, geo.size.width * fraction))
                        .opacity(count > 0 ? 1 : 0)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(count) votes\(isWinner ? ", winner" : "")\(isSelected ? ", your pick" : "")")
    }
}
