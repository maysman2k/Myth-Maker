import SwiftUI

struct VoteDetailView: View {
    @Environment(AppModel.self) private var model
    let voteID: String

    @State private var pendingConfirmOptionID: String?

    var body: some View {
        if let vote = model.votes.first(where: { $0.id == voteID }),
           let event = model.event(withID: vote.eventID) {
            content(vote: vote, event: event)
        } else {
            EmptyStateView(symbol: "questionmark.circle",
                           title: "Vote not found",
                           message: "This vote may have been removed.")
        }
    }

    private func content(vote: Vote, event: Event) -> some View {
        let participantCount = event.participantIDs.count
        let tallies = VoteCalculator.tallies(for: vote, participantCount: participantCount)
        let mySelection = Set(model.currentUser.flatMap { vote.response(from: $0.id)?.optionIDs } ?? [])

        return ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
                    if let detail = vote.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if vote.isOpen {
                        Text(vote.allowsMultipleSelection
                             ? "Tap every option that works for you."
                             : "Tap your pick. You can change it until the vote closes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let deadline = vote.deadline, vote.isOpen {
                        Label("Closes \(deadline.formatted(date: .abbreviated, time: .shortened))",
                              systemImage: "hourglass")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(vote.isPastDeadline() ? PlanrColor.statusDanger : PlanrColor.ember)
                    }
                }

                if vote.status == .confirmed, let winner = vote.winningOption {
                    GlassCard {
                        Label("Decided: \(winner.label)", systemImage: "checkmark.seal.fill")
                            .font(PlanrFont.cardTitle)
                            .foregroundStyle(PlanrColor.statusSuccess)
                    }
                }

                VStack(spacing: PlanrSpacing.md) {
                    ForEach(tallies, id: \.option.id) { tally in
                        optionRow(tally: tally, vote: vote,
                                  participantCount: participantCount,
                                  mySelection: mySelection)
                    }
                }

                consensusFooter(tallies: tallies, vote: vote, participantCount: participantCount)
                waitingOn(vote: vote, event: event)
                leaderActions(vote: vote, event: event, tallies: tallies)
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.vertical, PlanrSpacing.lg)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(vote.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Lock in this option?",
                            isPresented: Binding(get: { pendingConfirmOptionID != nil },
                                                 set: { if !$0 { pendingConfirmOptionID = nil } }),
                            titleVisibility: .visible) {
            Button("Confirm winner") {
                if let optionID = pendingConfirmOptionID {
                    model.confirm(vote: vote, winningOptionID: optionID)
                }
                pendingConfirmOptionID = nil
            }
        } message: {
            Text(confirmMessage(for: vote))
        }
    }

    private func confirmMessage(for vote: Vote) -> String {
        switch vote.kind {
        case .dateAvailability: return "This becomes the event date."
        case .location: return "This becomes the event location."
        case .freeform: return "This closes the vote and announces the result."
        }
    }

    private func optionRow(tally: VoteCalculator.Tally, vote: Vote,
                           participantCount: Int, mySelection: Set<String>) -> some View {
        let isSelected = mySelection.contains(tally.option.id)
        return Button {
            guard vote.isOpen else { return }
            var newSelection = mySelection
            if vote.allowsMultipleSelection {
                if isSelected { newSelection.remove(tally.option.id) } else { newSelection.insert(tally.option.id) }
            } else {
                newSelection = isSelected ? [] : [tally.option.id]
            }
            model.respond(to: vote, optionIDs: Array(newSelection))
        } label: {
            HStack(spacing: PlanrSpacing.md) {
                if vote.isOpen {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? PlanrColor.ember : .secondary)
                }
                TallyBar(label: tally.option.label,
                         subtitle: subtitle(for: tally.option),
                         fraction: tally.share,
                         count: tally.count,
                         isSelected: isSelected,
                         isWinner: vote.winningOptionID == tally.option.id)
            }
            .softCard()
        }
        .buttonStyle(.plain)
        .disabled(!vote.isOpen)
    }

    private func subtitle(for option: VoteOption) -> String? {
        if let date = option.date {
            return DateUtilities.countdownLabel(to: date)
        }
        return option.subtitle
    }

    @ViewBuilder
    private func consensusFooter(tallies: [VoteCalculator.Tally], vote: Vote, participantCount: Int) -> some View {
        if vote.isOpen, let top = tallies.first, top.count > 0 {
            let consensus = VoteCalculator.consensus(count: top.count, participantCount: participantCount)
            Label(consensusCopy(consensus, option: top.option.label),
                  systemImage: consensus == .unanimous ? "party.popper.fill" : "chart.bar.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func consensusCopy(_ consensus: VoteCalculator.Consensus, option: String) -> String {
        switch consensus {
        case .unanimous: return "Everyone can do \(option). That never happens."
        case .strongMajority: return "\(option) has a strong majority."
        case .bestAvailable: return "\(option) is the best available so far."
        case .none: return "No votes yet."
        }
    }

    @ViewBuilder
    private func waitingOn(vote: Vote, event: Event) -> some View {
        let waiting = VoteCalculator.nonResponders(for: vote, participantIDs: event.participantIDs)
            .compactMap { model.user(withID: $0) }
        if vote.isOpen && !waiting.isEmpty {
            HStack(spacing: PlanrSpacing.md) {
                AvatarStack(profiles: waiting)
                Text("\(waiting.count) still need\(waiting.count == 1 ? "s" : "") to vote.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func leaderActions(vote: Vote, event: Event,
                               tallies: [VoteCalculator.Tally]) -> some View {
        if vote.isOpen, model.role(in: event).canManage, let top = tallies.first, top.count > 0 {
            Button {
                pendingConfirmOptionID = top.option.id
            } label: {
                Label("Confirm \"\(top.option.label)\" as the winner", systemImage: "checkmark.seal.fill")
                    .font(PlanrFont.cardTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PlanrSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(PlanrColor.statusSuccess)
        }
    }
}
