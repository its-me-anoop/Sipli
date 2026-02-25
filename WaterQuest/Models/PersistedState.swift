import Foundation

struct PersistedState: Codable {
    var entries: [HydrationEntry]
    var profile: UserProfile
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary

    // Keep gameState and manualWeather as ignored keys so old persisted JSON decodes without error
    private enum CodingKeys: String, CodingKey {
        case entries, profile, lastWeather, lastWorkout, gameState, manualWeather
    }

    init(entries: [HydrationEntry], profile: UserProfile, lastWeather: WeatherSnapshot?, lastWorkout: WorkoutSummary) {
        self.entries = entries
        self.profile = profile
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries      = try c.decode([HydrationEntry].self, forKey: .entries)
        profile      = try c.decode(UserProfile.self,       forKey: .profile)
        lastWeather  = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout  = try c.decode(WorkoutSummary.self,    forKey: .lastWorkout)
        // .gameState and .manualWeather silently ignored if present in old JSON
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entries,     forKey: .entries)
        try c.encode(profile,     forKey: .profile)
        try c.encode(lastWeather, forKey: .lastWeather)
        try c.encode(lastWorkout, forKey: .lastWorkout)
    }

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        lastWeather: nil,
        lastWorkout: .empty
    )
}
