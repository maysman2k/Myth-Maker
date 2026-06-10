import SwiftUI

/// Full-screen pager with captions, reactions and delete-own-photo.
struct PhotoViewer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let initialPhotoID: String

    @State private var currentID: String = ""
    private let quickReactions = ["❤️", "😂", "🔥", "🍻"]

    var body: some View {
        let photos = model.photos(for: eventID)

        NavigationStack {
            TabView(selection: $currentID) {
                ForEach(photos) { photo in
                    photoPage(photo)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page)
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let photo = photos.first(where: { $0.id == currentID }),
                       model.canDelete(photo) {
                        Button(role: .destructive) {
                            model.deletePhoto(photo)
                            if model.photos(for: eventID).isEmpty { dismiss() }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete photo")
                    }
                }
            }
            .onAppear { currentID = initialPhotoID }
        }
    }

    private func photoPage(_ photo: EventPhoto) -> some View {
        VStack(spacing: PlanrSpacing.md) {
            Spacer()
            PhotoFullImage(photo: photo)
            Spacer()
            VStack(spacing: PlanrSpacing.sm) {
                if let caption = photo.caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                Text("by \(model.displayName(for: photo.uploaderID))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: PlanrSpacing.sm) {
                    ForEach(quickReactions, id: \.self) { emoji in
                        let count = photo.reactions[emoji]?.count ?? 0
                        let mine = photo.reactions[emoji]?.contains(model.currentUser?.id ?? "") ?? false
                        Button {
                            model.toggleReaction(emoji, on: photo)
                        } label: {
                            Text(count > 0 ? "\(emoji) \(count)" : emoji)
                                .font(.subheadline)
                                .padding(.horizontal, PlanrSpacing.md)
                                .padding(.vertical, PlanrSpacing.xs + 2)
                                .background(Capsule().fill(mine ? PlanrColor.ember.opacity(0.5)
                                                                : .white.opacity(0.15)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("React \(emoji), \(count) so far")
                    }
                }
            }
            .padding(.bottom, PlanrSpacing.xxl)
        }
    }
}

struct PhotoFullImage: View {
    @Environment(AppModel.self) private var model
    let photo: EventPhoto

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let paletteIndex = photo.placeholderPaletteIndex {
                PlaceholderPhotoView(paletteIndex: paletteIndex, symbol: photo.placeholderSymbol)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PlanrRadius.card))
                    .padding(PlanrSpacing.lg)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: photo.fileName) {
            guard let fileName = photo.fileName else { return }
            image = await model.imageStore.loadImage(named: fileName)
        }
    }
}
