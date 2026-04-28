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

    var onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var direction: OnboardingNavDirection = .forward
    @State private var state = OnboardingState()
    @State private var hasRequestedLocation = false

    var body: some View {
        ZStack {
            OnboardingPalette.paper.ignoresSafeArea()

            stepContainer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { @MainActor in
            // Sync the toggle with the system's actual HealthKit auth state —
            // if the user previously granted, surface that as ON; otherwise OFF.
            state.prefersHealthKit = healthKit.isAuthorized
        }
        .onChange(of: state.prefersHealthKit) { oldValue, newValue in
            handleHealthKitToggle(was: oldValue, now: newValue)
        }
        .onChange(of: state.prefersWeatherGoal) { oldValue, newValue in
            handleWeatherToggle(was: oldValue, now: newValue)
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

        // Premium-locked: roll back; the user will see the paywall after
        // onboarding completes (App-Store-friendly — no mid-onboard paywall).
        guard subscriptionManager.hasAccess(to: .healthKitSync) else {
            DispatchQueue.main.async { state.prefersHealthKit = false }
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
        guard subscriptionManager.hasAccess(to: .weatherGoals) else {
            DispatchQueue.main.async { state.prefersWeatherGoal = false }
            return
        }
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true
        Task {
            _ = await locationManager.requestWhenInUseAuthorizationAsync()
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
