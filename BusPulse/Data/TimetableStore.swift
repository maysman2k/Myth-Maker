import Foundation
import Observation

/// Saved timetables for offline use. One JSON file per service in
/// Application Support; everything readable with no connection at all.
@MainActor
@Observable
final class TimetableStore {

    private(set) var timetables: [CachedTimetable] = []
    private(set) var downloadingServiceIDs: Set<Int> = []

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("BusPulseTimetables", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadAll()
    }

    func timetable(forServiceID id: Int) -> CachedTimetable? {
        timetables.first { $0.service.id == id }
    }

    func isDownloading(serviceID: Int) -> Bool {
        downloadingServiceIDs.contains(serviceID)
    }

    /// Downloads today's trips for a service and stores them for offline use.
    func download(service: Service, using api: BusTimesAPIProviding,
                  date: Date = .now) async throws {
        guard !downloadingServiceIDs.contains(service.id) else { return }
        downloadingServiceIDs.insert(service.id)
        defer { downloadingServiceIDs.remove(service.id) }

        let trips = try await api.trips(serviceID: service.id, date: date)
        let timetable = CachedTimetable(service: service, date: date,
                                        downloadedAt: .now, trips: trips)
        save(timetable)
    }

    func delete(serviceID: Int) {
        try? FileManager.default.removeItem(at: fileURL(forServiceID: serviceID))
        timetables.removeAll { $0.service.id == serviceID }
    }

    func deleteAll() {
        for timetable in timetables {
            try? FileManager.default.removeItem(at: fileURL(forServiceID: timetable.service.id))
        }
        timetables = []
    }

    var totalSizeBytes: Int {
        timetables.reduce(0) { total, timetable in
            let url = fileURL(forServiceID: timetable.service.id)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }

    // MARK: Disk

    private func save(_ timetable: CachedTimetable) {
        guard let data = try? encoder.encode(timetable) else { return }
        try? data.write(to: fileURL(forServiceID: timetable.service.id), options: .atomic)
        timetables.removeAll { $0.service.id == timetable.service.id }
        timetables.append(timetable)
        timetables.sort { $0.service.lineName < $1.service.lineName }
    }

    private func loadAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: nil)) ?? []
        timetables = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(CachedTimetable.self, from: data)
            }
            .sorted { $0.service.lineName < $1.service.lineName }
    }

    private func fileURL(forServiceID id: Int) -> URL {
        directory.appendingPathComponent("service-\(id).json")
    }
}
