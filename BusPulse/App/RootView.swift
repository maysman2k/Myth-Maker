import SwiftUI

struct RootView: View {
    @Environment(NetworkMonitor.self) private var network
    @State private var deepLink: DeepLink?

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
        .onOpenURL { url in
            if let link = DeepLinkParser.parse(url) { deepLink = link }
        }
        .sheet(item: $deepLink) { link in
            NavigationStack {
                Group {
                    switch link {
                    case .route(let serviceID, let line, let description):
                        ServiceDetailView(service: Service(id: serviceID, lineName: line,
                                                           description: description))
                    case .stop(let atco, let name):
                        StopDetailView(stop: Stop(id: atco, name: name,
                                                  latitude: 0, longitude: 0, lineNames: []))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { deepLink = nil }
                    }
                }
            }
        }
    }
}
