import SwiftUI

/// Article hero artwork: the editor-approved remote image when one exists,
/// otherwise the branded procedural graphic. Callers set the frame; this
/// view fills and clips within it.
struct ArticleArtwork: View {
    var article: Article

    var body: some View {
        if let urlString = article.heroImageURL, let url = URL(string: urlString) {
            Color.clear
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            fallback
                        }
                    }
                }
                .clipped()
                .accessibilityHidden(true)
        } else {
            fallback
        }
    }

    private var fallback: some View {
        BrickArtView(seed: article.id.artSeed, tint: article.category.artTint, symbol: article.category.symbol)
    }
}

struct NewsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedCategory: ArticleCategory?

    private var filtered: [Article] {
        guard let selectedCategory else { return model.publishedArticles }
        return model.publishedArticles.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    categoryChips
                    if filtered.isEmpty {
                        EmptyStateView(
                            symbol: "newspaper",
                            message: "Nothing here yet. Try another category or check back soon.",
                            actionTitle: "Show all news",
                            action: { selectedCategory = nil }
                        )
                    } else {
                        ForEach(filtered) { article in
                            NavigationLink(value: ContentRoute.article(article.id)) {
                                ArticleCard(article: article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    NavigationLink {
                        ReviewsView()
                    } label: {
                        HStack {
                            Image(systemName: "star.bubble")
                            Text("Looking for kit reviews?")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(BrickFont.cardTitle)
                        .foregroundStyle(BrickColor.primaryText)
                        .padding(BrickSpacing.l)
                        .brickCard()
                    }
                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
            }
            .background(BrickColor.background)
            .navigationTitle("News")
            .contentRouteDestinations()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrickSpacing.s) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ArticleCategory.allCases) { category in
                    FilterChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.vertical, BrickSpacing.xs)
        }
    }
}

struct ArticleCard: View {
    @Environment(AppModel.self) private var model
    var article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleArtwork(article: article)
                .frame(height: 140)
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                HStack(spacing: BrickSpacing.s) {
                    TagBadge(text: article.category.rawValue)
                    if article.isRumour { RumourBadge() }
                    Spacer()
                    Button {
                        model.toggleBookmark(.article, article.id)
                    } label: {
                        Image(systemName: model.isBookmarked(.article, article.id) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(BrickColor.gold)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Bookmark article")
                }
                Text(article.title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text(article.summary)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: BrickSpacing.l) {
                    MetaLabel(symbol: "person", text: article.authorName)
                    MetaLabel(symbol: "clock", text: "\(article.readTimeMinutes) min")
                    MetaLabel(symbol: "bubble.left", text: "\(model.commentCount(for: .article, contentID: article.id))")
                    Spacer()
                    Text(AppDate.relative(article.publishedAt ?? article.createdAt))
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
            }
            .padding(BrickSpacing.l)
        }
        .brickCard()
    }
}
