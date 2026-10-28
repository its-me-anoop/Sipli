import Foundation

/// A real water bottle, independent of the daily goal. Values are estimates in mL.
struct BottleCompanion: Codable, Equatable {
    struct Undo: Codable, Equatable {
        var remainingML: Double
        var entryID: UUID?
    }
    let capacityML: Double
    private(set) var remainingML: Double
    private(set) var undo: Undo?
    // Write-ahead receipt: replaying after a process interruption uses the same entry ID.
    var pendingEntry: HydrationEntry?

    init?(capacityML: Double) {
        guard capacityML.isFinite, (100...5000).contains(capacityML) else { return nil }
        self.capacityML = capacityML
        self.remainingML = capacityML
    }

    enum Action { case checkpoint(Double), topUp(Double), adjust(Double), finish }

    @discardableResult
    mutating func apply(_ action: Action, at date: Date = Date()) -> HydrationEntry? {
        let next: Double
        let consumed: Double
        switch action {
        case .checkpoint(let level):
            guard level.isFinite, level >= 0, level <= remainingML else { return nil }
            next = level; consumed = remainingML - level
        case .topUp(let amount):
            guard amount.isFinite, amount > 0, amount <= capacityML - remainingML else { return nil }
            next = remainingML + amount; consumed = 0
        case .adjust(let level):
            guard level.isFinite, level >= 0, level <= capacityML else { return nil }
            next = level; consumed = 0
        case .finish:
            next = 0; consumed = remainingML
        }
        guard next != remainingML else { return nil }
        let entry = consumed > 0 ? HydrationEntry(date: date, volumeML: consumed, source: .manual,
                                                note: "Bottle Companion · estimated") : nil
        undo = Undo(remainingML: remainingML, entryID: entry?.id)
        remainingML = next
        pendingEntry = entry
        return entry
    }

    mutating func restore() -> UUID? {
        guard let previous = undo else { return nil }
        remainingML = previous.remainingML
        undo = nil
        pendingEntry = nil
        return previous.entryID
    }

    static let storageKey = "sipli.bottleCompanion.v1"
    static func load(defaults: UserDefaults = .standard) -> Self? {
        guard let data = defaults.data(forKey: storageKey),
              let bottle = try? JSONDecoder().decode(Self.self, from: data),
              bottle.capacityML.isFinite, (100...5000).contains(bottle.capacityML),
              bottle.remainingML.isFinite, (0...bottle.capacityML).contains(bottle.remainingML) else { return nil }
        return bottle
    }
    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

extension BottleCompanion {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.capacityML == rhs.capacityML && lhs.remainingML == rhs.remainingML && lhs.undo == rhs.undo && lhs.pendingEntry == rhs.pendingEntry
    }
}
