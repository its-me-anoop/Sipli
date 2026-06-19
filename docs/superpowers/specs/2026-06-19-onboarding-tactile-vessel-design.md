# Onboarding — The Persistent Tactile Vessel

**Date:** 2026-06-19
**Branch:** `redesign-onboarding-tactile-vessel`
**Status:** Design approved, ready for implementation plan

## Problem

The branch is named *tactile-vessel*, but the vessel concept was never finished. The Sipli bottle (`SipliBottle` → `LiquidProgressView`) appears on only 3 of the 8 onboarding steps — Welcome (static 62%), Target (live, goal-bound), Done (static 85%) — and the three fills are unrelated to each other. There is no single object that carries the user from Welcome to Done, so the flow reads as eight disconnected screens rather than one continuous act of "filling up."

Everything else about the onboarding is strong and stays: editorial serif display type, mono micro-labels, the calm "paper" palette, just-in-time permissions, and the `AnswerChipStack` recap. This work changes only the vessel and the minimal chrome needed to host it.

## Goal

Deliver the "tactile vessel": **one persistent bottle that fills as the user progresses**, giving visible momentum on every step and an earned, emotional payoff at Done. The fill the user builds *is* the celebration.

## Approved Decisions

| Decision | Choice |
| --- | --- |
| Vessel placement | **Hero companion** — the bottle is a persistent element present on every screen, not re-created per step |
| Fill meaning | **Pure momentum** — water level = completed steps / 7. No goal-binding. |
| Dense steps (Weight, Target) | Bottle goes **compact-in-header**, animating between hero and compact sizes |
| Target step | **Drops its own goal-bottle.** The one-vessel rule holds; goal is expressed by number + chip + slider |

## Design

### Fill model

- `fillFraction = currentStep.fillIndex / 7`, where `fillIndex` is the step's ordinal position in the displayed flow.
  - Welcome ≈ empty (a small non-zero floor, e.g. `0.04`, so the bottle reads as "waiting to be filled" rather than broken-empty).
  - Each `Continue` advances `fillFraction` by one measure (~`1/7`).
  - Done = full (`1.0`), water shifts toward the green "complete" tone with a brim/ripple.
- The pour moment on each advance = a spring animation on `fillFraction` + a ripple + `Haptics.impact(.medium)` (the CTA already fires `Haptics.impact(.medium)`; the vessel reacts to the fill change rather than adding a second haptic).
- **Reduced motion:** when `accessibilityReduceMotion` is on, the fill snaps without splash/ripple. `LiquidProgressView` already honors reduce-motion internally for its wave.

### Architecture — shared chrome owned by the coordinator

Today every step independently renders `VStack { SipliTopBar; ScrollView { content }; SipliCTA }` and three of them render their own bottle. The fix is to lift **only the vessel** into `OnboardingView` so it is instantiated once and never torn down between step transitions. Stable view identity is what makes SwiftUI animate the water level continuously instead of cross-fading a fresh bottle in on each step.

New/changed units:

1. **`OnboardingVessel`** (new component, `Views/Onboarding/Components/OnboardingVessel.swift`)
   - Wraps `LiquidProgressView`. Inputs: `fill: Double`, `placement: VesselPlacement`, `isComplete: Bool`.
   - Renders the bottle at the size/position dictated by `placement` (`.hero` vs `.compact`).
   - Owns the brim/complete tint and the ripple accent. Pure, no app state. `accessibilityHidden(true)` (progress is conveyed to assistive tech via the coordinator — see Accessibility).

2. **`VesselPlacement`** (enum: `.hero`, `.compact`)
   - `.hero` → tall, top-center (~150–180pt bottle).
   - `.compact` → small (~64–80pt) in the header strip beside a thin progress line.
   - Placement is a property of each step (see step table). Size and position animate between cases with a spring so the bottle reads as one object relocating.

3. **`OnboardingStep` extension** — add `fillIndex: Int` (ordinal for the fill fraction) and `vesselPlacement: VesselPlacement` computed properties so the model, not the views, owns these facts.

4. **`OnboardingView` (coordinator)** — renders a `ZStack`/layout that hosts the single `OnboardingVessel` above the per-step content, driving `fill` from `step.fillIndex` and `placement` from `step.vesselPlacement`, both inside the existing advance/retreat `withAnimation` spring.

5. **The 8 step views** — minimal churn:
   - Remove the bottle from `WelcomeStep`, `TargetStep`, `DoneStep`.
   - Each step keeps its own back button (`SipliTopBar`), headline, controls, and `SipliCTA`. Steps no longer draw a vessel; they leave room for the coordinator-owned one (hero steps reserve top space; compact steps reserve a header slot).
   - On `.compact` steps, a thin progress line sits beside the bottle in the header (it visually replaces the role the removed `01/07` stepper used to play).

### Per-step vessel behavior

| Step | Placement | Fill | Notes |
| --- | --- | --- | --- |
| Welcome | hero | ~empty | Replaces the bespoke water-hero; empty bottle waits, first tap pours |
| Name | hero | ~1/7 | |
| Weight | **compact** | ~2/7 | 240pt dial keeps its room; bottle + progress line in header |
| Activity | hero | ~3/7 | |
| Target | **compact** | ~4/7 | Goal-bottle removed; goal shown via number + "AI calibrated" chip + custom slider |
| Schedule | hero | ~5/7 | |
| Notifications | hero | ~6/7 | |
| Done | hero | full | Brim + green complete tone + ripple = payoff |

### Welcome and Done

- **Welcome:** the current bespoke animated water-hero (`waterLayer`, `FloatingDrops`, local `WaterFill`) is replaced by the persistent empty vessel. The floating-drops/wave flourish may be retained *behind* the vessel as ambient background if it composes cleanly, but the bottle is the persistent object. `Get started` pours the first measure as the flow advances.
- **Done:** uses the same vessel at full fill, so the celebration is literally the bottle the user filled. Keep the existing celebratory copy and CTA.

### Target step reconciliation (detail)

`TargetStep` currently builds its `targetStage` around a `SipliBottle(fill: displayedFillFraction)` plus a vertical custom-goal slider whose handle maps to the bottle's water level. Under the one-vessel rule:

- Remove the inline `SipliBottle` from `targetStage`.
- The goal remains fully expressed: the large serif number readout, the unit, the "Suggested for you / Custom goal" caption, and the "AI calibrated" chip all stay.
- The vertical custom-goal slider stays functional but no longer needs to visually align to an inline bottle; it maps to the number readout. (Implementation may keep it vertical or simplify to fit the reclaimed layout — to be decided in the plan.)
- The persistent header bottle shows setup momentum (~4/7), not the goal. This is intentional (pure-momentum decision); the number owns "your goal."

## Accessibility

- The decorative vessel is `accessibilityHidden`. Progress is exposed at the coordinator level (e.g., an `accessibilityValue` such as "Step 3 of 7") so VoiceOver users get the momentum information without a decorative bottle stealing focus.
- All motion (pour, splash, ripple, size transition) is gated on `accessibilityReduceMotion`: reduced → instant fill, no splash.
- Dynamic Type: headlines already use the editorial/mono relative-to text styles; the chrome refactor must not regress that. Hero vs compact sizing is fixed-point for the bottle art but must not clip step content at accessibility sizes (the dense steps already use `ScrollView`).

## Testing

- **Unit:** `OnboardingStep.fillIndex` / `vesselPlacement` return the correct value for every case; `fillFraction` is monotonic non-decreasing across the flow and equals `1.0` at `.done`; Welcome floor is non-zero.
- **Snapshot/preview:** `OnboardingVessel` previews at representative fills in both placements, light + dark, default + accessibility Dynamic Type.
- **Manual/device:** walk the full flow on simulator; confirm the bottle never disappears across any transition (including hero↔compact), the pour animation fires on each Continue, Done brims green, and reduce-motion snaps cleanly.

## Out of Scope

- No copy rewrites, no new or removed steps, no changes to permissions, data flow, `OnboardingState`, persistence, or `GoalCalculator`.
- No change to the layered-keepsake fill (explicitly rejected in favor of pure momentum).
- No goal-binding / hybrid Target fill.

## Files Touched (anticipated)

- **New:** `Views/Onboarding/Components/OnboardingVessel.swift` (+ `VesselPlacement`).
- **Edit:** `Views/OnboardingView.swift` (host the vessel, drive fill/placement), `Views/Onboarding/OnboardingStep.swift` (`fillIndex`, `vesselPlacement`).
- **Edit (remove inline bottle / reserve space):** `Steps/WelcomeStep.swift`, `Steps/TargetStep.swift`, `Steps/DoneStep.swift`; light space-reservation tweaks to `Steps/NameStep.swift`, `Steps/ActivityStep.swift`, `Steps/WeightStep.swift`, `Steps/ScheduleStep.swift`, `Steps/NotificationsStep.swift`.
- **Possibly retire:** the `SipliBottle` view in `Views/Onboarding/Components/SipliBottle.swift` if no longer referenced. Note `SipliMark` lives in the same file and **is still used** (`WelcomeStep` brand mark), so the file cannot simply be deleted — `SipliMark` must be preserved (move it out, or leave `SipliBottle` in place unused).
