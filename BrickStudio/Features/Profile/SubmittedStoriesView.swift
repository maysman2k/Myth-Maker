import PhotosUI
import SwiftUI
import UIKit

struct SubmittedStoriesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SubmitStoryEditorView()
                } label: {
                    Label("Submit a new story", systemImage: "square.and.pencil")
                }
            }

            Section("Holding queue") {
                if model.mySubmittedStories.isEmpty {
                    Text("Your submitted stories will appear here while they wait for review.")
                        .foregroundStyle(BrickColor.secondaryText)
                } else {
                    ForEach(model.mySubmittedStories) { submission in
                        NavigationLink {
                            SubmitStoryEditorView(submissionID: submission.id)
                        } label: {
                            submissionRow(submission)
                        }
                        .disabled(submission.status == .published || submission.status == .locked)
                    }
                }
            }
        }
        .navigationTitle("My Stories")
        .refreshable {
            await model.refreshSupabaseContent()
        }
        .task {
            await model.refreshSupabaseContent(quietErrors: true)
        }
    }

    private func submissionRow(_ submission: SubmittedStory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(submission.title)
                .font(.system(size: 15, weight: .semibold))
            HStack {
                TagBadge(text: submission.status.displayName, tint: tint(for: submission.status))
                if submission.declineCount > 0 {
                    TagBadge(text: "\(submission.declineCount)/3 declines", tint: BrickColor.brickRed)
                }
                Spacer()
            }
            if let feedback = submission.latestFeedback, !feedback.isEmpty {
                Text(feedback)
                    .font(BrickFont.meta)
                    .foregroundStyle(BrickColor.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func tint(for status: SubmittedStoryStatus) -> Color {
        switch status {
        case .pendingReview: return BrickColor.gold
        case .changesRequested: return BrickColor.brickRed
        case .published: return BrickColor.stadiumGreen
        case .locked: return BrickColor.secondaryText
        }
    }
}

struct SubmitStoryEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var submissionID: UUID?

    @State private var title = ""
    @State private var summary = ""
    @State private var bodyMarkdown = ""
    @State private var tagsText = ""
    @State private var category: ArticleCategory = .bricksInABagUpdates
    @State private var isRumour = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var selectedImageReferences: [String] = []
    @State private var selectedVideoReferences: [String] = []
    @State private var linksText = ""

    private var submission: SubmittedStory? {
        guard let submissionID else { return nil }
        return model.submittedStories.first { $0.id == submissionID }
    }

    private var canEdit: Bool {
        guard let submission else { return true }
        return submission.status != .published && submission.status != .locked && submission.declineCount < 3
    }

    private var canSubmit: Bool {
        canEdit &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                if let submission, let feedback = submission.latestFeedback {
                    feedbackCard(feedback, declineCount: submission.declineCount)
                }
                storyFields
                mediaPicker
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle(submissionID == nil ? "Submit Story" : "Edit Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Submit") { submit() }
                    .disabled(!canSubmit)
            }
        }
        .onAppear(perform: loadSubmission)
        .onChange(of: selectedItems) { _, newItems in
            Task { await importImages(from: newItems) }
        }
        .onChange(of: selectedVideoItems) { _, newItems in
            Task { await importVideos(from: newItems) }
        }
    }

    private func feedbackCard(_ feedback: String, declineCount: Int) -> some View {
        VStack(alignment: .leading, spacing: BrickSpacing.s) {
            Label("Admin feedback", systemImage: "text.bubble")
                .font(BrickFont.cardTitle)
                .foregroundStyle(BrickColor.primaryText)
            Text(feedback)
                .font(BrickFont.body)
                .foregroundStyle(BrickColor.secondaryText)
            Text(declineCount >= 3 ? "This entry is locked after three declines. Please create a new submission." : "Editing and submitting again puts this story back into the review queue.")
                .font(BrickFont.meta)
                .foregroundStyle(BrickColor.secondaryText)
        }
        .padding(BrickSpacing.l)
        .brickCard()
    }

    private var storyFields: some View {
        VStack(alignment: .leading, spacing: BrickSpacing.m) {
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
            Toggle("Mark as rumour", isOn: $isRumour)
                .tint(BrickColor.gold)
        }
        .disabled(!canEdit)
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

    private func formatButton(_ label: String, symbol: String, prefix: String, suffix: String) -> some View {
        Button {
            let trimmed = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            bodyMarkdown = trimmed.isEmpty ? "\(prefix)Text\(suffix)" : bodyMarkdown + "\(prefix)Text\(suffix)"
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
                PhotosPicker(selection: $selectedVideoItems, maxSelectionCount: 4, matching: .videos) {
                    Label("Videos", systemImage: "video.badge.plus")
                }
            }
            .font(BrickFont.meta)
            .foregroundStyle(BrickColor.gold)
            .disabled(!canEdit)

            editorField("Links, one per line", text: $linksText, minHeight: 86)
                .disabled(!canEdit)

            if selectedImageReferences.isEmpty && selectedVideoReferences.isEmpty {
                Text("Add images, videos, and links to support your story.")
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

    private func mediaPreview(reference: String, remove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            ArticleMediaView(reference: reference)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if canEdit {
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
    }

    private func loadSubmission() {
        guard let submission else { return }
        title = submission.title
        summary = submission.summary
        bodyMarkdown = submission.bodyMarkdown
        tagsText = submission.tags.joined(separator: ", ")
        category = submission.category
        isRumour = submission.isRumour
        selectedImageReferences = submission.imageReferences
        selectedVideoReferences = submission.mediaReferences
        linksText = submission.links.map(\.url).joined(separator: "\n")
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

    private func submit() {
        model.submitStory(
            existingID: submissionID,
            title: title,
            summary: summary,
            bodyMarkdown: bodyMarkdown,
            category: category,
            tags: tagsText.components(separatedBy: ","),
            imageReferences: selectedImageReferences,
            mediaReferences: selectedVideoReferences,
            links: parsedLinks,
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
                return ArticleSource(id: UUID(), name: host.replacingOccurrences(of: "www.", with: ""), url: url.absoluteString)
            }
    }
}
