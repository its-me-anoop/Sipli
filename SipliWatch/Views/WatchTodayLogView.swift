import SwiftUI

/// Today's Log content. MUST be used as direct children of a `List` —
/// nesting a `List` inside a `ScrollView` on watchOS breaks rendering
/// and swipe-to-delete, so this view emits list rows directly.
struct WatchTodayLogView: View {
    @EnvironmentObject private var store: WatchHydrationStore

    var body: some View {
        if store.todayEntries.isEmpty {
            Text("No drinks logged yet today")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(store.todayEntries.sorted(by: { $0.date > $1.date })) { entry in
                    WatchEntryRow(entry: entry, unitSystem: store.profile.unitSystem)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                }
                .onDelete { offsets in
                    let sorted = store.todayEntries.sorted(by: { $0.date > $1.date })
                    for offset in offsets {
                        store.deleteEntry(sorted[offset])
                    }
                }
            } header: {
                Text("Today's Log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
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
