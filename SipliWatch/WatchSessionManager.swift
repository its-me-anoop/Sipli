import Foundation
import WatchConnectivity

/// Bridges WCSession on the Watch side.
///
/// Outgoing (Watch → iPhone):
///   • `NewWatchEntry`         — a new HydrationEntry logged on Watch
///   • `DeletedWatchEntryID`   — UUID string of an entry deleted on Watch
///   • `SyncRequest`           — ask iPhone to push its current full state
///
/// Incoming (iPhone → Watch):
///   • `PersistedStateBlob`    — full authoritative PersistedState from iPhone
@MainActor
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    // Outgoing keys (Watch → iPhone)
    let newEntryKey    = "NewWatchEntry"
    let deletedIDKey   = "DeletedWatchEntryID"
    let syncRequestKey = "SyncRequest"

    // Incoming key (iPhone → Watch)
    let stateKey = "PersistedStateBlob"

    weak var store: WatchHydrationStore?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Outgoing

    /// Send a new Watch-logged entry to iPhone for processing and persistence.
    func sendNewEntry(_ entry: HydrationEntry) {
        guard WCSession.default.activationState == .activated else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        WCSession.default.transferUserInfo([newEntryKey: data])
    }

    /// Notify iPhone that an entry was deleted on Watch.
    func sendDeletion(id: UUID) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([deletedIDKey: id.uuidString])
    }

    /// Ask iPhone to push its current full state.
    /// Uses sendMessage for immediate delivery when reachable, otherwise queues via transferUserInfo.
    func sendSyncRequest() {
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage([syncRequestKey: true], replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo([syncRequestKey: true])
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    /// Receives iPhone's full state pushed via transferUserInfo.
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        applyStateIfPresent(userInfo)
    }

    /// Receives iPhone's full state pushed via sendMessage (e.g. immediate push).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        applyStateIfPresent(message)
    }

    nonisolated private func applyStateIfPresent(_ dict: [String: Any]) {
        guard let data = dict[stateKey] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let remoteState = try? decoder.decode(PersistedState.self, from: data) else { return }
        Task { @MainActor in
            self.store?.applyRemoteState(remoteState)
        }
    }
}
