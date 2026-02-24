import SwiftUI
import Charts

enum Timeframe: String, CaseIterable, Identifiable {
    case weekly = "7 Days"
    case monthly = "30 Days"
    
    var id: String { rawValue }
    
    var daysCount: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        }
    }
}

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedDate: Date?
    @State private var timeframe: Timeframe = .weekly

    private var chartData: [WeeklyDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let limit = timeframe.daysCount

        return (0..<limit).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(limit - 1 - offset), to: today) else {
                return nil
            }

            let total = store.entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.effectiveML }

            return WeeklyDay(date: day, totalML: total)
        }
    }

    private var averageML: Double {
        let totals = chartData.map(\.totalML)
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    private var daysGoalMet: Int {
        let target = max(1, store.dailyGoal.totalML)
        return chartData.filter { $0.totalML >= target }.count
    }

    private var selectedDay: WeeklyDay? {
        guard let selectedDate else { return nil }
        return chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSummary
                
                if isRegular {
                    // iPad Multi-column layout
                    HStack(alignment: .top, spacing: 20) {
                        // Left Column
                        VStack(spacing: 20) {
                            DashboardCard(title: "Weekly Intake", icon: "chart.bar.fill") { chartSection }
                        }
                        
                        // Right Column
                        VStack(spacing: 20) {
                            DashboardCard(title: "Goal Breakdown", icon: "target") { breakdownSection }
                        if !store.entries.isEmpty {
                            DashboardCard(title: "Beverage Breakdown (Past \(timeframe.rawValue))", icon: "cup.and.saucer.fill") { beverageBreakdownSection }
                        }
                            DashboardCard(title: "Recent Entries", icon: "clock.fill") { recentEntriesSection }
                        }
                    }
                } else {
                    // iPhone Stacked layout
                    VStack(spacing: 20) {
                        DashboardCard(title: "Weekly Intake", icon: "chart.bar.fill") { chartSection }
                        DashboardCard(title: "Goal Breakdown", icon: "target") { breakdownSection }
                        if !store.entries.isEmpty {
                            DashboardCard(title: "Beverage Breakdown (Past \(timeframe.rawValue))", icon: "cup.and.saucer.fill") { beverageBreakdownSection }
                        }
                        DashboardCard(title: "Recent Entries", icon: "clock.fill") { recentEntriesSection }
                    }
                }
            }
            .padding(isRegular ? 24 : 16)
        }
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Insights")
    }

    private var isRegular: Bool { sizeClass == .regular }

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
            Text("Your hydration trend")
                .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))

            HStack(spacing: isRegular ? 16 : 14) {
                MetricTile(title: "Today", value: Formatters.percentString(min(1, store.todayTotalML / max(1, store.dailyGoal.totalML))), icon: "drop.fill", color: Theme.lagoon, isRegular: isRegular)
                MetricTile(title: "\(timeframe == .weekly ? "7-day" : "30-day") avg", value: Formatters.volumeString(ml: averageML, unit: store.profile.unitSystem), icon: "chart.bar.fill", color: Theme.mint, isRegular: isRegular)
                MetricTile(title: "Goal days", value: "\(daysGoalMet)/\(timeframe.daysCount)", icon: "checkmark.circle.fill", color: Theme.sun, isRegular: isRegular)
            }
        }
        .padding(.vertical, isRegular ? 12 : 8)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
            Picker("Timeframe", selection: $timeframe) {
                ForEach(Timeframe.allCases) { tf in
                    Text(tf.rawValue).tag(tf)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)
            
            Chart(chartData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Intake", day.totalML)
                )
                .foregroundStyle(day.totalML >= store.dailyGoal.totalML ? Theme.mint : Theme.lagoon)
                .cornerRadius(isRegular ? 6 : 4)
            }
            .frame(height: isRegular ? 280 : 190)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXSelection(value: $selectedDate)

            if let selectedDay {
                HStack {
                    Text(selectedDay.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.subheadline)
                    Spacer()
                    Text(Formatters.volumeString(ml: selectedDay.totalML, unit: store.profile.unitSystem))
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                Text("Select a bar to view details")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var breakdownSection: some View {
        let goal = store.dailyGoal

        return VStack(spacing: 10) {
            BreakdownRow(title: "Base goal", value: goal.baseML, unitSystem: store.profile.unitSystem, icon: "figure.stand", tint: Theme.lagoon)
            BreakdownRow(title: "Weather adjustment", value: goal.weatherAdjustmentML, unitSystem: store.profile.unitSystem, icon: "cloud.sun", tint: Theme.sun)
            BreakdownRow(title: "Workout adjustment", value: goal.workoutAdjustmentML, unitSystem: store.profile.unitSystem, icon: "figure.run", tint: Theme.coral)

            Divider()

            HStack {
                Label("Daily target", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))
                    .font(.headline)
            }

            if goal.weatherAdjustmentML != 0 {
                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                    HStack(spacing: 4) {
                        Text("Weather data provided by")
                        Image(systemName: "applelogo")
                        Text("Weather")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var beverageBreakdownSection: some View {
        Group {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let limit = timeframe.daysCount
            
            if let startDate = calendar.date(byAdding: .day, value: -(limit - 1), to: today) {
                let periodEntries = store.entries.filter { $0.date >= startDate }
                
                let groupedByType = Dictionary(grouping: periodEntries, by: \.fluidType)
                let sorted = groupedByType.sorted { lhs, rhs in
                    lhs.value.reduce(0) { $0 + $1.effectiveML } > rhs.value.reduce(0) { $0 + $1.effectiveML }
                }

                let totalEffectiveVolume = sorted.reduce(0) { total, element in
                    total + element.value.reduce(0) { $0 + $1.effectiveML }
                }

                VStack(spacing: 20) {
                    if totalEffectiveVolume > 0 {
                        Chart(sorted, id: \.key) { type, entries in
                            let effectiveTotal = entries.reduce(0) { $0 + $1.effectiveML }
                            
                            SectorMark(
                                angle: .value("Volume", effectiveTotal),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(type.color)
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
                        .overlay {
                            VStack {
                                Text("Total")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(Formatters.volumeString(ml: totalEffectiveVolume, unit: store.profile.unitSystem))
                                    .font(.headline)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(sorted, id: \.key) { type, entries in
                            let rawTotal = entries.reduce(0) { $0 + $1.volumeML }
                            let effectiveTotal = entries.reduce(0) { $0 + $1.effectiveML }

                            HStack(spacing: 10) {
                                Image(systemName: type.iconName)
                                    .foregroundStyle(type.color)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(entries.count) \((entries.count == 1) ? "entry" : "entries")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formatters.volumeString(ml: effectiveTotal, unit: store.profile.unitSystem))
                                        .font(.subheadline.weight(.semibold))
                                    if type.hydrationFactor < 1.0 {
                                        Text("(\(Formatters.volumeString(ml: rawTotal, unit: store.profile.unitSystem)) raw)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var recentEntriesSection: some View {
        let recent = store.entries.sorted { $0.date > $1.date }.prefix(8)

        return Group {
            if recent.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent)) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.fluidType.iconName)
                            .foregroundStyle(entry.fluidType.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(Formatters.volumeString(ml: entry.volumeML, unit: store.profile.unitSystem))
                                if entry.fluidType != .water {
                                    Text(entry.fluidType.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(entry.fluidType.color)
                                }
                            }
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct WeeklyDay: Identifiable {
    let id = UUID()
    let date: Date
    let totalML: Double
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isRegular: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isRegular ? 8 : 6) {
            Image(systemName: icon)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(color)
            Text(value)
                .font(isRegular ? .title3.weight(.semibold) : .headline)
            Text(title)
                .font(isRegular ? .subheadline : .caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isRegular ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: isRegular ? 14 : 12, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }
}

private struct BreakdownRow: View {
    let title: String
    let value: Double
    let unitSystem: UnitSystem
    let icon: String
    let tint: Color

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(value >= 0 ? "+" : "-")\(Formatters.shortVolume(ml: abs(value), unit: unitSystem)) \(unitSystem.volumeUnit)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
        }
    }
}

#Preview("Insights") {
    PreviewEnvironment {
        InsightsView()
    }
}
