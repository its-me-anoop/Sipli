import AppIntents

struct SipliAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log a drink in \(.applicationName)",
                "Add water in \(.applicationName)",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: GetTodaysHydrationIntent(),
            phrases: [
                "How much water have I had in \(.applicationName)",
                "What's my hydration in \(.applicationName)",
                "Check my water in \(.applicationName)",
            ],
            shortTitle: "Today's Hydration",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: OpenSipliIntent(),
            phrases: [
                "Open \(.applicationName)",
            ],
            shortTitle: "Open Sipli",
            systemImageName: "app.fill"
        )
    }
}
