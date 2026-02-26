import SwiftUI

// MARK: - Theme Transition Coordinator

/// Observable object shared between the root view and the Settings theme picker.
/// When a theme change is requested, the coordinator captures the current window
/// snapshot, then animates a shockwave reveal from the tap origin.
@MainActor
final class ThemeTransitionCoordinator: ObservableObject {
    @Published var snapshot: UIImage?
    @Published var origin: CGPoint = .zero
    @Published var progress: CGFloat = 0
    @Published var isAnimating = false

    /// Duration of the reveal animation in seconds.
    let duration: TimeInterval = 0.65

    /// Begin the theme transition: capture, switch, animate.
    /// - Parameters:
    ///   - origin: Screen-space coordinate where the user tapped.
    ///   - applyTheme: Closure that actually flips the color scheme.
    func startTransition(from origin: CGPoint, applyTheme: @escaping () -> Void) {
        guard !isAnimating else { return }

        // 1. Capture the current window as a screenshot
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: \.isKeyWindow) else {
            applyTheme()
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        // 2. Set state
        self.snapshot = image
        self.origin = origin
        self.progress = 0
        self.isAnimating = true

        // 3. Switch the actual theme underneath the snapshot overlay
        applyTheme()

        // 4. Animate the reveal after a short delay (lets SwiftUI apply the new scheme)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: self.duration)) {
                self.progress = 1
            }

            // Clean up after animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + self.duration + 0.05) {
                self.snapshot = nil
                self.isAnimating = false
                self.progress = 0
            }
        }
    }
}

// MARK: - Overlay View

/// Full-screen overlay that shows the captured snapshot and applies
/// a circular clip + ripple shader as the reveal progresses.
struct ThemeTransitionOverlay: View {
    @EnvironmentObject private var coordinator: ThemeTransitionCoordinator

    var body: some View {
        if let snapshot = coordinator.snapshot {
            GeometryReader { geo in
                let size = geo.size
                let maxRadius = hypot(
                    max(coordinator.origin.x, size.width - coordinator.origin.x),
                    max(coordinator.origin.y, size.height - coordinator.origin.y)
                )
                let currentRadius = coordinator.progress * maxRadius

                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(
                        InvertedCircle(center: coordinator.origin, radius: currentRadius)
                    )
                    .layerEffect(
                        ShaderLibrary.themeRipple(
                            .float2(coordinator.origin.x, coordinator.origin.y),
                            .float(Float(coordinator.progress)),
                            .float2(Float(size.width), Float(size.height))
                        ),
                        maxSampleOffset: CGSize(width: 30, height: 30),
                        isEnabled: coordinator.isAnimating
                    )
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .transition(.identity)
        }
    }
}

// MARK: - Inverted Circle Shape

/// A shape that fills everything *outside* a circle.
/// Used to "punch out" the revealed area from the old-theme snapshot.
struct InvertedCircle: Shape {
    var center: CGPoint
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        return path
            .strokedPath(StrokeStyle()) // force even-odd by returning the compound path
    }

    // Use even-odd fill to cut out the circle
    static var role: ShapeRole { .fill }
}

// MARK: - View Extension

extension View {
    /// Attach the theme-transition overlay and inject the coordinator
    /// into the environment for child views (e.g. SettingsView) to use.
    func themeTransitionOverlay(coordinator: ThemeTransitionCoordinator) -> some View {
        self
            .environmentObject(coordinator)
            .overlay {
                ThemeTransitionOverlay()
                    .environmentObject(coordinator)
            }
    }
}
