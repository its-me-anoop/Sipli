import SwiftUI

struct ScheduleStep: View {
    @Binding var state: OnboardingState
    let onContinue: () -> Void
    @Environment(\.onboardingQuestionInHero) private var questionInHero

    private enum ActiveHandle { case wake, sleep }

    @State private var dragging: ActiveHandle? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !questionInHero {
                        headline
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)
                    }

                    Text("Drag the sun and moon. We'll only nudge you during waking hours.")
                        .font(.system(size: 15))
                        .foregroundStyle(OnboardingPalette.ink3)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    OnboardingAnswerLayout {
                        dial
                        readout
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }

            VStack {
                SipliCTA(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
    }

    private var headline: some View {
        OnboardingQuestion(step: .schedule)
    }

    private var dial: some View {
        GeometryReader { proxy in
            dial(diameter: min(320, proxy.size.width))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private func dial(diameter dialSize: CGFloat) -> some View {
        let radius = max(40, dialSize / 2 - 48)
        return ZStack {
            // Night ring (background)
            Circle()
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 22)
                .frame(width: radius * 2, height: radius * 2)

            // Hour ticks
            ForEach(0..<24) { i in
                let isMajor = i % 6 == 0
                Capsule()
                    .fill(OnboardingPalette.ink.opacity(isMajor ? 0.5 : 0.18))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 8 : 4)
                    .offset(y: -(radius + 20))
                    .rotationEffect(.degrees(Double(i) / 24.0 * 360))
            }

            // Hour labels at 0/6/12/18
            ForEach([0, 6, 12, 18], id: \.self) { h in
                Text(String(format: "%02d", h))
                    .font(.sipliMono(11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(OnboardingPalette.ink3)
                    .offset(
                        x: CGFloat(sin(Double(h) / 24 * 2 * .pi)) * (radius + 36),
                        y: -CGFloat(cos(Double(h) / 24 * 2 * .pi)) * (radius + 36)
                    )
            }

            // Awake arc (gradient)
            AwakeArc(wakeHour: state.wakeHour, sleepHour: state.sleepHour)
                .stroke(
                    AngularGradient(
                        colors: [OnboardingPalette.sun, OnboardingPalette.coral],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.wakeHour)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.sleepHour)

            // Center text
            VStack(spacing: 2) {
                Text(String(format: "%.1fh", state.awakeHours))
                    .font(.editorialSerif(44, weight: .regular, relativeTo: .largeTitle))
                    .foregroundStyle(OnboardingPalette.ink)
                    .contentTransition(.numericText())
                Text("AWAKE")
                    .font(.sipliMono(10, weight: .semibold, relativeTo: .caption2))
                    .tracking(2)
                    .foregroundStyle(OnboardingPalette.ink3)
            }

            // Wake handle
            handlePosition(hour: state.wakeHour, radius: radius) { offset in
                Circle()
                    .fill(OnboardingPalette.sun)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(OnboardingPalette.ink, lineWidth: 2.5))
                    .overlay(
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(OnboardingPalette.ink)
                    )
                    .offset(offset)
            }

            // Sleep handle
            handlePosition(hour: state.sleepHour, radius: radius) { offset in
                Circle()
                    .fill(OnboardingPalette.ink)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(OnboardingPalette.ink, lineWidth: 2.5))
                    .overlay(
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(OnboardingPalette.sun)
                    )
                    .offset(offset)
            }
        }
        .frame(width: dialSize, height: dialSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dialCenter = CGPoint(x: dialSize / 2, y: dialSize / 2)
                    let dx = value.location.x - dialCenter.x
                    let dy = value.location.y - dialCenter.y
                    let h = hourFrom(dx: dx, dy: dy)
                    if dragging == nil {
                        // Decide which handle is closer
                        let toWake = abs(((h - state.wakeHour) + 36).truncatingRemainder(dividingBy: 24) - 12)
                        let toSleep = abs(((h - state.sleepHour) + 36).truncatingRemainder(dividingBy: 24) - 12)
                        dragging = toWake < toSleep ? .wake : .sleep
                        Haptics.selection()
                    }
                    if dragging == .wake { state.wakeHour = h }
                    if dragging == .sleep { state.sleepHour = h }
                }
                .onEnded { _ in
                    dragging = nil
                    Haptics.selection()
                }
        )
    }

    @ViewBuilder
    private func handlePosition(hour: Double, radius: CGFloat, @ViewBuilder content: (CGSize) -> some View) -> some View {
        let angle = (hour / 24.0) * 360 - 90
        let dx = CGFloat(cos(angle * .pi / 180)) * radius
        let dy = CGFloat(sin(angle * .pi / 180)) * radius
        content(CGSize(width: dx, height: dy))
    }

    private func hourFrom(dx: CGFloat, dy: CGFloat) -> Double {
        var ang = atan2(Double(dx), -Double(dy)) * 180 / .pi
        if ang < 0 { ang += 360 }
        let raw = (ang / 360.0) * 24.0
        // Quarter-hour snap
        return (raw * 4).rounded() / 4
    }

    private var readout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { scheduleBlocks }
            VStack(alignment: .leading, spacing: 12) { scheduleBlocks }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.card)
        )
    }

    @ViewBuilder
    private var scheduleBlocks: some View {
        block(label: "WAKE", value: state.formatHour(state.wakeHour),
              iconBg: Color(red: 1.0, green: 0.886, blue: 0.714),
              iconFg: Color(red: 1.0, green: 0.541, blue: 0.122),
              symbol: "sun.max.fill")
        block(label: "SLEEP", value: state.formatHour(state.sleepHour),
              iconBg: OnboardingPalette.ink,
              iconFg: OnboardingPalette.sun,
              symbol: "moon.stars.fill")
    }

    private func block(label: String, value: String, iconBg: Color, iconFg: Color, symbol: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconFg)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.sipliMono(11, weight: .medium, relativeTo: .caption))
                    .tracking(0.6)
                    .foregroundStyle(OnboardingPalette.ink3)
                Text(value)
                    .font(.editorialSerif(22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(OnboardingPalette.ink)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AwakeArc: Shape {
    var wakeHour: Double
    var sleepHour: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(wakeHour, sleepHour) }
        set {
            wakeHour = newValue.first
            sleepHour = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle.degrees((wakeHour / 24) * 360 - 90)
        let end = Angle.degrees((sleepHour / 24) * 360 - 90)
        path.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}
