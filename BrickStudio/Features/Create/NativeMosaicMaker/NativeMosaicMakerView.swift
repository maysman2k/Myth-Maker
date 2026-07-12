import PhotosUI
import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

struct NativeMosaicMakerView: View {
    @Environment(\.openURL) private var openURL

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var croppedSourceImage: UIImage?
    @State private var imageForCropping: UIImage?
    @State private var isCropperPresented = false
    @State private var imageForCroppingHasTransparency = false
    @State private var croppedImageHasTransparency = false
    @State private var imageQualityWarnings: [String] = []
    @State private var brightnessAdjustment: Double = 0
    @State private var contrastAdjustment: Double = 1
    @State private var hasShownImageEditing = false
    @State private var selectedGrid = MosaicGrid.small
    @State private var results: [MosaicResultKey: MosaicResult] = [:]
    @State private var exportFilesByKey: [MosaicResultKey: ExportFiles] = [:]
    @State private var hasTransparentBackground = false
    @State private var selectedBackground = MosaicBackground.white
    @State private var blackAndWhite = false
    @State private var moderationDecision = ImageModerationDecision.notChecked
    @State private var errorMessage: String?
    @State private var isPreparingPhoto = false
    @State private var isGenerating = false
    @State private var purchaseSelection: PurchaseSelection?
    @State private var isMenuOpen = false
    @State private var selectedInfoPage: InfoPage?
    @State private var isTunePanelVisible = false
    @State private var showBlockedImagePlaceholder = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                logoBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        introLine

                        if selectedImage == nil {
                            if showBlockedImagePlaceholder {
                                blockedImagePlaceholderView
                                if shouldShowModerationPanel {
                                    moderationPanel
                                }
                            } else {
                                openingExample
                            }
                            photoPicker
                        }

                        if let selectedImage {
                            selectedImageView(selectedImage)
                            qualityWarningPanel
                            if shouldShowModerationPanel {
                                moderationPanel
                            }
                        }

                        if let result = currentResult {
                            resultView(result)
                            gridPicker
                        }

                        if hasShownImageEditing {
                            tunePhotoButton
                        }

                        if isTunePanelVisible {
                            imageEditPanel
                        }

                        if selectedImageData != nil && currentResult == nil && (!hasShownImageEditing || !isTunePanelVisible) {
                            generateButton
                        }

                        if selectedImage != nil {
                            clearButton
                        }

                        if currentResult != nil {
                            purchaseButtons
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }

                if isGenerating || isPreparingPhoto {
                    generatingOverlay
                }

                if isMenuOpen {
                    sideMenuOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: selectedPhoto) {
                await loadSelectedPhoto()
            }
            .onChange(of: selectedBackground) { _, _ in
                invalidateGeneratedMosaics()
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .sheet(item: $purchaseSelection) { selection in
                PurchaseSheet(
                    selection: selection,
                    result: selection.result,
                    variant: selection.variant
                )
            }
            .sheet(item: $selectedInfoPage) { page in
                InfoPageView(page: page)
            }
            .fullScreenCover(isPresented: $isCropperPresented) {
                if let imageForCropping {
                    ImageCropperView(
                        image: imageForCropping,
                        preservesTransparency: imageForCroppingHasTransparency
                    ) { croppedImage in
                        acceptCroppedImage(croppedImage)
                    } onCancel: {
                        clearImage()
                    }
                }
            }
        }
    }

    private var currentResult: MosaicResult? {
        results[currentResultKey]
    }

    private var currentVariant: MosaicVariant {
        blackAndWhite ? .blackAndWhite : .colour
    }

    private var currentResultKey: MosaicResultKey {
        MosaicResultKey(grid: selectedGrid, variant: currentVariant)
    }

    private var logoBackground: some View {
        GeometryReader { proxy in
            let tileSize: CGFloat = 150
            let columns = Int(proxy.size.width / tileSize) + 3
            let rows = Int(proxy.size.height / tileSize) + 4

            VStack(spacing: 22) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 22) {
                        ForEach(0..<columns, id: \.self) { _ in
                            Image("BIABLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 112, height: 112)
                                .rotationEffect(.degrees(-18))
                                .opacity(0.07)
                        }
                    }
                    .offset(x: row.isMultiple(of: 2) ? -42 : 30)
                }
            }
            .offset(x: -30, y: -38)
        }
        .allowsHitTesting(false)
    }

    private var sideMenuOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) {
                            isMenuOpen = false
                        }
                    }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bricks in a Bag")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text("Mosaic Maker")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.64))
                        }

                        Spacer()

                        Button {
                            withAnimation(.snappy) {
                                isMenuOpen = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.36), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .overlay(AppTheme.ink.opacity(0.18))

                    ForEach(InfoPage.allCases) { page in
                        Button {
                            selectedInfoPage = page
                            withAnimation(.snappy) {
                                isMenuOpen = false
                            }
                        } label: {
                            Label(page.title, systemImage: page.systemImage)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if let url = URL(string: "https://www.bricksinabag.com") {
                            openURL(url)
                        }
                    } label: {
                        Label("Visit bricksinabag.com", systemImage: "safari.fill")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("support@bricksinabag.com")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink.opacity(0.62))
                }
                .padding(18)
                .frame(width: min(320, proxy.size.width * 0.82))
                .frame(maxHeight: .infinity)
                .background(AppTheme.cardFill)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.30))
                        .frame(width: 1)
                }
                .transition(.move(edge: .trailing))
                .shadow(color: .black.opacity(0.24), radius: 18, x: -8, y: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.ink)
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.yellow)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Mosaic Maker")
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text("Bricks in a Bag")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.62))
            }

            Spacer()

            Button {
                withAnimation(.snappy) {
                    isMenuOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.orange, in: Circle())
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(.white.opacity(0.28))
                            .frame(width: 10, height: 10)
                            .offset(x: 7, y: 6)
                    }
                    .shadow(color: AppTheme.orange.opacity(0.30), radius: 7, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private var introLine: some View {
        Text("Create a custom mosaic and order genuine LEGO® bricks to build it.")
            .font(.callout.weight(.bold))
            .foregroundStyle(AppTheme.ink.opacity(0.74))
            .padding(.vertical, 2)
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            HStack(spacing: 10) {
                Image(systemName: selectedImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.orange)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedImage == nil ? "Choose photo" : "Choose different photo")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text("Pick a JPG or PNG from your library")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.62))
                    Text("Only upload images you own or have permission to use.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            }
            .padding(12)
            .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var openingExample: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From favourite photo to brick-built keepsake in just a few taps.")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Image("OpeningExample")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .padding(8)
                .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 7)
        }
    }

    private var clearButton: some View {
        Button {
            clearImage()
        } label: {
            Label("Clear image and start again", systemImage: "xmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isGenerating)
    }

    @ViewBuilder
    private var optionsPanel: some View {
        if selectedImage != nil {
            VStack(alignment: .leading, spacing: 10) {
                if hasTransparentBackground {
                    Picker("Background", selection: $selectedBackground) {
                        ForEach(MosaicBackground.allCases) { background in
                            Text(background.label).tag(background)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.subheadline.weight(.bold))
                    .tint(AppTheme.ink)
                }

                Toggle(isOn: $blackAndWhite) {
                    Text("Black and white mosaic")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
                .tint(AppTheme.ink)
            }
            .padding(12)
            .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private var gridPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mosaic size")
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 8) {
                ForEach(MosaicGrid.allCases) { grid in
                    Button {
                        selectedGrid = grid
                    } label: {
                        Text(grid.label)
                            .font(.callout.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selectedGrid == grid ? .white : AppTheme.ink)
                        .background {
                            if selectedGrid == grid {
                                AppTheme.blackSheen
                            } else {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(.white.opacity(0.36))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppTheme.highlightFill, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        }
    }

    private var generateButton: some View {
        Button {
            generateMosaic()
        } label: {
            if isGenerating {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Label("Generate mosaic", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(SheenButtonStyle())
        .disabled(selectedImageData == nil || isGenerating)
    }

    private func selectedImageView(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected photo")
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .padding(8)
                .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 7)
        }
    }

    private var blockedImagePlaceholderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected photo")
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            if let placeholder = UIImage(named: "BlockedImagePlaceholder") {
                Image(uiImage: placeholder)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .padding(8)
                    .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 18))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.36), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 7)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.36), lineWidth: 1)
                    }
            }
        }
    }

    @ViewBuilder
    private var qualityWarningPanel: some View {
        if !imageQualityWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Label("Photo quality note", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                ForEach(imageQualityWarnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.70))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.yellow.opacity(0.24), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.orange.opacity(0.26), lineWidth: 1)
            }
        }
    }

    private var moderationPanel: some View {
        HStack(spacing: 10) {
            moderationIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(moderationTitle)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                if let message = moderationDecision.message {
                    Text(message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.66))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var moderationIcon: some View {
        switch moderationDecision {
        case .checking:
            ProgressView()
                .tint(AppTheme.ink)
                .frame(width: 32, height: 32)
        case .approved:
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
        case .blocked:
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.red)
                .frame(width: 32, height: 32)
        case .unavailable:
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.orange)
                .frame(width: 32, height: 32)
        case .notChecked:
            Image(systemName: "shield.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.ink.opacity(0.65))
                .frame(width: 32, height: 32)
        }
    }

    private var moderationTitle: String {
        switch moderationDecision {
        case .notChecked:
            return "Image will be checked before generation"
        case .checking:
            return "Checking image"
        case .approved:
            return "Image ready"
        case .blocked:
            return "Choose another image"
        case .unavailable:
            return "Safety check not connected"
        }
    }

    private var shouldShowModerationPanel: Bool {
        switch moderationDecision {
        case .checking, .blocked, .unavailable:
            return true
        case .notChecked, .approved:
            return false
        }
    }

    private func resultView(_ result: MosaicResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated mosaic")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            Image(uiImage: result.preview)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .padding(7)
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.48), lineWidth: 1)
                }

        }
        .padding(12)
        .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.18))
                .frame(height: 42)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 7)
    }

    private var tunePhotoButton: some View {
        Button {
            withAnimation(.snappy) {
                isTunePanelVisible.toggle()
            }
        } label: {
            Label("Tune photo", systemImage: "slider.horizontal.3")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private var purchaseButtons: some View {
        HStack(spacing: 10) {
            Button {
                startPurchase(.fullKit)
            } label: {
                VStack(spacing: 2) {
                    Text("Purchase")
                    Text("Full Kit with")
                    Text("Genuine LEGO® bricks")
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PurchaseTileButtonStyle())

            Button {
                startPurchase(.instructions)
            } label: {
                VStack(spacing: 2) {
                    Text("Purchase")
                    Text("Instructions")
                    Text("and brick list")
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PurchaseTileButtonStyle())
        }
    }

    private func startPurchase(_ product: PurchaseProduct) {
        guard let result = currentResult else {
            errorMessage = "Please generate a mosaic first."
            return
        }

        purchaseSelection = PurchaseSelection(
            product: product,
            result: result,
            grid: selectedGrid,
            variant: currentVariant
        )
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                TurningBrickView()
                    .frame(width: 78, height: 58)

                Text(isPreparingPhoto ? "Preparing photo" : "Generating mosaic")
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 14)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }

        do {
            isPreparingPhoto = true
            brightnessAdjustment = 0
            contrastAdjustment = 1
            hasShownImageEditing = false
            isTunePanelVisible = false
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                throw MosaicGeneratorError.invalidImage
            }
            let image = try await Task.detached(priority: .userInitiated) {
                try UIImage.preparedForCropping(from: data)
            }.value
            let hasTransparency = MosaicGenerator.hasTransparency(data)

            await MainActor.run {
                showBlockedImagePlaceholder = false
                imageForCropping = image
                imageForCroppingHasTransparency = hasTransparency
                isCropperPresented = true
                isPreparingPhoto = false
                moderationDecision = .notChecked
                invalidateGeneratedMosaics()
            }
        } catch {
            isPreparingPhoto = false
            errorMessage = error.localizedDescription
        }
    }

    private func acceptCroppedImage(_ image: UIImage) {
        croppedSourceImage = image
        croppedImageHasTransparency = imageForCroppingHasTransparency
        hasTransparentBackground = imageForCroppingHasTransparency
        brightnessAdjustment = 0
        contrastAdjustment = 1
        applyImageAdjustments(invalidateResults: false)
        isTunePanelVisible = false
        moderationDecision = .notChecked
        imageQualityWarnings = analyzeImageQuality(image)
        hasShownImageEditing = false
        invalidateGeneratedMosaics()
        isCropperPresented = false
        imageForCropping = nil
    }

    private var imageEditPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tune photo", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Button {
                    brightnessAdjustment = 0
                    contrastAdjustment = 1
                    applyImageAdjustments()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 12) {
                Text("Black and white")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Toggle("", isOn: $blackAndWhite)
                    .labelsHidden()
                    .tint(AppTheme.ink)
            }

            if hasTransparentBackground {
                HStack(spacing: 12) {
                    Text("Background colour")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)

                    Spacer()

                    Picker("", selection: $selectedBackground) {
                        ForEach(MosaicBackground.allCases) { background in
                            Text(background.label).tag(background)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.subheadline.weight(.bold))
                    .tint(AppTheme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Brightness")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink.opacity(0.74))
                Slider(value: $brightnessAdjustment, in: -0.35...0.35)
                    .tint(AppTheme.ink)
                    .onChange(of: brightnessAdjustment) { _, _ in
                        applyImageAdjustments()
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Contrast")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink.opacity(0.74))
                Slider(value: $contrastAdjustment, in: 0.65...1.65)
                    .tint(AppTheme.ink)
                    .onChange(of: contrastAdjustment) { _, _ in
                        applyImageAdjustments()
                    }
            }

            Label("Regenerate after editing to preview the updated mosaic.", systemImage: "wand.and.stars")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.66))

            Button {
                generateMosaic()
            } label: {
                Label("Regenerate mosaic", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SheenButtonStyle())
            .disabled(selectedImageData == nil || isGenerating)
        }
        .padding(12)
        .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        }
    }

    private func applyImageAdjustments(invalidateResults shouldInvalidate: Bool = true) {
        guard let croppedSourceImage else { return }
        let adjustedImage = croppedSourceImage.adjusted(
            brightness: Float(brightnessAdjustment),
            contrast: Float(contrastAdjustment)
        ) ?? croppedSourceImage
        selectedImage = adjustedImage
        let pngData = adjustedImage.pngData()
        let adjustedImageHasTransparency = croppedImageHasTransparency || (pngData.map(MosaicGenerator.hasTransparency) ?? false)
        hasTransparentBackground = adjustedImageHasTransparency
        if adjustedImageHasTransparency {
            selectedImageData = pngData
        } else {
            selectedImageData = adjustedImage.jpegData(compressionQuality: 0.92) ?? pngData
            selectedBackground = .white
        }
        imageQualityWarnings = analyzeImageQuality(adjustedImage)
        moderationDecision = .notChecked

        if shouldInvalidate {
            invalidateGeneratedMosaics()
        }
    }

    private func moderationUploadData(for image: UIImage, fallback: Data) -> Data {
        let maxBytes = 5 * 1024 * 1024
        let preparedImage = resizedForModeration(image)
        var quality: CGFloat = 0.75

        while quality >= 0.35 {
            if let data = preparedImage.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        return preparedImage.jpegData(compressionQuality: 0.3) ?? fallback
    }

    private func resizedForModeration(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1_600
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let bounds = CGRect(origin: .zero, size: targetSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            image.draw(in: bounds)
        }
    }

    private func handleBlockedImage(_ decision: ImageModerationDecision) {
        selectedPhoto = nil
        selectedImage = nil
        selectedImageData = nil
        croppedSourceImage = nil
        imageForCropping = nil
        imageForCroppingHasTransparency = false
        isCropperPresented = false
        imageQualityWarnings = []
        brightnessAdjustment = 0
        contrastAdjustment = 1
        hasShownImageEditing = false
        isTunePanelVisible = false
        hasTransparentBackground = false
        croppedImageHasTransparency = false
        selectedBackground = .white
        moderationDecision = decision
        showBlockedImagePlaceholder = true
        invalidateGeneratedMosaics()
    }

    private func generateMosaic() {
        guard let imageData = selectedImageData ?? selectedImage?.pngData() else {
            errorMessage = "Please choose a photo first."
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let moderationData = moderationUploadData(for: selectedImage ?? UIImage(), fallback: imageData)
                await MainActor.run {
                    moderationDecision = .checking
                }

                let decision = await ImageModerationService.check(imageData: moderationData)
                guard decision.canGenerate else {
                    await MainActor.run {
                        handleBlockedImage(decision)
                        isGenerating = false
                    }
                    return
                }

                let delay = UInt64(Int.random(in: 3...6)) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)

                var generatedFiles: [MosaicResultKey: ExportFiles] = [:]
                var generatedResultsByKey: [MosaicResultKey: MosaicResult] = [:]

                for grid in MosaicGrid.allCases {
                    for variant in MosaicVariant.allCases {
                        let generated = try MosaicGenerator.generate(
                            from: imageData,
                            grid: grid,
                            background: hasTransparentBackground ? selectedBackground : .white,
                            blackAndWhite: variant == .blackAndWhite
                        )
                        let key = MosaicResultKey(grid: grid, variant: variant)
                        generatedResultsByKey[key] = generated
                        generatedFiles[key] = try ExportFiles.make(for: generated, variant: variant)
                    }
                }

                await MainActor.run {
                    moderationDecision = decision
                    results = generatedResultsByKey
                    exportFilesByKey = generatedFiles
                    hasShownImageEditing = true
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func invalidateGeneratedMosaics() {
        results = [:]
        exportFilesByKey = [:]
    }

    private func analyzeImageQuality(_ image: UIImage) -> [String] {
        var warnings: [String] = []
        let shortestSide = min(image.size.width * image.scale, image.size.height * image.scale)
        if shortestSide < 900 {
            warnings.append("This photo is quite low resolution, so the finished mosaic may look blocky or distorted.")
        }

        if estimatedDetailScore(for: image) > 0.22 {
            warnings.append("This crop has a lot of fine detail. Faces, text, crowds, and busy backgrounds may not translate cleanly into LEGO pixels.")
        }

        return warnings
    }

    private func estimatedDetailScore(for image: UIImage) -> Double {
        let sampleSize = 48
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleSize, height: sampleSize))
        let sampled = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        }

        guard let cgImage = sampled.cgImage else { return 0 }
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * sampleSize
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        var totalDifference = 0
        var comparisons = 0

        for y in 0..<sampleSize {
            for x in 0..<(sampleSize - 1) {
                let lhs = ((y * sampleSize) + x) * bytesPerPixel
                let rhs = lhs + bytesPerPixel
                let lhsLuma = Int(pixels[lhs]) + Int(pixels[lhs + 1]) + Int(pixels[lhs + 2])
                let rhsLuma = Int(pixels[rhs]) + Int(pixels[rhs + 1]) + Int(pixels[rhs + 2])
                totalDifference += abs(lhsLuma - rhsLuma)
                comparisons += 1
            }
        }

        guard comparisons > 0 else { return 0 }
        return Double(totalDifference) / Double(comparisons * 765)
    }

    private func clearImage() {
        selectedPhoto = nil
        selectedImage = nil
        selectedImageData = nil
        croppedSourceImage = nil
        imageForCropping = nil
        imageForCroppingHasTransparency = false
        croppedImageHasTransparency = false
        isCropperPresented = false
        isPreparingPhoto = false
        imageQualityWarnings = []
        brightnessAdjustment = 0
        contrastAdjustment = 1
        hasShownImageEditing = false
        isTunePanelVisible = false
        showBlockedImagePlaceholder = false
        hasTransparentBackground = false
        selectedBackground = .white
        blackAndWhite = false
        moderationDecision = .notChecked
        purchaseSelection = nil
        invalidateGeneratedMosaics()
    }
}

private enum InfoPage: String, CaseIterable, Identifiable {
    case about
    case refund
    case privacy
    case terms
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about:
            return "About Bricks in a Bag"
        case .refund:
            return "Refund policy"
        case .privacy:
            return "Privacy policy"
        case .terms:
            return "Terms and conditions"
        case .delivery:
            return "Delivery"
        }
    }

    var systemImage: String {
        switch self {
        case .about:
            return "info.circle.fill"
        case .refund:
            return "arrow.uturn.backward.circle.fill"
        case .privacy:
            return "lock.shield.fill"
        case .terms:
            return "doc.text.fill"
        case .delivery:
            return "shippingbox.fill"
        }
    }
}

private struct InfoPageView: View {
    let page: InfoPage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(sections, id: \.heading) { section in
                        PolicySectionView(section: section)
                    }

                    if page == .about {
                        Button {
                            if let url = URL(string: "https://www.bricksinabag.com") {
                                openURL(url)
                            }
                        } label: {
                            Label("Open bricksinabag.com", systemImage: "safari.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SheenButtonStyle())
                    }

                    Text("LEGO® is a trademark of the LEGO Group, which does not sponsor, authorise or endorse this app.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.58))
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                }
            }
        }
    }

    private var sections: [PolicySection] {
        switch page {
        case .about:
            return [
                PolicySection(
                    heading: "About",
                    body: "Bricks in a Bag creates buildable LEGO-inspired football stadium kits, instructions and bespoke builds. The original idea grew from a lifelong love of LEGO and football, starting with St James' Park and expanding into more stadiums and custom projects."
                ),
                PolicySection(
                    heading: "Mosaic Maker",
                    body: "Mosaic Maker turns your chosen photo into a LEGO-inspired mosaic design. You can crop the image, choose the mosaic size, preview the result, and order either digital instructions or a full kit using genuine LEGO® bricks."
                ),
                PolicySection(
                    heading: "Custom builds",
                    body: "If you would like a custom build, a special design, or help with a bespoke idea, email support@bricksinabag.com and the Bricks in a Bag team will review what is possible."
                )
            ]
        case .refund:
            return [
                PolicySection(
                    heading: "Returns",
                    body: "Physical products have a 30-day return window from the date you receive the item. Items must be unused, in their original condition and in the original packaging. Because custom mosaic kits are made specifically from your chosen image and crop, a full refund may not always be possible if the order has been made correctly and you simply change your mind. Contact support@bricksinabag.com before sending anything back, as returns without approval cannot be accepted."
                ),
                PolicySection(
                    heading: "Digital products",
                    body: "Digital instructions and digital instruction packs cannot be returned or refunded once the download link or email delivery has been sent. If files are missing, incorrect or do not work as expected, contact support@bricksinabag.com so the issue can be resolved."
                ),
                PolicySection(
                    heading: "Damages and missing parts",
                    body: "Check your order when it arrives. If it is damaged, incorrect, defective or missing parts, contact support@bricksinabag.com and replacement parts or a resolution will be arranged as soon as possible."
                ),
                PolicySection(
                    heading: "Refunds",
                    body: "Approved refunds are processed after the returned item has been received and inspected. Refunds are made to the original payment method and exclude any delivery charges."
                )
            ]
        case .privacy:
            return [
                PolicySection(
                    heading: "What we collect",
                    body: "Bricks in a Bag is the data controller for Mosaic Maker. Contact support@bricksinabag.com for privacy questions. Mosaic Maker collects the information needed to create and fulfil your order: your uploaded photo, cropped or adjusted image, generated mosaic files, moderation result, name, email address, delivery address, selected mosaic size, selected style, order reference, payment status, and payment reference."
                ),
                PolicySection(
                    heading: "How it is used",
                    body: "Your data is used to check the uploaded image, generate the mosaic, take payment, create the order, send notifications, prepare fulfilment files, deliver digital instructions where applicable, prevent misuse, and respond to customer service queries."
                ),
                PolicySection(
                    heading: "Lawful basis",
                    body: "Bricks in a Bag processes order and fulfilment data because it is needed to provide the product or service you buy. Payment and accounting records may be kept to meet legal obligations. Security, fraud prevention, support, and service improvement are handled under legitimate interests. Uploaded images are processed because you ask us to create the mosaic and confirm you have permission to use the image."
                ),
                PolicySection(
                    heading: "Where it goes",
                    body: "Payments are processed by Square. Order records may be created in Wix. Uploaded images may be checked by Google Vision moderation. Mosaic and order files are stored in Google Cloud Storage. Order emails are sent through the email provider configured by Bricks in a Bag. Apple and iOS may handle app-level services such as photo selection and payment-sheet presentation. Bricks in a Bag does not sell or rent your personal information."
                ),
                PolicySection(
                    heading: "Retention",
                    body: "Order files, generated mosaic files, and digital instruction files are kept for fulfilment and support for up to 3 months, after which they may be deleted. Payment, tax, accounting, dispute, and customer service records may be kept for longer where required by law or legitimate business need. Customers should keep their emailed instructions and attachments."
                ),
                PolicySection(
                    heading: "Your rights",
                    body: "You can ask to view, correct or delete personal data by contacting support@bricksinabag.com. Some order information may need to be retained where required for fulfilment, accounting, dispute handling or legal obligations."
                )
            ]
        case .terms:
            return [
                PolicySection(
                    heading: "Use of the app",
                    body: "By using Mosaic Maker, you agree to use it only for images and orders you are entitled to submit. You must own the uploaded image or have permission to use it, and the mosaic must not infringe copyright, trademark, privacy or other third-party rights. You must not upload unlawful, offensive, adult, violent, or otherwise unsuitable content."
                ),
                PolicySection(
                    heading: "Content and designs",
                    body: "Bricks in a Bag logos, images, designs, instructions, and generated fulfilment files remain the property of Bricks in a Bag or their respective owners. You remain responsible for the rights in any image you upload. Bricks in a Bag may refuse or cancel orders where an uploaded image appears to infringe third-party rights. Instructions and generated fulfilment files must not be copied, resold, or redistributed without permission. LEGO® is a trademark of the LEGO Group, which does not sponsor, authorise, or endorse this app."
                ),
                PolicySection(
                    heading: "Orders and cancellation",
                    body: "Full mosaic kits are personalised and custom-made from your chosen image and crop. Change-of-mind cancellation may not apply once production has started, but your statutory rights are not affected if an item is faulty, incorrect, or not as described. Digital instructions are supplied by email after payment; by purchasing them, you agree to immediate digital delivery and acknowledge that cancellation rights may be lost once the files have been sent."
                ),
                PolicySection(
                    heading: "Accuracy",
                    body: "Bricks in a Bag makes every effort to keep product, delivery and app information accurate and up to date, but custom mosaic results depend on the quality, crop and detail of the uploaded photo."
                ),
                PolicySection(
                    heading: "External links",
                    body: "The app may link to external sites including bricksinabag.com, Square and Wix-powered services. Bricks in a Bag is not responsible for the content or policies of external websites."
                )
            ]
        case .delivery:
            return [
                PolicySection(
                    heading: "Instructions only",
                    body: "Instructions-only purchases are delivered by email after the order is placed and payment has been confirmed. The email will include the mosaic preview, digital instructions, and brick list. Please save the email and attachments, as order files may be deleted from fulfilment storage after 3 months."
                ),
                PolicySection(
                    heading: "Mosaic and brick orders",
                    body: "Full mosaic kit orders are reviewed after payment. Genuine LEGO® brick requirements are checked and ordered, then the kit is packed and shipped once the required bricks are available. Courier tracking and delivery updates are provided directly by the courier where available."
                ),
                PolicySection(
                    heading: "Timing",
                    body: "The estimated fulfilment time for mosaic and brick orders is up to 21 working days. Bricks in a Bag will always aim to ship earlier where possible."
                ),
                PolicySection(
                    heading: "Payment and delivery costs",
                    body: "Payments are taken securely in app by Square. Any delivery charge shown at checkout is part of the order total. If a delivery issue occurs, contact support@bricksinabag.com with your order reference."
                ),
                PolicySection(
                    heading: "Questions",
                    body: "For delivery questions, order updates or support, email support@bricksinabag.com with your order reference."
                )
            ]
        }
    }
}

private struct PolicySection: Hashable {
    let heading: String
    let body: String
}

private struct PolicySectionView: View {
    let section: PolicySection

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(section.heading)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
            Text(section.body)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private enum PurchaseProduct: String, Identifiable {
    case fullKit
    case instructions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullKit:
            return "Full mosaic kit"
        case .instructions:
            return "Instructions only"
        }
    }

    var systemImage: String {
        switch self {
        case .fullKit:
            return "shippingbox.fill"
        case .instructions:
            return "doc.richtext.fill"
        }
    }

    var includedItems: [String] {
        switch self {
        case .fullKit:
            return [
                "LEGO parts for the selected mosaic",
                "Digital build instructions",
                "Brick list prepared for fulfilment"
            ]
        case .instructions:
            return [
                "Digital build instructions",
                "Brick list",
                "Mosaic preview by email"
            ]
        }
    }
}

private struct PurchaseSelection: Identifiable {
    let id = UUID()
    let product: PurchaseProduct
    let result: MosaicResult
    let grid: MosaicGrid
    let variant: MosaicVariant
}

private struct ImageCropperView: View {
    let image: UIImage
    let preservesTransparency: Bool
    let onUseCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotationDegrees: CGFloat = 0
    @State private var isFlipped = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(220, proxy.size.width - 32)
                let availableHeight = max(260, proxy.size.height - 260)
                let side = min(availableWidth, availableHeight, 460)
                let cropSide = side * 0.54
                let minimumScale = minimumScaleToCoverCrop(stageSide: side, cropSide: cropSide)
                let activeScale = max(scale, minimumScale)
                let activeOffset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: activeScale)

                ScrollView {
                    VStack(spacing: 16) {
                        Spacer(minLength: 8)

                        ZStack {
                            Color.black.opacity(0.88)

                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: side, height: side)
                                .scaleEffect(x: isFlipped ? -activeScale : activeScale, y: activeScale)
                                .rotationEffect(.degrees(rotationDegrees))
                                .offset(activeOffset)

                            cropOverlay(stageSide: side, cropSide: cropSide)
                        }
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.white.opacity(0.34), lineWidth: 3)
                        }
                        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = clampedOffset(
                                        CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        ),
                                        stageSide: side,
                                        cropSide: cropSide,
                                        scale: activeScale
                                    )
                                }
                                .onEnded { _ in
                                    offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: activeScale)
                                    lastOffset = offset
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, minimumScale), 5)
                                    offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: max(scale, minimumScale))
                                }
                                .onEnded { _ in
                                    scale = min(max(scale, minimumScale), 5)
                                    lastScale = scale
                                    offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: scale)
                                    lastOffset = offset
                                }
                        )
                        .onAppear {
                            scale = max(scale, minimumScale)
                            lastScale = scale
                            offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: scale)
                            lastOffset = offset
                        }

                        HStack(spacing: 10) {
                            Button {
                                let newRotation = rotationDegrees - 90
                                rotationDegrees = newRotation
                                scale = max(scale, minimumScaleToCoverCrop(stageSide: side, cropSide: cropSide, rotationDegrees: newRotation))
                                lastScale = scale
                                offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: scale, rotationDegrees: newRotation)
                                lastOffset = offset
                            } label: {
                                Label("Rotate left", systemImage: "rotate.left")
                                    .labelStyle(.iconOnly)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                let newRotation = rotationDegrees + 90
                                rotationDegrees = newRotation
                                scale = max(scale, minimumScaleToCoverCrop(stageSide: side, cropSide: cropSide, rotationDegrees: newRotation))
                                lastScale = scale
                                offset = clampedOffset(offset, stageSide: side, cropSide: cropSide, scale: scale, rotationDegrees: newRotation)
                                lastOffset = offset
                            } label: {
                                Label("Rotate right", systemImage: "rotate.right")
                                    .labelStyle(.iconOnly)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                isFlipped.toggle()
                            } label: {
                                Label("Flip", systemImage: "arrow.left.and.right")
                                    .labelStyle(.iconOnly)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                let resetScale = minimumScaleToCoverCrop(stageSide: side, cropSide: cropSide, rotationDegrees: 0)
                                scale = resetScale
                                lastScale = resetScale
                                offset = .zero
                                lastOffset = .zero
                                rotationDegrees = 0
                                isFlipped = false
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .labelStyle(.iconOnly)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal, 18)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Choose the square crop")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text("Move and zoom the photo so the part you want becomes the mosaic.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.68))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                        Button {
                            if let croppedImage = image.squareCrop(
                                stageSide: side,
                                cropSide: cropSide,
                                scale: activeScale,
                                offset: activeOffset,
                                rotationDegrees: rotationDegrees,
                                isFlipped: isFlipped,
                                preservesTransparency: preservesTransparency
                            ) {
                                onUseCrop(croppedImage)
                                dismiss()
                            }
                        } label: {
                            Label("Use this crop", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SheenButtonStyle())
                        .padding(.horizontal, 18)

                        Spacer(minLength: 8)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Crop photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                }
            }
        }
    }

    private func cropOverlay(stageSide: CGFloat, cropSide: CGFloat) -> some View {
        let inset = (stageSide - cropSide) / 2

        return ZStack {
            VStack(spacing: 0) {
                Color.black.opacity(0.42)
                    .frame(height: inset)
                HStack(spacing: 0) {
                    Color.black.opacity(0.42)
                        .frame(width: inset)
                    Color.white.opacity(0.20)
                        .frame(width: cropSide, height: cropSide)
                    Color.black.opacity(0.42)
                        .frame(width: inset)
                }
                Color.black.opacity(0.42)
                    .frame(height: inset)
            }

            Rectangle()
                .stroke(.white.opacity(0.74), lineWidth: 4)
                .frame(width: cropSide, height: cropSide)

            Rectangle()
                .stroke(.white.opacity(0.26), lineWidth: 1)
                .frame(width: cropSide - 12, height: cropSide - 12)
        }
        .allowsHitTesting(false)
    }

    private func minimumScaleToCoverCrop(
        stageSide: CGFloat,
        cropSide: CGFloat,
        rotationDegrees: CGFloat? = nil
    ) -> CGFloat {
        let displaySize = transformedDisplaySize(stageSide: stageSide, rotationDegrees: rotationDegrees ?? self.rotationDegrees)
        guard displaySize.width > 0, displaySize.height > 0 else { return 1 }
        return max(cropSide / displaySize.width, cropSide / displaySize.height, 0.35)
    }

    private func clampedOffset(
        _ proposed: CGSize,
        stageSide: CGFloat,
        cropSide: CGFloat,
        scale: CGFloat,
        rotationDegrees: CGFloat? = nil
    ) -> CGSize {
        let displaySize = transformedDisplaySize(stageSide: stageSide, rotationDegrees: rotationDegrees ?? self.rotationDegrees)
        let limitX = max(0, ((displaySize.width * scale) - cropSide) / 2)
        let limitY = max(0, ((displaySize.height * scale) - cropSide) / 2)
        return CGSize(
            width: min(max(proposed.width, -limitX), limitX),
            height: min(max(proposed.height, -limitY), limitY)
        )
    }

    private func transformedDisplaySize(stageSide: CGFloat, rotationDegrees: CGFloat) -> CGSize {
        let fittedScale = min(stageSide / image.size.width, stageSide / image.size.height)
        let fittedSize = CGSize(width: image.size.width * fittedScale, height: image.size.height * fittedScale)
        let quarterTurns = Int((rotationDegrees / 90).rounded()).modulo(4)
        if quarterTurns == 1 || quarterTurns == 3 {
            return CGSize(width: fittedSize.height, height: fittedSize.width)
        }
        return fittedSize
    }
}

private extension Int {
    func modulo(_ modulus: Int) -> Int {
        let result = self % modulus
        return result >= 0 ? result : result + modulus
    }
}

private struct SummaryItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.ink.opacity(0.62))
            Text(value)
                .font(.callout.weight(.black))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.18))
                .frame(height: 12)
        }
    }
}

private struct PurchaseSheet: View {
    let selection: PurchaseSelection
    let result: MosaicResult
    let variant: MosaicVariant

    @Environment(\.dismiss) private var dismiss
    @State private var isStartingCheckout = false
    @State private var checkoutError: String?
    @State private var orderReference: String?
    @State private var confirmedOrderStatus: OrderStatus?
    @State private var isCardEntryPresented = false
    @State private var customerName = ""
    @State private var customerEmail = ""
    @State private var addressLine = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var acceptedCustomTerms = false
    @State private var acceptedDigitalTerms = false
    @State private var acceptedImageRights = false
    @State private var isShareSheetPresented = false
    @State private var validationAttempted = false

    private var variantLabel: String {
        switch variant {
        case .colour:
            return "Colour"
        case .blackAndWhite:
            return "Black and white"
        }
    }

    private var priceLabel: String {
        switch selection.product {
        case .fullKit:
            return Self.currencyFormatter.string(from: NSDecimalNumber(value: Double(result.price) / 100)) ?? "\(result.price)p"
        case .instructions:
            return "£5.00"
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private var orderSummary: String {
        """
        Mosaic Make Order By Bricks in a Bag

        Product: \(selection.product.title)
        Mosaic size: \(result.gridLabel)
        Style: \(variantLabel)
        Bricks: \(result.totalBricks)
        Colours: \(result.parts.count)
        Price: \(priceLabel)

        https://www.bricksinabag.com
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: selection.product.systemImage)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.blackSheen, in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selection.product.title)
                                .font(.title3.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text("Review the mosaic before checkout")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.62))
                        }

                        Spacer()
                    }

                    if let confirmedOrderStatus {
                        CheckoutConfirmationView(status: confirmedOrderStatus, preview: result.preview)
                    } else {
                        Image(uiImage: result.preview)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(8)
                            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        HStack(spacing: 10) {
                            SummaryItem(label: "Size", value: result.gridLabel)
                            SummaryItem(label: "Style", value: variantLabel)
                        }

                        HStack(spacing: 10) {
                            SummaryItem(label: "Bricks", value: result.totalBricks.formatted())
                            SummaryItem(label: "Price", value: priceLabel)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Included")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(AppTheme.ink)

                            ForEach(selection.product.includedItems, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink.opacity(0.72))
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))

                        if selection.product == .fullKit {
                            deliveryDetailsForm
                        } else {
                            contactDetailsForm
                            digitalInstructionsConfirmation
                        }
                        imageRightsConfirmation

                        VStack(spacing: 8) {
                            if selection.product == .fullKit {
                                Button {
                                    startSquareCheckout()
                                } label: {
                                    if isStartingCheckout {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Label("Pay securely in app", systemImage: "creditcard.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(SheenButtonStyle())
                                .disabled(isStartingCheckout)

                                if validationAttempted && !isFullKitCheckoutValid {
                                    Text(fullKitCheckoutRequirementMessage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red.opacity(0.82))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                Button {
                                    startSquareCheckout()
                                } label: {
                                    if isStartingCheckout {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Label("Pay securely in app", systemImage: "creditcard.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(SheenButtonStyle())
                                .disabled(isStartingCheckout)

                                if validationAttempted && !isInstructionsCheckoutValid {
                                    Text(instructionsCheckoutRequirementMessage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red.opacity(0.82))
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            Button {
                                isShareSheetPresented = true
                            } label: {
                                Label("Share order details", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        if let checkoutError {
                            Text(checkoutError)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red.opacity(0.82))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                    }
                }
            }
        }
        .sheet(isPresented: $isCardEntryPresented) {
            SquareCardEntryView { sourceID in
                try await completeSquarePayment(sourceID: sourceID)
            } onComplete: { success in
                isCardEntryPresented = false
                if !success && confirmedOrderStatus == nil {
                    checkoutError = "Payment was cancelled."
                    isStartingCheckout = false
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: isCardEntryPresented) { _, isPresented in
            if !isPresented && isStartingCheckout && confirmedOrderStatus == nil {
                checkoutError = "Payment was cancelled."
                isStartingCheckout = false
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityShareSheet(items: shareItems)
        }
    }

    private var deliveryDetailsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Delivery details")
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            TextField("Name", text: $customerName)
                .textContentType(.name)
                .validationStroke(validationAttempted && customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            TextField("Email", text: $customerEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .validationStroke(validationAttempted && !isCustomerEmailValid)
            TextField("Address line", text: $addressLine)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .validationStroke(validationAttempted && addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .onChange(of: addressLine) { _, newValue in
                    splitAutofilledAddressIfNeeded(newValue)
                }
            HStack(spacing: 8) {
                TextField("Town / City", text: $city)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)
                    .validationStroke(validationAttempted && city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .onChange(of: city) { _, newValue in
                        splitAutofilledAddressIfNeeded(newValue)
                    }
                TextField("Postcode", text: $postalCode)
                    .textContentType(.postalCode)
                    .textInputAutocapitalization(.characters)
                    .validationStroke(validationAttempted && postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Toggle(isOn: $acceptedCustomTerms) {
                Text("I understand this is a personalised, custom-made mosaic kit created from my chosen image using genuine LEGO® bricks. Change-of-mind cancellation may not apply once production has started, but my statutory rights are not affected if the item is faulty, incorrect, or not as described.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.68))
            }
            .tint(AppTheme.ink)
            .padding(.top, 4)
            .validationStroke(validationAttempted && !acceptedCustomTerms)
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
    }

    private var contactDetailsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Email delivery details")
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            TextField("Name", text: $customerName)
                .textContentType(.name)
                .validationStroke(validationAttempted && customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            TextField("Email", text: $customerEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .validationStroke(validationAttempted && !isCustomerEmailValid)

            Text("Your instructions, mosaic preview, and brick list will be emailed after payment.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.64))
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
    }

    private var digitalInstructionsConfirmation: some View {
        Toggle(isOn: $acceptedDigitalTerms) {
            Text("I agree that digital instructions will be supplied by email immediately after payment, and I understand that cancellation rights may be lost once the files have been sent.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.68))
        }
        .tint(AppTheme.ink)
        .padding(12)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
        .validationStroke(validationAttempted && !acceptedDigitalTerms)
    }

    private var imageRightsConfirmation: some View {
        Toggle(isOn: $acceptedImageRights) {
            Text("I confirm I own or have permission to use the uploaded image, and that creating this mosaic will not infringe copyright, trademark, privacy or other rights.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.68))
        }
        .tint(AppTheme.ink)
        .padding(12)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
        .validationStroke(validationAttempted && !acceptedImageRights)
    }

    private var fullKitCheckoutRequirementMessage: String {
        if customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter your name to continue."
        }
        if !isCustomerEmailValid {
            return "Enter a valid email address to continue."
        }
        if addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the address line to continue."
        }
        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the town or city to continue."
        }
        if postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter the postcode to continue."
        }
        if !acceptedCustomTerms {
            return "Please confirm the custom-made kit note to continue."
        }
        return "Please confirm you have permission to use the uploaded image."
    }

    private var instructionsCheckoutRequirementMessage: String {
        if customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter your name to continue."
        }
        if !isCustomerEmailValid {
            return "Enter a valid email address to continue."
        }
        if !acceptedDigitalTerms {
            return "Please confirm the digital delivery note to continue."
        }
        return "Please confirm you have permission to use the uploaded image."
    }

    private var isCustomerEmailValid: Bool {
        let email = customerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.range(
            of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private var isFullKitCheckoutValid: Bool {
        checkoutCustomer.isComplete && isCustomerEmailValid && acceptedCustomTerms && acceptedImageRights
    }

    private var isInstructionsCheckoutValid: Bool {
        checkoutCustomer.hasContactDetails && isCustomerEmailValid && acceptedDigitalTerms && acceptedImageRights
    }

    private var checkoutCustomer: CheckoutCustomer {
        CheckoutCustomer(
            email: customerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            name: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            country: "GB"
        )
    }

    private func splitAutofilledAddressIfNeeded(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(",") || trimmed.contains("\n") || containsUKPostcode(trimmed) else { return }
        guard city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let parsed = parseAutofilledAddress(trimmed) else { return }

        if addressLine != parsed.addressLine {
            addressLine = parsed.addressLine
        }
        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            city = parsed.city
        }
        if postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            postalCode = parsed.postcode
        }
    }

    private func parseAutofilledAddress(_ value: String) -> (addressLine: String, city: String, postcode: String)? {
        guard let postcodeRange = value.range(
            of: #"[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        let postcode = String(value[postcodeRange])
            .uppercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let beforePostcode = String(value[..<postcodeRange.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines))
        let components = beforePostcode
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard components.count >= 2 else { return nil }

        let city = components.last ?? ""
        let address = components.dropLast().joined(separator: ", ")
        guard !address.isEmpty, !city.isEmpty else { return nil }
        return (address, city, postcode)
    }

    private func containsUKPostcode(_ value: String) -> Bool {
        value.range(
            of: #"[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func startSquareCheckout() {
        validationAttempted = true
        isStartingCheckout = true
        checkoutError = nil
        confirmedOrderStatus = nil

        let hasRequiredCustomerDetails = selection.product == .fullKit
            ? isFullKitCheckoutValid
            : isInstructionsCheckoutValid
        guard hasRequiredCustomerDetails else {
            isStartingCheckout = false
            checkoutError = selection.product == .fullKit ? fullKitCheckoutRequirementMessage : instructionsCheckoutRequirementMessage
            return
        }

        guard SquarePaymentConfiguration.configureSDK() else {
            isStartingCheckout = false
            checkoutError = "Square is not configured in this build. Add SQUARE_APPLICATION_ID to BrickStudio's build settings or Info.plist."
            return
        }

        isCardEntryPresented = true
    }

    private func completeSquarePayment(sourceID: String) async throws {
        do {
            let confirmation: SquarePaymentConfirmation
            if selection.product == .fullKit {
                confirmation = try await CheckoutService.createSquareFullKitPayment(
                    result: result,
                    variant: checkoutVariantValue,
                    sourceID: sourceID,
                    customer: checkoutCustomer
                )
            } else {
                confirmation = try await CheckoutService.createSquareInstructionsPayment(
                    result: result,
                    variant: checkoutVariantValue,
                    sourceID: sourceID,
                    customer: checkoutCustomer
                )
            }

            await MainActor.run {
                orderReference = confirmation.orderReference
                confirmedOrderStatus = OrderStatus(
                    orderReference: confirmation.orderReference,
                    status: "paid",
                    paid: true,
                    paidAt: nil,
                    product: selection.product.rawValue,
                    gridSize: result.gridSize,
                    variant: checkoutVariantValue,
                    priceGBP: selection.product == .fullKit ? result.price : 500,
                    customerEmail: checkoutCustomer.email,
                    customerName: checkoutCustomer.name,
                    deliveryAddress: selection.product == .fullKit
                        ? DeliveryAddress(
                            formattedAddress: nil,
                            addressLine: checkoutCustomer.addressLine,
                            city: checkoutCustomer.city,
                            postalCode: checkoutCustomer.postalCode,
                            country: checkoutCustomer.country
                        )
                        : nil,
                    message: confirmation.message
                )
                checkoutError = nil
                isStartingCheckout = false
            }
        } catch {
            await MainActor.run {
                checkoutError = error.localizedDescription
                isStartingCheckout = false
            }
            throw error
        }
    }

    private var checkoutVariantValue: String {
        switch variant {
        case .colour:
            return "colour"
        case .blackAndWhite:
            return "black_and_white"
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = [orderSummary]
        if let imageURL = result.preview.sharePNGURL(filename: "biab_mosaic_preview_\(result.gridSize)x\(result.gridSize).png") {
            items.append(imageURL)
        }
        return items
    }
}

private struct CheckoutConfirmationView: View {
    let status: OrderStatus
    let preview: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Payment confirmed", systemImage: "checkmark.seal.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(AppTheme.ink)

            Image(uiImage: preview)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .padding(8)
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(status.product == "instructions" ? "Your payment has been received. Your instructions and brick list will be emailed to you." : "Your payment has been received. Your mosaic kit is now on order.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.72))

            if status.product == "instructions" {
                Text("Digital orders are usually delivered within a few minutes.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.64))
            } else {
                Text("Please allow up to 21 days for dispatch.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.64))
            }

            Text("Reference: \(status.orderReference)")
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.ink.opacity(0.58))

            if let deliveryAddress = status.deliveryAddress?.displayText, !deliveryAddress.isEmpty {
                Divider()
                    .overlay(AppTheme.ink.opacity(0.18))

                Text("Delivery address")
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                Text(deliveryAddress)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.70))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    func validationStroke(_ isInvalid: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isInvalid ? Color.red.opacity(0.86) : Color.clear, lineWidth: 2)
        }
    }
}

private enum MosaicVariant: String, CaseIterable, Hashable {
    case colour
    case blackAndWhite

    var fileSuffix: String {
        switch self {
        case .colour:
            return "colour"
        case .blackAndWhite:
            return "black_white"
        }
    }
}

private struct MosaicResultKey: Hashable {
    let grid: MosaicGrid
    let variant: MosaicVariant
}

private enum AppTheme {
    static let ink = Color(red: 0.13, green: 0.11, blue: 0.08)
    static let yellow = Color(red: 1.0, green: 0.79, blue: 0.14)
    static let orange = Color(red: 0.91, green: 0.38, blue: 0.10)

    static let background = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.83, blue: 0.25),
            Color(red: 0.98, green: 0.65, blue: 0.17),
            Color(red: 0.94, green: 0.50, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.77, blue: 0.22),
            Color(red: 0.98, green: 0.59, blue: 0.14)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let highlightFill = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.66, blue: 0.16),
            Color(red: 0.94, green: 0.45, blue: 0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let blackSheen = LinearGradient(
        colors: [
            Color(red: 0.34, green: 0.31, blue: 0.27),
            Color.black,
            Color(red: 0.16, green: 0.14, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct SheenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(AppTheme.blackSheen)
                    Capsule()
                        .fill(.white.opacity(configuration.isPressed ? 0.10 : 0.24))
                        .frame(height: 12)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 17))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 5 : 9, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct CompactSheenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(AppTheme.blackSheen)
                    Capsule()
                        .fill(.white.opacity(configuration.isPressed ? 0.08 : 0.20))
                        .frame(height: 8)
                        .padding(.horizontal, 10)
                        .padding(.top, 5)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct PurchaseTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black))
            .lineLimit(3)
            .minimumScaleFactor(0.78)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(AppTheme.blackSheen)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(configuration.isPressed ? 0.08 : 0.22))
                        .frame(height: 16)
                        .padding(.horizontal, 3)
                        .padding(.top, 3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.white.opacity(configuration.isPressed ? 0.24 : 0.36), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TurningBrickView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let rotation = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6 * 360

            Image("BIABLogo")
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.26), radius: 9, x: 0, y: 6)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0.12, y: 1, z: 0))
        }
    }
}

private struct ExportFiles {
    let ldrawURL: URL
    let partsURL: URL

    static func make(for result: MosaicResult, variant: MosaicVariant) throws -> ExportFiles {
        let folder = FileManager.default.temporaryDirectory
        let ldrawURL = folder.appendingPathComponent("biab_mosaic_\(result.gridSize)x\(result.gridSize)_\(variant.fileSuffix).ldr")
        let partsURL = folder.appendingPathComponent("biab_mosaic_\(result.gridSize)x\(result.gridSize)_\(variant.fileSuffix)_parts.json")

        try result.ldraw.write(to: ldrawURL, atomically: true, encoding: .utf8)

        let payload = PartsPayload(
            gridSize: result.gridLabel,
            totalBricks: result.totalBricks,
            priceGBP: result.price,
            parts: result.parts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: partsURL, options: .atomic)

        return ExportFiles(ldrawURL: ldrawURL, partsURL: partsURL)
    }
}

private struct PartsPayload: Codable {
    let gridSize: String
    let totalBricks: Int
    let priceGBP: Int
    let parts: [MosaicPart]

    enum CodingKeys: String, CodingKey {
        case gridSize = "grid_size"
        case totalBricks = "total_bricks"
        case priceGBP = "price_gbp"
        case parts
    }
}

private extension UIImage {
    private static let sharedCIContext = CIContext(options: nil)

    static func preparedForCropping(from data: Data) throws -> UIImage {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            throw MosaicGeneratorError.invalidImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_800
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw MosaicGeneratorError.invalidImage
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    func normalizedForEditing() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func adjusted(brightness: Float, contrast: Float) -> UIImage? {
        guard brightness != 0 || contrast != 1 else { return self }
        guard let inputImage = CIImage(image: self) else { return nil }

        let filter = CIFilter.colorControls()
        filter.inputImage = inputImage
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = 1

        guard let outputImage = filter.outputImage,
              let cgImage = Self.sharedCIContext.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    func squareCrop(
        stageSide: CGFloat,
        cropSide: CGFloat,
        scale userScale: CGFloat,
        offset: CGSize,
        rotationDegrees: CGFloat,
        isFlipped: Bool,
        preservesTransparency: Bool = false
    ) -> UIImage? {
        let outputSide: CGFloat = 1400
        let fittedScale = min(stageSide / size.width, stageSide / size.height)
        let fittedSize = CGSize(width: size.width * fittedScale, height: size.height * fittedScale)
        let cropOrigin = CGPoint(x: (stageSide - cropSide) / 2, y: (stageSide - cropSide) / 2)
        let outputScale = outputSide / cropSide
        let imageCenter = CGPoint(x: (stageSide / 2) + offset.width, y: (stageSide / 2) + offset.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = !preservesTransparency
        format.scale = 1

        return UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format).image { context in
            if preservesTransparency {
                context.cgContext.clear(CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
            } else {
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
            }

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.scaleBy(x: outputScale, y: outputScale)
            cgContext.translateBy(x: -cropOrigin.x, y: -cropOrigin.y)
            cgContext.translateBy(x: imageCenter.x, y: imageCenter.y)
            cgContext.rotate(by: rotationDegrees * .pi / 180)
            cgContext.scaleBy(x: isFlipped ? -userScale : userScale, y: userScale)

            draw(
                in: CGRect(
                    x: -fittedSize.width / 2,
                    y: -fittedSize.height / 2,
                    width: fittedSize.width,
                    height: fittedSize.height
                )
            )
            cgContext.restoreGState()
        }
    }

    func sharePNGURL(filename: String) -> URL? {
        guard let data = pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

#Preview {
    NativeMosaicMakerView()
}
