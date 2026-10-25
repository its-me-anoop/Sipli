import Foundation

/// Pure, side-effect-free logic shared by the App Intents
/// (`LogWaterIntent`, `GetTodaysHydrationIntent`, `UndoLastIntakeIntent`).
///
/// Everything here operates on a `PersistedState` value with `now` injected,
/// so it is fully unit-testable without touching disk, iCloud, or the
/// `@MainActor` store. The intents are thin wrappers that load the state, call
/// into this core, then save and fire side effects (widget reload, donation).
///
/// Goal is computed from `profile` + `lastWeather` only (no workout) — a quick
/// Siri/Shortcuts log doesn't reach for live HealthKit; the full goal is
/// recomputed in-app when the store reloads.
enum HydrationIntentCore {
    /// Accepted intake range in millilitres, mirroring the in-app intake slider.
    static let minML: Double = 50
    static let maxML: Double = 2000

    static func clampAmount(_ ml: Int) -> Double {
        min(max(Double(ml), minML), maxML)
    }

    static func goalML(for state: PersistedState) -> Double {
        // Mirror HydrationStore.dailyGoal exactly: premium gating decides
        // whether weather/workout adjustments apply, and both use the cached
        // snapshots persisted in state — otherwise Siri speaks a different
        // goal (and streak/remaining numbers) than the app and widget show.
        let profile = state.profile.applyingPremiumAccess(state.hasPremiumAccess)
        return GoalCalculator.dailyGoal(
            profile: profile,
            weather: profile.prefersWeatherGoal ? state.lastWeather : nil,
            workout: profile.prefersHealthKit ? state.lastWorkout : nil
        ).totalML
    }

    static func todayTotalML(_ state: PersistedState, now: Date) -> Double {
        state.entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.effectiveML }
    }

    static func percent(total: Double, goal: Double) -> Int {
        goal > 0 ? Int((total / goal) * 100) : 0
    }

    // MARK: - Intent operations

    @discardableResult
    static func logWater(
        into state: inout PersistedState,
        amountInMilliliters: Int,
        fluidType: FluidType,
        now: Date,
        minimumML: Double = minML
    ) -> (entry: HydrationEntry, dialog: String, compactDialog: String) {
        let clampedML = min(max(Double(amountInMilliliters), minimumML), maxML)
        let entry = HydrationEntry(date: now, volumeML: clampedML, source: .manual, fluidType: fluidType)
        state.entries.append(entry)
        state.counters.siriLogCount += 1 // feeds the "Voice Activated" badge

        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let pct = percent(total: total, goal: goal)
        let amount = volume(clampedML, state)
        let remaining = goal - total
        // Answer the natural follow-up ("how much more?") in the same breath.
        let followUp = remaining >= 1
            ? "\(volume(remaining.rounded(.up), state)) to go."
            : "Today's goal is done."
        let dialog = "Logged \(amount) of \(label(for: fluidType)). You're at \(pct)% of today's goal — \(followUp)"
        let compact = "\(amount) \(label(for: fluidType)) logged — \(pct)% of goal"
        return (entry, dialog, compact)
    }

    static func todaysHydrationDialog(state: PersistedState, now: Date) -> String {
        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let pct = percent(total: total, goal: goal)
        return "You've had \(volume(total, state)) of water today — \(pct)% of your \(volume(goal, state)) goal."
    }

    /// Short variant for visual surfaces (Shortcuts banners, Spotlight) on
    /// iOS 27, where `systemContext.isVoiceOnly` distinguishes spoken from
    /// on-screen delivery. Voice always gets the full-sentence dialog.
    static func todaysHydrationCompact(state: PersistedState, now: Date) -> String {
        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let pct = percent(total: total, goal: goal)
        let unit = unitLabel(state)
        let shown = { (ml: Double) in Int(state.profile.unitSystem.amount(fromML: ml).rounded()) }
        return "\(shown(total)) / \(shown(goal)) \(unit) — \(pct)%"
    }

    @discardableResult
    static func undoLastToday(
        from state: inout PersistedState,
        now: Date
    ) -> (removed: HydrationEntry?, dialog: String, compactDialog: String) {
        let todayIndices = state.entries.indices.filter {
            Calendar.current.isDate(state.entries[$0].date, inSameDayAs: now)
        }
        guard let idx = todayIndices.max(by: { state.entries[$0].date < state.entries[$1].date }) else {
            let nothing = "There's nothing logged today to undo."
            return (nil, nothing, nothing)
        }
        let removed = state.entries.remove(at: idx)
        // Without this, an app process still holding the entry in memory
        // would merge it back on its next reload.
        state.recordRemoval(of: [removed.id], at: now)
        state.counters.undoCount += 1 // feeds the "Second Thoughts" badge
        let pct = percent(total: todayTotalML(state, now: now), goal: goalML(for: state))
        let amount = volume(removed.volumeML, state)
        let dialog = "Removed your last \(label(for: removed.fluidType)) (\(amount)). You're now at \(pct)% of today's goal."
        let compact = "Removed \(amount) \(label(for: removed.fluidType)) — \(pct)% of goal"
        return (removed, dialog, compact)
    }

    // MARK: - v5.0 intents

    /// Freeze-aware goal streak, same math as the app and widget.
    static func currentStreak(state: PersistedState, now: Date) -> Int {
        StreakCalculator.currentStreak(
            entries: state.entries,
            goalML: goalML(for: state),
            freezeDates: state.streakFreezeDates,
            now: now
        )
    }

    static func streakDialog(state: PersistedState, now: Date) -> (dialog: String, compactDialog: String) {
        let streak = currentStreak(state: state, now: now)
        switch streak {
        case 0:
            return (
                "No active streak yet — hit today's goal to start one.",
                "No active streak"
            )
        case 1:
            return (
                "Your streak is 1 day. Hit today's goal to keep it going.",
                "1-day streak"
            )
        default:
            return (
                "Your streak is \(streak) days. Keep it flowing.",
                "\(streak)-day streak"
            )
        }
    }

    static func remainingDialog(state: PersistedState, now: Date) -> (dialog: String, compactDialog: String) {
        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let remaining = goal - total
        // Sub-millilitre remainders round *up*, and anything under 1 mL counts
        // as done — never speak "You need 0 mL more".
        guard remaining >= 1 else {
            return (
                "You've already reached today's goal — anything more is a bonus.",
                "Goal reached ✓"
            )
        }
        let left = volume(remaining.rounded(.up), state)
        let pct = percent(total: total, goal: goal)
        return (
            "You need \(left) more to reach today's goal. You're at \(pct)%.",
            "\(left) to go — \(pct)%"
        )
    }

    /// Logs the same drink as the user's most recent entry ("my usual").
    /// Falls back to 250 mL of water when there's no history.
    @discardableResult
    static func repeatLastDrink(
        into state: inout PersistedState,
        now: Date
    ) -> (entry: HydrationEntry, dialog: String, compactDialog: String) {
        let last = state.entries.max(by: { $0.date < $1.date })
        let amount = last.map { Int($0.volumeML) } ?? 250
        let fluid = last?.fluidType ?? .water
        return logWater(into: &state, amountInMilliliters: amount, fluidType: fluid, now: now)
    }

    /// Logs a named drink ("log a latte") at the size the user usually has
    /// for it: their most recent amount of that drink, else its typical serving.
    @discardableResult
    static func logDrink(
        into state: inout PersistedState,
        fluidType: FluidType,
        now: Date
    ) -> (entry: HydrationEntry, dialog: String, compactDialog: String) {
        let amount = usualAmountML(for: fluidType, in: state)
        // Named drinks may be small (an espresso is 30 mL); the app's own
        // slider goes down to 10 mL, so don't round them up to 50.
        return logWater(
            into: &state,
            amountInMilliliters: Int(amount.rounded()),
            fluidType: fluidType,
            now: now,
            minimumML: 10
        )
    }

    static func usualAmountML(for fluidType: FluidType, in state: PersistedState) -> Double {
        state.entries
            .filter { $0.fluidType == fluidType && $0.source != .healthKit }
            .max(by: { $0.date < $1.date })?
            .volumeML ?? fluidType.defaultServingML
    }

    /// Numbers for the progress card Siri shows under its reply.
    struct Progress: Equatable {
        var totalML: Double
        var goalML: Double
        var unit: UnitSystem

        var fraction: Double { goalML > 0 ? min(totalML / goalML, 1) : 0 }
        var percent: Int { HydrationIntentCore.percent(total: totalML, goal: goalML) }
        var remainingML: Double { max(goalML - totalML, 0) }
    }

    static func progress(state: PersistedState, now: Date) -> Progress {
        Progress(totalML: todayTotalML(state, now: now), goalML: goalML(for: state), unit: state.profile.unitSystem)
    }

    // MARK: - Helpers

    /// Spoken volume in the user's units: "250 mL" or "8 oz".
    static func volume(_ ml: Double, _ state: PersistedState) -> String {
        volume(ml, unit: state.profile.unitSystem)
    }

    static func volume(_ ml: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return "\(Int(ml.rounded())) mL"
        case .imperial:
            let oz = unit.amount(fromML: ml)
            guard oz < 10 else { return "\(Int(oz.rounded())) oz" }
            // One decimal for small pours ("6.1 oz"), but never "2.0 oz".
            let tenths = (oz * 10).rounded() / 10
            return tenths == tenths.rounded()
                ? "\(Int(tenths)) oz"
                : String(format: "%.1f oz", tenths)
        }
    }

    private static func unitLabel(_ state: PersistedState) -> String {
        state.profile.unitSystem == .metric ? "mL" : "oz"
    }

    private static func label(for fluidType: FluidType) -> String {
        fluidType == .water ? "water" : fluidType.displayName.lowercased()
    }
}

// MARK: - Spoken amounts ("350 ml of latte")

/// A quantity, optionally of a named drink, as Siri hears it: "350 ml",
/// "12 oz of coffee", "half a litre". App Shortcut phrases allow one
/// parameter, so amount and drink travel together as one value. Siri can
/// only match values listed ahead of time (`suggestions`); typed text in
/// Shortcuts goes through `parse`, which accepts any amount.
struct DrinkAmount: Equatable, Hashable {
    enum Unit: String { case ml, oz }

    /// The number as said, in `unit`.
    var quantity: Double
    var unit: Unit
    /// nil means plain water ("log 350 ml").
    var fluid: FluidType?

    var milliliters: Double {
        unit == .ml ? quantity : UnitSystem.imperial.ml(from: quantity)
    }

    // MARK: Identity

    /// Stable id: "ml:350:latte" or "oz:12:".
    var id: String {
        "\(unit.rawValue):\(Self.number(quantity)):\(fluid?.rawValue ?? "")"
    }

    init(quantity: Double, unit: Unit, fluid: FluidType? = nil) {
        self.quantity = quantity
        self.unit = unit
        self.fluid = fluid == .water ? nil : fluid
    }

    init?(id: String) {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let unit = Unit(rawValue: parts[0]),
              let quantity = Double(parts[1]), quantity > 0
        else { return nil }
        let fluid = parts[2].isEmpty ? nil : FluidType(rawValue: parts[2])
        if !parts[2].isEmpty && fluid == nil { return nil }
        self.init(quantity: quantity, unit: unit, fluid: fluid)
    }

    // MARK: Display and speech

    var amountText: String {
        "\(Self.number(quantity)) \(unit.rawValue)"
    }

    var drinkName: String {
        fluid.map { $0.displayName.lowercased() } ?? "water"
    }

    var title: String {
        fluid == nil ? amountText : "\(amountText) of \(drinkName)"
    }

    /// Other ways people say the same thing, used by Siri to match speech.
    var synonyms: [String] {
        let n = Self.number(quantity)
        var amounts: [String]
        switch unit {
        case .ml:
            amounts = ["\(n) milliliters", "\(n) millilitres", "\(n) mls"]
            switch quantity {
            case 500: amounts += ["half a litre", "half a liter", "0.5 litres"]
            case 1000: amounts += ["a litre", "a liter", "1 litre", "1 liter", "one litre"]
            case 1500: amounts += ["1.5 litres", "1.5 liters", "one and a half litres"]
            case 2000: amounts += ["2 litres", "2 liters", "two litres"]
            default: break
            }
        case .oz:
            amounts = ["\(n) ounces", "\(n) fluid ounces", "\(n) fl oz"]
        }
        if fluid == nil {
            // "350 ml" and "350 ml of water" are the same request.
            return amounts + ([amountText] + amounts).map { "\($0) of water" }
        }
        let drink = drinkName
        return amounts.map { "\($0) of \(drink)" }
            + ([amountText] + amounts).map { "\($0) \(drink)" }
            + ["a \(amountText) \(drink)"]
    }

    // MARK: Parsing

    /// Reads typed text such as "350ml latte", "12 oz of coffee",
    /// "half a litre" or "350". A bare number uses `defaultUnit`.
    static func parse(_ text: String, defaultUnit: UnitSystem) -> DrinkAmount? {
        var s = " " + text.lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "-", with: " ") + " "
        for (from, to) in unitAliases {
            s = s.replacingOccurrences(of: from, with: to)
        }

        var quantity: Double?
        var unit: Unit?
        if s.contains(" half a l ") || s.contains(" half l ") {
            quantity = 500; unit = .ml
        } else if let match = s.firstMatch(of: #/(\d+(?:\.\d+)?)\s*(ml|cl|l|oz|cups?)?(?=\W)/#) {
            let value = Double(match.1) ?? 0
            switch match.2.map(String.init) {
            case "ml": quantity = value; unit = .ml
            case "cl": quantity = value * 10; unit = .ml
            case "l": quantity = value * 1000; unit = .ml
            case "oz": quantity = value; unit = .oz
            case "cup", "cups": quantity = value * 8; unit = .oz
            default:
                quantity = value
                unit = defaultUnit == .metric ? .ml : .oz
            }
        } else if s.contains(" a l ") || s.contains(" one l ") {
            quantity = 1000; unit = .ml
        }
        guard let quantity, let unit, quantity > 0 else { return nil }
        return DrinkAmount(quantity: quantity, unit: unit, fluid: fluid(in: s))
    }

    /// Longest drink name found in the text, so "green tea" beats "tea".
    static func fluid(in text: String) -> FluidType? {
        let padded = " " + text.lowercased() + " "
        return drinkNames
            .first { padded.contains(" \($0.name) ") }?
            .fluid
    }

    private static let unitAliases: [(String, String)] = [
        ("fluid ounces", "oz"), ("fluid ounce", "oz"), ("fl. oz", "oz"), ("fl oz", "oz"),
        ("ounces", "oz"), ("ounce", "oz"),
        ("millilitres", "ml"), ("milliliters", "ml"), ("millilitre", "ml"), ("milliliter", "ml"), ("mls", "ml"),
        ("centilitres", "cl"), ("centiliters", "cl"),
        ("litres", "l"), ("liters", "l"), ("litre", "l"), ("liter", "l"),
    ]

    private static let drinkNames: [(name: String, fluid: FluidType)] = {
        var names = FluidType.allCases.map { ($0.displayName.lowercased(), $0) }
        names += [
            ("cuppa", .tea), ("cup of tea", .tea), ("fizzy water", .sparklingWater), ("seltzer", .sparklingWater),
            ("orange juice", .juice), ("oj", .juice), ("coke", .soda), ("soft drink", .soda), ("pop", .soda),
            ("pint", .beer), ("peppermint", .peppermintTea), ("herbal", .herbalTea), ("decaf", .coffee),
        ]
        return names.sorted { $0.0.count > $1.0.count }
    }()

    // MARK: Suggestions for Siri

    /// Values Siri can match in speech. Siri can't hear arbitrary numbers in a
    /// shortcut phrase, so this lists common sizes in the user's unit, a few
    /// in the other unit, and sizes for their most-logged drinks.
    static func suggestions(state: PersistedState, now: Date = Date()) -> [DrinkAmount] {
        let imperial = state.profile.unitSystem == .imperial
        let mlSizes: [Double] = Array(stride(from: 50.0, through: 1000, by: 50)) + [1250, 1500, 2000]
        let ozSizes: [Double] = [2, 4, 6, 8, 10, 12, 14, 16, 17, 20, 24, 32, 40]
        let otherML: [Double] = [250, 330, 500, 750, 1000]
        let otherOZ: [Double] = [8, 12, 16, 20]

        var values: [DrinkAmount] = imperial
            ? ozSizes.map { DrinkAmount(quantity: $0, unit: .oz) } + otherML.map { DrinkAmount(quantity: $0, unit: .ml) }
            : mlSizes.map { DrinkAmount(quantity: $0, unit: .ml) } + otherOZ.map { DrinkAmount(quantity: $0, unit: .oz) }

        for fluid in favoriteDrinks(state: state, now: now) {
            let usual = HydrationIntentCore.usualAmountML(for: fluid, in: state)
            if imperial {
                let usualOZ = UnitSystem.imperial.amount(fromML: usual).rounded()
                for oz in Set([4, 6, 8, 10, 12, 16, 20, usualOZ]) where oz > 0 {
                    values.append(DrinkAmount(quantity: oz, unit: .oz, fluid: fluid))
                }
            } else {
                let sizes = Set(stride(from: 100.0, through: 500, by: 50))
                    .union([usual.rounded(), fluid.defaultServingML])
                for ml in sizes where ml > 0 {
                    values.append(DrinkAmount(quantity: ml, unit: .ml, fluid: fluid))
                }
            }
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0.id).inserted }
    }

    /// Up to five non-water drinks logged most in the last 60 days, with
    /// common drinks as a starting point for new users.
    static func favoriteDrinks(state: PersistedState, now: Date) -> [FluidType] {
        let since = now.addingTimeInterval(-60 * 86_400)
        var counts: [FluidType: Int] = [:]
        for entry in state.entries where entry.date >= since && entry.fluidType != .water && entry.source != .healthKit {
            counts[entry.fluidType, default: 0] += 1
        }
        var ranked = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
            .map(\.key)
        for starter in [FluidType.coffee, .tea, .latte] where ranked.count < 3 && !ranked.contains(starter) {
            ranked.append(starter)
        }
        return Array(ranked.prefix(5))
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
