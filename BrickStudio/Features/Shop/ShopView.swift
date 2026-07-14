import SwiftUI

struct ShopView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SecureShopWebView(
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView()
                        .padding(BrickSpacing.l)
                        .background(BrickColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
                }

                if let errorMessage {
                    VStack(spacing: BrickSpacing.m) {
                        EmptyStateView(
                            symbol: "wifi.exclamationmark",
                            message: errorMessage,
                            actionTitle: "Try Again",
                            action: {
                                self.errorMessage = nil
                                isLoading = true
                                ShopWebViewStore.shared.reload()
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrickColor.background)
                }
            }
            .background { BrickScreenBackground() }
            .toolbar(.hidden, for: .navigationBar)
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
