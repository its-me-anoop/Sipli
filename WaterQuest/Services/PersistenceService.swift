import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    static let appGroupID = "group.com.waterquest.hydration"

    private let url: URL
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

        self.url = directory.appendingPathComponent(filename)

        Self.migrateIfNeeded(to: self.url, filename: filename)
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
        let localData = try? Data(contentsOf: url)
        let data = resolveNewestStateData(localData: localData) ?? localData
        guard let data else { return fallback }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(value)
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic])
            syncToICloud(data)
        } catch {
            #if DEBUG
            print("Failed to save Sipli state: \(error)")
            #endif
        }
    }

    func setRemoteDataChangeHandler(_ handler: @escaping (Data) -> Void) {
        onRemoteDataChanged = handler
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

    private func syncToICloud(_ data: Data) {
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
        do {
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try payload.blob.write(to: url, options: [.atomic])
            setLocalUpdatedAt(payload.updatedAt)
        } catch {
            #if DEBUG
            print("Failed to persist iCloud state locally: \(error)")
            #endif
        }
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
