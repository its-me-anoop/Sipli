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
    /// Banked streak-freeze tokens (earned every 7-day streak, capped).
    var streakFreezeTokens: Int
    /// Start-of-day dates that a freeze token retroactively covered.
    /// StreakCalculator treats these days as goal-met.
    var streakFreezeDates: [Date]

    // `gameState`, `manualWeather`, and the legacy Earth Day 2026 keys are kept
    // in CodingKeys so old persisted JSON decodes without error — we just
    // ignore them on read and never emit them on write.
    private enum CodingKeys: String, CodingKey {
        case entries, profile, lastWeather, lastWorkout, hasPremiumAccess, premiumUpsellState, gameState, manualWeather
        case earthDay2026BannerDismissed, earthDay2026Earned
        case goalCompletionCount, lastGoalCompletionDate
        case matchDayWins, lastMatchDayWinDate
        case streakFreezeTokens, streakFreezeDates
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
        streakFreezeTokens: Int = 0,
        streakFreezeDates: [Date] = []
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
        self.streakFreezeTokens = streakFreezeTokens
        self.streakFreezeDates = streakFreezeDates
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
        streakFreezeTokens     = try c.decodeIfPresent(Int.self,  forKey: .streakFreezeTokens) ?? 0
        streakFreezeDates      = try c.decodeIfPresent([Date].self, forKey: .streakFreezeDates) ?? []
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
        try c.encode(streakFreezeTokens,          forKey: .streakFreezeTokens)
        try c.encode(streakFreezeDates,           forKey: .streakFreezeDates)
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
