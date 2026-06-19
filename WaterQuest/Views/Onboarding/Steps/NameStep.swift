import SwiftUI

struct NameStep: View {
    @Binding var state: OnboardingState
    let onContinue: () -> Void

    @FocusState private var nameFieldFocused: Bool
    @State private var replyAppeared = false

    private var trimmed: String { state.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 28)

                    chatStack
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack {
                SipliCTA(title: "Continue", disabled: !state.canContinueFromName, action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFieldFocused = true
            }
        }
        .onChange(of: trimmed.isEmpty) { _, isEmpty in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                replyAppeared = !isEmpty
            }
        }
    }

    private var headline: some View {
        (Text("What should we\n").foregroundStyle(OnboardingPalette.ink)
            + Text("call you?").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(44, relativeTo: .largeTitle))
            .lineSpacing(-3)
    }

    private var chatStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Bot intro bubble
            HStack(alignment: .bottom, spacing: 10) {
                avatar
                botBubble("Hey there! I'm your bottle. What's your name?")
                Spacer(minLength: 0)
            }

            // User input bubble
            HStack {
                Spacer(minLength: 0)
                userInputBubble
            }

            // Bot reply (after user types)
            if !trimmed.isEmpty {
                HStack(alignment: .bottom, spacing: 10) {
                    avatar
                    botBubble("Hi, \(trimmed). ✦ Nice to meet you.")
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    Spacer(minLength: 0)
                }
                .id("reply-\(trimmed)") // re-animate on name change
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.894, green: 0.871, blue: 0.800), lineWidth: 1.5)
                )
                .shadow(color: OnboardingPalette.ink.opacity(0.04), radius: 2, x: 0, y: 2)
            SipliMark(size: 30)
        }
    }

    private func botBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(OnboardingPalette.ink)
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 22,
                    style: .continuous
                )
                .fill(Color.white)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 22,
                    style: .continuous
                )
                .stroke(Color(red: 0.894, green: 0.871, blue: 0.800), lineWidth: 1.5)
            )
            .frame(maxWidth: 280, alignment: .leading)
            .shadow(color: OnboardingPalette.ink.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var userInputBubble: some View {
        TextField("", text: $state.name, prompt: Text("Type your name…").foregroundColor(.white.opacity(0.45)))
            .focused($nameFieldFocused)
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)
            .submitLabel(.done)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(OnboardingPalette.paper)
            .tint(OnboardingPalette.sun)
            .onSubmit {
                if state.canContinueFromName { onContinue() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: 280, alignment: .leading)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 22,
                    style: .continuous
                )
                .fill(OnboardingPalette.ink)
            )
            .shadow(color: OnboardingPalette.ink.opacity(0.30), radius: 18, x: 0, y: 6)
    }
}
