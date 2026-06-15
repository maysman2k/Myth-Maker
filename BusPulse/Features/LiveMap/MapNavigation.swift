import CoreLocation
import MapKit
import SwiftUI

// MARK: - Navigable values

/// One or more routes shown together on the focused live map.
struct ServiceFocus: Hashable {
    var serviceIDs: [Int]
    var lineNames: [String]
}

/// Lightweight snapshot of a live bus, used to navigate to its detail page.
struct BusRef: Hashable {
    var vehicleID: Int
    var serviceID: Int?
    var lineName: String
    var destination: String?
    var tripID: Int?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(vehicle: VehiclePosition) {
        vehicleID = vehicle.id
        serviceID = vehicle.serviceID
        lineName = vehicle.routeLabel
        destination = vehicle.destination
        tripID = vehicle.tripID
        latitude = vehicle.latitude
        longitude = vehicle.longitude
    }
}

// MARK: - Location search sheet

/// Search a place or postcode and recentre the map on it.
struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D) -> Void

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button {
                    if let coordinate = item.placemark.location?.coordinate {
                        onPick(coordinate)
                        dismiss()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Place")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let detail = item.placemark.title {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    BPEmptyState(symbol: "mappin.and.ellipse",
                                 title: "Find a location",
                                 message: "Search a town, area or postcode to jump the map there.")
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Place or postcode")
            .onChange(of: query) { _, value in search(value) }
            .navigationTitle("Search location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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

// MARK: - Add-route picker sheet

/// Search for a service and hand it back, e.g. to add the X83 alongside the 83.
struct ServicePickerSheet: View {
    @Environment(\.busAPI) private var api
    @Environment(\.dismiss) private var dismiss
    let onPick: (Service) -> Void

    @State private var query = ""
    @State private var results: [Service] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List(results) { service in
                Button {
                    onPick(service)
                    dismiss()
                } label: {
                    HStack(spacing: BPSpacing.md) {
                        RoutePill(lineName: service.lineName)
                        Text(service.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    BPEmptyState(symbol: "plus.magnifyingglass",
                                 title: "Add another route",
                                 message: "Search a route number to show it on the map too — handy for comparing, say, the 83 and the X83.")
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Route number or destination")
            .onChange(of: query) { _, value in search(value) }
            .navigationTitle("Add a route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func search(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if let found = try? await api.services(matching: trimmed) {
                results = found
            }
        }
    }
}
