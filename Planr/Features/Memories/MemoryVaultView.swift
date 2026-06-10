import SwiftUI

/// Warm, photo-led archive of everything the group has pulled off.
struct MemoryVaultView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                if model.completedEvents.isEmpty {
                    EmptyStateView(symbol: "photo.stack",
                                   title: "The vault is empty",
                                   message: "Wrapped events live here forever — photos, awards and all the stories.")
                } else {
                    ForEach(model.completedEvents) { event in
                        NavigationLink {
                            EventWrapView(eventID: event.id)
                        } label: {
                            memoryCard(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.vertical, PlanrSpacing.lg)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Memory Vault")
    }

    private func memoryCard(_ event: Event) -> some View {
        let photoCount = model.photos(for: event.id).count
        return VStack(alignment: .leading, spacing: 0) {
            CoverArtView(paletteIndex: event.coverPaletteIndex, kind: event.kind,
                         moodEmoji: event.moodEmoji, height: 110)
            VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
                Text(event.title)
                    .font(PlanrFont.cardTitle)
                    .foregroundStyle(.primary)
                HStack(spacing: PlanrSpacing.md) {
                    Label(DateUtilities.rangeLabel(start: event.startDate, end: event.endDate),
                          systemImage: "calendar")
                    if let location = event.locationName {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                    if photoCount > 0 {
                        Label("\(photoCount)", systemImage: "photo")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(PlanrSpacing.cardPadding)
        }
        .background(PlanrColor.surfacePrimary,
                    in: RoundedRectangle(cornerRadius: PlanrRadius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
}
