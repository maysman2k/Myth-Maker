import SwiftUI

struct CreateView: View {
    var body: some View {
        NativeMosaicMakerView()
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
            Text("\(project.widthStuds)x\(project.heightStuds) studs - ~\(project.estimatedBrickCount) bricks - \(project.estimatedColourCount) colours - \(project.difficulty.rawValue)")
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
