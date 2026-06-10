import SwiftUI

/// The event hub. Sections adapt to the event's lifecycle phase, so the
/// screen leads with planning before lockdown, the countdown in hype mode,
/// today's essentials when live, and memories once wrapped.
struct EventDashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    @State private var showInvite = false
    @State private var showLockdownConfirm = false
    @State private var showDeleteConfirm = false
    @State private var calendarFeedback: String?

    var body: some View {
        if let event = model.event(withID: eventID) {
            content(for: event)
        } else {
            EmptyStateView(symbol: "questionmark.circle",
                           title: "Event not found",
                           message: AppError.eventNotFound.errorDescription ?? "")
        }
    }

    private func content(for event: Event) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                header(for: event)

                if event.isLockedDown {
                    LockdownStatusBanner(event: event)
                }

                switch event.mode() {
                case .planning:
                    pulseCard(for: event)
                    nextSteps(for: event)
                case .lockdown, .hype:
                    if let start = event.startDate {
                        hypeCard(start: start, event: event)
                    }
                    pulseCard(for: event)
                case .live:
                    liveCard(for: event)
                case .memory:
                    memoryCard(for: event)
                }

                featureGrid(for: event)
                leaderControls(for: event)

                if let calendarFeedback {
                    Label(calendarFeedback, systemImage: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.bottom, PlanrSpacing.xxl)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent(for: event) }
        .sheet(isPresented: $showInvite) {
            InviteSheetView(eventID: event.id)
        }
        .confirmationDialog("Lock it in?", isPresented: $showLockdownConfirm, titleVisibility: .visible) {
            Button("Lock in the plan") { model.lockdown(event) }
        } message: {
            Text("Date and location get confirmed and protected. Changes after this need a leader override.")
        }
        .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                model.deleteEvent(event)
                dismiss()
            }
        } message: {
            Text("Votes, chat, tasks and photos all go with it. No undo.")
        }
    }

    // MARK: Header

    private func header(for event: Event) -> some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.md) {
            CoverArtView(paletteIndex: event.coverPaletteIndex, kind: event.kind,
                         moodEmoji: event.moodEmoji, height: 150)
                .overlay(alignment: .topTrailing) {
                    PhaseBadge(phase: event.phase)
                        .padding(PlanrSpacing.md)
                }
            VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
                Text(event.title)
                    .font(PlanrFont.heroTitle)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: PlanrSpacing.md) {
                    Label(DateUtilities.rangeLabel(start: event.startDate, end: event.endDate),
                          systemImage: "calendar")
                    if let location = event.locationName {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                HStack {
                    AvatarStack(profiles: model.participants(in: event))
                    Spacer()
                    Button {
                        showInvite = true
                    } label: {
                        Label("Invite", systemImage: "person.badge.plus")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Mode cards

    private func pulseCard(for event: Event) -> some View {
        let pulse = model.pulse(for: event)
        return GlassCard {
            VStack(alignment: .leading, spacing: PlanrSpacing.md) {
                HStack(spacing: PlanrSpacing.lg) {
                    EventPulseRing(score: pulse.score, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Event Pulse")
                            .font(PlanrFont.cardTitle)
                        Text(EventPulseCalculator.headline(for: pulse,
                                                           blockerName: model.blockerName(for: event)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: PlanrSpacing.lg) {
                    ForEach(pulse.components) { component in
                        VStack(spacing: PlanrSpacing.xs) {
                            Image(systemName: component.symbol)
                                .font(.caption)
                                .foregroundStyle(component.progress >= 1 ? PlanrColor.statusSuccess : .secondary)
                            Text("\(Int(component.progress * 100))%")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                            Text(component.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func nextSteps(for event: Event) -> some View {
        let steps = nextStepLines(for: event)
        return Group {
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                    Text("Next steps")
                        .font(PlanrFont.cardTitle)
                    ForEach(steps, id: \.self) { step in
                        Label(step, systemImage: "arrow.right.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                .softCard()
            }
        }
    }

    private func nextStepLines(for event: Event) -> [String] {
        var steps: [String] = []
        let openVotes = model.votes(for: event.id).filter(\.isOpen)
        if !openVotes.isEmpty {
            steps.append("\(openVotes.count) vote\(openVotes.count == 1 ? "" : "s") still open")
        }
        if event.startDate == nil {
            steps.append(openVotes.contains { $0.kind == .dateAvailability }
                         ? "Confirm the date once votes are in"
                         : "Open a date vote so people can pick days")
        } else if model.isLeader(of: event) && event.phase == .planning {
            steps.append("Date is set — ready to lock it in")
        }
        let openTasks = model.tasks(for: event.id).filter { $0.status != .complete }
        if !openTasks.isEmpty {
            steps.append("\(openTasks.count) task\(openTasks.count == 1 ? "" : "s") to finish")
        }
        return steps
    }

    private func hypeCard(start: Date, event: Event) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                Text("It's happening \(event.moodEmoji)")
                    .font(PlanrFont.cardTitle)
                CountdownHero(date: start)
                if let location = event.locationName {
                    Text("See you in \(location).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func liveCard(for event: Event) -> some View {
        let todayTasks = model.tasks(for: event.id)
            .filter { $0.status != .complete }
        return GlassCard {
            VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                Label("Today's plan", systemImage: "sun.max.fill")
                    .font(PlanrFont.cardTitle)
                if let location = event.locationName {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
                if let budget = event.budgetNote {
                    Label(budget, systemImage: "banknote")
                        .font(.subheadline)
                }
                if todayTasks.isEmpty {
                    Text("Nothing left on the list. Go enjoy it — and feed the photo album.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayTasks.prefix(3)) { task in
                        Label("\(task.title) — \(model.displayName(for: task.assigneeID))",
                              systemImage: "checklist")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func memoryCard(for event: Event) -> some View {
        NavigationLink {
            EventWrapView(eventID: event.id)
        } label: {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Event Wrap is ready")
                            .font(PlanrFont.cardTitle)
                        Text("Stats, awards and the story of the day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundStyle(PlanrColor.ember)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Feature grid

    private func featureGrid(for event: Event) -> some View {
        let openVotes = model.votes(for: event.id).filter(\.isOpen).count
        let openTasks = model.tasks(for: event.id).filter { $0.status != .complete }.count
        let owedShares = model.payments(for: event.id)
            .flatMap(\.shares).filter { $0.state != .confirmed }.count
        let photoCount = model.photos(for: event.id).count
        let lastMessage = model.messages(for: event.id).last

        return VStack(spacing: PlanrSpacing.md) {
            featureRow(title: "Plan & vote", symbol: "checkmark.seal.fill",
                       badge: openVotes > 0 ? "\(openVotes) open" : nil) {
                PlanningView(eventID: event.id)
            }
            featureRow(title: "Chat", symbol: "bubble.left.and.bubble.right.fill",
                       badge: nil,
                       subtitle: lastMessage.map { message in
                           message.kind == .system
                               ? message.text
                               : "\(model.displayName(for: message.senderID)): \(message.text)"
                       }) {
                ChatView(eventID: event.id)
            }
            featureRow(title: "Tasks & money", symbol: "checklist",
                       badge: badgeText(openTasks: openTasks, owedShares: owedShares)) {
                TasksMoneyView(eventID: event.id)
            }
            featureRow(title: "Photos", symbol: "photo.on.rectangle.angled",
                       badge: photoCount > 0 ? "\(photoCount)" : nil) {
                PhotosGridView(eventID: event.id)
            }
            featureRow(title: "Bingo & games", symbol: "gamecontroller.fill",
                       badge: bingoBadge(for: event)) {
                BingoView(eventID: event.id)
            }
        }
    }

    private func badgeText(openTasks: Int, owedShares: Int) -> String? {
        var parts: [String] = []
        if openTasks > 0 { parts.append("\(openTasks) tasks") }
        if owedShares > 0 { parts.append("\(owedShares) owe") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func bingoBadge(for event: Event) -> String? {
        guard let game = model.bingoGame(for: event.id) else { return nil }
        switch game.status {
        case .collecting: return "collecting"
        case .playing: return "live"
        case .finished: return "done"
        }
    }

    private func featureRow(title: String, symbol: String, badge: String?,
                            subtitle: String? = nil,
                            @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: PlanrSpacing.md) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(PlanrColor.ember)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PlanrFont.cardTitle)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, PlanrSpacing.sm)
                        .padding(.vertical, PlanrSpacing.xs)
                        .background(Capsule().fill(PlanrColor.ember.opacity(0.15)))
                        .foregroundStyle(PlanrColor.ember)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .softCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Leader controls & toolbar

    @ViewBuilder
    private func leaderControls(for event: Event) -> some View {
        if let me = model.currentUser {
            VStack(spacing: PlanrSpacing.md) {
                if LockdownPolicy.canLockdown(event, userID: me.id) {
                    Button {
                        showLockdownConfirm = true
                    } label: {
                        Label("Lock it in", systemImage: "lock.fill")
                            .font(PlanrFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PlanrSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlanrColor.statusLocked)
                } else if event.phase == .planning && model.isLeader(of: event) {
                    Label("Confirm a date to unlock Lockdown mode.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if LockdownPolicy.canStartLiveMode(event, userID: me.id) {
                    Button {
                        model.startLiveMode(event)
                    } label: {
                        Label("Start live mode", systemImage: "play.circle.fill")
                            .font(PlanrFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PlanrSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlanrColor.statusSuccess)
                }

                if LockdownPolicy.canComplete(event, userID: me.id) {
                    Button {
                        model.completeEvent(event)
                    } label: {
                        Label("Wrap it up", systemImage: "gift.fill")
                            .font(PlanrFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PlanrSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlanrColor.statusWarning)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(for event: Event) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if event.startDate != nil {
                    Button {
                        addToCalendar(event)
                    } label: {
                        Label("Add to calendar", systemImage: "calendar.badge.plus")
                    }
                }
                Button {
                    showInvite = true
                } label: {
                    Label("Invite people", systemImage: "person.badge.plus")
                }
                if model.isLeader(of: event) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete event", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        model.leaveEvent(event)
                        dismiss()
                    } label: {
                        Label("Leave event", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func addToCalendar(_ event: Event) {
        Task {
            do {
                try await model.calendarSync.addToCalendar(event)
                calendarFeedback = "Added to your calendar."
            } catch {
                calendarFeedback = (error as? AppError)?.errorDescription
                    ?? "Couldn't add to calendar."
            }
        }
    }
}
