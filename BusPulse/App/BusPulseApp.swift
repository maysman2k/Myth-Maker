import SwiftUI

@main
struct BusPulseApp: App {
    @State private var settings: SettingsStore
    @State private var timetables = TimetableStore()
    @State private var favorites = FavoritesStore()
    @State private var network = NetworkMonitor()
    @State private var location = LocationProvider()
    @State private var alarms: AlarmManager

    /// Where the app gets its data.
    /// DEBUG builds (running from Xcode) talk to your local BODS proxy in
    /// `Backend/` on localhost. Release builds use your deployed server —
    /// swap in your domain when you ship (see Backend/README.md).
    private let api: BusTimesAPIProviding

    init() {
        // Live backend on the droplet — the app talks to this on every
        // build now, so no local server is needed. For local backend work,
        // temporarily swap in: URL(string: "http://localhost:3000")!
        let api: BusTimesAPIProviding =
            BusTimesAPI(baseURL: URL(string: "https://waitless.bricksinabag.com")!)
        self.api = api
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _alarms = State(initialValue: AlarmManager(api: api, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(timetables)
                .environment(favorites)
                .environment(network)
                .environment(location)
                .environment(alarms)
                .environment(\.busAPI, api)
                .tint(BPColor.signal)
        }
    }
}

// MARK: - API injection

private struct BusAPIKey: EnvironmentKey {
    static let defaultValue: BusTimesAPIProviding = BusTimesAPI()
}

extension EnvironmentValues {
    var busAPI: BusTimesAPIProviding {
        get { self[BusAPIKey.self] }
        set { self[BusAPIKey.self] = newValue }
    }
}
