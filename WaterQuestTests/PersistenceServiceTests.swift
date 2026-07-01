import XCTest
@testable import Sipli

/// Tests for `PersistenceService`: round-trip persistence, the corrupt-file
/// quarantine (a decode failure must never let the next save wipe real user
/// data), and the coordinated `update` read-modify-write used by App Intents
/// and widget/watch extensions.
///
/// Every test uses a unique filename so tests are independent of each other
/// and of the app host's real state file. Tests stick to the local-only /
/// update paths, which don't depend on iCloud KVS state.
final class PersistenceServiceTests: XCTestCase {

    private var createdFiles: [URL] = []

    override func tearDown() {
        let fm = FileManager.default
        for url in createdFiles {
            try? fm.removeItem(at: url)
            // Also remove any quarantine backups the test produced.
            let dir = url.deletingLastPathComponent()
            let prefix = url.lastPathComponent + ".corrupt-"
            if let siblings = try? fm.contentsOfDirectory(atPath: dir.path) {
                for name in siblings where name.hasPrefix(prefix) {
                    try? fm.removeItem(at: dir.appendingPathComponent(name))
                }
            }
        }
        createdFiles = []
        super.tearDown()
    }

    private func makeService(_ label: String = #function) -> PersistenceService {
        let service = PersistenceService(filename: "test-\(label)-\(UUID().uuidString).json")
        createdFiles.append(service.fileURL)
        return service
    }

    private func makeState(entryCount: Int) -> PersistedState {
        var state = PersistedState.default
        state.entries = (0..<entryCount).map { i in
            HydrationEntry(date: Date(timeIntervalSince1970: Double(1_000 + i)), volumeML: 250, source: .manual)
        }
        return state
    }

    private func corruptBackups(for service: PersistenceService) -> [String] {
        let dir = service.fileURL.deletingLastPathComponent()
        let prefix = service.fileURL.lastPathComponent + ".corrupt-"
        let siblings = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return siblings.filter { $0.hasPrefix(prefix) }
    }

    // MARK: - Round trip

    func test_saveLocalOnly_thenLoadLocalOnly_roundTrips() {
        let service = makeService()
        service.saveLocalOnly(makeState(entryCount: 3))

        let loaded = service.loadLocalOnly(PersistedState.self, fallback: .default)
        XCTAssertEqual(loaded.entries.count, 3)
        XCTAssertEqual(loaded.entries.first?.volumeML, 250)
    }

    func test_loadLocalOnly_missingFile_returnsFallback_withoutQuarantine() {
        let service = makeService()

        let loaded = service.loadLocalOnly(PersistedState.self, fallback: makeState(entryCount: 1))
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertTrue(corruptBackups(for: service).isEmpty, "no backup should be created when no file exists")
    }

    // MARK: - Corrupt-file quarantine

    func test_loadLocalOnly_corruptFile_returnsFallback_andQuarantinesOriginalBytes() throws {
        let service = makeService()
        let garbage = Data("not json {{{".utf8)
        try FileManager.default.createDirectory(
            at: service.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try garbage.write(to: service.fileURL)

        let loaded = service.loadLocalOnly(PersistedState.self, fallback: .default)

        XCTAssertTrue(loaded.entries.isEmpty, "fallback expected for unreadable data")
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.fileURL.path),
                       "unreadable file must be moved aside, not left to be overwritten")
        let backups = corruptBackups(for: service)
        XCTAssertEqual(backups.count, 1, "exactly one quarantine backup expected")
        let backupURL = service.fileURL.deletingLastPathComponent().appendingPathComponent(backups[0])
        XCTAssertEqual(try Data(contentsOf: backupURL), garbage, "backup must preserve the original bytes")
    }

    func test_saveAfterQuarantine_doesNotTouchBackup() throws {
        let service = makeService()
        let garbage = Data("]]] broken".utf8)
        try FileManager.default.createDirectory(
            at: service.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try garbage.write(to: service.fileURL)

        _ = service.loadLocalOnly(PersistedState.self, fallback: .default)
        service.saveLocalOnly(makeState(entryCount: 2))

        let backups = corruptBackups(for: service)
        XCTAssertEqual(backups.count, 1)
        let backupURL = service.fileURL.deletingLastPathComponent().appendingPathComponent(backups[0])
        XCTAssertEqual(try Data(contentsOf: backupURL), garbage)
        XCTAssertEqual(service.loadLocalOnly(PersistedState.self, fallback: .default).entries.count, 2)
    }

    // MARK: - Coordinated update

    func test_update_appliesTransform_andPersists() {
        let service = makeService()
        service.saveLocalOnly(makeState(entryCount: 1))

        let result = service.update(PersistedState.self, fallback: .default) { state in
            state.entries.append(
                HydrationEntry(date: Date(), volumeML: 500, source: .manual, fluidType: .coffee)
            )
        }

        XCTAssertEqual(result.entries.count, 2)
        let reloaded = service.loadLocalOnly(PersistedState.self, fallback: .default)
        XCTAssertEqual(reloaded.entries.count, 2)
        XCTAssertEqual(reloaded.entries.last?.fluidType, .coffee)
    }

    func test_update_missingFile_startsFromFallback() {
        let service = makeService()

        let result = service.update(PersistedState.self, fallback: makeState(entryCount: 1)) { state in
            state.entries.append(HydrationEntry(date: Date(), volumeML: 100, source: .manual))
        }

        XCTAssertEqual(result.entries.count, 2)
    }

    func test_update_concurrentWriters_loseNoEntries() async {
        let filename = "test-concurrent-\(UUID().uuidString).json"
        // Two service instances over the same file simulate two processes
        // (widget + app) mutating shared state concurrently.
        let serviceA = PersistenceService(filename: filename)
        let serviceB = PersistenceService(filename: filename)
        createdFiles.append(serviceA.fileURL)
        serviceA.saveLocalOnly(PersistedState.default)

        let perWriter = 20
        await withTaskGroup(of: Void.self) { group in
            for service in [serviceA, serviceB] {
                group.addTask {
                    for _ in 0..<perWriter {
                        service.update(PersistedState.self, fallback: .default) { state in
                            state.entries.append(
                                HydrationEntry(date: Date(), volumeML: 250, source: .manual)
                            )
                        }
                    }
                }
            }
        }

        let final = serviceA.loadLocalOnly(PersistedState.self, fallback: .default)
        XCTAssertEqual(final.entries.count, perWriter * 2,
                       "coordinated updates must not lose concurrent writes")
    }
}
