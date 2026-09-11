# Home bottle verification — 11 September 2026

Branch: `codex/home-bottle-drain`. Other pre-existing uncommitted work was
removed as requested. The existing Home source changes only its bottle renderer;
the shared onboarding bottle and the rest of the app remain unchanged.

## Results

- Build: passed with Xcode 27.0 (27A5209h), unsigned simulator configuration.
- Bottle unit tests: 28 passed, no failures. Covers volume conservation, intake
  correction, smoothing, settling, gravity mapping, reduced motion and lifecycle.
- Full unit suite on iPhone 17 Pro / iOS 27: succeeded. XCTest reported 202 tests,
  two existing AppIntents system tests skipped, no failures. Swift Testing reported
  22 tests passed with 12 existing StoreKit entitlement verification known issues.
  Result bundle: `/private/tmp/sipli-bottle-unit-27.xcresult`.
- Simulator UI workflow on iPhone 17 Pro / iOS 26.5: passed, one complete flow,
  no failures, 258.342 seconds, 15 screenshot attachments. Covers logging, amount
  edits, deletion, relaunch, goal/overgoal, reduced motion and injected tilt.
  Result bundle: `/private/tmp/sipli-bottle-ui-v2.xcresult`.
- The final label sizing adjustment was subsequently built and checked visually
  at standard and largest accessibility text sizes; it was included in the full
  unit run. The full UI workflow preceded that typography-only adjustment.
- Final project syntax and `git diff --check`: passed.
- Physical-device sensor behavior: **NOT RUN**. Simulator tilt uses debug-only
  injected gravity through the same animation controller.

## Screenshots

These are unedited simulator captures of the final app. The dedicated QA fixture
uses Alex, a 2,000 ml goal, and no preunlocked badges. Other Home content reflects
the app's existing behavior for each fixture.

| Capture | State |
| --- | --- |
| [Full](01-full.png) | 0 ml logged, 100% left |
| [Half](02-half.png) | 1,000 ml logged, 50% left |
| [Empty](03-empty.png) | 2,000 ml logged, 0% left |
| [Left tilt](04-tilt-left.png) | 50% left, injected gravity x=-0.5, y=-0.8660254 |
| [Right tilt](05-tilt-right.png) | 50% left, injected gravity x=0.5, y=-0.8660254 |
| [Dark appearance](06-half-dark.png) | 50% left, resting level |
| [Largest text](07-largest-text.png) | Bottle label remains contained; surrounding existing Home layout is unchanged |

Reproduction commands: [UI test README](../WaterQuestUITests/README.md).
