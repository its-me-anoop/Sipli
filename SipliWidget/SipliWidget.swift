import SwiftUI
import WidgetKit

struct SipliWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let data: WidgetData
    var date: Date = .now

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: data, style: style)
        case .systemMedium:
            MediumWidgetView(data: data, style: style)
        case .systemLarge:
            LargeWidgetView(data: data, style: style)
        case .accessoryCircular:
            AccessoryCircularWidgetView(progress: progress, tint: style.accent)
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(data: data, progress: progress, tint: style.accent)
        case .accessoryInline:
            AccessoryInlineWidgetView(data: data, progress: progress)
        default:
            SmallWidgetView(data: data, style: style)
        }
    }

    private var style: WidgetSeasonStyle { WidgetSeasonStyle(date: date) }
}

// MARK: - Spooky Season

/// Widget colours: the usual water blue, or the potion palette while
/// Spooky Season is live (keyed off the timeline entry's date).
struct WidgetSeasonStyle {
    let spooky: Bool
    let halloween: Bool

    init(date: Date) {
        spooky = SpookySeason.showsTheme(on: date)
        halloween = spooky && SpookySeason.isHalloween(date)
    }

    static let standard = WidgetSeasonStyle(spooky: false, halloween: false)

    private init(spooky: Bool, halloween: Bool) {
        self.spooky = spooky
        self.halloween = halloween
    }

    var accent: Color { spooky ? SpookySeason.Palette.potion : .blue }

    var ringTrack: Color { spooky ? SpookySeason.Palette.potion.opacity(0.25) : Color.blue.opacity(0.2) }

    var ringFill: AnyShapeStyle {
        guard spooky else { return AnyShapeStyle(Color.blue) }
        return AnyShapeStyle(AngularGradient(
            colors: [SpookySeason.Palette.potion, SpookySeason.Palette.slime],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        ))
    }
}

/// Tiny corner decoration: a bat, or a pumpkin on Halloween itself.
struct SpookyCornerMark: View {
    let style: WidgetSeasonStyle
    var width: CGFloat = 22

    var body: some View {
        Group {
            if style.halloween {
                PumpkinView()
                    .frame(width: width * 0.8)
            } else {
                BatShape()
                    .fill(SpookySeason.Palette.potion.opacity(0.85))
                    .frame(width: width, height: width / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

struct AccessoryCircularWidgetView: View {
    let progress: Double
    var tint: Color = .blue

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(Formatters.percentString(progress))
                .font(.caption2.weight(.semibold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(tint)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct AccessoryRectangularWidgetView: View {
    let data: WidgetData
    let progress: Double
    var tint: Color = .blue

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
                .tint(tint)
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
            SipliWidgetEntryView(data: entry.data, date: entry.date)
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
        if #available(iOS 18.0, *) {
            SipliQuickLogControl()
        }
    }
}

#if DEBUG && WIDGET_PREVIEWS
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

private let spookyPreviewDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 15)) ?? .now
private let halloweenPreviewDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 21)) ?? .now

#Preview("Spooky - Small", as: .systemSmall) {
    SipliWidget()
} timeline: {
    SipliEntry(date: spookyPreviewDate, data: .previewMid)
    SipliEntry(date: halloweenPreviewDate, data: .previewGoalMetImperial)
}

#Preview("Spooky - Medium", as: .systemMedium) {
    SipliWidget()
} timeline: {
    SipliEntry(date: spookyPreviewDate, data: .previewMid)
    SipliEntry(date: halloweenPreviewDate, data: .previewMid)
}

#Preview("Spooky - Large", as: .systemLarge) {
    SipliWidget()
} timeline: {
    SipliEntry(date: spookyPreviewDate, data: .previewMid)
    SipliEntry(date: halloweenPreviewDate, data: .previewEmpty)
}

#Preview("Spooky - Lock Screen Circular", as: .accessoryCircular) {
    SipliWidget()
} timeline: {
    SipliEntry(date: spookyPreviewDate, data: .previewMid)
}
#endif
