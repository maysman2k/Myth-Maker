import SwiftUI

struct ArticleDetailView: View {
    @Environment(AppModel.self) private var model
    var articleID: UUID

    private var article: Article? {
        model.articles.first { $0.id == articleID }
    }

    var body: some View {
        Group {
            if let article {
                content(for: article)
            } else {
                EmptyStateView(symbol: "newspaper", message: "Something went wrong loading this article. Try again in a moment.")
            }
        }
        .background(BrickColor.background)
        .onAppear { model.incrementView(.article, articleID) }
    }

    private func content(for article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                BrickArtView(seed: article.id.artSeed, tint: article.category.artTint, symbol: article.category.symbol)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: BrickSpacing.s) {
                    TagBadge(text: article.category.rawValue)
                    if article.isRumour { RumourBadge() }
                }

                Text(article.title)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)

                Text(article.summary)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BrickColor.secondaryText)

                HStack(spacing: BrickSpacing.l) {
                    MetaLabel(symbol: "person", text: article.authorName)
                    MetaLabel(symbol: "calendar", text: AppDate.medium(article.publishedAt ?? article.createdAt))
                    MetaLabel(symbol: "clock", text: "\(article.readTimeMinutes) min read")
                }

                if article.isRumour {
                    Label("This story has not been officially confirmed.", systemImage: "exclamationmark.triangle")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                        .padding(BrickSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BrickColor.brickRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                MarkdownBody(markdown: article.bodyMarkdown)

                if !article.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BrickSpacing.s) {
                            ForEach(article.tags, id: \.self) { tag in
                                TagBadge(text: "#\(tag)", tint: BrickColor.secondaryText)
                            }
                        }
                    }
                }

                if !article.sources.isEmpty {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Text("Sources used for this article")
                            .font(BrickFont.cardTitle)
                            .foregroundStyle(BrickColor.primaryText)
                        ForEach(article.sources) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    Label(source.name, systemImage: "link")
                                        .font(BrickFont.meta)
                                        .foregroundStyle(BrickColor.gold)
                                }
                            }
                        }
                    }
                    .padding(BrickSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }

                if article.aiAssisted {
                    Text("Drafted with AI assistance and reviewed by Bricks in a Bag before publishing.")
                        .font(.system(size: 12))
                        .foregroundStyle(BrickColor.secondaryText)
                }

                EngagementBar(
                    contentType: .article,
                    contentID: article.id,
                    likeCount: article.likeCount,
                    shareText: "Check this out on Bricks in a Bag: \(article.title) — https://bricksinabag.com/news/\(article.slug)"
                )

                relatedArticles(for: article)

                Divider()

                if article.commentsEnabled {
                    CommentsSectionView(
                        contentType: .article,
                        contentID: article.id,
                        prompt: commentPrompt(for: article)
                    )
                }
                LegalDisclaimerFooter()
            }
            .padding(.horizontal, BrickSpacing.l)
            .padding(.top, BrickSpacing.m)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func relatedArticles(for article: Article) -> some View {
        let related = model.publishedArticles
            .filter { $0.id != article.id && ($0.category == article.category || !Set($0.tags).isDisjoint(with: article.tags)) }
            .prefix(3)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Related stories")
                ForEach(Array(related)) { relatedArticle in
                    NavigationLink(value: ContentRoute.article(relatedArticle.id)) {
                        HStack(spacing: BrickSpacing.m) {
                            BrickArtView(seed: relatedArticle.id.artSeed, tint: relatedArticle.category.artTint, symbol: relatedArticle.category.symbol)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(relatedArticle.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BrickColor.primaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(relatedArticle.category.rawValue)
                                    .font(BrickFont.meta)
                                    .foregroundStyle(BrickColor.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(BrickSpacing.m)
                        .brickCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func commentPrompt(for article: Article) -> String {
        switch article.category {
        case .officialReveals, .newSets: return "What do you think of this reveal?"
        case .stadiumBuilds: return "Which stadium should be next?"
        case .rumours: return "Rumour or real? Share your read."
        default: return "What do you make of this?"
        }
    }
}
