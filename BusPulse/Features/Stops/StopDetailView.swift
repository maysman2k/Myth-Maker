import CoreLocation
import SwiftUI

/// A stop's hub: live buses heading its way, the offline departure board
/// (powered by saved timetables), and the routes that call here.
struct StopDetailView: View {
    @Environment(\.busAPI) private var api
    @Environment(FavoritesStore.self) private var favorites
    @Environment(TimetableStore.self) private var timetables
    @Environment(NetworkMonitor.self) private var network

    let stop: Stop

    @State private var services: [Service] = []
    @State private var liveVehicles: [VehiclePosition] = []
    @State private var loadedLive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                header
                servicesSection
                departureBoard
                liveSection
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(stop)
                } label: {
                    Image(systemName: favorites.isFavorite(stop) ? "star.fill" : "star")
                }
                .accessibilityLabel(favorites.isFavorite(stop)
                                    ? "Remove from favourites" : "Add to favourites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: WaitlessShare.stop(name: stop.displayName, atco: stop.id),
                          message: Text(WaitlessShare.stopMessage(name: stop.displayName))) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var header: some View {
        HStack(spacing: BPSpacing.md) {
            VStack(alignment: .leading, spacing: BPSpacing.xs) {
                Text(stop.displayName)
                    .font(BPFont.cardTitle)
                if let code = stop.naptanCode {
                    Text("Stop code: \(code)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let bearing = stop.bearing {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .rotationEffect(.degrees(bearing))
                        .foregroundStyle(BPColor.signal)
                    Text("buses head")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Buses depart heading \(Int(bearing)) degrees")
            }
        }
        .bpCard()
    }

    // MARK: Departure board (works offline from saved timetables)

    private var departureBoard: some View {
        let saved = timetables.timetables.filter { timetable in
            timetable.trips.contains { trip in
                trip.times.contains { $0.atcoCode == stop.id }
            }
        }
        let departures = DepartureCalculator.nextDepartures(at: stop.id,
                                                            from: saved,
                                                            after: .now)

        return VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack {
                Text("Next departures")
                    .font(BPFont.cardTitle)
                Spacer()
                if !saved.isEmpty {
                    Label("Offline ready", systemImage: "arrow.down.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BPColor.signal)
                }
            }

            if departures.isEmpty {
                Text(saved.isEmpty
                     ? "Save a timetable for one of this stop's routes (below) and scheduled departures appear here — even with no signal."
                     : "No more departures today from your saved timetables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(departures) { departure in
                    HStack(spacing: BPSpacing.md) {
                        RoutePill(lineName: departure.lineName)
                        Text(departure.destination ?? "")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(DepartureCalculator.countdownLabel(to: departure.departure,
                                                                from: .now))
                            .font(BPFont.time)
                            .foregroundStyle(BPColor.signal)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .bpCard()
    }

    // MARK: Live buses

    @ViewBuilder
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack {
                Text("Live buses on these routes")
                    .font(BPFont.cardTitle)
                Spacer()
                if loadedLive { LiveBadge() }
            }
            if !network.isOnline {
                Text("Live positions need a connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if liveVehicles.isEmpty && loadedLive {
                Text("Nothing reporting right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nearestVehicles) { vehicle in
                    NavigationLink {
                        BusDetailView(bus: BusRef(vehicle: vehicle))
                    } label: {
                        HStack(spacing: BPSpacing.md) {
                            RoutePill(lineName: vehicle.routeLabel,
                                      backgroundHex: vehicle.liveryBackground,
                                      foregroundHex: vehicle.liveryForeground)
                            Text(vehicle.destination ?? "In service")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            if let delay = vehicle.delaySeconds {
                                DelayChip(status: DelayStatus(delaySeconds: delay))
                            }
                            Text(distanceLabel(for: vehicle))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .bpCard()
    }

    private var nearestVehicles: [VehiclePosition] {
        let here = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        return liveVehicles
            .sorted {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here)
                    < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: here)
            }
            .prefix(8)
            .map { $0 }
    }

    private func distanceLabel(for vehicle: VehiclePosition) -> String {
        let metres = CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude)
            .distance(from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
        return metres < 1000 ? "\(Int(metres)) m away" : String(format: "%.1f km away", metres / 1000)
    }

    // MARK: Routes calling here

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            Text("Buses from this stop")
                .font(BPFont.cardTitle)
            if services.isEmpty {
                Text(network.isOnline ? "Loading buses…" : "Connect once to load the buses from this stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(services) { service in
                NavigationLink {
                    ServiceDetailView(service: service)
                } label: {
                    HStack(spacing: BPSpacing.md) {
                        RoutePill(lineName: service.lineName)
                        Text(service.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        if timetables.timetable(forServiceID: service.id) != nil {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(BPColor.signal)
                                .accessibilityLabel("Timetable saved offline")
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .bpCard()
    }

    // MARK: Loading

    private func load() async {
        guard network.isOnline else { return }
        if let fetched = try? await api.services(callingAt: stop.id) {
            services = fetched.sorted { $0.lineName.localizedStandardCompare($1.lineName) == .orderedAscending }
        }
        let ids = services.map(\.id)
        if !ids.isEmpty, let vehicles = try? await api.liveVehicles(serviceIDs: ids) {
            liveVehicles = vehicles
        }
        loadedLive = true
    }
}
