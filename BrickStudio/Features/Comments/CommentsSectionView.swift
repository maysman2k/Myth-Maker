import SwiftUI

/// Shared comments UI used by articles, reviews and lessons (§11).
struct CommentsSectionView: View {
    @Environment(AppModel.self) private var model
    var contentType: ContentType
    var contentID: UUID
    var prompt: String?

    @State private var sort: CommentSort = .newest
    @State private var draftText = ""
    @State private var replyTarget: Comment?
    @State private var editTarget: Comment?
    @State private var reportTarget: Comment?
    @FocusState private var composerFocused: Bool

    private var topLevel: [Comment] {
        model.topLevelComments(for: contentType, contentID: contentID, sort: sort)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.l) {
            HStack {
                Text("Comments (\(model.commentCount(for: contentType, contentID: contentID)))")
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                Picker("Sort", selection: $sort) {
                    ForEach(CommentSort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(BrickColor.gold)
            }

            if let prompt {
                Text(prompt)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
            }

            if model.isSignedIn {
                composer
            } else {
                signInPrompt
            }

            if topLevel.isEmpty {
                Text("No comments yet. Be the first to start the conversation.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
                    .padding(.vertical, BrickSpacing.m)
            } else {
                ForEach(topLevel) { comment in
                    CommentRow(
                        comment: comment,
                        contentType: contentType,
                        contentID: contentID,
                        onReply: { replyTarget = $0; composerFocused = true },
                        onEdit: { editTarget = $0; draftText = $0.body; composerFocused = true },
                        onReport: { reportTarget = $0 }
                    )
                }
            }
        }
        .sheet(item: $reportTarget) { comment in
            ReportCommentSheet(comment: comment)
                .presentationDetents([.medium])
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            if let replyTarget {
                HStack {
                    Text("Replying to \(model.displayName(for: replyTarget.userID))")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                    Spacer()
                    Button("Cancel") { self.replyTarget = nil }
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                }
            }
            if editTarget != nil {
                HStack {
                    Text("Editing your comment")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                    Spacer()
                    Button("Cancel") { editTarget = nil; draftText = "" }
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                }
            }
            HStack(alignment: .bottom, spacing: BrickSpacing.s) {
                TextField("Add a comment…", text: $draftText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(BrickSpacing.m)
                    .background(BrickColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
                Button {
                    submit()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .frame(width: 44, height: 44)
                        .background(BrickColor.gold)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Post comment")
            }
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: BrickSpacing.m) {
            Text("Join the conversation")
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text("Sign in or create an account to leave a comment.")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Button("Sign In") { model.isShowingAuth = true }
                .buttonStyle(StudButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func submit() {
        if let editTarget {
            model.editComment(editTarget.id, body: draftText)
            self.editTarget = nil
        } else {
            let posted = model.postComment(
                type: contentType,
                contentID: contentID,
                body: draftText,
                parentCommentID: replyTarget?.id
            )
            guard posted else { return }
            replyTarget = nil
        }
        draftText = ""
        composerFocused = false
    }
}

private struct CommentRow: View {
    @Environment(AppModel.self) private var model
    var comment: Comment
    var contentType: ContentType
    var contentID: UUID
    var onReply: (Comment) -> Void
    var onEdit: (Comment) -> Void
    var onReport: (Comment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            commentContent(comment)
            let replies = model.replies(to: comment.id, type: contentType, contentID: contentID)
            ForEach(replies) { reply in
                commentContent(reply)
                    .padding(.leading, BrickSpacing.xl)
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    @ViewBuilder
    private func commentContent(_ comment: Comment) -> some View {
        let author = model.account(id: comment.userID)
        VStack(alignment: .leading, spacing: BrickSpacing.xs) {
            HStack(spacing: BrickSpacing.s) {
                AvatarView(name: author?.displayName ?? "?", size: 28)
                Text(author?.displayName ?? "Former member")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                if let role = author?.role, role.canModerate {
                    TagBadge(text: role.displayName, tint: BrickColor.stadiumGreen)
                }
                Spacer()
                Text(AppDate.relative(comment.createdAt))
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            if comment.status == .pendingReview {
                TagBadge(text: "Awaiting review", tint: BrickColor.brickRed)
            }
            Text(comment.body)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.primaryText)
            HStack(spacing: BrickSpacing.l) {
                Button {
                    model.toggleLike(.comment, comment.id)
                } label: {
                    Label("\(comment.likeCount)", systemImage: model.isLiked(.comment, comment.id) ? "heart.fill" : "heart")
                }
                .foregroundStyle(model.isLiked(.comment, comment.id) ? BrickColor.brickRed : BrickColor.secondaryText)

                if CommentPolicy.canReply(to: comment, in: model.comments) {
                    Button("Reply") { onReply(comment) }
                        .foregroundStyle(BrickColor.secondaryText)
                }
                if CommentPolicy.canEdit(comment, by: model.currentUserID) {
                    Button("Edit") { onEdit(comment) }
                        .foregroundStyle(BrickColor.secondaryText)
                }
                if CommentPolicy.canDelete(comment, by: model.currentUser) {
                    Button("Delete", role: .destructive) { model.deleteComment(comment.id) }
                        .foregroundStyle(BrickColor.brickRed)
                }
                if comment.userID != model.currentUserID {
                    Button {
                        onReport(comment)
                    } label: {
                        Image(systemName: "flag")
                    }
                    .foregroundStyle(BrickColor.secondaryText)
                    .accessibilityLabel("Report comment")
                }
                Spacer()
            }
            .font(BrickFont.meta)
            .buttonStyle(.plain)
            if comment.editedAt != nil {
                Text("Edited")
                    .font(.system(size: 11))
                    .foregroundStyle(BrickColor.secondaryText)
            }
        }
    }
}

private struct ReportCommentSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var comment: Comment
    @State private var reason: ReportReason = .spam
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this comment?") {
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
            .navigationTitle("Report comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        model.reportComment(comment.id, reason: reason, details: details)
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
