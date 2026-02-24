import SwiftUI

struct MainTabView: View {
    private enum Tab: Int {
        case dashboard
        case insights
        case settings
    }

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Tab = .dashboard
    @State private var showPaywall = false
    @State private var showAddIntake = false

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = .clear
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                AppWaterBackground().ignoresSafeArea()

                tabContent
            }

            // Floating log button
            logButton
        }
        .tint(Theme.lagoon)
        .onChange(of: selectedTab) {
            Haptics.selection()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isDismissible: true)
        }
        .sheet(isPresented: $showAddIntake) {
            NavigationStack {
                AddIntakeView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showAddIntake = false }
                        }
                    }
            }
        }
    }

    private var logButton: some View {
        Button {
            Haptics.impact(.medium)
            showAddIntake = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(Theme.lagoon)
                        .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
        .padding(.trailing, sizeClass == .regular ? 32 : 20)
        .padding(.bottom, sizeClass == .regular ? 32 : 78)
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.dashboard)

            NavigationStack {
                gatedContainer(
                    title: "Insights",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: "Unlock weekly trends and richer hydration analysis.",
                    content: { InsightsView() }
                )
            }
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(Tab.insights)

            NavigationStack {
                SettingsView()
            }
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .background(Color.clear)
        .iPadSidebarStyle()
    }

    @ViewBuilder
    private func gatedContainer<Content: View>(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if subscriptionManager.isPro {
            content()
        } else {
            LockedFeatureView(
                title: title,
                systemImage: systemImage,
                description: description,
                onUnlock: { showPaywall = true }
            )
        }
    }
}

private struct LockedFeatureView: View {
    let title: String
    let systemImage: String
    let description: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.lagoon)
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )

            VStack(spacing: 8) {
                Text("\(title) is part of Pro")
                    .font(.title2.weight(.semibold))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button("Unlock Pro") {
                Haptics.impact(.medium)
                onUnlock()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private extension View {
    @ViewBuilder
    func iPadSidebarStyle() -> some View {
        if #available(iOS 18.0, *) {
            self.tabViewStyle(.sidebarAdaptable)
        } else {
            self
        }
    }
}

#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
