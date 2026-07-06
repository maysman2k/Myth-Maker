import SwiftUI

/// In-app admin area (§22), available to moderators, editors and admins.
/// Editors/admins manage content and the AI draft queue; moderators handle
/// comments. Never visible to normal users.
struct AdminPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
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
                        adminLink("AI Draft Queue", symbol: "sparkles", badge: model.adminStats.pendingDrafts) {
                            AIDraftQueueView()
                        }
                        adminLink("Articles", symbol: "newspaper", badge: 0) {
                            AdminArticlesView()
                        }
                        adminLink("Products", symbol: "bag", badge: 0) {
                            AdminProductsView()
                        }
                    }
                    adminLink("Comment moderation", symbol: "bubble.left.and.exclamationmark.bubble.right", badge: model.adminStats.pendingComments) {
                        AdminCommentsView()
                    }
                    adminLink("Brick Bar requests", symbol: "wrench.and.screwdriver", badge: model.adminStats.openRequests) {
                        AdminRequestsView()
                    }
                }
                .brickCard()
                Text("AI drafts never publish automatically — everything below needs a human decision.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(BrickSpacing.l)
        }
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

    private var pending: [AIDraft] {
        model.aiDrafts.filter { $0.status == .needsReview }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if pending.isEmpty {
                    EmptyStateView(symbol: "sparkles", message: "The queue is clear. New drafts appear here when the scanner finds relevant stories.")
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
                            Label(source.name, systemImage: "link")
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.gold)
                        }
                    }
                }

                HStack(spacing: BrickSpacing.m) {
                    Button {
                        model.approveAIDraft(draft.id)
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
                AvatarView(name: model.displayName(for: comment.userID), size: 26)
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
                        }
                        .font(BrickFont.meta)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Articles")
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
