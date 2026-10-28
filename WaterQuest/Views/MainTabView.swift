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
    @State private var showAchievementCelebration = false
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.deepLinkAddIntake) private var deepLinkAddIntake
    @Environment(\.deepLinkTrophyRoom) private var deepLinkTrophyRoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.spookyTheme) private var spookyTheme

    var body: some View {
        tabContent
            .tint(spookyTheme ? SpookySeason.Palette.accent : Theme.lagoon)
            .fullScreenCover(isPresented: $showAchievementCelebration) {
                // A native presentation keeps the Duo's tab chrome from
                // intercepting taps on a visually overlaid celebration.
                if let pending = store.pendingAchievementUnlocks.first {
                    AchievementUnlockOverlay(achievement: pending) {
                        store.dismissPendingAchievement()
                        if store.pendingAchievementUnlocks.isEmpty {
                            showAchievementCelebration = false
                        }
                    }
                    .id(pending.id)
                    .transition(.opacity)
                    .presentationBackground(.clear)
                }
            }
            .spookySeasonInvite(canPresent: !showAddIntake && !showTrophyRoom && !showAchievementCelebration)
            .animation(reduceMotion ? nil : Theme.gentleSpring, value: store.pendingAchievementUnlocks.first?.id)
            .onChange(of: store.pendingAchievementUnlocks.first?.id) {
                presentPendingAchievement()
            }
            .onAppear(perform: presentPendingAchievement)
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
            .sheet(isPresented: $showAddIntake, onDismiss: presentPendingAchievement) {
                NavigationStack {
                    AddIntakeView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAddIntake = false }
                            }
                        }
                }
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
                // "Unlock" inside this sheet must present the paywall from here.
                .presentsPaywall()
            }
            .sheet(isPresented: $showTrophyRoom, onDismiss: presentPendingAchievement) {
                NavigationStack {
                    TrophyRoomView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showTrophyRoom = false }
                            }
                        }
                }
            }
    }

    private func presentPendingAchievement() {
        guard !showAddIntake, !showTrophyRoom,
              !store.pendingAchievementUnlocks.isEmpty else { return }
        showAchievementCelebration = true
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
                        .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.dashboard.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.insights.title, systemImage: AppTab.insights.symbol, value: .insights) {
                NavigationStack {
                    InsightsView()
                        .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.insights.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.diary.title, systemImage: AppTab.diary.symbol, value: .diary) {
                NavigationStack {
                    DiaryView()
                        .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.diary.rawValue, reduceMotion: reduceMotion))
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: .settings) {
                NavigationStack {
                    SettingsView()
                        .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.settings.rawValue, reduceMotion: reduceMotion))
            }
        }
        .tabViewStyle(.tabBarOnly)
    }

    // MARK: - iOS 17 Fallback

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
                    .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.dashboard.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }
            .tag(AppTab.dashboard)

            NavigationStack {
                InsightsView()
                    .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.insights.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.symbol) }
            .tag(AppTab.insights)

            NavigationStack {
                DiaryView()
                    .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.diary.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.diary.title, systemImage: AppTab.diary.symbol) }
            .tag(AppTab.diary)

            NavigationStack {
                SettingsView()
                    .modifier(AddIntakeToolbarButton(showAddIntake: $showAddIntake))
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(TabContentTransition(tabID: selectedTab.rawValue, ownerID: AppTab.settings.rawValue, reduceMotion: reduceMotion))
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
            .tag(AppTab.settings)
        }
    }
}

// MARK: - Add Intake Toolbar Button

/// The native navigation-bar "+" for logging water. As a toolbar item it gets
/// the system's Liquid Glass styling on iOS 26 and never overlaps content in
/// landscape or on either side of a fold.
private struct AddIntakeToolbarButton: ViewModifier {
    @Binding var showAddIntake: Bool

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
            }
    }

    private var addButton: some View {
        Button("Log water intake", systemImage: "plus") {
            showAddIntake = true
        }
        .accessibilityHint("Opens the intake logging screen")
    }
}

// MARK: - Tab Content Transition

/// A brief arrival cue on a real tab change, preserving each navigation stack.
private struct TabContentTransition: ViewModifier {
    let tabID: Int
    let ownerID: Int
    let reduceMotion: Bool
    @State private var arrivalTrigger = 0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat.zero, trigger: arrivalTrigger) { view, phase in
                view.opacity(1 - phase * 0.15).offset(y: phase * 6)
            } keyframes: { _ in
                MoveKeyframe(1)
                CubicKeyframe(0, duration: 0.24)
            }
            .onChange(of: tabID) {
                // Hidden native tabs do not render keyframes. Only start an
                // arrival for the tab that is actually becoming visible.
                if tabID == ownerID { arrivalTrigger += 1 }
            }
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
