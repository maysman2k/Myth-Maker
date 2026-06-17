import MapKit
import SwiftUI

/// The live map. Two modes:
/// - `.explore` (the main tab): opens zoomed to the user, stops shown by
///   default, live buses an opt-in toggle, with recentre and location search.
/// - `.routes`: one or more chosen routes only, with an "Add route" button
///   to compare services (e.g. the 83 and the X83 side by side).
struct LiveMapView: View {
    enum Mode: Equatable {
        case explore
        case routes(ServiceFocus)

        var isExplore: Bool {
            if case .explore = self { return true }
            return false
        }
    }

    @Environment(\.busAPI) private var api
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationProvider.self) private var location
    @Environment(FavoritesStore.self) private var favorites

    let mode: Mode

    @State private var position: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion?

    // Explore state
    @State private var showStops = true
    @State private var showBuses = false
    @State private var stops: [Stop] = []
    @State private var stopsTask: Task<Void, Never>?
    @State private var exploreStream: LiveVehiclesModel?
    @State private var showLocationSearch = false

    // Routes state
    @State private var focus = ServiceFocus(serviceIDs: [], lineNames: [])
    @State private var routeStream: LiveVehiclesModel?
    @State private var routeLines: [[CLLocationCoordinate2D]] = []
    @State private var routeStops: [Stop] = []
    @State private var routeFallbackBox: BoundingBox?
    @State private var routeFallbackVehicles: [VehiclePosition] = []
    @State private var routeFallbackTask: Task<Void, Never>?
    @State private var showAddRoute = false

    /// Above this viewport size (square degrees) we stop loading map objects —
    /// this is what keeps the national feed from swamping the device.
    private let maxObjectArea = 0.05

    /// Set once we've centred on the user, so we don't yank the map back if
    /// they've panned away.
    @State private var didCentreOnUser = false

    init(mode: Mode = .explore) {
        self.mode = mode
        switch mode {
        case .explore:
            // Start on a sensible region; jump to the user once a fix arrives
            // (see centreOnUserOnce), then leave the camera to the user.
            _position = State(initialValue: .region(
                MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426),
                                   span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))))
        case .routes(let value):
            _focus = State(initialValue: value)
            _position = State(initialValue: .automatic)
        }
    }

    private func centreOnUserOnce() {
        guard mode.isExplore, !didCentreOnUser,
              let coordinate = location.location?.coordinate else { return }
        didCentreOnUser = true
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
    }

    var body: some View {
        switch mode {
        case .explore: exploreMap
        case .routes: routesMap
        }
    }

    // MARK: - Explore

    private var exploreMap: some View {
        Map(position: $position) {
            UserAnnotation()

            if showStops {
                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                        NavigationLink(value: stop) { stopDot }
                            .accessibilityLabel("Bus stop: \(stop.displayName)")
                    }
                    .annotationTitles(.hidden)
                }
            }

            if showBuses {
                ForEach(displayedVehicles) { vehicle in
                    Annotation(vehicle.routeLabel, coordinate: vehicle.coordinate, anchor: .center) {
                        NavigationLink {
                            BusDetailView(bus: BusRef(vehicle: vehicle))
                        } label: {
                            VehicleMarker(vehicle: vehicle)
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            handleExploreCamera(context.region)
        }
        .overlay(alignment: .top) { exploreHint }
        .overlay(alignment: .bottom) { exploreFilterBar }
        .navigationDestination(for: Stop.self) { StopDetailView(stop: $0) }
        .navigationTitle("Live map")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchSheet { coordinate in moveCamera(to: coordinate) }
        }
        .task {
            location.requestAccess()
            centreOnUserOnce()
        }
        .onChange(of: location.location?.timestamp) { _, _ in
            centreOnUserOnce()
        }
        .onChange(of: showBuses) { _, on in
            if on {
                ensureExploreStream()
                refreshExploreBuses()
            } else {
                exploreStream?.stop()
            }
        }
        .onDisappear { exploreStream?.stop() }
    }

    private var stopDot: some View {
        Circle()
            .fill(BPColor.surfacePrimary)
            .stroke(BPColor.signal, lineWidth: 2)
            .frame(width: 11, height: 11)
    }

    /// Reference point for "closest" — the centre of what the user is looking at.
    private var mapCentre: CLLocationCoordinate2D {
        visibleRegion?.center
            ?? location.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426)
    }

    /// The buses actually drawn: capped to the nearest few, favourites first,
    /// so a busy area can't flood the map and freeze it.
    private var displayedVehicles: [VehiclePosition] {
        VehiclePrioritiser.prioritised(exploreStream?.vehicles ?? [],
                                       favouriteServiceIDs: Set(favorites.services.map(\.id)),
                                       near: mapCentre)
    }

    /// How many buses are in view in total (before the cap).
    private var candidateBusCount: Int {
        exploreStream?.vehicles.count ?? 0
    }

    @ViewBuilder
    private var exploreHint: some View {
        let area = visibleRegion.map { BoundingBox(region: $0).area } ?? 0
        if area > maxObjectArea {
            Label("Zoom in to load stops and buses", systemImage: "arrow.down.left.and.arrow.up.right")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, BPSpacing.md)
                .padding(.vertical, BPSpacing.sm)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, BPSpacing.sm)
        } else if showBuses {
            VStack(spacing: BPSpacing.xs) {
                HStack(spacing: BPSpacing.sm) {
                    LiveBadge()
                    Text("\(displayedVehicles.count) of \(candidateBusCount) buses")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                if candidateBusCount > 11 {
                    Text("Showing the nearest \(VehiclePrioritiser.displayLimit) — to see more live buses, use search")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, BPSpacing.md)
            .padding(.vertical, BPSpacing.sm)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, BPSpacing.sm)
            .padding(.horizontal, BPSpacing.screenMargin)
        }
    }

    private var exploreFilterBar: some View {
        HStack(spacing: BPSpacing.sm) {
            FilterPill(title: "Stops", systemImage: "bus.fill", isOn: $showStops)
            FilterPill(title: "Live buses", systemImage: "dot.radiowaves.up.forward", isOn: $showBuses)
            Spacer()
            Button {
                showLocationSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Search a location")
        }
        .padding(.horizontal, BPSpacing.screenMargin)
        .padding(.bottom, BPSpacing.sm)
    }

    private func handleExploreCamera(_ region: MKCoordinateRegion) {
        let box = BoundingBox(region: region)

        if showBuses {
            ensureExploreStream()
            if box.area < maxObjectArea {
                exploreStream?.watch(.boundingBox(box))
            }
        }

        stopsTask?.cancel()
        guard showStops, box.area < maxObjectArea else {
            stops = []
            return
        }
        stopsTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            if let fetched = try? await api.nearbyStops(in: box) {
                stops = fetched
            }
        }
    }

    private func ensureExploreStream() {
        if exploreStream == nil {
            exploreStream = LiveVehiclesModel(api: api, settings: settings)
        }
        exploreStream?.start()
    }

    private func refreshExploreBuses() {
        guard let region = visibleRegion else { return }
        let box = BoundingBox(region: region)
        if box.area < maxObjectArea {
            exploreStream?.watch(.boundingBox(box))
        }
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
    }

    // MARK: - Routes

    private var routesMap: some View {
        Map(position: $position) {
            ForEach(routeLines.indices, id: \.self) { index in
                MapPolyline(coordinates: routeLines[index])
                    .stroke(BPColor.signal, lineWidth: 4)
            }
            ForEach(routeStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                    Circle()
                        .fill(BPColor.surfacePrimary)
                        .stroke(BPColor.signal, lineWidth: 2)
                        .frame(width: 8, height: 8)
                }
                .annotationTitles(.hidden)
            }
            ForEach(displayedRouteVehicles) { vehicle in
                Annotation(vehicle.routeLabel, coordinate: vehicle.coordinate, anchor: .center) {
                    NavigationLink {
                        BusDetailView(bus: BusRef(vehicle: vehicle))
                    } label: {
                        VehicleMarker(vehicle: vehicle)
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .top) { routesCountBar }
        .navigationTitle(focus.lineNames.isEmpty ? "Route" : focus.lineNames.joined(separator: " · "))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddRoute = true
                } label: {
                    Label("Add route", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddRoute) {
            ServicePickerSheet { addRoute($0) }
        }
        .task {
            if routeStream == nil {
                routeStream = LiveVehiclesModel(api: api, settings: settings)
            }
            routeStream?.watch(.services(focus.serviceIDs))
            routeStream?.start()
            await loadRouteStaticData()
            startRouteFallbackPolling()
        }
        .onDisappear {
            routeStream?.stop()
            routeFallbackTask?.cancel()
            routeFallbackTask = nil
        }
    }

    private var routesCountBar: some View {
        HStack(spacing: BPSpacing.sm) {
            LiveBadge()
            Text("\(displayedRouteVehicles.count) buses on \(focus.lineNames.count) route\(focus.lineNames.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, BPSpacing.md)
        .padding(.vertical, BPSpacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, BPSpacing.sm)
    }

    private func addRoute(_ service: Service) {
        guard !focus.serviceIDs.contains(service.id) else { return }
        focus.serviceIDs.append(service.id)
        focus.lineNames.append(service.lineName)
        routeStream?.watch(.services(focus.serviceIDs))
        Task {
            await loadRouteStaticData()
            await refreshRouteFallbackVehicles()
        }
    }

    private func loadRouteStaticData() async {
        var lines: [[CLLocationCoordinate2D]] = []
        var allStops: [Stop] = []
        for id in focus.serviceIDs {
            if let geometry = try? await api.routeGeometry(serviceID: id) {
                for segment in geometry {
                    let coords = segment.compactMap { pair -> CLLocationCoordinate2D? in
                        pair.count >= 2
                            ? CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                            : nil
                    }
                    if coords.count > 1 { lines.append(coords) }
                }
            }
            if let serviceStops = try? await api.stops(onService: id) {
                allStops.append(contentsOf: serviceStops)
            }
        }
        routeLines = lines
        routeStops = allStops
        let routeCoordinates = lines.flatMap { $0 } + allStops.map(\.coordinate)
        routeFallbackBox = BoundingBox(coordinates: routeCoordinates, paddingMetres: 1_200)?
            .clamped(toArea: 0.5)
        await refreshRouteFallbackVehicles()
    }

    private var displayedRouteVehicles: [VehiclePosition] {
        RouteVehicleMatcher.merged(primary: routeStream?.vehicles ?? [],
                                   fallback: routeFallbackVehicles,
                                   lineNames: focus.lineNames)
    }

    private func startRouteFallbackPolling() {
        guard routeFallbackTask == nil else { return }
        routeFallbackTask = Task {
            while !Task.isCancelled {
                await refreshRouteFallbackVehicles()
                let interval = max(settings.refreshSeconds, 5)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func refreshRouteFallbackVehicles() async {
        guard let routeFallbackBox else {
            routeFallbackVehicles = []
            return
        }
        guard let vehicles = try? await api.liveVehicles(in: routeFallbackBox) else { return }
        routeFallbackVehicles = RouteVehicleMatcher.matching(vehicles, lineNames: focus.lineNames)
    }
}

/// Toggle pill for the live-map filter bar.
private struct FilterPill: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .padding(.horizontal, BPSpacing.md)
                .padding(.vertical, BPSpacing.sm)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isOn ? BPColor.signal : .clear, lineWidth: 2)
                }
                .foregroundStyle(isOn ? BPColor.signal : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Map marker: livery-coloured route pill with a heading arrow.
struct VehicleMarker: View {
    let vehicle: VehiclePosition

    var body: some View {
        VStack(spacing: 1) {
            if let heading = vehicle.heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 9, weight: .black))
                    .rotationEffect(.degrees(heading))
                    .foregroundStyle(Color(hexString: vehicle.liveryBackground) ?? BPColor.routeFallback)
            }
            RoutePill(lineName: vehicle.routeLabel,
                      backgroundHex: vehicle.liveryBackground,
                      foregroundHex: vehicle.liveryForeground)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .accessibilityLabel("Bus on route \(vehicle.routeLabel)\(vehicle.destination.map { " to \($0)" } ?? "")")
    }
}
