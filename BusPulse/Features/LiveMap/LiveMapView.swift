import MapKit
import SwiftUI

/// The big live map: every bus in the visible area, refreshed continuously,
/// with stops appearing as you zoom in.
struct LiveMapView: View {
    @Environment(\.busAPI) private var api
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationProvider.self) private var location

    @State private var stream: LiveVehiclesModel?
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06))))
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var stops: [Stop] = []
    @State private var stopsTask: Task<Void, Never>?
    @State private var selectedVehicle: VehiclePosition?
    @State private var followedVehicleID: Int?

    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            if showStops {
                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                        NavigationLink(value: stop) {
                            Circle()
                                .fill(BPColor.surfacePrimary)
                                .stroke(BPColor.signal, lineWidth: 2)
                                .frame(width: 12, height: 12)
                        }
                        .accessibilityLabel("Bus stop: \(stop.displayName)")
                    }
                    .annotationTitles(.hidden)
                }
            }

            ForEach(stream?.vehicles ?? []) { vehicle in
                Annotation(vehicle.routeLabel, coordinate: vehicle.coordinate, anchor: .center) {
                    VehicleMarker(vehicle: vehicle,
                                  isSelected: vehicle.id == selectedVehicle?.id)
                        .onTapGesture { selectedVehicle = vehicle }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            cameraMoved(to: context.region)
        }
        .overlay(alignment: .top) {
            statusBar
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailSheet(initialVehicle: vehicle,
                               stream: stream,
                               followedVehicleID: $followedVehicleID)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .navigationDestination(for: Stop.self) { stop in
            StopDetailView(stop: stop)
        }
        .navigationTitle("Live map")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            location.requestAccess()
            if stream == nil {
                stream = LiveVehiclesModel(api: api, settings: settings)
            }
            stream?.start()
        }
        .onDisappear {
            stream?.stop()
        }
        .onChange(of: stream?.vehicles ?? []) {
            followCameraIfNeeded()
        }
    }

    private var showStops: Bool {
        guard settings.showStopsOnMap, let region = visibleRegion else { return false }
        return BoundingBox(region: region).area < 0.02
    }

    private var statusBar: some View {
        HStack(spacing: BPSpacing.md) {
            LiveBadge()
            if let updated = stream?.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(stream?.vehicles.count ?? 0) buses")
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, BPSpacing.lg)
        .padding(.vertical, BPSpacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, BPSpacing.screenMargin)
        .padding(.top, BPSpacing.sm)
    }

    private func cameraMoved(to region: MKCoordinateRegion) {
        let box = BoundingBox(region: region)
        stream?.watch(.boundingBox(box))

        stopsTask?.cancel()
        guard settings.showStopsOnMap, box.area < 0.02 else {
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

    private func followCameraIfNeeded() {
        guard let followedVehicleID,
              let vehicle = stream?.vehicle(withID: followedVehicleID) else { return }
        withAnimation(.easeInOut) {
            position = .region(MKCoordinateRegion(
                center: vehicle.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
    }
}

/// Map marker: livery-coloured route pill with a heading arrow.
struct VehicleMarker: View {
    let vehicle: VehiclePosition
    var isSelected = false

    var body: some View {
        VStack(spacing: 1) {
            if let heading = vehicle.heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 9, weight: .black))
                    .rotationEffect(.degrees(heading))
                    .foregroundStyle(Color(hexString: vehicle.liveryBackground)
                                     ?? BPColor.routeFallback)
            }
            RoutePill(lineName: vehicle.routeLabel,
                      backgroundHex: vehicle.liveryBackground,
                      foregroundHex: vehicle.liveryForeground)
                .scaleEffect(isSelected ? 1.25 : 1)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel("Bus on route \(vehicle.routeLabel)\(vehicle.destination.map { " to \($0)" } ?? "")")
    }
}
