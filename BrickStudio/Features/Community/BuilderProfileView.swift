import SwiftUI

/// Public profile for any builder: follow, block/report, challenge crowns,
/// their shelf and their build posts. Saved items and requests stay
/// private per spec §7.9.
struct BuilderProfileView: View {
    @Environment(AppModel.self) private var model
    var userID: UUID

    @State private var isReporting = false

    private var builder: UserAccount? { model.account(id: userID) }
    private var isMe: Bool { userID == model.currentUserID }

    var body: some View {
        Group {
            if let builder, builder.publicProfileEnabled || isMe {
                content(for: builder)
            } else {
                EmptyStateView(symbol: "person.crop.circle.badge.questionmark", message: "This profile is private.")
            }
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Builder")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isReporting) {
            ReportUserSheet(userID: userID, postID: nil)
                .presentationDetents([.medium])
        }
    }

    private func content(for builder: UserAccount) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                header(for: builder)
                if !isMe { actionButtons }
                shelfSection
                postsSection
            }
            .padding(BrickSpacing.l)
        }
    }

    private func header(for builder: UserAccount) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack(spacing: BrickSpacing.m) {
                AvatarView(name: builder.displayName, imageReference: builder.avatarImageReference, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(builder.displayName)
                            .font(BrickFont.sectionTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        let wins = model.challengeWins(for: builder.id)
                        if wins > 0 {
                            Text(String(repeating: "👑", count: min(wins, 3)))
                                .accessibilityLabel("\(wins) challenge win\(wins == 1 ? "" : "s")")
                        }
                    }
                    Text("Building since \(AppDate.medium(builder.createdAt))")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
                Spacer()
            }
            if !builder.bio.isEmpty {
                Text(builder.bio)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            HStack(spacing: BrickSpacing.l) {
                stat("\(model.followerCount(for: builder.id))", "followers")
                stat("\(model.visibleCommunityPosts.filter { $0.userID == builder.id }.count)", "builds")
                stat("\(model.shelf(for: builder.id).count)", "on shelf")
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(BrickColor.primaryText)
            Text(label)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: BrickSpacing.m) {
            if model.isBlocked(userID) {
                Button("Unblock") { model.unblockUser(userID) }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                    .frame(maxWidth: .infinity)
            } else {
                Button(model.isFollowing(userID) ? "Following ✓" : "Follow") {
                    model.toggleFollow(userID)
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: !model.isFollowing(userID)))
                .frame(maxWidth: .infinity)
                Menu {
                    Button("Report builder", systemImage: "flag") { isReporting = true }
                    Button("Block builder", systemImage: "hand.raised", role: .destructive) {
                        model.blockUser(userID)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(BrickColor.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More options")
            }
        }
    }

    @ViewBuilder
    private var shelfSection: some View {
        let shelf = model.shelf(for: userID)
        if !shelf.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "On the shelf")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.s) {
                    ForEach(shelf) { item in
                        ArticleImage(reference: item.imageReference, mode: .fill)
                            .frame(height: 106)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel(item.caption.isEmpty ? "Shelf photo" : item.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var postsSection: some View {
        let posts = model.visibleCommunityPosts.filter { $0.userID == userID }
        if posts.isEmpty {
            EmptyStateView(symbol: "hammer", message: "No builds shared yet.")
        } else {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Builds")
                ForEach(posts) { post in
                    NavigationLink(value: ContentRoute.communityPost(post.id)) {
                        CommunityPostCard(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
