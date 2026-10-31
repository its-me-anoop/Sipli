import Foundation
import Testing
@testable import Sipli

@Suite("TrialTimeline", .tags(.subscription))
struct TrialTimelineTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    /// 30 Oct 2026, 09:00 London.
    private var start: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 9))!
    }

    private func make(
        _ length: TrialLength,
        canRemind: Bool = true
    ) -> TrialTimeline {
        TrialTimeline.make(
            trial: length,
            startingAt: start,
            renewalPrice: "£19.99/yr",
            canRemind: canRemind,
            calendar: calendar
        )
    }

    @Test("A one-month trial ends one calendar month after it starts")
    func monthTrial_endsOneMonthLater() {
        let timeline = make(TrialLength(value: 1, unit: .month))
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 9))!
        #expect(timeline.trialEnd == expected)
    }

    @Test("Milestones run unlock, reminder, then billing")
    func milestones_areOrdered() {
        let timeline = make(TrialLength(value: 1, unit: .month))
        #expect(timeline.milestones.map(\.kind) == [.unlock, .reminder, .billing])
        #expect(timeline.milestones.map(\.date) == timeline.milestones.map(\.date).sorted())
    }

    @Test("The reminder lands two days before the trial ends")
    func reminder_isTwoDaysBeforeEnd() {
        let timeline = make(TrialLength(value: 1, unit: .month))
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 9))!
        #expect(timeline.reminderDate == expected)
    }

    @Test("Short trials remind one day before the end")
    func shortTrial_remindsOneDayBefore() {
        let timeline = make(TrialLength(value: 3, unit: .day))
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))!
        #expect(timeline.reminderDate == expected)
    }

    @Test("A one-day trial has no room for a reminder")
    func oneDayTrial_hasNoReminder() {
        let timeline = make(TrialLength(value: 1, unit: .day))
        #expect(timeline.reminderDate == nil)
        #expect(timeline.milestones.map(\.kind) == [.unlock, .billing])
    }

    @Test("Without notification permission the reminder step is dropped, not promised")
    func cannotRemind_dropsReminderMilestone() {
        let timeline = make(TrialLength(value: 1, unit: .month), canRemind: false)
        #expect(timeline.reminderDate == nil)
        #expect(!timeline.milestones.contains { $0.kind == .reminder })
        let billing = timeline.milestones.last
        #expect(billing?.detail.contains("Cancel anytime before") == true)
    }

    @Test("The billing step states the renewal price")
    func billing_mentionsPrice() {
        let timeline = make(TrialLength(value: 1, unit: .month))
        #expect(timeline.milestones.last?.detail.contains("£19.99/yr") == true)
    }

    @Test("The reminder copy tells the user how far ahead it arrives")
    func reminder_copyMatchesLeadTime() {
        let month = make(TrialLength(value: 1, unit: .month))
        #expect(month.milestones[1].detail.contains("2 days before"))
        let short = make(TrialLength(value: 3, unit: .day))
        #expect(short.milestones[1].detail.contains("1 day before"))
    }

    @Test(
        "Trial length reads naturally in the call to action",
        arguments: [
            (TrialLength(value: 1, unit: .month), "month"),
            (TrialLength(value: 1, unit: .week), "week"),
            (TrialLength(value: 7, unit: .day), "7 days"),
            (TrialLength(value: 2, unit: .month), "2 months")
        ]
    )
    func trialLength_phrase(length: TrialLength, phrase: String) {
        #expect(length.phrase == phrase)
    }

    @Test("Call to action uses the short form for single periods")
    func callToAction_singlePeriod() {
        #expect(TrialLength(value: 1, unit: .month).callToAction == "Start my free month")
        #expect(TrialLength(value: 7, unit: .day).callToAction == "Start my free 7 days")
    }

    @Test(
        "Reminders are possible unless notifications are denied",
        arguments: [
            (TrialReminderAvailability.authorized, true),
            (.provisional, true),
            (.notDetermined, true),
            (.denied, false)
        ]
    )
    func canRemind_byAuthorization(status: TrialReminderAvailability, expected: Bool) {
        #expect(status.canRemind == expected)
    }
}
