import XCTest
@testable import Sipli

final class NotificationContextTests: XCTestCase {

    private func makeProfile() -> UserProfile { .default }

    private func makeEntries(volumesML: [Double], on date: Date) -> [HydrationEntry] {
        volumesML.enumerated().map { idx, volume in
            HydrationEntry(
                id: UUID(),
                date: date.addingTimeInterval(Double(idx) * 60),
                volumeML: volume,
                source: .manual,
                fluidType: .water,
                note: nil
            )
        }
    }

    private let fixedNow: Date = Date(timeIntervalSince1970: 1_800_000_000) // deterministic

    func test_progress_isRatioOfTodayTotalToGoal() {
        let entries = makeEntries(volumesML: [500, 500], on: fixedNow)
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false,
            capturedAt: fixedNow
        )
        XCTAssertEqual(context.progress, 0.5, accuracy: 0.001)
    }

    func test_progress_clampsToOneAboveGoal() {
        let entries = makeEntries(volumesML: [3000], on: fixedNow)
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false,
            capturedAt: fixedNow
        )
        XCTAssertEqual(context.progress, 1.0, accuracy: 0.001)
    }

    func test_progress_isZeroWhenGoalIsZero() {
        let context = NotificationContext(
            profile: makeProfile(),
            entries: [],
            goalML: 0,
            currentStreak: 0,
            hasPremiumAccess: false,
            capturedAt: fixedNow
        )
        XCTAssertEqual(context.progress, 0)
    }

    func test_todayTotalML_sumsOnlyTodayEntriesByEffectiveML() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: fixedNow)!
        let entries = [
            HydrationEntry(date: fixedNow,  volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: fixedNow,  volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: yesterday, volumeML: 1000, source: .manual, fluidType: .water),
        ]
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false,
            capturedAt: fixedNow
        )
        XCTAssertEqual(context.todayTotalML, 1000, accuracy: 0.001)
    }
}

extension NotificationContextTests {

    @MainActor
    func test_buildNotificationContext_returnsGoalAndPremiumFromStore() {
        let store = HydrationStore()
        store.updateProfile { $0.weightKg = 70 }
        store.updatePremiumAccess(false)

        let context = store.buildNotificationContext()

        XCTAssertFalse(context.hasPremiumAccess)
        XCTAssertGreaterThan(context.goalML, 0)
        XCTAssertEqual(context.profile.weightKg, 70)
    }
}
