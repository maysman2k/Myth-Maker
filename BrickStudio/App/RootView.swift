import SwiftUI
import UIKit

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
        .onAppear {
            ShopWebViewStore.shared.preload()
        }
        .task {
            await model.refreshSupabaseContent(quietErrors: true)
        }
    }

    private var mainTabs: some View {
        @Bindable var model = model
        return ZStack(alignment: .bottom) {
            Group {
                switch model.selectedTab {
                case .today:
                    TodayView()
                case .news:
                    NewsView()
                case .create:
                    CreateView()
                case .shop:
                    ShopView()
                case .brickBar:
                    BrickBarView()
                case .games:
                    GamesView()
                }
            }
            .padding(.bottom, 78)

            CustomMainTabBar(selection: $model.selectedTab)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct CustomMainTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(tab)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 23)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
                    .foregroundStyle(selection == tab ? .black : BrickColor.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selection == tab ? BrickColor.gold : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BrickColor.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    @ViewBuilder
    private func tabIcon(_ tab: MainTab) -> some View {
        if tab == .shop, UIImage(named: "ShopTabIcon") != nil {
            Image("ShopTabIcon")
                .renderingMode(.template)
        } else {
            Image(systemName: tab.symbol)
        }
    }
}
