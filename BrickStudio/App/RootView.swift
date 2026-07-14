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
            // Reserve space for the floating tab bar as a safe-area inset
            // (not padding) so each screen's background and scroll content
            // extend underneath it — that's what the glass blurs/reflects.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: 74)
                    .allowsHitTesting(false)
            }
            // Cross-fade with a gentle lift when switching tabs.
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .id(model.selectedTab)
            .animation(BrickMotion.smooth, value: model.selectedTab)

            CustomMainTabBar(selection: $model.selectedTab)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct CustomMainTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(BrickMotion.bouncy) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(tab)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 23)
                            .symbolEffect(.bounce, value: isSelected)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
                    .foregroundStyle(isSelected ? BrickColor.accentText : BrickColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if isSelected {
                            // The moving sunrise pill slides between tabs.
                            Capsule()
                                .fill(BrickGradient.sunrise)
                                .brickGlow(BrickColor.amber, radius: 12, strength: 0.5)
                                .matchedGeometryEffect(id: "selectedPill", in: pill)
                        }
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .liquidGlass(in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
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
