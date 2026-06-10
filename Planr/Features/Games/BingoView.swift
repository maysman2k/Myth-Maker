import SwiftUI

/// Event Bingo: everyone predicts what will happen, cards get dealt,
/// claims need leader sign-off, first full card wins.
struct BingoView: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    @State private var newPrediction = ""

    var body: some View {
        let event = model.event(withID: eventID)
        let game = model.bingoGame(for: eventID)

        ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                if let game, let event {
                    switch game.status {
                    case .collecting: collectingView(game: game, event: event)
                    case .playing: playingView(game: game, event: event)
                    case .finished: finishedView(game: game)
                    }
                } else if let event {
                    notStartedView(event: event)
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.vertical, PlanrSpacing.lg)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Event Bingo")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Not started

    private func notStartedView(event: Event) -> some View {
        EmptyStateView(symbol: "gamecontroller.fill",
                       title: "Event Bingo",
                       message: "Everyone predicts what'll happen — \"Gary misses the train\", that sort of thing. Cards get dealt, claims need sign-off, first full card wins.",
                       actionLabel: model.role(in: event).canManage ? "Start Bingo" : nil) {
            model.startBingo(for: eventID)
        }
    }

    // MARK: Collecting

    private func collectingView(game: BingoGame, event: Event) -> some View {
        let isManager = model.role(in: event).canManage
        let approvedCount = game.approvedSubmissions.count
        let needed = BingoCardGenerator.defaultCardSize

        return VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
            GlassCard {
                VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
                    Text("Predictions open 🎯")
                        .font(PlanrFont.cardTitle)
                    Text("\(approvedCount) of \(needed)+ approved predictions in the pot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: PlanrSpacing.sm) {
                TextField("Something that will definitely happen…", text: $newPrediction)
                    .textFieldStyle(.roundedBorder)
                Button {
                    model.submitBingoPrediction(newPrediction, eventID: eventID)
                    newPrediction = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newPrediction.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Submit prediction")
            }

            ForEach(game.submissions) { submission in
                HStack(spacing: PlanrSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(submission.text)
                            .font(.subheadline)
                        Text("by \(model.displayName(for: submission.authorID))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isManager {
                        Button {
                            model.setBingoSubmissionApproved(submission, eventID: eventID,
                                                             approved: !submission.approved)
                        } label: {
                            Image(systemName: submission.approved
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(submission.approved
                                                 ? PlanrColor.statusSuccess : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(submission.approved ? "Approved, tap to reject" : "Tap to approve")
                    } else if submission.approved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PlanrColor.statusSuccess)
                    }
                }
                .softCard()
            }

            if isManager {
                Button {
                    model.dealBingoCards(for: event)
                } label: {
                    Label("Deal the cards", systemImage: "rectangle.stack.fill")
                        .font(PlanrFont.cardTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PlanrSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .disabled(approvedCount < BingoCardGenerator.defaultCardSize)
            }
        }
    }

    // MARK: Playing

    private func playingView(game: BingoGame, event: Event) -> some View {
        let isManager = model.role(in: event).canManage
        let myCard = model.currentUser.flatMap { game.card(for: $0.id) }

        return VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
            if let myCard {
                Text("Your card — \(myCard.confirmedCount) of \(myCard.squares.count) ticked")
                    .font(PlanrFont.cardTitle)
                ForEach(myCard.squares) { square in
                    squareRow(square, game: game, isMine: true)
                }
            }

            if isManager {
                pendingClaims(game: game)
            }

            Text("How everyone's doing")
                .font(PlanrFont.cardTitle)
            ForEach(game.cards) { card in
                HStack {
                    AvatarView(profile: model.user(withID: card.ownerID), size: 28)
                    Text(model.displayName(for: card.ownerID))
                        .font(.subheadline)
                    Spacer()
                    Text("\(card.confirmedCount)/\(card.squares.count)")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(card.isComplete ? PlanrColor.statusSuccess : .secondary)
                }
                .softCard()
            }
        }
    }

    private func squareRow(_ square: BingoSquare, game: BingoGame, isMine: Bool) -> some View {
        let text = game.submission(withID: square.submissionID)?.text ?? "Mystery prediction"
        return HStack(spacing: PlanrSpacing.md) {
            Image(systemName: square.confirmed ? "checkmark.seal.fill"
                  : (square.claimedByID != nil ? "hourglass" : "seal"))
                .font(.title3)
                .foregroundStyle(square.confirmed ? PlanrColor.statusSuccess
                                 : (square.claimedByID != nil ? PlanrColor.statusWarning : .secondary))
            Text(text)
                .font(.subheadline)
                .strikethrough(square.confirmed)
            Spacer()
            if isMine && !square.confirmed && square.claimedByID == nil {
                Button("It happened!") {
                    model.claimBingoSquare(square, eventID: eventID)
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.bordered)
            } else if square.claimedByID != nil && !square.confirmed {
                Text("Awaiting sign-off")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .softCard()
    }

    @ViewBuilder
    private func pendingClaims(game: BingoGame) -> some View {
        let pending: [(card: BingoCard, square: BingoSquare)] = game.cards.flatMap { card in
            card.squares.filter { $0.claimedByID != nil && !$0.confirmed }
                .map { (card, $0) }
        }
        if !pending.isEmpty {
            Text("Claims to judge")
                .font(PlanrFont.cardTitle)
            ForEach(pending, id: \.square.id) { item in
                VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                    Text(game.submission(withID: item.square.submissionID)?.text ?? "")
                        .font(.subheadline.weight(.semibold))
                    Text("claimed by \(model.displayName(for: item.square.claimedByID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Approve") {
                            model.resolveBingoClaim(cardOwnerID: item.card.ownerID,
                                                    square: item.square,
                                                    eventID: eventID, approve: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PlanrColor.statusSuccess)
                        Button("Reject") {
                            model.resolveBingoClaim(cardOwnerID: item.card.ownerID,
                                                    square: item.square,
                                                    eventID: eventID, approve: false)
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption.weight(.bold))
                }
                .softCard()
            }
        }
    }

    // MARK: Finished

    private func finishedView(game: BingoGame) -> some View {
        VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
            GlassCard {
                VStack(spacing: PlanrSpacing.sm) {
                    Text("🏆")
                        .font(.system(size: 48))
                    Text(game.winnerID.map { "\(model.displayName(for: $0)) wins!" } ?? "Game over")
                        .font(PlanrFont.screenTitle)
                    Text("Full card. Called every bit of it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            ForEach(game.cards) { card in
                HStack {
                    AvatarView(profile: model.user(withID: card.ownerID), size: 28)
                    Text(model.displayName(for: card.ownerID))
                        .font(.subheadline)
                    Spacer()
                    Text("\(card.confirmedCount)/\(card.squares.count)")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(card.ownerID == game.winnerID
                                         ? PlanrColor.statusSuccess : .secondary)
                }
                .softCard()
            }
        }
    }
}
