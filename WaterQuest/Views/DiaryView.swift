import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager

    @State private var selectedDate = Date()
    @State private var entryToEdit: HydrationEntry?
    @State private var entryToDelete: HydrationEntry?

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    private var entriesForSelectedDate: [HydrationEntry] {
        store.entries
            .filter { $0.date.isSameDay(as: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private var dailyTotal: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.effectiveML }
    }

    private var goalMet: Bool {
        dailyTotal >= store.dailyGoal.totalML
    }

    var body: some View {
        Group {
            if isRegular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle("Diary")
        .confirmationDialog("Delete this entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                    entryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        }
        .sheet(item: $entryToEdit) { entry in
            EntryEditorSheet(entry: entry, unitSystem: store.profile.unitSystem) { updatedAmount, updatedFluidType, updatedNote in
                store.updateEntry(
                    id: entry.id,
                    volumeML: store.profile.unitSystem.ml(from: updatedAmount),
                    fluidType: updatedFluidType,
                    note: updatedNote
                )
            } onDelete: {
                deleteEntry(entry)
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                calendarSection

                daySummary

                entryList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left: Calendar
            VStack {
                calendarSection
                Spacer()
            }
            .frame(maxWidth: 380)

            // Right: Summary + Entries
            ScrollView {
                VStack(spacing: 16) {
                    daySummary

                    entryList
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .background(AppWaterBackground().ignoresSafeArea())
    }

    // MARK: - Components

    private var calendarSection: some View {
        DatePicker(
            "Select date",
            selection: $selectedDate,
            in: ...Date(),
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .tint(Theme.lagoon)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    private var daySummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate, style: .date)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text("Total: \(Formatters.volumeString(ml: dailyTotal, unit: store.profile.unitSystem))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lagoon)

                    if goalMet {
                        Label("Goal met", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Goal")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(Formatters.volumeString(ml: store.dailyGoal.totalML, unit: store.profile.unitSystem))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.lagoon)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var entryList: some View {
        if entriesForSelectedDate.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "drop")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No entries for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 12) {
                ForEach(entriesForSelectedDate) { entry in
                    let fluidTypeTotal = entriesForSelectedDate
                        .filter { $0.fluidType == entry.fluidType }
                        .reduce(0) { $0 + $1.effectiveML }

                    Button {
                        Haptics.selection()
                        entryToEdit = entry
                    } label: {
                        DetailedLogRow(
                            entry: entry,
                            unitSystem: store.profile.unitSystem,
                            fluidTypeTotalML: fluidTypeTotal
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func deleteEntry(_ entry: HydrationEntry) {
        Haptics.impact(.medium)
        if entry.source == .manual {
            Task {
                await healthKit.deleteWaterIntake(entryID: entry.id)
            }
        }
        store.deleteEntry(entry)
    }
}

#if DEBUG
#Preview("Diary") {
    PreviewEnvironment {
        DiaryView()
    }
}
#endif
