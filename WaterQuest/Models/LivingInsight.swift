import Foundation

struct LivingInsightSnapshot: Hashable {
    let entries: [HydrationEntry]
    let goalML: Double
    let day: Date
    let unit: String
    let freezeDates: [Date]
    init(entries: [HydrationEntry], goalML: Double, now: Date = Date(), unit: UnitSystem, freezeDates: [Date] = []) {
        self.entries = entries.sorted { $0.id.uuidString < $1.id.uuidString }
        self.goalML = goalML.isFinite ? max(1, goalML) : 1
        day = Calendar.current.startOfDay(for: now)
        self.unit = unit.rawValue
        self.freezeDates = freezeDates
    }
    var today: [HydrationEntry] { entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) } }
    var totalML: Double { today.reduce(0) { $0 + ($1.effectiveML.isFinite ? max(0, $1.effectiveML) : 0) } }
    var progress: Double { min(1, totalML / goalML) }
    var units: UnitSystem { UnitSystem(rawValue: unit) ?? .metric }
    var fact: String {
        "\(Formatters.volumeString(ml: totalML, unit: units)) logged today · \(Formatters.volumeString(ml: goalML, unit: units)) goal"
    }
    var fallback: String {
        if today.isEmpty { return "A fresh page for today. Your log is here whenever you’re ready." }
        if totalML >= goalML { return "Your day is recorded. There’s nothing extra to chase." }
        return "Small check-ins make your day easier to follow."
    }
    var detail: String {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: day) ?? day
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let days = Set(entries.filter { $0.date < end && $0.date >= start }
            .map { Calendar.current.startOfDay(for: $0.date) }).count
        return "\(today.count) check-in\(today.count == 1 ? "" : "s") today · logged on \(days) of the last 7 days"
    }
    var modelContext: String {
        "Purpose: choose a gentle tone for a hydration log. Today has \(today.count) entries. Goal is \(totalML >= goalML ? "already recorded; never encourage more drinking" : "not reached; never prescribe drinking"). Facts are shown separately by the app."
    }
}

enum BottleTone: String, Codable { case calm, warm, practical }
enum BottleMessagePurpose { case returning, logged, insight }
enum BottleCopy {
    static func text(tone: BottleTone, purpose: BottleMessagePurpose, snapshot: LivingInsightSnapshot) -> String {
        switch purpose {
        case .returning:
            switch tone {
            case .calm: return "Good to see you. Your log is here whenever you’re ready."
            case .warm: return "Welcome back. We can pick up from here."
            case .practical: return "Had a drink? You can add it when it suits you."
            }
        case .logged:
            guard snapshot.totalML <= snapshot.goalML else { return "Added to your log." }
            switch tone {
            case .calm: return "Saved. Thanks for checking in."
            case .warm: return "Nice check-in. Your log is up to date."
            case .practical: return "Logged. One less thing to keep track of."
            }
        case .insight:
            guard snapshot.totalML < snapshot.goalML, !snapshot.today.isEmpty else { return snapshot.fallback }
            switch tone {
            case .calm: return snapshot.fallback
            case .warm: return "Every check-in helps tell the story of your day."
            case .practical: return "Your latest changes are included here."
            }
        }
    }
}

/// Local presentation history: acknowledgements reward the check-in, never volume or over-goal intake.
struct BottleFeedbackPolicy: Codable {
    var lastWelcome: Date?
    var snoozedUntil: Date?
    var lastAcknowledgement: Date?
    var fingerprints: [String: Date] = [:]
    static let welcomeCooldown: TimeInterval = 24 * 60 * 60
    static let acknowledgementCooldown: TimeInterval = 90
    static let replayCooldown: TimeInterval = 10 * 60

    func welcomes(snapshot: LivingInsightSnapshot, now: Date, calendar: Calendar = .current) -> Bool {
        guard snapshot.totalML < snapshot.goalML,
              (snoozedUntil ?? .distantPast) <= now,
              now.timeIntervalSince(lastWelcome ?? .distantPast) >= Self.welcomeCooldown,
              let last = snapshot.entries.filter({ $0.source != .healthKit && $0.date <= now }).map(\.date).max(),
              now.timeIntervalSince(last) >= 4 * 60 * 60 else { return false }
        let hour = calendar.component(.hour, from: now)
        return (8..<21).contains(hour)
    }
    mutating func acknowledge(_ entry: HydrationEntry, snapshot: LivingInsightSnapshot, now: Date) -> Bool {
        fingerprints = fingerprints.filter { now.timeIntervalSince($0.value) < Self.replayCooldown }
        let key = "\(Calendar.current.startOfDay(for: entry.date).timeIntervalSince1970)|\(entry.fluidType.rawValue)|\(entry.volumeML.rounded())"
        let seen = fingerprints[key] != nil
        // Record suppressed events too, so undo/re-log doesn't manufacture a new acknowledgement.
        fingerprints[key] = now
        guard entry.source == .manual, entry.volumeML.isFinite, entry.volumeML > 0,
              entry.volumeML <= 750, snapshot.totalML <= snapshot.goalML,
              entry.date <= now, now.timeIntervalSince(entry.date) < 120,
              !seen, now.timeIntervalSince(lastAcknowledgement ?? .distantPast) >= Self.acknowledgementCooldown else { return false }
        return true
    }
}
