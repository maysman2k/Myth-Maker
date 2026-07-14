import SwiftUI
import PhotosUI

// MARK: - Post card

struct CommunityPostCard: View {
    @Environment(AppModel.self) private var model
    var post: CommunityPost
    /// Compact cards (feed) hide the reaction row's labels.
    var showsThreadContext = true

    @State private var isReporting = false
    @State private var isEditingBackers = false
    @State private var backerText = ""

    private var author: UserAccount? { model.account(id: post.userID) }

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            header
            if post.status == .pendingReview {
                TagBadge(text: "Awaiting review", tint: BrickColor.brickRed)
            }
            if post.kind != .standard {
                TagBadge(text: post.kind.label, tint: post.kind == .event ? BrickColor.stadiumGreen : BrickColor.gold)
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
            if !post.title.isEmpty {
                Text(post.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
            }
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
            }
            kindDetails
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
        .alert("Update backer count", isPresented: $isEditingBackers) {
            TextField("Backers", text: $backerText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let count = Int(backerText) {
                    model.updateBackerCount(post.id, to: count)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How many backers does the campaign have now?")
        }
    }

    /// Event and LEGO® Ideas posts carry extra structured info.
    @ViewBuilder
    private var kindDetails: some View {
        switch post.kind {
        case .standard:
            EmptyView()
        case .event:
            VStack(alignment: .leading, spacing: 4) {
                if let date = post.eventDate {
                    Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrickColor.stadiumGreen)
                }
                if let location = post.eventLocation, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
            }
            .padding(BrickSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrickColor.stadiumGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        case .ideas:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("\((post.backerCount ?? 0).formatted()) backers", systemImage: "person.3.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BrickColor.gold)
                    Spacer()
                    if let endDate = post.ideasEndDate {
                        let days = max(0, Int(endDate.timeIntervalSince(Date()) / 86_400))
                        TagBadge(
                            text: endDate < Date() ? "Campaign ended" : (days == 0 ? "Ends today!" : "\(days) day\(days == 1 ? "" : "s") left"),
                            tint: endDate < Date() ? BrickColor.secondaryText : BrickColor.brickRed
                        )
                    }
                }
                if post.userID == model.currentUserID {
                    Button {
                        backerText = "\(post.backerCount ?? 0)"
                        isEditingBackers = true
                    } label: {
                        Label("Update backers", systemImage: "plus.forwardslash.minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BrickColor.gold)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BrickSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrickColor.gold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .background { BrickScreenBackground() }
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
                    ForEach(Array(thread.enumerated()), id: \.element.id) { index, entry in
                        CommunityPostCard(post: entry)
                            .cardAppear(index)
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

// MARK: - Post type picker ("what do you want to put on?")

struct PostTypePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (CommunityPostKind) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: BrickSpacing.m) {
                ForEach(Array(CommunityPostKind.allCases.enumerated()), id: \.element) { index, kind in
                    Button {
                        dismiss()
                        onPick(kind)
                    } label: {
                        HStack(spacing: BrickSpacing.m) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 22))
                                .foregroundStyle(BrickColor.gold)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(BrickColor.gold.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.pickerTitle)
                                    .font(BrickFont.cardTitle)
                                    .foregroundStyle(BrickColor.primaryText)
                                Text(kind.pickerDetail)
                                    .font(BrickFont.meta)
                                    .foregroundStyle(BrickColor.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                        .padding(BrickSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .brickCard()
                    }
                    .buttonStyle(PressableStyle())
                    .cardAppear(index)
                }
                Spacer()
            }
            .padding(BrickSpacing.l)
            .navigationTitle("Create a Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(28)
    }
}

// MARK: - Composer

struct CommunityComposerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var kind: CommunityPostKind
    /// Pre-selects the active challenge when opened from a challenge screen.
    var challengeID: UUID?

    @State private var title = ""
    @State private var caption = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var enterChallenge: Bool
    @State private var threadChoice: UUID?
    @State private var startNewThread = false
    @State private var eventDate = Date().addingTimeInterval(7 * 86_400)
    @State private var eventLocation = ""
    @State private var ideasEndDate = Date().addingTimeInterval(30 * 86_400)
    @State private var backerText = ""

    init(kind: CommunityPostKind = .standard, challengeID: UUID? = nil) {
        self.kind = kind
        self.challengeID = challengeID
        _enterChallenge = State(initialValue: challengeID != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    TextField(titlePlaceholder, text: $title)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(BrickSpacing.m)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                    TextField(captionPlaceholder, text: $caption, axis: .vertical)
                        .lineLimit(4...10)
                        .padding(BrickSpacing.m)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                    if kind == .event {
                        VStack(alignment: .leading, spacing: BrickSpacing.s) {
                            DatePicker("When is it?", selection: $eventDate, in: Date()...)
                            TextField("Where? (optional)", text: $eventLocation)
                                .padding(BrickSpacing.m)
                                .background(BrickColor.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(BrickSpacing.m)
                        .brickCard()
                    }

                    if kind == .ideas {
                        VStack(alignment: .leading, spacing: BrickSpacing.s) {
                            DatePicker("Campaign ends", selection: $ideasEndDate, in: Date()..., displayedComponents: .date)
                            HStack {
                                Text("Current backers")
                                    .foregroundStyle(BrickColor.primaryText)
                                Spacer()
                                TextField("0", text: $backerText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                                    .padding(8)
                                    .background(BrickColor.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text("You can update the backer count from the post any time it changes.")
                                .font(.system(size: 12))
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                        .padding(BrickSpacing.m)
                        .brickCard()
                    }

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

                    if kind == .standard {
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
                    }

                    Text("Be kind and keep it brick-related — posts that break the community rules get removed.")
                        .font(.system(size: 12))
                        .foregroundStyle(BrickColor.secondaryText)
                }
                .padding(BrickSpacing.l)
            }
            .background { BrickScreenBackground() }
            .navigationTitle(kind == .standard ? "Share a Build" : (kind == .event ? "Add an Event" : "LEGO® Ideas Post"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { submit() }
                        .disabled(!canSubmit)
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

    private var titlePlaceholder: String {
        switch kind {
        case .standard: return "Title (e.g. Elland Road, Day 3)"
        case .event: return "Event name (e.g. Yorkshire Brick Show)"
        case .ideas: return "Ideas project name"
        }
    }

    private var captionPlaceholder: String {
        switch kind {
        case .standard: return "The write-up — what did you build?"
        case .event: return "What's happening, who's it for, tickets…"
        case .ideas: return "Tell everyone about the project and why they should back it"
        }
    }

    private var canSubmit: Bool {
        let hasContent = !title.trimmingCharacters(in: .whitespaces).isEmpty ||
            !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !images.isEmpty
        switch kind {
        case .standard: return hasContent
        // Events and Ideas posts need a name so the feed cards read properly.
        case .event, .ideas: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func submit() {
        let references = images.compactMap { ImageStore.save($0) }.map { "local-image://\($0)" }
        let selectedChallenge = (kind == .standard && enterChallenge) ? (challengeID ?? model.activeChallenge?.id) : nil
        model.createCommunityPost(
            title: title,
            caption: caption,
            imageReferences: references,
            kind: kind,
            eventDate: eventDate,
            eventLocation: eventLocation.isEmpty ? nil : eventLocation,
            ideasEndDate: ideasEndDate,
            backerCount: Int(backerText) ?? 0,
            challengeID: selectedChallenge,
            continueThread: kind == .standard ? threadChoice : nil,
            startThread: kind == .standard && startNewThread
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
