import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Shared intent plumbing

extension Notification.Name {
    /// Posted after an intent writes hydration data, so a running app
    /// reloads immediately instead of waiting for the next foreground.
    static let sipliHydrationDataChanged = Notification.Name("sipliHydrationDataChanged")
}

enum IntentEffects {
    /// Call after any intent writes the shared state file.
    static func hydrationDataChanged() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor in
            NotificationCenter.default.post(name: .sipliHydrationDataChanged, object: nil)
        }
    }
}

/// Compact progress card Siri and Shortcuts show under the spoken reply.
struct HydrationSnippetView: View {
    let progress: HydrationIntentCore.Progress

    private func volume(_ ml: Double) -> String {
        HydrationIntentCore.volume(ml, unit: progress.unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Theme.lagoon)
                Text(volume(progress.totalML))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("of \(volume(progress.goalML))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(progress.percent)%")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.lagoon)
            }
            // Plain shapes rather than ProgressView: snippets are rendered
            // out of process, where UIKit-backed controls may not draw.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.lagoon.opacity(0.18))
                    Capsule().fill(Theme.lagoon)
                        .frame(width: max(proxy.size.width * progress.fraction, progress.fraction > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
            Text(progress.remainingML >= 1 ? "\(volume(progress.remainingML)) to go today" : "Today's goal reached")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(volume(progress.totalML)) of \(volume(progress.goalML)), \(progress.percent) percent of today's goal"
        )
    }
}

// MARK: - FluidTypeAppEnum

/// AppEnum mirror of the model's FluidType. Only types that exist in
/// FluidType are included — adding a case here without a matching FluidType
/// case would be a compile error in FluidTypeAppEnum.toFluidType().
enum FluidTypeAppEnum: String, AppEnum {
    case water
    case sparklingWater
    case coconutWater
    case herbalTea
    case greenTea
    case blackTea
    case earlGrey
    case chamomile
    case peppermintTea
    case matcha
    case oolong
    case chai
    case rooibos
    case tea
    case milk
    case juice
    case lemonade
    case smoothie
    case sportsDrink
    case espresso
    case americano
    case latte
    case cappuccino
    case flatWhite
    case mocha
    case icedCoffee
    case coldBrew
    case macchiato
    case coffee
    case soda
    case energyDrink
    case soup
    case beer
    case wine
    case cocktail
    case other

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fluid Type")

    static var caseDisplayRepresentations: [FluidTypeAppEnum: DisplayRepresentation] = [
        .water:        DisplayRepresentation(title: "Water", synonyms: ["a glass of water", "glass of water", "a water", "a bottle of water"]),
        .sparklingWater: DisplayRepresentation(title: "Sparkling Water", synonyms: ["fizzy water", "a sparkling water", "seltzer"]),
        .coconutWater: DisplayRepresentation(title: "Coconut Water"),
        .herbalTea: DisplayRepresentation(title: "Herbal Tea", synonyms: ["an herbal tea", "a herbal tea"]),
        .greenTea: DisplayRepresentation(title: "Green Tea", synonyms: ["a green tea", "cup of green tea"]),
        .blackTea:     DisplayRepresentation(title: "Black Tea"),
        .earlGrey:     DisplayRepresentation(title: "Earl Grey"),
        .chamomile:    DisplayRepresentation(title: "Chamomile"),
        .peppermintTea: DisplayRepresentation(title: "Peppermint"),
        .matcha:       DisplayRepresentation(title: "Matcha"),
        .oolong:       DisplayRepresentation(title: "Oolong"),
        .chai:         DisplayRepresentation(title: "Chai"),
        .rooibos:      DisplayRepresentation(title: "Rooibos"),
        .tea: DisplayRepresentation(title: "Tea", synonyms: ["a tea", "a cup of tea", "cup of tea", "a cuppa"]),
        .milk: DisplayRepresentation(title: "Milk", synonyms: ["a glass of milk", "glass of milk"]),
        .juice: DisplayRepresentation(title: "Juice", synonyms: ["a juice", "a glass of juice", "orange juice"]),
        .lemonade:     DisplayRepresentation(title: "Lemonade"),
        .smoothie: DisplayRepresentation(title: "Smoothie", synonyms: ["a smoothie"]),
        .sportsDrink: DisplayRepresentation(title: "Sports Drink", synonyms: ["a sports drink"]),
        .espresso: DisplayRepresentation(title: "Espresso", synonyms: ["an espresso", "a shot of espresso"]),
        .americano: DisplayRepresentation(title: "Americano", synonyms: ["an americano"]),
        .latte: DisplayRepresentation(title: "Latte", synonyms: ["a latte"]),
        .cappuccino: DisplayRepresentation(title: "Cappuccino", synonyms: ["a cappuccino"]),
        .flatWhite: DisplayRepresentation(title: "Flat White", synonyms: ["a flat white"]),
        .mocha:        DisplayRepresentation(title: "Mocha"),
        .icedCoffee:   DisplayRepresentation(title: "Iced Coffee"),
        .coldBrew:     DisplayRepresentation(title: "Cold Brew"),
        .macchiato:    DisplayRepresentation(title: "Macchiato"),
        .coffee: DisplayRepresentation(title: "Coffee", synonyms: ["a coffee", "a cup of coffee", "cup of coffee"]),
        .soda: DisplayRepresentation(title: "Soda", synonyms: ["a soda", "a can of soda", "a soft drink", "a coke"]),
        .energyDrink: DisplayRepresentation(title: "Energy Drink", synonyms: ["an energy drink"]),
        .soup:         DisplayRepresentation(title: "Soup"),
        .beer: DisplayRepresentation(title: "Beer", synonyms: ["a beer", "a pint", "a pint of beer"]),
        .wine: DisplayRepresentation(title: "Wine", synonyms: ["a glass of wine", "glass of wine", "a wine"]),
        .cocktail:     DisplayRepresentation(title: "Cocktail"),
        .other:        DisplayRepresentation(title: "Other"),
    ]

    /// Converts to the model type. The one-to-one rawValue mapping keeps this O(1).
    func toFluidType() -> FluidType {
        FluidType(rawValue: rawValue) ?? .water
    }

    /// Converts from the model type.
    static func from(_ fluidType: FluidType) -> FluidTypeAppEnum {
        FluidTypeAppEnum(rawValue: fluidType.rawValue) ?? .water
    }
}

// MARK: - LogWaterIntent

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Logs a water intake to Sipli.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount (mL)", default: 250, inclusiveRange: (50, 2000))
    var amountInMilliliters: Int

    @Parameter(title: "Fluid Type")
    var fluidType: FluidTypeAppEnum?

    init() {}

    init(amountInMilliliters: Int, fluidType: FluidTypeAppEnum? = nil) {
        self.amountInMilliliters = amountInMilliliters
        self.fluidType = fluidType
    }

    static var parameterSummary: some ParameterSummary {
        When(\.$fluidType, .hasAnyValue) {
            Summary("Log \(\.$amountInMilliliters) mL of \(\.$fluidType)")
        } otherwise: {
            Summary("Log \(\.$amountInMilliliters) mL of water")
        }
    }

    // The iOS 27 App Intents surface (allowedExecutionTargets, isVoiceOnly)
    // exists only in the iOS 27 SDK, so it is fenced with compiler(>=6.4):
    // Xcode 27 beta ships Swift 6.4, the public Xcode 26.6 App Store
    // toolchain ships 6.3. The gates dissolve when Xcode 27 goes GM.
    #if compiler(>=6.4)
    /// iOS 27: this intent only ever executes in the app process; declaring
    /// that lets the system skip probing extension targets.
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let resolvedFluid = fluidType?.toFluidType() ?? .water
        let amount = amountInMilliliters

        // Coordinated read-modify-write: Siri/Shortcuts can run this while
        // the widget or app writes the same shared state file.
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        var progress: HydrationIntentCore.Progress!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            let now = Date()
            result = HydrationIntentCore.logWater(
                into: &state,
                amountInMilliliters: amount,
                fluidType: resolvedFluid,
                now: now
            )
            progress = HydrationIntentCore.progress(state: state, now: now)
        }

        IntentEffects.hydrationDataChanged()
        IntentDonationService.donateLogWater(
            amount: result.entry.volumeML,
            fluidType: resolvedFluid
        )

        // iOS 27 exposes whether the interaction is voice-only. Voice keeps
        // the full spoken sentence; visual surfaces get the compact line.
        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: progress)
        )
    }
}

// MARK: - LogDrinkIntent

/// "Log a latte in Sipli": logs a named drink at the user's usual size for
/// it (their last amount of that drink, else its typical serving), so Siri
/// never has to ask "how much?".
struct LogDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Drink"
    static var description = IntentDescription("Logs a drink at the size you usually have it.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Drink", requestValueDialog: "Which drink?")
    var fluidType: FluidTypeAppEnum

    init() {}

    init(fluidType: FluidTypeAppEnum) {
        self.fluidType = fluidType
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$fluidType)")
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let fluid = fluidType.toFluidType()
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        var progress: HydrationIntentCore.Progress!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            let now = Date()
            result = HydrationIntentCore.logDrink(into: &state, fluidType: fluid, now: now)
            progress = HydrationIntentCore.progress(state: state, now: now)
        }

        IntentEffects.hydrationDataChanged()
        IntentDonationService.donateLogWater(amount: result.entry.volumeML, fluidType: fluid)

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: progress)
        )
    }
}

// MARK: - LogAmountIntent

/// Siri-facing wrapper for `DrinkAmount`: "350 ml", "12 oz of coffee".
struct DrinkAmountEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Amount")
    static var defaultQuery = DrinkAmountQuery()

    let id: String
    let amount: DrinkAmount

    init(_ amount: DrinkAmount) {
        self.id = amount.id
        self.amount = amount
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(amount.title)",
            synonyms: amount.synonyms.map { "\($0)" }
        )
    }
}

struct DrinkAmountQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [DrinkAmountEntity] {
        identifiers.compactMap(DrinkAmount.init(id:)).map(DrinkAmountEntity.init)
    }

    /// Typed text in Shortcuts, e.g. "350ml latte" or "16 oz".
    func entities(matching string: String) async throws -> [DrinkAmountEntity] {
        let unit = PersistenceService.shared.load(PersistedState.self, fallback: .default).profile.unitSystem
        return DrinkAmount.parse(string, defaultUnit: unit).map { [DrinkAmountEntity($0)] } ?? []
    }

    /// The values Siri can recognise in speech; refreshed by
    /// `SipliAppShortcuts.updateAppShortcutParameters()`.
    func suggestedEntities() async throws -> [DrinkAmountEntity] {
        let state = PersistenceService.shared.load(PersistedState.self, fallback: .default)
        return DrinkAmount.suggestions(state: state).map(DrinkAmountEntity.init)
    }
}

/// "Log 350 ml of latte in Sipli", "I had 12 oz in Sipli".
struct LogAmountIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Amount"
    static var description = IntentDescription("Logs a specific amount of water or another drink, like 350 ml of latte.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", requestValueDialog: "How much did you drink?")
    var amount: DrinkAmountEntity

    init() {}

    init(amount: DrinkAmount) {
        self.amount = DrinkAmountEntity(amount)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount)")
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let drink = amount.amount
        let fluid = drink.fluid ?? .water
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        var progress: HydrationIntentCore.Progress!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            let now = Date()
            result = HydrationIntentCore.logWater(
                into: &state,
                amountInMilliliters: Int(drink.milliliters.rounded()),
                fluidType: fluid,
                now: now,
                minimumML: 10
            )
            progress = HydrationIntentCore.progress(state: state, now: now)
        }

        IntentEffects.hydrationDataChanged()
        IntentDonationService.donateLogWater(amount: result.entry.volumeML, fluidType: fluid)

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: progress)
        )
    }
}

// MARK: - GetTodaysHydrationIntent

struct GetTodaysHydrationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Hydration"
    static var description = IntentDescription("Returns today's water intake and goal progress.")
    static var openAppWhenRun: Bool = false

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let persistence = PersistenceService.shared
        let state = persistence.load(PersistedState.self, fallback: .default)
        let now = Date()
        var dialogText = HydrationIntentCore.todaysHydrationDialog(state: state, now: now)
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = HydrationIntentCore.todaysHydrationCompact(state: state, now: now)
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: HydrationIntentCore.progress(state: state, now: now))
        )
    }
}

// MARK: - OpenSipliIntent

struct OpenSipliIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Sipli"
    static var description = IntentDescription("Opens the Sipli app.")
    static var openAppWhenRun: Bool = true

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - GetStreakIntent

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Streak"
    static var description = IntentDescription("Returns your current hydration goal streak.")
    static var openAppWhenRun: Bool = false

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = PersistenceService.shared.load(PersistedState.self, fallback: .default)
        let result = HydrationIntentCore.streakDialog(state: state, now: Date())

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - GetRemainingIntent

struct GetRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "How Much More Do I Need"
    static var description = IntentDescription("Tells you how much more you need to drink to reach today's goal.")
    static var openAppWhenRun: Bool = false

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let state = PersistenceService.shared.load(PersistedState.self, fallback: .default)
        let now = Date()
        let result = HydrationIntentCore.remainingDialog(state: state, now: now)

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: HydrationIntentCore.progress(state: state, now: now))
        )
    }
}

// MARK: - RepeatLastDrinkIntent

struct RepeatLastDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log My Usual"
    static var description = IntentDescription("Logs the same drink as your most recent entry.")
    static var openAppWhenRun: Bool = false

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        var progress: HydrationIntentCore.Progress!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            let now = Date()
            result = HydrationIntentCore.repeatLastDrink(into: &state, now: now)
            progress = HydrationIntentCore.progress(state: state, now: now)
        }

        IntentEffects.hydrationDataChanged()
        IntentDonationService.donateLogWater(
            amount: result.entry.volumeML,
            fluidType: result.entry.fluidType
        )

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: progress)
        )
    }
}

// MARK: - OpenTrophyRoomIntent

extension Notification.Name {
    /// Posted by `OpenTrophyRoomIntent` after the system foregrounds the app;
    /// `WaterQuestApp` routes it into the same deep-link plumbing as
    /// `sipli://trophy-room`.
    static let sipliOpenTrophyRoom = Notification.Name("sipliOpenTrophyRoom")
}

struct OpenTrophyRoomIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Achievements"
    static var description = IntentDescription("Opens Sipli's Trophy Room with your earned badges.")
    /// Foregrounds the app first; perform() then runs in the app process,
    /// so a NotificationCenter post reaches the live SwiftUI scene.
    static var openAppWhenRun: Bool = true

    /// Cold-launch latch: on a fresh launch triggered by this intent the
    /// notification can fire before the scene's `.onReceive` subscriber is
    /// installed, so the request is also parked in UserDefaults and consumed
    /// when the scene becomes active.
    static let pendingOpenDefaultsKey = "pendingTrophyRoomOpen"

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: Self.pendingOpenDefaultsKey)
        NotificationCenter.default.post(name: .sipliOpenTrophyRoom, object: nil)
        return .result()
    }
}

// MARK: - UndoLastIntakeIntent

struct UndoLastIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Drink"
    static var description = IntentDescription("Removes the most recent drink you logged today in Sipli.")
    static var openAppWhenRun: Bool = false

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    #endif

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var result: (removed: HydrationEntry?, dialog: String, compactDialog: String)!
        var progress: HydrationIntentCore.Progress!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            let now = Date()
            result = HydrationIntentCore.undoLastToday(from: &state, now: now)
            progress = HydrationIntentCore.progress(state: state, now: now)
        }
        if result.removed != nil {
            IntentEffects.hydrationDataChanged()
        }

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: HydrationSnippetView(progress: progress)
        )
    }
}
