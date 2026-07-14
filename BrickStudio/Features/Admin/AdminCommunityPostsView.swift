import SwiftUI

/// Moderation queue for community build posts: flagged wording, reported
/// posts and hidden posts land here for a human decision.
struct AdminCommunityPostsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                let pending = model.postsAwaitingModeration
                if pending.isEmpty {
                    EmptyStateView(symbol: "checkmark.seal", message: "No community posts waiting for review.")
                } else {
                    ForEach(pending) { post in
                        moderationCard(for: post)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Community Posts")
        .contentRouteDestinations()
    }

    private func moderationCard(for post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            HStack {
                Text(model.displayName(for: post.userID))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                TagBadge(
                    text: post.status == .pendingReview ? "Pending" : "Hidden",
                    tint: BrickColor.brickRed
                )
            }
            Text(post.caption)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.primaryText)
                .lineLimit(4)
            if post.reportCount > 0 {
                MetaLabel(symbol: "flag", text: "\(post.reportCount) report\(post.reportCount == 1 ? "" : "s")")
            }
            let reasons = model.userReports.filter { $0.reportedPostID == post.id }.map(\.reason.rawValue)
            if !reasons.isEmpty {
                Text("Reported for: \(Set(reasons).sorted().joined(separator: ", "))")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            HStack(spacing: BrickSpacing.m) {
                Button("Approve") { model.setCommunityPostStatus(post.id, status: .visible) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: false))
                Button("Hide") { model.setCommunityPostStatus(post.id, status: .hidden) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                Button("Remove") { model.setCommunityPostStatus(post.id, status: .removed) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }
}
