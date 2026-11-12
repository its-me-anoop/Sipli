// Siri AI Developer Preview (iOS 27.3): new tool intents for requests
// people phrase in their own words. Compiled only with SIRI_AI_PREVIEW; see
// DrinkEntryEntity.swift for how the flag is set.
//
// All logic lives in `HydrationAssistantCore`; each intent loads the shared
// state, calls the core, saves, and fires the usual side effects.
#if SIRI_AI_PREVIEW
import AppIntents
import Foundation

// MARK: - Shared plumbing

@available(iOS 27.3, *)
extension HydrationAssistantCore.Failure: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: message)
    }
}

@available(iOS 27.3, *)
extension AppIntent {
    /// Voice gets the full sentence; screens get the compact line.
    func sipliDialog(_ full: String, compact: String) -> IntentDialog {
        IntentDialog(stringLiteral: systemContext.isVoiceOnly ? full : compact)
    }
}

/// Coordinated read-modify-write of the shared state file that lets the
/// core throw. The core validates before it mutates, so a thrown error
/// leaves the file as it was.
@available(iOS 27.3, *)
enum SiriAIState {
    static func update<T>(_ body: (inout PersistedState) throws -> T) throws -> T {
        var outcome: Result<T, Error>!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            var copy = state
            outcome = Result { try body(&copy) }
            if case .success = outcome { state = copy }
        }
        return try outcome.get()
    }

    static func load() -> PersistedState {
        PersistenceService.shared.load(PersistedState.self, fallback: .default)
    }

    static func dataChanged() {
        IntentEffects.hydrationDataChanged()
    }
}

// MARK: - Generable drink

/// One drink as Siri understands it from a request. Generable, so Siri
/// fills it in straight from "two coffees and a glass of water this
/// morning" without asking Sipli to look anything up.
@available(iOS 27.3, *)
@AppEntity(.generable)
struct DrinkToLog: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Drink to Log"

    @Property(
        title: "Drink",
        description: "The kind of drink. Use water when the person just says water or a glass, bottle or cup of water."
    )
    var drink: FluidTypeAppEnum

    @Property(
        title: "Amount (mL)",
        description: "How much of this one drink, in millilitres, from 10 to 2000. Convert other units: 1 US fl oz is about 30 mL, a cup is about 240 mL, a pint is about 470 mL, a litre is 1000 mL. Leave empty if the person didn't say, and Sipli uses their usual size for this drink."
    )
    var amountML: Int?

    @Property(
        title: "Time",
        description: "When the person had this drink, if they said, such as 'this morning', 'at 9' or 'with lunch yesterday'. Leave empty if they had it just now. Sipli accepts times up to 7 days ago."
    )
    var loggedAt: Date?

    var displayRepresentation: DisplayRepresentation {
        if let amountML {
            return "\(amountML) mL \(drink.localizedTitle)"
        }
        return "\(drink.localizedTitle)"
    }

    init() {}

    var request: HydrationAssistantCore.DrinkRequest {
        HydrationAssistantCore.DrinkRequest(
            fluid: drink.toFluidType(),
            amountML: amountML.map(Double.init),
            loggedAt: loggedAt
        )
    }
}

// MARK: - Log several drinks

@available(iOS 27.3, *)
@AppIntent(.tool)
struct LogDrinksIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Drinks"
    static let description = IntentDescription(
        "Adds one or more drinks to the person's Sipli hydration log in a single step, each with its own amount and time. Use it when someone lists several drinks, like 'two coffees and a water this morning', or says when they had a drink."
    )
    static let openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "Drinks",
        description: "Every drink the person mentioned, one item per drink: 'two coffees' is two coffee items. Up to 12 drinks."
    )
    var drinks: [DrinkToLog]

    init() {}

    func perform() async throws -> some ReturnsValue<[DrinkEntryEntity]> & ProvidesDialog & ShowsSnippetView {
        let now = Date()
        let requests = drinks.map(\.request)
        let (outcome, progress, unit) = try SiriAIState.update { state in
            let outcome = try HydrationAssistantCore.logDrinks(requests, into: &state, now: now)
            return (outcome, HydrationIntentCore.progress(state: state, now: now), state.profile.unitSystem)
        }
        SiriAIState.dataChanged()
        for entry in outcome.entries {
            IntentDonationService.donateLogWater(amount: entry.volumeML, fluidType: entry.fluidType)
        }
        return .result(
            value: outcome.entries.map { DrinkEntryEntity(entry: $0, unit: unit) },
            dialog: sipliDialog(outcome.dialog, compact: outcome.compactDialog),
            view: HydrationSnippetView(progress: progress)
        )
    }
}

// MARK: - Find drinks

@available(iOS 27.3, *)
@AppIntent(.tool)
struct FindDrinksIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Logged Drinks"
    static let description = IntentDescription(
        "Looks up the drinks the person logged in Sipli over one day or a range of days, optionally only one kind of drink, and says how many and how much. Use it for questions like 'what did I drink yesterday?' or 'how much coffee did I have this week?', and to find a drink before changing or deleting it."
    )
    static let openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "From",
        description: "The first day to look at. For 'today' use today, for 'yesterday' use yesterday, for 'this week' use the first day of this week."
    )
    var startDate: Date

    @Parameter(
        title: "Through",
        description: "The last day to include. Leave empty to look at the From day only."
    )
    var endDate: Date?

    @Parameter(
        title: "Drink",
        description: "Only include this kind of drink, such as coffee. Leave empty to include every drink."
    )
    var drink: FluidTypeAppEnum?

    init() {}

    func perform() async throws -> some ReturnsValue<[DrinkEntryEntity]> & ProvidesDialog {
        let state = SiriAIState.load()
        let now = Date()
        let end = endDate ?? startDate
        let fluid = drink?.toFluidType()
        let found = HydrationAssistantCore.entries(in: state, from: startDate, through: end, fluid: fluid)
        let summary = HydrationAssistantCore.historySummary(
            found, from: startDate, through: end, fluid: fluid, state: state, now: now
        )
        return .result(
            value: found.map { DrinkEntryEntity(entry: $0, unit: state.profile.unitSystem) },
            dialog: sipliDialog(summary.dialog, compact: summary.compactDialog)
        )
    }
}

// MARK: - Change a drink

@available(iOS 27.3, *)
@AppIntent(.tool)
struct UpdateDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Change a Logged Drink"
    static let description = IntentDescription(
        "Corrects a drink already in the person's Sipli log: its amount, the kind of drink, or both. Use it for 'that latte was actually 400 ml' or 'make my last drink a tea'."
    )
    static let openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "Drink Entry",
        description: "The logged drink to change."
    )
    var entry: DrinkEntryEntity

    @Parameter(
        title: "New Amount (mL)",
        description: "The corrected amount in millilitres, from 10 to 2000. Leave empty to keep the amount.",
        inclusiveRange: (10, 2000)
    )
    var amountML: Int?

    @Parameter(
        title: "New Drink",
        description: "The corrected kind of drink. Leave empty to keep it."
    )
    var drink: FluidTypeAppEnum?

    init() {}

    func perform() async throws -> some ReturnsValue<DrinkEntryEntity> & ProvidesDialog & ShowsSnippetView {
        let now = Date()
        let id = entry.id
        let amount = amountML.map(Double.init)
        let fluid = drink?.toFluidType()
        let (result, unit) = try SiriAIState.update { state in
            (try HydrationAssistantCore.updateEntry(id: id, amountML: amount, fluid: fluid, in: &state, now: now),
             state.profile.unitSystem)
        }
        SiriAIState.dataChanged()
        let updated = DrinkEntryEntity(entry: result.entry, unit: unit)
        return .result(
            value: updated,
            dialog: sipliDialog(result.dialog, compact: result.compactDialog),
            view: DrinkEntryCardView(entry: updated)
        )
    }
}

// MARK: - Delete a drink

@available(iOS 27.3, *)
@AppIntent(.tool)
struct DeleteDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete a Logged Drink"
    static let description = IntentDescription(
        "Removes one specific drink from the person's Sipli log, such as 'delete the coffee I logged at 9'. To remove just the most recent drink, the undo last drink action is simpler."
    )
    static let openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "Drink Entry",
        description: "The logged drink to delete."
    )
    var entry: DrinkEntryEntity

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Deleting can't be undone from Siri, so confirm the exact drink first.
        try await requestConfirmation(
            result: .result(dialog: "Delete \(entry.amountText) of \(entry.drink.localizedTitle.lowercased()) from \(entry.loggedAt.formatted(date: .abbreviated, time: .shortened))?")
        )
        let now = Date()
        let id = entry.id
        let result = try SiriAIState.update { state in
            try HydrationAssistantCore.deleteEntry(id: id, from: &state, now: now)
        }
        SiriAIState.dataChanged()
        return .result(dialog: sipliDialog(result.dialog, compact: result.compactDialog))
    }
}

// MARK: - Daily goal

@available(iOS 27.3, *)
@AppIntent(.tool)
struct SetDailyGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Daily Water Goal"
    static let description = IntentDescription(
        "Sets the person's daily hydration goal in Sipli to a fixed amount, or switches it back to the automatic goal Sipli calculates from their weight and activity."
    )
    static let openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(
        title: "Goal (mL)",
        description: "The new daily goal in millilitres. Sipli accepts about 1500 to 4500 mL; 2.5 litres is 2500 mL and 80 US fl oz is about 2370 mL. Leave empty only when the person asks to go back to the automatic goal."
    )
    var goalML: Int?

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = Date()
        let requested = goalML.map(Double.init)
        let (result, progress) = try SiriAIState.update { state in
            (HydrationAssistantCore.setDailyGoal(ml: requested, in: &state),
             HydrationIntentCore.progress(state: state, now: now))
        }
        SiriAIState.dataChanged()
        return .result(
            dialog: sipliDialog(result.dialog, compact: result.compactDialog),
            view: HydrationSnippetView(progress: progress)
        )
    }
}
#endif
