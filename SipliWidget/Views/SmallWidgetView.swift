import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    private var progress: Double {
        min(1, data.todayTotalML / max(1, data.goal.totalML))
    }

    var body: some View {
        VStack(spacing: 8) {
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

            Text("\(Formatters.shortVolume(ml: data.todayTotalML, unit: data.unitSystem)) / \(Formatters.volumeString(ml: data.goal.totalML, unit: data.unitSystem))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
