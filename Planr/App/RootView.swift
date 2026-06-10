import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.currentUser == nil {
            OnboardingFlow()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Events", systemImage: "sparkles")
            }

            NavigationStack {
                MemoryVaultView()
            }
            .tabItem {
                Label("Memories", systemImage: "photo.stack")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}
