import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    private var recentEntries: [HydrationEntry] {
        Array(data.todayEntries.prefix(5))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(Formatters.percentString(progress))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.volumeString(ml: data.todayTotalML, unit: data.unitSystem))
                        .font(.system(.title3, design: .rounded).weight(.heavy))

                    Text("of \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if data.streak > 0 {
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(data.streak)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            if recentEntries.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "drop")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No entries yet today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(recentEntries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.fluidType.iconName)
                            .font(.caption)
                            .foregroundStyle(entry.fluidType.color)
                            .frame(width: 20)

                        Text(entry.fluidType.displayName)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text(Formatters.volumeString(ml: entry.volumeML, unit: data.unitSystem))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()

                        Text(Self.timeFormatter.string(from: entry.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }

            Spacer(minLength: 0)

            Link(destination: URL(string: "sipli://add-intake")!) {
                HStack {
                    Spacer()
                    Label("Log Water", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
