import SwiftUI

/// The app's home screen (§8) — routes users into every key feature.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.xl) {
                    header
                    heroCard
                    quickActions
                    latestNews
                    featuredReview
                    featuredProduct
                    mosaicPrompt
                    brickBarPrompt
                    lessonCard
                    trendingDiscussions
                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
                .padding(.top, BrickSpacing.s)
            }
            .background(BrickColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .contentRouteDestinations()
        }
    }

    // MARK: Header (§8.3)

    private var header: some View {
        HStack(spacing: BrickSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BRICKS IN A BAG")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(BrickColor.gold)
                Text(greeting)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)
            }
            Spacer()
            NavigationLink {
                SearchView()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(BrickColor.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Search")
            NavigationLink {
                NotificationsView()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(BrickColor.primaryText)
                    .frame(width: 44, height: 44)
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
                    AvatarView(name: user.displayName, size: 38)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(BrickColor.secondaryText)
                        .frame(width: 44, height: 44)
                }
            }
            .accessibilityLabel("Profile")
        }
    }

    private var greeting: String {
        if let name = model.currentUser?.displayName.split(separator: " ").first {
            return "\(AppDate.greeting()), \(name)"
        }
        return "Welcome to Bricks in a Bag"
    }

    // MARK: Hero (§8.4) — rotates daily between featured content

    private var heroCard: some View {
        let heroes: [(label: String, title: String, subtitle: String, symbol: String, tint: Color, destination: HeroDestination)] = [
            ("Custom builds", "The Brick Bar is open", "Send us your build idea and we'll turn it into bricks.", "wrench.and.screwdriver", BrickColor.brickRed, .brickBar),
            ("Create", "Turn a photo into a brick mosaic", "Preview your photo in studs before we build it.", "square.grid.3x3", BrickColor.gold, .mosaic),
            ("Shop", "Stadium builds, made to order", "Your club's ground, hand-built to display scale.", "sportscourt", BrickColor.stadiumGreen, .shop)
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let hero = heroes[dayIndex % heroes.count]

        return Button {
            switch hero.destination {
            case .brickBar: model.selectedTab = .brickBar
            case .mosaic, .shop: model.selectedTab = hero.destination == .mosaic ? .create : .shop
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

    private enum HeroDestination { case brickBar, mosaic, shop }

    // MARK: Quick actions (§8.5)

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
            quickAction("Read News", symbol: "newspaper") { model.selectedTab = .news }
            quickAction("Make Mosaic", symbol: "square.grid.3x3") { model.selectedTab = .create }
            quickAction("Shop Stadiums", symbol: "sportscourt") { model.selectedTab = .shop }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.m) {
                        ForEach(latest) { article in
                            NavigationLink(value: ContentRoute.article(article.id)) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ArticleArtwork(article: article)
                                        .frame(height: 100)
                                    VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                                        HStack(spacing: BrickSpacing.xs) {
                                            TagBadge(text: article.category.rawValue)
                                            if article.isRumour { RumourBadge() }
                                        }
                                        Text(article.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(BrickColor.primaryText)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                        HStack {
                                            MetaLabel(symbol: "clock", text: "\(article.readTimeMinutes) min")
                                            MetaLabel(symbol: "bubble.left", text: "\(model.commentCount(for: .article, contentID: article.id))")
                                        }
                                    }
                                    .padding(BrickSpacing.m)
                                }
                                .frame(width: 230, alignment: .leading)
                                .brickCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
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
                SectionHeader(title: "From the shop", actionTitle: "Shop all") { model.selectedTab = .shop }
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
