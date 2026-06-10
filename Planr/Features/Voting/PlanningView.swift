import SwiftUI

/// All decisions for an event: open votes first, settled ones below.
struct PlanningView: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    @State private var showCreateVote = false

    var body: some View {
        let votes = model.votes(for: eventID)
        let event = model.event(withID: eventID)

        ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                if votes.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal",
                                   title: "No decisions yet",
                                   message: "Open a vote and let the group settle it — dates, places, fancy dress, anything.",
                                   actionLabel: canCreate ? "Start a vote" : nil) {
                        showCreateVote = true
                    }
                } else {
                    ForEach(votes) { vote in
                        NavigationLink {
                            VoteDetailView(voteID: vote.id)
                        } label: {
                            voteCard(vote, event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.vertical, PlanrSpacing.lg)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Plan & vote")
        .toolbar {
            if canCreate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateVote = true
                    } label: {
                        Label("New vote", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateVote) {
            CreateVoteView(eventID: eventID)
        }
    }

    private var canCreate: Bool {
        guard let event = model.event(withID: eventID) else { return false }
        return !event.isFinished
    }

    private func voteCard(_ vote: Vote, event: Event?) -> some View {
        let participantCount = event?.participantIDs.count ?? 1
        let leading = VoteCalculator.leadingTally(for: vote, participantCount: participantCount)
        let myResponse = model.currentUser.flatMap { vote.response(from: $0.id) }

        return VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
            HStack {
                Image(systemName: vote.kind.symbol)
                    .foregroundStyle(PlanrColor.ember)
                Text(vote.title)
                    .font(PlanrFont.cardTitle)
                    .foregroundStyle(.primary)
                Spacer()
                statusChip(for: vote)
            }
            if vote.status == .confirmed, let winner = vote.winningOption {
                Label(winner.label, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PlanrColor.statusSuccess)
            } else if let leading {
                Text("Leading: \(leading.option.label) (\(leading.count) of \(participantCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No votes yet — be the first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let deadline = vote.deadline, vote.isOpen {
                    Label(DateUtilities.countdownLabel(to: deadline), systemImage: "hourglass")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(vote.isPastDeadline() ? PlanrColor.statusDanger : .secondary)
                }
                Spacer()
                if vote.isOpen && myResponse == nil {
                    Text("Your vote needed")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PlanrColor.ember)
                }
            }
        }
        .softCard()
    }

    private func statusChip(for vote: Vote) -> some View {
        Text(vote.status == .confirmed ? "Decided" : "Open")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, PlanrSpacing.sm)
            .padding(.vertical, PlanrSpacing.xs)
            .background(Capsule().fill(vote.status == .confirmed
                                       ? PlanrColor.statusSuccess.opacity(0.15)
                                       : PlanrColor.ember.opacity(0.15)))
            .foregroundStyle(vote.status == .confirmed ? PlanrColor.statusSuccess : PlanrColor.ember)
    }
}
