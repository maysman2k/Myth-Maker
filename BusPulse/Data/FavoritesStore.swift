import Foundation
import Observation

/// Pinned stops and services, persisted as one small JSON file.
@MainActor
@Observable
final class FavoritesStore {

    private(set) var stops: [Stop] = []
    private(set) var services: [Service] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let encoder = JSONEncoder()

    private struct Payload: Codable {
        var stops: [Stop] = []
        var services: [Service] = []
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("BusPulse", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("favourites.json")
        if let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            stops = payload.stops
            services = payload.services
        }
    }

    func isFavorite(_ stop: Stop) -> Bool {
        stops.contains { $0.id == stop.id }
    }

    func isFavorite(_ service: Service) -> Bool {
        services.contains { $0.id == service.id }
    }

    func toggle(_ stop: Stop) {
        if let index = stops.firstIndex(where: { $0.id == stop.id }) {
            stops.remove(at: index)
        } else {
            stops.append(stop)
        }
        persist()
    }

    func toggle(_ service: Service) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services.remove(at: index)
        } else {
            services.append(service)
        }
        persist()
    }

    private func persist() {
        let payload = Payload(stops: stops, services: services)
        if let data = try? encoder.encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
