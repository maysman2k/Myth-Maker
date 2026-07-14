import SwiftUI

struct ProductDetailView: View {
    @Environment(AppModel.self) private var model
    var productID: UUID

    private var product: Product? {
        model.products.first { $0.id == productID }
    }

    var body: some View {
        Group {
            if let product {
                content(for: product)
            } else {
                EmptyStateView(symbol: "bag", message: "Something went wrong loading this build. Try again in a moment.")
            }
        }
        .background { BrickScreenBackground() }
        .onAppear { model.incrementView(.product, productID) }
    }

    private func content(for product: Product) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                BrickArtView(seed: product.id.artSeed, tint: BrickColor.stadiumGreen, symbol: "sportscourt")
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                TagBadge(text: product.category.rawValue)

                Text(product.name)
                    .font(BrickFont.pageTitle)
                    .foregroundStyle(BrickColor.primaryText)

                Text(product.priceLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(BrickColor.gold)

                Text(product.description)
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.primaryText)
                    .lineSpacing(4)

                detailsCard(for: product)

                VStack(spacing: BrickSpacing.m) {
                    if product.status == .soldOut {
                        Text("This build is sold out — but we can often make something similar.")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    } else if let url = URL(string: product.externalShopURL) {
                        Link(destination: url) {
                            Text("Buy Now")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen))
                    }
                    NavigationLink {
                        RequestFlowView(prefill: RequestFlowView.Prefill(
                            buildType: .other,
                            title: "About: \(product.name)",
                            description: "I'd like to ask about the \"\(product.name)\" build. "
                        ))
                    } label: {
                        Text("Ask About This Build")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                }

                HStack(spacing: BrickSpacing.xl) {
                    Button {
                        model.toggleBookmark(.product, product.id)
                    } label: {
                        Label(
                            model.isBookmarked(.product, product.id) ? "Saved" : "Save",
                            systemImage: model.isBookmarked(.product, product.id) ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .foregroundStyle(BrickColor.gold)
                    ShareLink(item: "I found this build on Bricks in a Bag: \(product.name) — \(product.externalShopURL)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(BrickColor.secondaryText)
                    Spacer()
                }
                .font(BrickFont.body)
                .frame(minHeight: 44)

                relatedProducts(for: product)
                LegalDisclaimerFooter()
            }
            .padding(.horizontal, BrickSpacing.l)
            .padding(.top, BrickSpacing.m)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailsCard(for product: Product) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            detailRow("Availability", product.availability)
            detailRow("Dimensions", product.dimensions)
            if let pieces = product.pieceCountEstimate {
                detailRow("Estimated pieces", "\(pieces)")
            }
            detailRow("Lead time", product.leadTime)
            detailRow("Delivery", product.deliveryInfo)
        }
        .padding(BrickSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brickCard()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrickColor.primaryText)
        }
    }

    @ViewBuilder
    private func relatedProducts(for product: Product) -> some View {
        let related = model.activeProducts
            .filter { $0.id != product.id && ($0.category == product.category || !Set($0.tags).isDisjoint(with: product.tags)) }
            .prefix(3)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                SectionHeader(title: "Related builds")
                ForEach(Array(related)) { relatedProduct in
                    NavigationLink(value: ContentRoute.product(relatedProduct.id)) {
                        HStack(spacing: BrickSpacing.m) {
                            BrickArtView(seed: relatedProduct.id.artSeed, tint: BrickColor.stadiumGreen, symbol: nil)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(relatedProduct.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BrickColor.primaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(relatedProduct.priceLabel)
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
}
