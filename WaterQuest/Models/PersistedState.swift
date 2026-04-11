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
    var earthDay2026BannerDismissed: Bool
    var earthDay2026Earned: Bool

    // Keep gameState and manualWeather as ignored keys so old persisted JSON decodes without error
    private enum CodingKeys: String, CodingKey {
        case entries, profile, lastWeather, lastWorkout, hasPremiumAccess, premiumUpsellState, gameState, manualWeather
        case earthDay2026BannerDismissed, earthDay2026Earned
    }

    init(
        entries: [HydrationEntry],
        profile: UserProfile,
        lastWeather: WeatherSnapshot?,
        lastWorkout: WorkoutSummary,
        hasPremiumAccess: Bool,
        premiumUpsellState: PremiumUpsellState,
        earthDay2026BannerDismissed: Bool = false,
        earthDay2026Earned: Bool = false
    ) {
        self.entries = entries
        self.profile = profile
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
        self.hasPremiumAccess = hasPremiumAccess
        self.premiumUpsellState = premiumUpsellState
        self.earthDay2026BannerDismissed = earthDay2026BannerDismissed
        self.earthDay2026Earned = earthDay2026Earned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries      = try c.decode([HydrationEntry].self, forKey: .entries)
        profile      = try c.decode(UserProfile.self,       forKey: .profile)
        lastWeather  = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout  = try c.decode(WorkoutSummary.self,    forKey: .lastWorkout)
        hasPremiumAccess = try c.decodeIfPresent(Bool.self, forKey: .hasPremiumAccess) ?? false
        premiumUpsellState = try c.decodeIfPresent(PremiumUpsellState.self, forKey: .premiumUpsellState) ?? .default
        earthDay2026BannerDismissed = try c.decodeIfPresent(Bool.self, forKey: .earthDay2026BannerDismissed) ?? false
        earthDay2026Earned          = try c.decodeIfPresent(Bool.self, forKey: .earthDay2026Earned) ?? false
        // .gameState and .manualWeather silently ignored if present in old JSON
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entries,     forKey: .entries)
        try c.encode(profile,     forKey: .profile)
        try c.encode(lastWeather, forKey: .lastWeather)
        try c.encode(lastWorkout, forKey: .lastWorkout)
        try c.encode(hasPremiumAccess, forKey: .hasPremiumAccess)
        try c.encode(premiumUpsellState, forKey: .premiumUpsellState)
        try c.encode(earthDay2026BannerDismissed, forKey: .earthDay2026BannerDismissed)
        try c.encode(earthDay2026Earned,          forKey: .earthDay2026Earned)
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
