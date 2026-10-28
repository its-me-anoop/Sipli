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

## TestFlight 6.2 (25)

The faceless revision was uploaded once from source commit `97a083d281fa6f2cdb0f72e80d33f946a755204d`. The app, iOS widget, Watch app and Watch widget all archive as 6.2/25. Repository archive preflight passed signatures, four privacy manifests, uniform versions, linkage, development-artifact exclusion and release toolchain checks. The Release binary excludes simulator fixture and preview access switches; no camera permission is present.

Upload `8b3bfb32-9489-41c3-91f7-b22d5b5f1516` succeeded at 19:38:45 UTC. Apple subsequently confirmed `processingState: VALID`, `qcState: BETA_INTERNAL_TESTING`, and `usesNonExemptEncryption: false`. This is available for existing internal TestFlight testing. No groups/testers, external beta review, main merge or public release were changed. See `testflight-6.2-25-verification.json` for the exact verification timestamp.

The two native UI tests and 39 relevant model/animation/feedback tests passed after removing all facial drawing. Seven Library preview items were replaced with faceless version 1, including welcome, feedback, live insights, light/dark, landscape and accessibility-size captures. These use isolated fixture data. Physical model output quality, VoiceOver speech and Duo-specific hardware remain unverified. No GitHub release/publish workflow was triggered.

## Coach copy cleanup

Following the 22:46 user feedback, ordinary coach/insight cards no longer show provenance or availability footers such as “Live log”, “built-in encouragement”, “On-device AI”, or the model-unavailable explanation. Useful intake, goal and check-in facts and encouragement remain. The insight section and refresh controls use neutral wording so fallback content is not presented as AI-generated. Privacy/legal disclosures and required Weather attribution remain intact.

The copy-only UI change preserves the faceless bottle, motion, cooldowns, state refresh and dark-theme colors. A DEBUG simulator fixture can deterministically exercise model-output and unavailable-model presentation without calling physical model inference. Accessibility-tree assertions check that removed labels are absent, while encouragement and intake facts remain reachable at standard and accessibility text sizes. Existing state tests passed (11/11).

The cleanup was initially verified on the feature branch, then delivered in TestFlight 6.2 (26). The earlier 6.2 (25) binary and its verification record remain intact.

Copy cleanup verification: all 3 native UI tests passed (`build/coach-copy-ui-verified.xcresult`), covering light fallback, dark simulated-model output and accessibility-size presentation. All 11 existing live-state tests passed (`build/coach-copy-state.xcresult`). Both encouragement and intake facts remained reachable; the complete accessibility hierarchy contained none of the removed provenance labels. Four reviewed native screenshots were saved to Library. Physical model inference was not used or claimed for these presentation fixtures.

## TestFlight 6.2 (26)

The copy cleanup at `5310c8c424818bfc1bf611a83bd288acf46697a3` was archived from release source `5da2cb011b9ed350c578c320664230c128b97b92`; only uniform build-number settings differ. A fresh Apple check confirmed 25 as the preceding build, and 26 was accepted. All app/Watch/widget bundles are 6.2/26. Archive preflight passed code signatures, four privacy manifests, binary hygiene, version parity and release toolchain checks. The shipping binary excludes the removed provenance footers and DEBUG preview switches.

The repository regression plan passed 291 tests with 2 system Intent tests skipped on simulator transport cancellation and no failures. The previously excluded StoreKit suite remains excluded for its existing finalization issue. The cleanup's 3 native presentation tests passed for fallback, simulated-model output, dark mode and accessibility-size text, including accessibility-tree absence checks. Physical inference quality and Duo hardware are not claimed verified.

Upload `58f26dfa-744f-4043-a3f6-2b370bf71bc8` completed once at 23:08:25 UTC. Apple confirmed `VALID` / `BETA_INTERNAL_TESTING`, with non-exempt encryption false. Exact terminal evidence is in `testflight-6.2-26-verification.json`. No testers/groups, external review, main merge or public release were changed; old builds and branches remain intact. GitHub release/publish workflows were not triggered.
