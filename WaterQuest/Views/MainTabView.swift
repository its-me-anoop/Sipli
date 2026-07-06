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
    @State private var showTrophyRoom = false
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.deepLinkAddIntake) private var deepLinkAddIntake
    @Environment(\.deepLinkTrophyRoom) private var deepLinkTrophyRoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        tabContent
            .tint(Theme.lagoon)
            .overlay {
                // Badge celebrations sit above the tabs so they present no
                // matter where the unlock happened (log, sync, watch entry).
                if let pending = store.pendingAchievementUnlocks.first {
                    AchievementUnlockOverlay(achievement: pending) {
                        store.dismissPendingAchievement()
                    }
                    .id(pending.id)
                    .zIndex(10)
                    .transition(.opacity)
                }
            }
            .animation(Theme.gentleSpring, value: store.pendingAchievementUnlocks.first?.id)
            .onChange(of: selectedTab) {
                Haptics.selection()
            }
            .onChange(of: deepLinkAddIntake) {
                if deepLinkAddIntake {
                    showAddIntake = true
                }
            }
            .onChange(of: deepLinkTrophyRoom) {
                guard deepLinkTrophyRoom else { return }
                if showAddIntake {
                    // Sibling sheets can't stack — retire the add-intake sheet
                    // first, then present once its dismissal settles.
                    showAddIntake = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showTrophyRoom = true
                    }
                } else {
                    showTrophyRoom = true
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
            .sheet(isPresented: $showTrophyRoom) {
                NavigationStack {
                    TrophyRoomView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showTrophyRoom = false }
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
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.insights.title, systemImage: AppTab.insights.symbol, value: .insights) {
                NavigationStack {
                    InsightsView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.diary.title, systemImage: AppTab.diary.symbol, value: .diary) {
                NavigationStack {
                    DiaryView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: .settings) {
                NavigationStack {
                    SettingsView()
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
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
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }
            .tag(AppTab.dashboard)

            NavigationStack {
                InsightsView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.symbol) }
            .tag(AppTab.insights)

            NavigationStack {
                DiaryView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.diary.title, systemImage: AppTab.diary.symbol) }
            .tag(AppTab.diary)

            NavigationStack {
                SettingsView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, reduceMotion: reduceMotion))
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
        content
            .background(Theme.lagoon, in: Circle())
            .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Tab Content Transition

/// Applies a cross-fade + subtle scale on tab switches.
/// The scale collapses to pure opacity when `reduceMotion` is true.
private struct TabContentTransition: ViewModifier {
    let tabID: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .animation(Theme.gentleSpring, value: tabID)
        } else {
            content
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
                .animation(Theme.gentleSpring, value: tabID)
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
