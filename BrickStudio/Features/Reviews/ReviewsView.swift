import SwiftUI

struct ReviewsView: View {
    @Environment(AppModel.self) private var model
    @State private var brandFilter: String?
    @State private var categoryFilter: ReviewCategory?

    private var brands: [String] {
        Array(Set(model.publishedReviews.map(\.brand))).sorted()
    }

    private var filtered: [Review] {
        model.publishedReviews.filter { review in
            (brandFilter == nil || review.brand == brandFilter) &&
            (categoryFilter == nil || review.category == categoryFilter)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                filters
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "star.bubble",
                        message: "No reviews match those filters yet.",
                        actionTitle: "Clear filters",
                        action: { brandFilter = nil; categoryFilter = nil }
                    )
                } else {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, review in
                        NavigationLink(value: ContentRoute.review(review.id)) {
                            ReviewCard(review: review)
                        }
                        .buttonStyle(PressableStyle())
                        .cardAppear(index)
                    }
                }
                LegalDisclaimerFooter()
            }
            .padding(.horizontal, BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Reviews")
        .contentRouteDestinations()
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrickSpacing.s) {
                    FilterChip(title: "All brands", isSelected: brandFilter == nil) { brandFilter = nil }
                    ForEach(brands, id: \.self) { brand in
                        FilterChip(title: brand, isSelected: brandFilter == brand) {
                            brandFilter = brandFilter == brand ? nil : brand
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrickSpacing.s) {
                    FilterChip(title: "All categories", isSelected: categoryFilter == nil) { categoryFilter = nil }
                    ForEach(ReviewCategory.allCases) { category in
                        FilterChip(title: category.rawValue, isSelected: categoryFilter == category) {
                            categoryFilter = categoryFilter == category ? nil : category
                        }
                    }
                }
            }
        }
        .padding(.top, BrickSpacing.xs)
    }
}

struct ReviewCard: View {
    @Environment(AppModel.self) private var model
    var review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrickArtView(seed: review.id.artSeed, tint: BrickColor.gold, symbol: "shippingbox")
                .frame(height: 120)
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                HStack {
                    TagBadge(text: review.brand, tint: BrickColor.stadiumGreen)
                    TagBadge(text: review.verdict.rawValue, tint: review.verdict.isPositive ? BrickColor.gold : BrickColor.brickRed)
                    Spacer()
                    StarRatingView(rating: review.ratingOverall)
                }
                Text(review.setName)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text(review.summary)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: BrickSpacing.l) {
                    if let pieces = review.pieceCount {
                        MetaLabel(symbol: "square.grid.2x2", text: "\(pieces) pieces")
                    }
                    MetaLabel(symbol: "sterlingsign.circle", text: review.priceLabel)
                    MetaLabel(symbol: "bubble.left", text: "\(model.commentCount(for: .review, contentID: review.id))")
                    Spacer()
                }
            }
            .padding(BrickSpacing.l)
        }
        .brickCard()
    }
}
