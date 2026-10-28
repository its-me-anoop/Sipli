# Sipli Scan verification — 28 October 2026

The separate branch `codex/sipli-scan` starts at released main `cf2443f050bddc970a94ba12d3b7c18bbe7f74c9` (6.1/22), excluding Bottle Companion. The rejected feature’s branch and 6.2/23 build remain intact. Original checkout marketing work and PR #10 are preserved.

## Implementation and safety

The camera toolbar action opens Sipli Scan. Native camera capture handles permission denial/restriction, cancellation and retake. Images are normalized in memory, never written to a photo album/app file or uploaded by app code, and released on close/reset/save. There is no photo-library permission or cloud model fallback.

The installed Xcode27.2/iOS27.2 SDK was inspected and compiled. On iOS27+, when `SystemLanguageModel.default.capabilities.contains(.vision)`, the on-device session receives a `Prompt` containing `Attachment(CGImage)` and returns a guided `ScanExtraction`. On older supported systems or unavailable image capability, Vision OCR text is interpreted by the same on-device Foundation Models API; the UI labels this as AI interpretation of label text. `SipliIntelligence.isReady` checks model availability and locale. No PCC model, managed entitlement, credential or server model is used.

Capacity proposals must be grounded in OCR evidence containing an unambiguous supported metric amount; nutrition/per100ml, serving, multipack, conflicting size, unmarked glass, low-confidence and unsupported/ambiguous-unit cases fall back to asking the person. The model never decides consumed volume. All/Half/Custom starts unselected. Package size and drink can be edited; custom amounts use locale-aware strict number parsing. Exact original millilitres are retained across imperial display rounding until the package field is edited. Log is disabled until a valid explicit portion/amount is chosen. There is no diary or HealthKit write during capture or analysis.

A per-scan commit gate claims before the sole diary write, blocking repeated taps. Confirmed amounts use the existing HydrationStore persistence, notification, goal, Watch/widget and intent donation paths. The shared state is reloaded before writing. Undo removes only the linked entry and serializes HealthKit removal after its save. Existing beverage and HealthKit subscription gates are retained. Closing/cancelling/retaking invalidates pending analysis results and writes nothing.

## Reported brown-colour issue

The user’s supplied image `libfile_96cd44f597308191b806cdbbe426a59f` was materialized through Library into the Mac workspace and visually inspected. It shows dark brown coffee/Americano quick-log text and beverage icons against a dark Log Intake surface. The scoped fix gives brown beverage accents a brighter warm tan in dark mode, with dark selected glyphs/save labels; light-mode browns remain dark enough for text. Related brown colours share a single palette owner. Other colour families and Watch colour values are preserved.

## Validation

- Initial Scan tests: seven passed, including actual Vision OCR against a generated package label image and consumption/idempotency checks. A simulator model attempt reported unsupported/missing model-catalog assets; it is not physical AI verification.
- Final named WaterQuest regression plan: **288 passed, 0 failed, 3 skipped**, excluding the existing SubscriptionManagerTests StoreKit suite implicated in prior runner finalization failures. One skip explicitly records unsupported physical image-model inference on the simulator; the other two are existing skips. `build/scan-regression-complete.xcresult` and `build/regression-summary.json`.
- Native UI: **three passed, 0 failures**. Tests cover required portion selection, Half logging, repeated taps, undo, unknown glass requiring Custom, explicit amount entry, cancellation without another log, simulated permission denial/manual fallback, and coffee selected/unselected views. Fixture controls are DEBUG+simulator-only and labelled “model not executed.” `build/scan-ui-final.xcresult`.
- Numerical palette checks pass 4.5:1 text/chip and selected-glyph contrast against representative white/dark elevated surfaces, and 3:1 dark disabled-state contrast. Framework colour-bridge test attempts that stalled were replaced by pure palette measurements; native screenshots are the visual evidence.
- The theme test was corrected to use the app’s numeric theme raw values (1 light, 2 dark); a fresh true-dark capture verifies actual appearance.
- Release archive 6.2/24 succeeded with app, iOS widget, Watch and Watch widget. Repository preflight passed OS/toolchain, uniform versions, privacy manifests, binary linkage, development-artifact exclusion and code signature. `build/Sipli-6.2-24-Scan-final.xcarchive` and `build/preflight.log`.
- Scoped native UI static audit and `git diff --check` passed.

## Limits and release

Healthy existing iPhone18Pro iOS27.2 simulators were used with UUID-named isolated fixture data; no simulator was erased or reset and no migration/runtime flags were changed. Native camera hardware, actual physical-device image-model quality, physical HealthKit delivery and Duo folding remain unverified. The user explicitly plans to check Scan on their phone through TestFlight. No purchase was made.

The fresh Apple response before release confirms previousBundleVersion23; 24 is the candidate with marketing version6.2 unchanged. Signing/distribution uses the already authorized Xcode account and existing assets. No testers/groups, external beta review or public App Store release actions are authorized or performed. Final upload/processing evidence will be recorded after Apple completes processing.
