import Foundation

/// Merges two sets of hydration entries by `id`. Used wherever the in-memory
/// store reconciles with a freshly-loaded `PersistedState` — iCloud remote
/// changes and the foreground reload that picks up entries written by App
/// Intents / widgets.
///
/// Conflict rule: `incoming` (the just-loaded source of truth) wins on shared
/// ids; entries that exist only locally are preserved (they were logged since
/// the last save and aren't in the loaded snapshot yet). Result is sorted by
/// date ascending. Ids in `removed` are dropped from both sides, so a delete
/// made elsewhere (e.g. a Siri undo) isn't resurrected by a stale local copy.
enum HydrationMerge {
    static func mergeByID(
        local: [HydrationEntry],
        incoming: [HydrationEntry],
        removed: Set<UUID> = []
    ) -> [HydrationEntry] {
        var byID = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        for entry in local where byID[entry.id] == nil {
            byID[entry.id] = entry
        }
        for id in removed { byID[id] = nil }
        return byID.values.sorted { $0.date < $1.date }
    }
}
