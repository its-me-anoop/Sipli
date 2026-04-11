import Foundation

/// Date-gated configuration for the Earth Day 2026 in-app event.
///
/// The entire event (banner, pledge, coach overrides, insights tile, etc.) is
/// controlled by `isActive(on:)`. Changing the dates in one place turns the
/// whole experience on or off so no feature leaks past Earth Week.
enum EarthDayEvent {
    /// Earth Week starts at the beginning of April 20, 2026.
    static let startComponents = DateComponents(year: 2026, month: 4, day: 20)

    /// Earth Week ends at the beginning of April 27, 2026 (exclusive).
    static let endComponents = DateComponents(year: 2026, month: 4, day: 27)

    /// Earth Day itself — April 22, 2026.
    static let earthDayComponents = DateComponents(year: 2026, month: 4, day: 22)

    /// Name of the alternate app icon bundle for the Earth Day variant.
    /// Matches the `EarthDayIcon.icon` bundle registered via
    /// `ASSETCATALOG_COMPILER_ALTERNATE_APP_ICON_NAMES` in project.yml.
    static let alternateIconName = "EarthDayIcon"

    /// Flip to `true` once the `EarthDayIcon.icon` bundle ships with artwork
    /// and `ASSETCATALOG_COMPILER_ALTERNATE_APP_ICON_NAMES` is wired up in
    /// project.yml. Keeping this `false` hides the Settings toggle so users
    /// never see a broken icon picker before the artwork lands.
    static var alternateIconAvailable: Bool { false }

    /// Returns `true` when the given date falls within Earth Week
    /// (inclusive of April 20, exclusive of April 27).
    static func isActive(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents) else {
            return false
        }
        return date >= start && date < end
    }

    /// Returns `true` when the given date is Earth Day itself (April 22, 2026).
    static func isEarthDay(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let earthDay = calendar.date(from: earthDayComponents) else { return false }
        return calendar.isDate(date, inSameDayAs: earthDay)
    }

    /// Number of entries logged between the start of Earth Week and the given date
    /// (capped at the Earth Week end). Used by the Insights tile to surface a
    /// "sips this Earth Week" count without fabricating any eco metric.
    static func entriesInEarthWeek(
        _ entries: [HydrationEntry],
        upTo date: Date = Date(),
        calendar: Calendar = .current
    ) -> [HydrationEntry] {
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents) else {
            return []
        }
        let cutoff = min(date, end)
        return entries.filter { $0.date >= start && $0.date < cutoff }
    }
}
