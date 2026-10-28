# Bottle Companion validation — 28 October 2026

Baseline: remote main `cf2443f050bddc970a94ba12d3b7c18bbe7f74c9` (6.1/22). Isolated branch: `codex/bottle-companion`. The original checkout and its untracked marketing work were preserved. PR #10 at `454d014c8a338d3c797a743c9ebfb149de5326d3` was inspected as a separate remote head and was not merged.

## Results

- Focused Bottle Companion, Siri/App Intents and bottle-renderer tests: **61 passed, 0 failed, 0 skipped**. `build/feature-tests.xcresult` and `build/feature-summary.json`.
- Broader named `WaterQuest` Xcode test plan, excluding the existing `SubscriptionManagerTests` StoreKit suite: **286 passed, 0 failed, 2 skipped**. `build/regression-tests.xcresult` and `build/regression-summary.json`.
- The complete initial plan ran all XCTest assertions successfully but did not finalize reliably around the existing StoreKit suite/known restore issue. Interrupted runs are retained as diagnostic evidence and are not reported as passing. No subscription behavior was changed.
- Native `BottleFlowTests.testBottleCompanionFlow`: **passed**, 0 failures. Covers setup, half checkpoint, duplicate prevention, relaunch persistence, finish once, undo and portrait/landscape rotation. `build/companion-ui-pass.xcresult` and `build/ui-summary.json`.
- Unit/store tests cover full→half→finish delta arithmetic, repeated checkpoints, partial refill, discard/shared adjustment, undo, invalid/nonfinite/bounds inputs, local persistence, pending-receipt recovery, stable UUID deduplication, yesterday’s receipt undo without subtracting from today, and preservation of external Siri/widget-style entries.
- The native UI test exposed SwiftUI Form’s automatic multi-button row behavior. Applying borderless style to the preset row ensures Half triggers only Half; the full native flow passed after this fix.
- Candidate **6.2 (23)**: Release archive succeeded with app, widget, Watch app and Watch widgets. Repository preflight passed all checks: uniform versions, privacy manifests, supported toolchain/OS, binary linkage, development-artifact exclusion and code seal. `build/Sipli-6.2-23-verified.xcarchive`, `build/preflight-verified.log`.
- Scoped native UI static audit: 0 errors/warnings (`build/companion-premium-audit.json`). The repository-wide audit also finds an existing unrelated marketing-web native-select ownership issue; marketing source was not changed.
- `git diff --check` passed.

## Visual evidence

Exported test screenshots and their manifest are in `build/companion-screenshots/`: setup portrait, half checkpoint controls, and landscape. Screenshots were inspected; the active form scrolls to its actions and uses native navigation, menus, labels and accessible sliders. Quantities are explicitly estimates; the action preview and disabled repeat commit are visible after logging.

## Environment limits

The existing iPhone 18 Pro iOS 27.2 simulators `5C940483-20F4-4628-BBC9-6836D58728E8` and `2FC0702A-56C0-44E3-B573-B7B5DE3F091B` booted successfully. UI tests use a UUID-named separate data file and defaults suite, retaining existing app records. No simulator was erased/reset. The existing Sipli Bottle QA simulator `5DEFA674-38CE-4829-A6D8-5CED7711993C` reported Data Migration Failed and was left intact. The already-failing Duo simulator was not changed. Native Duo book/tabletop/fold posture verification remains unverified; Home uses the existing fold layout and the native sheet follows the maintained sheet viewport contract. Physical-device Siri voice, motion, HealthKit delivery and accessibility-service behavior are not established by these simulator runs.

## Release access

Native computer use reports the Mac locked, and the separate in-app App Store Connect browser has no authenticated session. The existing Xcode signed-in account nevertheless supports shell distribution. A local export succeeded; Apple's current response confirmed version 6.1 build22 VALID and previousBundleVersion22 before selecting 6.2 build23. No new credentials, account/security changes or agreement acceptance were used.

TestFlight upload and processing evidence will be recorded separately when complete. No merge to main, tester/group assignment, external beta review or public App Store release is part of this work.
