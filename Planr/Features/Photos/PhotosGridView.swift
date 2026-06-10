import PhotosUI
import SwiftUI

struct PhotosGridView: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedPhotoID: String?
    @State private var isImporting = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        let photos = model.photos(for: eventID)

        ScrollView {
            if photos.isEmpty && !isImporting {
                EmptyStateView(symbol: "photo.on.rectangle.angled",
                               title: "No photos yet",
                               message: "Every event needs evidence. Add the first one.")
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    Button {
                        selectedPhotoID = photo.id
                    } label: {
                        PhotoThumbnail(photo: photo)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(photo.caption ?? "Event photo")
                }
            }
            if isImporting {
                ProgressView("Adding photos…")
                    .padding()
            }
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Label("Add photos", systemImage: "plus.circle.fill")
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
        }
        .sheet(isPresented: Binding(get: { selectedPhotoID != nil },
                                    set: { if !$0 { selectedPhotoID = nil } })) {
            if let selectedPhotoID {
                PhotoViewer(eventID: eventID, initialPhotoID: selectedPhotoID)
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            var datas: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    datas.append(data)
                }
            }
            model.importPhotos(datas, to: eventID)
            pickerItems = []
            isImporting = false
        }
    }
}

/// Async thumbnail; falls back to gradient art for seeded sample photos.
struct PhotoThumbnail: View {
    @Environment(AppModel.self) private var model
    let photo: EventPhoto

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let paletteIndex = photo.placeholderPaletteIndex {
                    PlaceholderPhotoView(paletteIndex: paletteIndex, symbol: photo.placeholderSymbol)
                } else {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .overlay { ProgressView() }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: photo.fileName) {
            guard let fileName = photo.fileName else { return }
            image = await model.imageStore.loadImage(named: fileName, maxDimension: 400)
        }
    }
}
