import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @State private var showQuickAdd = false

    private var spooky: Bool { SpookySeason.showsTheme() }
    private var accent: Color { spooky ? SpookySeason.Palette.potion : Theme.lagoon }

    var body: some View {
        // `List` is the correct root container on watchOS. Nesting a `List`
        // inside a `ScrollView` breaks rendering and swipe-to-delete.
        List {
            VStack(spacing: 12) {
                WatchProgressRing(
                    progress: store.progress,
                    currentML: store.todayTotalML,
                    goalML: store.goalBreakdown.totalML,
                    unitSystem: store.profile.unitSystem,
                    spooky: spooky
                )
                .frame(width: 120, height: 120)
                .overlay(alignment: .topTrailing) {
                    if spooky {
                        Group {
                            if SpookySeason.isHalloween() {
                                PumpkinView().frame(width: 20)
                            } else {
                                BatShape()
                                    .fill(SpookySeason.Palette.potion.opacity(0.9))
                                    .frame(width: 24, height: 12)
                            }
                        }
                        .offset(x: 14, y: -2)
                        .accessibilityHidden(true)
                    }
                }
                .padding(.top, 4)

                HStack(spacing: 8) {
                    WatchStatPill(icon: "drop.fill", text: "\(store.todayDrinkCount) drinks", tint: accent)
                    WatchStatPill(
                        icon: "target",
                        text: "\(Formatters.shortVolume(ml: store.remainingML, unit: store.profile.unitSystem)) left",
                        tint: accent
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
                .tint(accent)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

            WatchTodayLogView()
        }
        .listStyle(.plain)
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
    var tint: Color = Theme.lagoon

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(tint.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: Capsule())
    }
}
