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
            intent: RepeatLastDrinkIntent(),
            phrases: [
                "Log my usual in \(.applicationName)",
                "Same again in \(.applicationName)",
                "Log the same drink in \(.applicationName)",
            ],
            shortTitle: "Log My Usual",
            systemImageName: "arrow.clockwise"
        )

        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my streak in \(.applicationName)",
                "How long is my streak in \(.applicationName)",
                "Check my streak in \(.applicationName)",
            ],
            shortTitle: "My Streak",
            systemImageName: "flame.fill"
        )

        AppShortcut(
            intent: GetRemainingIntent(),
            phrases: [
                "How much more water do I need in \(.applicationName)",
                "How much is left in \(.applicationName)",
                "What's remaining in \(.applicationName)",
            ],
            shortTitle: "Remaining Today",
            systemImageName: "hourglass"
        )

        AppShortcut(
            intent: UndoLastIntakeIntent(),
            phrases: [
                "Undo my last drink in \(.applicationName)",
                "Undo last water in \(.applicationName)",
                "Remove my last drink in \(.applicationName)",
            ],
            shortTitle: "Undo Last Drink",
            systemImageName: "arrow.uturn.backward"
        )

        AppShortcut(
            intent: OpenTrophyRoomIntent(),
            phrases: [
                "Show my achievements in \(.applicationName)",
                "Open my trophies in \(.applicationName)",
                "Show my badges in \(.applicationName)",
            ],
            shortTitle: "Achievements",
            systemImageName: "trophy.fill"
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
