import Foundation

/// "Match Day" — a limited-time football-summer hydration challenge.
///
/// The user's hydration day is framed as a football match: first half until
/// early afternoon, second half until evening, extra time if the goal isn't
/// met by then, and full time once it is. Each logged drink is a goal; winning
/// the day means hitting the daily hydration goal. Win enough match days and
/// the Golden Bottle badge is earned.
///
/// Copy is deliberately generic football language. It must never reference
/// FIFA, "World Cup", tournament years, host nations, or official slogans —
/// those are protected marks (App Review guideline 5.2.1). Keep it that way.
enum MatchDay {
    /// The season window. Internally aligned with the football summer of
    /// 2026 but expressed only as plain dates — nothing user-facing mentions
    /// the tournament.
    static let seasonStart = DateComponents(year: 2026, month: 7, day: 3)
    static let seasonEnd = DateComponents(year: 2026, month: 8, day: 2)

    /// Number of match-day wins that earn the Golden Bottle badge.
    static let winsForGoldenBottle = 12

    enum Phase: Equatable {
        case firstHalf
        case secondHalf
        case extraTime
        case fullTime
    }

    static func isActive(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard
            let start = calendar.date(from: seasonStart),
            let endDay = calendar.date(from: seasonEnd),
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDay))
        else { return false }
        return date >= calendar.startOfDay(for: start) && date < end
    }

    /// First half runs to 13:00, second half to 20:00, then extra time.
    /// Hitting the goal at any point blows the full-time whistle.
    static func phase(progress: Double, now: Date = Date(), calendar: Calendar = .current) -> Phase {
        if progress >= 1.0 { return .fullTime }
        let hour = calendar.component(.hour, from: now)
        if hour < 13 { return .firstHalf }
        if hour < 20 { return .secondHalf }
        return .extraTime
    }

    /// Deterministic commentary line for the current match state.
    /// `score` is the number of drinks logged today ("goals").
    static func commentary(phase: Phase, progress: Double, score: Int) -> String {
        let pct = Int((progress * 100).rounded())
        switch phase {
        case .firstHalf:
            if score == 0 {
                return "It's match day. Kickoff — first sip starts the game."
            }
            return "First half: \(score) goal\(score == 1 ? "" : "s") in. Keep the tempo."
        case .secondHalf:
            if progress >= 0.5 {
                return "Second half, \(pct)% — you're controlling this match."
            }
            return "Half-time team talk: \(pct)% there. Hydrate like a pro at the break."
        case .extraTime:
            return "Extra time — \(100 - pct)% to go before the final whistle."
        case .fullTime:
            return "Full time. Goal reached — that's a win for today's match."
        }
    }

    /// Short scoreboard line, e.g. "3 goals · 64%".
    static func scoreline(score: Int, progress: Double) -> String {
        let pct = Int((progress * 100).rounded())
        return "\(score) goal\(score == 1 ? "" : "s") · \(pct)%"
    }

    /// Season progress line for the wins tally.
    static func winsSummary(wins: Int) -> String {
        if wins >= winsForGoldenBottle {
            return "Golden Bottle earned — \(wins) match days won"
        }
        return "\(wins) match day\(wins == 1 ? "" : "s") won · Golden Bottle at \(winsForGoldenBottle)"
    }
}
