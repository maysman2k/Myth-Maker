import MapKit
import SwiftUI

/// A route's home: live buses on a map with the route line, the stop list,
/// and the offline timetable download.
struct ServiceDetailView: View {
    @Environment(\.busAPI) private var api
    @Environment(SettingsStore.self) private var settings
    @Environment(FavoritesStore.self) private var favorites
    @Environment(TimetableStore.self) private var timetables
    @Environment(NetworkMonitor.self) private var network

    let service: Service

    @State private var stream: LiveVehiclesModel?
    @State private var stops: [Stop] = []
    @State private var routeLines: [[[Double]]] = []
    @State private var downloadError: String?
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                routeMap
                offlineCard
                stopsSection
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Route \(service.lineName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(service)
                } label: {
                    Image(systemName: favorites.isFavorite(service) ? "star.fill" : "star")
                }
                .accessibilityLabel(favorites.isFavorite(service)
                                    ? "Remove from favourites" : "Add to favourites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let url = service.webURL {
                    ShareLink(item: url,
                              message: Text("Route \(service.lineName) — \(service.description) 🚌")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            if stream == nil {
                stream = LiveVehiclesModel(api: api, settings: settings)
            }
            stream?.watch(.services([service.id]))
            await loadStaticData()
        }
        .onDisappear {
            stream?.stop()
        }
    }

    // MARK: Map (tap to open the full live map, filtered to this route)

    private var routeMap: some View {
        NavigationLink {
            LiveMapView(mode: .routes(ServiceFocus(serviceIDs: [service.id],
                                                   lineNames: [service.lineName])))
        } label: {
            Map(position: $mapPosition, interactionModes: []) {
                ForEach(routeLines.indices, id: \.self) { index in
                    MapPolyline(coordinates: routeLines[index].compactMap { pair in
                        pair.count >= 2
                            ? CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                            : nil
                    })
                    .stroke(BPColor.signal, lineWidth: 3)
                }
                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                        Circle()
                            .fill(BPColor.surfacePrimary)
                            .stroke(BPColor.signal, lineWidth: 2)
                            .frame(width: 8, height: 8)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(stream?.vehicles ?? []) { vehicle in
                    Annotation(vehicle.routeLabel, coordinate: vehicle.coordinate, anchor: .center) {
                        VehicleMarker(vehicle: vehicle)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: BPRadius.card, style: .continuous))
            .overlay(alignment: .topLeading) {
                HStack(spacing: BPSpacing.sm) {
                    LiveBadge()
                    Text("\(stream?.vehicles.count ?? 0) on route")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, BPSpacing.md)
                .padding(.vertical, BPSpacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(BPSpacing.sm)
            }
            .overlay(alignment: .bottomTrailing) {
                Label("Tap for full live map", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, BPSpacing.sm)
                    .padding(.vertical, BPSpacing.xs)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(BPSpacing.sm)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Offline timetable

    private var offlineCard: some View {
        let cached = timetables.timetable(forServiceID: service.id)
        let isDownloading = timetables.isDownloading(serviceID: service.id)

        return VStack(alignment: .leading, spacing: BPSpacing.sm) {
            Text(service.description)
                .font(BPFont.cardTitle)

            if let cached {
                Label("Saved for offline — \(cached.trips.count) journeys, \(cached.downloadedAt.formatted(date: .abbreviated, time: .shortened))",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(BPColor.signal)
                NavigationLink {
                    TimetableBrowserView(timetable: cached)
                } label: {
                    Label("Browse saved timetable", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                }
            }

            Button {
                download()
            } label: {
                if isDownloading {
                    HStack {
                        ProgressView()
                        Text("Downloading today's journeys…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label(cached == nil ? "Save timetable for offline" : "Refresh saved timetable",
                          systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloading || !network.isOnline)

            if !network.isOnline && cached == nil {
                Text("Connect to the internet to download this timetable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let downloadError {
                Text(downloadError)
                    .font(.caption)
                    .foregroundStyle(BPColor.late)
            }
        }
        .bpCard()
    }

    private func download() {
        downloadError = nil
        Task {
            do {
                try await timetables.download(service: service, using: api)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }

    // MARK: Stops

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            Text("Stops on this route")
                .font(BPFont.cardTitle)
            if stops.isEmpty {
                Text(network.isOnline ? "Loading stops…" : "Stops need a connection to load.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(stops) { stop in
                NavigationLink {
                    StopDetailView(stop: stop)
                } label: {
                    HStack {
                        Image(systemName: "smallcircle.filled.circle")
                            .font(.caption)
                            .foregroundStyle(BPColor.signal)
                        Text(stop.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, BPSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .bpCard()
    }

    private func loadStaticData() async {
        guard network.isOnline else { return }
        async let stopsResult = try? api.stops(onService: service.id)
        async let geometryResult = try? api.routeGeometry(serviceID: service.id)
        stops = (await stopsResult) ?? []
        routeLines = (await geometryResult) ?? []
    }
}
