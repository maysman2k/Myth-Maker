import SwiftUI

/// In-app admin area (§22), available to moderators, editors and admins.
/// Editors/admins manage content and the AI draft queue; moderators handle
/// comments. Never visible to normal users.
struct AdminPanelView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingTokenSheet = false

    var body: some View {
        Group {
            // Tiered access (§7.5–7.7): moderators handle comments, editors
            // manage content and the AI queue, admins see everything.
            if let user = model.currentUser, user.role.canModerate {
                content(for: user)
            } else {
                EmptyStateView(symbol: "lock", message: "This area is for the Bricks in a Bag team.")
            }
        }
        .background(BrickColor.background)
        .navigationTitle("Admin")
    }

    private func content(for user: UserAccount) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                statsGrid
                VStack(spacing: 0) {
                    if user.role.canEditContent {
                        adminLink("Create Story", symbol: "square.and.pencil", badge: 0) {
                            AdminStoryEditorView()
                        }
                        adminLink("AI Draft Queue", symbol: "sparkles", badge: model.adminStats.pendingDrafts) {
                            AIDraftQueueView()
                        }
                        adminLink("Articles", symbol: "newspaper", badge: 0) {
                            AdminArticlesView()
                        }
                        adminLink("Submitted Stories", symbol: "tray.and.arrow.down", badge: model.pendingSubmittedStories.count) {
                            AdminSubmittedStoriesView()
                        }
                        adminLink("Products", symbol: "bag", badge: 0) {
                            AdminProductsView()
                        }
                    }
                    adminLink("Comment moderation", symbol: "bubble.left.and.exclamationmark.bubble.right", badge: model.adminStats.pendingComments) {
                        AdminCommentsView()
                    }
                    if user.role.isAdmin {
                        adminLink("Brick Bar requests", symbol: "wrench.and.screwdriver", badge: model.adminStats.openRequests) {
                            AdminRequestsView()
                        }
                    }
                }
                .brickCard()

                if user.role.isAdmin {
                    integrationsCard
                }

                Text("AI drafts never publish automatically — everything below needs a human decision.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(BrickSpacing.l)
        }
        .sheet(isPresented: $isShowingTokenSheet) {
            GitHubTokenSheet(onSaved: nil)
                .presentationDetents([.large])
        }
    }

    /// Integration settings (news sources, GitHub, OpenAI) — admin only,
    /// per §7.7 (admins manage the AI source list and system settings).
    private var integrationsCard: some View {
        VStack(spacing: 0) {
                    adminLink("News sources", symbol: "antenna.radiowaves.left.and.right", badge: 0) {
                        AdminSourcesView()
                    }
                    Button {
                        isShowingTokenSheet = true
                    } label: {
                        HStack(spacing: BrickSpacing.m) {
                            Image(systemName: "key.horizontal")
                                .foregroundStyle(BrickColor.gold)
                                .frame(width: 28)
                            Text("GitHub connection")
                                .font(BrickFont.body)
                                .foregroundStyle(BrickColor.primaryText)
                            Spacer()
                            TagBadge(
                                text: KeychainStore.load(GitHubWorkflowService.tokenKeychainKey)?.isEmpty == false ? "Token saved" : "Not set up",
                                tint: KeychainStore.load(GitHubWorkflowService.tokenKeychainKey)?.isEmpty == false ? BrickColor.stadiumGreen : BrickColor.brickRed
                            )
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                        .padding(BrickSpacing.l)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        OpenAIKeySheet()
                    } label: {
                        HStack(spacing: BrickSpacing.m) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(BrickColor.gold)
                                .frame(width: 28)
                            Text("OpenAI connection")
                                .font(BrickFont.body)
                                .foregroundStyle(BrickColor.primaryText)
                            Spacer()
                            TagBadge(
                                text: KeychainStore.load(OpenAIStoryService.apiKeychainKey)?.isEmpty == false ? "Key saved" : "Not set up",
                                tint: KeychainStore.load(OpenAIStoryService.apiKeychainKey)?.isEmpty == false ? BrickColor.stadiumGreen : BrickColor.brickRed
                            )
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundStyle(BrickColor.secondaryText)
                        }
                        .padding(BrickSpacing.l)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
        }
        .brickCard()
    }

    private var statsGrid: some View {
        let stats = model.adminStats
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
            statCard("\(stats.totalUsers)", "Users")
            statCard("\(stats.articlesPublished)", "Articles live")
            statCard("\(stats.commentsPosted)", "Comments")
            statCard("\(stats.pendingDrafts)", "AI drafts")
            statCard("\(stats.pendingComments)", "To moderate")
            statCard("\(stats.openRequests)", "Open requests")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(BrickColor.primaryText)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(BrickColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .brickCard()
    }

    private func adminLink<Destination: View>(_ title: String, symbol: String, badge: Int, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: BrickSpacing.m) {
                Image(systemName: symbol)
                    .foregroundStyle(BrickColor.gold)
                    .frame(width: 28)
                Text(title)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(BrickColor.brickRed))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(BrickSpacing.l)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Draft Queue (§22.5)

struct AIDraftQueueView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingTokenSheet = false

    private var pending: [AIDraft] {
        model.aiDrafts.filter { $0.status == .needsReview }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if model.isScannerRunning {
                    HStack(spacing: BrickSpacing.m) {
                        ProgressView()
                        Text("Scanner running on GitHub — fresh drafts usually land in 2–4 minutes.")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }
                if pending.isEmpty {
                    if model.isScannerRunning {
                        EmptyStateView(
                            symbol: "sparkles",
                            message: "The queue is clear — the scanner is out looking for stories right now."
                        )
                    } else {
                        EmptyStateView(
                            symbol: "sparkles",
                            message: "The queue is clear. New drafts appear here when the scanner finds relevant stories.",
                            actionTitle: "Run scanner now",
                            action: { startScannerRun() }
                        )
                    }
                } else {
                    ForEach(pending) { draft in
                        NavigationLink {
                            AIDraftDetailView(draftID: draft.id)
                        } label: {
                            draftCard(draft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("AI Draft Queue")
        .refreshable { await model.refreshAIDrafts() }
        .task { await model.refreshAIDrafts() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startScannerRun()
                } label: {
                    if model.isScannerRunning {
                        ProgressView()
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                }
                .disabled(model.isScannerRunning)
                .accessibilityLabel("Run the news scanner now")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshAIDrafts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Check for new drafts")
            }
        }
        .sheet(isPresented: $isShowingTokenSheet) {
            GitHubTokenSheet(onSaved: {
                startScannerRun()
            })
            .presentationDetents([.large])
        }
    }

    /// Kick off a manual run; prompts for the GitHub token on first use.
    private func startScannerRun() {
        if KeychainStore.load(GitHubWorkflowService.tokenKeychainKey)?.isEmpty == false {
            Task { await model.runScannerNow() }
        } else {
            isShowingTokenSheet = true
        }
    }

    private func draftCard(_ draft: AIDraft) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                TagBadge(text: draft.category.rawValue)
                if draft.isRumour { RumourBadge() }
                Spacer()
                TagBadge(
                    text: "Relevance \(draft.relevanceScore) · \(draft.relevanceBand)",
                    tint: draft.relevanceScore > 80 ? BrickColor.stadiumGreen : BrickColor.gold
                )
            }
            Text(draft.title)
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
                .multilineTextAlignment(.leading)
            Text(draft.summary)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            MetaLabel(symbol: "clock", text: "Found \(AppDate.relative(draft.foundAt))")
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

struct AIDraftDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var draftID: UUID
    @State private var selectedImageURLs: [String] = []
    @State private var hasInitialisedSelection = false

    private var draft: AIDraft? {
        model.aiDrafts.first { $0.id == draftID }
    }

    var body: some View {
        Group {
            if let draft {
                content(for: draft)
            } else {
                EmptyStateView(symbol: "sparkles", message: "This draft is no longer in the queue.")
            }
        }
        .background(BrickColor.background)
        .navigationTitle("Review Draft")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for draft: AIDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                HStack {
                    TagBadge(text: draft.category.rawValue)
                    if draft.isRumour { RumourBadge() }
                    Spacer()
                    TagBadge(text: "Relevance \(draft.relevanceScore)")
                }
                Text(draft.title)
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Text(draft.summary)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BrickColor.secondaryText)

                VStack(alignment: .leading, spacing: BrickSpacing.s) {
                    Text("Risk notes")
                        .font(BrickFont.cardTitle)
                        .foregroundStyle(BrickColor.brickRed)
                    Text(draft.riskNotes)
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
                .padding(BrickSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrickColor.brickRed.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                MarkdownBody(markdown: draft.bodyMarkdown)

                if !draft.sourceLinks.isEmpty {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text("Sources")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        ForEach(draft.sourceLinks) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    Label(source.name, systemImage: "link")
                                        .font(BrickFont.meta)
                                        .foregroundStyle(BrickColor.gold)
                                }
                            }
                        }
                    }
                }

                imagePicker(for: draft)

                HStack(spacing: BrickSpacing.m) {
                    Button {
                        model.approveAIDraft(draft.id, imageURLs: selectedImageURLs)
                        dismiss()
                    } label: {
                        Text("Approve & Publish")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen))

                    Button {
                        model.rejectAIDraft(draft.id)
                        dismiss()
                    } label: {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                }
            }
            .padding(BrickSpacing.l)
        }
    }

    /// Scraped image candidates from the scanner. All are pre-selected —
    /// the editor unticks anything unwanted or off-brand. The first ticked
    /// image becomes the banner; the rest fill the in-article gallery.
    /// The licence warning stays in view (§10.8) since the editor signs
    /// off image rights as part of approval.
    @ViewBuilder
    private func imagePicker(for draft: AIDraft) -> some View {
        if let urls = draft.suggestedImageURLs, !urls.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                Text("Article images (\(selectedImageURLs.count) of \(urls.count) selected)")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Label("Scraped from the source page — licence unknown. Untick anything you don't have rights to use. First ticked image is the banner; untick all for the branded graphic.", systemImage: "exclamationmark.triangle")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.brickRed)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.s) {
                        ForEach(urls, id: \.self) { urlString in
                            imageOption(urlString, allURLs: urls)
                        }
                        noImageOption
                    }
                }
            }
            .padding(BrickSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brickCard()
            .onAppear {
                if !hasInitialisedSelection {
                    hasInitialisedSelection = true
                    selectedImageURLs = urls
                }
            }
        }
    }

    private var noImageOption: some View {
        Button {
            selectedImageURLs = []
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(BrickColor.gold)
                Text("Branded\ngraphic only")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BrickColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 110, height: 84)
            .background(BrickColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selectedImageURLs.isEmpty ? BrickColor.gold : BrickColor.border, lineWidth: selectedImageURLs.isEmpty ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use branded graphic instead of photos")
    }

    private func imageOption(_ urlString: String, allURLs: [String]) -> some View {
        let isSelected = selectedImageURLs.contains(urlString)
        let isHero = selectedImageURLs.first == urlString
        return Button {
            if isSelected {
                selectedImageURLs.removeAll { $0 == urlString }
            } else {
                // Keep suggestion order stable regardless of tap order.
                selectedImageURLs = allURLs.filter { selectedImageURLs.contains($0) || $0 == urlString }
            }
        } label: {
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(BrickColor.secondaryText)
                default:
                    ProgressView()
                }
            }
            .frame(width: 110, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isSelected ? 1 : 0.45)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? BrickColor.gold : BrickColor.border, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? BrickColor.gold : .white)
                    .background(Circle().fill(isSelected ? .white : Color.black.opacity(0.3)))
                    .padding(4)
            }
            .overlay(alignment: .bottomLeading) {
                if isHero {
                    Text("Banner")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(BrickColor.gold))
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Deselect this image" : "Select this image")
    }
}

// MARK: - Comment moderation

struct AdminCommentsView: View {
    @Environment(AppModel.self) private var model

    private var pending: [Comment] {
        model.comments
            .filter { $0.status == .pendingReview || $0.status == .hidden }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if pending.isEmpty {
                    EmptyStateView(symbol: "checkmark.bubble", message: "Nothing waiting for moderation. Lovely.")
                } else {
                    ForEach(pending) { comment in
                        moderationCard(for: comment)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Moderation")
    }

    private func moderationCard(for comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                AvatarView(name: model.displayName(for: comment.userID), imageReference: model.account(id: comment.userID)?.avatarImageReference, size: 26)
                Text(model.displayName(for: comment.userID))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                TagBadge(
                    text: comment.status == .pendingReview ? "Pending" : "Hidden",
                    tint: BrickColor.brickRed
                )
            }
            Text(comment.body)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.primaryText)
            if comment.reportCount > 0 {
                MetaLabel(symbol: "flag", text: "\(comment.reportCount) report\(comment.reportCount == 1 ? "" : "s")")
            }
            let reasons = model.commentReports.filter { $0.commentID == comment.id }.map(\.reason.rawValue)
            if !reasons.isEmpty {
                Text("Reported for: \(Set(reasons).sorted().joined(separator: ", "))")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            HStack(spacing: BrickSpacing.m) {
                Button("Approve") { model.setCommentStatus(comment.id, status: .visible) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: false))
                Button("Hide") { model.setCommentStatus(comment.id, status: .hidden) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                Button("Delete") { model.setCommentStatus(comment.id, status: .deleted) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

// MARK: - Brick Bar request management (§15.9)

struct AdminRequestsView: View {
    @Environment(AppModel.self) private var model
    @State private var quoteTarget: BrickBarRequest?

    private var requests: [BrickBarRequest] {
        model.brickBarRequests.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if requests.isEmpty {
                    EmptyStateView(symbol: "tray", message: "No custom build requests yet.")
                } else {
                    ForEach(requests) { request in
                        requestCard(for: request)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Brick Bar Requests")
        .sheet(item: $quoteTarget) { request in
            SendQuoteSheet(request: request)
                .presentationDetents([.medium])
        }
    }

    private func requestCard(for request: BrickBarRequest) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                Image(systemName: request.buildType.symbol)
                    .foregroundStyle(BrickColor.brickRed)
                Text(request.title.isEmpty ? request.buildType.rawValue : request.title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(1)
                Spacer()
                TagBadge(text: request.status.displayName, tint: request.status.isOpen ? BrickColor.stadiumGreen : BrickColor.secondaryText)
            }
            Text("From \(model.displayName(for: request.userID)) · \(request.budgetRange.rawValue) · \(request.deadlineType.rawValue)")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Text(request.description)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
                .lineLimit(3)
            if let quote = request.quotedPrice {
                MetaLabel(symbol: "sterlingsign.circle", text: "Quoted \(quote.formatted(.currency(code: "GBP")))")
            }
            HStack(spacing: BrickSpacing.m) {
                Menu {
                    ForEach(RequestStatus.allCases.filter { $0 != .draft }, id: \.rawValue) { status in
                        Button(status.displayName) {
                            model.updateBrickBarRequest(request.id, status: status)
                        }
                    }
                } label: {
                    Label("Set status", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrickColor.gold)
                        .frame(minHeight: 40)
                }
                Button {
                    quoteTarget = request
                } label: {
                    Label("Send quote", systemImage: "sterlingsign.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrickColor.stadiumGreen)
                        .frame(minHeight: 40)
                }
                Spacer()
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}

private struct SendQuoteSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var request: BrickBarRequest
    @State private var amountText = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Quote for \"\(request.title)\"") {
                    TextField("Amount in GBP", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Note to the customer (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Send Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        if let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 {
                            model.updateBrickBarRequest(request.id, status: .quoted, quote: amount, note: note)
                            dismiss()
                        }
                    }
                    .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Article & product management

struct AdminArticlesView: View {
    @Environment(AppModel.self) private var model
    @State private var removalTarget: Article?

    var body: some View {
        List {
            ForEach(model.articles.sorted { $0.createdAt > $1.createdAt }) { article in
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                    HStack {
                        TagBadge(text: article.status.displayName, tint: article.status == .published ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                        if article.aiAssisted { TagBadge(text: "AI-assisted") }
                        Spacer()
                        Menu("Change") {
                            ForEach(PublishStatus.allCases, id: \.rawValue) { status in
                                Button(status.displayName) {
                                    model.setArticleStatus(article.id, status: status)
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                removalTarget = article
                            } label: {
                                Label("Remove from app", systemImage: "archivebox")
                            }
                        }
                        .font(BrickFont.meta)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Articles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AdminStoryEditorView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Remove this story from the app?",
            isPresented: Binding(
                get: { removalTarget != nil },
                set: { if !$0 { removalTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let removalTarget {
                Button("Remove from app", role: .destructive) {
                    model.removeArticleFromApp(removalTarget.id)
                    self.removalTarget = nil
                }
            }
        } message: {
            Text("This story will be archived and no longer appear in News, Today, search, or related stories.")
        }
    }
}

struct AdminSubmittedStoriesView: View {
    @Environment(AppModel.self) private var model
    @State private var declineTarget: SubmittedStory?
    @State private var feedback = ""
    @State private var tidyingID: UUID?

    var body: some View {
        List {
            if model.pendingSubmittedStories.isEmpty {
                Text("No community stories are waiting for review.")
                    .foregroundStyle(BrickColor.secondaryText)
            } else {
                ForEach(model.pendingSubmittedStories) { submission in
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text(submission.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text("By \(model.displayName(for: submission.userID)) • \(AppDate.relative(submission.submittedAt))")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                        Text(submission.summary)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                            .lineLimit(3)
                        HStack {
                            TagBadge(text: submission.category.rawValue)
                            if submission.aiAssisted { TagBadge(text: "AI tidied") }
                            if submission.declineCount > 0 {
                                TagBadge(text: "\(submission.declineCount)/3 declines", tint: BrickColor.brickRed)
                            }
                        }
                        mediaPreview(for: submission)
                        HStack {
                            Button("Publish") {
                                model.publishSubmittedStory(submission.id)
                            }
                            .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: false))

                            Button {
                                tidy(submission)
                            } label: {
                                if tidyingID == submission.id {
                                    ProgressView()
                                } else {
                                    Text("AI Tidy")
                                }
                            }
                            .buttonStyle(StudButtonStyle(prominent: false))
                            .disabled(tidyingID != nil)

                            Button("Decline", role: .destructive) {
                                declineTarget = submission
                                feedback = ""
                            }
                            .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Submitted Stories")
        .refreshable {
            await model.refreshSupabaseContent()
        }
        .task {
            await model.refreshSupabaseContent(quietErrors: true)
        }
        .sheet(item: $declineTarget) { submission in
            NavigationStack {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    Text(submission.title)
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    Text("Tell the member what needs changing. Feedback is required.")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.secondaryText)
                    TextEditor(text: $feedback)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(BrickSpacing.s)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
                    Spacer()
                }
                .padding(BrickSpacing.l)
                .background(BrickColor.background)
                .navigationTitle("Decline Story")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { declineTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send Feedback") {
                            model.declineSubmittedStory(submission.id, feedback: feedback)
                            declineTarget = nil
                        }
                        .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaPreview(for submission: SubmittedStory) -> some View {
        let media = submission.imageReferences + submission.mediaReferences
        if !media.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrickSpacing.s) {
                    ForEach(media.prefix(6), id: \.self) { reference in
                        ArticleMediaView(reference: reference)
                            .frame(width: 96, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func tidy(_ submission: SubmittedStory) {
        tidyingID = submission.id
        Task {
            await model.tidySubmittedStoryWithAI(submission.id)
            tidyingID = nil
        }
    }
}

struct AdminProductsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            ForEach(model.products.sorted { $0.createdAt > $1.createdAt }) { product in
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                    HStack {
                        TagBadge(text: product.status.displayName, tint: product.status == .active ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                        Text(product.priceLabel)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                        Spacer()
                        Menu("Change") {
                            ForEach(ProductStatus.allCases, id: \.rawValue) { status in
                                Button(status.displayName) {
                                    model.setProductStatus(product.id, status: status)
                                }
                            }
                        }
                        .font(BrickFont.meta)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Products")
    }
}
