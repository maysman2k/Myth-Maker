import SwiftUI

/// The app's home screen (§8) — routes users into every key feature.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("brickStackBestScore") private var brickStackBestScore = 0
    @AppStorage("studMatchBestScore") private var studMatchBestScore = 0
    @AppStorage("buildSprintBestScore") private var buildSprintBestScore = 0
    @AppStorage("revealStadiumBestScore") private var revealStadiumBestScore = 0
    @State private var instagramPosts: [InstagramPost] = []
    @State private var instagramError: String?
    @State private var instagramLoading = false
    @State private var isPickingPostType = false
    @State private var composerKind: CommunityPostKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    // Each section cascades in as the feed appears.
                    storyStrip.cardAppear(0)
                    feedActionBar.cardAppear(1)
                    ChallengeCard().cardAppear(2)
                    newsTiles.cardAppear(3)
                    PollHighlightCard().cardAppear(4)
                    instagramCarousel.cardAppear(5)
                    LeaderboardHighlightCard().cardAppear(6)
                    CommunityBuildsSection().cardAppear(7)
                    communityPostFeed
                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
                .padding(.top, BrickSpacing.l)
            }
            .background(TodayFeedBackground())
            .toolbar(.hidden, for: .navigationBar)
            .contentRouteDestinations()
            .sheet(isPresented: $isPickingPostType) {
                PostTypePickerSheet { kind in
                    composerKind = kind
                }
            }
            .sheet(item: $composerKind) { kind in
                CommunityComposerSheet(kind: kind)
            }
            .task {
                await loadInstagramPosts()
                submitStoredBests()
                await model.refreshCommunityContent()
            }
            .onChange(of: brickStackBestScore) { _, score in model.submitGameScore(.brickStack, score: score) }
            .onChange(of: studMatchBestScore) { _, score in model.submitGameScore(.studMatch, score: score) }
            .onChange(of: buildSprintBestScore) { _, score in model.submitGameScore(.buildSprint, score: score) }
            .onChange(of: revealStadiumBestScore) { _, score in model.submitGameScore(.revealStadium, score: score) }
        }
    }

    /// Feeds the signed-in player's stored bests onto this week's board.
    private func submitStoredBests() {
        model.submitGameScore(.brickStack, score: brickStackBestScore)
        model.submitGameScore(.studMatch, score: studMatchBestScore)
        model.submitGameScore(.buildSprint, score: buildSprintBestScore)
        model.submitGameScore(.revealStadium, score: revealStadiumBestScore)
    }

    // MARK: Header (§8.3)

    private var header: some View {
        VStack(spacing: BrickSpacing.l) {
            HStack(spacing: BrickSpacing.s) {
                Spacer()
                NavigationLink {
                    SearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BrickColor.primaryText)
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Search")

                NavigationLink {
                    NotificationsView()
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BrickColor.primaryText)
                        .frame(width: 42, height: 42)
                        .overlay(alignment: .topTrailing) {
                            if model.unreadNotificationCount > 0 {
                                Text("\(model.unreadNotificationCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(BrickColor.brickRed))
                                    .offset(x: 2, y: 4)
                            }
                        }
                }
                .accessibilityLabel("Notifications")

                NavigationLink {
                    ProfileView()
                } label: {
                    if let user = model.currentUser {
                        AvatarView(name: user.displayName, imageReference: user.avatarImageReference, size: 36)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 25))
                            .foregroundStyle(BrickColor.secondaryText)
                            .frame(width: 42, height: 42)
                    }
                }
                .accessibilityLabel("Profile")
            }

            VStack(spacing: BrickSpacing.s) {
                Image("BIABLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 104)
                    .accessibilityLabel("Bricks in a Bag")

                Text(greeting)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(BrickColor.primaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var greeting: String {
        if let name = model.currentUser?.displayName.split(separator: " ").first {
            return "Hello \(name)"
        }
        return "Hello!"
    }

    // MARK: Live Feed

    private var communityComposer: some View {
        HStack(spacing: BrickSpacing.m) {
            Group {
                if let user = model.currentUser {
                    AvatarView(name: user.displayName, imageReference: user.avatarImageReference, size: 44)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 34))
                        .foregroundStyle(BrickColor.secondaryText)
                        .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Share a build")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Text("Photos, videos, links and write-ups go to review before publishing.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if model.isSignedIn {
                Button {
                    isPickingPostType = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(BrickColor.gold)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create a post")
            } else {
                Button {
                    model.isShowingAuth = true
                } label: {
                    Text("Sign in")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .frame(height: 38)
                        .background(BrickColor.gold)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var liveFeedItems: [TodayFeedItem] {
        var items: [TodayFeedItem] = []

        for article in model.publishedArticles.prefix(8) {
            items.append(.article(article, isCommunity: isCommunityArticle(article)))
        }

        if let review = model.publishedReviews.first {
            items.append(.review(review))
        }

        if let product = model.activeProducts.first(where: { $0.status == .active }) {
            items.append(.advert(product))
        }

        if let lesson = model.publishedLessons.first {
            items.append(.lesson(lesson))
        }

        if let gameScore = bestGameScore {
            items.append(.gameScore(gameScore))
        }

        return items
            .sorted { $0.date > $1.date }
            .prefix(12)
            .map { $0 }
    }

    @ViewBuilder
    private var liveFeed: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            SectionHeader(title: "Live Feed")

            ForEach(Array(liveFeedItems.enumerated()), id: \.element.id) { index, item in
                Group {
                    switch item {
                    case .article(let article, let isCommunity):
                        NavigationLink(value: ContentRoute.article(article.id)) {
                            TodayArticleFeedCard(article: article, isCommunity: isCommunity)
                        }
                        .buttonStyle(PressableStyle())
                    case .review(let review):
                        NavigationLink(value: ContentRoute.review(review.id)) {
                            TodayReviewFeedCard(review: review)
                        }
                        .buttonStyle(PressableStyle())
                    case .advert(let product):
                        NavigationLink(value: ContentRoute.product(product.id)) {
                            TodayAdvertFeedCard(product: product)
                        }
                        .buttonStyle(PressableStyle())
                    case .lesson(let lesson):
                        NavigationLink(value: ContentRoute.lesson(lesson.id)) {
                            TodayLessonFeedCard(lesson: lesson)
                        }
                        .buttonStyle(PressableStyle())
                    case .gameScore(let score):
                        Button {
                            model.selectedTab = .games
                        } label: {
                            TodayGameScoreFeedCard(score: score)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .cardAppear(index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestGameScore: TodayGameScore? {
        let scores = [
            TodayGameScore(title: "Brick Stack", score: brickStackBestScore, symbol: "square.stack.3d.up.fill"),
            TodayGameScore(title: "Stud Match", score: studMatchBestScore, symbol: "circle.grid.3x3.fill"),
            TodayGameScore(title: "Build Sprint", score: buildSprintBestScore, symbol: "timer"),
            TodayGameScore(title: "Reveal Stadium", score: revealStadiumBestScore, symbol: "sportscourt.fill")
        ]
        return scores.filter { $0.score > 0 }.max { $0.score < $1.score }
    }

    private func isCommunityArticle(_ article: Article) -> Bool {
        let officialAuthors = ["Bricks in a Bag Team", "Sasha", "Pete"]
        return !officialAuthors.contains(article.authorName)
    }

    private var officialArticles: [Article] {
        model.publishedArticles.filter { !isCommunityArticle($0) }
    }

    private var communityArticles: [Article] {
        model.publishedArticles.filter { isCommunityArticle($0) }
    }

    private var storyArticles: [Article] {
        Array(model.publishedArticles.prefix(8))
    }

    private var mixedPostArticles: [Article] {
        let community = communityArticles
        return community.isEmpty ? Array(model.publishedArticles.dropFirst(2).prefix(6)) : Array(community.prefix(8))
    }

    private var storyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                NavigationLink {
                    if model.isSignedIn {
                        SubmitStoryEditorView()
                    } else {
                        AuthView()
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            if let user = model.currentUser {
                                AvatarView(name: user.displayName, imageReference: user.avatarImageReference, size: 64)
                            } else {
                                Circle()
                                    .fill(.white.opacity(0.86))
                                    .frame(width: 64, height: 64)
                                    .overlay(Image(systemName: "person").foregroundStyle(BrickColor.secondaryText))
                            }
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 27, height: 27)
                                .background(BrickColor.gold)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        }
                        Text("Your Story")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 84, height: 116)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(PressableStyle(scale: 0.94))

                ForEach(storyArticles) { article in
                    NavigationLink(value: ContentRoute.article(article.id)) {
                        TodayStoryTile(article: article, isCommunity: isCommunityArticle(article))
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var feedActionBar: some View {
        HStack(spacing: 10) {
            feedActionButton("plus") {
                if model.isSignedIn {
                    isPickingPostType = true
                } else {
                    model.isShowingAuth = true
                }
            }
            feedActionButton("bookmark") {
                model.showToast("Saved posts are in your profile.", symbol: "bookmark")
            }
            feedActionButton("heart") {
                model.showToast("Notifications live in the bell.", symbol: "bell")
            }
            NavigationLink {
                SearchView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                    Spacer()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BrickColor.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.52), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func feedActionButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var newsTiles: some View {
        let articles = Array(officialArticles.prefix(2))
        if !articles.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                Text("News")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.black)

                HStack(spacing: BrickSpacing.m) {
                    ForEach(articles) { article in
                        NavigationLink(value: ContentRoute.article(article.id)) {
                            TodayNewsTile(article: article)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if articles.count == 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var communityPostFeed: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.l) {
            ForEach(Array(mixedPostArticles.enumerated()), id: \.element.id) { index, article in
                NavigationLink(value: ContentRoute.article(article.id)) {
                    TodayLargePostCard(article: article, isCommunity: isCommunityArticle(article))
                }
                .buttonStyle(PressableStyle())
                .cardAppear(index)

                if (index + 1) % 4 == 0, let product = model.activeProducts.first(where: { $0.status == .active }) {
                    NavigationLink(value: ContentRoute.product(product.id)) {
                        TodaySmallAdvertCard(product: product)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Hero (§8.4) — rotates daily between featured content

    private var heroCard: some View {
        let heroes: [(label: String, title: String, subtitle: String, symbol: String, tint: Color, destination: HeroDestination)] = [
            ("Custom builds", "The Brick Bar is open", "Send us your build idea and we'll turn it into bricks.", "wrench.and.screwdriver", BrickColor.brickRed, .brickBar),
            ("Create", "Turn a photo into a brick mosaic", "Preview your photo in studs before we build it.", "square.grid.3x3", BrickColor.gold, .mosaic),
            ("Games", "Quick brick-sized challenges", "Stack, match and race the clock — climb this week's board.", "gamecontroller", BrickColor.stadiumGreen, .games)
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let hero = heroes[dayIndex % heroes.count]

        return Button {
            switch hero.destination {
            case .brickBar: model.selectedTab = .brickBar
            case .mosaic: model.selectedTab = .create
            case .games: model.selectedTab = .games
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                BrickArtView(seed: dayIndex, tint: hero.tint, symbol: hero.symbol)
                    .frame(height: 210)
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                    TagBadge(text: hero.label, tint: .white)
                    Text(hero.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(hero.subtitle)
                        .font(BrickFont.meta)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(BrickSpacing.l)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private enum HeroDestination { case brickBar, mosaic, games }

    // MARK: Instagram

    @ViewBuilder
    private var instagramCarousel: some View {
        if InstagramFeedService.isConfigured {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Latest on Instagram")

                if instagramLoading && instagramPosts.isEmpty {
                    HStack(spacing: BrickSpacing.m) {
                        ProgressView()
                            .tint(BrickColor.gold)
                        Text("Loading posts")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                } else if let instagramError, instagramPosts.isEmpty {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Label("Instagram feed unavailable", systemImage: "camera")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        Text(instagramError)
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                            .lineLimit(3)
                        Button("Retry") {
                            Task { await loadInstagramPosts(force: true) }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BrickColor.gold)
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BrickSpacing.m) {
                            ForEach(instagramPosts) { post in
                                InstagramPostCard(post: post)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        }
    }

    @MainActor
    private func loadInstagramPosts(force: Bool = false) async {
        guard InstagramFeedService.isConfigured else { return }
        guard force || instagramPosts.isEmpty else { return }
        instagramLoading = true
        instagramError = nil
        do {
            instagramPosts = try await InstagramFeedService.fetchLatest(limit: 5)
        } catch {
            instagramError = error.localizedDescription
        }
        instagramLoading = false
    }

    // MARK: Quick actions (§8.5)

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
            quickAction("Read News", symbol: "newspaper") { model.selectedTab = .news }
            quickAction("Make Mosaic", symbol: "square.grid.3x3") { model.selectedTab = .create }
            quickAction("Play Games", symbol: "gamecontroller") { model.selectedTab = .games }
            quickAction("Request Build", symbol: "wrench.and.screwdriver") { model.selectedTab = .brickBar }
        }
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: BrickSpacing.s) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(BrickColor.gold)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .brickCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Latest news (§8.6)

    @ViewBuilder
    private var latestNews: some View {
        let latest = Array(model.publishedArticles.prefix(4))
        if !latest.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Latest news", actionTitle: "See all") { model.selectedTab = .news }

                if let lead = latest.first {
                    NavigationLink(value: ContentRoute.article(lead.id)) {
                        FeaturedArticleCard(article: lead)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: BrickSpacing.s) {
                    ForEach(Array(latest.dropFirst())) { article in
                        NavigationLink(value: ContentRoute.article(article.id)) {
                            CompactArticleRow(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Featured review (§8.7)

    @ViewBuilder
    private var featuredReview: some View {
        if let review = model.publishedReviews.first {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Featured review")
                NavigationLink(value: ContentRoute.review(review.id)) {
                    HStack(spacing: BrickSpacing.m) {
                        BrickArtView(seed: review.id.artSeed, tint: BrickColor.gold, symbol: "shippingbox")
                            .frame(width: 86, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                            Text(review.setName)
                                .font(BrickFont.cardTitle)
                                .foregroundStyle(BrickColor.primaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            StarRatingView(rating: review.ratingOverall)
                            Text(review.summary)
                                .font(BrickFont.meta)
                                .foregroundStyle(BrickColor.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
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

    // MARK: Featured product (§8.8)

    @ViewBuilder
    private var featuredProduct: some View {
        if let product = model.activeProducts.first(where: { $0.status == .active }) {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Featured build")
                NavigationLink(value: ContentRoute.product(product.id)) {
                    ProductCard(product: product)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Prompts (§8.9, §8.10)

    private var mosaicPrompt: some View {
        promptCard(
            title: "Turn a photo into a brick mosaic",
            cta: "Start Mosaic",
            symbol: "square.grid.3x3",
            tint: BrickColor.gold
        ) { model.selectedTab = .create }
    }

    private var brickBarPrompt: some View {
        promptCard(
            title: "Got an idea for a custom build?",
            cta: "Visit The Brick Bar",
            symbol: "wrench.and.screwdriver",
            tint: BrickColor.brickRed
        ) { model.selectedTab = .brickBar }
    }

    private func promptCard(title: String, cta: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BrickSpacing.m) {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(tint.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrickFont.cardTitle)
                        .foregroundStyle(BrickColor.primaryText)
                        .multilineTextAlignment(.leading)
                    Text(cta)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
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

    // MARK: Studio Lesson (§8 item 10)

    @ViewBuilder
    private var lessonCard: some View {
        if let lesson = model.publishedLessons.first {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Studio Lesson")
                NavigationLink(value: ContentRoute.lesson(lesson.id)) {
                    LessonCard(lesson: lesson)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Trending (§8.11)

    @ViewBuilder
    private var trendingDiscussions: some View {
        let trending = model.trendingDiscussions
        if !trending.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Trending discussions")
                ForEach(trending, id: \.id) { item in
                    if let route = ContentRoute(type: item.type, id: item.id) {
                        NavigationLink(value: route) {
                            HStack(spacing: BrickSpacing.m) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundStyle(BrickColor.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(BrickColor.primaryText)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    HStack {
                                        TagBadge(text: item.type.displayName)
                                        Text("\(item.commentCount) comment\(item.commentCount == 1 ? "" : "s") · \(AppDate.relative(item.latest))")
                                            .font(BrickFont.meta)
                                            .foregroundStyle(BrickColor.secondaryText)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(BrickColor.secondaryText)
                            }
                            .padding(BrickSpacing.m)
                            .brickCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct InstagramPostCard: View {
    var post: InstagramPost

    var body: some View {
        Group {
            if let permalink = post.permalink {
                Link(destination: permalink) {
                    content
                }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
        .frame(width: 214)
        .brickCard()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            ZStack(alignment: .topTrailing) {
                media
                    .frame(width: 214, height: 214)
                    .clipped()

                if post.mediaType.uppercased().contains("VIDEO") {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(BrickColor.gold))
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "View this post on Instagram")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Image(systemName: "camera")
                    Text(post.timestamp.map { AppDate.relative($0) } ?? "Instagram")
                }
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            }
            .padding([.horizontal, .bottom], BrickSpacing.m)
        }
    }

    @ViewBuilder
    private var media: some View {
        if let url = post.displayImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                default:
                    ZStack {
                        placeholder
                        ProgressView()
                            .tint(BrickColor.gold)
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            BrickColor.card
            Image(systemName: "camera")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(BrickColor.gold)
        }
    }
}

private struct TodayFeedBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFFE45C), Color(hex: 0xF4C430), Color(hex: 0xE9A81E)],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                Canvas { context, size in
                    let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 2.2, height: 2.2))
                    for x in stride(from: 0, through: size.width, by: 8) {
                        for y in stride(from: 0, through: size.height, by: 8) {
                            context.translateBy(x: x, y: y)
                            context.fill(dot, with: .color(.black.opacity(0.055)))
                            context.translateBy(x: -x, y: -y)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

private struct TodayStoryTile: View {
    var article: Article
    var isCommunity: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ArticleArtwork(article: article)
                .frame(width: 94, height: 116)
                .clipped()

            LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .top, endPoint: .center)

            AvatarView(name: article.authorName, imageReference: nil, size: 28)
                .padding(7)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("BIABLogoStamp")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 22, height: 22)
                        .padding(7)
                }
            }
        }
        .frame(width: 94, height: 116)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.72), lineWidth: 1.4))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
    }
}

private struct TodayNewsTile: View {
    var article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            GeometryReader { proxy in
                ArticleArtwork(article: article)
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(article.summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.72))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.62), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 9, y: 5)
    }
}

private struct TodayLargePostCard: View {
    @Environment(AppModel.self) private var model
    var article: Article
    var isCommunity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    ArticleArtwork(article: article)
                        .frame(width: proxy.size.width, height: 235)
                        .clipped()
                }
                .frame(height: 235)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 8) {
                    AvatarView(name: article.authorName, imageReference: nil, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(article.authorName)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.black)
                        Text(AppDate.relative(article.publishedAt ?? article.createdAt))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
            }

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isCommunity ? BrickColor.stadiumGreen : BrickColor.gold)
                        .frame(width: 8, height: 8)
                    Text(article.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(article.summary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    metric("shippingbox", article.likeCount)
                    metric("bubble.left", model.commentCount(for: .article, contentID: article.id))
                    metric("bookmark", article.viewCount)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, BrickSpacing.m)
            .padding(.bottom, BrickSpacing.m)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.62), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 7)
    }

    private func metric(_ symbol: String, _ value: Int) -> some View {
        Label("\(value)", systemImage: symbol)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(.black.opacity(0.82))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(0.46))
            .clipShape(Capsule())
    }
}

private struct TodaySmallAdvertCard: View {
    var product: Product

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            BrickArtView(seed: product.id.artSeed, tint: BrickColor.stadiumGreen, symbol: "tag.fill")
                .frame(width: 104, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Sponsored")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.red)
                Text(product.name)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                Text(product.priceLabel)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black.opacity(0.72))
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.65), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 9, y: 5)
    }
}

private enum TodayFeedItem: Identifiable {
    case article(Article, isCommunity: Bool)
    case review(Review)
    case advert(Product)
    case lesson(Lesson)
    case gameScore(TodayGameScore)

    var id: String {
        switch self {
        case .article(let article, let isCommunity): return "article-\(article.id)-\(isCommunity)"
        case .review(let review): return "review-\(review.id)"
        case .advert(let product): return "advert-\(product.id)"
        case .lesson(let lesson): return "lesson-\(lesson.id)"
        case .gameScore(let score): return "game-\(score.title)"
        }
    }

    var date: Date {
        switch self {
        case .article(let article, _): return article.publishedAt ?? article.createdAt
        case .review(let review): return review.publishedAt ?? review.createdAt
        case .advert(let product): return product.updatedAt
        case .lesson(let lesson): return lesson.publishedAt ?? lesson.createdAt
        case .gameScore: return Date()
        }
    }
}

private struct TodayGameScore {
    var title: String
    var score: Int
    var symbol: String
}

private struct TodayArticleFeedCard: View {
    @Environment(AppModel.self) private var model
    var article: Article
    var isCommunity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack(spacing: BrickSpacing.s) {
                TagBadge(text: isCommunity ? "Community Build" : "Official News", tint: isCommunity ? BrickColor.stadiumGreen : BrickColor.gold)
                if article.aiAssisted {
                    TagBadge(text: "AI assisted", tint: BrickColor.secondaryText)
                }
                Spacer()
                Text(AppDate.relative(article.publishedAt ?? article.createdAt))
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }

            GeometryReader { proxy in
                ArticleArtwork(article: article)
                    .frame(width: proxy.size.width, height: 190)
                    .clipped()
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text(article.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(article.summary)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: BrickSpacing.l) {
                Label(article.authorName, systemImage: isCommunity ? "person.crop.circle" : "checkmark.seal")
                Label("\(model.commentCount(for: .article, contentID: article.id))", systemImage: "bubble.left")
                Label("\(article.likeCount)", systemImage: "heart")
            }
            .font(BrickFont.meta)
            .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrickSpacing.l)
        .brickCard()
    }
}

private struct TodayReviewFeedCard: View {
    var review: Review

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            BrickArtView(seed: review.id.artSeed, tint: BrickColor.gold, symbol: "star.bubble")
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                TagBadge(text: "Review", tint: BrickColor.gold)
                Text(review.setName)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                StarRatingView(rating: review.ratingOverall)
                Text(review.summary)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrickSpacing.l)
        .brickCard()
    }
}

private struct TodayAdvertFeedCard: View {
    var product: Product

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            BrickArtView(seed: product.id.artSeed, tint: BrickColor.stadiumGreen, symbol: "bag")
                .frame(maxWidth: .infinity)
                .frame(height: 176)
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                TagBadge(text: "Promoted", tint: BrickColor.gold)
                Text(product.name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(product.shortDescription)
                    .font(BrickFont.meta)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
                Text(product.priceLabel)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(BrickColor.gold)
            }
            .padding(BrickSpacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
    }
}

private struct TodayLessonFeedCard: View {
    var lesson: Lesson

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(BrickColor.gold)
                .frame(width: 54, height: 54)
                .background(BrickColor.gold.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                TagBadge(text: "Studio Lesson", tint: BrickColor.gold)
                Text(lesson.title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                Text(lesson.summary)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrickSpacing.l)
        .brickCard()
    }
}

private struct TodayGameScoreFeedCard: View {
    var score: TodayGameScore

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            Image(systemName: score.symbol)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 58, height: 58)
                .background(BrickColor.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                TagBadge(text: "Games", tint: BrickColor.gold)
                Text("Your best \(score.title) score is \(score.score)")
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                Text("Leaderboards can become live once scores are stored in Supabase.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(BrickColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrickSpacing.l)
        .brickCard()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
