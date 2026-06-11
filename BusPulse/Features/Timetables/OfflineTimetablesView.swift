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
                    Text("Saved timetables cover the day they were downloaded. Refresh before you travel for the latest schedule. Using \(ByteCountFormatter.string(fromByteCount: Int64(timetables.totalSizeBytes), countStyle: .file)).")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Saved timetables")
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

/// Browse a saved timetable: journeys by departure time, fully offline.
struct TimetableBrowserView: View {
    let timetable: CachedTimetable

    var body: some View {
        List {
            Section {
                ForEach(sortedTrips) { trip in
                    NavigationLink {
                        TripTimesView(trip: trip, service: timetable.service)
                    } label: {
                        HStack(spacing: BPSpacing.md) {
                            Text(trip.startSeconds.map(TimeOfDay.label(forSeconds:)) ?? "—")
                                .font(BPFont.time)
                                .foregroundStyle(BPColor.signal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.headsign ?? trip.times.last?.stopName ?? "Journey")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("from \(trip.times.first?.stopName ?? "first stop") · \(trip.times.count) stops")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(timetable.date.formatted(date: .complete, time: .omitted))
            }
        }
        .scrollContentBackground(.hidden)
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Route \(timetable.service.lineName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedTrips: [TimetableTrip] {
        timetable.trips.sorted { ($0.startSeconds ?? 0) < ($1.startSeconds ?? 0) }
    }
}

/// All calling points of one journey.
struct TripTimesView: View {
    let trip: TimetableTrip
    let service: Service

    var body: some View {
        List {
            ForEach(Array(trip.times.enumerated()), id: \.offset) { index, time in
                HStack(spacing: BPSpacing.md) {
                    Text((time.departureSeconds ?? time.arrivalSeconds)
                            .map(TimeOfDay.label(forSeconds:)) ?? "—")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(BPColor.signal)
                        .frame(width: 84, alignment: .leading)
                    Image(systemName: index == 0 ? "circle.fill"
                          : index == trip.times.count - 1 ? "mappin.circle.fill"
                          : "smallcircle.filled.circle")
                        .font(.caption)
                        .foregroundStyle(BPColor.signal)
                    Text(time.stopName ?? time.atcoCode ?? "Stop")
                        .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BPColor.backgroundPrimary)
        .navigationTitle(trip.headsign ?? "Journey")
        .navigationBarTitleDisplayMode(.inline)
    }
}
