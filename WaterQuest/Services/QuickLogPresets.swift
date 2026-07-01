import Foundation

/// Learns the user's habitual drinks and exposes one-tap logging presets.
/// Pure and injected — no store access — so it's unit-testable.
enum QuickLogPresets {
    struct Preset: Equatable, Identifiable {
        let fluidType: FluidType
        let amountML: Double
        var id: String { "\(fluidType.rawValue)-\(Int(amountML))" }
    }

    /// Amounts are bucketed to the nearest 50 mL so 240/250/260 count as one habit.
    static func roundedAmount(_ ml: Double) -> Double {
        (ml / 50).rounded() * 50
    }

    /// Top presets from the last 30 days of manual logging, most frequent
    /// first (ties broken by recency), padded with sensible defaults.
    /// When `allowAllFluids` is false (free tier), only water presets surface —
    /// mirroring the fluid-type premium gate in AddIntakeView.
    static func presets(
        from entries: [HydrationEntry],
        allowAllFluids: Bool,
        limit: Int = 3,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Preset] {
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return defaults(limit: limit) }

        struct Key: Hashable {
            let fluid: FluidType
            let amount: Double
        }
        var frequency: [Key: Int] = [:]
        var lastUsed: [Key: Date] = [:]

        for entry in entries where entry.date >= cutoff && entry.source == .manual {
            guard allowAllFluids || entry.fluidType == .water else { continue }
            let amount = roundedAmount(entry.volumeML)
            guard amount >= 50 else { continue }
            let key = Key(fluid: entry.fluidType, amount: amount)
            frequency[key, default: 0] += 1
            if let existing = lastUsed[key] {
                if entry.date > existing { lastUsed[key] = entry.date }
            } else {
                lastUsed[key] = entry.date
            }
        }

        let learned = frequency
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let l = lastUsed[lhs.key] ?? .distantPast
                let r = lastUsed[rhs.key] ?? .distantPast
                return l > r
            }
            .map { Preset(fluidType: $0.key.fluid, amountML: $0.key.amount) }

        var result: [Preset] = []
        for preset in learned where result.count < limit {
            result.append(preset)
        }
        for fallback in defaults(limit: limit) where result.count < limit {
            if !result.contains(where: { $0.id == fallback.id }) {
                result.append(fallback)
            }
        }
        return result
    }

    static func defaults(limit: Int = 3) -> [Preset] {
        Array(
            [
                Preset(fluidType: .water, amountML: 250),
                Preset(fluidType: .water, amountML: 500),
                Preset(fluidType: .water, amountML: 750),
            ].prefix(limit)
        )
    }
}
