import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var healthKit: HealthKitManager

    @State private var isRefreshing = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    progressCard

                    quickAdd

                    statsRow

                    questsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await refreshSignals()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile.name.isEmpty ? "Hydration Quest" : "Hey, \(store.profile.name)")
                    .font(Theme.titleFont(size: 26))
                    .foregroundColor(.white)
                Text("Level \(store.gameState.level) • \(store.gameState.xp) XP")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            MascotView()
        }
    }

    private var progressCard: some View {
        let goal = store.dailyGoal
        let progress = min(1, store.todayTotalML / max(1, goal.totalML))

        return VStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: progress)
                    .frame(width: 160, height: 160)
                VStack(spacing: 6) {
                    Text(Formatters.percentString(progress))
                        .font(Theme.titleFont(size: 28))
                        .foregroundColor(.white)
                    Text("\(Formatters.volumeString(ml: store.todayTotalML, unit: store.profile.unitSystem)) / \(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))")
                        .font(Theme.bodyFont(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                StatPill(label: "Streak", value: "\(store.gameState.streakDays) days")
                StatPill(label: "Coins", value: "\(store.gameState.coins)")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.card)
        )
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(Theme.titleFont(size: 18))
                .foregroundColor(.white)

            let unit = store.profile.unitSystem
            let buttons = unit == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]

            HStack(spacing: 12) {
                ForEach(buttons, id: \.self) { amount in
                    Button("+\(amount) \(unit.volumeUnit)") {
                        store.addIntake(amount: Double(amount), source: .manual)
                    }
                    .font(Theme.bodyFont(size: 14))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(Theme.lagoon.opacity(0.25))
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(label: "Weather", value: weatherText)
            StatPill(label: "Workout", value: "\(Int(store.lastWorkout.exerciseMinutes)) min")
        }
    }

    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Quests")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(.white)
                Spacer()
                if isRefreshing {
                    ProgressView()
                        .tint(Theme.mint)
                }
            }

            ForEach(store.gameState.quests) { quest in
                let progress = min(1, quest.progressML / max(1, quest.targetML))
                QuestCard(quest: quest, progress: progress)
            }
        }
    }

    private func refreshSignals() async {
        isRefreshing = true
        if store.profile.prefersHealthKit {
            let summary = await healthKit.fetchTodayWorkoutSummary()
            store.updateWorkout(summary)
        }
        if store.profile.prefersWeatherGoal {
            await weather.refresh()
            if let snapshot = weather.currentWeather {
                store.updateWeather(snapshot)
            }
        }
        store.refreshQuests()
        isRefreshing = false
    }

    private var weatherText: String {
        if let snapshot = store.activeWeather {
            return "\(Int(snapshot.temperatureC))°C"
        }
        return "--"
    }
}

#Preview("Dashboard") {
    PreviewEnvironment {
        DashboardView()
    }
}
