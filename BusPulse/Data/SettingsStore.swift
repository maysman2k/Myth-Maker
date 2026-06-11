import Foundation
import Observation

/// User preferences, backed by UserDefaults. Nothing sensitive lives here.
@MainActor
@Observable
final class SettingsStore {

    var refreshSeconds: Double {
        didSet { defaults.set(refreshSeconds, forKey: Keys.refreshSeconds) }
    }

    var showStopsOnMap: Bool {
        didSet { defaults.set(showStopsOnMap, forKey: Keys.showStopsOnMap) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let refreshSeconds = "refreshSeconds"
        static let showStopsOnMap = "showStopsOnMap"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Keys.refreshSeconds)
        refreshSeconds = stored >= 5 ? stored : 15
        showStopsOnMap = defaults.object(forKey: Keys.showStopsOnMap) as? Bool ?? true
    }
}
