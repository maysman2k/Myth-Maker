import SwiftUI
import PhotosUI

// MARK: - Post card

struct CommunityPostCard: View {
    @Environment(AppModel.self) private var model
    var post: CommunityPost
    /// Compact cards (feed) hide the reaction row's labels.
    var showsThreadContext = true

    @State private var isReporting = false

    private var author: UserAccount? { model.account(id: post.userID) }

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            header
            if post.status == .pendingReview {
                TagBadge(text: "Awaiting review", tint: BrickColor.brickRed)
            }
            if let challengeID = post.challengeID, let challenge = model.challenge(challengeID) {
                NavigationLink(value: ContentRoute.challenge(challengeID)) {
                    TagBadge(text: "🏆 \(challenge.title)", tint: BrickColor.gold)
                }
                .buttonStyle(.plain)
            }
            if showsThreadContext, let day = post.threadDay {
                TagBadge(text: "WIP · Day \(day)", tint: BrickColor.stadiumGreen)
            }
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
            }
            imageStrip
            ReactionBar(post: post)
            HStack {
                MetaLabel(symbol: "bubble.left", text: "\(model.commentCount(for: .communityPost, contentID: post.id))")
                Spacer()
                if model.challengeWins(for: post.userID) > 0 {
                    Text("👑")
                        .accessibilityLabel("Challenge winner")
                }
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
        .sheet(isPresented: $isReporting) {
            ReportUserSheet(userID: post.userID, postID: post.id)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: BrickSpacing.s) {
            NavigationLink(value: ContentRoute.builder(post.userID)) {
                HStack(spacing: BrickSpacing.s) {
                    AvatarView(name: author?.displayName ?? "?", imageReference: author?.avatarImageReference, size: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(author?.displayName ?? "Former member")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BrickColor.primaryText)
                        Text(AppDate.relative(post.createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                if post.userID == model.currentUserID || model.currentUser?.role.canModerate == true {
                    Button("Delete post", role: .destructive) { model.deleteCommunityPost(post.id) }
                }
                if post.userID != model.currentUserID {
                    Button("Report", systemImage: "flag") { isReporting = true }
                    Button("Block \(author?.displayName ?? "builder")", systemImage: "hand.raised", role: .destructive) {
                        model.blockUser(post.userID)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(BrickColor.secondaryText)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Post options")
        }
    }

    @ViewBuilder
    private var imageStrip: some View {
        if post.imageReferences.isEmpty {
            BrickArtView(seed: post.id.artSeed, tint: BrickColor.stadiumGreen, symbol: "hammer")
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if post.imageReferences.count == 1, let reference = post.imageReferences.first {
            ArticleImage(reference: reference, mode: .fill)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrickSpacing.s) {
                    ForEach(post.imageReferences, id: \.self) { reference in
                        ArticleImage(reference: reference, mode: .fill)
                            .frame(width: 220, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

// MARK: - Reactions

struct ReactionBar: View {
    @Environment(AppModel.self) private var model
    var post: CommunityPost

    var body: some View {
        let counts = model.reactionCounts(for: post.id)
        let mine = model.myReaction(to: post.id)
        HStack(spacing: BrickSpacing.s) {
            ForEach(BrickReaction.allCases) { reaction in
                Button {
                    model.react(to: post.id, with: reaction)
                } label: {
                    HStack(spacing: 3) {
                        Text(reaction.emoji)
                            .font(.system(size: 15))
                        if let count = counts[reaction], count > 0 {
                            Text("\(count)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background(mine == reaction ? BrickColor.gold.opacity(0.25) : BrickColor.background)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(mine == reaction ? BrickColor.gold : BrickColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(reaction.label): \(counts[reaction] ?? 0)")
            }
            Spacer()
        }
    }
}

// MARK: - Post detail (thread + comments)

struct CommunityPostDetailView: View {
    @Environment(AppModel.self) private var model
    var postID: UUID

    private var post: CommunityPost? { model.communityPost(postID) }

    var body: some View {
        Group {
            if let post, post.status != .removed, !model.isBlocked(post.userID) {
                content(for: post)
            } else {
                EmptyStateView(symbol: "hammer", message: "This post isn't available.")
            }
        }
        .background(BrickColor.background)
        .navigationTitle("Build")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for post: CommunityPost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                let thread = model.threadPosts(for: post)
                if thread.count > 1 {
                    Text("Build diary — \(thread.count) updates")
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    ForEach(thread) { entry in
                        CommunityPostCard(post: entry)
                    }
                } else {
                    CommunityPostCard(post: post)
                }
                Divider()
                CommentsSectionView(contentType: .communityPost, contentID: post.id, prompt: nil)
            }
            .padding(BrickSpacing.l)
        }
    }
}

// MARK: - Composer

struct CommunityComposerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Pre-selects the active challenge when opened from a challenge screen.
    var challengeID: UUID?

    @State private var caption = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var enterChallenge: Bool
    @State private var threadChoice: UUID?
    @State private var startNewThread = false

    init(challengeID: UUID? = nil) {
        self.challengeID = challengeID
        _enterChallenge = State(initialValue: challengeID != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    TextField("What did you build?", text: $caption, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(BrickSpacing.m)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 4, matching: .images) {
                        Label(images.isEmpty ? "Add photos" : "Photos (\(images.count))", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))

                    if !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: BrickSpacing.s) {
                                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    if let challengeID, let challenge = model.challenge(challengeID), challenge.status == .open {
                        Toggle("Enter \"\(challenge.title)\" challenge 🏆", isOn: $enterChallenge)
                            .padding(BrickSpacing.m)
                            .brickCard()
                    } else if let active = model.activeChallenge {
                        Toggle("Enter \"\(active.title)\" challenge 🏆", isOn: $enterChallenge)
                            .padding(BrickSpacing.m)
                            .brickCard()
                    }

                    threadSection

                    Text("Be kind and keep it brick-related — posts that break the community rules get removed.")
                        .font(.system(size: 12))
                        .foregroundStyle(BrickColor.secondaryText)
                }
                .padding(BrickSpacing.l)
            }
            .background(BrickColor.background)
            .navigationTitle("Share a Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { submit() }
                        .disabled(caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: pickedItems) { _, newItems in
                Task {
                    var loaded: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            loaded.append(image)
                        }
                    }
                    images = loaded
                }
            }
        }
    }

    @ViewBuilder
    private var threadSection: some View {
        let openThreads = model.myOpenThreads
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text("Build diary")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Toggle("Start a new build diary (Day 1)", isOn: $startNewThread)
                .disabled(threadChoice != nil)
            if !openThreads.isEmpty {
                ForEach(openThreads) { thread in
                    Button {
                        threadChoice = threadChoice == thread.threadID ? nil : thread.threadID
                        if threadChoice != nil { startNewThread = false }
                    } label: {
                        HStack {
                            Image(systemName: threadChoice == thread.threadID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(BrickColor.gold)
                            Text("Continue: \(thread.caption.prefix(40))… (Day \((thread.threadDay ?? 0) + 1))")
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.primaryText)
                                .lineLimit(1)
                            Spacer()
                        }
                        .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(BrickSpacing.m)
        .brickCard()
    }

    private func submit() {
        let references = images.compactMap { ImageStore.save($0) }.map { "local-image://\($0)" }
        let selectedChallenge = enterChallenge ? (challengeID ?? model.activeChallenge?.id) : nil
        model.createCommunityPost(
            caption: caption,
            imageReferences: references,
            challengeID: selectedChallenge,
            continueThread: threadChoice,
            startThread: startNewThread
        )
        dismiss()
    }
}

// MARK: - Report sheet

struct ReportUserSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var userID: UUID
    var postID: UUID?

    @State private var reason: ReportReason = .spam
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What's wrong?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Anything else? (optional)") {
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        model.reportUser(userID, postID: postID, reason: reason, details: details)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
