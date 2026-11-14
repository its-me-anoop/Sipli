import Foundation

/// Pure logic behind the iOS 27.3 Siri AI tools (see `SiriAI/`).
///
/// Like `HydrationIntentCore`, everything here takes a `PersistedState`
/// value and an injected `now`, so it is unit-testable without disk, iCloud
/// or the `@MainActor` store. The tool intents only load state, call in
/// here, save and fire side effects. This file has no dependency on the
/// iOS 27.3 SDK and compiles with every toolchain the app supports.
enum HydrationAssistantCore {

    enum Failure: Error, Equatable {
        case nothingToLog
        case tooManyDrinks
        case tooFarInPast
        case entryNotFound
        case nothingToChange

        /// What Siri says when a tool can't do what was asked.
        var message: String {
            switch self {
            case .nothingToLog:
                return "I didn't catch any drinks to log."
            case .tooManyDrinks:
                return "That's a lot of drinks at once. Try logging up to \(HydrationAssistantCore.maxDrinksPerRequest) at a time."
            case .tooFarInPast:
                return "Sipli can only add drinks from the last 7 days."
            case .entryNotFound:
                return "I couldn't find that drink in Sipli. It may have been deleted."
            case .nothingToChange:
                return "Tell me the new amount or the drink to change it to."
            }
        }
    }

    /// Most drinks one request can log, so a misheard request can't flood the log.
    static let maxDrinksPerRequest = 12
    /// How far back a drink can be added, matching the diary's editable window.
    static let maxBackdate: TimeInterval = 7 * 86_400
    /// Smallest pour a tool accepts; the in-app slider also goes down to 10 mL.
    static let minDrinkML: Double = 10
    /// Days of history indexed in Spotlight for Siri to find.
    static let indexedDays = 30

    // MARK: - Logging several drinks

    /// One drink in a natural-language request such as "two coffees and a
    /// water this morning". `amountML == nil` means "my usual size".
    struct DrinkRequest: Equatable {
        var fluid: FluidType
        var amountML: Double?
        var loggedAt: Date?

        init(fluid: FluidType, amountML: Double? = nil, loggedAt: Date? = nil) {
            self.fluid = fluid
            self.amountML = amountML
            self.loggedAt = loggedAt
        }
    }

    struct LogOutcome {
        var entries: [HydrationEntry]
        var dialog: String
        var compactDialog: String
    }

    /// Validates the whole request first, then appends every drink, so a
    /// bad item never leaves a half-logged batch behind.
    @discardableResult
    static func logDrinks(
        _ requests: [DrinkRequest],
        into state: inout PersistedState,
        now: Date
    ) throws -> LogOutcome {
        guard !requests.isEmpty else { throw Failure.nothingToLog }
        guard requests.count <= maxDrinksPerRequest else { throw Failure.tooManyDrinks }

        let earliest = now.addingTimeInterval(-maxBackdate)
        // Resolve sizes against the log as it was before this request, so
        // "a 500 ml tea and another tea" uses the usual tea size, not 500.
        let snapshot = state
        let entries: [HydrationEntry] = try requests.map { request in
            let date = min(request.loggedAt ?? now, now)
            guard date >= earliest else { throw Failure.tooFarInPast }
            let raw = request.amountML ?? HydrationIntentCore.usualAmountML(for: request.fluid, in: snapshot)
            let ml = min(max(raw, minDrinkML), HydrationIntentCore.maxML)
            return HydrationEntry(date: date, volumeML: ml, source: .manual, fluidType: request.fluid)
        }

        state.entries.append(contentsOf: entries)
        state.counters.siriLogCount += entries.count

        let progress = HydrationIntentCore.progress(state: state, now: now)
        let followUp = progress.remainingML >= 1
            ? "\(volume(progress.remainingML.rounded(.up), state)) to go."
            : "Today's goal is done."
        let dialog = "Logged \(describe(entries, state)). You're at \(progress.percent)% of today's goal — \(followUp)"
        let compact: String
        if entries.count == 1, let only = entries.first {
            compact = "\(volume(only.volumeML, state)) \(HydrationIntentCore.label(for: only.fluidType)) logged — \(progress.percent)% of goal"
        } else {
            compact = "\(entries.count) drinks logged — \(progress.percent)% of goal"
        }
        return LogOutcome(entries: entries, dialog: dialog, compactDialog: compact)
    }

    // MARK: - Finding drinks

    /// Entries from the start of `start`'s day through the end of `end`'s
    /// day, oldest first. A reversed range is accepted.
    static func entries(
        in state: PersistedState,
        from start: Date,
        through end: Date,
        fluid: FluidType? = nil,
        calendar: Calendar = .current
    ) -> [HydrationEntry] {
        let (lower, upper) = dayBounds(start, end, calendar: calendar)
        return state.entries
            .filter { $0.date >= lower && $0.date < upper }
            .filter { fluid == nil || $0.fluidType == fluid }
            .sorted { $0.date < $1.date }
    }

    static func historySummary(
        _ entries: [HydrationEntry],
        from start: Date,
        through end: Date,
        fluid: FluidType?,
        state: PersistedState,
        now: Date,
        calendar: Calendar = .current
    ) -> (dialog: String, compactDialog: String) {
        let period = periodPhrase(start, end, now: now, calendar: calendar)
        guard !entries.isEmpty else {
            let what = fluid.map { HydrationIntentCore.label(for: $0) } ?? "drinks"
            let dialog = "You didn't log any \(what) \(period)."
            return (dialog, "Nothing logged")
        }
        let count = entries.count
        let total = entries.reduce(0) { $0 + $1.volumeML }
        let hydration = entries.reduce(0) { $0 + $1.effectiveML }
        let noun = fluid.map { count == 1 ? HydrationIntentCore.label(for: $0) : plural(HydrationIntentCore.label(for: $0)) }
            ?? (count == 1 ? "drink" : "drinks")
        var dialog = "You logged \(count) \(noun) \(period), \(volume(total, state)) in total"
        if (total - hydration).rounded() >= 1 {
            dialog += " (\(volume(hydration, state)) of hydration)"
        }
        dialog += "."
        let compact = "\(count) \(count == 1 ? "drink" : "drinks") · \(volume(total, state))"
        return (dialog, compact)
    }

    // MARK: - Editing and deleting

    @discardableResult
    static func updateEntry(
        id: UUID,
        amountML: Double?,
        fluid: FluidType?,
        in state: inout PersistedState,
        now: Date
    ) throws -> (entry: HydrationEntry, dialog: String, compactDialog: String) {
        guard amountML != nil || fluid != nil else { throw Failure.nothingToChange }
        guard let index = state.entries.firstIndex(where: { $0.id == id }) else { throw Failure.entryNotFound }
        if let amountML {
            state.entries[index].volumeML = min(max(amountML, minDrinkML), HydrationIntentCore.maxML)
        }
        if let fluid {
            state.entries[index].fluidType = fluid
        }
        let entry = state.entries[index]
        let pct = HydrationIntentCore.progress(state: state, now: now).percent
        let what = "\(volume(entry.volumeML, state)) of \(HydrationIntentCore.label(for: entry.fluidType))"
        return (
            entry,
            "Updated that drink to \(what). You're at \(pct)% of today's goal.",
            "Updated to \(volume(entry.volumeML, state)) \(HydrationIntentCore.label(for: entry.fluidType)) — \(pct)%"
        )
    }

    @discardableResult
    static func deleteEntry(
        id: UUID,
        from state: inout PersistedState,
        now: Date
    ) throws -> (removed: HydrationEntry, dialog: String, compactDialog: String) {
        guard let index = state.entries.firstIndex(where: { $0.id == id }) else { throw Failure.entryNotFound }
        let removed = state.entries.remove(at: index)
        // Same bookkeeping as an in-app delete: the removal must win when a
        // stale copy in another process merges, and it feeds "Second Thoughts".
        state.recordRemoval(of: [removed.id], at: now)
        state.counters.undoCount += 1
        let pct = HydrationIntentCore.progress(state: state, now: now).percent
        let what = "\(volume(removed.volumeML, state)) of \(HydrationIntentCore.label(for: removed.fluidType))"
        return (
            removed,
            "Deleted \(what). You're now at \(pct)% of today's goal.",
            "Deleted \(volume(removed.volumeML, state)) \(HydrationIntentCore.label(for: removed.fluidType)) — \(pct)%"
        )
    }

    // MARK: - Daily goal

    /// Same range as the custom goal slider in Settings, in the user's units.
    static func goalRangeML(for unit: UnitSystem) -> ClosedRange<Double> {
        switch unit {
        case .metric: return 1500...4500
        case .imperial: return unit.ml(from: 50)...unit.ml(from: 150)
        }
    }

    /// Sets a custom daily goal, or with `nil` returns to the automatic goal
    /// calculated from weight and activity.
    @discardableResult
    static func setDailyGoal(ml: Double?, in state: inout PersistedState) -> (goalML: Double, dialog: String, compactDialog: String) {
        guard let ml else {
            state.profile.customGoalML = nil
            let goal = HydrationIntentCore.goalML(for: state)
            let shown = volume(goal, state)
            return (goal, "Your goal is back to automatic: \(shown) a day, based on your weight and activity.", "Automatic goal: \(shown)")
        }
        let range = goalRangeML(for: state.profile.unitSystem)
        let clamped = min(max(ml, range.lowerBound), range.upperBound)
        state.profile.customGoalML = clamped
        let shown = volume(clamped, state)
        var dialog = "Your daily goal is now \(shown)"
        if ml > range.upperBound {
            dialog += ", the highest Sipli allows"
        } else if ml < range.lowerBound {
            dialog += ", the lowest Sipli allows"
        }
        dialog += "."
        return (clamped, dialog, "Goal: \(shown)")
    }

    // MARK: - Entity snapshot

    /// Everything `DrinkEntryEntity` shows, computed from a stored entry.
    struct EntrySnapshot: Equatable {
        var id: UUID
        var fluid: FluidType
        var title: String
        var amountML: Int
        var amountText: String
        var hydrationML: Int
        var loggedAt: Date
        var note: String?
    }

    static func snapshot(of entry: HydrationEntry, unit: UnitSystem) -> EntrySnapshot {
        EntrySnapshot(
            id: entry.id,
            fluid: entry.fluidType,
            title: entry.fluidType.displayName,
            amountML: Int(entry.volumeML.rounded()),
            amountText: HydrationIntentCore.volume(entry.volumeML, unit: unit),
            hydrationML: Int(entry.effectiveML.rounded()),
            loggedAt: entry.date,
            note: entry.note
        )
    }

    /// Plain text another app can receive, e.g. when Siri sends today's log
    /// to someone in Messages.
    static func shareText(for entries: [HydrationEntry], unit: UnitSystem) -> String {
        let lines = entries.sorted { $0.date < $1.date }.map { entry in
            let time = entry.date.formatted(date: .omitted, time: .shortened)
            return "• \(time) — \(HydrationIntentCore.volume(entry.volumeML, unit: unit)) \(HydrationIntentCore.label(for: entry.fluidType))"
        }
        let total = entries.reduce(0) { $0 + $1.volumeML }
        return (["My Sipli log"] + lines + ["Total: \(HydrationIntentCore.volume(total, unit: unit))"])
            .joined(separator: "\n")
    }

    /// The entries kept in Spotlight for Siri: the last `indexedDays` days.
    static func indexableEntries(in state: PersistedState, now: Date, calendar: Calendar = .current) -> [HydrationEntry] {
        let start = calendar.date(byAdding: .day, value: -(indexedDays - 1), to: calendar.startOfDay(for: now)) ?? now
        return state.entries.filter { $0.date >= start }
    }

    // MARK: - Helpers

    private static func volume(_ ml: Double, _ state: PersistedState) -> String {
        HydrationIntentCore.volume(ml, state)
    }

    /// "2 coffees (480 mL) and 250 mL of water", keeping first-mention order.
    private static func describe(_ entries: [HydrationEntry], _ state: PersistedState) -> String {
        var order: [FluidType] = []
        var groups: [FluidType: [HydrationEntry]] = [:]
        for entry in entries {
            if groups[entry.fluidType] == nil { order.append(entry.fluidType) }
            groups[entry.fluidType, default: []].append(entry)
        }
        let parts = order.map { fluid -> String in
            let group = groups[fluid] ?? []
            let total = group.reduce(0) { $0 + $1.volumeML }
            let label = HydrationIntentCore.label(for: fluid)
            return group.count == 1
                ? "\(volume(total, state)) of \(label)"
                : "\(group.count) \(plural(label)) (\(volume(total, state)))"
        }
        return joinedList(parts)
    }

    private static func joinedList(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }

    private static func plural(_ label: String) -> String {
        label.hasSuffix("s") ? label : label + "s"
    }

    private static func dayBounds(_ a: Date, _ b: Date, calendar: Calendar) -> (Date, Date) {
        let lower = calendar.startOfDay(for: min(a, b))
        let lastDay = calendar.startOfDay(for: max(a, b))
        let upper = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return (lower, upper)
    }

    private static func periodPhrase(_ a: Date, _ b: Date, now: Date, calendar: Calendar) -> String {
        let first = min(a, b), last = max(a, b)
        func dayPhrase(_ date: Date) -> String {
            if calendar.isDate(date, inSameDayAs: now) { return "today" }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
            return "on " + date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        if calendar.isDate(first, inSameDayAs: last) {
            return dayPhrase(first)
        }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "between \(first.formatted(style)) and \(last.formatted(style))"
    }
}
