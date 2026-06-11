import Foundation
import Network
import Observation

/// Connectivity awareness so the app can lean on saved timetables and
/// say so clearly, instead of spinning forever.
@MainActor
@Observable
final class NetworkMonitor {

    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.bricksinabag.buspulse.network"))
    }
}
