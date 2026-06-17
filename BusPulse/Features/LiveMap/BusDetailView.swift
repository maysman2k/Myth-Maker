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
    @State private var routeLines: [[CLLocationCoordinate2D]] = []
    @State private var showAlarmOptions = false
    @State private var showStopPicker = false
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
        .sheet(isPresented: $showStopPicker) {
            if let serviceID = bus.serviceID {
                AlarmStopPickerSheet(serviceID: serviceID, lineName: bus.lineName) { name, coordinate in
                    setStopAlarm(name: name, coordinate: coordinate)
                }
            }
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
            await loadRouteLine()
        }
        .onDisappear { stream?.stop() }
    }

    // MARK: Focused map (tap to open the full live map for this route)

    @ViewBuilder
    private var focusedMap: some View {
        let map = Map(position: $miniPosition, interactionModes: []) {
            ForEach(routeLines.indices, id: \.self) { index in
                MapPolyline(coordinates: routeLines[index])
                    .stroke(BPColor.signal, lineWidth: 3)
            }
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
            // "Near me" alarm.
            if let existing = alarms.alarm(forVehicle: bus.vehicleID, kind: .proximity) {
                alarmRow(icon: "bell.fill",
                         title: "Near-me alarm set",
                         detail: "We'll buzz you when it's \(existing.distanceShortLabel) away.") {
                    alarms.cancelAlarm(forVehicle: bus.vehicleID, kind: .proximity)
                }
            } else {
                Button {
                    showAlarmOptions = true
                } label: {
                    Label("Alarm when it's near me", systemImage: "bell.badge")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BPSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(BPColor.signal)
            }

            // "Reaches a stop" alarm.
            if let existing = alarms.alarm(forVehicle: bus.vehicleID, kind: .stopArrival) {
                alarmRow(icon: "mappin.circle.fill",
                         title: "Stop alarm set",
                         detail: "We'll tell you when it reaches \(existing.targetName ?? "the stop").") {
                    alarms.cancelAlarm(forVehicle: bus.vehicleID, kind: .stopArrival)
                }
            } else if bus.serviceID != nil {
                Button {
                    showStopPicker = true
                } label: {
                    Label("Alarm when it reaches a stop", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BPSpacing.sm)
                }
                .buttonStyle(.bordered)
            }

            if let alarmFeedback {
                Text(alarmFeedback)
                    .font(.caption)
                    .foregroundStyle(BPColor.late)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func alarmRow(icon: String, title: String, detail: String,
                          cancel: @escaping () -> Void) -> some View {
        HStack(spacing: BPSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(BPColor.signal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .destructive, action: cancel)
                .font(.caption.weight(.bold))
        }
        .bpCard()
    }

    private func setAlarm(_ metres: Double) {
        guard let reference = location.location?.coordinate else {
            alarmFeedback = "Turn on location to set a near-me alarm — we need to know where you're waiting."
            return
        }
        alarmFeedback = nil
        Task {
            let granted = await alarms.setAlarm(for: bus, metres: metres, reference: reference)
            if !granted {
                alarmFeedback = "Allow notifications for Wait Less in Settings to use alarms."
            }
        }
    }

    private func setStopAlarm(name: String, coordinate: CLLocationCoordinate2D) {
        alarmFeedback = nil
        Task {
            let granted = await alarms.setStopArrivalAlarm(for: bus, stopName: name,
                                                           stopCoordinate: coordinate)
            if !granted {
                alarmFeedback = "Allow notifications for Wait Less in Settings to use alarms."
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
        if let progress, !progress.upcoming.isEmpty {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: BPSpacing.sm) {
                    Text("Still to come")
                        .font(BPFont.cardTitle)
                    Text("Estimated arrival at each upcoming stop, based on where the bus is now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(progress.upcoming.enumerated()), id: \.element.id) { index, stop in
                        HStack(spacing: BPSpacing.md) {
                            Image(systemName: stop.isNext ? "location.fill"
                                  : index == progress.upcoming.count - 1 ? "mappin.circle.fill"
                                  : "smallcircle.filled.circle")
                                .font(.caption2)
                                .foregroundStyle(stop.isNext ? BPColor.live : BPColor.signal)
                            Text(stop.name)
                                .font(.subheadline.weight(stop.isNext ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer()
                            Text(etaLabel(stop.eta, now: context.date))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(stop.isNext ? BPColor.live : .secondary)
                        }
                    }
                    if progress.passedCount > 0 {
                        Text("\(progress.passedCount) stop\(progress.passedCount == 1 ? "" : "s") already passed")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .bpCard()
            }
        } else if bus.tripID != nil && !journeyFailed {
            HStack {
                ProgressView()
                Text("Working out the journey…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BPSpacing.md)
        }
    }

    /// Live journey progress for the tracked bus, recomputed from its current
    /// position against the scheduled stop times.
    private var progress: JourneyProgress.Result? {
        guard let journey, !journey.times.isEmpty else { return nil }
        let coordinate = vehicle?.coordinate ?? bus.coordinate
        return JourneyProgress.compute(times: journey.times,
                                       busCoordinate: coordinate,
                                       now: .now,
                                       dayStart: Calendar.current.startOfDay(for: .now))
    }

    private func etaLabel(_ eta: Date, now: Date) -> String {
        let seconds = eta.timeIntervalSince(now)
        if seconds < 60 { return "Due" }
        let minutes = Int(seconds / 60)
        if minutes <= 59 { return "\(minutes) min" }
        return eta.formatted(date: .omitted, time: .shortened)
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

    private func loadRouteLine() async {
        guard let serviceID = bus.serviceID,
              let geometry = try? await api.routeGeometry(serviceID: serviceID) else { return }
        routeLines = geometry.compactMap { segment in
            let coords = segment.compactMap { pair -> CLLocationCoordinate2D? in
                pair.count >= 2 ? CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0]) : nil
            }
            return coords.count > 1 ? coords : nil
        }
    }
}
