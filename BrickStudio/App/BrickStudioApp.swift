import SwiftUI

@main
struct BrickStudioApp: App {
    @State private var model = AppModel()
    @AppStorage("appAppearancePreference") private var appearancePreference = AppAppearancePreference.automatic.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(BrickColor.gold)
                .preferredColorScheme(selectedAppearance.colorScheme)
        }
    }

    private var selectedAppearance: AppAppearancePreference {
        AppAppearancePreference(rawValue: appearancePreference) ?? .automatic
    }
}
