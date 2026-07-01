import AppIntents
import Foundation
import WidgetKit

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
        .water:        DisplayRepresentation(title: "Water"),
        .sparklingWater: DisplayRepresentation(title: "Sparkling Water"),
        .coconutWater: DisplayRepresentation(title: "Coconut Water"),
        .herbalTea:    DisplayRepresentation(title: "Herbal Tea"),
        .greenTea:     DisplayRepresentation(title: "Green Tea"),
        .blackTea:     DisplayRepresentation(title: "Black Tea"),
        .earlGrey:     DisplayRepresentation(title: "Earl Grey"),
        .chamomile:    DisplayRepresentation(title: "Chamomile"),
        .peppermintTea: DisplayRepresentation(title: "Peppermint"),
        .matcha:       DisplayRepresentation(title: "Matcha"),
        .oolong:       DisplayRepresentation(title: "Oolong"),
        .chai:         DisplayRepresentation(title: "Chai"),
        .rooibos:      DisplayRepresentation(title: "Rooibos"),
        .tea:          DisplayRepresentation(title: "Tea"),
        .milk:         DisplayRepresentation(title: "Milk"),
        .juice:        DisplayRepresentation(title: "Juice"),
        .lemonade:     DisplayRepresentation(title: "Lemonade"),
        .smoothie:     DisplayRepresentation(title: "Smoothie"),
        .sportsDrink:  DisplayRepresentation(title: "Sports Drink"),
        .espresso:     DisplayRepresentation(title: "Espresso"),
        .americano:    DisplayRepresentation(title: "Americano"),
        .latte:        DisplayRepresentation(title: "Latte"),
        .cappuccino:   DisplayRepresentation(title: "Cappuccino"),
        .flatWhite:    DisplayRepresentation(title: "Flat White"),
        .mocha:        DisplayRepresentation(title: "Mocha"),
        .icedCoffee:   DisplayRepresentation(title: "Iced Coffee"),
        .coldBrew:     DisplayRepresentation(title: "Cold Brew"),
        .macchiato:    DisplayRepresentation(title: "Macchiato"),
        .coffee:       DisplayRepresentation(title: "Coffee"),
        .soda:         DisplayRepresentation(title: "Soda"),
        .energyDrink:  DisplayRepresentation(title: "Energy Drink"),
        .soup:         DisplayRepresentation(title: "Soup"),
        .beer:         DisplayRepresentation(title: "Beer"),
        .wine:         DisplayRepresentation(title: "Wine"),
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

    /// iOS 27: this intent only ever executes in the app process; declaring
    /// that lets the system skip probing extension targets.
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedFluid = fluidType?.toFluidType() ?? .water
        let amount = amountInMilliliters

        // Coordinated read-modify-write: Siri/Shortcuts can run this while
        // the widget or app writes the same shared state file.
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            result = HydrationIntentCore.logWater(
                into: &state,
                amountInMilliliters: amount,
                fluidType: resolvedFluid,
                now: Date()
            )
        }

        WidgetCenter.shared.reloadAllTimelines()
        IntentDonationService.donateLogWater(
            amount: result.entry.volumeML,
            fluidType: resolvedFluid
        )

        // iOS 27 exposes whether the interaction is voice-only. Voice keeps
        // the full spoken sentence; visual surfaces get the compact line.
        var dialogText = result.dialog
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - GetTodaysHydrationIntent

struct GetTodaysHydrationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Hydration"
    static var description = IntentDescription("Returns today's water intake and goal progress.")
    static var openAppWhenRun: Bool = false

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceService.shared
        let state = persistence.load(PersistedState.self, fallback: .default)
        let now = Date()
        var dialogText = HydrationIntentCore.todaysHydrationDialog(state: state, now: now)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = HydrationIntentCore.todaysHydrationCompact(state: state, now: now)
        }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - OpenSipliIntent

struct OpenSipliIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Sipli"
    static var description = IntentDescription("Opens the Sipli app.")
    static var openAppWhenRun: Bool = true

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - UndoLastIntakeIntent

struct UndoLastIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Drink"
    static var description = IntentDescription("Removes the most recent drink you logged today in Sipli.")
    static var openAppWhenRun: Bool = false

    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var result: (removed: HydrationEntry?, dialog: String, compactDialog: String)!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            result = HydrationIntentCore.undoLastToday(from: &state, now: Date())
        }
        if result.removed != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }

        var dialogText = result.dialog
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
