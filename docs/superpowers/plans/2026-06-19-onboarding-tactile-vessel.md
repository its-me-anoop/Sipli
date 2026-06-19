# Onboarding Tactile Vessel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three disconnected onboarding bottles with one persistent vessel that the coordinator owns and that fills as the user advances through the 8 steps, ending in a full-brim celebration at Done.

**Architecture:** Lift the vessel (and the shared back-button chrome) into `OnboardingView` so a single `OnboardingVessel` instance is rendered once and never torn down between step transitions — stable SwiftUI identity is what makes the water level animate continuously instead of cross-fading a new bottle in. Each step view becomes content-only: it stops drawing its own bottle and top bar, and declares its vessel placement (`.hero` or `.compact`) via the model. The vessel's fill is a pure function of the current step; its size/position animate between hero and compact.

**Tech Stack:** SwiftUI, existing `LiquidProgressView` (masked-bottle liquid renderer), `Haptics`, XCTest + Swift Testing (`@testable import Sipli`), Xcode `BuildProject` MCP tool. Module name is **`Sipli`**.

---

## Background the engineer needs

- The onboarding lives in `WaterQuest/Views/Onboarding/`. The coordinator is `WaterQuest/Views/OnboardingView.swift`; it `switch`es on an `OnboardingStep` enum (`WaterQuest/Views/Onboarding/OnboardingStep.swift`) and renders one of 8 step views from `Steps/`.
- Today **each step** independently renders `VStack(spacing: 0) { SipliTopBar(...); <content>; SipliCTA(...) }` and sets its own `.background(OnboardingPalette.paper)`. Three steps also draw a bottle via `SipliBottle` (`Components/SipliBottle.swift`), which wraps `LiquidProgressView`.
- `SipliBottle` usage today: `WelcomeStep.swift:73` (`fill: 0.62`), `TargetStep.swift:124` (`fill: displayedFillFraction`), `DoneStep.swift:42` (`fill: 0.85`).
- `SipliTopBar` (in `Components/SipliCTA.swift`) is currently just a back button — the old `01/07` stepper was removed. Its `stepIndex`/`total` args are unused.
- `LiquidProgressView` (`WaterQuest/Components/LiquidProgressView.swift`) signature:
  ```swift
  LiquidProgressView(progress: Double,
                     compositions: [FluidComposition],
                     isRegular: Bool,
                     bottleWidth: CGFloat?,
                     bottleHeight: CGFloat?,
                     showProgressLabel: Bool = true)
  ```
  It internally animates the water level with `.animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)` and honors `accessibilityReduceMotion` for waves/bubbles. So **changing `progress` animates the pour for free.**
- `SipliMark` (the brand logo) is defined in the **same file** as `SipliBottle` (`Components/SipliBottle.swift`) and is still used by `WelcomeStep`. Do not delete that file wholesale.
- Tests live in `WaterQuestTests/`. `OnboardingStateTests.swift` already tests `OnboardingState` and `OnboardingStep` navigation using XCTest. New pure-logic tests go in a new file using the Swift Testing framework (project preference), which coexists with XCTest in the same target.
- Build with the `BuildProject` MCP tool from `xcode-tools`. There is no command-line `swift test`; unit tests run via the Xcode test action (`RunSomeTests`/`RunAllTests` MCP tools).

## File Structure

| File | Responsibility | Action |
| --- | --- | --- |
| `WaterQuest/Views/Onboarding/OnboardingStep.swift` | Step enum + per-step vessel facts (`fillFraction`, `vesselPlacement`, `isComplete`) and the `VesselPlacement` type | Modify |
| `WaterQuest/Views/Onboarding/Components/OnboardingVessel.swift` | The single persistent bottle view; maps placement → size, renders completion accent | Create |
| `WaterQuest/Views/OnboardingView.swift` | Hosts the persistent vessel + shared back button; drives fill/placement from the current step | Modify |
| `WaterQuest/Views/Onboarding/Steps/WelcomeStep.swift` | Content-only welcome (text + CTA); reserves hero vessel space | Modify |
| `WaterQuest/Views/Onboarding/Steps/NameStep.swift` | Content-only | Modify |
| `WaterQuest/Views/Onboarding/Steps/WeightStep.swift` | Content-only; compact placement | Modify |
| `WaterQuest/Views/Onboarding/Steps/ActivityStep.swift` | Content-only | Modify |
| `WaterQuest/Views/Onboarding/Steps/TargetStep.swift` | Content-only; remove inline goal-bottle | Modify |
| `WaterQuest/Views/Onboarding/Steps/ScheduleStep.swift` | Content-only | Modify |
| `WaterQuest/Views/Onboarding/Steps/NotificationsStep.swift` | Content-only | Modify |
| `WaterQuest/Views/Onboarding/Steps/DoneStep.swift` | Content-only celebration; uses persistent vessel at full | Modify |
| `WaterQuestTests/OnboardingVesselModelTests.swift` | Unit tests for the model additions | Create |

**Convention for "content-only" steps:** the step view body becomes the *middle content + CTA only* — no `SipliTopBar`, no `SipliBottle`, no `.background(OnboardingPalette.paper)` (the coordinator paints paper and chrome). The coordinator wraps each step in a layout that reserves vessel space above the content.

---

## Task 1: Model — vessel fill & placement (TDD)

**Files:**
- Modify: `WaterQuest/Views/Onboarding/OnboardingStep.swift`
- Test: `WaterQuestTests/OnboardingVesselModelTests.swift` (create)

- [ ] **Step 1: Write the failing tests**

Create `WaterQuestTests/OnboardingVesselModelTests.swift`:

```swift
import Testing
@testable import Sipli

struct OnboardingVesselModelTests {

    @Test func welcomeFillIsNonZeroFloor() {
        // Welcome reads "waiting to be filled", not broken-empty.
        #expect(OnboardingStep.welcome.fillFraction > 0)
        #expect(OnboardingStep.welcome.fillFraction < 0.1)
    }

    @Test func doneFillIsFull() {
        #expect(OnboardingStep.done.fillFraction == 1.0)
    }

    @Test func fillIsMonotonicNonDecreasing() {
        let steps = OnboardingStep.allCases.sorted { $0.rawValue < $1.rawValue }
        for (a, b) in zip(steps, steps.dropFirst()) {
            #expect(a.fillFraction <= b.fillFraction, "\(a) should not fill more than \(b)")
        }
    }

    @Test func middleStepsUseSeventhsOfTheFlow() {
        // name=1/7 ... notifications=6/7 (welcome floored separately, done=1.0)
        #expect(abs(OnboardingStep.name.fillFraction - 1.0/7.0) < 0.0001)
        #expect(abs(OnboardingStep.target.fillFraction - 4.0/7.0) < 0.0001)
        #expect(abs(OnboardingStep.notifications.fillFraction - 6.0/7.0) < 0.0001)
    }

    @Test func weightAndTargetAreCompact() {
        #expect(OnboardingStep.weight.vesselPlacement == .compact)
        #expect(OnboardingStep.target.vesselPlacement == .compact)
    }

    @Test func everyOtherStepIsHero() {
        let heroes: [OnboardingStep] = [.welcome, .name, .activity, .schedule, .notifications, .done]
        for step in heroes {
            #expect(step.vesselPlacement == .hero, "\(step) should be hero")
        }
    }

    @Test func onlyDoneIsComplete() {
        for step in OnboardingStep.allCases {
            #expect(step.isComplete == (step == .done))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Use the `RunSomeTests` MCP tool targeting `OnboardingVesselModelTests` (or `RunAllTests`).
Expected: FAIL — `OnboardingStep` has no `fillFraction`, `vesselPlacement`, `isComplete`, and `VesselPlacement` is undefined.

- [ ] **Step 3: Add the model code**

In `WaterQuest/Views/Onboarding/OnboardingStep.swift`, add the placement type and an extension. Place `VesselPlacement` near the top (after the imports) and the extension below `OnboardingStep`:

```swift
/// Where the persistent onboarding vessel sits for a given step.
/// `.hero` = tall and central (light steps); `.compact` = small, in the
/// header strip so input-heavy steps keep their vertical space.
enum VesselPlacement: Equatable {
    case hero
    case compact
}

extension OnboardingStep {
    /// Fraction of the vessel filled while this step is on screen.
    /// Welcome floors at a small non-zero level so the empty bottle reads as
    /// "waiting"; each step pours one measure; Done brims full.
    var fillFraction: Double {
        if self == .welcome { return 0.04 }
        return min(1.0, Double(rawValue) / Double(OnboardingStep.displayedTotal))
    }

    /// Placement of the persistent vessel for this step.
    var vesselPlacement: VesselPlacement {
        switch self {
        case .weight, .target: return .compact
        default: return .hero
        }
    }

    /// True only on the celebration step — drives the vessel's completion accent.
    var isComplete: Bool { self == .done }
}
```

Note: `displayedTotal` is `7` and `done.rawValue` is `7`, so `done.fillFraction == 1.0`. `welcome.rawValue` is `0` but is floored to `0.04`.

- [ ] **Step 4: Run the tests to verify they pass**

Use `RunSomeTests` for `OnboardingVesselModelTests`.
Expected: PASS (all 7 tests).

- [ ] **Step 5: Commit**

```bash
git add WaterQuest/Views/Onboarding/OnboardingStep.swift WaterQuestTests/OnboardingVesselModelTests.swift
git commit -m "feat(onboarding): vessel fill + placement model with tests"
```

---

## Task 2: `OnboardingVessel` component

**Files:**
- Create: `WaterQuest/Views/Onboarding/Components/OnboardingVessel.swift`

This is a pure, previewable view. No unit test (view rendering isn't unit-testable here); verify via build + preview.

- [ ] **Step 1: Create the component**

Create `WaterQuest/Views/Onboarding/Components/OnboardingVessel.swift`:

```swift
import SwiftUI

/// The single persistent onboarding bottle. One instance is owned by
/// `OnboardingView` and reused across every step so the water level animates
/// continuously. Wraps `LiquidProgressView` (masked-bottle liquid renderer).
struct OnboardingVessel: View {
    var fill: Double
    var placement: VesselPlacement
    var isComplete: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bottle art width per placement. Height follows the asset's 1.36 ratio.
    var width: CGFloat {
        switch placement {
        case .hero: return 168
        case .compact: return 72
        }
    }

    var body: some View {
        LiquidProgressView(
            progress: max(0, min(1, fill)),
            compositions: [FluidComposition(type: .water, proportion: 1.0)],
            isRegular: false,
            bottleWidth: width,
            bottleHeight: width * 1.36,
            showProgressLabel: false
        )
        .background(completionGlow)
        .scaleEffect(isComplete && !reduceMotion ? 1.04 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isComplete)
        .accessibilityHidden(true)
    }

    /// A soft green halo behind the bottle at completion — the celebratory
    /// accent. The water itself stays blue; Done's confetti carries the colour.
    @ViewBuilder
    private var completionGlow: some View {
        if isComplete {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OnboardingPalette.Bottle.green.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: width * 1.1
                    )
                )
                .frame(width: width * 2.2, height: width * 2.2)
                .blur(radius: 12)
        }
    }
}

#if DEBUG
#Preview("OnboardingVessel — placements & fills") {
    HStack(alignment: .bottom, spacing: 24) {
        OnboardingVessel(fill: 0.04, placement: .hero)
        OnboardingVessel(fill: 0.57, placement: .compact)
        OnboardingVessel(fill: 1.0, placement: .hero, isComplete: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OnboardingPalette.paper)
}
#endif
```

- [ ] **Step 2: Build**

Run the `BuildProject` MCP tool.
Expected: build succeeds. If `OnboardingPalette.Bottle.green` is misnamed, fix to match `Components/OnboardingPalette.swift` (it is defined there as `enum Bottle { static let green = ... }`).

- [ ] **Step 3: Preview check**

Open `OnboardingVessel.swift` in Xcode canvas (or use `RenderPreview` MCP tool for the `OnboardingVessel — placements & fills` preview). Confirm: hero bottle is large and ~empty, compact bottle is small and ~half full, completion bottle is full with a green halo.

- [ ] **Step 4: Commit**

```bash
git add WaterQuest/Views/Onboarding/Components/OnboardingVessel.swift
git commit -m "feat(onboarding): OnboardingVessel persistent bottle component"
```

---

## Task 3: Coordinator hosts the persistent vessel + shared back button

This is the structural heart of the change. The coordinator renders, in a single `ZStack`: the paper background, a shared back button, the per-step content (wrapped so it reserves vessel space), and the persistent vessel positioned by placement. The vessel and back button live **outside** the `.id(step)` subtree so they persist across transitions.

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Important:** This task changes the coordinator to expect **content-only** step views (no top bar / no vessel / no paper background). The step views are still in their old form until Tasks 4–10. To keep the build green between tasks, this task introduces the chrome and a `vesselReservation` wrapper but the steps will visually double-up (their own top bars/bottles still present) until migrated. That is expected and acceptable mid-plan; the final walkthrough (Task 11) confirms the end state. Build must still succeed after this task.

- [ ] **Step 1: Replace the coordinator body and add chrome helpers**

In `WaterQuest/Views/OnboardingView.swift`, replace the `body` and `stepContainer`/`slideTransition` section (lines ~23–100) with:

```swift
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                OnboardingPalette.paper.ignoresSafeArea()

                // Per-step content. Reserves space at the top for the vessel
                // zone so content never underlaps the floating bottle.
                stepContainer
                    .padding(.top, contentTopInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Shared back button — persists across step changes (outside .id).
                HStack {
                    if canGoBack {
                        SipliBackButton(action: retreat)
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // The single persistent vessel. Size + position animate by placement.
                OnboardingVessel(
                    fill: step.fillFraction,
                    placement: step.vesselPlacement,
                    isComplete: step.isComplete
                )
                .position(vesselPosition(in: proxy.size))
                .animation(.spring(response: 0.55, dampingFraction: 0.84), value: step)

                // Accessibility: the vessel is decorative/hidden, so expose
                // setup progress here as a small, early-sorted element.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Setup progress")
                    .accessibilityValue("Step \(min(step.rawValue + 1, OnboardingStep.displayedTotal)) of \(OnboardingStep.displayedTotal)")
                    .accessibilitySortPriority(1)
            }
        }
        .task { @MainActor in
            state.prefersHealthKit = healthKit.isAuthorized
        }
        .onChange(of: state.prefersHealthKit) { oldValue, newValue in
            handleHealthKitToggle(was: oldValue, now: newValue)
        }
        .onChange(of: state.prefersWeatherGoal) { oldValue, newValue in
            handleWeatherToggle(was: oldValue, now: newValue)
        }
    }

    /// Back button is shown on every step except the first and the celebration.
    private var canGoBack: Bool {
        step != .welcome && step != .done
    }

    /// Vertical space reserved above step content for the vessel zone.
    /// Hero needs room for the tall bottle; compact only needs the header strip.
    private var contentTopInset: CGFloat {
        switch step.vesselPlacement {
        case .hero: return 268      // back row (~60) + hero bottle (~228) minus overlap
        case .compact: return 84    // back row + compact bottle sitting inline
        }
    }

    /// Centre point for the persistent vessel given the current placement.
    /// Hero: centred horizontally, upper third. Compact: tucked top-trailing
    /// beside the back button.
    private func vesselPosition(in size: CGSize) -> CGPoint {
        switch step.vesselPlacement {
        case .hero:
            return CGPoint(x: size.width / 2, y: 188)
        case .compact:
            return CGPoint(x: size.width - 64, y: 52)
        }
    }

    @ViewBuilder
    private var stepContainer: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeStep(onContinue: advance)
            case .name:
                NameStep(state: $state,
                         answers: state.answerChips(upTo: .name),
                         onContinue: advance,
                         onBack: retreat)
            case .weight:
                WeightStep(state: $state,
                           answers: state.answerChips(upTo: .weight),
                           onContinue: advance,
                           onBack: retreat)
            case .activity:
                ActivityStep(state: $state,
                             answers: state.answerChips(upTo: .activity),
                             onContinue: advance,
                             onBack: retreat)
            case .target:
                TargetStep(state: $state,
                           answers: state.answerChips(upTo: .target),
                           onContinue: advance,
                           onBack: retreat)
            case .schedule:
                ScheduleStep(state: $state,
                             answers: state.answerChips(upTo: .schedule),
                             onContinue: advance,
                             onBack: retreat)
            case .notifications:
                NotificationsStep(state: $state,
                                  answers: state.answerChips(upTo: .notifications),
                                  onFinish: { Task { await finishToDone() } },
                                  onBack: retreat)
            case .done:
                DoneStep(state: state, onFinish: completeAndExit)
            }
        }
        .id(step)
        .transition(slideTransition)
    }

    private var slideTransition: AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 40)),
                removal: .opacity.combined(with: .offset(y: -40))
            )
        case .backward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -40)),
                removal: .opacity.combined(with: .offset(y: 40))
            )
        }
    }
```

Leave `advance()`, `retreat()`, the permission handlers, and completion methods unchanged.

- [ ] **Step 2: Build**

Run `BuildProject`.
Expected: success. (Step views still compile — their signatures are unchanged. They will render their own redundant chrome on top of the coordinator's for now.)

- [ ] **Step 3: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): coordinator owns persistent vessel + shared back button"
```

---

## Task 4: Migrate WelcomeStep to content-only

Welcome currently builds a bespoke animated water hero (`waterLayer`, `FloatingDrops`, `WaterFill`) plus a `SipliBottle`. Replace all of that with a content-only layout (brand mark + headline + subtitle + CTA). The persistent vessel (empty) now provides the bottle.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Steps/WelcomeStep.swift`

- [ ] **Step 1: Replace the file body with content-only**

Replace the entire `struct WelcomeStep` (keep the file's helper types removed — `WaterFill` and `FloatingDrops` are no longer used and should be deleted to avoid dead code):

```swift
import SwiftUI

struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            welcomeText
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            SipliCTA(title: "Get started", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var welcomeText: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SipliMark(size: 24)
                Text("SIPLI")
                    .font(.sipliMono(12, weight: .semibold, relativeTo: .caption))
                    .tracking(1.6)
                    .foregroundStyle(OnboardingPalette.ink)
            }

            (Text("Drink water\nlike you ").foregroundStyle(OnboardingPalette.ink)
            + Text("mean it.").italic().foregroundStyle(OnboardingPalette.water))
                .font(.editorialSerif(46, relativeTo: .largeTitle))
                .lineSpacing(-2)

            Text("A hydration habit that actually fits in your life. No streaks to lose sleep over.")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink3)
                .lineSpacing(2)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

(Delete the old `hero`, `waterLayer`, `startAnimations`, the `@State`/`@Environment` motion properties, and the private `WaterFill` and `FloatingDrops` types. Keep/restore the `#if DEBUG #Preview` if present, wrapping `WelcomeStep(onContinue: {})` in `PreviewEnvironment` if needed.)

- [ ] **Step 2: Build**

Run `BuildProject`.
Expected: success. No references to the deleted `WaterFill`/`FloatingDrops` remain (they were `private` to this file).

- [ ] **Step 3: Preview / render check**

Use `RenderPreview` on `OnboardingView`'s light preview (it renders Welcome first). Confirm: the empty hero bottle sits above the headline; the bespoke wave hero is gone; the headline and CTA are not overlapped by the vessel.
If the headline underlaps the vessel, nudge `contentTopInset`'s `.hero` value (Task 3) and rebuild.

- [ ] **Step 4: Commit**

```bash
git add WaterQuest/Views/Onboarding/Steps/WelcomeStep.swift
git commit -m "feat(onboarding): Welcome uses persistent vessel; drop bespoke water hero"
```

---

## Task 5: Migrate the hero content steps (Name, Activity, Schedule, Notifications)

These four steps don't draw a bottle today; they only carry the redundant `SipliTopBar` and their own paper background. Make each content-only: remove the `SipliTopBar(...)` line and the `.background(OnboardingPalette.paper)` modifier so the coordinator's chrome shows through. Do them one at a time, building after each.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Steps/NameStep.swift`
- Modify: `WaterQuest/Views/Onboarding/Steps/ActivityStep.swift`
- Modify: `WaterQuest/Views/Onboarding/Steps/ScheduleStep.swift`
- Modify: `WaterQuest/Views/Onboarding/Steps/NotificationsStep.swift`

- [ ] **Step 1: NameStep — remove top bar + background**

In `NameStep.swift`, find the outer `VStack(spacing: 0) { ... }` body. Remove the line:
```swift
SipliTopBar(stepIndex: 1, total: OnboardingStep.displayedTotal, canGoBack: true, onBack: onBack)
```
and remove the `.background(OnboardingPalette.paper)` modifier on that VStack. Keep `onBack` in the signature (the coordinator passes it; it's now unused inside the view — silence with `_ = onBack` only if the compiler warns about an unused property; struct stored `let` properties don't warn, so leave it).

- [ ] **Step 2: Build**

Run `BuildProject`. Expected: success.

- [ ] **Step 3: Repeat for ActivityStep**

In `ActivityStep.swift`, remove its `SipliTopBar(stepIndex: 3, ...)` line and its `.background(OnboardingPalette.paper)`.

- [ ] **Step 4: Build**

Run `BuildProject`. Expected: success.

- [ ] **Step 5: Repeat for ScheduleStep**

In `ScheduleStep.swift`, remove its `SipliTopBar(stepIndex: 5, ...)` line and its `.background(OnboardingPalette.paper)`.

- [ ] **Step 6: Build**

Run `BuildProject`. Expected: success.

- [ ] **Step 7: Repeat for NotificationsStep**

In `NotificationsStep.swift`, remove its `SipliTopBar(stepIndex: 6, ...)` line and its `.background(OnboardingPalette.paper)`.

- [ ] **Step 8: Build + preview**

Run `BuildProject`. Then `RenderPreview` on `OnboardingView` and step through (or render each step's own `#Preview` if present). Confirm each step's content starts below the hero vessel and the single back button shows (no doubled back buttons).

- [ ] **Step 9: Commit**

```bash
git add WaterQuest/Views/Onboarding/Steps/NameStep.swift \
        WaterQuest/Views/Onboarding/Steps/ActivityStep.swift \
        WaterQuest/Views/Onboarding/Steps/ScheduleStep.swift \
        WaterQuest/Views/Onboarding/Steps/NotificationsStep.swift
git commit -m "feat(onboarding): hero steps become content-only under shared chrome"
```

---

## Task 6: Migrate WeightStep (compact placement)

Weight is a dense step using compact placement. Remove its top bar + background. Add a thin progress line in the header strip beside where the compact vessel sits (top-trailing), to give the header meaning. The 240pt ruler keeps its space because the compact vessel only reserves ~84pt up top.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Steps/WeightStep.swift`

- [ ] **Step 1: Remove chrome, add a header progress line**

In `WeightStep.swift`:
1. Remove `SipliTopBar(stepIndex: 2, total: OnboardingStep.displayedTotal, canGoBack: true, onBack: onBack)`.
2. Remove `.background(OnboardingPalette.paper)`.
3. At the very top of the outer `VStack(spacing: 0)` body (now where the top bar was), insert a header progress line that leaves room on the trailing side for the coordinator's compact vessel:

```swift
// Header strip: thin progress meter. The compact vessel (coordinator-owned)
// floats at the trailing edge of this strip.
HStack {
    Capsule()
        .fill(OnboardingPalette.ink.opacity(0.12))
        .frame(height: 4)
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                Capsule()
                    .fill(OnboardingPalette.water)
                    .frame(width: geo.size.width * OnboardingStep.weight.fillFraction)
            }
        }
    Spacer().frame(width: 96) // clearance for the compact vessel
}
.frame(height: 44)
.padding(.horizontal, 24)
.padding(.top, 50)   // sit below the shared back button
.padding(.bottom, 4)
```

- [ ] **Step 2: Build**

Run `BuildProject`. Expected: success.

- [ ] **Step 3: Preview check**

`RenderPreview` on `WeightStep` (or `OnboardingView` advanced to weight). Confirm: compact bottle in the top-trailing corner, thin progress line to its left, the dial/readout retain their room, single back button.
Tune `vesselPosition(.compact)` / `contentTopInset(.compact)` (Task 3) and the header `.padding(.top, ...)` if the bottle and progress line don't align.

- [ ] **Step 4: Commit**

```bash
git add WaterQuest/Views/Onboarding/Steps/WeightStep.swift
git commit -m "feat(onboarding): Weight step compact vessel + header progress line"
```

---

## Task 7: Migrate TargetStep (compact placement, drop the goal-bottle)

Target currently builds `targetStage` around an inline `SipliBottle(fill: displayedFillFraction, size: 110)` with a vertical custom-goal slider aligned to it. Per the one-vessel rule, remove the inline bottle. Keep the big serif number, the unit, the "Suggested / Custom goal" caption, the "AI calibrated" chip, and the custom-goal slider (it now maps to the number, not a bottle). Add the same header progress line as Weight. The persistent compact vessel shows momentum (~4/7), not the goal.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Steps/TargetStep.swift`

- [ ] **Step 1: Remove chrome + add header progress line**

In `TargetStep.swift`:
1. Remove `SipliTopBar(stepIndex: 4, ...)`.
2. Remove `.background(OnboardingPalette.paper)`.
3. Insert the same header strip used in Weight, but bound to Target's fill:

```swift
HStack {
    Capsule()
        .fill(OnboardingPalette.ink.opacity(0.12))
        .frame(height: 4)
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                Capsule()
                    .fill(OnboardingPalette.water)
                    .frame(width: geo.size.width * OnboardingStep.target.fillFraction)
            }
        }
    Spacer().frame(width: 96)
}
.frame(height: 44)
.padding(.horizontal, 24)
.padding(.top, 50)
.padding(.bottom, 4)
```

- [ ] **Step 2: Remove the inline goal-bottle from `targetStage`**

In the `targetStage` computed property, delete the `SipliBottle(fill: displayedFillFraction, size: 110)` line (the first child of the `HStack`). Keep the `verticalGoalSlider` (shown when `customGoalEnabled`) and the numeric readout `VStack`. The `HStack` now holds: optional `verticalGoalSlider` + the readout. Adjust the readout's `VStack` alignment so it reads naturally without the bottle on the left — change the outer `HStack(alignment: .center, spacing: 12)` content so the readout is leading-aligned:

```swift
private var targetStage: some View {
    HStack(alignment: .center, spacing: 16) {
        if state.customGoalEnabled {
            verticalGoalSlider
                .frame(width: 28, height: 150)
                .transition(.opacity)
        }

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(displayedTopLine)
                    .font(.editorialSerif(64, weight: .regular, relativeTo: .largeTitle))
                    .foregroundStyle(OnboardingPalette.ink)
                    .contentTransition(.numericText())
                Text(displayedUnit)
                    .font(.sipliMono(18, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: displayedML)

            Text(state.customGoalEnabled ? "Custom goal" : "Suggested for you")
                .font(.system(size: 13))
                .foregroundStyle(OnboardingPalette.ink3)

            if !state.customGoalEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("AI calibrated")
                }
                .font(.sipliMono(11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(OnboardingPalette.sun)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(OnboardingPalette.ink))
                .padding(.top, 4)
            }
        }
        Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .frame(minHeight: 160)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.910, green: 0.957, blue: 0.984), Color(red: 1.0, green: 0.956, blue: 0.878)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
    )
}
```

`displayedFillFraction` is now unused — delete that computed property to avoid a dead-code warning.

- [ ] **Step 3: Build**

Run `BuildProject`. Expected: success, no "unused `displayedFillFraction`" reference errors (you removed it and its only use).

- [ ] **Step 4: Preview check**

`RenderPreview` on `TargetStep` via `OnboardingView` (needs the env objects — use the existing onboarding preview which injects `PreviewEnvironment`). Confirm: no inline bottle in the target card; number + chip + (when custom on) vertical slider read correctly; compact vessel + progress line in header; toggles and weather card unchanged.

- [ ] **Step 5: Commit**

```bash
git add WaterQuest/Views/Onboarding/Steps/TargetStep.swift
git commit -m "feat(onboarding): Target drops inline goal-bottle; compact vessel + header"
```

---

## Task 8: Migrate DoneStep (celebration uses the persistent vessel)

Done currently draws its own `SipliBottle(fill: 0.85, size: 150)` centered with a bob, plus confetti and its own gradient background. Remove the inline bottle (the persistent hero vessel, now full + isComplete, sits above). Keep the confetti, the headline, the target line, and the CTA. Done is a hero placement, so the coordinator's vessel is centered up top at full fill.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Steps/DoneStep.swift`

- [ ] **Step 1: Make Done content-only**

In `DoneStep.swift`:
1. Remove the `SipliBottle(fill: 0.85, size: 150).offset(y: bobOffset)` from the inner `VStack`.
2. Remove the now-unused `bobOffset` state and `startAnimations()` bob animation (keep `Haptics.success()` in `onAppear`). Keep `confettiSeed` + `ConfettiLayer`.
3. Keep the gradient background and confetti, but ensure the text block sits below the vessel zone. Replace the leading `Spacer(minLength: 36)` with `Spacer(minLength: 36)` → keep, but the inner content `VStack` should start lower so it doesn't collide with the full hero vessel; the coordinator's `contentTopInset` (hero) already pushes content down, so leave the structure and just drop the bottle.

Resulting body (text + CTA + confetti, no bottle, no bob):

```swift
var body: some View {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.863, green: 0.933, blue: 1.0), OnboardingPalette.paper],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        if !reduceMotion {
            ConfettiLayer(seed: confettiSeed)
                .allowsHitTesting(false)
        }

        VStack(spacing: 0) {
            Spacer(minLength: 12)

            (Text("You're set,\n").foregroundStyle(OnboardingPalette.ink)
                + Text("\(firstName).").italic().foregroundStyle(OnboardingPalette.water))
                .font(.editorialSerif(38, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Your daily target: \(Text(targetDisplay).fontWeight(.semibold).foregroundColor(OnboardingPalette.ink)). Let's start with a small sip.")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 18)
                .frame(maxWidth: 320)

            Spacer()

            SipliCTA(title: "Open Sipli", variant: .water, action: onFinish)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }
    .onAppear { Haptics.success() }
}
```

Remove `@State private var bobOffset` and the `startAnimations()` method. Keep `@Environment(\.accessibilityReduceMotion)` (used by confetti), `firstName`, `targetDisplay`, `confettiSeed`, and `ConfettiLayer`.

Note: Done provides its own gradient + confetti as a full-screen `ZStack`. Because Done is rendered inside `stepContainer` (which is padded by `contentTopInset`), confirm in preview the gradient still covers the full screen — if the top inset clips it, move Done's gradient to ignore the inset by keeping `.ignoresSafeArea()` (already present) and verifying visually in Step 3.

- [ ] **Step 2: Build**

Run `BuildProject`. Expected: success.

- [ ] **Step 3: Preview check**

`RenderPreview` Done via `OnboardingView`. Confirm: full vessel with green glow centered up top, confetti falling, "You're set, <name>." below it, target line, "Open Sipli" CTA. The gradient covers the screen.
If the gradient is clipped by `contentTopInset`, Task 9 makes Done's inset zero — that fix is next; for now just confirm the bottle/text composition.

- [ ] **Step 4: Commit**

```bash
git add WaterQuest/Views/Onboarding/Steps/DoneStep.swift
git commit -m "feat(onboarding): Done celebration uses persistent full vessel"
```

---

## Task 9: Handle Done's full-bleed background vs. content inset

Done (and only Done) wants a full-bleed gradient that ignores the coordinator's `contentTopInset`. The inset is applied to `stepContainer` uniformly. Make the inset conditional so Done gets zero top inset (its own layout handles spacing), while all other steps keep their inset.

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

- [ ] **Step 1: Make the content inset skip Done**

In `OnboardingView.swift`, change `contentTopInset` so Done returns 0:

```swift
private var contentTopInset: CGFloat {
    switch step {
    case .done: return 0
    default:
        switch step.vesselPlacement {
        case .hero: return 268
        case .compact: return 84
        }
    }
}
```

- [ ] **Step 2: Build + preview**

Run `BuildProject`, then `RenderPreview` Done. Confirm the gradient is full-bleed and the headline sits clear below the full vessel (the vessel is at `y: 188`; Done's `Spacer(minLength: 12)` + headline should begin around mid-screen). Adjust Done's leading `Spacer(minLength:)` if the headline crowds the vessel.

- [ ] **Step 3: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "fix(onboarding): Done gets full-bleed background, no content inset"
```

---

## Task 10: Retire the now-unused `SipliBottle` view (keep `SipliMark`)

After Tasks 4/7/8, `SipliBottle` has no remaining references. `SipliMark` (same file) is still used by Welcome. Remove only the `SipliBottle` struct and its previews; keep `SipliMark`.

**Files:**
- Modify: `WaterQuest/Views/Onboarding/Components/SipliBottle.swift`

- [ ] **Step 1: Confirm no remaining `SipliBottle(` references**

Search the workspace for `SipliBottle(`. Expected: only matches inside `SipliBottle.swift` itself (the struct + its `#Preview`). If any step still references it, that step wasn't migrated — fix before continuing.

- [ ] **Step 2: Delete the `SipliBottle` struct + its preview block; keep `SipliMark` and the `SipliMark` preview**

Edit `SipliBottle.swift` to remove `struct SipliBottle { ... }` and the `#Preview("SipliBottle — multiple fills")` block. Keep `struct SipliMark { ... }` and `#Preview("SipliMark sizes")`. (Optionally rename the file to `SipliMark.swift` later — out of scope; leaving the filename is fine.)

- [ ] **Step 3: Build**

Run `BuildProject`. Expected: success, no "cannot find SipliBottle" errors.

- [ ] **Step 4: Commit**

```bash
git add WaterQuest/Views/Onboarding/Components/SipliBottle.swift
git commit -m "chore(onboarding): retire unused SipliBottle view; keep SipliMark"
```

---

## Task 11: Full verification + device walkthrough

**Files:** none (verification only)

- [ ] **Step 1: Full build**

Run `BuildProject`. Expected: success, no warnings about unused properties introduced by this work (`bobOffset`, `displayedFillFraction`, `WaterFill`, `FloatingDrops` should all be gone).

- [ ] **Step 2: Run the unit tests**

Run `RunAllTests` (or at least `OnboardingVesselModelTests` + `OnboardingStateTests`).
Expected: PASS.

- [ ] **Step 3: Device/simulator walkthrough**

Launch the app (`RunProject`) into onboarding (fresh install or reset onboarding flag). Walk all 8 steps and confirm:
- The bottle is present on **every** screen and **never disappears** across any transition, including Weight↔Activity and Target↔Schedule (hero↔compact and back).
- Each "Continue" raises the water by ~one measure with a smooth pour, and the CTA's existing `Haptics.impact(.medium)` fires.
- Welcome shows a near-empty bottle; Done shows a full bottle with the green glow + confetti.
- Exactly one back button, never two; back navigation lowers the water correctly.
- Weight's dial and Target's controls are not cramped.

- [ ] **Step 4: Reduced-motion check**

Enable Settings → Accessibility → Reduce Motion. Re-walk a few steps. Confirm the fill snaps without splashing and the completion scale-pop is suppressed (per `OnboardingVessel`'s `reduceMotion` guard and `LiquidProgressView`'s internal handling).

- [ ] **Step 5: Dynamic Type spot check**

Set a large accessibility text size. Confirm headlines scale and the dense steps (Weight, Target) scroll without clipping, and content doesn't collide with the vessel.

- [ ] **Step 6: Final commit (if any tuning changes were made)**

```bash
git add -A
git commit -m "polish(onboarding): final vessel position/inset tuning after walkthrough"
```

---

## Notes on tuning constants

The vessel position (`vesselPosition`), content insets (`contentTopInset`), and the compact header paddings are starting values chosen from the asset ratio (bottle height = width × 1.36) and the existing 24pt horizontal rhythm. They are expected to need small in-preview adjustments on first run — the preview/walkthrough steps are where you confirm alignment. They are real values, not placeholders; adjust only if the visual checks fail.

## Open items deferred from the spec (decide during execution)

- **Target custom-goal slider:** kept vertical in this plan (lowest churn). If it looks unbalanced without its companion bottle, simplifying it to a horizontal slider under the readout is acceptable — keep the same `state.customGoalValue` binding and snapping logic.
- **Welcome ambient drops/waves:** removed in this plan for a clean empty-bottle moment. If you want ambient motion back, add it as a coordinator-level background behind the vessel, gated on `accessibilityReduceMotion` — do not reintroduce it inside the step (steps are content-only now).
