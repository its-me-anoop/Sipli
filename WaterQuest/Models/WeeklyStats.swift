import Foundation

/// Pure aggregation of the last seven days of hydration, used by the Weekly
/// Digest (AI narrative + static fallback). Everything injected, no store
/// access, so it's fully unit-testable.
struct WeeklyStats: Equatable {
    /// Total effective intake across the last 7 days (today inclusive).
    var totalML: Double
    /// Days (of 7) with at least one entry.
    var activeDays: Int
    /// Days (of 7) whose effective total met the goal.
    var goalHits: Int
    /// Weekday name of the highest-intake day, nil if the week is empty.
    var bestDayName: String?
    /// Effective intake of the best day.
    var bestDayML: Double
    /// Mean effective intake per day over the 7 days.
    var averageML: Double
    /// Percent change of this week's total vs the previous 7 days;
    /// nil when the previous week has no data.
    var weekOverWeekPercent: Double?

    static func compute(
        entries: [HydrationEntry],
        goalML: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyStats {
        let today = calendar.startOfDay(for: now)

        func dayTotal(offset: Int) -> (day: Date, total: Double)? {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.effectiveML }
            return (day, total)
        }

        let thisWeek = (0..<7).compactMap { dayTotal(offset: $0) }
        let lastWeek = (7..<14).compactMap { dayTotal(offset: $0) }

        let totalML = thisWeek.reduce(0) { $0 + $1.total }
        let activeDays = thisWeek.filter { $0.total > 0 }.count
        let goalHits = goalML > 0 ? thisWeek.filter { $0.total >= goalML }.count : 0

        let best = thisWeek.max { $0.total < $1.total }
        var bestDayName: String?
        if let best, best.total > 0 {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "EEEE"
            bestDayName = formatter.string(from: best.day)
        }

        let lastWeekTotal = lastWeek.reduce(0) { $0 + $1.total }
        let weekOverWeek: Double? = lastWeekTotal > 0
            ? ((totalML - lastWeekTotal) / lastWeekTotal) * 100
            : nil

        return WeeklyStats(
            totalML: totalML,
            activeDays: activeDays,
            goalHits: goalHits,
            bestDayName: bestDayName,
            bestDayML: best?.total ?? 0,
            averageML: totalML / 7,
            weekOverWeekPercent: weekOverWeek
        )
    }

    /// Deterministic digest used when the on-device model is unavailable.
    var staticDigest: String {
        var lines: [String] = []
        if goalHits >= 6 {
            lines.append("A near-perfect week — you hit your goal on \(goalHits) of 7 days.")
        } else if goalHits >= 3 {
            lines.append("Solid week: \(goalHits) of 7 days on goal.")
        } else if activeDays > 0 {
            lines.append("You logged water on \(activeDays) day\(activeDays == 1 ? "" : "s") this week — a base to build on.")
        } else {
            lines.append("A quiet week. A single glass today restarts the habit.")
        }
        if let bestDayName {
            lines.append("\(bestDayName) was your strongest day at \(Int(bestDayML)) mL.")
        }
        if let wow = weekOverWeekPercent {
            if wow >= 10 {
                lines.append("Intake is up \(Int(wow))% on last week.")
            } else if wow <= -10 {
                lines.append("Intake dipped \(Int(-wow))% from last week — tomorrow is a fresh start.")
            }
        }
        return lines.joined(separator: " ")
    }
}
