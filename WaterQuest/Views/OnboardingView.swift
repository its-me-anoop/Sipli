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

    @State private var step: OnboardingStep = .welcome
    @State private var direction: OnboardingNavDirection = .forward
    @State private var state = OnboardingState()
    @State private var hasRequestedLocation = false

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

    // MARK: - Navigation

    private func advance() {
        guard let next = step.next() else { return }
        direction = .forward
        withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
            step = next
        }
    }

    private func retreat() {
        guard let prev = step.previous() else { return }
        direction = .backward
        withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
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

    private func finishToDone() async {
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
