import SwiftUI

struct WatchProgressRing: View {
    let progress: Double
    let currentML: Double
    let goalML: Double
    let unitSystem: UnitSystem

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.11, green: 0.47, blue: 0.96), Color(red: 0.19, green: 0.76, blue: 0.64)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.86), value: progress)

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(Formatters.shortVolume(ml: currentML, unit: unitSystem)) / \(Formatters.shortVolume(ml: goalML, unit: unitSystem))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
