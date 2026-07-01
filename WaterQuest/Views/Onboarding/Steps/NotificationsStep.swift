import SwiftUI
import Combine

struct NotificationsStep: View {
    @Binding var state: OnboardingState
    let onFinish: () -> Void

    @State private var msgIdx = 0
    private let msgTimer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()

    private var firstName: String {
        let n = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "friend" : n
    }

    private var sampleMessages: [(time: String, body: String)] {
        [
            ("now", "\(firstName) — quick sip? 250ml gets you to 60%."),
            ("2m", "Your bottle is feeling lonely 🫧"),
            ("5m", "Halfway there. One glass of water = ✨")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                        .padding(.horizontal, 24)
                        .padding(.bottom, 26)

                    notifPreview
                        .padding(.horizontal, 24)
                        .padding(.bottom, 26)

                    cadenceRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .onReceive(msgTimer) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    msgIdx = (msgIdx + 1) % sampleMessages.count
                }
            }

            VStack {
                SipliCTA(title: "Start hydrating, \(firstName)", variant: .water, action: onFinish)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
    }

    private var headline: some View {
        (Text("How loud\nshould we ").foregroundStyle(OnboardingPalette.ink)
            + Text("nudge?").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40, relativeTo: .largeTitle))
            .lineSpacing(-2)
    }

    private var notifPreview: some View {
        ZStack {
            // Stack 2 (deepest)
            notifCardSurface()
                .frame(height: 110)
                .padding(.horizontal, 22)
                .opacity(0.4)
                .offset(y: 12)

            // Stack 1 (middle)
            notifCardSurface()
                .frame(height: 110)
                .padding(.horizontal, 12)
                .opacity(0.7)
                .offset(y: 6)

            // Front card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(OnboardingPalette.paper)
                            .frame(width: 28, height: 28)
                        SipliMark(size: 20)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(OnboardingPalette.ink.opacity(0.08), lineWidth: 1)
                    )
                    Text("SIPLI")
                        .font(.sipliMono(11, weight: .semibold, relativeTo: .caption))
                        .tracking(0.8)
                        .foregroundStyle(OnboardingPalette.ink3)
                    Spacer()
                    Text(sampleMessages[msgIdx].time)
                        .font(.system(size: 11))
                        .foregroundStyle(OnboardingPalette.ink3)
                }
                Text("Time for a sip 💧")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text(sampleMessages[msgIdx].body)
                    .font(.system(size: 13))
                    .foregroundStyle(OnboardingPalette.ink2)
                    .lineSpacing(2)
                    .id("msg-\(msgIdx)")
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .shadow(color: OnboardingPalette.ink.opacity(0.18), radius: 30, x: 0, y: 12)
            .padding(.horizontal, 0)
        }
        .frame(height: 130)
    }

    private func notifCardSurface() -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.7))
    }

    private var cadenceRow: some View {
        HStack(spacing: 8) {
            ForEach(ReminderCadence.allCases) { cadence in
                cadencePill(cadence)
            }
        }
    }

    private func cadencePill(_ c: ReminderCadence) -> some View {
        let selected = state.cadence == c
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                state.cadence = c
            }
        } label: {
            VStack(spacing: 4) {
                Text(c.perDayLabel)
                    .font(.editorialSerif(22, relativeTo: .title2))
                    .foregroundStyle(selected ? OnboardingPalette.paper : OnboardingPalette.ink)
                Text(c.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? OnboardingPalette.paper : OnboardingPalette.ink)
                Text(c.sublabel)
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? OnboardingPalette.paper.opacity(0.7) : OnboardingPalette.ink3)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? OnboardingPalette.ink : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? OnboardingPalette.ink : Color.clear, lineWidth: 2)
            )
            .shadow(color: selected ? OnboardingPalette.ink.opacity(0.4) : .clear, radius: 14, x: 0, y: 6)
            .offset(y: selected ? -2 : 0)
        }
        .buttonStyle(.plain)
    }
}
