import CoreLocation
import MapKit
import SwiftUI

/// "HH:MM[:SS]" → "HH:MM" for display, wrapping GTFS past-midnight hours
/// ("24:15" → "00:15") onto the clock face.
private func displayClock(_ time: String) -> String {
    let pieces = time.split(separator: ":")
    guard pieces.count >= 2, let hour = Int(pieces[0]) else { return String(time.prefix(5)) }
    return String(format: "%02d:%@", hour % 24, String(pieces[1]))
}

/// Small "N live" indicator shown when the server sees vehicles out on a route.
private struct LiveNowBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 3) {
                Circle().fill(BPColor.signal).frame(width: 6, height: 6)
                Text("\(count) live")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BPColor.signal)
            }
        }
    }
}

/// Direct-bus journey planner: pick a start and destination and see which
/// single buses get you there, with the next departures. (Multi-leg routing
/// with transfers is a future enhancement — see the note in the empty state.)
///
/// Place entry is inline: tap the From/To field and type, and matching places
/// appear right below the fields — no separate modal. Results are biased to
/// the area you're in, so "Newcastle" surfaces the city centre first.
struct JourneyPlannerView: View {
    @Environment(\.busAPI) private var api
    @Environment(LocationProvider.self) private var location

    enum Field: Hashable { case from, to }
    enum LoadState: Equatable { case idle, loading, loaded, empty, failed(String) }

    @State private var fromText = "My location"
    @State private var toText = ""
    @State private var fromCoordinate: CLLocationCoordinate2D?
    @State private var usingCurrentLocationForFrom = true
    @State private var toCoordinate: CLLocationCoordinate2D?

    @FocusState private var focusedField: Field?
    @StateObject private var places = PlaceCompleter()

    /// What the field held before it was cleared for typing, so tapping in
    /// and tapping away without choosing doesn't lose the previous choice.
    private struct FieldStash { var text: String; var coordinate: CLLocationCoordinate2D?; var usingLocation: Bool }
    @State private var fromStash: FieldStash?
    @State private var toStash: FieldStash?

    @State private var direct: [JourneyOption] = []
    @State private var itineraries: [JourneyItinerary] = []
    @State private var state: LoadState = .idle

    enum When: Hashable { case leaveNow, arriveBy }
    @State private var when: When = .leaveNow
    @State private var arriveByTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                fieldsCard

                if focusedField == nil {
                    whenCard
                }

                if let field = focusedField {
                    suggestions(for: field)
                } else {
                    Button(action: plan) {
                        Label("Find buses", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(BPFont.cardTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BPSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BPColor.signal)
                    .disabled(!canPlan)

                    results
                }
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Plan a journey")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .task { location.requestAccess() }
        .onChange(of: fromText) { _, value in
            if focusedField == .from { places.search(value, around: searchRegion) }
        }
        .onChange(of: toText) { _, value in
            if focusedField == .to { places.search(value, around: searchRegion) }
        }
        .onChange(of: focusedField) { _, field in onFocusChange(field) }
    }

    // MARK: Fields

    private var fieldsCard: some View {
        VStack(spacing: BPSpacing.sm) {
            fieldRow(title: "From", text: $fromText, field: .from,
                     symbol: "smallcircle.filled.circle", prompt: "Start, or use my location")
            Divider()
            fieldRow(title: "To", text: $toText, field: .to,
                     symbol: "mappin.circle.fill", prompt: "Search destination")
        }
        .bpCard()
    }

    private var whenCard: some View {
        VStack(spacing: BPSpacing.sm) {
            Picker("When", selection: $when) {
                Text("Leave now").tag(When.leaveNow)
                Text("Arrive by").tag(When.arriveBy)
            }
            .pickerStyle(.segmented)

            if when == .arriveBy {
                DatePicker("Arrive by", selection: $arriveByTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
            }
        }
        .bpCard()
    }

    private func fieldRow(title: String, text: Binding<String>, field: Field,
                          symbol: String, prompt: String) -> some View {
        HStack(spacing: BPSpacing.md) {
            Image(systemName: symbol).foregroundStyle(BPColor.signal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                TextField(prompt, text: text)
                    .focused($focusedField, equals: field)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            if focusedField == field && !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Inline suggestions

    @ViewBuilder
    private func suggestions(for field: Field) -> some View {
        VStack(spacing: 0) {
            Button { useMyLocation(for: field) } label: {
                Label("Use my current location", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BPColor.signal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, BPSpacing.sm)
            }
            .buttonStyle(.plain)

            ForEach(Array(places.suggestions.enumerated()), id: \.offset) { _, item in
                Divider()
                Button { pick(item, for: field) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, BPSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .bpCard()
    }

    // MARK: Results

    @ViewBuilder
    private var results: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Finding buses…").frame(maxWidth: .infinity).padding(BPSpacing.xl)
        case .empty:
            BPEmptyState(symbol: "bus.trianglebadge.exclamationmark",
                         title: "No journey found",
                         message: "Nothing links those points in the next few hours — not even with a change of bus. Try a different time or destination. (Journeys needing two or more changes aren't planned yet.)")
        case .failed(let message):
            BPEmptyState(symbol: "exclamationmark.triangle", title: "Couldn't plan that", message: message)
        case .loaded:
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                if !direct.isEmpty {
                    VStack(alignment: .leading, spacing: BPSpacing.md) {
                        Text("Direct buses").font(BPFont.cardTitle)
                        ForEach(direct) { option in
                            NavigationLink {
                                ServiceDetailView(service: option.service)
                            } label: {
                                optionCard(option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !itineraries.isEmpty {
                    VStack(alignment: .leading, spacing: BPSpacing.md) {
                        Text(direct.isEmpty ? "No direct bus — with one change" : "Or with one change")
                            .font(BPFont.cardTitle)
                        if direct.isEmpty {
                            Text("There's no single bus for this trip. These journeys take one change of bus — times are checked so you can make the connection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(itineraries) { itinerary in
                            NavigationLink {
                                JourneyItineraryDetailView(itinerary: itinerary)
                            } label: {
                                itineraryCard(itinerary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Sorted by shortest walk / soonest arrival. Direct buses and journeys with a single change — trips needing two or more changes aren't planned yet.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                AdBannerSlot()
            }
        }
    }

    private func itineraryCard(_ itinerary: JourneyItinerary) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack {
                Label(itinerary.changes == 1 ? "1 change" : "\(itinerary.changes) changes",
                      systemImage: "arrow.triangle.swap")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BPColor.signal)
                Spacer()
                if let arrival = itinerary.arrival {
                    Text("Arrives \(hhmm(arrival))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            ForEach(itinerary.legs) { leg in
                legRow(leg)
            }
        }
        .bpCard()
    }

    @ViewBuilder
    private func legRow(_ leg: JourneyLeg) -> some View {
        switch leg.kind {
        case .walk:
            Label("Walk \(walkText(leg.walkMeters ?? 0)) to the next stop", systemImage: "figure.walk")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, BPSpacing.xs)
        case .bus:
            HStack(spacing: BPSpacing.md) {
                if let service = leg.service {
                    RoutePill(lineName: service.lineName)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(leg.fromStopName ?? "Stop") → \(leg.toStopName ?? "Stop")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let departure = leg.departure, let arrival = leg.arrival {
                        Text("\(hhmm(departure)) – \(hhmm(arrival))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                LiveNowBadge(count: leg.liveVehicles ?? 0)
            }
        }
    }

    /// "HH:MM:SS" (or "HH:MM") → "HH:MM".
    private func hhmm(_ time: String) -> String { displayClock(time) }

    private func optionCard(_ option: JourneyOption) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack(spacing: BPSpacing.md) {
                RoutePill(lineName: option.service.lineName)
                Text(option.service.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                LiveNowBadge(count: option.liveVehicles ?? 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            Label("\(option.fromStopName) → \(option.toStopName)", systemImage: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let metres = option.fromWalkMeters {
                Label("\(walkText(metres)) to your stop", systemImage: "figure.walk")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if option.departures.isEmpty {
                Text("No more departures today").font(.caption2).foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: BPSpacing.xs) {
                    ForEach(option.departures) { bus in
                        HStack(spacing: BPSpacing.xs) {
                            Text(displayClock(bus.departure))
                                .fontWeight(.semibold)
                            if let arrival = bus.arrival {
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                                Text(displayClock(arrival))
                                Text("arrive").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BPColor.signal)
                    }
                }
            }
        }
        .bpCard()
    }

    private func walkText(_ metres: Int) -> String {
        metres < 1000 ? "\(metres) m" : String(format: "%.1f km", Double(metres) / 1000)
    }

    // MARK: Logic

    /// Search bias: a box around the user (so "Newcastle" finds the nearest
    /// Newcastle first), falling back to the whole UK if location is unknown.
    private var searchRegion: MKCoordinateRegion {
        if let coordinate = location.location?.coordinate {
            return MKCoordinateRegion(center: coordinate,
                                      latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 54.5, longitude: -2.5),
                                  latitudinalMeters: 1_200_000, longitudinalMeters: 1_200_000)
    }

    private var resolvedFrom: CLLocationCoordinate2D? {
        usingCurrentLocationForFrom ? location.location?.coordinate : fromCoordinate
    }

    private var canPlan: Bool { resolvedFrom != nil && toCoordinate != nil }

    /// Tapping into a field stashes its value and clears it for fresh typing.
    /// Tapping away without choosing restores the stash, so an accidental tap
    /// never loses a chosen place; an empty "From" falls back to My location.
    private func onFocusChange(_ field: Field?) {
        if field == nil {
            if fromCoordinate == nil, !usingCurrentLocationForFrom {
                if let stash = fromStash {
                    fromText = stash.text
                    fromCoordinate = stash.coordinate
                    usingCurrentLocationForFrom = stash.usingLocation
                } else {
                    usingCurrentLocationForFrom = true
                    fromText = "My location"
                }
            }
            if toCoordinate == nil, let stash = toStash {
                toText = stash.text
                toCoordinate = stash.coordinate
            }
            fromStash = nil
            toStash = nil
        }
        places.clear()
        switch field {
        case .from:
            fromStash = FieldStash(text: fromText, coordinate: fromCoordinate,
                                   usingLocation: usingCurrentLocationForFrom)
            fromText = ""
            usingCurrentLocationForFrom = false
            fromCoordinate = nil
        case .to:
            if toCoordinate != nil || !toText.isEmpty {
                toStash = FieldStash(text: toText, coordinate: toCoordinate, usingLocation: false)
            }
            toText = ""
            toCoordinate = nil
        case nil:
            break
        }
    }

    private func useMyLocation(for field: Field) {
        focusedField = nil
        switch field {
        case .from:
            usingCurrentLocationForFrom = true
            fromCoordinate = nil
            fromText = "My location"
        case .to:
            toCoordinate = location.location?.coordinate
            toText = "My location"
        }
        places.clear()
    }

    private func pick(_ completion: MKLocalSearchCompletion, for field: Field) {
        Task {
            guard let resolved = await places.resolve(completion) else { return }
            focusedField = nil
            switch field {
            case .from:
                fromText = resolved.name
                fromCoordinate = resolved.coordinate
                usingCurrentLocationForFrom = false
            case .to:
                toText = resolved.name
                toCoordinate = resolved.coordinate
            }
            places.clear()
        }
    }

    private func plan() {
        guard let from = resolvedFrom, let to = toCoordinate else { return }
        focusedField = nil
        state = .loading
        Task {
            do {
                let plan = try await api.journeyOptions(fromLat: from.latitude, fromLon: from.longitude,
                                                        toLat: to.latitude, toLon: to.longitude,
                                                        arriveBy: when == .arriveBy ? arriveByTime : nil)
                direct = plan.direct
                itineraries = plan.itineraries
                state = (plan.direct.isEmpty && plan.itineraries.isEmpty) ? .empty : .loaded
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

/// Full breakdown of a single-change journey: each bus leg with all its
/// calling points and times, and the walk in between.
struct JourneyItineraryDetailView: View {
    let itinerary: JourneyItinerary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                header
                ForEach(itinerary.legs) { leg in
                    legSection(leg)
                }
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Your journey")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Label(itinerary.changes == 1 ? "1 change" : "\(itinerary.changes) changes",
                  systemImage: "arrow.triangle.swap")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BPColor.signal)
            Spacer()
            if let arrival = itinerary.arrival {
                Text("Arrives \(hhmm(arrival))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func legSection(_ leg: JourneyLeg) -> some View {
        switch leg.kind {
        case .walk:
            Label("Walk \(walkText(leg.walkMeters ?? 0)) to the next stop", systemImage: "figure.walk")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, BPSpacing.xs)
        case .bus:
            VStack(alignment: .leading, spacing: BPSpacing.sm) {
                HStack(spacing: BPSpacing.md) {
                    if let service = leg.service {
                        RoutePill(lineName: service.lineName)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.service?.description ?? "Bus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if let departure = leg.departure, let arrival = leg.arrival {
                            Text("\(hhmm(departure)) – \(hhmm(arrival))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    LiveNowBadge(count: leg.liveVehicles ?? 0)
                }
                if leg.stops.isEmpty {
                    Text("\(leg.fromStopName ?? "Start") → \(leg.toStopName ?? "End")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(leg.stops.enumerated()), id: \.element.id) { index, stop in
                            stopRow(stop, isEnd: index == 0 || index == leg.stops.count - 1)
                        }
                    }
                }
            }
            .bpCard()
        }
    }

    private func stopRow(_ stop: JourneyLegStop, isEnd: Bool) -> some View {
        HStack(spacing: BPSpacing.sm) {
            Text(stop.time.map(hhmm) ?? "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Image(systemName: isEnd ? "circle.fill" : "circle")
                .font(.system(size: 7))
                .foregroundStyle(isEnd ? BPColor.signal : .secondary)
            Text(stop.name)
                .font(.caption.weight(isEnd ? .semibold : .regular))
                .foregroundStyle(isEnd ? .primary : .secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func walkText(_ metres: Int) -> String {
        metres < 1000 ? "\(metres) m" : String(format: "%.1f km", Double(metres) / 1000)
    }

    private func hhmm(_ time: String) -> String { displayClock(time) }
}

/// As-you-type place suggestions via MapKit's local-search completer, with a
/// helper to resolve a chosen suggestion to coordinates. ObservableObject (not
/// @Observable) so it can be the delegate target MapKit calls on the main thread.
final class PlaceCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(_ fragment: String, around region: MKCoordinateRegion) {
        completer.region = region
        let trimmed = fragment.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { clear(); return }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
        completer.queryFragment = ""
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> (name: String, coordinate: CLLocationCoordinate2D)? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return nil }
        return (completion.title, item.placemark.coordinate)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
