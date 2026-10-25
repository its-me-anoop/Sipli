import SwiftUI

struct NameStep: View {
    @Binding var state: OnboardingState
    let onContinue: () -> Void
    @Environment(\.onboardingQuestionInHero) private var questionInHero

    @FocusState private var nameFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmed: String { state.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !questionInHero {
                            headline
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
                                .padding(.bottom, 28)
                        }

                        chatStack
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: trimmed.isEmpty)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)

                        Color.clear.frame(height: 1).id(Self.chatBottomID)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollDismissesKeyboard(.interactively)
                // Keep the field being typed in (and the bottle's reply)
                // visible above the keyboard on short screens.
                .onChange(of: nameFieldFocused) { _, focused in
                    guard focused else { return }
                    scrollToChatBottom(scroller, delay: 0.35)
                }
                .onChange(of: trimmed.isEmpty) { _, _ in
                    scrollToChatBottom(scroller, delay: 0.1)
                }
            }

            VStack {
                SipliCTA(title: "Continue", disabled: !state.canContinueFromName) {
                    nameFieldFocused = false
                    onContinue()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
        .task {
            do { try await Task.sleep(for: .seconds(0.4)) } catch { return }
            nameFieldFocused = true
        }
    }

    private static let chatBottomID = "name-chat-bottom"

    private func scrollToChatBottom(_ scroller: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                scroller.scrollTo(Self.chatBottomID, anchor: .bottom)
            }
        }
    }

    private var headline: some View {
        OnboardingQuestion(step: .name, fontSize: 44)
    }

    @ViewBuilder
    private var chatStack: some View {
        if questionInHero {
            OnboardingAnswerLayout {
                userInputBubble
                HStack(alignment: .bottom, spacing: 10) {
                    avatar
                    botBubble(trimmed.isEmpty ? "Hey there! I'm your bottle." : "Hi, \(trimmed). ✦ Nice to meet you.")
                    Spacer(minLength: 0)
                }
            }
        } else {
            singlePaneChat
        }
    }

    private var singlePaneChat: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Bot intro bubble
            if !questionInHero {
                HStack(alignment: .bottom, spacing: 10) {
                    avatar
                    botBubble("Hey there! I'm your bottle. What's your name?")
                    Spacer(minLength: 0)
                }
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
                .id("name-reply")
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(OnboardingPalette.card)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(OnboardingPalette.cardStroke, lineWidth: 1.5)
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
                .fill(OnboardingPalette.card)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 22,
                    style: .continuous
                )
                .stroke(OnboardingPalette.cardStroke, lineWidth: 1.5)
            )
            .frame(maxWidth: 280, alignment: .leading)
            .shadow(color: OnboardingPalette.ink.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var userInputBubble: some View {
        TextField("", text: $state.name, prompt: Text("Type your name…").foregroundColor(OnboardingPalette.paper.opacity(0.55)))
            .focused($nameFieldFocused)
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)
            .submitLabel(.done)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(OnboardingPalette.paper)
            .tint(OnboardingPalette.sun)
            .onSubmit {
                nameFieldFocused = false
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
