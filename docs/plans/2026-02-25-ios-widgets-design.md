# iOS Widgets Design — Sipli

**Date**: 2026-02-25

## Summary

Add Small, Medium, and Large home screen widgets to Sipli using WidgetKit. Widgets display hydration progress, daily goal, streak, and recent entries. Data is shared between the main app and widget extension via a JSON file in a shared App Group container.

## Decisions

- **Approach**: Shared JSON via App Groups (Approach A)
- **Sizes**: Small (2x2), Medium (4x2), Large (4x4). No Lock Screen widgets.
- **Quick-add**: Yes — deep link button opens the app to the add-intake screen
- **Visual style**: System default WidgetKit styling with lagoon blue accent for progress ring

## Data Sharing

**App Group**: `group.com.waterquest.hydration`

1. `PersistenceService` updated to use the shared App Group container
2. One-time migration moves `WaterQuestState.json` from Application Support to the shared container on first launch after update
3. Widget reads the shared JSON via a lightweight `WidgetDataProvider` (read-only, no @MainActor)
4. Entitlements added to both main app and widget extension targets

**Data the widget reads from JSON**:
- `entries` — filtered to today for totals and log display
- `profile` — for goal calculation (weight, activity level, custom goal, unit system)
- `lastWeather` / `lastWorkout` — for goal adjustments
- Goal recalculated using shared `GoalCalculator`

## Widget Content

### Small (2x2)
- Circular progress ring with percentage
- Current total / goal (e.g. "1,200 / 2,500 ml")
- Tap opens the app

### Medium (4x2)
- Left: progress ring with percentage
- Right: current total / goal, streak count, quick-add "+" button
- Quick-add deep links to add-intake screen

### Large (4x4)
- Top: progress ring + total / goal + streak
- Middle: last 4-5 log entries (time, fluid type icon, volume)
- Bottom: quick-add "+" button

## File Structure

```
SipliWidget/
├── SipliWidget.swift           -- @main entry point
├── SipliWidgetBundle.swift     -- WidgetBundle
├── WidgetDataProvider.swift    -- Reads shared JSON, calculates today's data
├── TimelineProvider.swift      -- WidgetKit timeline provider
├── Views/
│   ├── SmallWidgetView.swift
│   ├── MediumWidgetView.swift
│   └── LargeWidgetView.swift
└── Supporting/
    └── SipliWidget.entitlements
```

**Shared code** (both targets): `GoalCalculator.swift`, `HydrationEntry.swift`, `UserProfile.swift`, `FluidType.swift`, `GoalBreakdown.swift`, `UnitSystem.swift`, `WeatherSnapshot.swift`, `WorkoutSummary.swift`, `Formatters.swift`, `PersistenceService.swift`

## Timeline Refresh

- `.atEnd` policy with 15-minute intervals
- Main app calls `WidgetCenter.shared.reloadAllTimelines()` on every entry add/edit/delete

## Deep Linking

- URL scheme: `sipli://add-intake`
- Handled in `RootView` via `.onOpenURL`
- Opens AddIntakeView directly

## Visual Style

- Standard `containerBackground` with system material
- SF Symbols for fluid type icons
- System fonts with `.monospacedDigit()` for numbers
- `Theme.lagoon` for progress ring tint and accent text only
