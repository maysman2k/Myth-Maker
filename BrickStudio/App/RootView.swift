import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.hasCompletedOnboarding {
                mainTabs
            } else {
                OnboardingFlow()
            }
        }
        .sheet(isPresented: $model.isShowingAuth) {
            AuthView()
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation { model.toast = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toast)
    }

    private var mainTabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            TodayView()
                .tabItem { Label(MainTab.today.title, systemImage: MainTab.today.symbol) }
                .tag(MainTab.today)
            NewsView()
                .tabItem { Label(MainTab.news.title, systemImage: MainTab.news.symbol) }
                .tag(MainTab.news)
            CreateView()
                .tabItem { Label(MainTab.create.title, systemImage: MainTab.create.symbol) }
                .tag(MainTab.create)
            ShopView()
                .tabItem { Label(MainTab.shop.title, systemImage: MainTab.shop.symbol) }
                .tag(MainTab.shop)
            BrickBarView()
                .tabItem { Label(MainTab.brickBar.title, systemImage: MainTab.brickBar.symbol) }
                .tag(MainTab.brickBar)
        }
    }
}
