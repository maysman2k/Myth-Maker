import SwiftUI

/// Everything saved for offline use: per-route timetables that work
/// with zero signal — underground, in the sticks, on a plane.
struct OfflineTimetablesView: View {
    @Environment(\.busAPI) private var api
    @Environment(TimetableStore.self) private var timetables
    @Environment(NetworkMonitor.self) private var network

    var body: some View {
        List {
            if timetables.timetables.isEmpty {
                BPEmptyState(symbol: "arrow.down.circle",
                             title: "Nothing saved yet",
                             message: "Open any route and tap \"Save timetable for offline\". It'll be here whenever you need it — signal or not.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(timetables.timetables) { timetable in
                        NavigationLink {
                            TimetableBrowserView(timetable: timetable)
                        } label: {
                            row(for: timetable)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            timetables.delete(serviceID: timetables.timetables[index].service.id)
                        }
                    }
                } footer: {
                    Text("Swipe a timetable left, or tap Edit, to delete it. Saved timetables cover the day they were downloaded — refresh before you travel. Using \(ByteCountFormatter.string(fromByteCount: Int64(timetables.totalSizeBytes), countStyle: .file)).")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Saved timetables")
        .toolbar {
            if !timetables.timetables.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func row(for timetable: CachedTimetable) -> some View {
        HStack(spacing: BPSpacing.md) {
            RoutePill(lineName: timetable.service.lineName)
            VStack(alignment: .leading, spacing: 2) {
                Text(timetable.service.description)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(timetable.trips.count) journeys · saved \(timetable.downloadedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if network.isOnline {
                Button {
                    refresh(timetable)
                } label: {
                    if timetables.isDownloading(serviceID: timetable.service.id) {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Refresh timetable")
            }
        }
    }

    private func refresh(_ timetable: CachedTimetable) {
        Task {
            try? await timetables.download(service: timetable.service, using: api)
        }
    }
}

/// A saved timetable shown as the classic grid — stops down the side,
/// journeys across the top, grouped by direction. Works fully offline.
struct TimetableBrowserView: View {
    @Environment(TimetableStore.self) private var timetables
    @Environment(\.dismiss) private var dismiss

    let timetable: CachedTimetable

    @State private var showDeleteConfirm = false

    private let rowHeight: CGFloat = 34
    private let stopColumnWidth: CGFloat = 158
    private let timeColumnWidth: CGFloat = 56

    private var directions: [TimetableGrid.Direction] {
        TimetableGrid.directions(from: timetable.trips)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: BPSpacing.xl) {
                Text(timetable.date.formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, BPSpacing.screenMargin)

                if directions.isEmpty {
                    BPEmptyState(symbol: "calendar.badge.exclamationmark",
                                 title: "No journeys saved",
                                 message: "This saved timetable has no journeys for its date. Refresh it from the Saved list while online.")
                } else {
                    ForEach(directions) { direction in
                        directionGrid(direction)
                    }
                }
            }
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Route \(timetable.service.lineName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete saved timetable")
            }
        }
        .confirmationDialog("Delete this saved timetable?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                timetables.delete(serviceID: timetable.service.id)
                dismiss()
            }
        } message: {
            Text("You can download it again any time you're online.")
        }
    }

    private func directionGrid(_ direction: TimetableGrid.Direction) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            Text(direction.heading)
                .font(BPFont.cardTitle)
                .padding(.horizontal, BPSpacing.screenMargin)

            HStack(alignment: .top, spacing: 0) {
                // Frozen stop-name column.
                VStack(spacing: 0) {
                    cell(text: "", width: stopColumnWidth, isHeader: true)
                    ForEach(Array(direction.stops.enumerated()), id: \.offset) { index, stop in
                        Text(stop.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: stopColumnWidth, height: rowHeight, alignment: .leading)
                            .padding(.leading, BPSpacing.md)
                            .background(index.isMultiple(of: 2) ? Color.clear : BPColor.signal.opacity(0.05))
                    }
                }
                .background(BPColor.surfacePrimary)

                // Scrollable journey columns.
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 0) {
                        ForEach(direction.columns) { column in
                            VStack(spacing: 0) {
                                Text(column.startSeconds.map(TimeOfDay.clock(forSeconds:)) ?? "")
                                    .font(.caption2.weight(.bold))
                                    .frame(width: timeColumnWidth, height: rowHeight)
                                    .foregroundStyle(BPColor.signal)
                                ForEach(Array(column.times.enumerated()), id: \.offset) { index, seconds in
                                    Text(seconds.map(TimeOfDay.clock(forSeconds:)) ?? "·")
                                        .font(.caption.monospacedDigit())
                                        .frame(width: timeColumnWidth, height: rowHeight)
                                        .foregroundStyle(seconds == nil ? .tertiary : .primary)
                                        .background(index.isMultiple(of: 2) ? Color.clear : BPColor.signal.opacity(0.05))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func cell(text: String, width: CGFloat, isHeader: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .frame(width: width, height: rowHeight)
    }
}
