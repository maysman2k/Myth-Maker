import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PickedStoryVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedStoryVideo(url: copy)
        }
    }
}

struct AdminStoryEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var bodyMarkdown = ""
    @State private var tagsText = ""
    @State private var category: ArticleCategory = .bricksInABagUpdates
    @State private var status: PublishStatus = .draft
    @State private var isRumour = false
    @State private var aiAssisted = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var selectedImageReferences: [String] = []
    @State private var selectedVideoReferences: [String] = []
    @State private var linksText = ""
    @State private var brief = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var isShowingOpenAIKeySheet = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                aiPanel
                storyFields
                mediaPicker
                publishOptions
            }
            .padding(BrickSpacing.l)
        }
        .background { BrickScreenBackground() }
        .navigationTitle("Create Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(status == .published ? "Publish" : "Save") {
                    saveStory()
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $isShowingOpenAIKeySheet) {
            OpenAIKeySheet()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await importImages(from: newItems) }
        }
        .onChange(of: selectedVideoItems) { _, newItems in
            Task { await importVideos(from: newItems) }
        }
    }

    private var aiPanel: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack {
                Label("AI story writer", systemImage: "sparkles")
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                Button("API Key") {
                    isShowingOpenAIKeySheet = true
                }
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.gold)
            }

            TextEditor(text: $brief)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(BrickSpacing.s)
                .background(BrickColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if brief.isEmpty {
                        Text("Brief overview for OpenAI...")
                            .font(BrickFont.body)
                            .foregroundStyle(BrickColor.secondaryText)
                            .padding(.horizontal, BrickSpacing.m)
                            .padding(.vertical, BrickSpacing.m + 2)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                generateStory()
            } label: {
                HStack {
                    if isGenerating { ProgressView().padding(.trailing, 4) }
                    Text(isGenerating ? "Writing story..." : "Generate Story")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(StudButtonStyle())
            .disabled(isGenerating || brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let generationError {
                Label(generationError, systemImage: "exclamationmark.triangle.fill")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.brickRed)
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var storyFields: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Text("Story")
                .font(BrickFont.sectionTitle)
                .foregroundStyle(BrickColor.primaryText)

            editorField("Title", text: $title, minHeight: 44)
            editorField("Summary", text: $summary, minHeight: 86)

            Picker("Category", selection: $category) {
                ForEach(ArticleCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(BrickColor.gold)

            VStack(alignment: .leading, spacing: BrickSpacing.s) {
                HStack {
                    Text("Main text")
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                    Spacer()
                    formattingControls
                }
                TextEditor(text: $bodyMarkdown)
                    .frame(minHeight: 260)
                    .scrollContentBackground(.hidden)
                    .padding(BrickSpacing.s)
                    .background(BrickColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
            }

            editorField("Tags, separated by commas", text: $tagsText, minHeight: 44)
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var formattingControls: some View {
        HStack(spacing: 6) {
            formatButton("B", symbol: "bold", prefix: "**", suffix: "**")
            formatButton("I", symbol: "italic", prefix: "_", suffix: "_")
            formatButton("U", symbol: "underline", prefix: "<u>", suffix: "</u>")
            formatButton("H", symbol: "textformat.size", prefix: "\n## ", suffix: "\n")
            formatButton("•", symbol: "list.bullet", prefix: "\n- ", suffix: "")
        }
    }

    private var mediaPicker: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            HStack {
                Text("Media")
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)
                Spacer()
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 8, matching: .images) {
                    Label("Images", systemImage: "photo.badge.plus")
                }
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.gold)
                PhotosPicker(selection: $selectedVideoItems, maxSelectionCount: 4, matching: .videos) {
                    Label("Videos", systemImage: "video.badge.plus")
                }
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.gold)
            }

            editorField("Links, one per line", text: $linksText, minHeight: 86)

            if selectedImageReferences.isEmpty && selectedVideoReferences.isEmpty {
                Text("The first image becomes the story banner. Extra images and videos appear in the article media gallery. Links appear as story sources.")
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrickSpacing.m) {
                    ForEach(selectedImageReferences, id: \.self) { reference in
                        mediaPreview(reference: reference) {
                            selectedImageReferences.removeAll { $0 == reference }
                        }
                    }
                    ForEach(selectedVideoReferences, id: \.self) { reference in
                        mediaPreview(reference: reference) {
                            selectedVideoReferences.removeAll { $0 == reference }
                        }
                    }
                }
            }
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func mediaPreview(reference: String, remove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            ArticleMediaView(reference: reference)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.black.opacity(0.65)))
            }
            .padding(6)
        }
    }

    private var publishOptions: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
            Picker("Status", selection: $status) {
                Text("Draft").tag(PublishStatus.draft)
                Text("Published").tag(PublishStatus.published)
                Text("Scheduled").tag(PublishStatus.scheduled)
            }
            .pickerStyle(.segmented)

            Toggle("Mark as rumour", isOn: $isRumour)
                .tint(BrickColor.gold)
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private func editorField(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Text(label)
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(BrickSpacing.s)
                .background(BrickColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))
        }
    }

    private func formatButton(_ label: String, symbol: String, prefix: String, suffix: String) -> some View {
        Button {
            applyFormat(prefix: prefix, suffix: suffix)
        } label: {
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BrickColor.primaryText)
        .background(Circle().fill(BrickColor.card))
        .overlay(Circle().strokeBorder(BrickColor.border, lineWidth: 1))
        .accessibilityLabel(label)
    }

    private func applyFormat(prefix: String, suffix: String) {
        let trimmed = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            bodyMarkdown = "\(prefix)Text\(suffix)"
        } else {
            bodyMarkdown += "\(prefix)Text\(suffix)"
        }
    }

    @MainActor
    private func importImages(from items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let filename = ImageStore.save(image) else { continue }
            selectedImageReferences.append("local-image://\(filename)")
        }
        selectedItems = []
    }

    @MainActor
    private func importVideos(from items: [PhotosPickerItem]) async {
        for item in items {
            guard let picked = try? await item.loadTransferable(type: PickedStoryVideo.self),
                  let filename = ImageStore.saveVideo(from: picked.url) else { continue }
            selectedVideoReferences.append("local-video://\(filename)")
        }
        selectedVideoItems = []
    }

    private func generateStory() {
        isGenerating = true
        generationError = nil
        Task {
            do {
                let draft = try await OpenAIStoryService.generateStory(from: brief)
                title = draft.title
                summary = draft.summary
                bodyMarkdown = draft.bodyMarkdown
                tagsText = draft.tags.joined(separator: ", ")
                category = draft.category
                isRumour = draft.isRumour
                aiAssisted = true
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func saveStory() {
        model.createArticle(
            title: title,
            summary: summary,
            bodyMarkdown: bodyMarkdown,
            category: category,
            tags: tagsText.components(separatedBy: ","),
            imageReferences: selectedImageReferences,
            mediaReferences: selectedVideoReferences,
            links: parsedLinks,
            status: status,
            aiAssisted: aiAssisted,
            isRumour: isRumour
        )
        dismiss()
    }

    private var parsedLinks: [ArticleSource] {
        linksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { raw in
                let urlString = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
                guard let url = URL(string: urlString), let host = url.host else { return nil }
                let name = host.replacingOccurrences(of: "www.", with: "")
                return ArticleSource(id: UUID(), name: name, url: url.absoluteString)
            }
    }
}

struct OpenAIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var hasSavedKey = KeychainStore.load(OpenAIStoryService.apiKeychainKey)?.isEmpty == false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("OpenAI connection")
                    .font(BrickFont.sectionTitle)
                    .foregroundStyle(BrickColor.primaryText)

                Label(hasSavedKey ? "An API key is saved on this device." : "No API key saved yet.", systemImage: hasSavedKey ? "checkmark.seal.fill" : "key")
                    .font(BrickFont.meta)
                    .foregroundStyle(hasSavedKey ? BrickColor.stadiumGreen : BrickColor.secondaryText)

                SecureField(hasSavedKey ? "Paste a new key to replace the saved one" : "sk-...", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(BrickSpacing.m)
                    .background(BrickColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BrickColor.border, lineWidth: 1))

                Button {
                    KeychainStore.save(trimmedKey, for: OpenAIStoryService.apiKeychainKey)
                    hasSavedKey = true
                    dismiss()
                } label: {
                    Text("Save API Key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudButtonStyle())
                .disabled(trimmedKey.isEmpty)

                if hasSavedKey {
                    Button("Remove saved key", role: .destructive) {
                        KeychainStore.delete(OpenAIStoryService.apiKeychainKey)
                        hasSavedKey = false
                    }
                    .foregroundStyle(BrickColor.brickRed)
                }

                Spacer()
            }
            .padding(BrickSpacing.l)
            .background { BrickScreenBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var trimmedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
