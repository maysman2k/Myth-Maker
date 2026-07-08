import SwiftUI
import PhotosUI

/// The Mosaic Maker flow (§13): pick a photo, choose style/size/colour mode,
/// generate a brick-mapped preview with estimates, then save or send on.
struct MosaicMakerView: View {
    @Environment(AppModel.self) private var model

    @State private var pickedItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var style: MosaicStyle = .portrait
    @State private var size: MosaicSize = .medium
    @State private var colourMode: MosaicColourMode = .fullColour
    @State private var title = ""
    @State private var isGenerating = false
    @State private var output: MosaicRenderer.Output?
    @State private var generationFailed = false
    @State private var savedProjectID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("Upload a photo and turn it into a brick-style mosaic preview.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)

                photoSection
                if sourceImage != nil {
                    settingsSection
                    generateButton
                }
                if isGenerating {
                    HStack(spacing: BrickSpacing.m) {
                        ProgressView()
                        Text("Mapping your photo to bricks…")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(BrickSpacing.l)
                }
                if generationFailed {
                    Label("Something went wrong generating the preview. Try another photo.", systemImage: "exclamationmark.triangle")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.brickRed)
                }
                if let output {
                    resultSection(output)
                }
                privacyNote
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("Mosaic Maker")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    sourceImage = image
                    output = nil
                    savedProjectID = nil
                    generationFailed = false
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            if let sourceImage {
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label(sourceImage == nil ? "Choose a photo" : "Try another photo", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: sourceImage == nil))
            if sourceImage == nil {
                Text("Tip: tight crops with strong contrast make the best mosaics. Portraits with plain backgrounds are the sweet spot.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text("Style")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.s) {
                        ForEach(MosaicStyle.allCases) { option in
                            FilterChip(title: option.rawValue, isSelected: style == option) { style = option }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text("Size")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                HStack(spacing: BrickSpacing.s) {
                    ForEach(MosaicSize.allCases) { option in
                        FilterChip(title: option.rawValue, isSelected: size == option) { size = option }
                    }
                }
                Text(size.approximateDimensions)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            }
            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text("Colour mode")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrickSpacing.s) {
                        ForEach(MosaicColourMode.allCases) { option in
                            FilterChip(title: option.rawValue, isSelected: colourMode == option) { colourMode = option }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: BrickSpacing.xs) {
                Text("Name your design (optional)")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                TextField("e.g. Dad's 60th portrait", text: $title)
                    .padding(BrickSpacing.m)
                    .background(BrickColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
            }
        }
    }

    private var generateButton: some View {
        Button {
            generate()
        } label: {
            Text(output == nil ? "Generate Preview" : "Regenerate")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudButtonStyle())
        .disabled(isGenerating)
    }

    private func resultSection(_ output: MosaicRenderer.Output) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            SectionHeader(title: "Your mosaic preview")
            Image(uiImage: output.preview)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BrickColor.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                statRow("Dimensions", size.approximateDimensions)
                statRow("Estimated bricks", "\(output.estimate.brickCount)")
                statRow("Colours used", "\(output.estimate.colourCount)")
                statRow("Difficulty", output.estimate.difficulty.rawValue)
            }
            .padding(BrickSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brickCard()

            VStack(spacing: BrickSpacing.m) {
                Button {
                    sendToBrickBar()
                } label: {
                    Text("Send to The Brick Bar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed))

                HStack(spacing: BrickSpacing.m) {
                    Button {
                        saveProject()
                    } label: {
                        Text(savedProjectID == nil ? "Save Design" : "Saved ✓")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.gold, prominent: false))
                    .disabled(savedProjectID != nil)

                    ShareLink(
                        item: Image(uiImage: output.preview),
                        preview: SharePreview("My brick mosaic preview", image: Image(uiImage: output.preview))
                    ) {
                        Text("Share")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudButtonStyle(tint: BrickColor.stadiumGreen, prominent: false))
                }
            }
        }
    }

    private var privacyNote: some View {
        Text("Your photos stay private on this device and are only used to build your mosaic preview.")
            .font(.system(size: 12))
            .foregroundStyle(BrickColor.secondaryText)
            .padding(.top, BrickSpacing.s)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrickColor.primaryText)
        }
    }

    private func generate() {
        guard let sourceImage else { return }
        isGenerating = true
        generationFailed = false
        output = nil
        savedProjectID = nil
        let selectedSize = size
        let selectedMode = colourMode
        Task.detached(priority: .userInitiated) {
            let result = MosaicRenderer.generate(from: sourceImage, size: selectedSize, colourMode: selectedMode)
            await MainActor.run {
                isGenerating = false
                if let result {
                    output = result
                } else {
                    generationFailed = true
                }
            }
        }
    }

    @discardableResult
    private func saveProject() -> MosaicProject? {
        guard model.requireAccount(), let userID = model.currentUserID else { return nil }
        guard let output, let sourceImage else { return nil }
        if let savedProjectID, let existing = model.mosaics.first(where: { $0.id == savedProjectID }) {
            return existing
        }
        guard let originalFilename = ImageStore.save(sourceImage),
              let previewFilename = ImageStore.save(output.preview) else {
            model.showToast("Couldn't save the design. Try again.", symbol: "exclamationmark.triangle")
            return nil
        }
        let project = MosaicProject(
            id: UUID(),
            userID: userID,
            title: title,
            style: style,
            size: size,
            widthStuds: size.studs.width,
            heightStuds: size.studs.height,
            colourMode: colourMode,
            estimatedBrickCount: output.estimate.brickCount,
            estimatedColourCount: output.estimate.colourCount,
            difficulty: output.estimate.difficulty,
            originalImageFilename: originalFilename,
            previewImageFilename: previewFilename,
            status: .generated,
            createdAt: Date(),
            updatedAt: Date()
        )
        model.saveMosaic(project)
        savedProjectID = project.id
        return project
    }

    private func sendToBrickBar() {
        guard let project = saveProject() else { return }
        model.sendMosaicToBrickBar(project.id)
    }
}
