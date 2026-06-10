import SwiftUI

/// The Event Wrap: story cards with stats, awards and highlights.
struct EventWrapView: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    var body: some View {
        if let event = model.event(withID: eventID) {
            content(for: event)
        } else {
            EmptyStateView(symbol: "questionmark.circle",
                           title: "Event not found",
                           message: AppError.eventNotFound.errorDescription ?? "")
        }
    }

    private func content(for event: Event) -> some View {
        let wrap = EventWrapBuilder.build(event: event,
                                          participants: model.participants(in: event),
                                          votes: model.votes(for: event.id),
                                          tasks: model.tasks(for: event.id),
                                          payments: model.payments(for: event.id),
                                          messages: model.messages(for: event.id),
                                          photos: model.photos(for: event.id),
                                          bingo: model.bingoGame(for: event.id))

        return ScrollView {
            VStack(alignment: .leading, spacing: PlanrSpacing.lg) {
                // Hero
                VStack(alignment: .leading, spacing: PlanrSpacing.sm) {
                    CoverArtView(paletteIndex: event.coverPaletteIndex, kind: event.kind,
                                 moodEmoji: event.moodEmoji, height: 150)
                    Text("That's a wrap \(event.moodEmoji)")
                        .font(PlanrFont.heroTitle)
                    Text("\(event.title) · \(DateUtilities.rangeLabel(start: event.startDate, end: event.endDate))\(event.locationName.map { " · \($0)" } ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: PlanrSpacing.md) {
                    ForEach(wrap.stats) { stat in
                        VStack(spacing: PlanrSpacing.xs) {
                            Image(systemName: stat.symbol)
                                .font(.title3)
                                .foregroundStyle(PlanrColor.ember)
                            Text(stat.value)
                                .font(PlanrFont.numeric)
                            Text(stat.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .softCard()
                        .accessibilityElement(children: .combine)
                    }
                }

                // Awards
                if !wrap.awards.isEmpty {
                    Text("Awards night 🏅")
                        .font(PlanrFont.screenTitle)
                    ForEach(wrap.awards) { award in
                        HStack(spacing: PlanrSpacing.md) {
                            Text(award.emoji)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(award.title)
                                    .font(PlanrFont.cardTitle)
                                Text(award.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            AvatarView(profile: model.user(withID: award.userID), size: 32)
                        }
                        .softCard()
                    }
                }

                // Best of chat
                if let topMessageID = wrap.topMessageID,
                   let message = model.messages(for: event.id).first(where: { $0.id == topMessageID }) {
                    Text("Quote of the event")
                        .font(PlanrFont.screenTitle)
                    GlassCard {
                        VStack(alignment: .leading, spacing: PlanrSpacing.xs) {
                            Text("\u{201C}\(message.text)\u{201D}")
                                .font(.title3.italic())
                            Text("— \(model.displayName(for: message.senderID)), \(message.reactionCount) reactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Photos strip
                let photos = model.photos(for: event.id)
                if !photos.isEmpty {
                    Text("The evidence")
                        .font(PlanrFont.screenTitle)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PlanrSpacing.sm) {
                            ForEach(photos) { photo in
                                PhotoThumbnail(photo: photo)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: PlanrRadius.chip))
                            }
                        }
                    }
                    NavigationLink {
                        PhotosGridView(eventID: event.id)
                    } label: {
                        Label("Open the full album", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                // Closing card
                GlassCard {
                    VStack(spacing: PlanrSpacing.sm) {
                        Text("Same again next year?")
                            .font(PlanrFont.cardTitle)
                        ShareLink(item: shareText(event: event, wrap: wrap)) {
                            Label("Share the wrap", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, PlanrSpacing.screenMargin)
            .padding(.bottom, PlanrSpacing.xxl)
        }
        .background(PlanrColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Event Wrap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shareText(event: Event, wrap: EventWrapBuilder.Wrap) -> String {
        var lines = ["\(event.title) — wrapped \(event.moodEmoji)"]
        lines.append(contentsOf: wrap.stats.map { "\($0.title): \($0.value)" })
        if let winner = wrap.bingoWinnerID {
            lines.append("Bingo champion: \(model.displayName(for: winner))")
        }
        lines.append("Planned with Planr.")
        return lines.joined(separator: "\n")
    }
}
