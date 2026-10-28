import SwiftUI
import WidgetKit

/// Dashboard content for the Spooky Season Halloween event.
/// Free feature, visible only while `SpookySeason.isActive()`.
struct SpookySeasonCard: View {
    let progress: Double
    let sips: Int
    let brews: Int
    let phase: SpookySeason.Phase
    var halloween: Bool = SpookySeason.isHalloween()

    private var incantation: String {
        SpookySeason.incantation(phase: phase, progress: progress, sips: sips, halloween: halloween)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(incantation)
                    .font(Theme.editorialSerif(18, weight: .semibold, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                PumpkinView()
                    .frame(width: 34)
            }

            HStack(spacing: 10) {
                Image(systemName: "flask.fill")
                    .font(.body)
                    .foregroundStyle(SpookySeason.Palette.accent)
                Text(SpookySeason.cauldronLine(sips: sips, progress: progress))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                Spacer()
                phaseBadge
            }

            PotionProgressBar(progress: progress)

            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundStyle(brews >= SpookySeason.brewsForCauldronKeeper ? SpookySeason.Palette.pumpkin : .secondary)
                Text(SpookySeason.brewsSummary(brews: brews))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spooky Season. \(incantation) \(SpookySeason.brewsSummary(brews: brews))")
    }

    private var phaseBadge: some View {
        Text(SpookySeason.phaseLabel(phase))
            .font(Theme.sipliMono(10, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(SpookySeason.Palette.potion.opacity(0.16)))
            .foregroundStyle(SpookySeason.Palette.accent)
    }
}

/// Potion-filled capsule with a few rising bubbles. Bubbles stay still under
/// Reduce Motion.
private struct PotionProgressBar: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fill = max(0, min(1, progress)) * width
            ZStack(alignment: .leading) {
                Capsule().fill(SpookySeason.Palette.potion.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(
                        colors: [SpookySeason.Palette.potion, SpookySeason.Palette.slime],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: fill)
                    .overlay(alignment: .leading) {
                        if fill > 24 {
                            TimelineView(.animation(paused: reduceMotion)) { context in
                                bubbles(width: fill, time: context.date.timeIntervalSinceReferenceDate)
                            }
                        }
                    }
                    .clipShape(Capsule())
            }
            .animation(Theme.fluidSpring, value: progress)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private func bubbles(width: CGFloat, time: TimeInterval) -> some View {
        Canvas { context, size in
            for index in 0..<5 {
                let seed = Double(index) * 0.37
                let x = width * (0.12 + 0.19 * Double(index))
                let rise = (time * (0.5 + seed) + seed).truncatingRemainder(dividingBy: 1)
                let y = size.height * (1 - rise)
                let r = 1.4 + seed
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55 * (1 - rise))))
            }
        }
    }
}

// MARK: - Goal celebration (Halloween variant)

/// Shown instead of the droplet celebration while Spooky Season is active:
/// bats scatter from the centre, a pumpkin pops and "Brewed!" appears.
/// Transform/opacity only; under Reduce Motion it renders a static badge.
struct SpookyCelebrationOverlay: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var popped = false
    @State private var batsFlying = false

    var body: some View {
        ZStack {
            if reduceMotion {
                badge
            } else {
                ForEach(0..<7, id: \.self) { index in
                    FlyingBat(index: index, flying: batsFlying)
                }
                badge
                    .scaleEffect(popped ? 1 : 0.4)
                    .opacity(popped ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            Haptics.splash()
            withAnimation(Theme.quickSpring.delay(0.1)) { popped = true }
            withAnimation(.easeOut(duration: 1.2)) { batsFlying = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                isShowing = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Potion brewed! Today's goal is reached.")
    }

    private var badge: some View {
        VStack(spacing: 8) {
            PumpkinView()
                .frame(width: 64)
            Text("Brewed!")
                .font(Theme.editorialSerif(38, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(SpookySeason.Palette.accent)
        }
    }
}

private struct FlyingBat: View {
    let index: Int
    let flying: Bool

    var body: some View {
        let angle = -150.0 + Double(index) * 20 // fan out upwards
        let distance: CGFloat = flying ? 220 : 10
        BatShape()
            .fill(SpookySeason.Palette.midnight.opacity(0.85))
            .frame(width: 30 + CGFloat(index % 3) * 6, height: 15 + CGFloat(index % 3) * 3)
            .offset(
                x: cos(angle * .pi / 180) * distance,
                y: sin(angle * .pi / 180) * distance
            )
            .opacity(flying ? 0 : 1)
    }
}

#Preview("Spooky Season Card") {
    VStack(spacing: 24) {
        DashboardCard(title: "Spooky Season", icon: "moon.stars.fill") {
            SpookySeasonCard(progress: 0.42, sips: 3, brews: 2, phase: .simmering, halloween: false)
        }
        DashboardCard(title: "Spooky Season", icon: "moon.stars.fill") {
            SpookySeasonCard(progress: 1.0, sips: 8, brews: 5, phase: .brewed, halloween: true)
        }
    }
    .padding()
    .background { AppWaterBackground().ignoresSafeArea() }
}

#Preview("Brewed celebration") {
    SpookyCelebrationOverlay(isShowing: .constant(true))
}

// MARK: - App-wide switch provider

/// Sets `\.spookyTheme` for the whole app: on only within the event dates
/// and after the user opted in (invite popup or Settings). The date is re-checked whenever the
/// app comes to the foreground, so the theme switches itself off after
/// November 7 without a new build.
private struct SpookyThemeProvider: ViewModifier {
    @AppStorage(SpookySeason.themeDefaultsKey, store: UserDefaults(suiteName: SpookySeason.appGroupID))
    private var enabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()

    func body(content: Content) -> some View {
        content
            .environment(\.spookyTheme, enabled && SpookySeason.isActive(on: now))
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = Date() }
            }
    }
}

extension View {
    func spookyThemeProvider() -> some View {
        modifier(SpookyThemeProvider())
    }
}

// MARK: - Opt-in invite

/// Asks once per season whether the user wants the Halloween event. Nothing
/// Halloween shows until they say yes; dismissing counts as "not for me".
/// Either way, Settings can change it later.
private struct SpookySeasonInviteModifier: ViewModifier {
    /// False while another sheet or celebration is up.
    let canPresent: Bool

    @AppStorage(SpookySeason.themeDefaultsKey, store: UserDefaults(suiteName: SpookySeason.appGroupID))
    private var enabled = false
    @AppStorage(SpookySeason.invitePromptedKey) private var prompted = false
    @State private var showInvite = false

    private var shouldInvite: Bool {
        canPresent && !prompted && !enabled && SpookySeason.isActive()
    }

    func body(content: Content) -> some View {
        content
            .task {
                // Let the splash and first layout settle before asking.
                try? await Task.sleep(for: .seconds(1.5))
                if shouldInvite { showInvite = true }
            }
            .onChange(of: canPresent) {
                if shouldInvite { showInvite = true }
            }
            .sheet(isPresented: $showInvite, onDismiss: { prompted = true }) {
                SpookySeasonInviteView { accepted in
                    prompted = true
                    if accepted {
                        enabled = true
                        WidgetCenter.shared.reloadAllTimelines()
                        PhoneSessionManager.shared.sendSpookyPreference(true)
                    }
                    showInvite = false
                }
                .presentationDetents([.medium, .large])
            }
    }
}

extension View {
    func spookySeasonInvite(canPresent: Bool) -> some View {
        modifier(SpookySeasonInviteModifier(canPresent: canPresent))
    }
}

struct SpookySeasonInviteView: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .bottom, spacing: 14) {
                    BatShape()
                        .fill(SpookySeason.Palette.accent)
                        .frame(width: 40, height: 20)
                        .offset(y: -24)
                    PumpkinView()
                        .frame(width: 76)
                    BatShape()
                        .fill(SpookySeason.Palette.accent)
                        .frame(width: 30, height: 15)
                        .offset(y: -34)
                }
                .padding(.top, 28)
                .accessibilityHidden(true)

                Text("Join Spooky Season?")
                    .font(Theme.editorialSerif(30, weight: .semibold, relativeTo: .title))
                    .multilineTextAlignment(.center)

                Text("A Halloween twist on Sipli until November 7: a potion-purple bottle, a daily brewing challenge and three limited-time badges.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button {
                        Haptics.selection()
                        onChoice(true)
                    } label: {
                        Text("Turn it on")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SpookySeason.Palette.potion)

                    Button("Not for me") {
                        onChoice(false)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                }
                .padding(.top, 6)

                Text("You can change this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background { AppWaterBackground().ignoresSafeArea() }
    }
}

#Preview("Spooky Season invite") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SpookySeasonInviteView { _ in }
            .presentationDetents([.medium, .large])
    }
}

// MARK: - Settings card

/// Settings home for the event: shown only during the season. Explains what
/// joining means while off, and shows progress once on. Always uses the
/// night-sky look so it matches the invite in light and dark mode.
struct SpookySeasonSettingsCard: View {
    @EnvironmentObject private var store: HydrationStore
    @AppStorage(SpookySeason.themeDefaultsKey, store: UserDefaults(suiteName: SpookySeason.appGroupID))
    private var enabled = false
    @AppStorage(SpookySeason.invitePromptedKey) private var prompted = false

    private static let badges: [(id: String, symbol: String, title: String)] = [
        ("spooky.first", "flask.fill", "First Brew"),
        ("spooky.cauldron", "moon.stars.fill", "Cauldron Keeper"),
        ("spooky.halloween", "theatermasks.fill", "Trick or Treat"),
    ]

    private var daysLeft: Int { SpookySeason.daysLeft() }
    private var brews: Int { store.spookyBrewDates.count }
    private var earnedBadges: Int {
        Self.badges.filter { store.unlockedAchievements[$0.id] != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            joinToggle
            if enabled {
                progress
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                included
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text(enabled
                 ? "Turn it off anytime. Badges you've earned stay in your Trophy Room."
                 : "Not into Halloween? Leave it off and nothing changes.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SpookySeason.Palette.potion.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: SpookySeason.Palette.potion.opacity(0.25), radius: 16, x: 0, y: 8)
        .animation(Theme.fluidSpring, value: enabled)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited-time event")
                    .font(Theme.sipliMono(11, weight: .semibold, relativeTo: .caption))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(SpookySeason.Palette.pumpkin)
                Text("Spooky Season")
                    .font(Theme.editorialSerif(28, weight: .semibold, relativeTo: .title))
                Text("Until 7 November · \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            ZStack {
                BatShape()
                    .fill(SpookySeason.Palette.accent)
                    .frame(width: 26, height: 13)
                    .offset(x: -30, y: -20)
                BatShape()
                    .fill(SpookySeason.Palette.accent.opacity(0.8))
                    .frame(width: 18, height: 9)
                    .offset(x: 28, y: -26)
                PumpkinView()
                    .frame(width: 58)
            }
            .frame(width: 92, height: 70)
            .accessibilityHidden(true)
        }
    }

    private var joinToggle: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(enabled ? "You're in" : "Join the event")
                    .font(.headline)
                Text(enabled ? "Halloween look and challenge are on" : "Off — Sipli looks as usual")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .tint(SpookySeason.Palette.pumpkin)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
        .onChange(of: enabled) {
            Haptics.selection()
            prompted = true // a choice in Settings answers the invite too
            WidgetCenter.shared.reloadAllTimelines()
            PhoneSessionManager.shared.sendSpookyPreference(enabled)
        }
    }

    private var included: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's included")
                .font(Theme.sipliMono(11, weight: .semibold, relativeTo: .caption))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.6))
            includedRow("paintbrush.pointed.fill", "Halloween look", "Potion-purple bottle, bats and cobwebs on every screen")
            includedRow("flask.fill", "Daily potion challenge", "Hit your goal to brew the day's potion")
            includedRow("rosette", "Three limited badges", "Only earnable until 7 November")
            includedRow("applewatch", "Widgets and Watch", "The theme follows you everywhere")
        }
    }

    private func includedRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(SpookySeason.Palette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: some View {
        HStack(alignment: .top, spacing: 12) {
            statTile {
                Text("Potions brewed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(min(brews, SpookySeason.brewsForCauldronKeeper)) / \(SpookySeason.brewsForCauldronKeeper)")
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [SpookySeason.Palette.potion, SpookySeason.Palette.slime],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width
                                   * min(1, Double(brews) / Double(SpookySeason.brewsForCauldronKeeper)))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Potions brewed: \(brews) of \(SpookySeason.brewsForCauldronKeeper)")

            statTile {
                Text("Badges")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(earnedBadges) / \(Self.badges.count)")
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                HStack(spacing: 8) {
                    ForEach(Self.badges, id: \.id) { badge in
                        let earned = store.unlockedAchievements[badge.id] != nil
                        Image(systemName: badge.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(earned ? SpookySeason.Palette.pumpkin : .white.opacity(0.3))
                            .accessibilityLabel("\(badge.title), \(earned ? "earned" : "not yet earned")")
                    }
                }
            }
        }
    }

    private func statTile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(
                colors: [SpookySeason.Palette.midnight, Color(red: 0.24, green: 0.13, blue: 0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(SpookySeason.Palette.pumpkin.opacity(0.22))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: -40, y: 60)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(SpookySeason.Palette.potion.opacity(0.35))
                    .frame(width: 160, height: 160)
                    .blur(radius: 45)
                    .offset(x: 30, y: -40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
