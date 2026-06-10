import SwiftUI

/// Compact countdown pill: "In 23 days".
struct CountdownPill: View {
    let date: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            Label(DateUtilities.countdownLabel(to: date, from: context.date),
                  systemImage: "hourglass")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, PlanrSpacing.md)
                .padding(.vertical, PlanrSpacing.xs + 2)
                .background(Capsule().fill(PlanrColor.ember.opacity(0.16)))
                .foregroundStyle(PlanrColor.ember)
        }
    }
}

/// Big countdown for the dashboard in hype mode.
struct CountdownHero: View {
    let date: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.everyMinute) { context in
            let days = max(0, DateUtilities.daysUntil(date, from: context.date))
            HStack(spacing: PlanrSpacing.sm) {
                Text("\(days)")
                    .font(PlanrFont.numeric)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text(days == 1 ? "day to go" : "days to go")
                    .font(PlanrFont.cardTitle)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
