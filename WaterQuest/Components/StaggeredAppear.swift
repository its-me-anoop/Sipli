import SwiftUI

/// Fades content in with a slight rise, delayed by its position, so a stack
/// of cards arrives as a cascade instead of a slab. One-shot per view life;
/// collapses to a plain fade under Reduce Motion.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                withAnimation(Theme.fluidSpring.delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Position-delayed entrance for stacked dashboard cards.
    func staggeredAppear(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
