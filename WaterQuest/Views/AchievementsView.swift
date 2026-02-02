import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: HydrationStore

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Quests & Badges")
                            .font(Theme.titleFont(size: 26))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Refresh") {
                            store.refreshQuests()
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Quests")
                            .font(Theme.titleFont(size: 18))
                            .foregroundColor(.white)

                        ForEach(store.gameState.quests) { quest in
                            let progress = min(1, quest.progressML / max(1, quest.targetML))
                            QuestCard(quest: quest, progress: progress)
                        }
                    }

                    Text("Achievements")
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(.white)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.gameState.achievements) { achievement in
                            AchievementBadgeView(achievement: achievement)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview("Quests") {
    PreviewEnvironment {
        AchievementsView()
    }
}
