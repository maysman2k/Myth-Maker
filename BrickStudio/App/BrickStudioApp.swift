import SwiftUI

@main
struct BrickStudioApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(BrickColor.gold)
        }
    }
}
