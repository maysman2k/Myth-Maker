import MapKit
import SwiftUI

/// Full detail for a tapped bus: a focused live map of its route (tap to
/// open the full live map), live punctuality and destination, the journey's
/// calling points, and a link to the route's stops and offline timetable.
struct BusDetailView: View {
    @Environment(\.busAPI) private var api
    @Environment(SettingsStore.self) private var settings
    @Environment(AlarmManager.self) private var alarms
    @Environment(LocationProvider.self) private var location

    let bus: BusRef

    @State private var stream: LiveVehiclesModel?
    @State private var miniPosition: MapCameraPosition
    @State private var journey: TimetableTrip?
    @State private var journeyFailed = false
    @State private var showAlarmOptions = false
    @State private var alarmFeedback: String?

    init(bus: BusRef) {
        self.bus = bus
        _miniPosition = State(initialValue: .region(MKCoordinateRegion(
            center: bus.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))))
    }

    /// Freshest position for this bus, falling back to the tapped snapshot.
    private var vehicle: VehiclePosition? {
        stream?.vehicle(withID: bus.vehicleID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                focusedMap
                header
                alarmButton
                shareButton
                journeySection
                fullRouteLink
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Route \(bus.lineName)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Notify me when this bus is…", isPresented: $showAlarmOptions,
                            titleVisibility: .visible) {
            ForEach(AlarmDistances.options) { option in
                Button(option.label) { setAlarm(option.metres) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll buzz you when the \(bus.lineName) gets within range of where you are now. Keep the app open or recently used for the alarm to fire.")
        }
        .task {
            if let serviceID = bus.serviceID {
                if stream == nil {
                    stream = LiveVehiclesModel(api: api, settings: settings)
                }
                stream?.watch(.services([serviceID]))
                stream?.start()
            }
            await loadJourney()
        }
        .onDisappear { stream?.stop() }
    }

    // MARK: Focused map (tap to open the full live map for this route)

    @ViewBuilder
    private var focusedMap: some View {
        let map = Map(position: $miniPosition, interactionModes: []) {
            ForEach(stream?.vehicles ?? []) { vehicle in
                Annotation(vehicle.routeLabel, coordinate: vehicle.coordinate, anchor: .center) {
                    VehicleMarker(vehicle: vehicle)
                }
                .annotationTitles(.hidden)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: BPRadius.card, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Label("Open full map", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, BPSpacing.sm)
                .padding(.vertical, BPSpacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(BPSpacing.sm)
        }

        if let serviceID = bus.serviceID {
            NavigationLink {
                LiveMapView(mode: .routes(ServiceFocus(serviceIDs: [serviceID], lineNames: [bus.lineName])))
            } label: {
                map
            }
            .buttonStyle(.plain)
        } else {
            map
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack(spacing: BPSpacing.md) {
                RoutePill(lineName: bus.lineName,
                          backgroundHex: vehicle?.liveryBackground,
                          foregroundHex: vehicle?.liveryForeground)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle?.destination ?? bus.destination ?? "In service")
                        .font(BPFont.cardTitle)
                    if let name = vehicle?.vehicleName {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                LiveBadge()
            }
            HStack(spacing: BPSpacing.md) {
                if let delay = vehicle?.delaySeconds {
                    DelayChip(status: DelayStatus(delaySeconds: delay))
                }
                if let recorded = vehicle?.recordedAt {
                    Text("Seen \(recorded.formatted(.relative(presentation: .numeric)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .bpCard()
    }

    // MARK: Arrival alarm

    @ViewBuilder
    private var alarmButton: some View {
        VStack(spacing: BPSpacing.sm) {
            if let existing = alarms.alarm(forVehicle: bus.vehicleID) {
                HStack(spacing: BPSpacing.md) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(BPColor.signal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alarm set")
                            .font(.subheadline.weight(.semibold))
                        Text("We'll buzz you when it's \(existing.distanceShortLabel) away.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel", role: .destructive) {
                        alarms.cancelAlarm(forVehicle: bus.vehicleID)
                    }
                    .font(.caption.weight(.bold))
                }
                .bpCard()
            } else {
                Button {
                    showAlarmOptions = true
                } label: {
                    Label("Set arrival alarm", systemImage: "bell.badge")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BPSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(BPColor.signal)
            }
            if let alarmFeedback {
                Text(alarmFeedback)
                    .font(.caption)
                    .foregroundStyle(BPColor.late)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func setAlarm(_ metres: Double) {
        guard let reference = location.location?.coordinate else {
            alarmFeedback = "Turn on location to set an arrival alarm — we need to know where you're waiting."
            return
        }
        alarmFeedback = nil
        Task {
            let granted = await alarms.setAlarm(for: bus, metres: metres, reference: reference)
            if !granted {
                alarmFeedback = "Allow notifications for Wait Less in Settings to use arrival alarms."
            }
        }
    }

    private var shareButton: some View {
        ShareLink(item: shareURL, message: Text(shareText)) {
            Label("Share live bus", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, BPSpacing.sm)
        }
        .buttonStyle(.bordered)
    }

    // MARK: Journey

    @ViewBuilder
    private var journeySection: some View {
        if let journey, !journey.times.isEmpty {
            VStack(alignment: .leading, spacing: BPSpacing.sm) {
                Text("This journey")
                    .font(BPFont.cardTitle)
                ForEach(Array(journey.times.enumerated()), id: \.offset) { index, time in
                    HStack(spacing: BPSpacing.md) {
                        Image(systemName: index == 0 ? "circle.fill"
                              : index == journey.times.count - 1 ? "mappin.circle.fill"
                              : "smallcircle.filled.circle")
                            .font(.caption2)
                            .foregroundStyle(BPColor.signal)
                        Text(time.stopName ?? time.atcoCode ?? "Stop")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let seconds = time.departureSeconds ?? time.arrivalSeconds {
                            Text(TimeOfDay.label(forSeconds: seconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .bpCard()
        } else if bus.tripID != nil && !journeyFailed {
            HStack {
                ProgressView()
                Text("Loading journey…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BPSpacing.md)
        }
    }

    // MARK: Full route link

    @ViewBuilder
    private var fullRouteLink: some View {
        if let serviceID = bus.serviceID {
            NavigationLink {
                ServiceDetailView(service: Service(id: serviceID,
                                                   lineName: bus.lineName,
                                                   description: bus.destination ?? ""))
            } label: {
                HStack {
                    Label("Route stops & offline timetable", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .bpCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    private var shareURL: URL {
        WaitlessShare.bus(line: bus.lineName,
                          serviceID: bus.serviceID,
                          destination: vehicle?.destination ?? bus.destination)
    }

    private var shareText: String {
        WaitlessShare.busMessage(line: bus.lineName,
                                 destination: vehicle?.destination ?? bus.destination)
    }

    private func loadJourney() async {
        guard let tripID = bus.tripID else {
            journeyFailed = true
            return
        }
        do {
            journey = try await api.trip(id: tripID)
        } catch {
            journeyFailed = true
        }
    }
}
