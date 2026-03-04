import SwiftUI

struct MainTabView: View {
    private enum Tab: Int {
        case dashboard
        case insights
        case diary
        case settings
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var showAddIntake = false
    @Environment(\.deepLinkAddIntake) private var deepLinkAddIntake

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
            tabContent

            // Floating log button
            logButton
        }
        .tint(Theme.lagoon)
        .onChange(of: selectedTab) {
            Haptics.selection()
        }
        .onChange(of: deepLinkAddIntake) {
            if deepLinkAddIntake {
                showAddIntake = true
            }
        }
        .sheet(isPresented: $showAddIntake) {
            NavigationStack {
                AddIntakeView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddIntake = false }
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
        .accessibilityLabel("Log water intake")
        .accessibilityHint("Opens the intake logging screen")
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
                InsightsView()
            }
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(Tab.insights)

            NavigationStack {
                DiaryView()
            }
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem {
                Label("Diary", systemImage: "book.fill")
            }
            .tag(Tab.diary)

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

#if DEBUG
#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
#endif
