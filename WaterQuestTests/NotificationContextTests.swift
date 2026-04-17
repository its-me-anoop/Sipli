import XCTest
@testable import Sipli

final class NotificationContextTests: XCTestCase {

    private func makeProfile() -> UserProfile { .default }

    private func makeEntries(volumesML: [Double], on date: Date = Date()) -> [HydrationEntry] {
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

    func test_progress_isRatioOfTodayTotalToGoal() {
        let entries = makeEntries(volumesML: [500, 500])
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 0.5, accuracy: 0.001)
    }

    func test_progress_clampsToOneAboveGoal() {
        let entries = makeEntries(volumesML: [3000])
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 1.0, accuracy: 0.001)
    }

    func test_progress_isZeroWhenGoalIsZero() {
        let context = NotificationContext(
            profile: makeProfile(),
            entries: [],
            goalML: 0,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 0)
    }

    func test_todayTotalML_sumsOnlyTodayEntriesByEffectiveML() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            HydrationEntry(date: today,     volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: today,     volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: yesterday, volumeML: 1000, source: .manual, fluidType: .water),
        ]
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.todayTotalML, 1000, accuracy: 0.001)
    }
}
