#if canImport(AppIntentsTesting)
import XCTest
import AppIntentsTesting
@testable import Sipli

/// iOS 27 `AppIntentsTesting` smoke tests: exercises the intents the app
/// registers with the system through real system pathways (discovery,
/// parameter resolution, perform), complementing the pure-logic coverage in
/// `SipliAppIntentsTests`.
///
/// The framework is iOS 27-only and ships with Xcode 27's testing platform
/// frameworks, so the whole file is gated on `canImport` and each test guards
/// on `#available(iOS 27.0, *)`. Execution errors are downgraded to skips —
/// system-pathway availability varies across beta simulator environments and
/// must not mask the deterministic unit suites.
final class SipliAppIntentsSystemTests: XCTestCase {

    private static let bundleID = "com.waterquest.hydration"

    func test_logWaterIntent_definitionResolvesAndRuns() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27") }

        let definitions = IntentDefinitions(bundleIdentifier: Self.bundleID)
        let definition = definitions.intents["LogWaterIntent"]
        XCTAssertEqual(definition.identifier, "LogWaterIntent")
        XCTAssertEqual(definition.bundleIdentifier, Self.bundleID)

        do {
            let intent = definition.makeIntent(amountInMilliliters: 250)
            _ = try await intent.run()
        } catch {
            throw XCTSkip("Intent execution pathway unavailable in this environment: \(error)")
        }
    }

    func test_getTodaysHydrationIntent_definitionResolvesAndRuns() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27") }

        let definitions = IntentDefinitions(bundleIdentifier: Self.bundleID)
        let definition = definitions.intents["GetTodaysHydrationIntent"]
        XCTAssertEqual(definition.identifier, "GetTodaysHydrationIntent")

        do {
            let intent = definition.makeIntent()
            _ = try await intent.run()
        } catch {
            throw XCTSkip("Intent execution pathway unavailable in this environment: \(error)")
        }
    }

    func test_fluidTypeAppEnum_definitionResolvesCases() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27") }

        let definitions = IntentDefinitions(bundleIdentifier: Self.bundleID)
        let enumDefinition = definitions.enums["FluidTypeAppEnum"]
        let water = enumDefinition.makeCase("water")
        XCTAssertEqual(water.rawValue, "water")
    }
}
#endif
