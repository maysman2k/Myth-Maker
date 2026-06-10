import SwiftUI

struct TasksMoneyView: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    private enum Tab: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case money = "Money"
        case shame = "Shame board"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .tasks
    @State private var showNewTask = false
    @State private var showNewPayment = false

    var body: some View {
        let event = model.event(withID: eventID)
        let tabs: [Tab] = event?.shameBoardEnabled == true ? Tab.allCases : [.tasks, .money]

        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(tabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.vertical, PlanrSpacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: PlanrSpacing.md) {
                    switch tab {
                    case .tasks: TasksSection(eventID: eventID, showNewTask: $showNewTask)
                    case .money: PaymentsSection(eventID: eventID, showNewPayment: $showNewPayment)
                    case .shame: ShameBoardSection(eventID: eventID)
                    }
                }
                .padding(.horizontal, PlanrSpacing.screenMargin)
                .padding(.vertical, PlanrSpacing.lg)
            }
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Tasks & money")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if event?.isFinished == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showNewTask = true
                        } label: {
                            Label("New task", systemImage: "checklist")
                        }
                        Button {
                            showNewPayment = true
                        } label: {
                            Label("Track a payment", systemImage: "sterlingsign.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewTask) {
            NewTaskSheet(eventID: eventID)
        }
        .sheet(isPresented: $showNewPayment) {
            NewPaymentSheet(eventID: eventID)
        }
    }
}

// MARK: - Tasks

private struct TasksSection: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    @Binding var showNewTask: Bool

    var body: some View {
        let tasks = model.tasks(for: eventID)
        let myID = model.currentUser?.id

        if tasks.isEmpty {
            EmptyStateView(symbol: "checklist",
                           title: "No jobs yet",
                           message: "Split the work so it isn't one hero doing everything.",
                           actionLabel: "Add a task") { showNewTask = true }
        } else {
            let mine = tasks.filter { $0.assigneeID == myID }
            let others = tasks.filter { $0.assigneeID != myID }
            if !mine.isEmpty {
                Text("Yours").font(PlanrFont.cardTitle)
                ForEach(mine) { taskRow($0) }
            }
            if !others.isEmpty {
                Text("Everyone else").font(PlanrFont.cardTitle)
                ForEach(others) { taskRow($0) }
            }
        }
    }

    private func taskRow(_ task: EventTask) -> some View {
        let canUpdate = task.assigneeID == model.currentUser?.id
            || model.event(withID: eventID).map { model.role(in: $0).canManage } == true

        return HStack(spacing: PlanrSpacing.md) {
            Button {
                guard canUpdate else { return }
                let next: TaskStatus = switch task.status {
                case .open: .inProgress
                case .inProgress: .complete
                case .complete: .open
                }
                model.setTaskStatus(task, to: next)
            } label: {
                Image(systemName: task.status.symbol)
                    .font(.title3)
                    .foregroundStyle(task.status == .complete ? PlanrColor.statusSuccess : PlanrColor.ember)
            }
            .buttonStyle(.plain)
            .disabled(!canUpdate)
            .accessibilityLabel("Status: \(task.status.label). Tap to change.")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(task.status == .complete)
                HStack(spacing: PlanrSpacing.sm) {
                    Text(model.displayName(for: task.assigneeID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let due = task.dueDate {
                        Label(due.formatted(date: .abbreviated, time: .omitted),
                              systemImage: task.isOverdue() ? "exclamationmark.circle.fill" : "calendar")
                            .font(.caption)
                            .foregroundStyle(task.isOverdue() ? PlanrColor.statusDanger : .secondary)
                    }
                }
            }
            Spacer()
            Text(task.status.label)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, PlanrSpacing.sm)
                .padding(.vertical, PlanrSpacing.xs)
                .background(Capsule().fill(.secondary.opacity(0.12)))
                .foregroundStyle(.secondary)
        }
        .softCard()
    }
}

// MARK: - Payments

private struct PaymentsSection: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    @Binding var showNewPayment: Bool

    var body: some View {
        let payments = model.payments(for: eventID)

        if payments.isEmpty {
            EmptyStateView(symbol: "sterlingsign.circle",
                           title: "Nothing owed",
                           message: "Track deposits and tabs here. Planr never holds the money — it just remembers who owes.",
                           actionLabel: "Track a payment") { showNewPayment = true }
        } else {
            summaryLine(payments)
            ForEach(payments) { paymentCard($0) }
            Text("Planr tracks who owes what. Money changes hands outside the app.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func summaryLine(_ payments: [Payment]) -> some View {
        if let myID = model.currentUser?.id {
            let iOwe = payments.reduce(Decimal(0)) { total, payment in
                payment.share(for: myID)?.state == .owed ? total + payment.amountPerPerson : total
            }
            let currency = payments.first?.currencyCode ?? "GBP"
            GlassCard {
                Label(iOwe > 0
                      ? "You owe \(iOwe.formatted(.currency(code: currency)))"
                      : "You're all settled up. Halo earned.",
                      systemImage: iOwe > 0 ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                    .font(PlanrFont.cardTitle)
                    .foregroundStyle(iOwe > 0 ? PlanrColor.statusWarning : PlanrColor.statusSuccess)
            }
        }
    }

    private func paymentCard(_ payment: Payment) -> some View {
        let event = model.event(withID: eventID)
        let canConfirm = event.map { model.role(in: $0).canManage } == true
            || payment.paidByID == model.currentUser?.id

        return VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(payment.title)
                        .font(PlanrFont.cardTitle)
                    Text("\(payment.formattedAmount) each, to \(model.displayName(for: payment.paidByID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let due = payment.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted),
                          systemImage: payment.isOverdue() ? "exclamationmark.circle.fill" : "calendar")
                        .font(.caption)
                        .foregroundStyle(payment.isOverdue() ? PlanrColor.statusDanger : .secondary)
                }
            }
            Divider()
            ForEach(payment.shares) { share in
                shareRow(share, payment: payment, canConfirm: canConfirm)
            }
        }
        .softCard()
    }

    private func shareRow(_ share: PaymentShare, payment: Payment, canConfirm: Bool) -> some View {
        HStack(spacing: PlanrSpacing.md) {
            AvatarView(profile: model.user(withID: share.userID), size: 28)
            Text(model.displayName(for: share.userID))
                .font(.subheadline)
            Spacer()
            switch share.state {
            case .owed:
                if share.userID == model.currentUser?.id {
                    Button("Mark as paid") {
                        model.markShare(of: payment, userID: share.userID, as: .markedPaid)
                    }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                } else {
                    stateChip("Owes", color: PlanrColor.statusWarning)
                }
            case .markedPaid:
                if canConfirm {
                    Button("Confirm") {
                        model.markShare(of: payment, userID: share.userID, as: .confirmed)
                    }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(PlanrColor.statusSuccess)
                } else {
                    stateChip("Says it's paid", color: PlanrColor.statusWarning)
                }
            case .confirmed:
                stateChip("Paid ✓", color: PlanrColor.statusSuccess)
            }
        }
    }

    private func stateChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, PlanrSpacing.sm)
            .padding(.vertical, PlanrSpacing.xs)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

// MARK: - Shame board

private struct ShameBoardSection: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    var body: some View {
        let event = model.event(withID: eventID)
        let entries = ShameBoardCalculator.entries(
            participants: event.map { model.participants(in: $0) } ?? [],
            tasks: model.tasks(for: eventID),
            payments: model.payments(for: eventID))

        if entries.isEmpty {
            EmptyStateView(symbol: "trophy",
                           title: "Nothing to report",
                           message: "No heroes, no stragglers. Yet.")
        } else {
            ForEach(entries) { entry in
                HStack(spacing: PlanrSpacing.md) {
                    Text(entry.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(PlanrFont.cardTitle)
                        Text(entry.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    AvatarView(profile: model.user(withID: entry.userID), size: 32)
                }
                .softCard()
            }
            Text("All in good fun. Anyone can hide themselves from shame boards in Profile settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
