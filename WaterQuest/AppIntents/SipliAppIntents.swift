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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceService()
        var state = persistence.load(PersistedState.self, fallback: .default)

        let clampedML = min(max(Double(amountInMilliliters), 50), 2_000)
        let resolvedFluid = fluidType?.toFluidType() ?? .water

        let entry = HydrationEntry(
            date: Date(),
            volumeML: clampedML,
            source: .manual,
            fluidType: resolvedFluid
        )

        state.entries.append(entry)
        persistence.save(state)
        WidgetCenter.shared.reloadAllTimelines()

        IntentDonationService.donateLogWater(
            amount: clampedML,
            fluidType: resolvedFluid
        )

        let goalML = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: state.lastWeather,
            workout: nil
        ).totalML

        let todayML = state.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0.0) { $0 + $1.effectiveML }

        let percent = goalML > 0 ? Int((todayML / goalML) * 100) : 0
        let formattedAmount = "\(Int(clampedML)) mL"
        let fluidLabel = resolvedFluid == .water ? "water" : resolvedFluid.displayName.lowercased()

        return .result(
            dialog: "Logged \(formattedAmount) of \(fluidLabel). You're at \(percent)% of today's goal."
        )
    }
}

// MARK: - GetTodaysHydrationIntent

struct GetTodaysHydrationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Hydration"
    static var description = IntentDescription("Returns today's water intake and goal progress.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let persistence = PersistenceService()
        let state = persistence.load(PersistedState.self, fallback: .default)

        let goalML = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: state.lastWeather,
            workout: nil
        ).totalML

        let todayML = state.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0.0) { $0 + $1.effectiveML }

        let percent = goalML > 0 ? Int((todayML / goalML) * 100) : 0
        let todayFormatted = "\(Int(todayML)) mL"
        let goalFormatted = "\(Int(goalML)) mL"

        return .result(
            dialog: "You've had \(todayFormatted) of water today — \(percent)% of your \(goalFormatted) goal."
        )
    }
}

// MARK: - OpenSipliIntent

struct OpenSipliIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Sipli"
    static var description = IntentDescription("Opens the Sipli app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
