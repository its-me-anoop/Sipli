import Foundation

/// Length of a free trial, independent of StoreKit so the paywall copy and
/// timeline can be tested without a live store.
struct TrialLength: Equatable, Sendable {
    enum Unit: Equatable, Sendable {
        case day, week, month, year
    }

    let value: Int
    let unit: Unit

    /// "month", "7 days", "2 months" — reads after "free".
    var phrase: String {
        let noun: String
        switch unit {
        case .day: noun = "day"
        case .week: noun = "week"
        case .month: noun = "month"
        case .year: noun = "year"
        }
        return value == 1 ? noun : "\(value) \(noun)s"
    }

    var callToAction: String { "Start my free \(phrase)" }

    fileprivate var calendarComponent: Calendar.Component {
        switch unit {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Whether Sipli can deliver the trial-ending reminder. Mirrors the
/// notification authorisation states that matter here.
enum TrialReminderAvailability: Equatable, Sendable {
    case authorized
    case provisional
    case notDetermined
    case denied

    /// `notDetermined` counts: provisional permission can be granted
    /// quietly at purchase time without a prompt.
    var canRemind: Bool { self != .denied }
}

/// The "what happens next" story shown on the paywall for a free trial:
/// everything unlocks today, a reminder arrives before the trial ends,
/// then the plan begins. Only promises a reminder Sipli can deliver.
struct TrialTimeline: Equatable {
    struct Milestone: Equatable, Identifiable {
        enum Kind: Equatable {
            case unlock, reminder, billing

            var symbol: String {
                switch self {
                case .unlock: return "lock.open.fill"
                case .reminder: return "bell.fill"
                case .billing: return "drop.fill"
                }
            }
        }

        let kind: Kind
        let date: Date
        let title: String
        let detail: String

        var id: Kind { kind }
    }

    let trial: TrialLength
    let trialEnd: Date
    let reminderDate: Date?
    let milestones: [Milestone]

    static func make(
        trial: TrialLength,
        startingAt start: Date,
        renewalPrice: String,
        canRemind: Bool,
        calendar: Calendar = .current
    ) -> TrialTimeline {
        let end = calendar.date(byAdding: trial.calendarComponent, value: trial.value, to: start) ?? start
        let trialDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let leadDays = reminderLeadDays(forTrialDays: trialDays)

        let reminder: Date? = {
            guard canRemind, let leadDays else { return nil }
            return calendar.date(byAdding: .day, value: -leadDays, to: end)
        }()

        var milestones = [
            Milestone(
                kind: .unlock,
                date: start,
                title: "Today: everything unlocks",
                detail: "Beverage types, AI insights, HealthKit sync, and goals that adapt to your weather and workouts."
            )
        ]

        if let reminder, let leadDays {
            let lead = leadDays == 1 ? "1 day" : "\(leadDays) days"
            milestones.append(Milestone(
                kind: .reminder,
                date: reminder,
                title: "We'll remind you",
                detail: "A notification \(lead) before your trial ends, so nothing is a surprise."
            ))
        }

        let cancelNote = reminder == nil
            ? " Cancel anytime before then in Settings."
            : " Cancel anytime before then."
        milestones.append(Milestone(
            kind: .billing,
            date: end,
            title: "Your plan begins",
            detail: "\(renewalPrice) starts after your free \(trial.phrase).\(cancelNote)"
        ))

        return TrialTimeline(
            trial: trial,
            trialEnd: end,
            reminderDate: reminder,
            milestones: milestones
        )
    }

    /// Two days' notice for trials of four days or more, one day for
    /// shorter ones, none when the trial is a single day.
    private static func reminderLeadDays(forTrialDays days: Int) -> Int? {
        switch days {
        case ..<2: return nil
        case 2...3: return 1
        default: return 2
        }
    }
}
