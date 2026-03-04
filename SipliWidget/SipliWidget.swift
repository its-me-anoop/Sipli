import SwiftUI
import WidgetKit

struct SipliWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: data)
        case .systemMedium:
            MediumWidgetView(data: data)
        case .systemLarge:
            LargeWidgetView(data: data)
        case .accessoryCircular:
            AccessoryCircularWidgetView(progress: progress)
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(data: data, progress: progress)
        case .accessoryInline:
            AccessoryInlineWidgetView(data: data, progress: progress)
        default:
            SmallWidgetView(data: data)
        }
    }
}

struct AccessoryCircularWidgetView: View {
    let progress: Double

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(Formatters.percentString(progress))
                .font(.caption2.weight(.semibold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.blue)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct AccessoryRectangularWidgetView: View {
    let data: WidgetData
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hydration")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Formatters.shortVolume(ml: data.todayTotalML, unit: data.unitSystem)) / \(Formatters.shortVolume(ml: data.goal.totalML, unit: data.unitSystem))")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Gauge(value: progress) {
                EmptyView()
            }
                .gaugeStyle(.accessoryLinear)
                .tint(.blue)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct AccessoryInlineWidgetView: View {
    let data: WidgetData
    let progress: Double

    var body: some View {
        Text("Hydration \(Formatters.percentString(progress)) • \(Formatters.shortVolume(ml: data.todayTotalML, unit: data.unitSystem))")
    }
}

struct SipliWidget: Widget {
    let kind = "SipliWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SipliTimelineProvider()) { entry in
            SipliWidgetEntryView(data: entry.data)
        }
        .configurationDisplayName("Sipli")
        .description("Track your daily hydration progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct SipliWidgetBundle: WidgetBundle {
    var body: some Widget {
        SipliWidget()
    }
}

#if DEBUG
private extension WidgetData {
    static let previewMid = WidgetData(
        todayEntries: [
            HydrationEntry(date: .now.addingTimeInterval(-45 * 60), volumeML: 300, source: .manual, fluidType: .water),
            HydrationEntry(date: .now.addingTimeInterval(-2 * 60 * 60), volumeML: 250, source: .manual, fluidType: .tea),
            HydrationEntry(date: .now.addingTimeInterval(-4 * 60 * 60), volumeML: 350, source: .manual, fluidType: .sparklingWater),
            HydrationEntry(date: .now.addingTimeInterval(-6 * 60 * 60), volumeML: 200, source: .manual, fluidType: .coffee)
        ],
        todayTotalML: 1680,
        goal: GoalBreakdown(baseML: 2450, weatherAdjustmentML: 200, workoutAdjustmentML: 150, totalML: 2800),
        streak: 6,
        unitSystem: .metric
    )

    static let previewEmpty = WidgetData(
        todayEntries: [],
        todayTotalML: 0,
        goal: GoalBreakdown(baseML: 2400, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2400),
        streak: 0,
        unitSystem: .metric
    )

    static let previewGoalMetImperial = WidgetData(
        todayEntries: [
            HydrationEntry(date: .now.addingTimeInterval(-30 * 60), volumeML: 520, source: .manual, fluidType: .water),
            HydrationEntry(date: .now.addingTimeInterval(-90 * 60), volumeML: 500, source: .manual, fluidType: .water),
            HydrationEntry(date: .now.addingTimeInterval(-3 * 60 * 60), volumeML: 480, source: .manual, fluidType: .water),
            HydrationEntry(date: .now.addingTimeInterval(-5 * 60 * 60), volumeML: 500, source: .manual, fluidType: .water)
        ],
        todayTotalML: 2000,
        goal: GoalBreakdown(baseML: 1800, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 1800),
        streak: 10,
        unitSystem: .imperial
    )
}

#Preview("Small - Mid", as: .systemSmall) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewMid)
}

#Preview("Medium - Mid", as: .systemMedium) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewMid)
}

#Preview("Large - Empty", as: .systemLarge) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewEmpty)
}

#Preview("Large - Goal Met", as: .systemLarge) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewGoalMetImperial)
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewMid)
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewMid)
}

#Preview("Lock Screen Inline", as: .accessoryInline) {
    SipliWidget()
} timeline: {
    SipliEntry(date: .now, data: .previewMid)
}
#endif
