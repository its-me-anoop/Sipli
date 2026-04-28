import SwiftUI

struct TargetStep: View {
    @Binding var state: OnboardingState
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let answers: [OnboardingAnswerChip]
    let onContinue: () -> Void
    let onBack: () -> Void

    private var hasWeatherPremium: Bool {
        subscriptionManager.hasAccess(to: .weatherGoals)
    }

    private var displayedML: Double { state.displayedTargetML }

    /// Goal with weather + (always-zero here) workout adjustments applied via
    /// the canonical GoalCalculator. Only meaningful when the user has the
    /// weather toggle on AND we have a snapshot.
    private var weatherAdjustedGoal: GoalBreakdown? {
        guard state.prefersWeatherGoal, let snapshot = weather.currentWeather else { return nil }
        let profile = UserProfile(
            name: state.name,
            unitSystem: state.unitSystem,
            weightKg: state.weightKg,
            activityLevel: state.activityLevel,
            customGoalML: state.customGoalML,
            remindersEnabled: true,
            wakeMinutes: state.wakeMinutes,
            sleepMinutes: state.sleepMinutes,
            prefersWeatherGoal: true,
            prefersHealthKit: false,
            smartRemindersEnabled: false
        )
        return GoalCalculator.dailyGoal(profile: profile, weather: snapshot, workout: nil)
    }

    private var canFetchWeather: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private var displayedFillFraction: Double {
        let v = displayedML
        return max(0.05, min(0.95, v / 4000.0))
    }

    private var displayedTopLine: String {
        switch state.unitSystem {
        case .metric: return String(format: "%.1f", displayedML / 1000.0)
        case .imperial: return String(format: "%.0f", state.unitSystem.amount(fromML: displayedML))
        }
    }
    private var displayedUnit: String {
        state.unitSystem == .metric ? "L" : "oz"
    }

    var body: some View {
        VStack(spacing: 0) {
            SipliTopBar(stepIndex: 4, total: OnboardingStep.displayedTotal, canGoBack: true, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AnswerChipStack(chips: answers)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    headline
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                    targetStage
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    customGoalToggle
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    weatherToggle
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                    if state.prefersWeatherGoal && hasWeatherPremium {
                        weatherAdjustmentCard
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Color.clear.frame(height: 16) // bottom breathing room
                }
            }
            .onChange(of: state.prefersWeatherGoal) { _, isOn in
                if isOn && hasWeatherPremium { fetchWeatherIfPossible() }
            }
            .task { @MainActor in
                if state.prefersWeatherGoal && hasWeatherPremium {
                    fetchWeatherIfPossible()
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.customGoalEnabled)

            VStack {
                SipliCTA(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
        .background(OnboardingPalette.paper)
    }

    private var headline: some View {
        (Text("Pour the perfect\n").foregroundStyle(OnboardingPalette.ink)
            + Text("daily amount.").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40))
            .lineSpacing(-2)
    }

    private var targetStage: some View {
        HStack(alignment: .center, spacing: 12) {
            SipliBottle(fill: displayedFillFraction, size: 110)

            // Vertical custom-goal slider sits between the bottle and the
            // numeric readout so its handle visually maps to the bottle's
            // water level.
            if state.customGoalEnabled {
                verticalGoalSlider
                    .frame(width: 28, height: 150)
                    .transition(.opacity)
            }

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(displayedTopLine)
                        .font(.editorialSerif(64, weight: .regular))
                        .foregroundStyle(OnboardingPalette.ink)
                        .contentTransition(.numericText())
                    Text(displayedUnit)
                        .font(.sipliMono(18, weight: .semibold))
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
                    .font(.sipliMono(11, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.sun)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(OnboardingPalette.ink))
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(minHeight: 200)
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

    private var verticalGoalSlider: some View {
        let r = state.customGoalRange()
        let pct = (state.customGoalValue - r.lowerBound) / (r.upperBound - r.lowerBound)
        return GeometryReader { proxy in
            let h = proxy.size.height
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(OnboardingPalette.ink.opacity(0.08))
                    .frame(width: 14, height: h)

                Capsule()
                    .fill(OnboardingPalette.water)
                    .frame(width: 14, height: max(0, pct * h))

                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(OnboardingPalette.water, lineWidth: 3))
                    .shadow(color: OnboardingPalette.water.opacity(0.3), radius: 4, x: 0, y: 4)
                    .offset(y: -(pct * h - 13))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in updateFromY(y: value.location.y, in: h, range: r) }
                    .onEnded { _ in Haptics.selection() }
            )
        }
    }

    private func updateFromY(y: CGFloat, in height: CGFloat, range: ClosedRange<Double>) {
        guard height > 0 else { return }
        let pct = max(0, min(1, 1.0 - (y / height)))
        let value = Double(range.lowerBound) + pct * (range.upperBound - range.lowerBound)
        let step = state.unitSystem == .metric ? 50.0 : 2.0
        let snapped = (value / step).rounded() * step
        let clamped = min(max(snapped, range.lowerBound), range.upperBound)
        if abs(clamped - state.customGoalValue) >= step / 2 {
            state.customGoalValue = clamped
        }
    }

    private var customGoalToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Set my own goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Override the suggestion")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
            SipliToggle(isOn: $state.customGoalEnabled, tint: OnboardingPalette.water)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Weather adjustment readout

    private var weatherAdjustmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch weather.status {
            case .idle where weather.currentWeather != nil:
                if let snapshot = weather.currentWeather, let breakdown = weatherAdjustedGoal {
                    weatherReadout(snapshot: snapshot, breakdown: breakdown)
                }
            case .loading:
                weatherLoading
            case .failed:
                weatherFailed
            case .idle where !canFetchWeather:
                // Permission still pending or denied — surface that quietly.
                weatherPermissionPending
            default:
                EmptyView()
            }

            // Apple Weather attribution — required by WeatherKit terms.
            Link(destination: Legal.weatherAttributionURL) {
                HStack(spacing: 4) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 9, weight: .medium))
                    Text("Weather")
                        .font(.sipliMono(10, weight: .medium))
                        .tracking(0.6)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(OnboardingPalette.ink3)
                .padding(.top, 4)
            }
            .accessibilityLabel("Weather data legal attribution")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }

    private func weatherReadout(snapshot: WeatherSnapshot, breakdown: GoalBreakdown) -> some View {
        let tempLabel = Formatters.temperatureString(celsius: snapshot.temperatureC, unit: state.unitSystem)
        let adjustML = breakdown.weatherAdjustmentML
        let totalML = breakdown.totalML

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: WeatherSnapshot.sfSymbol(for: snapshot.conditionKey))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.sun)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(snapshot.condition) · \(tempLabel)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                    Text(adjustmentSubtitle(adjustML: adjustML))
                        .font(.system(size: 12))
                        .foregroundStyle(OnboardingPalette.ink3)
                }
                Spacer()
            }

            HStack(alignment: .lastTextBaseline) {
                Text("New target")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
                Spacer()
                Text(formatVolume(ml: totalML))
                    .font(.editorialSerif(28, weight: .regular))
                    .foregroundStyle(OnboardingPalette.water)
                    .contentTransition(.numericText())
            }
        }
    }

    private var weatherLoading: some View {
        HStack(spacing: 10) {
            ProgressView().tint(OnboardingPalette.water)
            Text("Checking your local weather…")
                .font(.system(size: 13))
                .foregroundStyle(OnboardingPalette.ink3)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weatherFailed: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(OnboardingPalette.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't reach Weather right now")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("We'll retry once you're back online.")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weatherPermissionPending: some View {
        Text("Allow location access to see today's adjustment.")
            .font(.system(size: 12))
            .foregroundStyle(OnboardingPalette.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func adjustmentSubtitle(adjustML: Double) -> String {
        if adjustML > 0 {
            return "+\(Int(adjustML)) ml today"
        } else if adjustML < 0 {
            return "\(Int(adjustML)) ml today"
        }
        return "No adjustment today"
    }

    private func formatVolume(ml: Double) -> String {
        switch state.unitSystem {
        case .metric:
            return String(format: "%.1f L", ml / 1000.0)
        case .imperial:
            let oz = state.unitSystem.amount(fromML: ml)
            return "\(Int(oz)) oz"
        }
    }

    private func fetchWeatherIfPossible() {
        Task { @MainActor in
            await weather.refresh()
        }
    }

    private var weatherToggle: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.886, blue: 0.714))
                    .frame(width: 36, height: 36)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1.0, green: 0.541, blue: 0.122))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Adjust for weather")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Drink more on hot days")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
            PremiumGatedToggle(
                isOn: $state.prefersWeatherGoal,
                isPremium: hasWeatherPremium,
                onPaywall: {
                    Haptics.selection()
                    subscriptionManager.presentPaywall(for: .weatherGoals)
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if !hasWeatherPremium {
                Haptics.selection()
                subscriptionManager.presentPaywall(for: .weatherGoals)
            }
        }
        .accessibilityHint(hasWeatherPremium ? "" : "Premium feature. Opens upgrade screen.")
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}
