import Foundation
import WatchConnectivity

/// Bridges WCSession on the iPhone side.
/// Sends the full persisted state to the Watch whenever data changes, and
/// delivers Watch-originated states to HydrationStore for merging.
@MainActor
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private let stateKey = "PersistedStateBlob"
    weak var store: HydrationStore?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call this after any local state change to push to the Watch.
    func sendState(_ state: PersistedState) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        // transferUserInfo is queued and delivered even if Watch is not currently reachable.
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

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[stateKey] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let remoteState = try? decoder.decode(PersistedState.self, from: data) else { return }
        // Fix 3: use mergeWatchState — Watch packets only contribute entries;
        // they must not overwrite iPhone-authoritative profile/weather/workout.
        Task { @MainActor in
            self.store?.mergeWatchState(remoteState)
        }
    }
}
