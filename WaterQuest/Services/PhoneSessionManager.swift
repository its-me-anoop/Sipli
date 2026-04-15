import Foundation
import WatchConnectivity

/// Bridges WCSession on the iPhone side.
///
/// Outgoing (iPhone → Watch):
///   • `PersistedStateBlob`    — full authoritative PersistedState
///
/// Incoming (Watch → iPhone):
///   • `NewWatchEntry`         — a new HydrationEntry to add
///   • `DeletedWatchEntryID`   — UUID string of an entry to delete
///   • `SyncRequest`           — Watch asking for a full state push
@MainActor
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    // Outgoing key (iPhone → Watch)
    private let stateKey = "PersistedStateBlob"

    // Incoming keys (Watch → iPhone) — must match WatchSessionManager constants
    private let newEntryKey    = "NewWatchEntry"
    private let deletedIDKey   = "DeletedWatchEntryID"
    private let syncRequestKey = "SyncRequest"

    weak var store: HydrationStore?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Push full state to Watch. Called after every iPhone-side change.
    func sendState(_ state: PersistedState) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        // transferUserInfo is queued and delivered even if Watch is not reachable.
        WCSession.default.transferUserInfo([stateKey: data])
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Receives Watch messages delivered via transferUserInfo (background).
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        handleWatchMessage(userInfo)
    }

    /// Receives Watch messages delivered via sendMessage (immediate, Watch in foreground).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        handleWatchMessage(message)
    }

    nonisolated private func handleWatchMessage(_ dict: [String: Any]) {
        // New entry logged on Watch
        if let entryData = dict[newEntryKey] as? Data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let entry = try? decoder.decode(HydrationEntry.self, from: entryData) {
                Task { @MainActor in
                    self.store?.addWatchEntry(entry)
                }
            }
        }

        // Entry deleted on Watch
        if let idString = dict[deletedIDKey] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in
                self.store?.deleteEntry(byID: id)
            }
        }

        // Watch requesting a full state push (e.g. app foregrounded)
        if dict[syncRequestKey] != nil {
            Task { @MainActor in
                self.store?.pushStateToWatch()
            }
        }
    }
}
