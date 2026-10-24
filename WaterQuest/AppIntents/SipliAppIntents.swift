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


// MARK: - DrinkAmountAppEnum

/// Closed set of speakable amounts for App Shortcut phrases.
/// App Shortcuts can only interpolate AppEnum/AppEntity (not Int), so free-form
/// "300" must match a case via DisplayRepresentation title/synonyms.
enum DrinkAmountAppEnum: String, AppEnum {
    case ml100 = "100"
    case ml150 = "150"
    case ml200 = "200"
    case ml250 = "250"
    case ml300 = "300"
    case ml350 = "350"
    case ml400 = "400"
    case ml500 = "500"
    case ml600 = "600"
    case ml750 = "750"
    case ml1000 = "1000"
    case glass
    case cup

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Amount")

    static var caseDisplayRepresentations: [DrinkAmountAppEnum: DisplayRepresentation] = [
        .ml100: DisplayRepresentation(
            title: "100 milliliters",
            synonyms: ["100 ml", "100 mL", "100 millilitres", "100mls"]
        ),
        .ml150: DisplayRepresentation(
            title: "150 milliliters",
            synonyms: ["150 ml", "150 mL", "150 millilitres", "150mls"]
        ),
        .ml200: DisplayRepresentation(
            title: "200 milliliters",
            synonyms: ["200 ml", "200 mL", "200 millilitres", "200mls"]
        ),
        .ml250: DisplayRepresentation(
            title: "250 milliliters",
            synonyms: ["250 ml", "250 mL", "250 millilitres", "250mls"]
        ),
        .ml300: DisplayRepresentation(
            title: "300 milliliters",
            synonyms: ["300 ml", "300 mL", "300 millilitres", "300mls", "300ml"]
        ),
        .ml350: DisplayRepresentation(
            title: "350 milliliters",
            synonyms: ["350 ml", "350 mL", "350 millilitres", "350mls"]
        ),
        .ml400: DisplayRepresentation(
            title: "400 milliliters",
            synonyms: ["400 ml", "400 mL", "400 millilitres", "400mls"]
        ),
        .ml500: DisplayRepresentation(
            title: "500 milliliters",
            synonyms: ["500 ml", "500 mL", "500 millilitres", "500mls", "half a liter", "half a litre"]
        ),
        .ml600: DisplayRepresentation(
            title: "600 milliliters",
            synonyms: ["600 ml", "600 mL", "600 millilitres", "600mls"]
        ),
        .ml750: DisplayRepresentation(
            title: "750 milliliters",
            synonyms: ["750 ml", "750 mL", "750 millilitres", "750mls"]
        ),
        .ml1000: DisplayRepresentation(
            title: "1000 milliliters",
            synonyms: ["1000 ml", "1000 mL", "1 liter", "1 litre", "a liter", "a litre"]
        ),
        .glass: DisplayRepresentation(
            title: "a glass",
            synonyms: ["glass", "a glass of", "one glass"]
        ),
        .cup: DisplayRepresentation(
            title: "a cup",
            synonyms: ["cup", "a cup of", "one cup"]
        ),
    ]

    var milliliters: Int {
        switch self {
        case .ml100: return 100
        case .ml150: return 150
        case .ml200: return 200
        case .ml250: return 250
        case .ml300: return 300
        case .ml350: return 350
        case .ml400: return 400
        case .ml500: return 500
        case .ml600: return 600
        case .ml750: return 750
        case .ml1000: return 1000
        case .glass: return 250
        case .cup: return 240
        }
    }
}

// MARK: - LogWaterIntent

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Logs a water intake to Sipli.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount (mL)", default: 250, inclusiveRange: (50, 2000))
    var amountInMilliliters: Int

    /// Speakable preset for App Shortcut phrases (AppEnum). When set, wins over
    /// `amountInMilliliters` so Siri-bound amounts are not stuck at the Int default.
    @Parameter(title: "Preset Amount")
    var presetAmount: DrinkAmountAppEnum?

    @Parameter(title: "Fluid Type")
    var fluidType: FluidTypeAppEnum?

    init() {}

    init(amountInMilliliters: Int, fluidType: FluidTypeAppEnum? = nil, presetAmount: DrinkAmountAppEnum? = nil) {
        self.amountInMilliliters = amountInMilliliters
        self.fluidType = fluidType
        self.presetAmount = presetAmount
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedFluid = fluidType?.toFluidType() ?? .water
        let amount = presetAmount?.milliliters ?? amountInMilliliters

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
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceService.shared
        let state = persistence.load(PersistedState.self, fallback: .default)
        let now = Date()
        var dialogText = HydrationIntentCore.todaysHydrationDialog(state: state, now: now)
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = HydrationIntentCore.todaysHydrationCompact(state: state, now: now)
        }
        #endif
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = PersistenceService.shared.load(PersistedState.self, fallback: .default)
        let result = HydrationIntentCore.remainingDialog(state: state, now: Date())

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var result: (entry: HydrationEntry, dialog: String, compactDialog: String)!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            result = HydrationIntentCore.repeatLastDrink(into: &state, now: Date())
        }

        WidgetCenter.shared.reloadAllTimelines()
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
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var result: (removed: HydrationEntry?, dialog: String, compactDialog: String)!
        PersistenceService.shared.update(PersistedState.self, fallback: .default) { state in
            result = HydrationIntentCore.undoLastToday(from: &state, now: Date())
        }
        if result.removed != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }

        var dialogText = result.dialog
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), !systemContext.isVoiceOnly {
            dialogText = result.compactDialog
        }
        #endif
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
