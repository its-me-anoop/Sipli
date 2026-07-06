import SwiftUI

/// Dashboard card body listing this week's three rotating quests.
/// Pure presentation — the caller supplies quests and progress.
struct WeeklyQuestCard: View {
    let quests: [(quest: WeeklyQuest, progress: QuestProgress)]
    let daysRemaining: Int

    private var completedCount: Int {
        quests.filter(\.progress.isComplete).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(headline)
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(countdown)
                    .font(Theme.sipliMono(10, weight: .medium, relativeTo: .caption2))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 12) {
                ForEach(quests, id: \.quest.id) { pair in
                    questRow(pair.quest, progress: pair.progress)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var headline: String {
        switch completedCount {
        case quests.count where !quests.isEmpty:
            return "All quests complete — take a bow."
        case 0:
            return "Three fresh quests this week."
        default:
            return "\(completedCount) of \(quests.count) quests complete."
        }
    }

    private var countdown: String {
        daysRemaining == 0 ? "LAST DAY" : "\(daysRemaining)d LEFT"
    }

    private func questRow(_ quest: WeeklyQuest, progress: QuestProgress) -> some View {
        HStack(spacing: 12) {
            Image(systemName: progress.isComplete ? "checkmark.circle.fill" : quest.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(progress.isComplete ? Theme.mintText : Theme.lagoon)
                .frame(width: 28)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(quest.title)
                        .font(Theme.titleFont(.subheadline))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(progress.done)/\(progress.target)")
                        .font(Theme.sipliMono(11, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(progress.isComplete ? Theme.mintText : Theme.textSecondary)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.lagoon.opacity(0.1))
                        Capsule()
                            .fill(progress.isComplete ? AnyShapeStyle(Theme.mintText) : AnyShapeStyle(Theme.lagoon))
                            .frame(width: max(6, geo.size.width * progress.fraction))
                            .animation(Theme.fluidSpring, value: progress.fraction)
                    }
                }
                .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(quest.detail): \(progress.done) of \(progress.target)\(progress.isComplete ? ", complete" : "")")
    }
}
