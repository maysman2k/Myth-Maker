import CoreLocation
import MapKit
import SwiftUI

/// Direct-bus journey planner: pick a start and destination and see which
/// single buses get you there, with the next departures. (Multi-leg routing
/// with transfers is a future enhancement — see the note in the empty state.)
struct JourneyPlannerView: View {
    @Environment(\.busAPI) private var api
    @Environment(LocationProvider.self) private var location

    enum Field: Identifiable { case from, to; var id: Int { self == .from ? 0 : 1 } }
    enum LoadState: Equatable { case idle, loading, loaded, empty, failed(String) }

    @State private var fromCoordinate: CLLocationCoordinate2D?
    @State private var fromLabel = "My location"
    @State private var usingCurrentLocationForFrom = true
    @State private var toCoordinate: CLLocationCoordinate2D?
    @State private var toLabel = ""
    @State private var picking: Field?
    @State private var options: [JourneyOption] = []
    @State private var state: LoadState = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                fieldsCard
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
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Plan a journey")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picking) { field in
            JourneyPlaceSearchSheet(allowCurrentLocation: field == .from) { name, coordinate in
                set(field, name: name, coordinate: coordinate)
            }
        }
        .task { location.requestAccess() }
    }

    private var fieldsCard: some View {
        VStack(spacing: BPSpacing.sm) {
            fieldRow(title: "From", value: fromLabel, symbol: "smallcircle.filled.circle") { picking = .from }
            Divider()
            fieldRow(title: "To", value: toLabel.isEmpty ? "Choose destination" : toLabel,
                     symbol: "mappin.circle.fill",
                     placeholder: toLabel.isEmpty) { picking = .to }
        }
        .bpCard()
    }

    private func fieldRow(title: String, value: String, symbol: String,
                          placeholder: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BPSpacing.md) {
                Image(systemName: symbol).foregroundStyle(BPColor.signal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(placeholder ? .secondary : .primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

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
                Text("Shows buses you can take without changing. Multi-leg journeys with transfers are a planned enhancement.")
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

    // MARK: Logic

    private var resolvedFrom: CLLocationCoordinate2D? {
        usingCurrentLocationForFrom ? location.location?.coordinate : fromCoordinate
    }

    private var canPlan: Bool {
        resolvedFrom != nil && toCoordinate != nil
    }

    private func set(_ field: Field, name: String?, coordinate: CLLocationCoordinate2D?) {
        switch field {
        case .from:
            if let coordinate {
                fromCoordinate = coordinate
                usingCurrentLocationForFrom = false
                fromLabel = name ?? "Chosen location"
            } else {
                usingCurrentLocationForFrom = true
                fromLabel = "My location"
            }
        case .to:
            toCoordinate = coordinate
            toLabel = name ?? "Chosen location"
        }
    }

    private func plan() {
        guard let from = resolvedFrom, let to = toCoordinate else { return }
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

/// Pick a place by search, or (for the start) the user's current location.
private struct JourneyPlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let allowCurrentLocation: Bool
    let onPick: (String?, CLLocationCoordinate2D?) -> Void

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if allowCurrentLocation {
                    Button {
                        onPick(nil, nil) // nil coordinate signals "use my location"
                        dismiss()
                    } label: {
                        Label("Use my current location", systemImage: "location.fill")
                    }
                }
                ForEach(results, id: \.self) { item in
                    Button {
                        onPick(item.name, item.placemark.location?.coordinate)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Place").font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let detail = item.placemark.title {
                                Text(detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Search a place or postcode")
            .onChange(of: query) { _, value in search(value) }
            .navigationTitle("Choose a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func search(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.resultTypes = [.address, .pointOfInterest]
            let response = try? await MKLocalSearch(request: request).start()
            results = response?.mapItems ?? []
        }
    }
}
