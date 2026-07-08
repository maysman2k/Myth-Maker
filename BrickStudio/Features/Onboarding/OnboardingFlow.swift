import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    private let slides: [(symbol: String, tint: Color, title: String, body: String)] = [
        ("newspaper", BrickColor.gold, "Brick news, builds and reviews", "Daily brick-building news and honest kit reviews, written for collectors and builders."),
        ("square.grid.3x3", BrickColor.brickRed, "Create mosaics from photos", "Turn any photo into a brick-style mosaic preview — then have us build it for real."),
        ("wrench.and.screwdriver", BrickColor.stadiumGreen, "Request custom builds", "Stadiums, landmarks, gifts — send your idea to The Brick Bar and we'll turn it into bricks."),
        ("bookmark", Color(hex: 0x20325C), "Save favourites, join in", "Bookmark what you love, rate the sets you've built, and join the conversation.")
    ]

    var body: some View {
        VStack(spacing: BrickSpacing.l) {
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)
                    .padding(BrickSpacing.l)
            }
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    VStack(spacing: BrickSpacing.xl) {
                        BrickArtView(seed: index * 97 + 13, tint: slide.tint, symbol: slide.symbol)
                            .frame(width: 240, height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                        Text(slide.title)
                            .font(BrickFont.pageTitle)
                            .foregroundStyle(BrickColor.primaryText)
                            .multilineTextAlignment(.center)
                        Text(slide.body)
                            .font(BrickFont.body)
                            .foregroundStyle(BrickColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BrickSpacing.xl)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < slides.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < slides.count - 1 ? "Next" : "Start Building")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudButtonStyle())
            .padding(.horizontal, BrickSpacing.xl)
            .padding(.bottom, BrickSpacing.xl)
        }
        .background(BrickColor.background)
    }

    private func finish() {
        model.hasCompletedOnboarding = true
        model.persist()
    }
}
