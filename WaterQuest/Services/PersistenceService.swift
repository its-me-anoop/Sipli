import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    static let appGroupID = "group.com.waterquest.hydration"

    /// Internal (not private) so tests can write fixture bytes directly.
    let fileURL: URL
    private let keyValueStore = NSUbiquitousKeyValueStore.default
    private let iCloudStateKey = "WaterQuestPersistedStatePayload"
    private let localUpdatedAtKey = "WaterQuestStateLocalUpdatedAt"
    private var onRemoteDataChanged: ((Data) -> Void)?
    private var kvStoreObserver: NSObjectProtocol?

    private struct SyncedPayload: Codable {
        let updatedAt: Date
        let blob: Data
    }

    init(filename: String = "WaterQuestState.json") {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PersistenceService.appGroupID
        )
        let directory = groupURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.fileURL = directory.appendingPathComponent(filename)

        Self.migrateIfNeeded(to: self.fileURL, filename: filename)
        keyValueStore.synchronize()

        kvStoreObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: keyValueStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleKVSChange(notification)
        }
    }

    deinit {
        if let kvStoreObserver {
            NotificationCenter.default.removeObserver(kvStoreObserver)
        }
    }

    func load<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        // boundary: synchronous load is acceptable here, called once at scene init
        let localData = Self.coordinatedRead(at: fileURL)
        let data = resolveNewestStateData(localData: localData) ?? localData
        guard let data else { return fallback }
        return decodeOrQuarantine(type, from: data, fallback: fallback)
    }

    /// Async variant that reads the file off the calling actor.
    /// Prefer this at non-init call sites where blocking is not acceptable.
    func loadAsync<T: Decodable>(_ type: T.Type, fallback: T) async -> T {
        let fileURL = fileURL
        let iCloudKey = iCloudStateKey
        let kvStore = keyValueStore

        return await Task.detached(priority: .userInitiated) {
            let localData = Self.coordinatedRead(at: fileURL)

            // Resolve against iCloud KVS without touching MainActor state.
            var resolved: Data? = localData
            if let payloadData = kvStore.data(forKey: iCloudKey) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let payload = try? decoder.decode(SyncedPayload.self, from: payloadData) {
                    let localTimestamp = UserDefaults.standard.object(forKey: "WaterQuestStateLocalUpdatedAt") as? Date ?? .distantPast
                    if payload.updatedAt > localTimestamp {
                        resolved = payload.blob
                    }
                }
            }

            guard let data = resolved else { return fallback }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
            Self.quarantineUnreadableFile(at: fileURL)
            return fallback
        }.value
    }

    func save<T: Encodable>(_ value: T) {
        guard let data = encodeValue(value) else { return }
        Self.coordinatedWrite(data, to: fileURL)
        syncToICloud(data)
    }

    /// Saves to the local file only — intentionally skips iCloud KVS sync.
    /// Used by the watchOS companion to avoid conflicting with iPhone's KVS writes.
    func saveLocalOnly<T: Encodable>(_ value: T) {
        guard let data = encodeValue(value) else { return }
        Self.coordinatedWrite(data, to: fileURL)
    }

    /// Loads from the local file only — does not compare against iCloud KVS.
    /// Used by the watchOS companion for cold-start display while WCSession delivers.
    func loadLocalOnly<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        guard let data = Self.coordinatedRead(at: fileURL) else { return fallback }
        return decodeOrQuarantine(type, from: data, fallback: fallback)
    }

    /// Coordinated read-modify-write. This is the safe entry point for App
    /// Intents and widget/watch extensions: the app, widget, and watch
    /// processes all mutate the same app-group file, and separate
    /// load()/save() calls can interleave across processes and lose an
    /// update. The whole read→transform→write runs under one file
    /// coordination claim, so concurrent writers queue instead of clobbering.
    @discardableResult
    func update<T: Codable>(_ type: T.Type, fallback: T, transform: (inout T) -> Void) -> T {
        var result = fallback
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { _ in
            result = performUpdate(type, fallback: fallback, transform: transform)
        }
        if coordinationError != nil {
            // Coordination denied (shouldn't happen for app-group files) —
            // degrade to the uncoordinated path rather than dropping the log.
            result = performUpdate(type, fallback: fallback, transform: transform)
        }
        syncToICloud(encodeValue(result))
        return result
    }

    /// Uncoordinated read→transform→write. Must only run inside an active
    /// coordination block (or as the fallback when coordination fails) —
    /// taking a second claim on the same file from the same thread deadlocks.
    private func performUpdate<T: Codable>(_ type: T.Type, fallback: T, transform: (inout T) -> Void) -> T {
        let localData = try? Data(contentsOf: fileURL)
        let data = resolveNewestStateData(localData: localData) ?? localData
        var value: T
        if let data {
            value = decodeOrQuarantine(type, from: data, fallback: fallback)
        } else {
            value = fallback
        }
        transform(&value)
        if let encoded = encodeValue(value) {
            Self.writeRaw(encoded, to: fileURL)
        }
        return value
    }

    func setRemoteDataChangeHandler(_ handler: @escaping (Data) -> Void) {
        onRemoteDataChanged = handler
    }

    // MARK: - Decode failure quarantine

    /// Decodes `data`; on failure moves the unreadable state file aside as
    /// `<filename>.corrupt-<timestamp>` before returning the fallback.
    /// Without the quarantine, returning an empty fallback means the very
    /// next save() permanently overwrites the user's real history — the
    /// backup keeps the bytes recoverable and distinguishes "fresh install"
    /// from "file exists but can't be read".
    private func decodeOrQuarantine<T: Decodable>(_ type: T.Type, from data: Data, fallback: T) -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }
        Self.quarantineUnreadableFile(at: fileURL)
        return fallback
    }

    private static func quarantineUnreadableFile(at url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = url.appendingPathExtension("corrupt-\(stamp)")
        try? fm.moveItem(at: url, to: backupURL)
        #if DEBUG
        print("Quarantined unreadable Sipli state to \(backupURL.lastPathComponent)")
        #endif
    }

    // MARK: - Coordinated file primitives

    /// All processes (app, widget, watch) go through NSFileCoordinator for
    /// the shared file so writes are serialized instead of racing. Atomic
    /// writes alone only prevent torn files, not lost updates.
    private static func coordinatedRead(at url: URL) -> Data? {
        var data: Data?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        if coordinationError != nil {
            data = try? Data(contentsOf: url)
        }
        return data
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) {
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            writeRaw(data, to: writeURL)
        }
        if coordinationError != nil {
            writeRaw(data, to: url)
        }
    }

    private static func writeRaw(_ data: Data, to url: URL) {
        do {
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to save Sipli state: \(error)")
            #endif
        }
    }

    private func encodeValue<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(value)
    }

    private func handleKVSChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
            reasonValue == NSUbiquitousKeyValueStoreServerChange || reasonValue == NSUbiquitousKeyValueStoreInitialSyncChange
        else { return }

        guard
            let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
            changedKeys.contains(iCloudStateKey)
        else { return }

        guard
            let payloadData = keyValueStore.data(forKey: iCloudStateKey),
            let payload = decodePayload(payloadData),
            payload.updatedAt > localUpdatedAt
        else { return }

        persistRemoteBlobLocally(payload)
        onRemoteDataChanged?(payload.blob)
    }

    private var localUpdatedAt: Date {
        UserDefaults.standard.object(forKey: localUpdatedAtKey) as? Date ?? .distantPast
    }

    private func setLocalUpdatedAt(_ date: Date) {
        UserDefaults.standard.set(date, forKey: localUpdatedAtKey)
    }

    private func syncToICloud(_ data: Data?) {
        guard let data else { return }
        let payload = SyncedPayload(updatedAt: Date(), blob: data)
        guard let encodedPayload = encodePayload(payload) else { return }
        setLocalUpdatedAt(payload.updatedAt)
        keyValueStore.set(encodedPayload, forKey: iCloudStateKey)
        keyValueStore.synchronize()
    }

    private func resolveNewestStateData(localData: Data?) -> Data? {
        guard
            let payloadData = keyValueStore.data(forKey: iCloudStateKey),
            let payload = decodePayload(payloadData)
        else {
            return localData
        }

        guard payload.updatedAt > localUpdatedAt else {
            return localData
        }

        persistRemoteBlobLocally(payload)
        return payload.blob
    }

    private func persistRemoteBlobLocally(_ payload: SyncedPayload) {
        Self.writeRaw(payload.blob, to: fileURL)
        setLocalUpdatedAt(payload.updatedAt)
    }

    private func encodePayload(_ payload: SyncedPayload) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    private func decodePayload(_ data: Data) -> SyncedPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SyncedPayload.self, from: data)
    }

    private static func migrateIfNeeded(to newURL: URL, filename: String) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }

        guard let oldDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldURL = oldDir.appendingPathComponent(filename)
        guard fm.fileExists(atPath: oldURL.path) else { return }

        do {
            try fm.moveItem(at: oldURL, to: newURL)
        } catch {
            #if DEBUG
            print("Migration failed, copying instead: \(error)")
            #endif
            try? fm.copyItem(at: oldURL, to: newURL)
        }
    }
}
