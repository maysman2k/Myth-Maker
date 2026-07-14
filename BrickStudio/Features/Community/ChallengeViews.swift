import SwiftUI

// MARK: - Today card

/// Compact Weekly Build Challenge card for the Today feed. Self-contained:
/// pulls everything from the environment.
struct ChallengeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let challenge = model.activeChallenge ?? model.votingChallenge {
            NavigationLink(value: ContentRoute.challenge(challenge.id)) {
                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    HStack {
                        Text("🏆 Weekly Build Challenge")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(BrickColor.gold)
                        Spacer()
                        TagBadge(
                            text: challenge.status == .voting ? "Voting open" : timeLeftLabel(challenge),
                            tint: challenge.status == .voting ? BrickColor.stadiumGreen : BrickColor.brickRed
                        )
                    }
                    Text(challenge.title)
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    Text(challenge.prompt)
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack {
                        MetaLabel(symbol: "person.3", text: "\(model.entries(for: challenge.id).count) entries")
                        Spacer()
                        Text(challenge.status == .voting ? "Vote now →" : "Enter →")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BrickColor.gold)
                    }
                }
                .padding(BrickSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brickCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func timeLeftLabel(_ challenge: BuildChallenge) -> String {
        let days = max(0, Int(challenge.votingAt.timeIntervalSince(Date()) / 86_400))
        return days == 0 ? "Last day!" : "\(days) day\(days == 1 ? "" : "s") left"
    }
}

// MARK: - Detail

struct ChallengeDetailView: View {
    @Environment(AppModel.self) private var model
    var challengeID: UUID

    @State private var isComposing = false

    private var challenge: BuildChallenge? { model.challenge(challengeID) }

    var body: some View {
        Group {
            if let challenge {
                content(for: challenge)
            } else {
                EmptyStateView(symbol: "trophy", message: "This challenge isn't available.")
            }
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Build Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isComposing) {
            CommunityComposerSheet(challengeID: challengeID)
        }
    }

    private func content(for challenge: BuildChallenge) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    HStack {
                        Text("🏆")
                            .font(.system(size: 34))
                        Spacer()
                        statusBadge(for: challenge)
                    }
                    Text(challenge.title)
                        .font(BrickFont.pageTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    Text(challenge.prompt)
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.secondaryText)
                    timeline(for: challenge)
                }
                .padding(BrickSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brickCard()

                if challenge.status == .open {
                    Button {
                        if model.requireAccount() { isComposing = true }
                    } label: {
                        Text("Enter Your Build")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold))
                }

                if let winnerID = challenge.winnerPostID, let winner = model.communityPost(winnerID) {
                    VStack(alignment: .leading, spacing: BrickSpacing.m) {
                        SectionHeader(title: "👑 Winner")
                        NavigationLink(value: ContentRoute.communityPost(winner.id)) {
                            CommunityPostCard(post: winner)
                        }
                        .buttonStyle(.plain)
                    }
                }

                entriesSection(for: challenge)

                if model.currentUser?.role.canEditContent == true, challenge.status != .finished {
                    Button {
                        model.advanceChallenge(challenge.id)
                    } label: {
                        Text(challenge.status == .open ? "Admin: Open Voting" : "Admin: Crown the Winner")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                }
            }
            .padding(BrickSpacing.l)
        }
    }

    private func statusBadge(for challenge: BuildChallenge) -> some View {
        switch challenge.status {
        case .upcoming: return TagBadge(text: "Coming soon", tint: BrickColor.secondaryText)
        case .open: return TagBadge(text: "Open for entries", tint: BrickColor.stadiumGreen)
        case .voting: return TagBadge(text: "Voting open", tint: BrickColor.gold)
        case .finished: return TagBadge(text: "Finished", tint: BrickColor.secondaryText)
        }
    }

    private func timeline(for challenge: BuildChallenge) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(symbol: "hammer", text: "Entries until \(AppDate.medium(challenge.votingAt))")
            MetaLabel(symbol: "checkmark.seal", text: "Voting until \(AppDate.medium(challenge.endsAt))")
        }
    }

    @ViewBuilder
    private func entriesSection(for challenge: BuildChallenge) -> some View {
        let entries = model.entries(for: challenge.id)
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            SectionHeader(title: "Entries (\(entries.count))")
            if entries.isEmpty {
                Text("No entries yet — be the first on the podium.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    NavigationLink(value: ContentRoute.communityPost(entry.id)) {
                        CommunityPostCard(post: entry, showsThreadContext: false)
                    }
                    .buttonStyle(.plain)
                    if challenge.status == .voting {
                        voteRow(for: entry, in: challenge)
                    } else if challenge.status == .finished {
                        MetaLabel(symbol: "checkmark.seal", text: "\(model.voteCount(for: entry.id, in: challenge.id)) vote\(model.voteCount(for: entry.id, in: challenge.id) == 1 ? "" : "s")")
                    }
                }
                .cardAppear(index)
            }
        }
    }

    private func voteRow(for entry: CommunityPost, in challenge: BuildChallenge) -> some View {
        let votes = model.voteCount(for: entry.id, in: challenge.id)
        let isMyVote = model.myChallengeVote(in: challenge.id) == entry.id
        return HStack {
            Button {
                model.voteForEntry(entry.id, in: challenge.id)
            } label: {
                Label(isMyVote ? "Your vote ✓" : "Vote for this build", systemImage: isMyVote ? "checkmark.seal.fill" : "hand.thumbsup")
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: isMyVote))
            Spacer()
            Text("\(votes) vote\(votes == 1 ? "" : "s")")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
    }
}

// MARK: - Admin creation

struct AdminChallengeView: View {
    @Environment(AppModel.self) private var model
    @State private var title = ""
    @State private var prompt = ""
    @State private var daysOpen = 5
    @State private var votingDays = 2

    var body: some View {
        Form {
            Section("New challenge") {
                TextField("Title (e.g. Terrace Heroes)", text: $title)
                TextField("The brief builders see", text: $prompt, axis: .vertical)
                    .lineLimit(2...4)
                Stepper("Entries open: \(daysOpen) days", value: $daysOpen, in: 1...14)
                Stepper("Voting: \(votingDays) days", value: $votingDays, in: 1...7)
                Button("Launch challenge") {
                    model.createChallenge(title: title, prompt: prompt, daysOpen: daysOpen, votingDays: votingDays)
                    title = ""
                    prompt = ""
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("All challenges") {
                ForEach(model.challenges.sorted { $0.createdAt > $1.createdAt }) { challenge in
                    NavigationLink {
                        ChallengeDetailView(challengeID: challenge.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(challenge.status.rawValue.capitalized) · \(model.entries(for: challenge.id).count) entries")
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle("Challenges")
    }
}
