import Foundation
import WatchConnectivity

/// Bridges WCSession on the Watch side.
/// Sends the full persisted state to the iPhone whenever data changes, and
/// delivers iPhone-originated states to WatchHydrationStore for merging.
@MainActor
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let stateKey = "PersistedStateBlob"
    weak var store: WatchHydrationStore?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call this after any local state change to push to the iPhone.
    func sendState(_ state: PersistedState) {
        guard WCSession.default.activationState == .activated else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        WCSession.default.transferUserInfo([stateKey: data])
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[stateKey] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let remoteState = try? decoder.decode(PersistedState.self, from: data) else { return }
        Task { @MainActor in
            self.store?.applyRemoteState(remoteState)
        }
    }
}
