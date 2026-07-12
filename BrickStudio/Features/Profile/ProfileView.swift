import PhotosUI
import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                if let user = model.currentUser {
                    signedInHeader(for: user)
                    linksSection(for: user)
                    if user.role.isAdmin {
                        adminSection
                    }
                    signOutButton
                } else {
                    guestContent
                }
                LegalDisclaimerFooter()
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signedInHeader(for user: UserAccount) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack(spacing: BrickSpacing.m) {
                AvatarView(name: user.displayName, imageReference: user.avatarImageReference, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(BrickFont.sectionTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    if user.role != .user {
                        TagBadge(text: user.role.displayName, tint: BrickColor.stadiumGreen)
                    }
                    Text("Member since \(AppDate.medium(user.createdAt))")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
                Spacer()
            }
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            HStack(spacing: BrickSpacing.l) {
                statPill("\(model.myComments.count)", "comments")
                statPill("\(model.mySavedItems().count)", "saved")
                statPill("\(model.myMosaics.count)", "designs")
            }
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }

    private func statPill(_ value: String, _ label: String) -> some View {
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

    private func linksSection(for user: UserAccount) -> some View {
        VStack(spacing: 0) {
            profileLink("Edit profile", symbol: "pencil") { EditProfileView() }
            profileLink("Saved items", symbol: "bookmark") { SavedItemsView() }
            profileLink("My designs", symbol: "square.grid.3x3") { SavedDesignsView() }
            profileLink("My Brick Bar requests", symbol: "wrench.and.screwdriver") { MyRequestsView() }
            profileLink("My stories", symbol: "square.and.pencil") { SubmittedStoriesView() }
            profileLink("My comments", symbol: "bubble.left") { MyCommentsView() }
            profileLink("Notifications", symbol: "bell") { NotificationsView() }
            profileLink("Settings", symbol: "gearshape") { SettingsView() }
        }
        .brickCard()
    }

    private var adminSection: some View {
        VStack(spacing: 0) {
            profileLink("Admin panel", symbol: "shield.lefthalf.filled") { AdminPanelView() }
        }
        .brickCard()
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            model.signOut()
        } label: {
            Text("Sign out")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
    }

    private var guestContent: some View {
        VStack(spacing: BrickSpacing.l) {
            EmptyStateView(
                symbol: "person.crop.circle",
                message: "Create a free account to comment, save favourites, build mosaics and send custom build requests.",
                actionTitle: "Sign In or Create Account",
                action: { model.isShowingAuth = true }
            )
            VStack(spacing: 0) {
                profileLink("Community rules", symbol: "text.book.closed") { CommunityRulesView() }
                profileLink("Legal & about", symbol: "info.circle") { LegalView() }
            }
            .brickCard()
        }
    }

    private func profileLink<Destination: View>(_ title: String, symbol: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
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

// MARK: - Edit profile

struct EditProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var favouriteClub = ""
    @State private var favouriteTopics: Set<String> = []
    @State private var publicProfileEnabled = true
    @State private var avatarImageReference: String?
    @State private var selectedAvatarItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Profile") {
                HStack(spacing: BrickSpacing.m) {
                    AvatarView(name: displayName, imageReference: avatarImageReference, size: 72)
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                            Label(avatarImageReference == nil ? "Add profile photo" : "Change profile photo", systemImage: "camera")
                        }
                        if avatarImageReference != nil {
                            Button(role: .destructive) {
                                avatarImageReference = nil
                            } label: {
                                Label("Remove photo", systemImage: "trash")
                            }
                        }
                    }
                }
                TextField("Display name", text: $displayName)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Favourite club", text: $favouriteClub)
                Toggle("Public profile", isOn: $publicProfileEnabled)
            }
            Section("Favourite topics") {
                ForEach(FavouriteTopic.all, id: \.self) { topic in
                    Button {
                        if favouriteTopics.contains(topic) {
                            favouriteTopics.remove(topic)
                        } else {
                            favouriteTopics.insert(topic)
                        }
                    } label: {
                        HStack {
                            Text(topic)
                                .foregroundStyle(BrickColor.primaryText)
                            Spacer()
                            if favouriteTopics.contains(topic) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(BrickColor.gold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    model.updateProfile(
                        displayName: displayName,
                        bio: bio,
                        favouriteClub: favouriteClub,
                        favouriteTopics: Array(favouriteTopics),
                        publicProfileEnabled: publicProfileEnabled,
                        avatarImageReference: avatarImageReference
                    )
                    dismiss()
                }
            }
        }
        .onChange(of: selectedAvatarItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAvatar(from: newItem) }
        }
        .onAppear {
            guard let user = model.currentUser else { return }
            displayName = user.displayName
            bio = user.bio
            favouriteClub = user.favouriteClub
            favouriteTopics = Set(user.favouriteTopics)
            publicProfileEnabled = user.publicProfileEnabled
            avatarImageReference = user.avatarImageReference
        }
    }

    @MainActor
    private func loadAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let filename = ImageStore.save(image, quality: 0.86) else { return }
        avatarImageReference = "local-image://\(filename)"
    }
}

// MARK: - Saved items (§19)

struct SavedItemsView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: ContentType?

    private let groups: [(String, ContentType)] = [
        ("News", .article), ("Reviews", .review), ("Shop", .product), ("Lessons", .lesson)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                HStack(spacing: BrickSpacing.s) {
                    FilterChip(title: "All", isSelected: filter == nil) { filter = nil }
                    ForEach(groups, id: \.1) { group in
                        FilterChip(title: group.0, isSelected: filter == group.1) {
                            filter = filter == group.1 ? nil : group.1
                        }
                    }
                }
                let items = model.mySavedItems(of: filter)
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "bookmark",
                        message: "No saved articles yet. Save news, reviews or builds and they'll appear here.",
                        actionTitle: "Explore News",
                        action: { model.selectedTab = .news }
                    )
                } else {
                    ForEach(items) { item in
                        savedRow(for: item)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Saved Items")
    }

    @ViewBuilder
    private func savedRow(for item: SavedItem) -> some View {
        if let route = ContentRoute(type: item.contentType, id: item.contentID) {
            NavigationLink(value: route) {
                HStack(spacing: BrickSpacing.m) {
                    TagBadge(text: item.contentType.displayName)
                    Text(savedTitle(for: item))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrickColor.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Button {
                        model.toggleBookmark(item.contentType, item.contentID)
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(BrickColor.gold)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove from saved")
                }
                .padding(BrickSpacing.m)
                .brickCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func savedTitle(for item: SavedItem) -> String {
        switch item.contentType {
        case .article: return model.articles.first { $0.id == item.contentID }?.title ?? "Article"
        case .review: return model.reviews.first { $0.id == item.contentID }?.setName ?? "Review"
        case .product: return model.products.first { $0.id == item.contentID }?.name ?? "Product"
        case .lesson: return model.lessons.first { $0.id == item.contentID }?.title ?? "Lesson"
        default: return item.contentType.displayName
        }
    }
}

// MARK: - My comments

struct MyCommentsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.m) {
                if model.myComments.isEmpty {
                    EmptyStateView(
                        symbol: "bubble.left",
                        message: "You haven't commented yet. Join a discussion under any article or review."
                    )
                } else {
                    ForEach(model.myComments) { comment in
                        commentRow(for: comment)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("My Comments")
    }

    @ViewBuilder
    private func commentRow(for comment: Comment) -> some View {
        let row = VStack(alignment: .leading, spacing: BrickSpacing.xs) {
            HStack {
                TagBadge(text: comment.contentType.displayName)
                if comment.status == .pendingReview {
                    TagBadge(text: "Awaiting review", tint: BrickColor.brickRed)
                }
                Spacer()
                Text(AppDate.relative(comment.createdAt))
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            Text(comment.body)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.primaryText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            MetaLabel(symbol: "heart", text: "\(comment.likeCount)")
        }
        .padding(BrickSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()

        if let route = ContentRoute(type: comment.contentType, id: comment.contentID) {
            NavigationLink(value: route) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}
