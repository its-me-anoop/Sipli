import SwiftUI

/// Caches the three expensive data derivations from `InsightsView` so they
/// are not recomputed on every SwiftUI body evaluation.
///
/// Recomputes lazily whenever `entries.count` or `dailyGoalML` changes
/// (the cheapest stable invalidation key for append-only hydration data).
/// `heatmapData` additionally tracks `heatmapMonthOffset`.
@MainActor
@Observable
final class InsightsViewModel {

    // MARK: - Cached outputs

    private(set) var chartData: [WeeklyDay] = []
    private(set) var heatmapData: [HeatmapDay] = []
    private(set) var trendData: TrendData = .empty

    // MARK: - Last-seen invalidation keys

    private var lastEntriesCount: Int = -1
    private var lastDailyGoalML: Double = -1
    private var lastTimeframe: Timeframe = .weekly
    private var lastHeatmapMonthOffset: Int = -999

    // MARK: - Public recompute entry-point

    /// Call from `onChange(of:)` or `.task(id:)` in the view.
    func recompute(
        entries: [HydrationEntry],
        dailyGoalML: Double,
        timeframe: Timeframe,
        heatmapMonthOffset: Int,
        streakFreezeDates: [Date] = []
    ) {
        let entriesChanged = entries.count != lastEntriesCount || dailyGoalML != lastDailyGoalML
        let timeframeChanged = timeframe != lastTimeframe
        let heatmapOffsetChanged = heatmapMonthOffset != lastHeatmapMonthOffset

        if entriesChanged || timeframeChanged {
            chartData = Self.buildChartData(entries: entries, timeframe: timeframe)
            trendData = Self.buildTrendData(entries: entries, goalML: dailyGoalML, streakFreezeDates: streakFreezeDates)
        }

        if entriesChanged || heatmapOffsetChanged {
            heatmapData = Self.buildHeatmapData(entries: entries, goalML: dailyGoalML, monthOffset: heatmapMonthOffset)
        }

        lastEntriesCount = entries.count
        lastDailyGoalML = dailyGoalML
        lastTimeframe = timeframe
        lastHeatmapMonthOffset = heatmapMonthOffset
    }

    // MARK: - Static builders (pure, no captures)

    static func buildChartData(entries: [HydrationEntry], timeframe: Timeframe) -> [WeeklyDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let limit = timeframe.daysCount

        return (0..<limit).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(limit - 1 - offset), to: today) else {
                return nil
            }
            let total = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.effectiveML }
            return WeeklyDay(date: day, totalML: total)
        }
    }

    static func buildHeatmapData(entries: [HydrationEntry], goalML: Double, monthOffset: Int) -> [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let monthRef = calendar.date(byAdding: .month, value: -monthOffset, to: today) else { return [] }
        let comps = calendar.dateComponents([.year, .month], from: monthRef)
        guard let startOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        let goal = max(1, goalML)

        return range.compactMap { day -> HeatmapDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { return nil }
            let total = entries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.effectiveML }
            return HeatmapDay(date: date, totalML: total, ratio: min(1, total / goal))
        }
    }

    static func buildTrendData(entries: [HydrationEntry], goalML: Double, streakFreezeDates: [Date] = []) -> TrendData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let goal = max(1, goalML)

        var dailyTotals: [(date: Date, total: Double)] = []
        for offset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let total = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.effectiveML }
            dailyTotals.append((day, total))
        }

        // Shared, freeze-aware streak — identical math to the store and widget.
        let currentStreak = StreakCalculator.currentStreak(
            entries: entries,
            goalML: goal,
            freezeDates: streakFreezeDates
        )

        let frozen = Set(streakFreezeDates.map { calendar.startOfDay(for: $0) })
        var longestStreak = 0
        var tempStreak = 0
        for dt in dailyTotals.reversed() {
            if dt.total >= goal || frozen.contains(dt.date) {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 0
            }
        }

        let thisWeek = dailyTotals.prefix(7).map(\.total)
        let lastWeek = Array(dailyTotals.dropFirst(7).prefix(7)).map(\.total)
        let thisWeekAvg = thisWeek.isEmpty ? 0 : thisWeek.reduce(0, +) / Double(thisWeek.count)
        let lastWeekAvg = lastWeek.isEmpty ? 0 : lastWeek.reduce(0, +) / Double(lastWeek.count)
        let wow: Double? = lastWeekAvg > 0 ? ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100 : nil

        let last30 = Array(dailyTotals.prefix(30))
        let daysWithIntake = last30.filter { $0.total > 0 }.count
        let consistency = last30.isEmpty ? 0 : Double(daysWithIntake) / Double(last30.count)

        let last30Totals = last30.map(\.total)
        let bestDay = last30Totals.max() ?? 0
        let lowestDay = last30Totals.filter { $0 > 0 }.min()

        return TrendData(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            weekOverWeekChange: wow,
            consistency: consistency,
            bestDay: bestDay,
            lowestDay: lowestDay
        )
    }
}
