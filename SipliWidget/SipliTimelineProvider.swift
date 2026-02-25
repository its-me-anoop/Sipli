import WidgetKit

struct SipliEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct SipliTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SipliEntry {
        SipliEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SipliEntry) -> Void) {
        let entry = SipliEntry(date: .now, data: WidgetDataProvider.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SipliEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = SipliEntry(date: .now, data: data)

        let calendar = Calendar.current
        let fifteenMin = calendar.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let nextRefresh = min(fifteenMin, midnight)

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

extension WidgetData {
    static let placeholder = WidgetData(
        todayEntries: [],
        todayTotalML: 1250,
        goal: GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450),
        streak: 3,
        unitSystem: .metric
    )
}
