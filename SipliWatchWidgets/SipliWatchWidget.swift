import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider

struct WatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), progress: 0.65, currentML: 1560, goalML: 2400, unitSystem: .metric)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> WatchWidgetEntry {
        let persistence = PersistenceService()
        let state = persistence.load(PersistedState.self, fallback: .default)

        let todayEntries = state.entries.filter { $0.date >= Date().startOfDay }
        let totalML = todayEntries.reduce(0.0) { $0 + $1.effectiveML }

        let weather = state.profile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = state.profile.prefersHealthKit ? state.lastWorkout : nil
        let goal = GoalCalculator.dailyGoal(profile: state.profile, weather: weather, workout: workout)

        let progress = goal.totalML > 0 ? min(totalML / goal.totalML, 1.0) : 0

        return WatchWidgetEntry(
            date: Date(),
            progress: progress,
            currentML: totalML,
            goalML: goal.totalML,
            unitSystem: state.profile.unitSystem
        )
    }
}

// MARK: - Entry

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let progress: Double
    let currentML: Double
    let goalML: Double
    let unitSystem: UnitSystem
}

// MARK: - Complication Views

struct CircularComplicationView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
                .foregroundStyle(Theme.lagoon)
        } currentValueLabel: {
            Text("\(Int(entry.progress * 100))")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [
            Theme.lagoon,
            Color(red: 0.19, green: 0.76, blue: 0.64)
        ]))
    }
}

struct CornerComplicationView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        Text("\(Int(entry.progress * 100))%")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.lagoon)
            .widgetLabel {
                Gauge(value: entry.progress) {
                    Text("Hydration")
                } currentValueLabel: {
                    Text("\(Int(entry.progress * 100))%")
                }
                .tint(Theme.lagoon)
                .gaugeStyle(.accessoryLinear)
            }
    }
}

struct SipliWatchComplicationView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WatchWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Complication Widget

struct SipliWatchComplication: Widget {
    let kind = "SipliWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            SipliWatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Sipli Hydration")
        .description("Track your daily hydration progress.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

// MARK: - Quick Add Widget View

struct QuickAddWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(entry.progress * 100))%")
                    .font(.system(size: 20, weight: .bold))
                Text(Formatters.shortVolume(ml: entry.currentML, unit: entry.unitSystem))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(intent: WatchQuickAddIntent()) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.lagoon)
            }
            .buttonStyle(.plain)
        }
    }
}

struct SipliQuickAddWidget: Widget {
    let kind = "SipliQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Sipli Quick Add")
        .description("Tap to log 250ml of water.")
        .supportedFamilies([.accessoryRectangular])
    }
}
