import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @State private var showQuickAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                WatchProgressRing(
                    progress: store.progress,
                    currentML: store.todayTotalML,
                    goalML: store.goalBreakdown.totalML,
                    unitSystem: store.profile.unitSystem
                )
                .frame(width: 120, height: 120)
                .padding(.top, 4)

                HStack(spacing: 8) {
                    WatchStatPill(icon: "drop.fill", text: "\(store.todayDrinkCount) drinks")
                    WatchStatPill(
                        icon: "target",
                        text: "\(Formatters.shortVolume(ml: store.remainingML, unit: store.profile.unitSystem)) left"
                    )
                }

                Button {
                    showQuickAdd = true
                } label: {
                    Label("Add Water", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.47, blue: 0.96))

                WatchTodayLogView()
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            WatchQuickAddView()
        }
    }
}

struct WatchStatPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96).opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: 0.11, green: 0.47, blue: 0.96).opacity(0.15), in: Capsule())
    }
}
