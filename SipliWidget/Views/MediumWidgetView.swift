import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(Formatters.percentString(progress))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 6) {
                Text(Formatters.volumeString(ml: data.todayTotalML, unit: data.unitSystem))
                    .font(.system(.title3, design: .rounded).weight(.heavy))

                Text("of \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if data.streak > 0 {
                    Label("\(data.streak)-day streak", systemImage: "flame.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Link(destination: URL(string: "sipli://add-intake")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
