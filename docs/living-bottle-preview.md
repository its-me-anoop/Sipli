# Living bottle insights preview

Branch starts from released main cf2443f (6.1/22), excluding both rejected feature branches. The initial preview did not include an upload. The subsequent user-authorized faceless revision prepares version 6.2 (25) for TestFlight. Coffee contrast changes are retained independently.

The existing Sipli bottle stays faceless; the existing water renderer and remaining-goal gauge remain intact. A nonmodal dismissible inline Home banner welcomes a returning user after a four-hour logging gap, during daytime, at most once per 24 hours. Dismissal snoozes it for a day. Entry, trophy and achievement presentations defer feedback. A saved manual check-in can receive a four-second acknowledgement after its sheet closes; the policy limits acknowledgements to once per 90 seconds and suppresses same-drink/amount undo-replay for ten minutes. Health imports and excessive/over-goal volumes do not earn this feedback. Motion respects accessibility Reduce Motion and background state.

Live snapshots include complete entry values, daily goal, unit, calendar day and freeze dates. Same-count edits, undo/deletion, goal changes, date rollover and foreground entry refresh analytics and copy. Numbers and weekly narratives remain app-calculated. Foundation Models chooses calm/warm/practical wording from validated phrases using the existing on-device model/locale availability gate; it cannot invent quantities, prescribe intake or create medical claims. No cloud fallback, new permission, entitlements, photo feature or bottle inventory exists in this branch. Stale async results are discarded and updates are debounced/throttled. Built-in encouragement remains immediate when unavailable.

Preview screenshots use a DEBUG simulator-only, UUID-isolated local persistence file with iCloud synchronization disabled: 500 ml logged five hours earlier and a 2,000 ml goal, followed by a 250 ml check-in. The separate namespace preserves existing simulator records. Accessibility captures exercise the same Reduce Motion branch through a DEBUG simulator flag and system accessibility text-size launch preference. They are rendered native UI, not mockups. Physical model performance, VoiceOver speech and Duo fold hardware remain unverified.

## Verification

- Xcode 27.2 Debug simulator build passed.
- WaterQuest regression plan: 288 passed, 2 skipped, 0 failures (`build/living-regression-2.xcresult`). Two system App Intent execution tests skipped because the simulator transport cancelled; the StoreKit suite was explicitly excluded due to its previously observed test-session finalization issue.
- Final focused suite: 11 passed, 0 failures (`build/living-verified.xcresult`): live snapshot/cache correction and rollover, deferral, deletion/undo/re-log suppression, persistent dismissal, opening-only welcome, background lifecycle, unavailable-model fallback, stale async rejection, safe quantities and light/dark coffee contrast.
- Native UI suite: 2 passed, 0 failures (`build/living-ui-verified.xcresult`), using existing healthy iPhone 18 Pro iOS 27.2 simulator 2FC0702A-56C0-44E3-B573-B7B5DE3F091B. Welcome dismissal, unobstructed Add, entry-flow interruption, post-save feedback, live 750 ml insight, persistence across relaunch, dark coffee selection and accessibility-size layout captured.
- The screenshot review caught and corrected a navigation overlap and an accessibility-size fixed-height overflow. A short-landscape layout explicitly reserves visible space for the bottle instead of allowing its geometry to collapse.
- Physical on-device AI output quality, VoiceOver speech and Duo-specific display/motion remain unverified. Native UI tests use built-in fallback text; no claim of physical model inference is made.
- Repository workflows are manual release/publish workflows; no CI workflow or release is triggered for this preview.
- Final short-landscape rerun: 1 native UI test passed (`build/living-landscape-verified.xcresult`), including a >80pt bottle-height assertion after rotation and refreshed native screenshot. The final calendar window uses Calendar day arithmetic across daylight-saving boundaries.

## Faceless revision

The user-requested revision removes both eyes and smile from the shared bottle renderer, including its unused face configuration and drawing shape. Original bottle artwork, water animation, remaining-goal gauge, encouragement and saved-log behavior are preserved.

Faceless revision verification: 39 bottle animation/model and live-feedback tests passed; 2 native UI tests passed. Welcome, saved-feedback, Insights, dark Home, coffee, landscape and accessibility screenshots were refreshed as Library version 1. Apple’s fresh response at 19:29 UTC confirmed previousBundleVersion 24; build 25 is used uniformly for app and embedded targets. Archive and upload evidence follows after processing completes.
