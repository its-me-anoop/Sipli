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
                .tint(Theme.lagoon)

                WatchTodayLogView()
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            WatchQuickAddView()
        }
        .overlay {
            if store.justReachedGoal {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.yellow)
                    Text("Goal Reached!")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            store.justReachedGoal = false
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: store.justReachedGoal)
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
        .foregroundStyle(Theme.lagoon.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.lagoon.opacity(0.15), in: Capsule())
    }
}
