import Foundation
import Observation

/// Polls the live vehicle feed for whatever the user is looking at —
/// a map viewport, a set of services, or one followed bus. Backs off
/// exponentially on errors and pauses entirely when nothing is watching.
@MainActor
@Observable
final class LiveVehiclesModel {

    enum Query: Equatable {
        case boundingBox(BoundingBox)
        case services([Int])
    }

    private(set) var vehicles: [VehiclePosition] = []
    private(set) var lastUpdated: Date?
    private(set) var isPolling = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let api: BusTimesAPIProviding
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var query: Query?
    @ObservationIgnored private var backoffSeconds: Double = 0

    init(api: BusTimesAPIProviding, settings: SettingsStore) {
        self.api = api
        self.settings = settings
    }

    /// Updates what's being watched. Triggers an immediate refresh when
    /// the query changes; the poll loop keeps it fresh afterwards.
    func watch(_ newQuery: Query) {
        let changed = newQuery != query
        query = newQuery
        if pollTask == nil {
            start()
        } else if changed {
            Task { await refresh() }
        }
    }

    func start() {
        guard pollTask == nil else { return }
        isPolling = true
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                let interval = max(self.settings.refreshSeconds, 5) + self.backoffSeconds
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func refresh() async {
        guard let query else { return }
        do {
            let fresh: [VehiclePosition]
            switch query {
            case .boundingBox(let box):
                fresh = try await api.liveVehicles(in: box)
            case .services(let ids):
                fresh = try await api.liveVehicles(serviceIDs: ids)
            }
            vehicles = fresh
            lastUpdated = .now
            errorMessage = nil
            backoffSeconds = 0
        } catch {
            errorMessage = error.localizedDescription
            // 0 → 5 → 10 → 20 → 40 → cap 60 extra seconds between polls.
            backoffSeconds = min(60, backoffSeconds == 0 ? 5 : backoffSeconds * 2)
        }
    }

    func vehicle(withID id: Int) -> VehiclePosition? {
        vehicles.first { $0.id == id }
    }
}
