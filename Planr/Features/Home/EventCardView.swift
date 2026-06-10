import SwiftUI

/// Large event card for the Home screen — cover-led, glanceable.
struct EventCardView: View {
    @Environment(AppModel.self) private var model
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverArtView(paletteIndex: event.coverPaletteIndex, kind: event.kind,
                         moodEmoji: event.moodEmoji, height: 120)
                .overlay(alignment: .topTrailing) {
                    PhaseBadge(phase: event.phase)
                        .padding(PlanrSpacing.md)
                }

            VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(PlanrFont.cardTitle)
                            .foregroundStyle(.primary)
                        Text(subtitleLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    EventPulseRing(score: model.pulse(for: event).score, size: 44)
                }

                HStack {
                    AvatarStack(profiles: model.participants(in: event))
                    Spacer()
                    if let start = event.startDate {
                        CountdownPill(date: start)
                    } else {
                        Text("Date TBC")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, PlanrSpacing.md)
                            .padding(.vertical, PlanrSpacing.xs + 2)
                            .background(Capsule().fill(.secondary.opacity(0.15)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(PlanrSpacing.cardPadding)
        }
        .background(PlanrColor.surfacePrimary,
                    in: RoundedRectangle(cornerRadius: PlanrRadius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }

    private var subtitleLine: String {
        var parts = [event.kind.label]
        if let location = event.locationName { parts.append(location) }
        parts.append(DateUtilities.rangeLabel(start: event.startDate, end: event.endDate))
        return parts.joined(separator: " · ")
    }
}
