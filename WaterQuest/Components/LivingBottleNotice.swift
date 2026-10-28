import SwiftUI

struct LivingBottleNotice: View {
    let notice: LivingBottleCoordinator.Notice
    let progress: Double
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false
    var body: some View {
        HStack(spacing: 10) {
            RemainingWaterBottle(progress: progress, isRegular: false, bottleWidth: 47, bottleHeight: 64, showsGauge: false)
                .accessibilityHidden(true)
                .rotationEffect(.degrees(lifted && !LivingBottleMotion.disabled(reduceMotion) ? -5 : 0))
            VStack(alignment: .leading, spacing: 3) {
                Text(notice.purpose == .logged ? "Check-in saved" : "Hello again")
                    .font(.subheadline.weight(.semibold))
                Text(notice.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
                .accessibilityLabel("Dismiss bottle encouragement")
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Theme.card)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityIdentifier("livingBottleNotice")
        .onAppear {
            guard !LivingBottleMotion.disabled(reduceMotion) else { return }
            withAnimation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)) { lifted = true }
        }
    }
}

struct LivingInsightCard: View {
    @EnvironmentObject private var living: LivingBottleCoordinator
    var body: some View {
        if let snapshot = living.snapshot {
            HStack(alignment: .center, spacing: 12) {
                RemainingWaterBottle(progress: snapshot.progress, isRegular: false, bottleWidth: 65, bottleHeight: 92, showsGauge: false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(living.wording).font(.subheadline.weight(.medium))
                    Text(snapshot.fact).font(.caption).foregroundStyle(.secondary)
                    Text(snapshot.detail).font(.caption).foregroundStyle(.secondary)
                    Text(living.onDeviceWording ? "On-device AI · live log" : "Live log · built-in encouragement")
                        .font(.caption2).foregroundStyle(.secondary)
                    if !LivingBottleCoordinator.isModelReady {
                        Text("Apple Intelligence is unavailable here. Your log still updates live.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("livingInsightCard")
        }
    }
}

enum LivingBottleMotion {
    static func disabled(_ systemValue: Bool) -> Bool {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SIPLI_LIVING_REDUCE_MOTION"] == "1" { return true }
#endif
        return systemValue
    }
}
