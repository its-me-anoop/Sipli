import SwiftUI

/// Color palette specific to the redesigned onboarding flow.
/// Mirrors the design tokens from `Sipli Onboarding.html` so onboarding
/// has its own warm "paper" identity, separate from the rest-of-app theme.
enum OnboardingPalette {
    // Inks — `ink` mirrors `Theme.ink` (kept aliased here so existing call
    // sites resolve without churn). `ink2`/`ink3` are tier shades only used
    // inside onboarding.
    static let ink = Theme.ink
    static let ink2 = Color(red: 0.169, green: 0.227, blue: 0.322)       // #2B3A52
    static let ink3 = Color(red: 0.420, green: 0.478, blue: 0.573)       // #6B7A92

    // Paper backgrounds
    static let paper = Theme.paper                                        // #F4F1EA
    static let paper2 = Color(red: 0.929, green: 0.906, blue: 0.855)     // #EDE7DA
    static let paperOuter = Color(red: 0.910, green: 0.886, blue: 0.824) // #E8E2D2

    // Water — `water` mirrors `Theme.lagoon`.
    static let water = Theme.lagoon
    static let waterDeep = Color(red: 0.055, green: 0.247, blue: 0.745)  // #0E3FBE
    static let waterBright = Color(red: 0.310, green: 0.718, blue: 1.0)  // #4FB7FF

    // Accents — main accents now live on `Theme`; aliases here keep
    // existing onboarding call sites compiling.
    static let aqua = Color(red: 0.435, green: 0.890, blue: 0.824)       // #6FE3D2
    static let sun = Theme.sun
    static let coral = Theme.coral
    static let lilac = Theme.lavender
    static let mint = Color(red: 0.659, green: 0.902, blue: 0.714)       // #A8E6B6 — softer mint, used only in chips

    // Bottle palette
    enum Bottle {
        static let cap = Color(red: 0.839, green: 0.851, blue: 0.867)    // #D6D9DD
        static let capRing = Color(red: 0.910, green: 0.318, blue: 0.235) // #E8513C
        static let loop = Color(red: 0.910, green: 0.318, blue: 0.235)    // #E8513C
        static let blue = Color(red: 0.122, green: 0.616, blue: 0.867)    // #1F9DDD
        static let green = Color(red: 0.486, green: 0.769, blue: 0.341)   // #7CC457
        static let yellow = Color(red: 0.949, green: 0.816, blue: 0.290)  // #F2D04A
        static let orange = Color(red: 0.953, green: 0.604, blue: 0.227)  // #F39A3A
        static let waveLight = Color(red: 0.749, green: 0.902, blue: 0.957) // #BFE6F4
        static let waveDark = Color(red: 0.561, green: 0.827, blue: 0.933)  // #8FD3EE
        static let empty = Color(red: 0.910, green: 0.886, blue: 0.824)   // #E8E2D2
    }
}

extension Font {
    /// Editorial serif for headlines — falls back to SF Serif on iOS (close to Instrument Serif).
    static func editorialSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Mono face for steppers, labels, numerical readouts. SF Mono on iOS (close to Geist Mono).
    static func sipliMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
