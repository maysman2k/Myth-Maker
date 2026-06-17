import CoreLocation
import Foundation
import Observation

/// Holds active bus arrival alarms and, while any exist, polls the live feed
/// for the relevant routes, measuring each tracked bus against its alarm's
/// reference point. When a bus comes within range it fires a local
/// notification and clears that alarm.
///
/// This is the foreground/recent-use version (v1). The server-push upgrade
/// (v2, fires with the app closed) will register these same alarms with the
/// backend instead of polling here.
@MainActor
@Observable
final class AlarmManager {

    private(set) var alarms: [BusAlarm] = []

    @ObservationIgnored private let api: BusTimesAPIProviding
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let notifications = LocalNotifications()
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// Stop chasing a bus that never arrives (e.g. it went out of service).
    @ObservationIgnored private let maxAge: TimeInterval = 2 * 60 * 60

    init(api: BusTimesAPIProviding, settings: SettingsStore) {
        self.api = api
        self.settings = settings
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("BusPulse", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("alarms.json")
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([BusAlarm].self, from: data) {
            alarms = stored
        }
        if !alarms.isEmpty { start() }
    }

    // MARK: Public

    func hasAlarm(forVehicle vehicleID: Int) -> Bool {
        alarms.contains { $0.vehicleID == vehicleID }
    }

    func alarm(forVehicle vehicleID: Int, kind: AlarmKind) -> BusAlarm? {
        alarms.first { $0.vehicleID == vehicleID && $0.kind == kind }
    }

    /// "Tell me when it's near me." Returns false if notification permission
    /// was refused (so the UI can nudge the user to Settings).
    @discardableResult
    func setAlarm(for bus: BusRef, metres: Double,
                  reference: CLLocationCoordinate2D) async -> Bool {
        let granted = await notifications.requestAuthorization()
        guard granted else { return false }

        alarms.removeAll { $0.vehicleID == bus.vehicleID && $0.kind == .proximity }
        alarms.append(BusAlarm(kind: .proximity,
                               vehicleID: bus.vehicleID,
                               serviceID: bus.serviceID,
                               lineName: bus.lineName,
                               destination: bus.destination,
                               thresholdMetres: metres,
                               reference: reference))
        persist()
        start()
        return true
    }

    /// "Tell me when this bus reaches a stop." Follows the public bus to the
    /// chosen stop; a small radius counts as "arrived".
    @discardableResult
    func setStopArrivalAlarm(for bus: BusRef, stopName: String,
                             stopCoordinate: CLLocationCoordinate2D) async -> Bool {
        let granted = await notifications.requestAuthorization()
        guard granted else { return false }

        alarms.removeAll { $0.vehicleID == bus.vehicleID && $0.kind == .stopArrival }
        alarms.append(BusAlarm(kind: .stopArrival,
                               vehicleID: bus.vehicleID,
                               serviceID: bus.serviceID,
                               lineName: bus.lineName,
                               destination: bus.destination,
                               thresholdMetres: 120,
                               reference: stopCoordinate,
                               targetName: stopName))
        persist()
        start()
        return true
    }

    func cancel(_ alarm: BusAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        persist()
        if alarms.isEmpty { stop() }
    }

    func cancelAlarm(forVehicle vehicleID: Int, kind: AlarmKind) {
        alarms.removeAll { $0.vehicleID == vehicleID && $0.kind == kind }
        persist()
        if alarms.isEmpty { stop() }
    }

    // MARK: Polling

    private func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !self.alarms.isEmpty, !Task.isCancelled {
                await self.check()
                // Poll briskly while an alarm is live — the server itself
                // updates every ~10s, so faster than this gains nothing.
                try? await Task.sleep(for: .seconds(10))
            }
            self?.clearTask()
        }
    }

    private func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func clearTask() {
        pollTask = nil
    }

    private func check() async {
        // Expire anything too old to still be meaningful.
        let now = Date.now
        let expired = alarms.filter { now.timeIntervalSince($0.createdAt) > maxAge }
        if !expired.isEmpty {
            alarms.removeAll { alarm in expired.contains { $0.id == alarm.id } }
            persist()
        }
        guard !alarms.isEmpty else { return }

        let serviceIDs = Array(Set(alarms.compactMap(\.serviceID)))
        guard !serviceIDs.isEmpty,
              let vehicles = try? await api.liveVehicles(serviceIDs: serviceIDs) else { return }

        var triggered: [BusAlarm] = []
        for alarm in alarms {
            guard let vehicle = vehicles.first(where: { $0.id == alarm.vehicleID }) else { continue }
            let busLocation = CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude)
            let distance = busLocation.distance(from: alarm.referenceLocation)
            // Compensate for stale data: estimate how far the bus has likely
            // travelled since its last reported position and fire that bit
            // earlier. Only for "near me" alarms — a "reached the stop" alarm
            // should mean it genuinely arrived, so no lead there.
            let lead: Double
            if alarm.kind == .proximity, let recorded = vehicle.recordedAt {
                let age = max(0, now.timeIntervalSince(recorded))
                lead = min(400, 9.0 * age) // ~20 mph * data age, capped at 400 m
            } else {
                lead = 0
            }
            if distance <= alarm.thresholdMetres + lead {
                triggered.append(alarm)
            }
        }

        for alarm in triggered {
            switch alarm.kind {
            case .proximity:
                notifications.fireBusNearby(lineName: alarm.lineName,
                                            destination: alarm.destination,
                                            distanceLabel: alarm.distanceShortLabel)
            case .stopArrival:
                notifications.fireBusAtStop(lineName: alarm.lineName,
                                            stopName: alarm.targetName ?? "the stop")
            }
        }
        if !triggered.isEmpty {
            alarms.removeAll { alarm in triggered.contains { $0.id == alarm.id } }
            persist()
            if alarms.isEmpty { stop() }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(alarms) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
