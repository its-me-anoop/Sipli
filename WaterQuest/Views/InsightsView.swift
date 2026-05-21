import SwiftUI
import Charts
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedDate: Date?
    @State private var timeframe: Timeframe = .weekly
    @State private var heatmapMonthOffset = 0
    @State private var aiInsight: String?
    @State private var isGeneratingInsight = false
    @State private var viewModel = InsightsViewModel()
    @State private var streakPopScale: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chartData: [WeeklyDay] { viewModel.chartData }
    private var heatmapData: [HeatmapDay] { viewModel.heatmapData }
    private var trendData: TrendData { viewModel.trendData }

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

    private func heatmapColor(for day: HeatmapDay) -> Color {
        if day.totalML == 0 { return Theme.cardElevated }
        if day.ratio >= 1.0 { return Theme.mint }
        if day.ratio >= 0.8 { return Theme.lagoon.opacity(0.8) }
        if day.ratio >= 0.6 { return Theme.lagoon.opacity(0.6) }
        if day.ratio >= 0.4 { return Theme.lagoon.opacity(0.4) }
        return Theme.lagoon.opacity(0.2)
    }

    // MARK: - Body

    private var hasAnyEntries: Bool {
        !store.entries.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasAnyEntries {
                    VStack(spacing: 16) {
                        Spacer(minLength: 40)
                        Image(systemName: "chart.bar")
                            .font(.system(.largeTitle))
                            .foregroundStyle(.tertiary)
                        Text("No data yet")
                            .font(.title3.weight(.semibold))
                        Text("Start logging water on the Home tab to see your hydration trends, streaks, and insights here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }

                headerSummary

                if isRegular {
                    // iPad Multi-column layout
                    HStack(alignment: .top, spacing: 20) {
                        // Left Column
                        VStack(spacing: 20) {
                            DashboardCard(title: "Weekly Intake", icon: "chart.bar.fill") { chartSection }
                            DashboardCard(title: "Hydration Heatmap", icon: "square.grid.3x3.fill") { heatmapSection }
                        }

                        // Right Column
                        VStack(spacing: 20) {
                            DashboardCard(title: "Goal Breakdown", icon: "target") { breakdownSection }
                            if subscriptionManager.hasAccess(to: .fluidTypes), !store.entries.isEmpty {
                                DashboardCard(title: "Beverage Breakdown (Past \(timeframe.rawValue))", icon: "cup.and.saucer.fill") { beverageBreakdownSection }
                            }
                            DashboardCard(title: "Trends & Streaks", icon: "chart.line.uptrend.xyaxis") { trendsSection }
                        }
                    }

                    // Full-width AI Insights below columns
                    if subscriptionManager.hasAccess(to: .aiInsights) {
                        DashboardCard(title: "AI Insights", icon: "brain.head.profile.fill") { aiInsightsSection }
                    }
                } else {
                    // iPhone Stacked layout
                    VStack(spacing: 20) {
                        DashboardCard(title: "Weekly Intake", icon: "chart.bar.fill") { chartSection }
                        DashboardCard(title: "Goal Breakdown", icon: "target") { breakdownSection }
                        if subscriptionManager.hasAccess(to: .fluidTypes), !store.entries.isEmpty {
                            DashboardCard(title: "Beverage Breakdown (Past \(timeframe.rawValue))", icon: "cup.and.saucer.fill") { beverageBreakdownSection }
                        }
                        DashboardCard(title: "Hydration Heatmap", icon: "square.grid.3x3.fill") { heatmapSection }
                        DashboardCard(title: "Trends & Streaks", icon: "chart.line.uptrend.xyaxis") { trendsSection }
                        if subscriptionManager.hasAccess(to: .aiInsights) {
                            DashboardCard(title: "AI Insights", icon: "brain.head.profile.fill") { aiInsightsSection }
                        }
                    }
                }
            }
            .padding(isRegular ? 24 : 16)
        }
        .background { AppWaterBackground().ignoresSafeArea() }
        .navigationTitle("Insights")
        .task {
            viewModel.recompute(
                entries: store.entries,
                dailyGoalML: store.dailyGoal.totalML,
                timeframe: timeframe,
                heatmapMonthOffset: heatmapMonthOffset
            )
        }
        .onChange(of: store.entries.count) {
            viewModel.recompute(
                entries: store.entries,
                dailyGoalML: store.dailyGoal.totalML,
                timeframe: timeframe,
                heatmapMonthOffset: heatmapMonthOffset
            )
        }
        .onChange(of: timeframe) {
            viewModel.recompute(
                entries: store.entries,
                dailyGoalML: store.dailyGoal.totalML,
                timeframe: timeframe,
                heatmapMonthOffset: heatmapMonthOffset
            )
        }
        .onChange(of: heatmapMonthOffset) {
            viewModel.recompute(
                entries: store.entries,
                dailyGoalML: store.dailyGoal.totalML,
                timeframe: timeframe,
                heatmapMonthOffset: heatmapMonthOffset
            )
        }
    }

    private var isRegular: Bool { sizeClass == .regular }

    // MARK: - Header Summary

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
            HStack(alignment: .center, spacing: 8) {
                (Text("Your hydration ").foregroundStyle(Theme.ink)
                    + Text("trend.").italic().foregroundStyle(Theme.lagoon))
                    .font(Theme.editorialSerif(isRegular ? 32 : 28))
                Spacer(minLength: 0)
            }

            HStack(spacing: isRegular ? 16 : 14) {
                MetricTile(title: "Today", value: Formatters.percentString(min(1, store.todayTotalML / max(1, store.dailyGoal.totalML))), icon: "drop.fill", color: Theme.lagoon, isRegular: isRegular)
                MetricTile(title: "\(timeframe == .weekly ? "7-day" : "30-day") avg", value: Formatters.volumeString(ml: averageML, unit: store.profile.unitSystem), icon: "chart.bar.fill", color: Theme.mint, isRegular: isRegular)
                MetricTile(title: "Goal days", value: "\(daysGoalMet)/\(timeframe.daysCount)", icon: "checkmark.circle.fill", color: Theme.sun, isRegular: isRegular)
            }
        }
        .padding(.vertical, isRegular ? 12 : 8)
    }

    // MARK: - Chart Section

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

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        let goal = store.dailyGoal
        let hasPremiumAccess = subscriptionManager.hasPremiumAccess
        let displayedTarget = hasPremiumAccess ? goal.totalML : goal.baseML

        return VStack(spacing: 10) {
            BreakdownRow(title: "Base goal", value: goal.baseML, unitSystem: store.profile.unitSystem, icon: "figure.stand", tint: Theme.lagoon)

            if hasPremiumAccess {
                BreakdownRow(title: "Weather adjustment", value: goal.weatherAdjustmentML, unitSystem: store.profile.unitSystem, icon: "cloud.sun", tint: Theme.sun)
                BreakdownRow(title: "Workout adjustment", value: goal.workoutAdjustmentML, unitSystem: store.profile.unitSystem, icon: "figure.run", tint: Theme.coral)
            }

            Divider()

            HStack {
                Label("Daily target", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formatters.volumeString(ml: displayedTarget, unit: store.profile.unitSystem))
                    .font(.headline)
            }

            if hasPremiumAccess, goal.weatherAdjustmentML != 0 {
                Link(destination: Legal.weatherAttributionURL) {
                    HStack(spacing: 4) {
                        Text("Weather data provided by")
                        Image(systemName: "applelogo")
                        Text("Weather")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.lagoon.opacity(0.8))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Sources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Link("National Academies: Dietary Reference Intakes for Water (2005)", destination: Legal.hydrationBaseCitationURL)
                    .font(.caption)
                Link("CDC: Water and Healthier Drinks", destination: Legal.hydrationHeatCitationURL)
                    .font(.caption)
                Link("ACSM: Facts About Hydration & Electrolytes", destination: Legal.hydrationExerciseCitationURL)
                    .font(.caption)

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text("This app does not provide medical advice. Hydration goals are general wellness estimates based on the sources above. Consult a healthcare professional for guidance specific to your health needs.")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Beverage Breakdown Section

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

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthRef = calendar.date(byAdding: .month, value: -heatmapMonthOffset, to: today) ?? today
        let monthName = monthRef.formatted(.dateTime.month(.wide).year())

        let comps = calendar.dateComponents([.year, .month], from: monthRef)
        let startOfMonth = calendar.date(from: comps) ?? monthRef
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth) - calendar.firstWeekday
        let leadingBlanks = (weekdayOfFirst + 7) % 7

        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(Theme.quickSpring) {
                        heatmapMonthOffset = min(11, heatmapMonthOffset + 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Text(monthName)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Button {
                    withAnimation(Theme.quickSpring) {
                        heatmapMonthOffset = max(0, heatmapMonthOffset - 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(heatmapMonthOffset == 0)
            }

            // Weekday headers
            HStack(spacing: 4) {
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Leading blanks
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(heatmapData) { day in
                    let isFuture = day.date > today
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isFuture ? Color.clear : heatmapColor(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityElement()
                        .accessibilityLabel(isFuture
                            ? "Future date"
                            : "\(day.date.formatted(.dateTime.month(.abbreviated).day())): \(day.totalML > 0 ? "\(Int(day.ratio * 100)) percent of goal" : "No intake")")
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0.2, 0.4, 0.6, 0.8], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.lagoon.opacity(opacity))
                        .frame(width: 12, height: 12)
                }
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.mint)
                    .frame(width: 12, height: 12)
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        let data = trendData
        let columns = Array(repeating: GridItem(.flexible(), spacing: isRegular ? 12 : 8), count: 2)
        let wowValue = data.weekOverWeekChange ?? 0
        let wowIcon = wowValue >= 0 ? "arrow.up.right" : "arrow.down.right"
        let wowColor = wowValue >= 0 ? Theme.mint : Theme.coral

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: isRegular ? 12 : 8) {
                TrendTile(
                    title: "Current streak",
                    value: "\(data.currentStreak) days",
                    icon: "flame.fill",
                    color: Theme.coral,
                    isRegular: isRegular
                )
                .scaleEffect(streakPopScale)
                .onChange(of: data.currentStreak) { oldValue, newValue in
                    guard !reduceMotion, newValue > oldValue else { return }
                    streakPopScale = 1.18
                    withAnimation(Theme.quickSpring) {
                        streakPopScale = 1.0
                    }
                }
                TrendTile(
                    title: "Longest streak",
                    value: "\(data.longestStreak) days",
                    icon: "trophy.fill",
                    color: Theme.sun,
                    isRegular: isRegular
                )
                TrendTile(
                    title: "Week vs last",
                    value: data.weekOverWeekChange.map { String(format: "%+.0f%%", $0) } ?? "—",
                    icon: wowIcon,
                    color: wowColor,
                    isRegular: isRegular
                )
                TrendTile(
                    title: "Consistency",
                    value: String(format: "%.0f%%", data.consistency * 100),
                    icon: "checkmark.seal.fill",
                    color: Theme.lavender,
                    isRegular: isRegular
                )
            }

            // Best / Lowest day row
            HStack(spacing: isRegular ? 12 : 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Theme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.volumeString(ml: data.bestDay, unit: store.profile.unitSystem))
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(isRegular ? 14 : 10)
                .background(
                    RoundedRectangle(cornerRadius: isRegular ? 14 : 12, style: .continuous)
                        .fill(Theme.cardSurface)
                )

                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.coral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lowest day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(data.lowestDay.map { Formatters.volumeString(ml: $0, unit: store.profile.unitSystem) } ?? "—")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(isRegular ? 14 : 10)
                .background(
                    RoundedRectangle(cornerRadius: isRegular ? 14 : 12, style: .continuous)
                        .fill(Theme.cardSurface)
                )
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isGeneratingInsight {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating insight...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let insight = aiInsight {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.lavender)
                        .font(.body)
                    Text(insight)
                        .font(.subheadline)
                }
            }

            Button {
                Task { await generateAIInsight() }
            } label: {
                Label("Refresh insight", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(isGeneratingInsight)
        }
        .padding(.vertical, 6)
        .task {
            guard subscriptionManager.hasAccess(to: .aiInsights), aiInsight == nil else { return }
            await generateAIInsight()
        }
    }

    // MARK: - AI Insight Generation

    private func generateAIInsight() async {
        guard subscriptionManager.hasAccess(to: .aiInsights) else { return }
        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        let data = trendData
        let todayProgress = store.todayTotalML / max(1, store.dailyGoal.totalML)

        let prompt = """
            Generate a brief personalized hydration insight (2-3 sentences max).
            Today's progress: \(String(format: "%.0f", todayProgress * 100))%
            Current streak: \(data.currentStreak) days
            Week-over-week change: \(data.weekOverWeekChange.map { String(format: "%.0f%%", $0) } ?? "N/A")
            Consistency (30 days): \(String(format: "%.0f", data.consistency * 100))%
            Best day (30 days): \(Int(data.bestDay)) ml
            Lowest day (30 days): \(data.lowestDay.map { "\(Int($0)) ml" } ?? "N/A")
            Be encouraging and specific. No emojis.
            """

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let result = await _generateInsightWithFoundationModels(prompt: prompt) {
                aiInsight = result
                return
            }
        }
        #endif

        aiInsight = generateStaticInsight(data: data)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func _generateInsightWithFoundationModels(prompt: String) async -> String? {
        guard SystemLanguageModel.default.isAvailable else { return nil }

        let session = LanguageModelSession(instructions: """
            You are a hydration coach inside Sipli, a mobile hydration tracking app.
            Provide brief, personalized, encouraging insights about the user's hydration habits.
            Keep responses to 2-3 sentences. Be specific about their data. No emojis.
            """)

        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    #endif

    private func generateStaticInsight(data: TrendData) -> String {
        if data.currentStreak >= 7 {
            return "Incredible! You've hit your hydration goal \(data.currentStreak) days in a row. Your consistency is paying off — keep this momentum going."
        } else if data.currentStreak >= 3 {
            return "Nice streak! \(data.currentStreak) consecutive days of meeting your goal. You're building a solid hydration habit."
        }

        if let wow = data.weekOverWeekChange, wow > 10 {
            return "Your intake is up \(String(format: "%.0f", wow))% compared to last week. Great improvement — your body is thanking you."
        } else if let wow = data.weekOverWeekChange, wow < -10 {
            return "Your intake dipped \(String(format: "%.0f", abs(wow)))% from last week. Try setting a few extra reminders to get back on track."
        }

        if data.consistency >= 0.9 {
            return "You've logged water on \(String(format: "%.0f", data.consistency * 100))% of the last 30 days. That's outstanding consistency — hydration is clearly a habit for you."
        } else if data.consistency < 0.5 {
            return "You've been active \(String(format: "%.0f", data.consistency * 100))% of the last 30 days. Try to log at least one glass daily to build the habit."
        }

        return "Stay consistent with your hydration goals. Every glass counts toward better health and energy throughout the day."
    }

}

// MARK: - Supporting Types

struct WeeklyDay: Identifiable {
    let id = UUID()
    let date: Date
    let totalML: Double
}

struct HeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let totalML: Double
    let ratio: Double
}

struct TrendData {
    let currentStreak: Int
    let longestStreak: Int
    let weekOverWeekChange: Double?
    let consistency: Double
    let bestDay: Double
    let lowestDay: Double?

    static let empty = TrendData(
        currentStreak: 0,
        longestStreak: 0,
        weekOverWeekChange: nil,
        consistency: 0,
        bestDay: 0,
        lowestDay: nil
    )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct TrendTile: View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
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

#if DEBUG
#Preview("Insights") {
    PreviewEnvironment {
        InsightsView()
    }
}
#endif
