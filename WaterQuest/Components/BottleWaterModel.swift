import CoreGraphics
import Foundation

/// Water remaining in the Home bottle. Intake changes its volume; gravity only
/// changes the surface angle, and disturbances decay back to a still surface.
struct BottleWaterModel {
    static let restingTilt = 0.0

    private(set) var remaining: Double
    private(set) var targetRemaining: Double
    private(set) var tilt = restingTilt
    private(set) var ripple = 0.0
    private(set) var phase = 0.0
    private var targetTilt = restingTilt

    var isSettled: Bool {
        remaining == targetRemaining && tilt == targetTilt && ripple == 0
    }

    init(progress: Double) {
        let fraction = Self.remainingFraction(for: progress)
        remaining = fraction
        targetRemaining = fraction
    }

    static func remainingFraction(for progress: Double) -> Double {
        // Missing intake behaves like a new day. Infinities still clamp to the
        // appropriate endpoint, without allowing NaN into drawing coordinates.
        guard !progress.isNaN else { return 1 }
        return 1 - min(1, max(0, progress))
    }

    mutating func setProgress(_ progress: Double, animated: Bool) {
        let next = Self.remainingFraction(for: progress)
        let change = abs(next - targetRemaining)
        targetRemaining = next
        if animated {
            if change > 0 {
                ripple = max(ripple, min(1, 0.32 + change * 1.4))
            }
        } else {
            remaining = next
            ripple = 0
            phase = 0
        }
    }

    mutating func setGravity(x: Double, y: Double, acceleration: Double = 0) {
        // A phone lying flat has no useful gravity projection onto its screen.
        // Retain the last stable angle instead of amplifying sensor noise.
        guard x.isFinite, y.isFinite, hypot(x, y) >= 0.12 else { return }
        let limit = 35.0 * .pi / 180
        let next = Self.restingTilt + min(limit, max(-limit, atan2(-x, -y)))
        let change = abs(next - targetTilt)
        if change > 0.003 { targetTilt = next }

        let movement = acceleration.isFinite ? max(0, abs(acceleration) - 0.025) : 0
        if change > 0.003 || movement > 0 {
            ripple = max(ripple, min(1, change * 2.8 + movement * 0.65))
        }
    }

    mutating func advance(by dt: Double) {
        guard dt.isFinite, dt > 0, !isSettled else { return }
        // App pauses and delayed frames must not cause a large visual jump.
        let step = min(dt, 0.1)
        remaining += (targetRemaining - remaining) * (1 - exp(-7.5 * step))
        tilt += (targetTilt - tilt) * (1 - exp(-10 * step))

        if abs(targetRemaining - remaining) < 0.0001 { remaining = targetRemaining }
        if abs(targetTilt - tilt) < 0.0001 { tilt = targetTilt }
        if ripple > 0 {
            phase += step * 5.2
            ripple *= exp(-2.8 * step)
            if ripple < 0.001 { ripple = 0 }
        }
    }

    /// Used for reduced motion and lifecycle changes: no unfinished animation
    /// remains scheduled and the current reading is immediately accurate.
    mutating func settle() {
        remaining = targetRemaining
        tilt = targetTilt
        ripple = 0
        phase = 0
    }
}

/// The interior of the Home photo asset, in its original 1240 × 1748 aspect
/// ratio. Drawing and volume calculations use this same sampled contour.
enum BottleWaterGeometry {
    private static let points: [CGPoint] = {
        var result = [CGPoint(x: 0.33, y: 0.247), CGPoint(x: 0.65, y: 0.247)]
        func curve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
            let start = result.last!
            for index in 1...16 {
                let t = Double(index) / 16
                let u = 1 - t
                result.append(CGPoint(
                    x: u * u * u * start.x + 3 * u * u * t * control1.x
                        + 3 * u * t * t * control2.x + t * t * t * end.x,
                    y: u * u * u * start.y + 3 * u * u * t * control1.y
                        + 3 * u * t * t * control2.y + t * t * t * end.y
                ))
            }
        }
        curve(to: CGPoint(x: 0.728, y: 0.35),
              control1: CGPoint(x: 0.65, y: 0.29),
              control2: CGPoint(x: 0.723, y: 0.31))
        result.append(CGPoint(x: 0.736, y: 0.40))
        result.append(CGPoint(x: 0.736, y: 0.90))
        curve(to: CGPoint(x: 0.70, y: 0.94),
              control1: CGPoint(x: 0.736, y: 0.928),
              control2: CGPoint(x: 0.724, y: 0.94))
        result.append(CGPoint(x: 0.285, y: 0.94))
        curve(to: CGPoint(x: 0.25, y: 0.90),
              control1: CGPoint(x: 0.262, y: 0.94),
              control2: CGPoint(x: 0.25, y: 0.928))
        result.append(CGPoint(x: 0.25, y: 0.36))
        curve(to: CGPoint(x: 0.33, y: 0.247),
              control1: CGPoint(x: 0.25, y: 0.315),
              control2: CGPoint(x: 0.33, y: 0.29))
        return result
    }()

    private static let capacity = submergedArea(centerY: 0.265, slope: 0)

    static func outline(size: CGSize) -> [CGPoint] {
        guard valid(size) else { return [] }
        return points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    /// Finds the center height of a flat free surface while preserving its
    /// cross-sectional area. A tilted bottle never appears to gain water.
    static func surfaceY(remaining: Double, tilt: Double, size: CGSize) -> Double {
        guard valid(size) else { return 0 }
        let fraction = remaining.isNaN ? 0 : min(1, max(0, remaining))
        guard fraction > 0 else { return size.height * 0.94 }
        let safeTilt = tilt.isFinite ? min(.pi / 3, max(-.pi / 3, tilt)) : 0
        let slope = tan(safeTilt) * size.width / size.height
        let desiredArea = capacity * fraction
        var lower = 0.247 - abs(slope)
        var upper = 0.94 + abs(slope)
        for _ in 0..<28 {
            let midpoint = (lower + upper) / 2
            if submergedArea(centerY: midpoint, slope: slope) > desiredArea {
                lower = midpoint
            } else {
                upper = midpoint
            }
        }
        return (lower + upper) / 2 * size.height
    }

    private static func valid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    /// Clip to the half-plane beneath the surface and compute its shoelace
    /// area. Summing edges directly avoids allocating a polygon every frame.
    private static func submergedArea(centerY: Double, slope: Double) -> Double {
        var first: CGPoint?
        var last: CGPoint?
        var twiceArea = 0.0
        func append(_ point: CGPoint) {
            if let previous = last {
                twiceArea += previous.x * point.y - point.x * previous.y
            } else {
                first = point
            }
            last = point
        }
        var previous = points.last!
        var previousDistance = previous.y - centerY - slope * (previous.x - 0.5)
        for point in points {
            let distance = point.y - centerY - slope * (point.x - 0.5)
            if (previousDistance >= 0) != (distance >= 0) {
                let fraction = previousDistance / (previousDistance - distance)
                append(CGPoint(x: previous.x + fraction * (point.x - previous.x),
                               y: previous.y + fraction * (point.y - previous.y)))
            }
            if distance >= 0 { append(point) }
            previous = point
            previousDistance = distance
        }
        if let first, let last {
            twiceArea += last.x * first.y - first.x * last.y
        }
        return abs(twiceArea) / 2
    }
}
