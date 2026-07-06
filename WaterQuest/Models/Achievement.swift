import Foundation

/// Badge categories shown as distinct sections in the Trophy Room.
enum AchievementCategory: String, CaseIterable, Codable {
    case consistency
    case volume
    case explorer
    case dedication
    case season
    case secret

    var displayName: String {
        switch self {
        case .consistency: return "Consistency"
        case .volume:      return "Volume"
        case .explorer:    return "Explorer"
        case .dedication:  return "Dedication"
        case .season:      return "Season"
        case .secret:      return "Secret"
        }
    }
}

/// A single earnable badge. The catalog is code-defined and append-only:
/// `id` is persisted in `PersistedState.unlockedAchievements`, so ids must
/// never change or be reused once shipped.
struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    /// How to earn it — shown under the title. For secret badges this stays
    /// hidden until unlocked.
    let detail: String
    let symbol: String
    let category: AchievementCategory

    var isSecret: Bool { category == .secret }
}

enum AchievementCatalog {
    /// Display order within the Trophy Room follows this order.
    static let all: [Achievement] = [
        // MARK: Consistency — streak milestones
        Achievement(id: "streak.3",   title: "Three in a Row",   detail: "Keep a 3-day goal streak", symbol: "flame", category: .consistency),
        Achievement(id: "streak.7",   title: "Week of Waves",    detail: "Keep a 7-day goal streak", symbol: "flame.fill", category: .consistency),
        Achievement(id: "streak.14",  title: "Fortnight Flow",   detail: "Keep a 14-day goal streak", symbol: "water.waves", category: .consistency),
        Achievement(id: "streak.30",  title: "Monthly Monsoon",  detail: "Keep a 30-day goal streak", symbol: "cloud.rain.fill", category: .consistency),
        Achievement(id: "streak.60",  title: "Season of Sips",   detail: "Keep a 60-day goal streak", symbol: "hurricane", category: .consistency),
        Achievement(id: "streak.100", title: "Century Stream",   detail: "Keep a 100-day goal streak", symbol: "crown.fill", category: .consistency),
        Achievement(id: "week.perfect", title: "Perfect Week",   detail: "Hit your goal every day of a calendar week", symbol: "calendar.badge.checkmark", category: .consistency),

        // MARK: Volume — lifetime effective litres
        Achievement(id: "volume.10",  title: "First Ten Litres", detail: "Log 10 litres overall", symbol: "drop", category: .volume),
        Achievement(id: "volume.50",  title: "Fifty Up",         detail: "Log 50 litres overall", symbol: "drop.fill", category: .volume),
        Achievement(id: "volume.100", title: "Hundred Club",     detail: "Log 100 litres overall", symbol: "drop.circle.fill", category: .volume),
        Achievement(id: "volume.250", title: "Reservoir",        detail: "Log 250 litres overall", symbol: "humidity.fill", category: .volume),
        Achievement(id: "volume.500", title: "Half Tonne Hero",  detail: "Log 500 litres overall", symbol: "trophy.fill", category: .volume),
        Achievement(id: "day.overflow", title: "Overflow",       detail: "Reach 150% of your goal in one day", symbol: "waveform.path.ecg", category: .volume),

        // MARK: Explorer — beverage variety
        Achievement(id: "explorer.first", title: "Beyond Water", detail: "Log your first non-water drink", symbol: "cup.and.saucer", category: .explorer),
        Achievement(id: "explorer.3",  title: "Taste Tester",    detail: "Log 3 different drink types", symbol: "cup.and.saucer.fill", category: .explorer),
        Achievement(id: "explorer.8",  title: "Menu Explorer",   detail: "Log 8 different drink types", symbol: "list.bullet.clipboard", category: .explorer),
        Achievement(id: "explorer.15", title: "Connoisseur",     detail: "Log 15 different drink types", symbol: "sparkles", category: .explorer),

        // MARK: Dedication — lifetime goal days & habits
        Achievement(id: "goal.7",   title: "Seven Wins",         detail: "Hit your daily goal 7 times", symbol: "checkmark.seal", category: .dedication),
        Achievement(id: "goal.30",  title: "Thirty Wins",        detail: "Hit your daily goal 30 times", symbol: "checkmark.seal.fill", category: .dedication),
        Achievement(id: "goal.100", title: "Hundred Wins",       detail: "Hit your daily goal 100 times", symbol: "rosette", category: .dedication),
        Achievement(id: "earlybird", title: "Early Bird",        detail: "Log a drink before 7 am", symbol: "sunrise.fill", category: .dedication),
        Achievement(id: "nightowl",  title: "Night Owl",         detail: "Log a drink after 10 pm", symbol: "moon.stars.fill", category: .dedication),
        Achievement(id: "weekend.perfect", title: "Weekend Warrior", detail: "Hit your goal on both days of a weekend", symbol: "figure.run", category: .dedication),
        Achievement(id: "freeze.full", title: "Ice Reserves",    detail: "Bank the maximum 3 streak freezes", symbol: "snowflake", category: .dedication),

        // MARK: Season — Match Day
        Achievement(id: "matchday.first",  title: "First Whistle", detail: "Win your first match day", symbol: "soccerball", category: .season),
        Achievement(id: "matchday.golden", title: "Golden Bottle", detail: "Win 12 match days in a season", symbol: "trophy.circle.fill", category: .season),

        // MARK: Secret — hidden until earned
        Achievement(id: "secret.midnight", title: "Midnight Sip",   detail: "Log a drink in the midnight hour", symbol: "moon.zzz.fill", category: .secret),
        Achievement(id: "secret.siri",     title: "Voice Activated", detail: "Log a drink with Siri", symbol: "waveform", category: .secret),
        Achievement(id: "secret.widget",   title: "Speed Sipper",   detail: "Log a drink from a widget", symbol: "bolt.fill", category: .secret),
        Achievement(id: "secret.undo",     title: "Second Thoughts", detail: "Remove 5 logged drinks", symbol: "arrow.uturn.backward.circle.fill", category: .secret),
        Achievement(id: "secret.purist",   title: "Unassisted",     detail: "Keep a 30-day streak without using a freeze", symbol: "hands.clap.fill", category: .secret),
    ]

    static let byID: [String: Achievement] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )
}
