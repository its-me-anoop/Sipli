import XCTest
@testable import Sipli

/// Tests for the Spooky Season (Halloween) model: season window, brew phases,
/// the theme toggle, and the deterministic copy.
final class SpookySeasonTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Season window

    func test_isActive_insideWindow() {
        XCTAssertTrue(SpookySeason.isActive(on: date(2026, 10, 24, hour: 0)))
        XCTAssertTrue(SpookySeason.isActive(on: date(2026, 10, 31)))
        XCTAssertTrue(SpookySeason.isActive(on: date(2026, 11, 7, hour: 23)))
    }

    func test_isActive_outsideWindow() {
        XCTAssertFalse(SpookySeason.isActive(on: date(2026, 10, 23, hour: 23)))
        XCTAssertFalse(SpookySeason.isActive(on: date(2026, 11, 8, hour: 0)))
        XCTAssertFalse(SpookySeason.isActive(on: date(2027, 10, 31)))
    }

    func test_isHalloween() {
        XCTAssertTrue(SpookySeason.isHalloween(date(2026, 10, 31, hour: 1)))
        XCTAssertFalse(SpookySeason.isHalloween(date(2026, 10, 30)))
        XCTAssertFalse(SpookySeason.isHalloween(date(2026, 11, 1)))
    }

    func test_daysLeft_countsToday() {
        XCTAssertEqual(SpookySeason.daysLeft(from: date(2026, 11, 7)), 1)
        XCTAssertEqual(SpookySeason.daysLeft(from: date(2026, 10, 28)), 11)
        XCTAssertEqual(SpookySeason.daysLeft(from: date(2026, 11, 20)), 0)
    }

    // MARK: - Theme toggle

    /// Opt-in: nothing Halloween until the user says yes.
    func test_theme_offByDefault_andFollowsOptIn() throws {
        let suite = "SpookySeasonTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(SpookySeason.showsTheme(on: date(2026, 10, 30), defaults: defaults))
        defaults.set(true, forKey: SpookySeason.themeDefaultsKey)
        XCTAssertTrue(SpookySeason.showsTheme(on: date(2026, 10, 30), defaults: defaults))
        defaults.set(false, forKey: SpookySeason.themeDefaultsKey)
        XCTAssertFalse(SpookySeason.showsTheme(on: date(2026, 10, 30), defaults: defaults))
    }

    func test_theme_offOutsideSeason() throws {
        let suite = "SpookySeasonTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: SpookySeason.themeDefaultsKey)
        XCTAssertFalse(SpookySeason.showsTheme(on: date(2026, 12, 1), defaults: defaults))
    }

    // MARK: - Deep link

    func test_deepLink_matchesEventURLOnly() throws {
        XCTAssertTrue(SpookySeason.isDeepLink(try XCTUnwrap(URL(string: "sipli://spooky-season"))))
        XCTAssertTrue(SpookySeason.isDeepLink(try XCTUnwrap(URL(string: "SIPLI://Spooky-Season"))))
        XCTAssertFalse(SpookySeason.isDeepLink(try XCTUnwrap(URL(string: "sipli://trophy-room"))))
        XCTAssertFalse(SpookySeason.isDeepLink(try XCTUnwrap(URL(string: "https://spooky-season"))))
    }

    // MARK: - App icon

    func test_appIcon_spookyOverridesPreference_andClassicIsPrimary() {
        XCTAssertEqual(AppIconManager.desiredIconName(spooky: true, preferred: .ocean), "AppIcon-Spooky")
        XCTAssertEqual(AppIconManager.desiredIconName(spooky: false, preferred: .ocean), "AppIcon-Ocean")
        XCTAssertNil(AppIconManager.desiredIconName(spooky: false, preferred: .classic))
        XCTAssertEqual(Set(AppIconChoice.allCases.compactMap(\.alternateName)).count, AppIconChoice.allCases.count - 1)
    }

    // MARK: - Phases

    func test_phase_goalMetIsBrewed() {
        XCTAssertEqual(SpookySeason.phase(progress: 1.0, now: date(2026, 10, 30, hour: 9)), .brewed)
    }

    func test_phase_byTimeOfDay() {
        XCTAssertEqual(SpookySeason.phase(progress: 0.3, now: date(2026, 10, 30, hour: 9)), .brewing)
        XCTAssertEqual(SpookySeason.phase(progress: 0.5, now: date(2026, 10, 30, hour: 15)), .simmering)
        XCTAssertEqual(SpookySeason.phase(progress: 0.7, now: date(2026, 10, 30, hour: 21)), .witchingHour)
    }

    // MARK: - Copy

    func test_incantation_matchesPhase() {
        XCTAssertTrue(SpookySeason.incantation(phase: .brewing, progress: 0, sips: 0).contains("cauldron"))
        XCTAssertTrue(SpookySeason.incantation(phase: .brewing, progress: 0, sips: 0, halloween: true).contains("Halloween"))
        XCTAssertTrue(SpookySeason.incantation(phase: .witchingHour, progress: 0.8, sips: 5).contains("20%"))
        XCTAssertTrue(SpookySeason.incantation(phase: .brewed, progress: 1, sips: 8).contains("brewed"))
    }

    func test_cauldronLine_pluralises() {
        XCTAssertEqual(SpookySeason.cauldronLine(sips: 1, progress: 0.25), "1 sip · 25%")
        XCTAssertEqual(SpookySeason.cauldronLine(sips: 3, progress: 0.5), "3 sips · 50%")
    }

    func test_brewsSummary_cauldronKeeperAtThreshold() {
        XCTAssertTrue(SpookySeason.brewsSummary(brews: 4).contains("Cauldron Keeper at 5"))
        XCTAssertTrue(SpookySeason.brewsSummary(brews: 5).contains("Cauldron Keeper earned"))
    }
}
