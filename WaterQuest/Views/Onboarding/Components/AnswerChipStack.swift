import SwiftUI

/// iOS-notification-style stack of previous answers. Shows the front (most recent)
/// chip fully, with older ones peeking out behind. Tapping toggles a fan-out so
/// the user can read every previous answer without consuming vertical space.
struct AnswerChipStack: View {
    let chips: [OnboardingAnswerChip]
    @State private var expanded: Bool = false

    var body: some View {
        if chips.isEmpty {
            EmptyView()
        } else {
            HStack {
                Spacer(minLength: 0)
                ZStack(alignment: .bottomTrailing) {
                    ForEach(Array(chips.enumerated()), id: \.element.id) { idx, chip in
                        chipView(chip, indexFromTop: chips.count - 1 - idx, isFront: idx == chips.count - 1)
                    }
                }
                .frame(minHeight: chipStackHeight, alignment: .bottomTrailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
                Haptics.selection()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(chips.count) previous answers — tap to \(expanded ? "collapse" : "expand")")
        }
    }

    private var chipStackHeight: CGFloat {
        // Reserve enough room for the front chip plus visible lips of stacked chips.
        expanded ? CGFloat(chips.count) * 48 : 64
    }

    private func chipView(_ chip: OnboardingAnswerChip, indexFromTop: Int, isFront: Bool) -> some View {
        // Behaviour mirrors the design's nth-last-child rules.
        let collapsed = collapsedTransform(indexFromTop: indexFromTop)
        let expandedT = expandedTransform(indexFromTop: indexFromTop)
        let t = expanded ? expandedT : collapsed
        return ChipBubble(chip: chip, isFront: isFront)
            .scaleEffect(t.scale, anchor: .bottomTrailing)
            .offset(x: 0, y: t.offsetY)
            .opacity(t.opacity)
            .saturation(t.saturation)
            .zIndex(Double(10 - indexFromTop))
    }

    private struct Transform {
        var offsetY: CGFloat
        var scale: CGFloat
        var opacity: Double
        var saturation: Double = 1
    }

    private func collapsedTransform(indexFromTop: Int) -> Transform {
        switch indexFromTop {
        case 0: return Transform(offsetY: 0, scale: 1.0, opacity: 1.0)
        case 1: return Transform(offsetY: -12, scale: 0.96, opacity: 0.92)
        case 2: return Transform(offsetY: -22, scale: 0.92, opacity: 0.7, saturation: 0.9)
        case 3: return Transform(offsetY: -30, scale: 0.88, opacity: 0.45)
        default: return Transform(offsetY: -36, scale: 0.84, opacity: 0.22)
        }
    }

    private func expandedTransform(indexFromTop: Int) -> Transform {
        switch indexFromTop {
        case 0: return Transform(offsetY: 0, scale: 1.0, opacity: 1.0)
        case 1: return Transform(offsetY: -46, scale: 1.0, opacity: 0.95)
        case 2: return Transform(offsetY: -88, scale: 1.0, opacity: 0.85)
        case 3: return Transform(offsetY: -130, scale: 1.0, opacity: 0.7)
        default: return Transform(offsetY: -172, scale: 1.0, opacity: 0.55)
        }
    }
}

private struct ChipBubble: View {
    let chip: OnboardingAnswerChip
    let isFront: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(chip.label)
                .font(.sipliMono(10, weight: .medium))
                .tracking(1)
                .foregroundStyle(isFront ? Color.white.opacity(0.55) : OnboardingPalette.ink3)

            Text(chip.value)
                .font(.editorialSerif(16))
                .italic()
                .foregroundStyle(isFront ? Color.white : OnboardingPalette.ink)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 4,
                topTrailingRadius: 14,
                style: .continuous
            )
            .fill(isFront ? OnboardingPalette.ink : OnboardingPalette.ink.opacity(0.07))
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 4,
                topTrailingRadius: 14,
                style: .continuous
            )
            .stroke(isFront ? OnboardingPalette.ink : OnboardingPalette.ink.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: isFront ? OnboardingPalette.ink.opacity(0.45) : .clear, radius: 18, x: 0, y: 6)
    }
}

#if DEBUG
#Preview("AnswerChipStack — 3 chips") {
    AnswerChipStack(chips: [
        OnboardingAnswerChip(id: "name", label: "NAME", value: "Maya"),
        OnboardingAnswerChip(id: "weight", label: "WEIGHT", value: "70 kg"),
        OnboardingAnswerChip(id: "activity", label: "ACTIVITY", value: "Steady")
    ])
    .padding(24)
    .frame(maxWidth: .infinity)
    .background(OnboardingPalette.paper)
}
#endif
