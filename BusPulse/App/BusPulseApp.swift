import SwiftUI

@main
struct BusPulseApp: App {
    @State private var settings = SettingsStore()
    @State private var timetables = TimetableStore()
    @State private var favorites = FavoritesStore()
    @State private var network = NetworkMonitor()
    @State private var location = LocationProvider()

    private let api: BusTimesAPIProviding = BusTimesAPI()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(timetables)
                .environment(favorites)
                .environment(network)
                .environment(location)
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
