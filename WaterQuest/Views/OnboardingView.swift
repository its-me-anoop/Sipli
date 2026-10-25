import SwiftUI
import UserNotifications
import CoreLocation

/// Coordinator for the redesigned Sipli onboarding (8 screens). Owns the
/// `OnboardingState`, drives step transitions with vertical slide animations,
/// requests permissions just-in-time when the user enables a feature.
struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var weather: WeatherClient

    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFinishing = false
    @State private var step: OnboardingStep = .welcome
    @State private var direction: OnboardingNavDirection = .forward
    @State private var state = OnboardingState()
    @State private var hasRequestedLocation = false
    @State private var questionHeight: CGFloat = 104
    @Environment(\.simulatedFoldGlobalFrame) private var simulatedFold

    var body: some View {
        // Hosted in a NavigationStack so the back control is the system's own
        // navigation-bar button (Liquid Glass on iOS 26).
        NavigationStack {
            content
                .toolbar {
                    if canGoBack {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                Haptics.selection()
                                retreat()
                            } label: {
                                Label("Back", systemImage: "chevron.backward")
                            }
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
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

    private var content: some View {
        GeometryReader { proxy in
            // Fold (book / tabletop) or wide landscape: the bottle gets a pane
            // of its own and the step content gets the other.
            let arrangement = FoldResolver.arrangement(
                in: proxy,
                simulatedGlobal: simulatedFold,
                allowsLandscapeSplit: true,
                landscapeLeadingFraction: 0.4
            )
            // When vertical space is tight (keyboard up / very short screen),
            // a hero bottle would crowd the text and clip the headline — so it
            // collapses to the small top-right corner, freeing room for content.
            // A split layout always has room for the hero bottle.
            let constrained = proxy.size.height < 560
            let placement: VesselPlacement = arrangement.isSplit
                ? .hero
                : ((step.vesselPlacement == .hero && constrained) ? .compact : step.vesselPlacement)
            let questionInHero = arrangement.isSplit && step.hasQuestion
            let geo = vesselGeometry(placement: placement, in: proxy.size, arrangement: arrangement,
                                     questionHeight: questionInHero ? questionHeight + 12 : 0)
            ZStack(alignment: .top) {
                OnboardingPalette.paper.ignoresSafeArea()

                // Per-step content. The top inset equals the bottle's actual
                // bottom edge (+gap), so content can never overlap the vessel.
                // Done paints a full-bleed gradient/confetti and handles its own
                // text inset internally, so it isn't padded here.
                stepContainer(insetForDone: geo.contentInset, leadingInsetForDone: geo.contentLeading)
                    .environment(\.onboardingQuestionInHero, questionInHero)
                    .padding(.top, step == .done ? 0 : geo.contentInset)
                    .padding(.leading, step == .done ? 0 : geo.contentLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if questionInHero {
                    let pane = questionPaneSize(in: proxy.size, arrangement: arrangement)
                    let columns = questionUsesColumns(in: proxy.size, arrangement: arrangement)
                    OnboardingQuestion(step: step, fontSize: 36)
                        .padding(.horizontal, 24)
                        .padding(.top, columns ? 0 : 8)
                        .frame(width: columns ? pane.width * 0.52 : pane.width, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionHeight = $0 }
                        .frame(height: columns ? pane.height : questionHeight, alignment: .leading)
                        .position(x: columns ? pane.width * 0.74 : pane.width / 2,
                                  y: columns ? pane.height / 2 : questionHeight / 2)
                        .accessibilitySortPriority(2)
                }

                // The single persistent vessel. Size + position are derived from
                // the screen, so they spring smoothly between steps (the
                // navigation `withAnimation` drives the interpolation).
                OnboardingVessel(
                    fill: step.fillFraction,
                    placement: placement,
                    isComplete: step.isComplete,
                    size: geo.width
                )
                .position(geo.center)
                .allowsHitTesting(false)
                // Smooth respring whenever the bottle resizes or relocates
                // (e.g. hero → top-right corner when the keyboard appears).
                .animation(.smooth(duration: 0.5), value: placement)
                .animation(.smooth(duration: 0.45), value: geo.width)

                // Accessibility: the vessel is decorative/hidden, so expose
                // setup progress here as a small, early-sorted element.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Setup progress")
                    .accessibilityValue(step == .done ? "Setup complete" : "Step \(step.rawValue + 1) of \(OnboardingStep.displayedTotal)")
                    .accessibilitySortPriority(1)
            }
        }
    }

    /// Back button is shown on every step except the first and the celebration.
    private var canGoBack: Bool {
        step != .welcome && step != .done
    }

    /// Resolved layout for the persistent vessel: a dynamic bottle width, its
    /// centre point, and the content inset (the bottle's bottom edge + a gap).
    /// Driving the inset from the bottle's real geometry guarantees content can
    /// never overlap the vessel, and the width scales down on shorter screens.
    private struct VesselGeometry {
        var width: CGFloat
        var center: CGPoint
        var contentInset: CGFloat
        /// Leading offset of the content column (non-zero in side-by-side).
        var contentLeading: CGFloat = 0
    }

    private func questionPaneSize(in size: CGSize, arrangement: PaneArrangement) -> CGSize {
        switch arrangement {
        case let .sideBySide(leading, _, _): CGSize(width: leading, height: size.height)
        case let .stacked(top, _, _): CGSize(width: size.width, height: top)
        case .single: size
        }
    }

    private func questionUsesColumns(in size: CGSize, arrangement: PaneArrangement) -> Bool {
        let pane = questionPaneSize(in: size, arrangement: arrangement)
        return step.hasQuestion && pane.width >= 440
            && (pane.width > pane.height * 1.1 || size.width > size.height)
    }

    private func vesselGeometry(placement: VesselPlacement, in size: CGSize, arrangement: PaneArrangement,
                                questionHeight: CGFloat = 0) -> VesselGeometry {
        // The navigation bar (with the back button) sits above this proxy, so
        // only a small breathing gap is needed at the top.
        let backRowBottom: CGFloat = 8
        let columns = questionUsesColumns(in: size, arrangement: arrangement)
        switch arrangement {
        case let .sideBySide(leading, gap, _):
            // Bottle centred in the leading pane, below the back button row.
            let start = backRowBottom + (columns ? 0 : questionHeight)
            let available = max(1, size.height - start - 24)
            // The asset has generous transparent side margins. Its canvas
            // can extend beyond this pane while the visible bottle stays
            // inside it, filling the available height instead of a tiny cap.
            let bottlePaneWidth = columns ? leading * 0.48 : leading
            let width = min(bottlePaneWidth * 1.4, available / 1.36)
            let centerY = start + available / 2
            return VesselGeometry(
                width: width,
                center: CGPoint(x: bottlePaneWidth / 2, y: centerY),
                contentInset: 8,
                contentLeading: leading + gap
            )
        case let .stacked(top, gap, _):
            // Tabletop: bottle stands in the upper half, content sits below the fold.
            let start = backRowBottom + (columns ? 0 : questionHeight)
            let available = max(1, top - start - 12)
            let bottlePaneWidth = columns ? size.width * 0.48 : size.width
            let width = min(bottlePaneWidth * 1.2, available / 1.36)
            let height = width * 1.36
            let centerY = start + available / 2
            return VesselGeometry(
                width: width,
                center: CGPoint(x: bottlePaneWidth / 2, y: min(centerY, top - height / 2 - 6)),
                contentInset: top + gap
            )
        case .single:
            break
        }

        switch placement {
        case .hero:
            let topGap: CGFloat = 14
            let bottomGap: CGFloat = 20
            // Give the bottle more presence while scaling it down on shorter
            // screens. The content inset below follows its enlarged bounds.
            let availableHeight = size.height * ((step == .welcome || step == .done) ? 0.48 : 0.32)
            let width = min(size.width * 1.1, max(150, availableHeight / 1.36))
            let height = width * 1.36
            let centerY = backRowBottom + topGap + height / 2
            let inset = centerY + height / 2 + bottomGap
            return VesselGeometry(
                width: width,
                center: CGPoint(x: size.width / 2, y: centerY),
                contentInset: inset
            )
        case .compact:
            // Keep the entire compact vessel inside the content bounds and
            // start the question below its base, including on the cover display.
            return VesselGeometry(
                width: 60,
                center: CGPoint(x: size.width - 50, y: 42),
                contentInset: 88
            )
        }
    }

    @ViewBuilder
    private func stepContainer(insetForDone: CGFloat, leadingInsetForDone: CGFloat) -> some View {
        Group {
            switch step {
            case .welcome:
                WelcomeStep(onContinue: advance)
            case .name:
                NameStep(state: $state, onContinue: advance)
            case .weight:
                WeightStep(state: $state, onContinue: advance)
            case .activity:
                ActivityStep(state: $state, onContinue: advance)
            case .target:
                TargetStep(state: $state, onContinue: advance)
            case .schedule:
                ScheduleStep(state: $state, onContinue: advance)
            case .notifications:
                NotificationsStep(state: $state,
                                  onFinish: { Task { await finishToDone() } })
            case .done:
                DoneStep(state: state, topInset: insetForDone, leadingInset: leadingInsetForDone, onFinish: completeAndExit)
            }
        }
        .id(step)
        .transition(slideTransition)
    }

    private var slideTransition: AnyTransition {
        if reduceMotion { return .opacity }
        // The whole content block glides + fades + subtly scales in, so every
        // element on the step animates together with the same smooth feel.
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 28)).combined(with: .scale(scale: 0.98, anchor: .top)),
                removal: .opacity.combined(with: .offset(y: -28)).combined(with: .scale(scale: 0.98, anchor: .top))
            )
        case .backward:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -28)).combined(with: .scale(scale: 0.98, anchor: .bottom)),
                removal: .opacity.combined(with: .offset(y: 28)).combined(with: .scale(scale: 0.98, anchor: .bottom))
            )
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard let next = step.next() else { return }
        direction = .forward
        withAnimation(.smooth(duration: 0.5)) {
            step = next
        }
    }

    private func retreat() {
        guard let prev = step.previous() else { return }
        direction = .backward
        withAnimation(.smooth(duration: 0.5)) {
            step = prev
        }
    }

    // MARK: - Permission handling

    private func handleHealthKitToggle(was oldValue: Bool, now newValue: Bool) {
        // Toggling OFF: just update the flag; iOS doesn't allow programmatic
        // permission revocation, but the user opting out from inside the app
        // means we shouldn't read Health data going forward.
        guard newValue, !oldValue else { return }

        // Non-premium users see a paywall pill instead of this toggle, so
        // direct user taps can't reach this branch. Roll back defensively
        // (in case state is set programmatically) and surface the paywall.
        guard subscriptionManager.hasAccess(to: .healthKitSync) else {
            DispatchQueue.main.async { state.prefersHealthKit = false }
            subscriptionManager.presentPaywall(for: .healthKitSync)
            return
        }

        // Already authorized — leaving the toggle on is correct, no dialog
        // needed (iOS would suppress it anyway).
        if healthKit.isAuthorized { return }

        Task { @MainActor in
            await healthKit.requestAuthorization()
            // If the user denied or dismissed the dialog, snap the toggle
            // back so its visible state matches actual auth.
            if !healthKit.isAuthorized {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    state.prefersHealthKit = false
                }
                Haptics.warning()
            } else {
                Haptics.success()
            }
        }
    }

    private func handleWeatherToggle(was oldValue: Bool, now newValue: Bool) {
        guard newValue, !oldValue else { return }
        // Non-premium users see a paywall pill in place of this toggle, so
        // hitting this branch from a tap is impossible. Defensively roll the
        // flag back if it's set programmatically (e.g. from persisted state)
        // and surface the paywall.
        guard subscriptionManager.hasAccess(to: .weatherGoals) else {
            DispatchQueue.main.async { state.prefersWeatherGoal = false }
            subscriptionManager.presentPaywall(for: .weatherGoals)
            return
        }
        Task { @MainActor in
            let status = await locationManager.requestWhenInUseAuthorizationAsync()
            hasRequestedLocation = true
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                await weather.refresh()
            } else {
                Haptics.warning()
            }
        }
    }

    // MARK: - Completion

    @MainActor
    private func finishToDone() async {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        // Notification permission requested as we enter the celebration screen.
        await notifier.requestAuthorization()
        await MainActor.run { advance() }
    }

    private func completeAndExit() {
        let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)

        store.updateProfile { profile in
            profile.name = trimmedName
            profile.unitSystem = state.unitSystem
            profile.weightKg = state.weightKg
            profile.activityLevel = state.activityLevel
            profile.customGoalML = state.customGoalML
            profile.remindersEnabled = true
            profile.wakeMinutes = state.wakeMinutes
            profile.sleepMinutes = state.sleepMinutes
            profile.prefersWeatherGoal = state.prefersWeatherGoal
            profile.prefersHealthKit = state.prefersHealthKit
        }

        // Persist cadence as a UserDefault for the NotificationScheduler to read later.
        UserDefaults.standard.set(state.cadence.rawValue, forKey: "onboarding.reminderCadence")
        UserDefaults.standard.set(state.cadence.dailyCount, forKey: "onboarding.reminderDailyCount")

        notifier.scheduleReminders(context: store.buildNotificationContext())
        Haptics.success()
        onComplete()
    }
}

#if DEBUG
#Preview("Onboarding — Light") {
    PreviewEnvironment {
        OnboardingView { }
    }
    .preferredColorScheme(.light)
}
#endif
