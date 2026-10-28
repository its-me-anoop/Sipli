import XCTest
@testable import Sipli

final class BottleCompanionTests: XCTestCase {
    @MainActor
    func testStoreIntegrationPreservesOtherEntriesAndUndoAcrossRelaunch() throws {
        let namespace = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: namespace))
        let persistence = PersistenceService(filename: "test-companion-\(namespace).json")
        defer {
            defaults.removePersistentDomain(forName: namespace)
            try? FileManager.default.removeItem(at: persistence.fileURL)
        }
        var store = HydrationStore(persistence: persistence, companionDefaults: defaults)
        store.startCompanion(capacityML: 750)
        let first = try XCTUnwrap(store.changeCompanion(.checkpoint(375)))
        XCTAssertEqual(first.volumeML, 375)
        XCTAssertEqual(store.entries.filter { $0.id == first.id }.count, 1)
        XCTAssertNil(store.changeCompanion(.checkpoint(375)))
        let other = HydrationEntry(date: Date(), volumeML: 200, source: .manual)
        // Simulate a Siri/widget write while Home holds a stale in-memory snapshot.
        persistence.update(PersistedState.self, fallback: .default) { $0.entries.append(other) }
        XCTAssertNil(store.changeCompanion(.topUp(375)))
        XCTAssertEqual(store.companion?.remainingML, 750)
        let beforeFinish = store.todayTotalML
        let finished = try XCTUnwrap(store.changeCompanion(.finish))
        XCTAssertEqual(store.todayTotalML, beforeFinish + 750)
        store = HydrationStore(persistence: persistence, companionDefaults: defaults)
        XCTAssertEqual(store.companion?.remainingML, 0)
        XCTAssertEqual(store.undoCompanion()?.id, finished.id)
        XCTAssertEqual(store.todayTotalML, beforeFinish)
        XCTAssertTrue(store.entries.contains { $0.id == other.id })
        XCTAssertEqual(store.companion?.remainingML, 750)
        store.stopCompanion()
        XCTAssertNil(BottleCompanion.load(defaults: defaults))
        XCTAssertEqual(store.todayTotalML, beforeFinish)
    }

    @MainActor
    func testPendingReceiptRecoveryIsIdempotentAndUndoDoesNotSubtractFromNewDay() throws {
        let namespace = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: namespace))
        let persistence = PersistenceService(filename: "test-companion-recovery-\(namespace).json")
        defer {
            defaults.removePersistentDomain(forName: namespace)
            try? FileManager.default.removeItem(at: persistence.fileURL)
        }
        var bottle = try XCTUnwrap(BottleCompanion(capacityML: 750))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = try XCTUnwrap(bottle.apply(.checkpoint(375), at: yesterday))
        bottle.save(defaults: defaults)
        var fixture = PersistedState.default
        fixture.entries = [entry] // Process stopped after intake commit, before receipt clear.
        persistence.saveLocalOnly(fixture)
        let store = HydrationStore(persistence: persistence, companionDefaults: defaults)
        XCTAssertEqual(store.entries.filter { $0.id == entry.id }.count, 1)
        XCTAssertNil(store.companion?.pendingEntry)
        let today = store.addIntake(amount: 200, unitSystem: .metric)
        XCTAssertEqual(store.todayTotalML, 200)
        XCTAssertEqual(store.undoCompanion()?.id, entry.id)
        XCTAssertEqual(store.todayTotalML, 200)
        XCTAssertTrue(store.entries.contains { $0.id == today.id })
        XCTAssertEqual(store.companion?.remainingML, 750)
    }

    func testCheckpointsNeverDoubleCount() throws {
        var b = try XCTUnwrap(BottleCompanion(capacityML: 750))
        XCTAssertEqual(b.apply(.checkpoint(375))?.volumeML, 375)
        XCTAssertNil(b.apply(.checkpoint(375)))
        XCTAssertNil(b.apply(.checkpoint(500)))
        XCTAssertEqual(b.apply(.finish)?.volumeML, 375)
        XCTAssertNil(b.apply(.finish))
        XCTAssertEqual(b.remainingML, 0)
    }
    func testTopUpDiscardShareAndUndo() throws {
        var b = try XCTUnwrap(BottleCompanion(capacityML: 750))
        _ = b.apply(.checkpoint(250))
        XCTAssertNil(b.apply(.topUp(500)))
        XCTAssertEqual(b.remainingML, 750)
        XCTAssertNil(b.restore())
        XCTAssertEqual(b.remainingML, 250)
        XCTAssertNil(b.apply(.adjust(100)))
        XCTAssertEqual(b.remainingML, 100)
        XCTAssertNil(b.restore())
        XCTAssertEqual(b.remainingML, 250)
        let entry = try XCTUnwrap(b.apply(.finish))
        XCTAssertEqual(b.restore(), entry.id)
        XCTAssertEqual(b.remainingML, 250)
        XCTAssertNil(b.restore())
    }
    func testInvalidAmountsDoNotMutateBottle() throws {
        XCTAssertNil(BottleCompanion(capacityML: .nan))
        XCTAssertNil(BottleCompanion(capacityML: 0))
        var b = try XCTUnwrap(BottleCompanion(capacityML: 750))
        for action in [BottleCompanion.Action.checkpoint(-1), .checkpoint(.nan), .topUp(1), .adjust(751), .adjust(.infinity)] {
            let before = b
            XCTAssertNil(b.apply(action))
            XCTAssertEqual(b, before)
        }
    }
    func testPersistenceReceiptAndUndoSurviveRelaunchAndMidnight() throws {
        let suite = "BottleCompanionTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var b = try XCTUnwrap(BottleCompanion(capacityML: 750))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = try XCTUnwrap(b.apply(.checkpoint(500), at: yesterday))
        b.save(defaults: defaults)
        var restored = try XCTUnwrap(BottleCompanion.load(defaults: defaults))
        XCTAssertEqual(restored, b)
        XCTAssertEqual(restored.pendingEntry?.id, entry.id)
        XCTAssertTrue(Calendar.current.isDate(restored.pendingEntry!.date, inSameDayAs: yesterday))
        restored.pendingEntry = nil
        restored.save(defaults: defaults)
        restored = try XCTUnwrap(BottleCompanion.load(defaults: defaults))
        XCTAssertEqual(restored.remainingML, 500) // No daily-goal reset.
        XCTAssertEqual(restored.restore(), entry.id)
        XCTAssertEqual(restored.remainingML, 750)
    }
}
