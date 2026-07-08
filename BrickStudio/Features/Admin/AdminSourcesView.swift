import SwiftUI

/// Admin management of the scanner's approved source list (§10.3, §22
/// "Sources"). Reads NewsScanner/sources.json from GitHub and commits
/// changes back, so the very next scan uses the updated list.
struct AdminSourcesView: View {
    @Environment(AppModel.self) private var model

    @State private var sources: [NewsSource] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var editingSource: NewsSource?
    @State private var isAdding = false
    @State private var isShowingTokenSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrickSpacing.l) {
                Text("The sites the scanner checks for brick news. Changes save straight to GitHub and apply from the next scan.")
                    .font(BrickFont.body)
                    .foregroundStyle(BrickColor.secondaryText)

                if isSaving {
                    HStack(spacing: BrickSpacing.m) {
                        ProgressView()
                        Text("Saving to GitHub…")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .padding(BrickSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }

                if saveFailed {
                    VStack(alignment: .leading, spacing: BrickSpacing.s) {
                        Label("Your last change hasn't been saved to GitHub yet.", systemImage: "exclamationmark.triangle.fill")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.brickRed)
                        Button("Retry save") { persistToGitHub() }
                            .buttonStyle(StudButtonStyle(tint: BrickColor.brickRed, prominent: false))
                    }
                    .padding(BrickSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brickCard()
                }

                if isLoading {
                    HStack(spacing: BrickSpacing.m) {
                        ProgressView()
                        Text("Loading source list…")
                            .font(BrickFont.meta)
                            .foregroundStyle(BrickColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(BrickSpacing.xl)
                } else if loadFailed {
                    EmptyStateView(
                        symbol: "wifi.exclamationmark",
                        message: "Couldn't load the source list from GitHub. Check your connection and try again.",
                        actionTitle: "Try again",
                        action: { Task { await load() } }
                    )
                } else if sources.isEmpty {
                    EmptyStateView(
                        symbol: "antenna.radiowaves.left.and.right",
                        message: "No sources yet. Add the first site the scanner should check.",
                        actionTitle: "Add a source",
                        action: { isAdding = true }
                    )
                } else {
                    ForEach(sources) { source in
                        sourceRow(source)
                    }
                }
            }
            .padding(BrickSpacing.l)
        }
        .background(BrickColor.background)
        .navigationTitle("News Sources")
        .refreshable { await load() }
        .task {
            if sources.isEmpty { await load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isLoading || loadFailed)
                .accessibilityLabel("Add a news source")
            }
        }
        .sheet(item: $editingSource) { source in
            SourceFormView(
                source: source,
                isNew: false,
                onSave: { updated in
                    if let index = sources.firstIndex(where: { $0.id == updated.id }) {
                        sources[index] = updated
                        persistToGitHub()
                    }
                },
                onDelete: {
                    sources.removeAll { $0.id == source.id }
                    persistToGitHub()
                }
            )
        }
        .sheet(isPresented: $isAdding) {
            SourceFormView(
                source: NewsSource(),
                isNew: true,
                onSave: { new in
                    sources.append(new)
                    persistToGitHub()
                },
                onDelete: nil
            )
        }
        .sheet(isPresented: $isShowingTokenSheet) {
            GitHubTokenSheet(onSaved: { persistToGitHub() })
                .presentationDetents([.large])
        }
    }

    private func sourceRow(_ source: NewsSource) -> some View {
        Button {
            editingSource = source
        } label: {
            HStack(spacing: BrickSpacing.m) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(source.enabled ? BrickColor.stadiumGreen : BrickColor.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill((source.enabled ? BrickColor.stadiumGreen : BrickColor.secondaryText).opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(BrickFont.cardTitle)
                        .foregroundStyle(BrickColor.primaryText)
                    Text(source.host)
                        .font(BrickFont.meta)
                        .foregroundStyle(BrickColor.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                TagBadge(
                    text: source.enabled ? "Active" : "Paused",
                    tint: source.enabled ? BrickColor.stadiumGreen : BrickColor.secondaryText
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(BrickColor.secondaryText)
            }
            .padding(BrickSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .brickCard()
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        isLoading = sources.isEmpty
        loadFailed = false
        do {
            sources = try await SourcesService.fetch()
        } catch {
            if sources.isEmpty { loadFailed = true }
        }
        isLoading = false
    }

    private func persistToGitHub() {
        guard let token = KeychainStore.load(GitHubWorkflowService.tokenKeychainKey), !token.isEmpty else {
            saveFailed = true
            isShowingTokenSheet = true
            return
        }
        isSaving = true
        saveFailed = false
        Task {
            do {
                try await SourcesService.save(sources, token: token)
                model.showToast("Sources updated — next scan uses the new list")
            } catch {
                saveFailed = true
                model.showToast(error.localizedDescription, symbol: "exclamationmark.triangle")
            }
            isSaving = false
        }
    }
}

/// Add/edit form for one source.
private struct SourceFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var source: NewsSource
    let isNew: Bool
    var onSave: (NewsSource) -> Void
    var onDelete: (() -> Void)?

    @State private var validationMessage: String?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    TextField("Name (e.g. Brickset)", text: $source.name)
                    TextField("RSS feed URL (https://…/feed)", text: $source.rssUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Enabled", isOn: $source.enabled)
                }
                Section {
                    TextField("Notes (optional)", text: $source.notes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(BrickColor.brickRed)
                    } else {
                        Text("The scanner needs an RSS or Atom feed URL, not a homepage. Most sites publish one at /feed or /rss.")
                    }
                }
                if !isNew, onDelete != nil {
                    Section {
                        Button("Remove this source", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Source" : source.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove \(source.name)? The scanner will stop checking it from the next run.",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Remove source", role: .destructive) {
                    dismiss()
                    onDelete?()
                }
            }
        }
    }

    private func save() {
        let name = source.name.trimmingCharacters(in: .whitespaces)
        let url = source.rssUrl.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            validationMessage = "Give the source a name."
            return
        }
        guard url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") else {
            validationMessage = "The feed URL needs to start with https://"
            return
        }
        var cleaned = source
        cleaned.name = name
        cleaned.rssUrl = url
        dismiss()
        onSave(cleaned)
    }
}
