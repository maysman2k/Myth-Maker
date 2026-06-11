import CoreLocation
import SwiftUI

struct StopsView: View {
    @Environment(\.busAPI) private var api
    @Environment(LocationProvider.self) private var location
    @Environment(FavoritesStore.self) private var favorites

    private enum Tab: String, CaseIterable {
        case nearby = "Nearby"
        case favourites = "Favourites"
    }

    @State private var tab: Tab = .nearby
    @State private var nearbyStops: [Stop] = []
    @State private var isLoadingNearby = false
    @State private var smsCode = ""
    @State private var codeLookupResult: Stop?
    @State private var codeLookupFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BPSpacing.lg) {
                smsCodeField

                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .nearby: nearbySection
                case .favourites: favouritesSection
                }
            }
            .padding(.horizontal, BPSpacing.screenMargin)
            .padding(.vertical, BPSpacing.md)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle("Stops")
        .navigationDestination(for: Stop.self) { stop in
            StopDetailView(stop: stop)
        }
        .task {
            location.requestAccess()
            await loadNearby()
        }
        .onChange(of: location.location) {
            Task { await loadNearby() }
        }
        .refreshable {
            await loadNearby()
        }
    }

    // MARK: SMS code lookup — the code printed on every stop flag

    private var smsCodeField: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            HStack {
                TextField("Stop code from the flag, e.g. mangjwd", text: $smsCode)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { lookUpCode() }
                Button("Find") { lookUpCode() }
                    .buttonStyle(.borderedProminent)
                    .disabled(smsCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let found = codeLookupResult {
                NavigationLink(value: found) {
                    StopRow(stop: found, distanceFrom: location.location)
                }
                .buttonStyle(.plain)
            } else if codeLookupFailed {
                Text("No stop with that code. Double-check the flag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func lookUpCode() {
        let code = smsCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        codeLookupFailed = false
        codeLookupResult = nil
        Task {
            if let stop = try? await api.stop(naptanCode: code) {
                codeLookupResult = stop
            } else {
                codeLookupFailed = true
            }
        }
    }

    // MARK: Nearby

    @ViewBuilder
    private var nearbySection: some View {
        if !location.isAuthorized && location.authorization != .notDetermined {
            BPEmptyState(symbol: "location.slash",
                         title: "Location is off",
                         message: "Allow location access in Settings to see stops near you, or find a stop by its code above.")
        } else if isLoadingNearby && nearbyStops.isEmpty {
            ProgressView("Finding stops near you…")
                .frame(maxWidth: .infinity)
                .padding(BPSpacing.xl)
        } else if nearbyStops.isEmpty {
            BPEmptyState(symbol: "bus",
                         title: "No stops found",
                         message: "Move the map or check back — stops within about a kilometre show up here.")
        } else {
            ForEach(nearbyStops) { stop in
                NavigationLink(value: stop) {
                    StopRow(stop: stop, distanceFrom: location.location)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadNearby() async {
        guard let coordinate = location.location?.coordinate else { return }
        isLoadingNearby = true
        defer { isLoadingNearby = false }
        let box = BoundingBox(center: coordinate, radiusMetres: 1000)
        guard let stops = try? await api.nearbyStops(in: box) else { return }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        nearbyStops = stops.sorted {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here)
                < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: here)
        }
    }

    // MARK: Favourites

    @ViewBuilder
    private var favouritesSection: some View {
        if favorites.stops.isEmpty {
            BPEmptyState(symbol: "star",
                         title: "No favourites yet",
                         message: "Star the stops you use every day and they'll live here, departures ready.")
        } else {
            ForEach(favorites.stops) { stop in
                NavigationLink(value: stop) {
                    StopRow(stop: stop, distanceFrom: location.location)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One stop in a list: name, indicator, route pills, distance.
struct StopRow: View {
    let stop: Stop
    var distanceFrom: CLLocation?

    var body: some View {
        HStack(spacing: BPSpacing.md) {
            Image(systemName: "bus")
                .font(.title3)
                .foregroundStyle(BPColor.signal)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: BPSpacing.xs) {
                Text(stop.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if !stop.lineNames.isEmpty {
                    Text(stop.lineNames.prefix(8).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let from = distanceFrom {
                let metres = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                    .distance(from: from)
                Text(metres < 1000
                     ? "\(Int(metres)) m"
                     : String(format: "%.1f km", metres / 1000))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .bpCard()
    }
}
