import SwiftUI
import PhotosUI

// MARK: - Poll card (Today + admin)

struct PollHighlightCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let poll = model.openPolls.first {
            PollCard(poll: poll)
        }
    }
}

struct PollCard: View {
    @Environment(AppModel.self) private var model
    var poll: Poll

    var body: some View {
        let myVote = model.myPollVote(poll.id)
        let results = model.pollResults(poll)
        let totalVotes = results.reduce(0) { $0 + $1.votes }
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text("📊 COMMUNITY POLL")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(BrickColor.gold)
            Text(poll.question)
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            ForEach(results, id: \.option.id) { result in
                Button {
                    model.votePoll(poll.id, optionID: result.option.id)
                } label: {
                    HStack {
                        Text(result.option.label)
                            .font(.system(size: 14, weight: myVote == result.option.id ? .bold : .regular))
                            .foregroundStyle(BrickColor.primaryText)
                        Spacer()
                        if myVote != nil {
                            Text("\(Int((result.share * 100).rounded()))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                        if myVote == result.option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BrickColor.gold)
                        }
                    }
                    .padding(BrickSpacing.m)
                    .frame(minHeight: 42)
                    .background(alignment: .leading) {
                        if myVote != nil {
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(BrickColor.gold.opacity(myVote == result.option.id ? 0.28 : 0.12))
                                    .frame(width: proxy.size.width * result.share)
                            }
                        }
                    }
                    .background(BrickColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(BrickColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(poll.status == .closed)
            }
            Text(myVote == nil ? "Tap to vote — results show after" : "\(totalVotes) vote\(totalVotes == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(BrickColor.secondaryText)
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

struct AdminPollView: View {
    @Environment(AppModel.self) private var model
    @State private var question = ""
    @State private var options = ["", ""]

    var body: some View {
        Form {
            Section("New poll") {
                TextField("Question (e.g. Which stadium next?)", text: $question)
                ForEach(options.indices, id: \.self) { index in
                    TextField("Option \(index + 1)", text: $options[index])
                }
                if options.count < 4 {
                    Button("Add option") { options.append("") }
                }
                Button("Launch poll") {
                    model.createPoll(question: question, optionLabels: options)
                    question = ""
                    options = ["", ""]
                }
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count < 2)
            }
            Section("All polls") {
                ForEach(model.polls.sorted { $0.createdAt > $1.createdAt }) { poll in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(poll.question)
                            .font(.system(size: 15, weight: .semibold))
                        HStack {
                            TagBadge(text: poll.status == .open ? "Open" : "Closed", tint: poll.status == .open ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                            Spacer()
                            if poll.status == .open {
                                Button("Close") { model.closePoll(poll.id) }
                                    .font(BrickFont.meta)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Polls")
    }
}

// MARK: - Leaderboard

struct LeaderboardHighlightCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let champion = model.weeklyChampion {
            NavigationLink {
                LeaderboardView()
            } label: {
                HStack(spacing: BrickSpacing.m) {
                    Text("🥇")
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(champion.displayName) leads \(champion.game.displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BrickColor.primaryText)
                        Text("Score \(champion.score) · resets Monday — think you can beat it?")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BrickColor.secondaryText)
                }
                .padding(BrickSpacing.l)
                .brickCard()
            }
            .buttonStyle(.plain)
        }
    }
}

struct LeaderboardView: View {
    @Environment(AppModel.self) private var model
    @State private var game: GameKind = .brickStack

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("Weekly leaderboards — top scores reset every Monday.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.s) {
                        ForEach(GameKind.allCases) { candidate in
                            FilterChip(title: candidate.displayName, isSelected: game == candidate) {
                                game = candidate
                            }
                        }
                    }
                }
                let entries = model.weeklyLeaderboard(for: game)
                if entries.isEmpty {
                    EmptyStateView(
                        symbol: "trophy",
                        message: "No scores yet this week. Play \(game.displayName) and put your name up first.",
                        actionTitle: "Play now",
                        action: { model.selectedTab = .games }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: BrickSpacing.m) {
                                Text(medal(for: index))
                                    .font(.system(size: 18))
                                    .frame(width: 34)
                                NavigationLink(value: ContentRoute.builder(entry.userID)) {
                                    Text(entry.displayName)
                                        .font(.system(size: 15, weight: index == 0 ? .bold : .medium))
                                        .foregroundStyle(BrickColor.primaryText)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text("\(entry.score)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(index == 0 ? BrickColor.gold : BrickColor.primaryText)
                            }
                            .padding(BrickSpacing.m)
                            if entry.id != entries.last?.id { Divider() }
                        }
                    }
                    .brickCard()
                }
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Leaderboards")
        .contentRouteDestinations()
    }

    private func medal(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(index + 1)."
        }
    }
}

// MARK: - My Shelf

struct MyShelfView: View {
    @Environment(AppModel.self) private var model
    @State private var pickedItem: PhotosPickerItem?
    @State private var shareImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("Your display shelf — show off the collection. Photos appear on your public builder profile.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Add a shelfie", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.gold))

                let items = model.currentUserID.map { model.shelf(for: $0) } ?? []
                if items.isEmpty {
                    EmptyStateView(symbol: "square.grid.2x2", message: "Nothing on the shelf yet. Snap your display and start the collection.")
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                ArticleImage(reference: item.imageReference, mode: .fill)
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                if !item.caption.isEmpty {
                                    Text(item.caption)
                                        .font(BrickFont.meta)
                                        .foregroundStyle(BrickColor.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            .contextMenu {
                                Button("Share with BIAB frame", systemImage: "square.and.arrow.up") {
                                    shareImage = ShelfShareRenderer.render(item: item, builderName: model.currentUser?.displayName ?? "")
                                }
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    model.removeShelfItem(item.id)
                                }
                            }
                        }
                    }
                    Text("Long-press a photo to share it with the Bricks in a Bag frame — perfect for Instagram.")
                        .font(.system(size: 12))
                        .foregroundStyle(BrickColor.secondaryText)
                }
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("My Shelf")
        .onChange(of: pickedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let filename = ImageStore.save(image) {
                    model.addShelfItem(imageReference: "local-image://\(filename)", caption: "")
                }
                pickedItem = nil
            }
        }
        .sheet(item: Binding(
            get: { shareImage.map(ShareableImage.init) },
            set: { _ in shareImage = nil }
        )) { wrapper in
            ShareSheet(items: [wrapper.image])
        }
    }
}

private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Renders a shelf photo inside a branded square frame for sharing out —
/// the reverse direction of the Instagram carousel: users marketing BIAB.
enum ShelfShareRenderer {
    static func render(item: ShelfItem, builderName: String) -> UIImage? {
        let filename = item.imageReference.replacingOccurrences(of: "local-image://", with: "")
        guard let photo = ImageStore.load(filename) else { return nil }
        let side: CGFloat = 1080
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            UIColor(hex: 0x101010).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            // Photo, aspect-filled into the frame area.
            let inset: CGFloat = 54
            let photoRect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2 - 90)
            context.cgContext.saveGState()
            let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 28)
            path.addClip()
            let scale = max(photoRect.width / photo.size.width, photoRect.height / photo.size.height)
            let drawSize = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            photo.draw(in: CGRect(
                x: photoRect.midX - drawSize.width / 2,
                y: photoRect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
            context.cgContext.restoreGState()
            // Caption bar.
            let brand = "BRICKS IN A BAG"
            let name = builderName.isEmpty ? "My shelf" : "\(builderName)'s shelf"
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor(hex: 0xC8A45D),
                .kern: 4
            ]
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let brandSize = brand.size(withAttributes: brandAttributes)
            brand.draw(at: CGPoint(x: inset, y: side - 84), withAttributes: brandAttributes)
            name.draw(at: CGPoint(x: inset + brandSize.width + 24, y: side - 78), withAttributes: nameAttributes)
        }
    }
}

// MARK: - Community builds section (Today)

struct CommunityBuildsSection: View {
    @Environment(AppModel.self) private var model
    @State private var isComposing = false
    @State private var composerKind: CommunityPostKind?
    @State private var showFollowedOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack {
                Text("Community builds")
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                if model.isSignedIn, !model.followedCommunityPosts.isEmpty || showFollowedOnly {
                    FilterChip(title: "Following", isSelected: showFollowedOnly) {
                        showFollowedOnly.toggle()
                    }
                }
                Button {
                    if model.requireAccount() { isComposing = true }
                } label: {
                    Label("Share", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrickColor.gold)
                }
                .accessibilityLabel("Share a build")
            }
            let posts = showFollowedOnly ? model.followedCommunityPosts : model.visibleCommunityPosts
            if posts.isEmpty {
                EmptyStateView(
                    symbol: "hammer",
                    message: showFollowedOnly
                        ? "Nothing from builders you follow yet."
                        : "No builds shared yet. Got something on the desk? Show it off.",
                    actionTitle: "Share a build",
                    action: { if model.requireAccount() { isComposing = true } }
                )
            } else {
                ForEach(posts.prefix(10)) { post in
                    NavigationLink(value: ContentRoute.communityPost(post.id)) {
                        CommunityPostCard(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $isComposing) {
            PostTypePickerSheet { kind in
                composerKind = kind
            }
        }
        .sheet(item: $composerKind) { kind in
            CommunityComposerSheet(kind: kind)
        }
    }
}

// MARK: - Blocked users (Settings)

struct BlockedUsersView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            let blockedIDs = Array(model.myBlockedUserIDs)
            if blockedIDs.isEmpty {
                Text("You haven't blocked anyone. Blocked builders' posts and comments disappear from your feeds.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            } else {
                ForEach(blockedIDs, id: \.self) { userID in
                    HStack {
                        Text(model.displayName(for: userID))
                        Spacer()
                        Button("Unblock") { model.unblockUser(userID) }
                            .foregroundStyle(BrickColor.gold)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
    }
}
