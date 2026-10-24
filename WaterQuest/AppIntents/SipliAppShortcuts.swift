import AppIntents

struct SipliAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // LogWater: App Shortcut phrases may bind at most ONE AppEnum/AppEntity
        // parameter (not Int). Amount phrases use `presetAmount`; fluid phrases
        // use `fluidType`. Free-form Int amounts still work from the Shortcuts app.
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                // Defaults (Int parameter stays 250)
                "Log water in \(.applicationName)",
                "Log a drink in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Record water in \(.applicationName)",
                "Track water in \(.applicationName)",
                "I drank water in \(.applicationName)",
                "Drink water in \(.applicationName)",
                // Amount AppEnum bound (covers "Log 300 milliliters of water in Sipli")
                "Log \(.$presetAmount) of water in \(.applicationName)",
                "Add \(.$presetAmount) of water in \(.applicationName)",
                "Record \(.$presetAmount) of water in \(.applicationName)",
                "Track \(.$presetAmount) of water in \(.applicationName)",
                "I drank \(.$presetAmount) of water in \(.applicationName)",
                "Drink \(.$presetAmount) of water in \(.applicationName)",
                "Had \(.$presetAmount) of water in \(.applicationName)",
                "Log \(.$presetAmount) in \(.applicationName)",
                "Add \(.$presetAmount) in \(.applicationName)",
                // Fluid type only (amount defaults to 250 unless Shortcuts supplies Int)
                "Log \(.$fluidType) in \(.applicationName)",
                "Add \(.$fluidType) in \(.applicationName)",
                "Record \(.$fluidType) in \(.applicationName)",
                "I drank \(.$fluidType) in \(.applicationName)",
                "Drink \(.$fluidType) in \(.applicationName)",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: GetTodaysHydrationIntent(),
            phrases: [
                "How much water have I had in \(.applicationName)",
                "How much water did I drink in \(.applicationName)",
                "How much did I drink today in \(.applicationName)",
                "How much have I drunk today in \(.applicationName)",
                "How much have I logged today in \(.applicationName)",
                "What's my hydration in \(.applicationName)",
                "What's my intake today in \(.applicationName)",
                "What's my water intake today in \(.applicationName)",
                "Am I on track in \(.applicationName)",
                "Check my water in \(.applicationName)",
                "Check my hydration in \(.applicationName)",
                "Show today's water in \(.applicationName)",
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
                "Another of the same in \(.applicationName)",
                "Repeat my last drink in \(.applicationName)",
                "Log that again in \(.applicationName)",
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
                "How many days in a row in \(.applicationName)",
                "What's my hydration streak in \(.applicationName)",
                "Show my streak in \(.applicationName)",
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
                "How much left in \(.applicationName)",
                "How much remaining in \(.applicationName)",
                "How much still to go in \(.applicationName)",
                "How much until my goal in \(.applicationName)",
                "How much more do I need in \(.applicationName)",
                "What's left today in \(.applicationName)",
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
                "Undo last drink in \(.applicationName)",
                "Delete my last drink in \(.applicationName)",
                "Take back my last drink in \(.applicationName)",
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
                "Open trophy room in \(.applicationName)",
                "Show my trophies in \(.applicationName)",
            ],
            shortTitle: "Achievements",
            systemImageName: "trophy.fill"
        )

        AppShortcut(
            intent: OpenSipliIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)",
                "Start \(.applicationName)",
            ],
            shortTitle: "Open Sipli",
            systemImageName: "app.fill"
        )
    }
}
