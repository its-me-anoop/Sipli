import SwiftUI
#if SIRI_AI_PREVIEW
import AppIntents
#endif

extension View {
    /// Tells Siri which logged drink this view shows, so on iOS 27.3 a
    /// person can say "change this to 400 ml" or "delete that coffee" while
    /// looking at it. A no-op on earlier SDKs and OS versions.
    @ViewBuilder
    func siriDrinkEntry(_ id: UUID) -> some View {
        #if SIRI_AI_PREVIEW
        if #available(iOS 27.3, *) {
            appEntityIdentifier(EntityIdentifier(for: DrinkEntryEntity.self, identifier: id))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// Side effects the Siri AI layer needs after the hydration log changes.
/// Callers stay unaware of SDK gating.
enum SiriAIEffects {
    /// Refreshes the Spotlight index Siri searches for logged drinks.
    @MainActor
    static func hydrationLogChanged() {
        #if SIRI_AI_PREVIEW
        if #available(iOS 27.3, *) {
            DrinkEntrySpotlightIndex.scheduleReindex()
        }
        #endif
    }
}
