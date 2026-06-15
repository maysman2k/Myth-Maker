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
    }

    @Environment(\.busAPI) private var api
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationProvider.self) private var location

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
    @State private var showAddRoute = false

    /// Above this viewport size (square degrees) we stop loading map objects —
    /// this is what keeps the national feed from swamping the device.
    private let maxObjectArea = 0.05

    init(mode: Mode = .explore) {
        self.mode = mode
        switch mode {
        case .explore:
            _position = State(initialValue: .userLocation(fallback: .region(
                MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426),
                                   span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))))
        case .routes(let value):
            _focus = State(initialValue: value)
            _position = State(initialValue: .automatic)
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
                ForEach(exploreStream?.vehicles ?? []) { vehicle in
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
        } else if showBuses, let stream = exploreStream {
            HStack(spacing: BPSpacing.sm) {
                LiveBadge()
                Text("\(stream.vehicles.count) buses")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .padding(.horizontal, BPSpacing.md)
            .padding(.vertical, BPSpacing.sm)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, BPSpacing.sm)
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
            ForEach(routeStream?.vehicles ?? []) { vehicle in
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
        }
        .onDisappear { routeStream?.stop() }
    }

    private var routesCountBar: some View {
        HStack(spacing: BPSpacing.sm) {
            LiveBadge()
            Text("\(routeStream?.vehicles.count ?? 0) buses on \(focus.lineNames.count) route\(focus.lineNames.count == 1 ? "" : "s")")
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
        Task { await loadRouteStaticData() }
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
