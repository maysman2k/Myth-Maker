import CoreLocation
import MapKit
import SwiftUI

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

    @State private var options: [JourneyOption] = []
    @State private var state: LoadState = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                fieldsCard

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
                         title: "No direct buses found",
                         message: "No single bus links those points right now. Journeys needing a change of bus aren't planned yet — that's coming.")
        case .failed(let message):
            BPEmptyState(symbol: "exclamationmark.triangle", title: "Couldn't plan that", message: message)
        case .loaded:
            VStack(alignment: .leading, spacing: BPSpacing.md) {
                Text("Direct buses").font(BPFont.cardTitle)
                ForEach(options) { option in
                    NavigationLink {
                        ServiceDetailView(service: option.service)
                    } label: {
                        optionCard(option)
                    }
                    .buttonStyle(.plain)
                }
                Text("Sorted by shortest walk to a stop. Shows buses you can take without changing — multi-leg journeys with transfers are a planned enhancement.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func optionCard(_ option: JourneyOption) -> some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack(spacing: BPSpacing.md) {
                RoutePill(lineName: option.service.lineName)
                Text(option.service.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
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
                HStack(spacing: BPSpacing.sm) {
                    ForEach(option.departures, id: \.self) { time in
                        Text(time)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, BPSpacing.sm)
                            .padding(.vertical, BPSpacing.xs)
                            .background(Capsule().fill(BPColor.signal.opacity(0.15)))
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

    /// Tapping into a field clears it for fresh typing; leaving "From" empty
    /// falls back to the user's location so the field is never left invalid.
    private func onFocusChange(_ field: Field?) {
        if field == nil, fromText.isEmpty, fromCoordinate == nil, !usingCurrentLocationForFrom {
            usingCurrentLocationForFrom = true
            fromText = "My location"
        }
        places.clear()
        switch field {
        case .from:
            fromText = ""
            usingCurrentLocationForFrom = false
            fromCoordinate = nil
        case .to:
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
                let found = try await api.journeyOptions(fromLat: from.latitude, fromLon: from.longitude,
                                                         toLat: to.latitude, toLon: to.longitude)
                options = found
                state = found.isEmpty ? .empty : .loaded
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
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
