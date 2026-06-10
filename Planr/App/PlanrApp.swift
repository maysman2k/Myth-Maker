import SwiftUI

@main
struct PlanrApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(PlanrColor.ember)
        }
    }
}
