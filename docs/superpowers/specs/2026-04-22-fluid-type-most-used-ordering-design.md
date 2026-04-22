# Fluid Type Most-Used Ordering — Design

**Status:** Approved
**Date:** 2026-04-22
**Related code:** `WaterQuest/Views/AddIntakeView.swift`, `WaterQuest/Services/HydrationStore.swift`, `WaterQuest/Models/FluidType.swift`

## Problem

The iOS "Log Intake" picker iterates `FluidType.allCases` in enum declaration order — `water`, `sparklingWater`, `coconutWater`, etc. A user who logs coffee 200 times has to scroll past sparkling water, coconut water, and eight teas every single time.

The Watch picker (`WatchHydrationStore.topFluidTypes`) already ranks by usage, capped at 6, so behavior is inconsistent across devices.

## Goal

Surface the user's most-used fluid types at the front of the iOS picker so the common case is a zero-scroll tap.

## Non-goals

- No change to the Watch picker (its 6-item cap suits the small screen).
- No reorder animation when counts change mid-session.
- No "Recent" vs. "All" section — keep a single horizontal list.
- No persistence of a pre-computed ranking; compute fresh from `entries`.
- No UX for pinning / favoriting specific types.
- No UI changes to the freemium (water-only) view.

## Design

### Algorithm

1. Group `HydrationStore.entries` by `fluidType`, count each bucket.
2. Sort descending by count.
3. Break ties (and include never-used types) by falling back to `FluidType.allCases` order.
4. Return all 36 types — most-used first, then the untouched enum tail.

### Surface

New computed property on `HydrationStore`:

```swift
var rankedFluidTypes: [FluidType] {
    let counts = Dictionary(grouping: entries, by: \.fluidType).mapValues(\.count)
    return FluidType.allCases.sorted { lhs, rhs in
        let l = counts[lhs] ?? 0
        let r = counts[rhs] ?? 0
        if l != r { return l > r }
        // Stable tie-break: enum declaration order.
        return FluidType.allCases.firstIndex(of: lhs)! < FluidType.allCases.firstIndex(of: rhs)!
    }
}
```

`AddIntakeView.swift:50` swaps `ForEach(FluidType.allCases)` → `ForEach(store.rankedFluidTypes)`.

### Edge cases

- **Zero entries (new user):** all types tie at 0 → enum order → `water` first. Matches current behavior.
- **Freemium (no `.fluidTypes` access):** picker shows the static water-only card; ordering is irrelevant.
- **Tie-break:** stable via enum order so ordering does not churn for users with mostly equal counts.
- **Performance:** O(n) group + O(k log k) sort with k = 36. Safe for tens of thousands of entries; no caching.

### Testing

Unit tests on `HydrationStore.rankedFluidTypes`:

1. Empty entries → `.water` first, order equals `FluidType.allCases`.
2. Entries weighted toward `.coffee` and `.greenTea` → `.coffee` first, then `.greenTea`, then enum-order tail.
3. Ties → stable enum order (e.g. 3 `.milk` + 3 `.juice` → `.milk` precedes `.juice`).

## Out of scope

- Animating row reorder.
- Watch behavior changes.
- Recency-weighted ranking.
- Persisting last-used type across app launches.
