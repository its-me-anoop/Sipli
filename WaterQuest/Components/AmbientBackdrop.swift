import SwiftUI

/// Decides whether the shared water backdrop moves, and how often it redraws.
///
/// The backdrop sits behind every screen. Redrawing its large blurred blobs on
/// every display frame (up to 120 Hz) competes with scrolling for the GPU, so
/// it redraws at a low fixed rate and stops whenever nobody can see it move.
struct AmbientBackdropPolicy: Equatable {
    enum Mode: Equatable {
        /// Drawn once at its resting pose (Reduce Motion).
        case still
        /// Keeps the last drawn frame (offscreen, app inactive, Low Power Mode).
        case paused
        /// Redraws no more often than every `frameInterval` seconds.
        case animated
    }

    /// The blobs drift under ~12 pt/s, so 20 fps moves them under 1 pt per
    /// frame: visually the same as 120 fps for a sixth of the work or less.
    static let frameInterval: TimeInterval = 1.0 / 20.0

    var reduceMotion: Bool
    var isLowPowerMode: Bool
    var isSceneActive: Bool
    var isVisible: Bool

    var mode: Mode {
        if reduceMotion { return .still }
        if !isSceneActive || !isVisible || isLowPowerMode { return .paused }
        return .animated
    }
}

/// Pure motion curves for the backdrop, kept apart from drawing so the speed
/// limit the frame rate relies on can be tested.
struct AmbientBackdropMotion: Equatable {
    var gradientStart: UnitPoint
    var gradientEnd: UnitPoint
    var blobA: CGSize
    var blobB: CGSize
    var blobC: CGSize

    init(time t: TimeInterval) {
        gradientStart = UnitPoint(x: 0.18 + 0.12 * sin(t * 0.14), y: 0.02 + 0.06 * cos(t * 0.12))
        gradientEnd = UnitPoint(x: 0.82 + 0.1 * cos(t * 0.1), y: 0.98 + 0.04 * sin(t * 0.16))
        blobA = CGSize(width: -120 + cos(t * 0.22) * 48, height: -140 + sin(t * 0.18) * 38)
        blobB = CGSize(width: 120 + sin(t * 0.2) * 56, height: 42 + cos(t * 0.16) * 36)
        blobC = CGSize(width: 0 + sin(t * 0.15) * 44, height: 340 + cos(t * 0.14) * 30)
    }

    /// Largest distance, in points, any blob moves between two poses.
    func maxBlobDistance(to other: AmbientBackdropMotion) -> CGFloat {
        zip([blobA, blobB, blobC], [other.blobA, other.blobB, other.blobC])
            .map { hypot($0.width - $1.width, $0.height - $1.height) }
            .max() ?? 0
    }
}

/// Opacity profile of a solid disc after a Gaussian blur, as radial
/// gradient stops. Drawing it as a gradient looks the same as `.blur` on a
/// circle but costs no blur pass, so the blob is cheap to redraw and to
/// composite under scrolling content.
struct SoftBlobProfile: Equatable {
    /// Radius of the disc before blurring, in points.
    let radius: CGFloat
    /// Blur strength, matching the value passed to `.blur(radius:)`.
    let blur: CGFloat

    /// The gradient reaches zero here; nothing is visible beyond it.
    var outerRadius: CGFloat { radius + max(blur, 0) * 3 }

    /// Fraction of the disc's colour that reaches `distance` from its centre.
    func opacity(at distance: CGFloat) -> Double {
        let r = Double(max(radius, 0))
        let sigma = Double(max(blur, 0.0001))
        // Exact value at the centre of a blurred disc, then the 1D edge
        // profile scaled to meet it, which is close for these large blobs.
        let centre = 1 - exp(-(r * r) / (2 * sigma * sigma))
        let edge = { (x: Double) in 0.5 * erfc(-x / 2.squareRoot()) }
        let scale = centre / max(edge(r / sigma), 0.0001)
        let value = edge((r - Double(distance)) / sigma) * scale
        return min(max(value, 0), 1)
    }

    func stops(color: Color, count: Int = 12) -> [Gradient.Stop] {
        let steps = max(count, 2)
        return (0..<steps).map { index in
            let location = CGFloat(index) / CGFloat(steps - 1)
            let alpha = index == steps - 1 ? 0 : opacity(at: location * outerRadius)
            return Gradient.Stop(color: color.opacity(alpha), location: location)
        }
    }
}

/// A soft colour blob, equivalent to `Circle().frame(width:height:).blur(radius:)`
/// with the same centre, drawn as a radial gradient instead of a blur.
struct SoftBlob: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let blur: CGFloat

    var body: some View {
        // A Circle inscribes itself in the smaller side of its frame.
        let profile = SoftBlobProfile(radius: min(width, height) / 2, blur: blur)
        let diameter = profile.outerRadius * 2
        Circle()
            .fill(RadialGradient(
                stops: profile.stops(color: color),
                center: .center,
                startRadius: 0,
                endRadius: profile.outerRadius
            ))
            .frame(width: diameter, height: diameter)
            .frame(width: width, height: height)
            .allowsHitTesting(false)
    }
}
