import SwiftUI

/// "Spooky Season" — a limited-time Halloween hydration event.
///
/// The day is framed as brewing a potion: every drink adds an ingredient,
/// hitting the daily goal finishes the brew. Brew enough potions during the
/// season and the Cauldron Keeper badge is earned. While the season is live,
/// Home's bottle fills with potion purple and the widgets and Watch pick up
/// the same palette.
///
/// Free for everyone, but opt-in: not everyone celebrates Halloween, so
/// nothing Halloween shows until the user says yes in the invite popup or
/// in Settings. Copy stays generic Halloween — no film, character or
/// brand references (App Review guideline 5.2.1).
///
/// Compiled into the app, widget, Watch and Watch-widget targets, so it must
/// only depend on Foundation and SwiftUI.
enum SpookySeason {
    /// Runs a week past Halloween so users who update late still see it.
    static let seasonStart = DateComponents(year: 2026, month: 10, day: 24)
    static let seasonEnd = DateComponents(year: 2026, month: 11, day: 7)

    /// Brews (goal days in the season) that earn the Cauldron Keeper badge.
    static let brewsForCauldronKeeper = 5

    /// Shared app-group key so the widgets and Watch follow the in-app choice.
    static let themeDefaultsKey = "spookyThemeEnabled"
    /// Set once the invite popup has been answered (or dismissed) this season.
    static let invitePromptedKey = "spookySeason2026InvitePrompted"
    /// Parked by `sipli://spooky-season` until the main screen can respond,
    /// so a cold launch from the App Store event isn't lost behind the splash.
    static let deepLinkPendingKey = "spookySeasonDeepLinkPending"

    /// The App Store in-app event opens the app with `sipli://spooky-season`.
    static func isDeepLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "sipli" && url.host?.lowercased() == "spooky-season"
    }
    static let appGroupID = "group.com.waterquest.hydration"

    enum Phase: Equatable {
        case brewing       // before 13:00
        case simmering     // 13:00–20:00
        case witchingHour  // after 20:00, goal not met
        case brewed        // goal met
    }

    // MARK: - Window

    static func isActive(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard
            let start = calendar.date(from: seasonStart),
            let endDay = calendar.date(from: seasonEnd),
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDay))
        else { return false }
        return date >= calendar.startOfDay(for: start) && date < end
    }

    /// Whole days left in the season, counting today. 0 once it's over.
    static func daysLeft(from date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let endDay = calendar.date(from: seasonEnd) else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: endDay)).day ?? 0
        return max(0, days + 1)
    }

    static func isHalloween(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return parts.month == 10 && parts.day == 31
    }

    /// Whether the user opted in. Off until they say yes.
    static func isThemeEnabled(defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        (defaults?.object(forKey: themeDefaultsKey) as? Bool) ?? false
    }

    /// True when the event is live and the user opted in.
    static func showsTheme(on date: Date = Date(), defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        isActive(on: date) && isThemeEnabled(defaults: defaults)
    }

    // MARK: - Copy

    static func phase(progress: Double, now: Date = Date(), calendar: Calendar = .current) -> Phase {
        if progress >= 1.0 { return .brewed }
        let hour = calendar.component(.hour, from: now)
        if hour < 13 { return .brewing }
        if hour < 20 { return .simmering }
        return .witchingHour
    }

    /// Deterministic line for the current brew. `sips` is drinks logged today.
    static func incantation(phase: Phase, progress: Double, sips: Int, halloween: Bool = false) -> String {
        let pct = Int((progress * 100).rounded())
        switch phase {
        case .brewing:
            if sips == 0 {
                return halloween
                    ? "Happy Halloween. The cauldron's cold — first sip lights the fire."
                    : "The cauldron's cold. First sip lights the fire."
            }
            return "\(sips) ingredient\(sips == 1 ? "" : "s") in. Keep stirring."
        case .simmering:
            if progress >= 0.5 {
                return "Bubbling nicely at \(pct)%. The potion's taking shape."
            }
            return "Simmering at \(pct)%. Your brew needs more water."
        case .witchingHour:
            return "The witching hour. \(100 - pct)% left before the brew is done."
        case .brewed:
            return halloween
                ? "Potion brewed on Halloween night. Spooky and well hydrated."
                : "Potion brewed. Goal reached — the cauldron's full."
        }
    }

    /// Short line, e.g. "3 sips · 64%".
    static func cauldronLine(sips: Int, progress: Double) -> String {
        let pct = Int((progress * 100).rounded())
        return "\(sips) sip\(sips == 1 ? "" : "s") · \(pct)%"
    }

    static func brewsSummary(brews: Int) -> String {
        if brews >= brewsForCauldronKeeper {
            return "Cauldron Keeper earned — \(brews) potions brewed"
        }
        return "\(brews) potion\(brews == 1 ? "" : "s") brewed · Cauldron Keeper at \(brewsForCauldronKeeper)"
    }

    static func phaseLabel(_ phase: Phase) -> String {
        switch phase {
        case .brewing: return "Brewing"
        case .simmering: return "Simmering"
        case .witchingHour: return "Witching Hour"
        case .brewed: return "Brewed"
        }
    }

    // MARK: - Palette

    enum Palette {
        static let pumpkin = Color(red: 1.0, green: 0.478, blue: 0.102)   // #FF7A1A
        static let potion = Color(red: 0.482, green: 0.247, blue: 0.894)  // #7B3FE4
        static let slime = Color(red: 0.533, green: 0.894, blue: 0.333)   // #88E455
        static let midnight = Color(red: 0.106, green: 0.082, blue: 0.188) // #1B1530

        /// Purple for text, icons and control tints: potion in light mode, a
        /// lighter violet (#B094FF) in dark mode so it keeps its contrast on
        /// dark cards. Fills (bottle, bats, bars) keep `potion`.
        #if os(iOS)
        static let accent = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.690, green: 0.580, blue: 1.0, alpha: 1)
                : UIColor(red: 0.482, green: 0.247, blue: 0.894, alpha: 1)
        })
        #else
        static let accent = potion
        #endif
    }
}

// MARK: - Shapes (no Halloween SF Symbols exist, so draw them)

/// A simple bat silhouette, wings spread, in a 2:1 box.
struct BatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + w * x, y: rect.minY + h * y)
        }
        var path = Path()
        path.move(to: p(0.5, 0.30))
        // Ears
        path.addLine(to: p(0.46, 0.12))
        path.addLine(to: p(0.44, 0.30))
        // Left wing top edge
        path.addQuadCurve(to: p(0.0, 0.18), control: p(0.22, 0.05))
        // Left wing scalloped bottom edge
        path.addQuadCurve(to: p(0.16, 0.62), control: p(0.12, 0.40))
        path.addQuadCurve(to: p(0.30, 0.66), control: p(0.22, 0.52))
        path.addQuadCurve(to: p(0.42, 0.84), control: p(0.38, 0.66))
        // Body
        path.addQuadCurve(to: p(0.58, 0.84), control: p(0.5, 1.0))
        // Right wing (mirror)
        path.addQuadCurve(to: p(0.70, 0.66), control: p(0.62, 0.66))
        path.addQuadCurve(to: p(0.84, 0.62), control: p(0.78, 0.52))
        path.addQuadCurve(to: p(1.0, 0.18), control: p(0.88, 0.40))
        path.addQuadCurve(to: p(0.56, 0.30), control: p(0.78, 0.05))
        path.addLine(to: p(0.54, 0.12))
        path.closeSubpath()
        return path
    }
}

/// A plain pumpkin: three overlapping lobes and a stem.
struct PumpkinView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                Ellipse().fill(SpookySeason.Palette.pumpkin.opacity(0.85))
                    .frame(width: w * 0.55, height: h * 0.78)
                    .offset(x: -w * 0.2, y: h * 0.1)
                Ellipse().fill(SpookySeason.Palette.pumpkin.opacity(0.85))
                    .frame(width: w * 0.55, height: h * 0.78)
                    .offset(x: w * 0.2, y: h * 0.1)
                Ellipse().fill(SpookySeason.Palette.pumpkin)
                    .frame(width: w * 0.5, height: h * 0.82)
                    .offset(y: h * 0.09)
                Capsule().fill(SpookySeason.Palette.slime.opacity(0.9))
                    .frame(width: w * 0.1, height: h * 0.24)
                    .rotationEffect(.degrees(12))
                    .offset(y: -h * 0.36)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(1.2, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - App-wide switch

private struct SpookyThemeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while Spooky Season is live and the user hasn't switched the look
    /// off. Set once at the app root; every screen and sheet reads it, so
    /// nothing Halloween shows outside the event dates.
    var spookyTheme: Bool {
        get { self[SpookyThemeKey.self] }
        set { self[SpookyThemeKey.self] = newValue }
    }
}

/// A corner cobweb anchored at the top-trailing corner of its frame.
struct CobwebShape: Shape {
    func path(in rect: CGRect) -> Path {
        let corner = CGPoint(x: rect.maxX, y: rect.minY)
        let radius = min(rect.width, rect.height)
        let angles: [Double] = [90, 112.5, 135, 157.5, 180] // down … left
        func point(_ angle: Double, _ r: Double) -> CGPoint {
            CGPoint(x: corner.x + cos(angle * .pi / 180) * r,
                    y: corner.y + sin(angle * .pi / 180) * r)
        }
        var path = Path()
        for angle in angles {
            path.move(to: corner)
            path.addLine(to: point(angle, radius))
        }
        // Sagging threads between neighbouring spokes.
        for ring in [0.35, 0.62, 0.9] {
            let r = radius * ring
            path.move(to: point(angles[0], r))
            for i in 1..<angles.count {
                let mid = (angles[i - 1] + angles[i]) / 2
                path.addQuadCurve(to: point(angles[i], r), control: point(mid, r * 0.82))
            }
        }
        return path
    }
}

/// Decorative layer for the shared app background during Spooky Season:
/// dusk-coloured glows and three faint bats drifting slowly across. No
/// fixed-position art: the background can't know where content sits on
/// every layout (fold panes, side rail), so anything static would collide.
/// The bats are faint and keep moving. `time` is 0 under Reduce Motion, which freezes the bats.
struct SpookyNightSky: View {
    let time: TimeInterval
    let isLight: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Circle()
                    .fill(SpookySeason.Palette.potion.opacity(isLight ? 0.08 : 0.20))
                    .frame(width: w * 0.8, height: w * 0.8)
                    .blur(radius: 70)
                    .position(x: w * 0.85, y: h * 0.08)
                Circle()
                    .fill(SpookySeason.Palette.pumpkin.opacity(isLight ? 0.07 : 0.10))
                    .frame(width: w * 0.9, height: w * 0.7)
                    .blur(radius: 80)
                    .position(x: w * 0.1, y: h * 0.92)

                ForEach(0..<3, id: \.self) { index in
                    let seed = Double(index)
                    let span = w + 120
                    let x = (seed * span / 3 + time * (9 + seed * 4)).truncatingRemainder(dividingBy: span) - 60
                    let y = h * (0.16 + 0.27 * seed) + sin(time * 0.8 + seed * 2) * 12
                    BatShape()
                        .fill((isLight ? SpookySeason.Palette.midnight : SpookySeason.Palette.potion)
                            .opacity(isLight ? 0.10 : 0.30))
                        .frame(width: 26 + seed * 6, height: 13 + seed * 3)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Adds a faint corner cobweb to a card while `\.spookyTheme` is on.
private struct SpookyCobwebModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.spookyTheme) private var spookyTheme

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if spookyTheme {
                CobwebShape()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.7)
                    .frame(width: 32, height: 32)
                    .padding(4)
                    .clipShape(RoundedRectangle(cornerRadius: max(0, cornerRadius - 4), style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func spookyCobweb(cornerRadius: CGFloat = 20) -> some View {
        modifier(SpookyCobwebModifier(cornerRadius: cornerRadius))
    }
}
