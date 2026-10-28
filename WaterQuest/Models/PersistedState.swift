import Foundation

struct PremiumUpsellState: Codable {
    var nextEligibleAt: Date?
    var dismissCount: Int

    init(nextEligibleAt: Date? = nil, dismissCount: Int = 0) {
        self.nextEligibleAt = nextEligibleAt
        self.dismissCount = dismissCount
    }

    static let `default` = PremiumUpsellState()
}

/// Monotonic counters for engagement events that can't be derived from
/// entries (which surface logged/undid a drink). Feed secret achievements.
struct EngagementCounters: Codable, Equatable {
    var siriLogCount: Int
    var widgetLogCount: Int
    var undoCount: Int

    init(siriLogCount: Int = 0, widgetLogCount: Int = 0, undoCount: Int = 0) {
        self.siriLogCount = siriLogCount
        self.widgetLogCount = widgetLogCount
        self.undoCount = undoCount
    }

    static let zero = EngagementCounters()

    /// Per-field maximum — counters only ever grow, so the larger side of a
    /// multi-device merge is always the more complete one.
    func merged(with other: EngagementCounters) -> EngagementCounters {
        EngagementCounters(
            siriLogCount: max(siriLogCount, other.siriLogCount),
            widgetLogCount: max(widgetLogCount, other.widgetLogCount),
            undoCount: max(undoCount, other.undoCount)
        )
    }
}

struct PersistedState: Codable {
    var entries: [HydrationEntry]
    var profile: UserProfile
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary
    var hasPremiumAccess: Bool
    var premiumUpsellState: PremiumUpsellState
    /// Lifetime count of days the user has hit their daily hydration goal.
    /// Used to decide when to prompt for an App Store review.
    var goalCompletionCount: Int
    /// Start-of-day of the most recent day the user hit their goal.
    /// Used to dedupe same-day increments when multiple intakes cross the goal.
    var lastGoalCompletionDate: Date?
    /// Match Day (football-summer challenge): number of match days won.
    var matchDayWins: Int
    /// Start-of-day of the most recent match-day win, for same-day dedupe.
    var lastMatchDayWinDate: Date?
    /// Spooky Season (Halloween event): start-of-day dates the potion was brewed (goal hit).
    var spookyBrewDates: [Date]
    /// Banked streak-freeze tokens (earned every 7-day streak, capped).
    var streakFreezeTokens: Int
    /// Start-of-day dates that a freeze token retroactively covered.
    /// StreakCalculator treats these days as goal-met.
    var streakFreezeDates: [Date]
    /// Achievement id → date first earned. Latched: ids are only ever added.
    var unlockedAchievements: [String: Date]
    /// Monotonic engagement counters (Siri/widget logs, undos) for secret badges.
    var counters: EngagementCounters
    /// Entry id → removal date. Lets a delete made in one process (a Siri
    /// undo, the watch, another device) stick when another copy that still
    /// holds the entry merges. Pruned after `removedEntryRetention`.
    var removedEntryIDs: [UUID: Date]

    static let removedEntryRetention: TimeInterval = 30 * 24 * 60 * 60

    /// Records `ids` as removed and drops expired records.
    mutating func recordRemoval(of ids: [UUID], at date: Date) {
        for id in ids { removedEntryIDs[id] = date }
        removedEntryIDs = Self.pruned(removedEntryIDs, now: date)
    }

    /// Union of two removal maps, keeping the later date, minus expired ones.
    static func mergedRemovals(_ a: [UUID: Date], _ b: [UUID: Date], now: Date = Date()) -> [UUID: Date] {
        pruned(a.merging(b) { max($0, $1) }, now: now)
    }

    private static func pruned(_ removals: [UUID: Date], now: Date) -> [UUID: Date] {
        removals.filter { now.timeIntervalSince($0.value) < removedEntryRetention }
    }

    // `gameState`, `manualWeather`, and the legacy Earth Day 2026 keys are kept
    // in CodingKeys so old persisted JSON decodes without error — we just
    // ignore them on read and never emit them on write.
    private enum CodingKeys: String, CodingKey {
        case entries, profile, lastWeather, lastWorkout, hasPremiumAccess, premiumUpsellState, gameState, manualWeather
        case earthDay2026BannerDismissed, earthDay2026Earned
        case goalCompletionCount, lastGoalCompletionDate
        case matchDayWins, lastMatchDayWinDate
        case spookyBrewDates
        case streakFreezeTokens, streakFreezeDates
        case unlockedAchievements, counters
        case removedEntryIDs
    }

    init(
        entries: [HydrationEntry],
        profile: UserProfile,
        lastWeather: WeatherSnapshot?,
        lastWorkout: WorkoutSummary,
        hasPremiumAccess: Bool,
        premiumUpsellState: PremiumUpsellState,
        goalCompletionCount: Int = 0,
        lastGoalCompletionDate: Date? = nil,
        matchDayWins: Int = 0,
        lastMatchDayWinDate: Date? = nil,
        spookyBrewDates: [Date] = [],
        streakFreezeTokens: Int = 0,
        streakFreezeDates: [Date] = [],
        unlockedAchievements: [String: Date] = [:],
        counters: EngagementCounters = .zero,
        removedEntryIDs: [UUID: Date] = [:]
    ) {
        self.entries = entries
        self.profile = profile
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
        self.hasPremiumAccess = hasPremiumAccess
        self.premiumUpsellState = premiumUpsellState
        self.goalCompletionCount = goalCompletionCount
        self.lastGoalCompletionDate = lastGoalCompletionDate
        self.matchDayWins = matchDayWins
        self.lastMatchDayWinDate = lastMatchDayWinDate
        self.spookyBrewDates = spookyBrewDates
        self.streakFreezeTokens = streakFreezeTokens
        self.streakFreezeDates = streakFreezeDates
        self.unlockedAchievements = unlockedAchievements
        self.counters = counters
        self.removedEntryIDs = removedEntryIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries      = try c.decode([HydrationEntry].self, forKey: .entries)
        profile      = try c.decode(UserProfile.self,       forKey: .profile)
        lastWeather  = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout  = try c.decode(WorkoutSummary.self,    forKey: .lastWorkout)
        hasPremiumAccess = try c.decodeIfPresent(Bool.self, forKey: .hasPremiumAccess) ?? false
        premiumUpsellState = try c.decodeIfPresent(PremiumUpsellState.self, forKey: .premiumUpsellState) ?? .default
        goalCompletionCount    = try c.decodeIfPresent(Int.self,  forKey: .goalCompletionCount) ?? 0
        lastGoalCompletionDate = try c.decodeIfPresent(Date.self, forKey: .lastGoalCompletionDate)
        matchDayWins           = try c.decodeIfPresent(Int.self,  forKey: .matchDayWins) ?? 0
        lastMatchDayWinDate    = try c.decodeIfPresent(Date.self, forKey: .lastMatchDayWinDate)
        spookyBrewDates        = try c.decodeIfPresent([Date].self, forKey: .spookyBrewDates) ?? []
        streakFreezeTokens     = try c.decodeIfPresent(Int.self,  forKey: .streakFreezeTokens) ?? 0
        streakFreezeDates      = try c.decodeIfPresent([Date].self, forKey: .streakFreezeDates) ?? []
        unlockedAchievements   = try c.decodeIfPresent([String: Date].self, forKey: .unlockedAchievements) ?? [:]
        counters               = try c.decodeIfPresent(EngagementCounters.self, forKey: .counters) ?? .zero
        removedEntryIDs        = try c.decodeIfPresent([UUID: Date].self, forKey: .removedEntryIDs) ?? [:]
        // .gameState, .manualWeather, .earthDay2026* silently ignored if
        // present in old persisted JSON.
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entries,     forKey: .entries)
        try c.encode(profile,     forKey: .profile)
        try c.encode(lastWeather, forKey: .lastWeather)
        try c.encode(lastWorkout, forKey: .lastWorkout)
        try c.encode(hasPremiumAccess, forKey: .hasPremiumAccess)
        try c.encode(premiumUpsellState, forKey: .premiumUpsellState)
        try c.encode(goalCompletionCount,         forKey: .goalCompletionCount)
        try c.encodeIfPresent(lastGoalCompletionDate, forKey: .lastGoalCompletionDate)
        try c.encode(matchDayWins,                forKey: .matchDayWins)
        try c.encodeIfPresent(lastMatchDayWinDate, forKey: .lastMatchDayWinDate)
        try c.encode(spookyBrewDates,             forKey: .spookyBrewDates)
        try c.encode(streakFreezeTokens,          forKey: .streakFreezeTokens)
        try c.encode(streakFreezeDates,           forKey: .streakFreezeDates)
        try c.encode(unlockedAchievements,        forKey: .unlockedAchievements)
        try c.encode(counters,                    forKey: .counters)
        try c.encode(removedEntryIDs,             forKey: .removedEntryIDs)
    }

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        lastWeather: nil,
        lastWorkout: .empty,
        hasPremiumAccess: false,
        premiumUpsellState: .default
    )
}
