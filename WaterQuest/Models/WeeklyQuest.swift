import Foundation

/// Progress toward one weekly quest. `done` is capped at `target` for display.
struct QuestProgress: Equatable {
    let done: Int
    let target: Int
    var isComplete: Bool { done >= target }
    var fraction: Double { target > 0 ? Double(done) / Double(target) : 0 }
}

/// A short-horizon goal that rotates weekly — the mid-term retention layer
/// between the daily streak and the seasonal Match Day event.
struct WeeklyQuest: Identifiable, Hashable {
    /// What the quest measures. All kinds are computable purely from this
    /// week's entries + the current goal, so nothing new is persisted and
    /// multi-device sync can't disagree.
    enum Kind {
        case goalDays      // days this week meeting the daily goal
        case varietyCount  // distinct fluid types logged this week
        case morningLogs   // drinks logged before noon this week
        case volumeLitres  // total effective litres this week
        case loggingDays   // days with at least one log this week
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let kind: Kind
    let target: Int
}

enum WeeklyQuests {
    /// The rotation pool. Three are drawn per calendar week, deterministically
    /// from the week number — every device picks the same three with no server.
    static let pool: [WeeklyQuest] = [
        WeeklyQuest(id: "quest.goal5",    title: "High Five",      detail: "Hit your goal on 5 days this week",    symbol: "target",              kind: .goalDays,     target: 5),
        WeeklyQuest(id: "quest.goal3",    title: "Hat Trick",      detail: "Hit your goal on 3 days this week",    symbol: "checkmark.circle",    kind: .goalDays,     target: 3),
        WeeklyQuest(id: "quest.variety4", title: "Mix It Up",      detail: "Log 4 different drinks this week",     symbol: "takeoutbag.and.cup.and.straw", kind: .varietyCount, target: 4),
        WeeklyQuest(id: "quest.variety2", title: "Change of Taste", detail: "Log 2 different drinks this week",    symbol: "cup.and.saucer",      kind: .varietyCount, target: 2),
        WeeklyQuest(id: "quest.morning5", title: "Early Riser",    detail: "Log 5 drinks before noon this week",   symbol: "sunrise",             kind: .morningLogs,  target: 5),
        WeeklyQuest(id: "quest.morning3", title: "Morning Person", detail: "Log 3 drinks before noon this week",   symbol: "sun.min",             kind: .morningLogs,  target: 3),
        WeeklyQuest(id: "quest.volume12", title: "Twelve Litres",  detail: "Drink 12 litres in total this week",   symbol: "drop.triangle",       kind: .volumeLitres, target: 12),
        WeeklyQuest(id: "quest.logging7", title: "Every Single Day", detail: "Log at least once every day",        symbol: "calendar",            kind: .loggingDays,  target: 7),
        WeeklyQuest(id: "quest.logging5", title: "Show Up",        detail: "Log at least once on 5 days",          symbol: "hand.wave",           kind: .loggingDays,  target: 5),
    ]

    /// The three quests active for the week containing `date`. Deterministic:
    /// a seeded Fisher–Yates shuffle keyed on (yearForWeekOfYear, weekOfYear),
    /// so every device — and every call — agrees without a backend.
    static func active(for date: Date = Date(), calendar: Calendar = .current) -> [WeeklyQuest] {
        let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        let week = comps.weekOfYear ?? 1
        let year = comps.yearForWeekOfYear ?? 2026

        var seed = UInt64(year) &* 521 &+ UInt64(week)
        var indices = Array(pool.indices)
        for i in indices.indices.reversed() where i > 0 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(seed % UInt64(i + 1))
            indices.swapAt(i, j)
        }
        return indices.prefix(3).map { pool[$0] }
    }

    /// Whole days left in the current week after today (0 on the last day).
    static func daysRemaining(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let today = calendar.startOfDay(for: now)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end).map { calendar.startOfDay(for: $0) } ?? today
        return max(0, calendar.dateComponents([.day], from: today, to: lastDay).day ?? 0)
    }

    /// Progress for one quest from this week's entries. Pure — mirrors
    /// `StreakCalculator` so it's shared-target-safe and unit-testable.
    static func progress(
        for quest: WeeklyQuest,
        entries: [HydrationEntry],
        goalML: Double,
        freezeDates: [Date] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuestProgress {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return QuestProgress(done: 0, target: quest.target)
        }
        let weekEntries = entries.filter { week.contains($0.date) }

        let raw: Int
        switch quest.kind {
        case .goalDays:
            guard goalML > 0 else { raw = 0; break }
            var totalByDay: [Date: Double] = [:]
            for entry in weekEntries {
                totalByDay[calendar.startOfDay(for: entry.date), default: 0] += entry.effectiveML
            }
            let frozen = Set(freezeDates.map { calendar.startOfDay(for: $0) }).filter { week.contains($0) }
            let met = Set(totalByDay.filter { $0.value >= goalML }.keys).union(frozen)
            raw = met.count
        case .varietyCount:
            raw = Set(weekEntries.map(\.fluidType)).count
        case .morningLogs:
            raw = weekEntries.filter { calendar.component(.hour, from: $0.date) < 12 }.count
        case .volumeLitres:
            raw = Int(weekEntries.reduce(0) { $0 + $1.effectiveML } / 1000)
        case .loggingDays:
            raw = Set(weekEntries.map { calendar.startOfDay(for: $0.date) }).count
        }

        return QuestProgress(done: min(raw, quest.target), target: quest.target)
    }
}
