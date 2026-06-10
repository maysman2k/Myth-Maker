import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showCreateEvent = false
    @State private var showJoinEvent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.xl) {
                greeting

                if !model.pendingActions.isEmpty {
                    pendingActionsSection
                }

                if model.upcomingEvents.isEmpty {
                    EmptyStateView(symbol: "sparkles",
                                   title: "Nothing in the works",
                                   message: "Start planning something worth talking about.",
                                   actionLabel: "Plan an event") { showCreateEvent = true }
                } else {
                    VStack(alignment: .leading, spacing: PlanrSpacing.md) {
                        Text("In the works")
                            .font(PlanrFont.screenTitle)
                        ForEach(model.upcomingEvents) { event in
                            NavigationLink(value: event.id) {
                                EventCardView(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let memory = model.completedEvents.first {
                    memoryTeaser(memory)
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.bottom, PlanrSpacing.xxl)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Planr")
        .navigationDestination(for: String.self) { eventID in
            EventDashboardView(eventID: eventID)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showJoinEvent = true
                } label: {
                    Label("Join with code", systemImage: "qrcode.viewfinder")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateEvent = true
                } label: {
                    Label("New event", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            EventCreationView()
        }
        .sheet(isPresented: $showJoinEvent) {
            JoinEventView()
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
            Text("Alright, \(model.currentUser?.firstName ?? "you") 👋")
                .font(PlanrFont.heroTitle)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, PlanrSpacing.sm)
    }

    private var subtitle: String {
        let count = model.pendingActions.count
        if count == 0 { return "All caught up. Smug feeling earned." }
        return count == 1 ? "One thing needs you." : "\(count) things need you."
    }

    private var pendingActionsSection: some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.md) {
            Text("Needs your attention")
                .font(PlanrFont.screenTitle)
            ForEach(model.pendingActions.prefix(4)) { action in
                NavigationLink(value: action.eventID) {
                    HStack(spacing: PlanrSpacing.md) {
                        Image(systemName: action.symbol)
                            .foregroundStyle(PlanrColor.ember)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(action.eventTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .softCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memoryTeaser(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.md) {
            Text("Remember this?")
                .font(PlanrFont.screenTitle)
            NavigationLink {
                EventWrapView(eventID: event.id)
            } label: {
                HStack(spacing: PlanrSpacing.md) {
                    CoverArtView(paletteIndex: event.coverPaletteIndex, kind: event.kind,
                                 moodEmoji: event.moodEmoji, height: 64,
                                 cornerRadius: PlanrRadius.chip)
                        .frame(width: 96)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(PlanrFont.cardTitle)
                            .foregroundStyle(.primary)
                        Text(DateUtilities.rangeLabel(start: event.startDate, end: event.endDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .softCard()
            }
            .buttonStyle(.plain)
        }
    }
}
