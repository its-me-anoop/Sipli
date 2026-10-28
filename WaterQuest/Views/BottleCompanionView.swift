import SwiftUI

struct BottleCompanionView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var capacity = 750.0
    @State private var level = 0.0
    @State private var mode = Mode.drink
    @State private var confirmStop = false
    @State private var feedback = ""
    enum Mode: String, CaseIterable { case drink = "Drank", refill = "Top up", adjust = "Discard / shared" }

    var body: some View {
        NavigationStack {
            Form {
                if let bottle = store.companion {
                    Section {
                        RemainingWaterBottle(progress: 1 - bottle.remainingML / bottle.capacityML,
                                             isRegular: false, bottleWidth: 140, bottleHeight: 190)
                            .frame(maxWidth: .infinity).frame(height: 190)
                            .accessibilityLabel("Real bottle, approximately \(Int(bottle.remainingML)) millilitres remaining")
                        LabeledContent("Estimated remaining", value: amount(bottle.remainingML))
                        LabeledContent("Bottle capacity", value: amount(bottle.capacityML))
                    } footer: {
                        Text("This is your real water bottle. Your daily-goal bottle stays separate. Log drinks from this bottle here to avoid counting them twice.")
                    }
                    Section {
                        Picker("Action", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        LabeledContent("Water left", value: amount(level))
                        Slider(value: $level, in: 0...bottle.capacityML, step: 1)
                            .accessibilityLabel("Estimated water remaining in millilitres")
                        HStack {
                            Button("Empty") { level = 0 }.frame(minHeight: 44)
                            Spacer()
                            Button("Half") { level = bottle.capacityML / 2 }.frame(minHeight: 44)
                            Spacer()
                            Button("Full") { level = bottle.capacityML }.frame(minHeight: 44)
                        }.buttonStyle(.borderless)
                        Text(explanation(bottle)).font(.footnote).foregroundStyle(.secondary)
                        Button(actionLabel(bottle)) { commit(bottle) }
                            .disabled(!valid(bottle))
                        Button("Finished bottle") {
                            save(store.changeCompanion(.finish))
                            feedback = "Remaining water logged as an estimate."
                            level = store.companion?.remainingML ?? 0
                        }.disabled(bottle.remainingML == 0)
                    } header: { Text("Match the waterline") }
                    Section {
                        Button("Undo last bottle action") {
                            if let entry = store.undoCompanion(), store.effectiveProfile.prefersHealthKit {
                                Task { await healthKit.deleteWaterIntake(entryID: entry.id) }
                            }
                            level = store.companion?.remainingML ?? 0
                            feedback = "Bottle action undone."
                        }.disabled(bottle.undo == nil)
                        Button("Stop tracking bottle", role: .destructive) { confirmStop = true }
                    } footer: { Text("Undo restores the previous water level and removes only that action’s drink, even after midnight. Stopping keeps drinks already logged.") }
                    if !feedback.isEmpty { Text(feedback).accessibilityAddTraits(.updatesFrequently) }
                } else {
                    Section {
                        Text("Log what’s left, not every sip.").font(.headline)
                        Text("Set your water bottle’s capacity once. Check its remaining level to log only what you drank. Refills and discarded or shared water add no intake.")
                        TextField("Capacity in millilitres", value: $capacity, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Bottle capacity in millilitres")
                        LabeledContent("Capacity", value: amount(capacity))
                        Slider(value: $capacity, in: 100...5000, step: 50).accessibilityLabel("Bottle capacity in millilitres")
                        Button("Start with a full bottle") {
                            store.startCompanion(capacityML: capacity)
                            level = capacity
                        }.disabled(!capacity.isFinite || !(100...5000).contains(capacity))
                    } footer: { Text("Optional · one active bottle · saved on this device. All quantities are estimates. You can adjust the initial level without logging a drink.") }
                }
            }
            .navigationTitle("Bottle Companion")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Stop tracking this bottle?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stop tracking", role: .destructive) { store.stopCompanion() }
            } message: { Text("Already logged drinks stay in your diary. The estimated water level and bottle undo will be cleared.") }
            .onAppear { level = store.companion?.remainingML ?? 0 }
        }
    }

    private func amount(_ ml: Double) -> String { Formatters.volumeString(ml: ml, unit: store.profile.unitSystem) }
    private func valid(_ b: BottleCompanion) -> Bool {
        switch mode {
        case .drink: return level < b.remainingML
        case .refill: return level > b.remainingML
        case .adjust: return level != b.remainingML
        }
    }
    private func explanation(_ b: BottleCompanion) -> String {
        switch mode {
        case .drink: return level <= b.remainingML ? "Log approximately \(amount(b.remainingML - level)) drunk." : "Water increased? Choose Top up."
        case .refill: return "Match the new level after adding water. No intake is logged."
        case .adjust: return "Match what remains after pouring away or sharing. No intake is logged."
        }
    }
    private func actionLabel(_ b: BottleCompanion) -> String {
        switch mode { case .drink: return "Log consumed water"; case .refill: return "Save top up"; case .adjust: return "Adjust without logging" }
    }
    private func commit(_ b: BottleCompanion) {
        let action: BottleCompanion.Action
        switch mode {
        case .drink: action = .checkpoint(level)
        case .refill: action = .topUp(level - b.remainingML)
        case .adjust: action = .adjust(level)
        }
        save(store.changeCompanion(action))
        level = store.companion?.remainingML ?? 0
        feedback = mode == .drink ? "Consumed water logged as an estimate." : "Water level saved. No intake added."
    }
    private func save(_ entry: HydrationEntry?) {
        guard let entry, store.effectiveProfile.prefersHealthKit else { return }
        Task { await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id) }
    }
}
