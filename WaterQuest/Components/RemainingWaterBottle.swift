import SwiftUI
import Combine
import CoreMotion

/// Home's remaining-water gauge. The shared onboarding renderer stays unchanged.
struct RemainingWaterBottle: View {
    let progress: Double
    let isRegular: Bool
    let bottleWidth: CGFloat
    let bottleHeight: CGFloat

    @StateObject private var animation: BottleWaterAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    init(progress: Double, isRegular: Bool, bottleWidth: CGFloat, bottleHeight: CGFloat) {
        self.progress = progress
        self.isRegular = isRegular
        self.bottleWidth = bottleWidth
        self.bottleHeight = bottleHeight
        _animation = StateObject(wrappedValue: BottleWaterAnimation(progress: progress))
    }

    private var usesReducedMotion: Bool {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SIPLI_BOTTLE_REDUCE_MOTION"] == "1" { return true }
#endif
        return reduceMotion
    }

    private var remainingPercent: Int {
        Int((BottleWaterModel.remainingFraction(for: progress) * 100).rounded())
    }

    var body: some View {
        ZStack {
            // Render in the asset's own aspect ratio so the liquid and glass align
            // at both phone and tablet sizes, including the outer letterboxing.
            BottleWaterCanvas(water: animation.frame)
                .aspectRatio(1240.0 / 1748.0, contentMode: .fit)
            Image("bottle")
                .resizable()
                .scaledToFit()

            VStack(spacing: 0) {
                Text("\(remainingPercent)%")
                    .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .contentTransition(.numericText())
                Text("left")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                if progress >= 1 {
                    Image(systemName: "star.fill")
                        .font(isRegular ? .title3 : .subheadline)
                        .foregroundStyle(Theme.sun)
                        .padding(.top, 4)
                }
            }
            .frame(width: bottleWidth * 0.48)
            .foregroundStyle(BottleOptics.highlight)
            .shadow(color: BottleOptics.shadow.opacity(0.8), radius: 2, x: 0, y: 1)
        }
        .frame(width: bottleWidth, height: bottleHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water remaining")
        .accessibilityValue("\(remainingPercent) percent left")
        .accessibilityIdentifier("homeWaterBottle")
        .onAppear {
            visible = true
            animation.setProgress(progress, animated: false)
            updateActivity()
        }
        .onDisappear {
            visible = false
            animation.setActive(false, reduceMotion: usesReducedMotion)
        }
        .onChange(of: progress) { _, value in
            animation.setProgress(value, animated: !usesReducedMotion)
        }
        .onChange(of: scenePhase) { updateActivity() }
        .onChange(of: usesReducedMotion) { updateActivity() }
        // Water changes its drawing, never the surrounding layout. Suppress any
        // inherited log/celebration animation, especially with Reduce Motion.
        .transaction { $0.animation = nil }
    }

    private func updateActivity() {
        animation.setActive(visible && scenePhase == .active, reduceMotion: usesReducedMotion)
    }
}

private enum BottleOptics {
    // Light passing through the glass stays pale in either appearance.
    // OKLCH (0.981, 0.006, 240) and (0.205, 0.034, 250), converted to sRGB.
    static let highlight = Color(red: 0.9619, green: 0.9779, blue: 0.9900)
    static let shadow = Color(red: 0.0407, green: 0.0947, blue: 0.1493)
}

private struct BottleWaterCanvas: View {
    let water: BottleWaterModel

    var body: some View {
        Canvas { context, size in
            guard water.remaining > 0 else { return }
            let outline = BottleWaterGeometry.outline(size: size)
            var bottle = Path()
            bottle.addLines(outline)
            bottle.closeSubpath()
            context.clip(to: bottle)

            let level = BottleWaterGeometry.surfaceY(remaining: water.remaining, tilt: water.tilt, size: size)
            // Short, damped capillary waves after drinking or moving the phone.
            // There is no perpetual animation once the water has settled.
            let amplitude = size.height * 0.012 * water.ripple * min(1, water.remaining * 15)
            let slope = tan(water.tilt)
            func surface(back: Bool) -> Path {
                var path = Path()
                for index in 0...80 {
                    let x = size.width * Double(index) / 80
                    let u = (x / size.width - 0.25) / 0.486
                    let wave = sin(u * .pi * 2 + water.phase + (back ? 1.4 : 0))
                        + 0.3 * sin(u * .pi * 4 - water.phase * 0.7)
                    let y = level + slope * (x - size.width / 2)
                        + amplitude * wave * (back ? 0.6 : 1)
                        + (back ? -size.height * 0.004 : 0)
                    let point = CGPoint(x: x, y: y)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                return path
            }
            func filled(_ surface: Path) -> Path {
                var path = surface
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
                return path
            }

            let rear = surface(back: true)
            let front = surface(back: false)
            let waterBlue = Theme.lagoon
            context.fill(filled(rear), with: .color(waterBlue.opacity(0.32)))
            context.fill(filled(front), with: .linearGradient(
                Gradient(colors: [waterBlue.opacity(0.60), waterBlue.opacity(0.94)]),
                startPoint: CGPoint(x: 0, y: level),
                endPoint: CGPoint(x: 0, y: size.height * 0.94)
            ))
            context.stroke(rear, with: .color(BottleOptics.highlight.opacity(0.36)), lineWidth: 0.7)
            context.stroke(front, with: .color(BottleOptics.highlight.opacity(0.86)), lineWidth: 1.2)

            // Refracted light follows the wet portion, under the original glass.
            context.clip(to: filled(front))
            let light = Path(CGRect(x: size.width * 0.34, y: 0, width: size.width * 0.09, height: size.height))
            context.fill(light, with: .linearGradient(
                Gradient(colors: [.clear, BottleOptics.highlight.opacity(0.18), .clear]),
                startPoint: CGPoint(x: size.width * 0.34, y: 0),
                endPoint: CGPoint(x: size.width * 0.43, y: 0)
            ))
            if water.ripple > 0.02 {
                for index in 0..<5 {
                    let cycle = (water.phase * 0.06 + Double(index) * 0.21).truncatingRemainder(dividingBy: 1)
                    let x = size.width * (0.30 + Double(index) * 0.083) + sin(water.phase + Double(index)) * 1.4
                    let y = size.height * 0.94 - cycle * max(0, size.height * 0.94 - level)
                    let radius = size.width * (index.isMultiple(of: 2) ? 0.005 : 0.008)
                    let bubble = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                    context.stroke(bubble, with: .color(BottleOptics.highlight.opacity(water.ripple * 0.48)), lineWidth: 0.65)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Motion belongs to this Home bottle only. Sensors stop offscreen, in the
/// background and under Reduce Motion; the display link stops at rest.
@MainActor
final class BottleWaterAnimation: ObservableObject {
    @Published private(set) var frame: BottleWaterModel
    private var model: BottleWaterModel
    private let motion = CMMotionManager()
    private var displayLink: CADisplayLink?
    private var displayTarget: BottleDisplayLinkTarget?
    private var lastTimestamp: CFTimeInterval?
    private(set) var isActive = false
    private(set) var isReducedMotion = false
    var isAnimating: Bool { displayLink != nil }

    init(progress: Double) {
        let initial = BottleWaterModel(progress: progress)
        model = initial
        frame = initial
    }

    deinit {
        motion.stopDeviceMotionUpdates()
        displayLink?.invalidate()
    }

    func setProgress(_ progress: Double, animated: Bool) {
        model.setProgress(progress, animated: animated && isActive && !isReducedMotion)
        frame = model
        wakeAnimation()
    }

    func setActive(_ active: Bool, reduceMotion: Bool) {
        isActive = active
        isReducedMotion = reduceMotion
        motion.stopDeviceMotionUpdates()
        guard active && !reduceMotion else {
            stopAnimation()
            model.setGravity(x: 0, y: -1)
            model.settle()
            frame = model
            return
        }
#if DEBUG && targetEnvironment(simulator)
        // The simulator has no accelerometer. UI tests send deterministic
        // gravity through the same input and animation path as Core Motion.
        let env = ProcessInfo.processInfo.environment
        if let x = env["SIPLI_BOTTLE_GRAVITY_X"].flatMap(Double.init),
           let y = env["SIPLI_BOTTLE_GRAVITY_Y"].flatMap(Double.init) {
            receiveGravity(x: x, y: y)
            return
        }
#endif
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data, error == nil else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let orientation = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }?.interfaceOrientation ?? .portrait
                let gravity = Self.screenGravity(x: data.gravity.x, y: data.gravity.y, orientation: orientation)
                let a = data.userAcceleration
                self.receiveGravity(x: gravity.x, y: gravity.y, acceleration: sqrt(a.x * a.x + a.y * a.y + a.z * a.z))
            }
        }
        wakeAnimation()
    }

    static func screenGravity(x: Double, y: Double, orientation: UIInterfaceOrientation) -> (x: Double, y: Double) {
        switch orientation {
        case .landscapeLeft: return (y, -x)
        case .landscapeRight: return (-y, x)
        case .portraitUpsideDown: return (-x, -y)
        default: return (x, y)
        }
    }

    func receiveGravity(x: Double, y: Double, acceleration: Double = 0) {
        guard isActive && !isReducedMotion else { return }
        model.setGravity(x: x, y: y, acceleration: acceleration)
        wakeAnimation()
    }

    private func wakeAnimation() {
        guard isActive, !isReducedMotion, !model.isSettled, displayLink == nil else { return }
        let target = BottleDisplayLinkTarget()
        target.owner = self
        let link = CADisplayLink(target: target, selector: #selector(BottleDisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayTarget = target
        displayLink = link
        lastTimestamp = nil
        link.add(to: .main, forMode: .common)
    }

    fileprivate func step(at timestamp: CFTimeInterval) {
        let dt = lastTimestamp.map { timestamp - $0 } ?? 1.0 / 60.0
        lastTimestamp = timestamp
        model.advance(by: dt)
        frame = model
        if model.isSettled { stopAnimation() }
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        displayTarget = nil
        lastTimestamp = nil
    }
}

@MainActor
private final class BottleDisplayLinkTarget: NSObject {
    weak var owner: BottleWaterAnimation?
    @objc func tick(_ link: CADisplayLink) { owner?.step(at: link.timestamp) }
}
