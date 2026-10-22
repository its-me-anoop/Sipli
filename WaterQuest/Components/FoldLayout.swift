import SwiftUI

// MARK: - Fold model
//
// Foldable iPhones (iPhone Duo) report the fold as a "division" reserved
// region: a band of the screen that content should split around rather than
// straddle. SwiftUI exposes it through `GeometryProxy.reservedRegions(kind:)`
// (iOS 27.1+), already converted into the proxy's own coordinate space, so
// each container resolves the fold locally.
//
// - Fold line running top-to-bottom (book pose): panes sit side by side.
// - Fold line running across (tabletop pose): panes sit above and below.
// - No active fold: callers get a landscape split or their normal layout.

/// The fold band, in the local coordinate space of the view that resolved it.
struct FoldDivision: Equatable {
    enum Axis { case vertical, horizontal }

    var frame: CGRect

    /// `.vertical` = book pose (panes left/right); `.horizontal` = tabletop
    /// pose (panes top/bottom).
    var axis: Axis { frame.height >= frame.width ? .vertical : .horizontal }
}

/// How a two-pane container should lay itself out right now.
enum PaneArrangement: Equatable {
    /// Leading pane width, gap (the fold), trailing pane width.
    case sideBySide(leading: CGFloat, gap: CGFloat, trailing: CGFloat)
    /// Top pane height, gap (the fold), bottom pane height.
    case stacked(top: CGFloat, gap: CGFloat, bottom: CGFloat)
    /// No split; use the caller's normal layout.
    case single

    var isSplit: Bool { self != .single }
}

enum FoldResolver {
    /// Panes narrower than this aren't worth splitting into.
    static let minimumPaneLength: CGFloat = 220

    /// The active fold crossing a view of `size`, or nil if there isn't one.
    static func division(in proxy: GeometryProxy, simulatedGlobal: CGRect?) -> FoldDivision? {
        let bounds = CGRect(origin: .zero, size: proxy.size)
        var candidate: CGRect?

        if #available(iOS 27.1, *) {
            candidate = proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame
        }

        #if DEBUG
        if candidate == nil, let simulatedGlobal {
            let origin = proxy.frame(in: .global).origin
            candidate = simulatedGlobal.offsetBy(dx: -origin.x, dy: -origin.y)
        }
        #endif

        guard let frame = candidate, frame.intersects(bounds) else { return nil }
        return FoldDivision(frame: frame)
    }

    /// Resolves the arrangement for a container: fold first, then (optionally)
    /// a landscape side-by-side split, otherwise `.single`.
    static func arrangement(
        in proxy: GeometryProxy,
        simulatedGlobal: CGRect?,
        allowsLandscapeSplit: Bool,
        landscapeLeadingFraction: CGFloat = 0.46
    ) -> PaneArrangement {
        let size = proxy.size

        if let division = division(in: proxy, simulatedGlobal: simulatedGlobal) {
            let band = division.frame
            switch division.axis {
            case .vertical:
                let leading = max(0, min(size.width, band.minX))
                let trailing = max(0, size.width - band.maxX)
                if leading >= minimumPaneLength, trailing >= minimumPaneLength {
                    return .sideBySide(leading: leading, gap: size.width - leading - trailing, trailing: trailing)
                }
            case .horizontal:
                let top = max(0, min(size.height, band.minY))
                let bottom = max(0, size.height - band.maxY)
                if top >= minimumPaneLength * 0.7, bottom >= minimumPaneLength * 0.7 {
                    return .stacked(top: top, gap: size.height - top - bottom, bottom: bottom)
                }
            }
        }

        if allowsLandscapeSplit, size.width > size.height * 1.15, size.width >= minimumPaneLength * 2 + 24 {
            let leading = (size.width * landscapeLeadingFraction).rounded()
            let gap: CGFloat = 16
            return .sideBySide(leading: leading, gap: gap, trailing: size.width - leading - gap)
        }

        return .single
    }
}

// MARK: - Environment

private struct SimulatedFoldKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct HingeStatusKey: EnvironmentKey {
    static let defaultValue: HingeStatus = .unavailable
}

/// Simplified hinge state for views that care about the physical pose
/// (e.g. to tone down motion while the device is being folded).
enum HingeStatus: Equatable {
    case unavailable, closed, partiallyOpen, fullyOpen
}

extension EnvironmentValues {
    /// DEBUG-only stand-in for the fold, in global coordinates. Lets the fold
    /// layouts be exercised on simulators that can't move the hinge.
    var simulatedFoldGlobalFrame: CGRect? {
        get { self[SimulatedFoldKey.self] }
        set { self[SimulatedFoldKey.self] = newValue }
    }

    var hingeStatus: HingeStatus {
        get { self[HingeStatusKey.self] }
        set { self[HingeStatusKey.self] = newValue }
    }
}

// MARK: - Root tracking

/// Install once at the root. Publishes hinge status and re-renders the tree
/// when the hinge moves, so every `FoldAwareSplit` re-resolves the fold.
struct FoldTracking: ViewModifier {
    @State private var status: HingeStatus = .unavailable
    @State private var windowFrame: CGRect = .zero

    func body(content: Content) -> some View {
        tracked(content)
            .environment(\.hingeStatus, status)
            .environment(\.simulatedFoldGlobalFrame, simulatedFold)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { windowFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in windowFrame = frame }
                }
                .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private func tracked(_ content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                status = HingeStatus(context.hinge)
            }
        } else {
            content
        }
    }

    /// `-SipliSimulatedFold book|tabletop` (DEBUG builds only) draws a fake
    /// 24pt fold through the middle of the window.
    private var simulatedFold: CGRect? {
        #if DEBUG
        guard windowFrame.width > 0,
              let pose = UserDefaults.standard.string(forKey: "SipliSimulatedFold") else { return nil }
        let band: CGFloat = 24
        switch pose {
        case "book":
            return CGRect(x: windowFrame.midX - band / 2, y: windowFrame.minY, width: band, height: windowFrame.height)
        case "tabletop":
            return CGRect(x: windowFrame.minX, y: windowFrame.midY - band / 2, width: windowFrame.width, height: band)
        default:
            return nil
        }
        #else
        return nil
        #endif
    }
}

@available(iOS 27.1, *)
private extension HingeStatus {
    init(_ hinge: DeviceHinge?) {
        guard let status = hinge?.status else { self = .unavailable; return }
        if status == .closed {
            self = .closed
        } else if status == .partiallyOpen {
            self = .partiallyOpen
        } else if status == .fullyOpen {
            self = .fullyOpen
        } else {
            self = .unavailable
        }
    }
}

extension View {
    func foldTracking() -> some View { modifier(FoldTracking()) }
}

// MARK: - Two-pane container

/// Lays out `primary` and `secondary` on either side of the fold (book or
/// tabletop pose), side by side in wide landscape when allowed, and falls back
/// to `single` otherwise. Each pane owns its own scrolling.
struct FoldAwareSplit<Primary: View, Secondary: View, Single: View>: View {
    var allowsLandscapeSplit: Bool = true
    var landscapeLeadingFraction: CGFloat = 0.46
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary
    @ViewBuilder var single: () -> Single

    @Environment(\.simulatedFoldGlobalFrame) private var simulatedFold

    var body: some View {
        GeometryReader { proxy in
            let arrangement = FoldResolver.arrangement(
                in: proxy,
                simulatedGlobal: simulatedFold,
                allowsLandscapeSplit: allowsLandscapeSplit,
                landscapeLeadingFraction: landscapeLeadingFraction
            )

            switch arrangement {
            case let .sideBySide(leading, gap, trailing):
                HStack(spacing: gap) {
                    primary().frame(width: leading)
                    secondary().frame(width: trailing)
                }
                .frame(maxHeight: .infinity)
            case let .stacked(top, gap, bottom):
                VStack(spacing: gap) {
                    primary().frame(height: top)
                    secondary().frame(height: bottom)
                }
                .frame(maxWidth: .infinity)
            case .single:
                single()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

// MARK: - Fit a hero component inside its pane

/// Scales content down (never up) so it fits the pane's height instead of
/// being cut off at the fold. Below `minimumScale` it would get too small to
/// read, so it scrolls at full size instead.
private struct FitToPane: ViewModifier {
    var minimumScale: CGFloat
    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let raw = contentHeight > 0 ? proxy.size.height / contentHeight : 1
            let scale = min(1, raw)

            if scale >= minimumScale {
                measured(content)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            } else {
                ScrollView { measured(content) }
            }
        }
    }

    private func measured(_ content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }
}

extension View {
    /// Shrinks a hero component to fit its pane rather than clipping it.
    func fittingPane(minimumScale: CGFloat = 0.62) -> some View {
        modifier(FitToPane(minimumScale: minimumScale))
    }
}

// MARK: - Keep single-column content out of the fold

private struct FoldAvoiding: ViewModifier {
    /// Widest a single column gets in phone landscape before it reads as stretched.
    static let readableWidth: CGFloat = 620

    @Environment(\.simulatedFoldGlobalFrame) private var simulatedFold
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            if verticalSizeClass == .compact, size.width > Self.readableWidth + 80 {
                // Phone landscape: keep a centred, readable column.
                content
                    .frame(width: Self.readableWidth, height: size.height)
                    .frame(width: size.width)
            } else if let division = FoldResolver.division(in: proxy, simulatedGlobal: simulatedFold),
               division.axis == .vertical {
                // A single column can't be split, so it moves wholly into the
                // roomier pane instead of running across the fold.
                let leading = max(0, division.frame.minX)
                let trailing = max(0, size.width - division.frame.maxX)
                if leading >= trailing {
                    content
                        .frame(width: leading, height: size.height)
                        .frame(width: size.width, alignment: .leading)
                } else {
                    content
                        .frame(width: trailing, height: size.height)
                        .frame(width: size.width, alignment: .trailing)
                }
            } else {
                content.frame(width: size.width, height: size.height)
            }
        }
        // Margins beside a narrowed column keep the app's water backdrop.
        .background { AppWaterBackground().ignoresSafeArea() }
    }
}

extension View {
    /// Keeps a single column from straddling a vertical fold (book pose), and
    /// from stretching edge to edge in phone landscape.
    func avoidingFold() -> some View { modifier(FoldAvoiding()) }
}
