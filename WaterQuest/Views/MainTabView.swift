import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "drop.fill")
                    Text("Today")
                }
            AddIntakeView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Insights")
                }
            AchievementsView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Quests")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tint(Theme.mint)
    }
}

#Preview("Main Tabs") {
    PreviewEnvironment {
        MainTabView()
    }
}
