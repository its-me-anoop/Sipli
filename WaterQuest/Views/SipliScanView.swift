import SwiftUI
import AVFoundation

struct SipliScanView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ScanDraft?
    @State private var image: UIImage?
    @State private var camera = false
    @State private var requestingCamera = false
    @State private var busy = false
    @State private var message: String?
    @State private var denied = false
    @State private var manual = false
    @State private var capacity = ""
    @State private var initialCapacityText = ""
    @State private var custom = ""
    @State private var portion: ScanDraft.Portion?
    @State private var drink: FluidType = .other
    @State private var work: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var gate = ScanLogGate()
    @State private var saved: HydrationEntry?
    @State private var didUndo = false
    @State private var healthWork: Task<Void, Never>?

    private var units: UnitSystem { store.profile.unitSystem }
    private var packageML: Double? {
        if capacity == initialCapacityText, let exact = draft?.packageML { return ScanDraft.validML(exact) }
        return ScanDraft.number(capacity).map { units.ml(from: $0) }.flatMap(ScanDraft.validML)
    }
    private var consumedML: Double? {
        ScanDraft.consumedML(portion: portion, packageML: packageML,
                             customML: ScanDraft.number(custom).map { units.ml(from: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                if let saved {
                    Section {
                        Label(didUndo ? "Drink undone" : "Drink logged", systemImage: didUndo ? "arrow.uturn.backward" : "checkmark.circle.fill")
                        Text(Formatters.volumeString(ml: saved.volumeML, unit: units) + " · " + saved.fluidType.displayName)
                        if !didUndo {
                            Button("Undo scanned drink") {
                                gate.undo { store.deleteEntry($0) }
                                didUndo = true
                                let pending = healthWork
                                healthWork = Task {
                                    await pending?.value
                                    if subscriptionManager.hasAccess(to: .healthKitSync), store.effectiveProfile.prefersHealthKit { await healthKit.deleteWaterIntake(entryID: saved.id) }
                                }
                            }
                        }
                        Button("Done") { dismiss() }
                    }
                } else if busy {
                    Section {
                        ProgressView("Reading your drink on this device…")
                        Button("Cancel analysis") { reset() }
                    } footer: { Text("Nothing is logged until you confirm. Photos aren’t saved or sent to a cloud model.") }
                } else if let draft {
                    confirmation(draft)
                } else {
                    Section {
                        Label("Snap your drink. Confirm. Log.", systemImage: "camera.viewfinder").font(.headline)
                        Text("Photograph the label and package size on a bottle or can. Then tell Sipli how much you drank.")
                        if ScanAnalyzer.isReady {
                            Text(ScanAnalyzer.capability).font(.footnote).foregroundStyle(.secondary)
                            Button("Take photo", systemImage: "camera") { Task { await openCamera() } }.disabled(requestingCamera)
                        } else {
                            Text("On-device AI isn’t available. Scan needs a supported language, a ready Apple Intelligence model and a compatible device.")
                        }
                        Button("Log manually") { manual = true }
                    } footer: { Text("Photos stay in memory for this scan and aren’t saved by Sipli. No cloud fallback. Unmarked glasses need an amount from you.") }
                    if let message {
                        Section {
                            Text(message).foregroundStyle(.secondary)
                            if denied {
                                Button("Open camera settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                }
                            }
                        }
                    }
#if DEBUG && targetEnvironment(simulator)
                    if isFixtureRun {
                        Section("UI test fixtures · no camera or model execution") {
                            Button("Use labelled water fixture") { applyFixture(unknown: false) }
                            Button("Use unmarked glass fixture") { applyFixture(unknown: true) }
                            Button("Simulate camera denial") { denied = true; message = "Camera access is off. Allow camera access in Settings, or log manually." }
                        }
                    }
#endif
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sipli Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { reset(); dismiss() } } }
            .fullScreenCover(isPresented: $camera) {
                ScanCamera { photo in
                    camera = false
                    guard let photo else { return }
                    analyze(photo)
                }.ignoresSafeArea()
            }
            .sheet(isPresented: $manual) {
                NavigationStack {
                    AddIntakeView()
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { manual = false } } }
                }.presentsPaywall()
            }
            .presentsPaywall()
            .onDisappear { work?.cancel(); image = nil }
        }
    }

    @ViewBuilder
    private func confirmation(_ draft: ScanDraft) -> some View {
        Section {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 150).accessibilityLabel("Photo of your drink label")
            }
            Text("Check the result").font(.headline)
            Text(draft.method).font(.footnote).foregroundStyle(.secondary)
            if draft.needsReview { Text("Some details are uncertain. Choose the drink and enter the amount you consumed.").foregroundStyle(.secondary) }
            Picker("Drink", selection: $drink) { ForEach(FluidType.allCases) { Text($0.displayName).tag($0) } }
            LabeledContent("Package size (\(units.volumeUnit))") {
                TextField("Unknown", text: $capacity).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .accessibilityLabel("Package size in \(units.volumeUnit)")
                    .accessibilityIdentifier("scanPackageSize")
            }
            Text(draft.evidence).font(.footnote).foregroundStyle(.secondary)
            if drink != .water && !subscriptionManager.hasAccess(to: .fluidTypes) {
                Text("As with manual logging, beverages other than water need Sipli Premium.")
                Button("Unlock beverages") { subscriptionManager.presentPaywall(for: .fluidTypes) }
            }
        } footer: { Text("Package size is not the amount you drank. Edit any result before logging.") }
        Section("How much did you drink?") {
            HStack {
                ForEach(ScanDraft.Portion.allCases, id: \.self) { choice in
                    Button {
                        portion = choice
                    } label: {
                        Label(choice.rawValue, systemImage: portion == choice ? "checkmark.circle.fill" : "circle")
                            .frame(minHeight: 44)
                            .foregroundStyle(choice != .custom && packageML == nil ? Color.secondary : (portion == choice ? Theme.lagoon : Theme.textPrimary))
                    }.disabled(choice != .custom && packageML == nil)
                    if choice != .custom { Spacer() }
                }
            }.buttonStyle(.borderless)
            if portion == .custom {
                LabeledContent("Amount drunk (\(units.volumeUnit))") {
                    TextField("Enter amount", text: $custom).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .accessibilityLabel("Amount consumed in \(units.volumeUnit)")
                        .accessibilityIdentifier("scanConsumedAmount")
                }
            }
            if let consumedML {
                LabeledContent("Will log", value: Formatters.volumeString(ml: consumedML, unit: units))
            } else {
                Text(portion == nil ? "Choose All, Half or Custom. Nothing has been logged." : "Enter a valid amount between 10 and 5,000 ml.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Log drink") { log() }
                .accessibilityIdentifier("Confirm scanned drink")
                .disabled(consumedML == nil || (drink != .water && !subscriptionManager.hasAccess(to: .fluidTypes)))
        }
        Section {
            Button("Retake photo") { reset(); Task { await openCamera() } }
            Button("Log manually instead") { reset(); manual = true }
        }
    }

    private func openCamera() async {
        guard !requestingCamera, !camera, !busy else { return }
        requestingCamera = true
        defer { requestingCamera = false }
        let token = requestID
        denied = false
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            message = "A camera isn’t available here. You can log manually."; return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .restricted {
            message = "Camera access is restricted on this device. You can log manually."; return
        }
        var allowed = status == .authorized
        if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        guard token == requestID, !Task.isCancelled else { return }
        if allowed { message = nil; camera = true }
        else { denied = true; message = "Camera access is off. Allow camera access in Settings, or log manually." }
    }

    private func analyze(_ photo: UIImage) {
        reset(); image = ScanAnalyzer.normalized(photo); busy = true
        let token = requestID
        work = Task {
            do {
                let result = try await ScanAnalyzer().analyze(photo)
                guard !Task.isCancelled, token == requestID else { return }
                accept(result)
            } catch {
                guard !Task.isCancelled, token == requestID else { return }
                message = (error as? ScanFailure)?.errorDescription ?? "On-device AI couldn’t finish. Retake the label or log manually."
                image = nil
            }
            busy = false
        }
    }
    private func accept(_ result: ScanDraft) {
        draft = result; drink = result.fluidType; portion = nil
        capacity = result.packageML.map { units.amount(fromML: $0).formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? ""
        initialCapacityText = capacity
    }
    private func reset() {
        work?.cancel(); work = nil; requestID = UUID(); image = nil; draft = nil
        busy = false; message = nil; denied = false; capacity = ""; initialCapacityText = ""; custom = ""; portion = nil
    }
    private func log() {
        guard saved == nil, drink == .water || subscriptionManager.hasAccess(to: .fluidTypes) else { return }
        let entry = gate.log(volumeML: consumedML, type: drink) { ml, type in
            store.reloadFromDisk()
            return store.addIntake(amount: ml, unitSystem: .metric, fluidType: type, note: "Sipli Scan · confirmed")
        }
        guard let entry else { return }
        saved = entry; image = nil
        if subscriptionManager.hasAccess(to: .healthKitSync), store.effectiveProfile.prefersHealthKit {
            healthWork = Task { await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id) }
        }
    }
#if DEBUG && targetEnvironment(simulator)
    private var isFixtureRun: Bool { UUID(uuidString: ProcessInfo.processInfo.environment["SIPLI_SCAN_UI_NAMESPACE"] ?? "") != nil }
    private func applyFixture(unknown: Bool) {
        reset()
        accept(ScanDraft(fluidType: .water, packageML: unknown ? nil : 500,
                         evidence: unknown ? "Package size not confirmed. Enter an amount yourself." : "WATER · 500 ml",
                         needsReview: unknown, method: "UI test fixture · model not executed"))
    }
#endif
}
