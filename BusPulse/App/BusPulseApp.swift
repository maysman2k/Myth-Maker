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
        let api: BusTimesAPIProviding = {
            #if DEBUG
            return BusTimesAPI(baseURL: URL(string: "http://localhost:3000")!)
            #else
            // Set appToken to match the server's APP_SHARED_TOKEN when you deploy.
            return BusTimesAPI(baseURL: URL(string: "https://api.your-domain.com")!,
                               appToken: "")
            #endif
        }()
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
