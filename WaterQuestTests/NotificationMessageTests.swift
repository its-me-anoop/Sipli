import XCTest
@testable import Sipli

final class NotificationMessageTests: XCTestCase {

    private func makeContext(progress: Double, streak: Int = 0) -> NotificationContext {
        let goalML: Double = 2000
        let todayML = progress * goalML
        let entry = HydrationEntry(
            date: Date(),
            volumeML: todayML,
            source: .manual,
            fluidType: .water
        )
        return NotificationContext(
            profile: .default,
            entries: todayML > 0 ? [entry] : [],
            goalML: goalML,
            currentStreak: streak,
            hasPremiumAccess: false,
            capturedAt: Date()
        )
    }

    @MainActor
    func test_messageFor_firstSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.1), slot: .first)
        XCTAssertFalse(msg.isEmpty)
    }

    @MainActor
    func test_messageFor_midSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.4), slot: .mid)
        XCTAssertFalse(msg.isEmpty)
    }

    @MainActor
    func test_messageFor_lateSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.8), slot: .late)
        XCTAssertFalse(msg.isEmpty)
    }

    @MainActor
    func test_messageFor_escalationSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.2), slot: .escalation)
        XCTAssertFalse(msg.isEmpty)
    }

    /// `slotFor(context:)` is the convenience that the scheduler uses when
    /// producing a reminder based solely on progress (no explicit slot).
    @MainActor
    func test_slotFor_picksFirstWhenProgressLow() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.1)), .first)
    }

    @MainActor
    func test_slotFor_picksMidWhenProgressMid() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.4)), .mid)
    }

    @MainActor
    func test_slotFor_picksLateWhenProgressHigh() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.8)), .late)
    }
}
