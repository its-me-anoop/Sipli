import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Insights")
                        .font(Theme.titleFont(size: 26))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 7 Days")
                            .font(Theme.titleFont(size: 18))
                            .foregroundColor(.white)

                        ForEach(lastSevenDays, id: \.date) { day in
                            HStack {
                                Text(day.label)
                                    .font(Theme.bodyFont(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 60, alignment: .leading)

                                ProgressView(value: min(1, day.totalML / max(1, store.dailyGoal.totalML)))
                                    .tint(Theme.mint)

                                Text(Formatters.shortVolume(ml: day.totalML, unit: store.profile.unitSystem) + " " + store.profile.unitSystem.volumeUnit)
                                    .font(Theme.bodyFont(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.card)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Goal Breakdown")
                            .font(Theme.titleFont(size: 18))
                            .foregroundColor(.white)

                        let goal = store.dailyGoal
                        breakdownRow(label: "Base", value: goal.baseML)
                        breakdownRow(label: "Weather", value: goal.weatherAdjustmentML)
                        breakdownRow(label: "Workout", value: goal.workoutAdjustmentML)
                        breakdownRow(label: "Total", value: goal.totalML, highlight: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.card)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Logs")
                            .font(Theme.titleFont(size: 18))
                            .foregroundColor(.white)

                        ForEach(recentEntries) { entry in
                            HStack {
                                Text(timeFormatter.string(from: entry.date))
                                    .font(Theme.bodyFont(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text(Formatters.volumeString(ml: entry.volumeML, unit: store.profile.unitSystem))
                                    .font(Theme.bodyFont(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.card)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var lastSevenDays: [(date: Date, label: String, totalML: Double)] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let total = store.entries.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.volumeML }
            let label = DateFormatter.shortWeekday.string(from: date)
            return (date, label, total)
        }.reversed()
    }

    private func breakdownRow(label: String, value: Double, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(Formatters.volumeString(ml: value, unit: store.profile.unitSystem))
                .font(Theme.bodyFont(size: highlight ? 16 : 14))
                .foregroundColor(highlight ? Theme.sun : .white)
        }
    }

    private var recentEntries: [HydrationEntry] {
        store.entries.sorted { $0.date > $1.date }.prefix(8).map { $0 }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }
}

private extension DateFormatter {
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

#Preview("Insights") {
    PreviewEnvironment {
        InsightsView()
    }
}
