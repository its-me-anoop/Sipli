import SwiftUI
import WidgetKit

struct SipliWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let data: WidgetData

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: data)
        case .systemMedium:
            MediumWidgetView(data: data)
        case .systemLarge:
            LargeWidgetView(data: data)
        default:
            SmallWidgetView(data: data)
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SipliWidgetBundle: WidgetBundle {
    var body: some Widget {
        SipliWidget()
    }
}
