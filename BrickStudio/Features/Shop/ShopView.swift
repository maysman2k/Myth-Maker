import SwiftUI

struct ShopView: View {
    @Environment(AppModel.self) private var model
    @State private var categoryFilter: ProductCategory?

    private var filtered: [Product] {
        guard let categoryFilter else { return model.activeProducts }
        return model.activeProducts.filter { $0.category == categoryFilter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    Text("Hand-built stadiums, mosaics and display models from Bricks in a Bag.")
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.secondaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BrickSpacing.s) {
                            FilterChip(title: "All", isSelected: categoryFilter == nil) { categoryFilter = nil }
                            ForEach(ProductCategory.allCases) { category in
                                FilterChip(title: category.rawValue, isSelected: categoryFilter == category) {
                                    categoryFilter = categoryFilter == category ? nil : category
                                }
                            }
                        }
                    }

                    if filtered.isEmpty {
                        EmptyStateView(
                            symbol: "bag",
                            message: "Nothing in this category yet. New builds land regularly.",
                            actionTitle: "Show everything",
                            action: { categoryFilter = nil }
                        )
                    } else {
                        ForEach(filtered) { product in
                            NavigationLink(value: ContentRoute.product(product.id)) {
                                ProductCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
            }
            .background(BrickColor.background)
            .navigationTitle("Shop")
            .contentRouteDestinations()
        }
    }
}

struct ProductCard: View {
    @Environment(AppModel.self) private var model
    var product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrickArtView(seed: product.id.artSeed, tint: BrickColor.stadiumGreen, symbol: productSymbol)
                .frame(height: 150)
                .overlay(alignment: .topTrailing) {
                    if product.status == .soldOut {
                        TagBadge(text: "Sold out", tint: BrickColor.brickRed)
                            .padding(BrickSpacing.s)
                    }
                }
            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                HStack {
                    TagBadge(text: product.category.rawValue)
                    Spacer()
                    Button {
                        model.toggleBookmark(.product, product.id)
                    } label: {
                        Image(systemName: model.isBookmarked(.product, product.id) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(BrickColor.gold)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save product")
                }
                Text(product.name)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text(product.shortDescription)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(product.priceLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(BrickColor.primaryText)
                    Spacer()
                    Text(product.availability)
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                }
            }
            .padding(BrickSpacing.l)
        }
        .brickCard()
    }

    private var productSymbol: String {
        switch product.category {
        case .stadiumBuilds, .footballStadiums, .customStadiums: return "sportscourt"
        case .mosaics: return "square.grid.3x3"
        case .gifts: return "gift"
        case .accessories: return "key"
        case .limitedRuns: return "seal"
        default: return "cube.transparent"
        }
    }
}
