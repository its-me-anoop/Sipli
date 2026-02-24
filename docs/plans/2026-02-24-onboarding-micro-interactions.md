# Onboarding Micro-Interactions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the static onboarding flow into a polished, animation-rich experience that matches the app's water-themed design language.

**Architecture:** All changes are in a single file (`OnboardingView.swift`). We add new private sub-views for the water drop progress indicator, enhance the existing `AnimatedOnboardingPage` with staggered entrance animations and per-step themed icon animations, add micro-interactions to selection controls, and polish the navigation bar.

**Tech Stack:** SwiftUI animations, Theme.swift constants, Haptics.swift feedback patterns

---

### Task 1: Add Water Drop Step Progress Indicator

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Step 1: Add the `WaterDropProgressIndicator` private view**

Add a new private struct below `BouncyButtonStyle` (after line 357). This view renders 7 water drop shapes in a horizontal row. Completed steps are filled with Lagoon color, the current step pulses, and future steps are outlined.

```swift
// MARK: - Water Drop Progress Indicator
private struct WaterDropProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { index in
                WaterDropDot(
                    state: index < currentStep ? .completed : (index == currentStep ? .current : .upcoming)
                )
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

private struct WaterDropDot: View {
    enum DropState {
        case completed, current, upcoming
    }

    let state: DropState

    @State private var isPulsing = false
    @State private var splashScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Splash ring for completed drops
            if state == .completed {
                Circle()
                    .stroke(Theme.lagoon.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .scaleEffect(splashScale)
                    .opacity(splashScale > 1.2 ? 0 : 0.6)
            }

            Image(systemName: "drop.fill")
                .font(.system(size: state == .current ? 16 : 12))
                .foregroundStyle(
                    state == .upcoming
                        ? Color.white.opacity(0.25)
                        : Theme.lagoon
                )
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .shadow(
                    color: state == .current ? Theme.lagoon.opacity(0.4) : .clear,
                    radius: 6
                )
        }
        .animation(Theme.quickSpring, value: state)
        .onAppear {
            if state == .current {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: state) { _, newState in
            if newState == .completed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    splashScale = 1.5
                }
                // Reset for next time
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    splashScale = 0.8
                }
            }
            if newState == .current {
                isPulsing = false
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}
```

**Step 2: Integrate the progress indicator into the main `body`**

In `OnboardingView.body` (around line 37), insert the progress indicator above the `TabView`:

Replace:
```swift
VStack(spacing: 0) {
    TabView(selection: $step) {
```

With:
```swift
VStack(spacing: 0) {
    WaterDropProgressIndicator(currentStep: step, totalSteps: totalSteps)

    TabView(selection: $step) {
```

**Step 3: Build and verify**

Run: Build in Xcode. Verify 7 drops appear at top, current step pulses, advancing fills previous drops.

**Step 4: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): add water drop step progress indicator"
```

---

### Task 2: Add Per-Step Themed Icon Animations to AnimatedOnboardingPage

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Step 1: Add an `IconAnimation` enum and update `AnimatedOnboardingPage`**

Replace the existing `AnimatedOnboardingPage` struct (lines 360-426) with an enhanced version that supports per-step themed animations. The key change is adding an `iconAnimation` parameter and staggered entrance animations for all content blocks (matching what `AnimatedWelcomeStep` already does).

```swift
// MARK: - Icon Animation Types
private enum IconAnimation {
    case pulse          // Default: gentle scale pulse
    case wiggle         // Rotation wiggle ±8°
    case tilt           // Scale tilt like a balance ±12°
    case bounce         // Vertical bounce
    case spin           // Slow continuous rotation + pulse rings
    case rise           // Rising arc + glow
    case ring           // Bell sway ±15°

    var loopDuration: Double {
        switch self {
        case .pulse: return 2.0
        case .wiggle: return 1.8
        case .tilt: return 2.0
        case .bounce: return 0.8
        case .spin: return 8.0
        case .rise: return 3.0
        case .ring: return 2.5
        }
    }
}

// MARK: - Reusable Onboarding Page
private struct AnimatedOnboardingPage<Content: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    var iconAnimation: IconAnimation = .pulse
    var iconColor: Color = Theme.lagoon
    @ViewBuilder let content: Content

    @State private var isAnimating = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                // Animated Glyph with per-step animation
                ZStack {
                    // Pulse rings for spin animation
                    if iconAnimation == .spin {
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .stroke(iconColor.opacity(0.15), lineWidth: 1)
                                .frame(width: 140 + CGFloat(i) * 30, height: 140 + CGFloat(i) * 30)
                                .scaleEffect(isAnimating ? 1.2 : 0.9)
                                .opacity(isAnimating ? 0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 2.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.8),
                                    value: isAnimating
                                )
                        }
                    }

                    // Glow ring for rise animation
                    if iconAnimation == .rise {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [iconColor.opacity(isAnimating ? 0.25 : 0.08), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 140, height: 140)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: iconColor.opacity(0.15), radius: 24, x: 0, y: 12)
                        )
                        .modifier(IconAnimationModifier(animation: iconAnimation, isAnimating: isAnimating))
                }
                .scaleEffect(showIcon ? 1 : 0.6)
                .opacity(showIcon ? 1 : 0)

                // Copy
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .offset(y: showTitle ? 0 : 20)
                        .opacity(showTitle ? 1 : 0)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .offset(y: showSubtitle ? 0 : 15)
                        .opacity(showSubtitle ? 1 : 0)
                }

                // Input Component
                DashboardCard(title: "", icon: "") {
                    content
                }
                .padding(.horizontal, 24)
                .offset(y: showCard ? 0 : 20)
                .opacity(showCard ? 1 : 0)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startEntranceAnimations()
        }
    }

    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
            showIcon = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
            showTitle = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45)) {
            showSubtitle = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.6)) {
            showCard = true
        }
        // Start icon loop animation after entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            isAnimating = true
        }
    }
}

// MARK: - Icon Animation Modifier
private struct IconAnimationModifier: ViewModifier {
    let animation: IconAnimation
    let isAnimating: Bool

    func body(content: Content) -> some View {
        switch animation {
        case .pulse:
            content
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)

        case .wiggle:
            content
                .rotationEffect(.degrees(isAnimating ? 8 : -8))
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isAnimating)

        case .tilt:
            content
                .rotationEffect(.degrees(isAnimating ? 12 : -12))
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)

        case .bounce:
            content
                .offset(y: isAnimating ? -6 : 0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

        case .spin:
            content
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 8.0).repeatForever(autoreverses: false), value: isAnimating)

        case .rise:
            content
                .offset(y: isAnimating ? -8 : 4)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)

        case .ring:
            content
                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
        }
    }
}
```

**Step 2: Update all step view references to pass `iconAnimation` and `iconColor`**

Update the step views in `OnboardingView`:

```swift
// nameStep - wiggle
private var nameStep: some View {
    AnimatedOnboardingPage(
        title: "Let's get acquainted",
        subtitle: "What should we call you to keep things personal?",
        iconName: "person.wave.2.fill",
        iconAnimation: .wiggle,
        iconColor: Theme.lagoon
    ) { ... }
}

// weightStep - tilt
private var weightStep: some View {
    AnimatedOnboardingPage(
        title: "Tailored to your body",
        subtitle: "We use your weight and preferred units to calculate a baseline hydration goal.",
        iconName: "scalemass.fill",
        iconAnimation: .tilt,
        iconColor: Theme.lagoon
    ) { ... }
}

// activityStep - bounce
private var activityStep: some View {
    AnimatedOnboardingPage(
        title: "Built for your lifestyle",
        subtitle: "More movement means more water. How active are you on an average day?",
        iconName: "figure.run",
        iconAnimation: .bounce,
        iconColor: Theme.coral
    ) { ... }
}

// goalStep - spin
private var goalStep: some View {
    AnimatedOnboardingPage(
        title: "Target your hydration",
        subtitle: "We'll suggest a dynamic goal, or you can take control and set a custom daily target.",
        iconName: "target",
        iconAnimation: .spin,
        iconColor: Theme.sun
    ) { ... }
}

// scheduleStep - rise
private var scheduleStep: some View {
    AnimatedOnboardingPage(
        title: "Fits your day",
        subtitle: "When does your day begin and end? We'll only send reminders while you're awake.",
        iconName: "sun.and.horizon.fill",
        iconAnimation: .rise,
        iconColor: Theme.sun
    ) { ... }
}

// remindersStep - ring
private var remindersStep: some View {
    AnimatedOnboardingPage(
        title: "Stay on track",
        subtitle: "Let us gently nudge you throughout the day so you never fall behind.",
        iconName: "bell.and.waves.left.and.right.fill",
        iconAnimation: .ring,
        iconColor: Theme.lavender
    ) { ... }
}
```

**Step 3: Build and verify**

Run: Build in Xcode. Navigate through each step and verify each icon has its unique animation and content stagger-animates in.

**Step 4: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): add per-step themed icon animations and staggered entrances"
```

---

### Task 3: Add Selection Micro-Interactions

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Step 1: Enhance activity level buttons with haptics and animated transitions**

In `activityStep`, update the button action and checkmark:

- Add `Haptics.selection()` in the button action
- Add `transition(.scale.combined(with: .opacity))` to the checkmark Image
- Animate the selected button with a brief scale spring

**Step 2: Add haptics to all toggles**

In `activityStep`, `goalStep`, `remindersStep` — add `Haptics.selection()` inside each `.onChange` handler.

**Step 3: Add animated reveal for custom goal slider**

In `goalStep`, wrap the conditional `if customGoalEnabled` block with an explicit transition:

```swift
if customGoalEnabled {
    VStack(spacing: 16) { ... }
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

And ensure the `customGoalEnabled` toggle triggers with animation:

```swift
Toggle("Set a custom daily goal", isOn: $customGoalEnabled)
    .tint(Theme.lagoon)
    .font(.headline)
    .onChange(of: customGoalEnabled) { _, _ in
        Haptics.selection()
    }
```

Wrap the whole VStack in `goalStep` with `.animation(Theme.fluidSpring, value: customGoalEnabled)`.

**Step 4: Build and verify**

Run: Build in Xcode. Tap activity levels (should feel haptic feedback, checkmark animates), toggle custom goal (slider slides in from top), toggle reminders (haptic feedback).

**Step 5: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): add selection micro-interactions and haptic feedback"
```

---

### Task 4: Polish Navigation Bar

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Step 1: Add step counter and shimmer to the navigation bar**

Replace the `navigationBar` computed property with an enhanced version:

```swift
private var navigationBar: some View {
    VStack(spacing: 12) {
        // Step counter
        Text("\(step + 1) of \(totalSteps)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .animation(Theme.quickSpring, value: step)

        HStack {
            // Back button with animated fade
            Button(action: {
                Haptics.selection()
                withAnimation(Theme.fluidSpring) {
                    step -= 1
                }
            }) {
                Text("Back")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(BouncyButtonStyle())
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)
            .animation(Theme.fluidSpring, value: step)

            Spacer()

            // Continue / Start button
            Button(action: {
                Haptics.impact(.medium)
                if step == totalSteps - 1 {
                    finishOnboarding()
                } else {
                    withAnimation(Theme.fluidSpring) {
                        step += 1
                    }
                }
            }) {
                Text(step == totalSteps - 1 ? "Start" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Theme.lagoon)
                    .clipShape(Capsule())
                    .shadow(color: Theme.lagoon.opacity(0.3), radius: 8, y: 4)
                    .overlay(
                        Group {
                            if step == totalSteps - 1 {
                                Capsule()
                                    .fill(.clear)
                                    .shimmer()
                            }
                        }
                    )
            }
            .buttonStyle(BouncyButtonStyle())
            .animation(Theme.quickSpring, value: step)
        }
    }
}
```

**Step 2: Build and verify**

Run: Build in Xcode. Verify step counter shows "1 of 7" and transitions smoothly. On last step, "Start" button has shimmer effect. Back button fades smoothly.

**Step 3: Commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): polish navigation bar with step counter and shimmer"
```

---

### Task 5: Final Polish and Visual Verification

**Files:**
- Modify: `WaterQuest/Views/OnboardingView.swift`

**Step 1: Test full flow end-to-end**

Build and run the app. Reset onboarding if needed (via settings or deleting app data). Walk through all 7 steps verifying:

- Water drop progress indicator fills correctly
- Each step has unique icon animation
- Content stagger-animates on each page
- Activity level selection has haptic feedback and animated checkmark
- Toggle interactions feel responsive with haptics
- Custom goal slider slides in/out smoothly
- Navigation counter transitions between numbers
- "Start" button has shimmer on final step
- Back button fades in/out properly

**Step 2: Fix any visual issues found during testing**

Adjust animation timings, spacing, or colors as needed.

**Step 3: Final commit**

```bash
git add WaterQuest/Views/OnboardingView.swift
git commit -m "feat(onboarding): final polish and animation timing adjustments"
```
