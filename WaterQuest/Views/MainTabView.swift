import SwiftUI

struct MainTabView: View {
    private enum AppTab: Int, CaseIterable, Identifiable {
        case dashboard
        case insights
        case diary
        case settings

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .dashboard: "Home"
            case .insights: "Insights"
            case .diary: "Diary"
            case .settings: "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: "house"
            case .insights: "chart.line.uptrend.xyaxis"
            case .diary: "book"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selectedTab: AppTab = .dashboard
    @State private var showAddIntake = false
    @Environment(\.deepLinkAddIntake) private var deepLinkAddIntake

    var body: some View {
        tabContent
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

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    // MARK: - iOS 18+ Native Tab View (Liquid Glass on iOS 26)

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol, value: .dashboard) {
                NavigationStack {
                    DashboardView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }

            Tab(AppTab.insights.title, systemImage: AppTab.insights.symbol, value: .insights) {
                NavigationStack {
                    InsightsView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }

            Tab(AppTab.diary.title, systemImage: AppTab.diary.symbol, value: .diary) {
                NavigationStack {
                    DiaryView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: .settings) {
                NavigationStack {
                    SettingsView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .modifier(FloatingAddButtonModifier(showAddIntake: $showAddIntake))
    }

    // MARK: - iOS 17 Fallback

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }
            .tag(AppTab.dashboard)

            NavigationStack {
                InsightsView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.symbol) }
            .tag(AppTab.insights)

            NavigationStack {
                DiaryView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem { Label(AppTab.diary.title, systemImage: AppTab.diary.symbol) }
            .tag(AppTab.diary)

            NavigationStack {
                SettingsView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
            .tag(AppTab.settings)
        }
        .modifier(FloatingAddButtonModifier(showAddIntake: $showAddIntake))
    }
}

// MARK: - Floating Action Button (Liquid Glass on iOS 26)

private struct FloatingAddButtonModifier: ViewModifier {
    @Binding var showAddIntake: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                fab
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
            }
    }

    private var fab: some View {
        Button {
            Haptics.impact(.medium)
            showAddIntake = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
        }
        .modifier(GlassFABStyle())
        .accessibilityLabel("Log water intake")
        .accessibilityHint("Opens the intake logging screen")
    }
}

private struct GlassFABStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(Theme.lagoon).interactive(),
                    in: .circle
                )
        } else {
            content
                .background(Theme.lagoon, in: Circle())
                .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)
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
