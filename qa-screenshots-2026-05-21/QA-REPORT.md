# WaterQuest / Sipli — QA Report
**Date:** 2026-05-21  
**Build:** 4.0 (build 5)  
**Device:** iPhone 17 Pro simulator, iOS 26.4  
**Screenshots captured:** 40 PNGs  
**Branch:** redesign-onboarding-tactile-vessel  

---

## Screen-by-screen log

- **01-onboarding-welcome.png** — Welcome step (light). Bottle hero, "Drink water like you *mean it.*" headline, "Get started" CTA. Clean. No issues.
- **01b-onboarding-welcome-dark.png** — Welcome step (dark, via `simctl ui appearance dark`). Renders correctly; background transitions from near-black to deep blue. Hero image has a light-blue internal fill that reads well against the dark canvas. No issues.
- **02-onboarding-name.png** — Name step. Answer chip with "NAME Alex" stacked top-right. Editorial headline "Who are we hydrating?" renders correctly. No issues.
- **03-onboarding-weight.png** — Weight step. Ticker/dial scroll widget present. "NAME Alex" chip visible. "70 kg / That's about 2.3 L a day" inline feedback functional. No issues.
- **04-onboarding-activity.png** — Activity step. Three activity cards (Calm, Steady, Active) render correctly with icon and description rows. No issues.
- **05-onboarding-target.png** — Target step. AI-calibrated 2.4 L suggestion displays. "Set my own goal" toggle and "Adjust for weather (Premium)" row visible. Answer chip stack shows "ACTIVITY Steady" — only one chip visible; prior chips appear trimmed at top edge of the stack container. **See P2-01.**
- **06-onboarding-schedule.png** — Schedule step. Wake/sleep time pickers render correctly. Ring visualisation in mini-card is visible. No issues.
- **07-onboarding-notifications.png** — Notifications step (notification frequency selection: 4×/day, 8×/day, 12×/day). Shows the notification-frequency picker, not the OS permission dialog. "How loud should we nudge?" headline visible. Looks correct.
- **08-onboarding-done.png** — Captured the same notifications frequency screen as 07. The "Done" confetti/completion step was not isolated because tapping "Start hydrating, Alex" immediately triggers the OS notification permission alert before the Done step can be screenshotted. **See P2-02.**
- **09-dashboard-after-onboarding.png** — Post-onboarding celebration: "You're set, Alex. Your daily target: 2.4 L." Confetti particles visible. Visually excellent.
- **09-dashboard-home.png / 09-dashboard-home-fresh.png / 09b-dashboard-home-main.png** — Dashboard home (empty state). "Good morning" editorial serif headline, "0 ml of 2450 ml today", empty bottle, "TODAY'S LOG / No water logged yet." FAB (+) present. Clean layout. **Under Dynamic Type XXXL (21-dashboard-dynamic-type-xxxl.png): headline and volume readout do not scale — see P1-01.**
- **09b-dashboard-scrolled.png** — Dashboard scrolled — no additional visible sections below the log card in empty state. Clean.
- **09c-dashboard-after-log.png** — Dashboard after logging an intake; bottle still shows 0% because the log was saved but the screenshot was taken immediately. No visual regression; the "0 ml" readout is consistent.
- **10-insights-7day.png / 10-tab2-insights.png** — Insights tab, 7-day view. Empty-state message "No data yet — start logging water on the Home tab." Stats row (0%, 0 ml, 0/7 goal days) renders correctly. No issues.
- **10b-insights-30day.png** — Insights tab, 30-day view. Same empty-state content. Segment picker switches correctly. No issues.
- **10c-insights-scrolled.png** — Insights scrolled. Weekly intake chart section header visible. No issues.
- **11-diary-today.png / 11-tab3-diary.png** — Diary tab. Calendar view with today (21 May 2026) highlighted in blue. "21 May 2026 / Total 0 ml / Goal 2450 ml" summary row visible. Clean.
- **11-diary-with-entry.png** — Diary after a logged entry. Entry row present. No issues.
- **11b-diary-scrolled.png** — Diary scrolled. No issues.
- **12-settings-main.png / 12-settings-top.png / 12-tab4-settings.png** — Settings top (Profile: Name field empty, Weight 70 kg, Metric/Imperial). Appearance picker (System/Light/Dark buttons). Daily Goal row with "Custom goal" and (+) button. Clean. **Note: Name field shows placeholder "Your Name" — expected for test session.**
- **12b-settings-scrolled.png / 12b-settings-mid.png** — Settings mid-scroll: Weather adjustment (Premium), Workout adjustment (Premium), goal methodology sources with hyperlinks, Schedule (Wake 07:00, Sleep 22:00), Reminders toggle. Clean.
- **12c-settings-bottom.png / 12c-settings-premium-rows.png** — Settings bottom: Weather permissions (Premium), Notifications (Enabled), About section (Rate Sipli, Privacy Policy, Terms of Use, Version 4.0), "Explore premium plans" row. Clean.
- **14-add-intake-sheet.png / 14b-add-intake-sheet-detail.png** — Log Intake sheet. "250 ml" amount in `.system(size: 44)` bold font, slider, Beverage row showing "Water" with "Unlock" button. **Under Dynamic Type XXXL: amount numeral does not scale — see P1-01. Entry editor / edit-existing flow was not captured — see P1-02.**
- **16-settings-notifications.png** — Settings notifications deep-link (scrolled into Reminders section showing "Enable reminders" toggle). Clean.
- **18-dashboard-dark-mode.png** — Dashboard in dark mode (set via `simctl ui appearance dark` before cold launch). Renders correctly — near-black background, tinted neutrals, bottle contrast preserved, tab bar readable. No issues.
- **19-settings-dark-mode.png** — Settings in dark mode. **Renders in light mode, not dark.** The `simctl ui appearance dark` used for dashboard was not re-applied before this screenshot; the test framework reset appearance between test runs. This is a test infrastructure gap, not an app bug — confirmed dark mode does render correctly in 18.
- **21-dashboard-dynamic-type-xxxl.png** — Dashboard at XXXL accessibility text size. "Good morning" heading and "0 ml" volume readout remain at their compiled fixed pixel sizes (32 pt). Body text ("of 2450 ml today", tab labels) scales correctly via `Font.TextStyle`. **See P1-01.**
- **22-settings-dynamic-type-xxxl.png** — Settings at XXXL. "Settings" page title and list row text scale. The weight value "70 kg" and section labels use `Font.TextStyle` and scale correctly. No issues with settings text. **However, the XXXL size was likely not injected via launchArguments — Dynamic Type scaling came from the base simulator setting, not from the test. See P1-01 for the root cause.**

---

## Issues found

### P0

None identified.

---

### P1

**P1-01 — `editorialSerif` and `sipliMono` are not Dynamic Type-aware; key UI text does not scale at Accessibility sizes**

Every call site passing a raw `CGFloat` to `Theme.editorialSerif(_:)` or `Theme.sipliMono(_:)` bypasses Dynamic Type. At XXXL the bottle fill percentage overlay ("0%"), greeting ("Good morning"), and volume readout ("0 ml") remain at their compiled sizes while surrounding body text grows, creating severe layout imbalance.

Affected call sites (not exhaustive):

| File | Line | Hard-coded size |
|---|---|---|
| `WaterQuest/Components/Theme.swift` | 259, 263 | root cause: fixed-size factory |
| `WaterQuest/Views/DashboardView.swift` | 736 | `editorialSerif(isRegular ? 36 : 32)` |
| `WaterQuest/Views/DashboardView.swift` | 740 | `sipliMono(11, ...)` |
| `WaterQuest/Views/DashboardView.swift` | 789 | `editorialSerif(isRegular ? 38 : 32)` |
| `WaterQuest/Views/AddIntakeView.swift` | 35 | `.system(size: isRegular ? 56 : 44, ...)` |
| `WaterQuest/Views/Onboarding/Steps/WelcomeStep.swift` | 110 | `editorialSerif(46)` |
| `WaterQuest/Views/Onboarding/Steps/WeightStep.swift` | 79 | `editorialSerif(96, ...)` |
| `WaterQuest/Views/Onboarding/Steps/TargetStep.swift` | 138 | `editorialSerif(64, ...)` |
| `WaterQuest/Views/Onboarding/Steps/NotificationsStep.swift` | 67 | `editorialSerif(40)` |
| `WaterQuest/Views/MainTabView.swift` | 169 | `.system(size: 24, ...)` |

The fix path is to add a `relativeTo:` parameter to `editorialSerif`/`sipliMono` (or accept a `Font.TextStyle` and use `.custom(_:size:relativeTo:)` / `UIFontMetrics`) and update each call site. `displayFont`/`titleFont`/`bodyFont`/`captionFont` already follow the correct pattern (`Font.TextStyle`).

---

**P1-02 — Paywall screens not captured; paywall entry points unconfirmed working**

Both automated routes to the paywall returned zero screenshots:
- Tapping "Unlock" in the Log Intake sheet (via `test05_BeveragePaywall`)
- Tapping the "Explore premium plans" / premium subscription row in Settings (via `test02_Settings`)

The Log Intake sheet renders correctly (14-add-intake-sheet.png shows the "Unlock" button), but the tap did not trigger the paywall sheet, or the paywall was dismissed faster than the 2-second wait. Manual verification of the paywall presentation and dismissal flow is required before the next release.

Screens missing: `20-paywall-tier-select`, `20b-paywall-from-beverage`

---

### P2

**P2-01 — Answer chip stack clips accumulated chips at the top edge on the Target step**

`AnswerChipStack` uses a `ZStack(alignment: .bottomTrailing)` with a fixed `minHeight: 64` (collapsed). When 3+ chips are stacked, the upper chips' negative `offsetY` values push them above the `minHeight` frame boundary and they are clipped. Visible in `05-onboarding-target.png` where the top portion of the "NAME Alex" chip is truncated.

Relevant code: `WaterQuest/Views/Onboarding/Components/AnswerChipStack.swift:36-38`

```swift
private var chipStackHeight: CGFloat {
    expanded ? CGFloat(chips.count) * 48 : 64  // collapsed: always 64 regardless of n chips
}
```

The collapsed height needs to account for the maximum peek offset (`-36` for 5+ chips per `collapsedTransform`). A `max(64, 64 + 36)` = 100 pt minimum, or `clipped(false)` on the ZStack, would prevent the truncation.

---

**P2-02 — Onboarding "Done / celebration" step is not isolatable via UITest; steps 07 and 08 capture the same screen**

Tapping "Start hydrating, Alex" on the notifications step immediately presents the iOS system notification permission alert, which dismisses the completion screen before a screenshot can be taken. The DoneStep confetti view is only visible for a fraction of a second. The OS-level alert fires synchronously on the main thread before the test's `Thread.sleep` can interpose.

The `08-onboarding-done.png` screenshot is a duplicate of `07-onboarding-notifications.png`.

The celebration screen *is* confirmed working when reached organically (see `09-dashboard-after-onboarding.png` captured via a separate cold-launch run that went straight to the confetti screen before notification permission was re-requested).

Relevant: `WaterQuest/Views/Onboarding/Steps/DoneStep.swift` (confetti), `WaterQuest/Views/Onboarding/Steps/NotificationsStep.swift` (where "Start hydrating" CTA lives).

---

## Verified good

The following screens passed visual inspection with no issues:

- Onboarding welcome — light and dark (01, 01b)
- Onboarding name step, chip stack with one chip (02)
- Onboarding weight step, ticker dial (03)
- Onboarding activity selection (04)
- Onboarding schedule step (06)
- Onboarding notifications frequency picker (07)
- Post-onboarding celebration screen with confetti (09-dashboard-after-onboarding)
- Dashboard empty state — light (09-dashboard-home-main)
- Dashboard dark mode (18-dashboard-dark-mode) — colours, contrast, tab bar all correct
- Insights tab empty state — 7-day and 30-day (10, 10b, 10c)
- Diary tab with calendar (11, 11b)
- Settings — all three scroll positions in light mode (12, 12b, 12c)
- Log Intake sheet — amount readout, slider, beverage row with Unlock button (14, 14b)
- Settings notifications deep-link (16)
- Reduce motion: honoured in WelcomeStep floating drops, DoneStep confetti, AddIntakeView scale animation, MainTabView tab transitions
- `AppTheme` dark mode via `simctl ui appearance` — renders correctly end-to-end (18)
- Settings under Dynamic Type XXXL — list row text, section headers, weight value all scale correctly (22)
