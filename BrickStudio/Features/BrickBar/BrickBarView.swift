import SwiftUI

struct BrickBarView: View {
    @State private var selectedGalleryImage: BrickBarGalleryImage?

    private let galleryImages = [
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_8d5d23fd4ab34fd4ace172a539a6b85f~mv2.png/v1/fill/w_482,h_642,q_90,enc_avif,quality_auto/cb3f86_8d5d23fd4ab34fd4ace172a539a6b85f~mv2.png"),
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_029f627848634e458639ba573e68a77f~mv2.png/v1/fill/w_484,h_364,q_90,enc_avif,quality_auto/cb3f86_029f627848634e458639ba573e68a77f~mv2.png"),
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_1c5cf2d0692e4dc382899d1add533fb0~mv2.png/v1/fill/w_482,h_362,q_90,enc_avif,quality_auto/cb3f86_1c5cf2d0692e4dc382899d1add533fb0~mv2.png"),
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_66d897676f114574881f2bf2a51577a5f003.jpg/v1/fill/w_482,h_642,q_90,enc_avif,quality_auto/cb3f86_66d897676f114574881f2bf2a51577a5f003.jpg"),
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_3b54126a7db24993956c876a55004d5d~mv2.png/v1/fill/w_482,h_362,q_90,enc_avif,quality_auto/cb3f86_3b54126a7db24993956c876a55004d5d~mv2.png"),
        BrickBarGalleryImage(urlString: "https://static.wixstatic.com/media/cb3f86_00d9b27de3a840b081b8ed5510dd4bdf~mv2.png/v1/fill/w_484,h_646,q_90,enc_avif,quality_auto/cb3f86_00d9b27de3a840b081b8ed5510dd4bdf~mv2.png")
    ]

    private let offers = [
        "Corporate gifts that make a lasting impression",
        "Large display models for offices, receptions, or events",
        "Unique one-off gifts for special occasions or just because",
        "Faithful representations that capture the key essence and personality of your space or object",
        "Personal support throughout, from concept to completion",
        "Flexible kits: choose between fully prebuilt models or build-it-yourself kits"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.xl) {
                    hero
                    intro
                    offerList
                    founderQuote
                    gallery
                    requestCard
                    legalFooter
                }
                .padding(.horizontal, BrickSpacing.l)
                .padding(.top, BrickSpacing.l)
                .padding(.bottom, BrickSpacing.xxl)
            }
            .background { BrickScreenBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedGalleryImage) { image in
            BrickBarImagePreview(image: image) {
                selectedGalleryImage = nil
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.l) {
            RemoteBrickBarImage(
                urlString: "https://static.wixstatic.com/media/cb3f86_d8aea8d70c1d4018b526d5ff0dce13ab~mv2.jpg/v1/fill/w_350,h_350,al_c,lg_1,q_80,enc_avif,quality_auto/The%20Brick%20Bar%20sm.jpg",
                aspectRatio: 1
            )
            .frame(width: 112)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                TagBadge(text: "Custom LEGO(R) Builds", tint: BrickColor.gold)
                Text("Welcome to The Brick Bar")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(BrickColor.primaryText)
                    .textCase(.uppercase)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Custom LEGO(R) builds beyond the stadium.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrickColor.secondaryText)
            }

            NavigationLink {
                RequestFlowView(prefill: RequestFlowView.Prefill(
                    buildType: .displayModel,
                    title: "Custom Brick Bar build",
                    description: ""
                ))
            } label: {
                Label("Start a Custom Request", systemImage: "wrench.and.screwdriver")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Text("Custom LEGO(R) builds beyond the stadium")
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)

            Text("At Bricks in a Bag, we've made our name capturing the magic of sport in brick form, but more and more people have asked, \"Can you build something else?\"")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("So we've opened The Brick Bar, our creative space for commissions that go beyond stadiums. From bespoke corporate gifts to one-of-a-kind passion projects, The Brick Bar exists to bring your vision to life, brick by brick.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Whether it's a miniature version of your business, a memorable personal gift, or a show-stopping display for your office or event, we're happy to explore any idea.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var offerList: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            SectionHeader(title: "What We Offer")

            ForEach(offers, id: \.self) { offer in
                HStack(alignment: .top, spacing: BrickSpacing.m) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BrickColor.stadiumGreen)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 22)
                    Text(offer)
                        .font(BrickFont.body)
                        .foregroundStyle(BrickColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var founderQuote: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.l) {
            RemoteBrickBarImage(
                urlString: "https://static.wixstatic.com/media/cb3f86_1abdfb49040d4b7b8d4ce83e91b6e7e5~mv2.jpg/v1/fill/w_746,h_996,al_c,q_85,usm_0.66_1.00_0.01,enc_avif,quality_auto/IMG_5978_edited.jpg",
                aspectRatio: 0.75
            )

            VStack(alignment: .leading, spacing: BrickSpacing.m) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BrickColor.gold)

                Text("I'm always up for a new challenge, so if you've got an idea, let's talk. Welcome to The Brick Bar. The next round's on us.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BrickColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Peter - Founder and Lead Designer")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            SectionHeader(title: "Recent Builds")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: BrickSpacing.m),
                    GridItem(.flexible(), spacing: BrickSpacing.m)
                ],
                spacing: BrickSpacing.m
            ) {
                ForEach(galleryImages) { image in
                    Button {
                        selectedGalleryImage = image
                    } label: {
                        BrickBarGalleryTile(image: image)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open build image")
                }
            }
        }
    }

    private var requestCard: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Text("Custom Build Request")
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)

            Text("Tell us what you want to build, your deadline, and any useful details. We'll review the idea and come back with the next step.")
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                RequestFlowView(prefill: RequestFlowView.Prefill(
                    buildType: .displayModel,
                    title: "Custom Brick Bar build",
                    description: ""
                ))
            } label: {
                Label("Submit a Request", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var legalFooter: some View {
        Text("LEGO(R) is a trademark of the LEGO group which does not sponsor, authorise or endorse this app.")
            .font(BrickFont.meta)
            .foregroundStyle(BrickColor.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

private struct BrickBarGalleryImage: Identifiable, Hashable {
    var urlString: String
    var id: String { urlString }
}

private struct RemoteBrickBarImage: View {
    var urlString: String
    var aspectRatio: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ZStack {
                    BrickColor.border
                    Image(systemName: "photo")
                        .foregroundStyle(BrickColor.secondaryText)
                }
            case .empty:
                ZStack {
                    BrickColor.border.opacity(0.45)
                    ProgressView()
                }
            @unknown default:
                BrickColor.border
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BrickColor.border, lineWidth: 1)
        )
    }
}

private struct BrickBarGalleryTile: View {
    var image: BrickBarGalleryImage

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: URL(string: image.urlString)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        BrickColor.border
                        Image(systemName: "photo")
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                case .empty:
                    ZStack {
                        BrickColor.border.opacity(0.45)
                        ProgressView()
                    }
                @unknown default:
                    BrickColor.border
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BrickColor.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BrickBarImagePreview: View {
    var image: BrickBarGalleryImage
    var close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: image.urlString)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(BrickSpacing.l)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(.top, BrickSpacing.xl)
            .padding(.trailing, BrickSpacing.l)
            .accessibilityLabel("Close image")
        }
    }
}
