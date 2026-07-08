import SwiftUI

struct CreateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrickSpacing.l) {
                    NavigationLink {
                        MosaicMakerView()
                    } label: {
                        featureCard(
                            title: "Mosaic Maker",
                            subtitle: "Upload a photo and turn it into a brick-style mosaic preview.",
                            symbol: "square.grid.3x3",
                            tint: BrickColor.gold,
                            seed: 11
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LessonsView()
                    } label: {
                        featureCard(
                            title: "Studio Lessons",
                            subtitle: "Design, scale, colour and technique — learn how we build.",
                            symbol: "graduationcap",
                            tint: BrickColor.stadiumGreen,
                            seed: 22
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SavedDesignsView()
                    } label: {
                        featureCard(
                            title: "Saved Designs",
                            subtitle: model.myMosaics.isEmpty ? "Your mosaic projects will live here." : "\(model.myMosaics.count) design\(model.myMosaics.count == 1 ? "" : "s") saved.",
                            symbol: "folder",
                            tint: Color(hex: 0x20325C),
                            seed: 33
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RequestFlowView()
                    } label: {
                        featureCard(
                            title: "Request a Custom Build",
                            subtitle: "Send your idea to The Brick Bar and we'll turn it into bricks.",
                            symbol: "wrench.and.screwdriver",
                            tint: BrickColor.brickRed,
                            seed: 44
                        )
                    }
                    .buttonStyle(.plain)

                    LegalDisclaimerFooter()
                }
                .padding(.horizontal, BrickSpacing.l)
            }
            .background(BrickColor.background)
            .navigationTitle("Create")
            .contentRouteDestinations()
        }
    }

    private func featureCard(title: String, subtitle: String, symbol: String, tint: Color, seed: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BrickArtView(seed: seed, tint: tint, symbol: symbol)
                .frame(height: 110)
            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text(title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Text(subtitle)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding(BrickSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .brickCard()
    }
}

struct SavedDesignsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: BrickSpacing.l) {
                if model.myMosaics.isEmpty {
                    EmptyStateView(
                        symbol: "square.grid.3x3",
                        message: model.isSignedIn
                            ? "No designs yet. Turn a photo into a brick mosaic and it'll appear here."
                            : "Sign in to save mosaic designs to your profile.",
                        actionTitle: model.isSignedIn ? nil : "Sign In",
                        action: model.isSignedIn ? nil : { model.isShowingAuth = true }
                    )
                } else {
                    ForEach(model.myMosaics) { project in
                        MosaicProjectCard(project: project)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Saved Designs")
    }
}

struct MosaicProjectCard: View {
    @Environment(AppModel.self) private var model
    var project: MosaicProject

    var body: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            if let preview = ImageStore.load(project.previewImageFilename) {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Text(project.title.isEmpty ? project.style.rawValue : project.title)
                    .font(BrickFont.cardTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                if project.status == .sentToBrickBar {
                    TagBadge(text: "Sent to Brick Bar", tint: BrickColor.stadiumGreen)
                }
            }
            Text("\(project.widthStuds)×\(project.heightStuds) studs · ~\(project.estimatedBrickCount) bricks · \(project.estimatedColourCount) colours · \(project.difficulty.rawValue)")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            HStack(spacing: BrickSpacing.m) {
                if project.status != .sentToBrickBar {
                    Button("Send to Brick Bar") {
                        model.sendMosaicToBrickBar(project.id)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                }
                Button(role: .destructive) {
                    model.deleteMosaic(project.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(BrickColor.brickRed)
                .accessibilityLabel("Delete design")
                Spacer()
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }
}
