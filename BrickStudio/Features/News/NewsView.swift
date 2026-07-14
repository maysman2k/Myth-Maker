import AVKit
import SwiftUI

/// Article hero artwork: the editor-approved remote/local image when one
/// exists, otherwise the branded procedural graphic. Callers set the frame.
struct ArticleArtwork: View {
    var article: Article

    var body: some View {
        if let urlString = article.heroImageURL {
            ArticleImage(reference: urlString, mode: .fill, fallback: AnyView(fallback))
                .accessibilityHidden(true)
        } else {
            fallback
        }
    }

    private var fallback: some View {
        BrickArtView(seed: article.id.artSeed, tint: article.category.artTint, symbol: article.category.symbol)
    }
}

struct ArticleImage: View {
    enum Mode {
        case fill
        case fit
    }

    var reference: String
    var mode: Mode
    var fallback: AnyView? = nil

    var body: some View {
        if let filename = localFilename(from: reference), let uiImage = ImageStore.load(filename) {
            imageView(Image(uiImage: uiImage))
        } else if let url = URL(string: reference), url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    imageView(image)
                case .failure:
                    fallback
                default:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(BrickColor.border.opacity(0.5))
                        .overlay(ProgressView())
                }
            }
        } else {
            fallback
        }
    }

    @ViewBuilder
    private func imageView(_ image: Image) -> some View {
        switch mode {
        case .fill:
            // Fill inside an overlay so the photo can never dictate layout
            // width — a bare scaledToFill() with only a height frame adopts
            // the image's native width and pushes the whole page off-screen.
            Color.clear
                .overlay { image.resizable().scaledToFill() }
                .clipped()
        case .fit:
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
    }

    private func localFilename(from reference: String) -> String? {
        let prefix = "local-image://"
        guard reference.hasPrefix(prefix) else { return nil }
        return String(reference.dropFirst(prefix.count))
    }
}

struct ArticleMediaView: View {
    var reference: String

    var body: some View {
        if reference.hasPrefix("local-video://"), let url = localVideoURL(from: reference) {
            video(url)
        } else if let url = URL(string: reference), url.scheme != nil, isVideoURL(url) {
            video(url)
        } else {
            ArticleImage(reference: reference, mode: .fit)
        }
    }

    private func video(_ url: URL) -> some View {
        VideoPlayer(player: AVPlayer(url: url))
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(BrickSpacing.s)
            }
    }

    private func localVideoURL(from reference: String) -> URL? {
        let prefix = "local-video://"
        guard reference.hasPrefix(prefix) else { return nil }
        return ImageStore.videoURL(String(reference.dropFirst(prefix.count)))
    }

    private func isVideoURL(_ url: URL) -> Bool {
        ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased())
    }
}

struct NewsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedCategory: ArticleCategory?

    private var filtered: [Article] {
        guard let selectedCategory else { return model.publishedArticles }
        return model.publishedArticles.filter { $0.category == selectedCategory }
    }

    private var featuredArticle: Article? {
        filtered.first
    }

    private var listArticles: [Article] {
        Array(filtered.dropFirst())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.xl) {
                    header

                    if filtered.isEmpty {
                        EmptyStateView(
                            symbol: "newspaper",
                            message: "Nothing here yet. Try another category or check back soon.",
                            actionTitle: "Show all news",
                            action: { selectedCategory = nil }
                        )
                    } else {
                        if let featuredArticle {
                            NavigationLink(value: ContentRoute.article(featuredArticle.id)) {
                                FeaturedArticleCard(article: featuredArticle)
                            }
                            .buttonStyle(PressableStyle())
                            .cardAppear(0)
                        }

                        VStack(alignment: .leading, spacing: BrickSpacing.m) {
                            SectionHeader(title: selectedCategory == nil ? "Latest news" : selectedCategory?.rawValue ?? "Latest news")
                            ForEach(Array(listArticles.enumerated()), id: \.element.id) { index, article in
                                NavigationLink(value: ContentRoute.article(article.id)) {
                                    CompactArticleRow(article: article)
                                }
                                .buttonStyle(PressableStyle())
                                .cardAppear(index + 1)
                            }
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
                .padding(.top, BrickSpacing.s)
            }
            .background { BrickScreenBackground() }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Pinned chip bar floats on glass so content blurs beneath it.
                categoryChips
                    .padding(.leading, BrickSpacing.l)
                    .padding(.vertical, BrickSpacing.s)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.xs) {
            Text("BIAB NEWS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(BrickColor.gold)
            Text("Latest from the studio")
                .font(BrickFont.pageTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text("Build reveals, Brick Bar updates and mosaic stories.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
        }
    }

    /// Only categories that currently have published articles, with live
    /// counts — so every chip visibly changes the list and none dead-ends.
    private var populatedCategories: [(category: ArticleCategory, count: Int)] {
        ArticleCategory.allCases.compactMap { category in
            let count = model.publishedArticles.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrickSpacing.s) {
                FilterTab(title: "All", count: model.publishedArticles.count, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(populatedCategories, id: \.category) { entry in
                    FilterTab(title: entry.category.rawValue, count: entry.count, isSelected: selectedCategory == entry.category) {
                        selectedCategory = selectedCategory == entry.category ? nil : entry.category
                    }
                }
            }
            .padding(.vertical, BrickSpacing.xs)
        }
    }
}

private struct FilterTab: View {
    var title: String
    var count: Int
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text("\(title) \(count)")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? BrickColor.primaryText : BrickColor.secondaryText)
                Capsule()
                    .fill(isSelected ? BrickColor.gold : Color.clear)
                    .frame(height: 3)
            }
            .padding(.horizontal, BrickSpacing.xs)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FeaturedArticleCard: View {
    @Environment(AppModel.self) private var model
    var article: Article

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArticleArtwork(article: article)
                .frame(height: 238)
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                HStack(spacing: BrickSpacing.s) {
                    TagBadge(text: article.category.rawValue, tint: BrickColor.gold)
                    if article.isRumour { RumourBadge() }
                    Spacer()
                    Image(systemName: model.isBookmarked(.article, article.id) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(BrickColor.gold)
                }
                Text(article.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: BrickSpacing.l) {
                    Label(AppDate.relative(article.publishedAt ?? article.createdAt), systemImage: "clock")
                    Label("\(model.commentCount(for: .article, contentID: article.id))", systemImage: "bubble.left")
                }
                .font(BrickFont.meta)
                .foregroundStyle(.white.opacity(0.82))
            }
            .padding(BrickSpacing.l)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct CompactArticleRow: View {
    @Environment(AppModel.self) private var model
    var article: Article

    var body: some View {
        HStack(spacing: BrickSpacing.m) {
            ArticleArtwork(article: article)
                .frame(width: 92, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                HStack(spacing: BrickSpacing.xs) {
                    Text(article.category.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BrickColor.gold)
                    if article.isRumour {
                        Text("Rumour")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BrickColor.brickRed)
                    }
                }
                Text(article.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: BrickSpacing.m) {
                    MetaLabel(symbol: "clock", text: "\(article.readTimeMinutes) min")
                    MetaLabel(symbol: "bubble.left", text: "\(model.commentCount(for: .article, contentID: article.id))")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(BrickSpacing.m)
        .background(BrickColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
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
