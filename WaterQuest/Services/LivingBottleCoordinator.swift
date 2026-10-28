import Foundation
import Combine

@MainActor
final class LivingBottleCoordinator: ObservableObject {
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let purpose: BottleMessagePurpose
        let expiresAt: Date
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    }
    @Published private(set) var snapshot: LivingInsightSnapshot?
    @Published private(set) var wording = ""
    @Published private(set) var notice: Notice?
    @Published private(set) var pulseID = UUID()
    @Published private(set) var onDeviceWording = false
    private var policy: BottleFeedbackPolicy
    private let defaults: UserDefaults
    private let key = "sipli.livingBottle.feedback.v1"
    private var pending: Notice?
    private var welcomePending = true
    private var baselineIDs: Set<UUID>?
    private var generation: Task<Void, Never>?
    private var revision = UUID()
    private var lastGeneration: Date?
    private let toneGenerator: @MainActor (String) async -> BottleTone?
    @Published var entryFlowActive = false

    static var feedbackDefaults: UserDefaults {
#if DEBUG && targetEnvironment(simulator)
        if let id = ProcessInfo.processInfo.environment["SIPLI_LIVING_UI_NAMESPACE"], UUID(uuidString: id) != nil {
            return UserDefaults(suiteName: "living-ui-" + id)!
        }
#endif
        return .standard
    }
    init(defaults: UserDefaults? = nil, toneGenerator: (@MainActor (String) async -> BottleTone?)? = nil) {
        let defaults = defaults ?? Self.feedbackDefaults
        self.defaults = defaults
        var generator = toneGenerator ?? { await Self.generateTone(context: $0) }
#if DEBUG && targetEnvironment(simulator)
        // Exercise both presentation paths without requiring simulator model assets.
        if UUID(uuidString: ProcessInfo.processInfo.environment["SIPLI_LIVING_UI_NAMESPACE"] ?? "") != nil,
           let response = ProcessInfo.processInfo.environment["SIPLI_LIVING_UI_RESPONSE"] {
            if let tone = BottleTone(rawValue: response) { generator = { _ in tone } }
            else if response == "unavailable" { generator = { _ in nil } }
        }
#endif
        self.toneGenerator = generator
        policy = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(BottleFeedbackPolicy.self, from: $0) } ?? BottleFeedbackPolicy()
    }
    func update(_ next: LivingInsightSnapshot, now: Date, canPresent: Bool, useAI: Bool) {
        let changed = next != snapshot
        let ids = Set(next.entries.map(\.id))
        if let baselineIDs {
            let additions = next.entries.filter { !baselineIDs.contains($0.id) }.sorted { $0.date < $1.date }
            for entry in additions {
                if policy.acknowledge(entry, snapshot: next, now: now) {
                    pending = Notice(text: BottleCopy.text(tone: .warm, purpose: .logged, snapshot: next), purpose: .logged, expiresAt: now.addingTimeInterval(60))
                }
            }
            // An undo/deletion invalidates a queued acknowledgement for an entry no longer present.
            if !baselineIDs.subtracting(ids).isEmpty {
                pending = nil
                if notice?.purpose == .logged { notice = nil }
            }
        }
        baselineIDs = ids
        snapshot = next
        if changed {
            revision = UUID(); generation?.cancel()
            wording = next.fallback; onDeviceWording = false
        }
        // Never keep old copy on screen while fresh facts are already shown.
        if useAI, !onDeviceWording, now.timeIntervalSince(lastGeneration ?? .distantPast) >= 300 {
            lastGeneration = now
            let token = revision
            generation = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                let tone = await self?.toneGenerator(next.modelContext)
                guard let self, !Task.isCancelled, self.revision == token, self.snapshot == next else { return }
                if let tone {
                    self.wording = BottleCopy.text(tone: tone, purpose: .insight, snapshot: next)
                    self.onDeviceWording = true
                }
            }
        }
        present(now: now, allowed: canPresent)
        persist()
    }
    func present(now: Date, allowed: Bool) {
        guard allowed && !entryFlowActive else { notice = nil; return }
        if let notice, notice.expiresAt <= now { self.notice = nil }
        if let pending {
            self.pending = nil
            guard pending.expiresAt > now else { return }
            notice = Notice(text: pending.text, purpose: pending.purpose, expiresAt: now.addingTimeInterval(4))
            welcomePending = false
            policy.lastAcknowledgement = now
            pulseID = UUID()
            persist()
            return
        }
        guard notice == nil, welcomePending, let snapshot else { return }
        welcomePending = false
        guard policy.welcomes(snapshot: snapshot, now: now) else { return }
        notice = Notice(text: BottleCopy.text(tone: .warm, purpose: .returning, snapshot: snapshot), purpose: .returning, expiresAt: now.addingTimeInterval(20))
        policy.lastWelcome = now; persist()
    }
    func dismiss(now: Date = Date()) {
        if notice?.purpose == .returning { policy.snoozedUntil = now.addingTimeInterval(24 * 60 * 60) }
        notice = nil; pending = nil; persist()
    }
    func background() {
        generation?.cancel(); revision = UUID(); notice = nil; pending = nil; welcomePending = true
    }
    func expire(_ id: UUID) { if notice?.id == id { notice = nil } }
    private func persist() { if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: key) } }
    static var isModelReady: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SipliIntelligence.shared.isReady }
#endif
        return false
    }
    static func generateTone(context: String) async -> BottleTone? {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *), SipliIntelligence.shared.isReady {
            return await SipliIntelligence.shared.bottleTone(context: context)
        }
#endif
        return nil
    }
}
