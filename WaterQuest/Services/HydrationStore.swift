import Foundation

@MainActor
final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var gameState: GameState
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary
    @Published var activeAchievement: Achievement?

    private let persistence = PersistenceService.shared
    private var pendingAchievements: [Achievement] = []

    /// Set by the app after both objects are created so the store can notify
    /// the scheduler when new intake is logged.
    weak var notificationScheduler: NotificationScheduler?

    init() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        self.entries = state.entries
        self.profile = state.profile
        self.gameState = state.gameState
        self.lastWeather = state.lastWeather
        self.lastWorkout = state.lastWorkout
        self.activeAchievement = nil
        GamificationEngine.ensureAchievements(state: &self.gameState)
        GamificationEngine.refreshDailyQuests(state: &self.gameState, goalML: dailyGoal.totalML)
    }

    var dailyGoal: GoalBreakdown {
        GoalCalculator.dailyGoal(profile: profile, weather: activeWeather, workout: lastWorkout)
    }

    var activeWeather: WeatherSnapshot? {
        profile.prefersWeatherGoal ? lastWeather : nil
    }

    var todayEntries: [HydrationEntry] {
        entries.filter { $0.date.isSameDay(as: Date()) }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.volumeML }
    }

    func addIntake(amount: Double, unitSystem: UnitSystem? = nil, source: HydrationSource = .manual) {
        let previouslyUnlocked = Set(gameState.achievements.filter { $0.isUnlocked }.map { $0.id })
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source)
        entries.append(entry)
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.applyIntake(state: &gameState, entry: entry, todayTotalML: todayTotalML, goalML: dailyGoal.totalML, allEntries: entries)
        notificationScheduler?.onIntakeLogged(entry: entry)
        persist()
        let newlyUnlocked = gameState.achievements.filter { $0.isUnlocked && !previouslyUnlocked.contains($0.id) }
        enqueueAchievements(newlyUnlocked)
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func updateProfile(_ update: (inout UserProfile) -> Void) {
        var copy = profile
        update(&copy)
        profile = copy
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist()
    }

    func updateWeather(_ snapshot: WeatherSnapshot) {
        lastWeather = snapshot
        persist()
    }

    func updateWorkout(_ summary: WorkoutSummary) {
        lastWorkout = summary
        persist()
    }

    func refreshQuests() {
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist()
    }

    func resetToday() {
        entries.removeAll { $0.date.isSameDay(as: Date()) }
        persist()
    }

    func dismissActiveAchievement() {
        if pendingAchievements.isEmpty {
            activeAchievement = nil
        } else {
            activeAchievement = pendingAchievements.removeFirst()
        }
    }

    private func persist() {
        let state = PersistedState(
            entries: entries,
            profile: profile,
            gameState: gameState,
            lastWeather: lastWeather,
            lastWorkout: lastWorkout
        )
        persistence.save(state)
    }

    private func enqueueAchievements(_ achievements: [Achievement]) {
        guard !achievements.isEmpty else { return }
        pendingAchievements.append(contentsOf: achievements)
        if activeAchievement == nil {
            activeAchievement = pendingAchievements.removeFirst()
        }
    }
}

struct PersistedState: Codable {
    var entries: [HydrationEntry]
    var profile: UserProfile
    var gameState: GameState
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary

    // manualWeather removed; kept as ignored key so old persisted JSON decodes without error
    private enum CodingKeys: String, CodingKey {
        case entries, profile, gameState, lastWeather, lastWorkout, manualWeather
    }

    init(entries: [HydrationEntry], profile: UserProfile, gameState: GameState, lastWeather: WeatherSnapshot?, lastWorkout: WorkoutSummary) {
        self.entries = entries
        self.profile = profile
        self.gameState = gameState
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries      = try c.decode([HydrationEntry].self, forKey: .entries)
        profile      = try c.decode(UserProfile.self,       forKey: .profile)
        gameState    = try c.decode(GameState.self,         forKey: .gameState)
        lastWeather  = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout  = try c.decode(WorkoutSummary.self,    forKey: .lastWorkout)
        // .manualWeather silently ignored if present in old JSON
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entries,     forKey: .entries)
        try c.encode(profile,     forKey: .profile)
        try c.encode(gameState,   forKey: .gameState)
        try c.encode(lastWeather, forKey: .lastWeather)
        try c.encode(lastWorkout, forKey: .lastWorkout)
    }

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        gameState: .default,
        lastWeather: nil,
        lastWorkout: .empty
    )
}
