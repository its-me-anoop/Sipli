import SwiftUI

struct WatchTodayLogView: View {
    @EnvironmentObject private var store: WatchHydrationStore

    var body: some View {
        if store.todayEntries.isEmpty {
            Text("No drinks logged yet today")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            VStack(spacing: 4) {
                Text("Today's Log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    ForEach(store.todayEntries.sorted(by: { $0.date > $1.date })) { entry in
                        WatchEntryRow(entry: entry, unitSystem: store.profile.unitSystem)
                    }
                    .onDelete { offsets in
                        let sorted = store.todayEntries.sorted(by: { $0.date > $1.date })
                        for offset in offsets {
                            store.deleteEntry(sorted[offset])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct WatchEntryRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    var body: some View {
        HStack {
            Image(systemName: entry.fluidType.iconName)
                .font(.system(size: 14))
                .foregroundStyle(entry.fluidType.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fluidType.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text("\(Formatters.shortVolume(ml: entry.volumeML, unit: unitSystem)) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
