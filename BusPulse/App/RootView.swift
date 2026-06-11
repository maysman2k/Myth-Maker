import SwiftUI

struct RootView: View {
    @Environment(NetworkMonitor.self) private var network

    var body: some View {
        VStack(spacing: 0) {
            if !network.isOnline {
                OfflineBanner()
            }
            TabView {
                NavigationStack {
                    LiveMapView()
                }
                .tabItem {
                    Label("Live map", systemImage: "map.fill")
                }

                NavigationStack {
                    StopsView()
                }
                .tabItem {
                    Label("Stops", systemImage: "bus")
                }

                NavigationStack {
                    ServiceSearchView()
                }
                .tabItem {
                    Label("Routes", systemImage: "magnifyingglass")
                }

                NavigationStack {
                    OfflineTimetablesView()
                }
                .tabItem {
                    Label("Saved", systemImage: "arrow.down.circle.fill")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
    }
}
