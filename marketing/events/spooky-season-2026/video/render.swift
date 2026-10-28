// Spooky Season in-app event video: a 15-second loop in two shapes, 16:9 for
// the event card and 9:16 for the event details page. Everything is drawn in
// code (Core Graphics) except the Sipli bottle artwork; the soundtrack is
// synthesized. No text — the App Store overlays the event name itself.
//
// Build & run from the repo root:
//   swiftc -O -parse-as-library marketing/events/spooky-season-2026/video/render.swift \
//     WaterQuest/Components/BottleWaterModel.swift -o /tmp/spooky-video
//   /tmp/spooky-video                    # both videos
//   /tmp/spooky-video --stills 3,7,9,12  # preview frames only
import AppKit
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

// MARK: - Timing helpers

let fps = 30
let duration = 15.0

func clamp(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double { max(a, min(b, v)) }
func prog(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func easeOutBack(_ x: Double) -> Double { let c1 = 1.9, c3 = c1 + 1; return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2) }
func easeOutBounce(_ x: Double) -> Double {
    let n = 7.5625, d = 2.75
    if x < 1 / d { return n * x * x }
    if x < 2 / d { let y = x - 1.5 / d; return n * y * y + 0.75 }
    if x < 2.5 / d { let y = x - 2.25 / d; return n * y * y + 0.9375 }
    let y = x - 2.625 / d; return n * y * y + 0.984375
}
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }

/// Small deterministic random generator so every render is identical.
struct Rand {
    var s: UInt64
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double(s >> 11) / Double(1 << 53)
    }
}

// MARK: - Palette

struct RGB { var r, g, b: CGFloat
    func cg(_ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r: lerp(r, o.r, t), g: lerp(g, o.g, t), b: lerp(b, o.b, t)) }
}
let midnight = RGB(r: 0.075, g: 0.055, b: 0.15)
let dusk = RGB(r: 0.26, g: 0.13, b: 0.47)
let potion = RGB(r: 0.48, g: 0.25, b: 0.89)
let pumpkinOrange = RGB(r: 1.0, g: 0.48, b: 0.10)
let slime = RGB(r: 0.49, g: 0.86, b: 0.23)
let lagoon = RGB(r: 0.17, g: 0.42, b: 1.0)
let moonGlow = RGB(r: 1.0, g: 0.87, b: 0.62)
let candle = RGB(r: 1.0, g: 0.86, b: 0.35)
let white = RGB(r: 1, g: 1, b: 1)

// MARK: - Scene layout

struct Layout {
    let W: CGFloat, H: CGFloat
    var portrait: Bool { H > W }
    var s: CGFloat { min(W, H) / 1080 }
    var bottleHeight: CGFloat { portrait ? H * 0.40 : H * 0.60 }
    var bottleWidth: CGFloat { bottleHeight * 1240 / 1748 }
    var bottleCenter: CGPoint { CGPoint(x: W * 0.5, y: portrait ? H * 0.55 : H * 0.555) }
    var groundY: CGFloat { portrait ? H * 0.88 : H * 0.90 }
}

// MARK: - Shapes

func batPath(_ r: CGRect, flap: Double) -> CGPath {
    // Wings fold toward the body as `flap` goes 1 → 0.
    let w = r.width, h = r.height
    let lift = CGFloat(0.35 + 0.65 * flap)
    func p(_ x: Double, _ y: Double) -> CGPoint {
        let cx = 0.5, cy = 0.45
        let yy = cy + (y - cy) * Double(lift) - (1 - Double(lift)) * abs(x - cx) * 0.5
        return CGPoint(x: r.minX + w * x, y: r.minY + h * yy)
    }
    let path = CGMutablePath()
    path.move(to: p(0.5, 0.30)); path.addLine(to: p(0.46, 0.12)); path.addLine(to: p(0.44, 0.30))
    path.addQuadCurve(to: p(0.0, 0.18), control: p(0.22, 0.05))
    path.addQuadCurve(to: p(0.16, 0.62), control: p(0.12, 0.40))
    path.addQuadCurve(to: p(0.30, 0.66), control: p(0.22, 0.52))
    path.addQuadCurve(to: p(0.42, 0.84), control: p(0.38, 0.66))
    path.addQuadCurve(to: p(0.58, 0.84), control: p(0.5, 1.0))
    path.addQuadCurve(to: p(0.70, 0.66), control: p(0.62, 0.66))
    path.addQuadCurve(to: p(0.84, 0.62), control: p(0.78, 0.52))
    path.addQuadCurve(to: p(1.0, 0.18), control: p(0.88, 0.40))
    path.addQuadCurve(to: p(0.56, 0.30), control: p(0.78, 0.05))
    path.addLine(to: p(0.54, 0.12)); path.closeSubpath()
    return path
}

func drawBat(_ c: CGContext, center: CGPoint, width: CGFloat, flap: Double, tilt: CGFloat, alpha: CGFloat = 0.92) {
    c.saveGState()
    c.translateBy(x: center.x, y: center.y); c.rotate(by: tilt)
    c.addPath(batPath(CGRect(x: -width / 2, y: -width / 4, width: width, height: width / 2), flap: flap))
    c.setFillColor(CGColor(srgbRed: 0.04, green: 0.02, blue: 0.08, alpha: alpha)); c.fillPath()
    // Tiny glowing eyes.
    c.setFillColor(candle.cg(alpha))
    for dx in [-0.035, 0.035] {
        c.fillEllipse(in: CGRect(x: width * dx - width * 0.012, y: -width * 0.07, width: width * 0.024, height: width * 0.024))
    }
    c.restoreGState()
}

func glow(_ c: CGContext, at p: CGPoint, radius: CGFloat, color: RGB, alpha: CGFloat) {
    guard alpha > 0.001 else { return }
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color.cg(alpha), color.cg(0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [])
}

func drawMoon(_ c: CGContext, center: CGPoint, r: CGFloat) {
    glow(c, at: center, radius: r * 3.2, color: moonGlow, alpha: 0.28)
    c.saveGState()
    let bite = CGMutablePath()
    bite.addRect(CGRect(x: center.x - r * 3, y: center.y - r * 3, width: r * 6, height: r * 6))
    bite.addEllipse(in: CGRect(x: center.x - r * 0.35, y: center.y - r * 1.25, width: r * 1.75, height: r * 1.75))
    c.addPath(bite); c.clip(using: .evenOdd)
    c.setFillColor(moonGlow.cg()); c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    c.restoreGState()
}

func drawPumpkin(_ c: CGContext, base: CGPoint, size: CGFloat, scale: Double, flicker: Double) {
    guard scale > 0.001 else { return }
    c.saveGState()
    c.translateBy(x: base.x, y: base.y); c.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let w = size, h = size * 0.82
    glow(c, at: CGPoint(x: 0, y: -h * 0.45), radius: w * 1.1, color: pumpkinOrange, alpha: 0.22 + 0.12 * CGFloat(flicker))
    for (dx, a) in [(-0.22, 0.85), (0.22, 0.85), (0.0, 1.0)] as [(CGFloat, CGFloat)] {
        let lw = dx == 0 ? w * 0.52 : w * 0.56
        c.setFillColor(pumpkinOrange.mix(RGB(r: 0.85, g: 0.32, b: 0.05), dx == 0 ? 0 : 0.35).cg(a))
        c.fillEllipse(in: CGRect(x: dx * w - lw / 2, y: -h, width: lw, height: h))
    }
    // Stem
    c.setFillColor(CGColor(srgbRed: 0.33, green: 0.55, blue: 0.2, alpha: 1))
    c.fill(CGRect(x: -w * 0.04, y: -h * 1.14, width: w * 0.08, height: h * 0.2))
    // Jack-o'-lantern face, lit from inside.
    let lit = candle.mix(pumpkinOrange, 0.25 * (1 - flicker)).cg()
    c.setFillColor(lit)
    for sx in [-1.0, 1.0] as [CGFloat] {
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: sx * w * 0.16, y: -h * 0.70))
        eye.addLine(to: CGPoint(x: sx * w * 0.07, y: -h * 0.52))
        eye.addLine(to: CGPoint(x: sx * w * 0.25, y: -h * 0.52))
        eye.closeSubpath(); c.addPath(eye); c.fillPath()
    }
    let mouth = CGMutablePath()
    mouth.move(to: CGPoint(x: -w * 0.24, y: -h * 0.36))
    mouth.addQuadCurve(to: CGPoint(x: w * 0.24, y: -h * 0.36), control: CGPoint(x: 0, y: -h * 0.06))
    mouth.addLine(to: CGPoint(x: w * 0.12, y: -h * 0.33))
    mouth.addLine(to: CGPoint(x: w * 0.06, y: -h * 0.27))
    mouth.addLine(to: CGPoint(x: 0, y: -h * 0.33))
    mouth.addLine(to: CGPoint(x: -w * 0.06, y: -h * 0.27))
    mouth.addLine(to: CGPoint(x: -w * 0.12, y: -h * 0.33))
    mouth.closeSubpath(); c.addPath(mouth); c.fillPath()
    c.restoreGState()
}

func drawGhost(_ c: CGContext, center: CGPoint, size: CGFloat, t: Double, wave: Double, alpha: CGFloat) {
    guard alpha > 0.01 else { return }
    c.saveGState()
    c.translateBy(x: center.x, y: center.y)
    c.setAlpha(alpha)
    let w = size, h = size * 1.15
    glow(c, at: .zero, radius: w * 1.2, color: white, alpha: 0.12)
    let body = CGMutablePath()
    body.move(to: CGPoint(x: -w / 2, y: 0))
    body.addArc(center: CGPoint(x: 0, y: 0), radius: w / 2, startAngle: .pi, endAngle: 0, clockwise: false)
    body.addLine(to: CGPoint(x: w / 2, y: h * 0.5))
    let scallops = 4
    for i in 0..<scallops {
        let x0 = w / 2 - CGFloat(i) * w / CGFloat(scallops)
        let x1 = x0 - w / CGFloat(scallops)
        let sway = CGFloat(sin(t * 6 + Double(i))) * w * 0.03
        body.addQuadCurve(to: CGPoint(x: x1, y: h * 0.5), control: CGPoint(x: (x0 + x1) / 2 + sway, y: h * 0.5 + w * 0.16))
    }
    body.closeSubpath()
    c.addPath(body); c.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 1, alpha: 0.95)); c.fillPath()
    // Waving arm, out to the side: rests low, swings up to wave.
    let armAngle = CGFloat(0.5 - 1.6 * wave * (0.6 + 0.4 * sin(t * 11)))
    c.saveGState()
    c.translateBy(x: w * 0.44, y: h * 0.12); c.rotate(by: armAngle)
    c.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 1, alpha: 0.95))
    c.fillEllipse(in: CGRect(x: 0, y: -w * 0.08, width: w * 0.32, height: w * 0.16))
    c.restoreGState()
    // Face
    c.setFillColor(CGColor(srgbRed: 0.08, green: 0.05, blue: 0.15, alpha: 1))
    for sx in [-1.0, 1.0] as [CGFloat] {
        c.fillEllipse(in: CGRect(x: sx * w * 0.15 - w * 0.06, y: -w * 0.12, width: w * 0.12, height: w * 0.16))
    }
    c.fillEllipse(in: CGRect(x: -w * 0.07, y: w * 0.08, width: w * 0.14, height: w * 0.16)) // "ooo"
    c.setFillColor(CGColor(srgbRed: 1, green: 0.55, blue: 0.7, alpha: 0.6))
    for sx in [-1.0, 1.0] as [CGFloat] {
        c.fillEllipse(in: CGRect(x: sx * w * 0.27 - w * 0.06, y: w * 0.02, width: w * 0.12, height: w * 0.07))
    }
    c.restoreGState()
}

func drawHat(_ c: CGContext, width w: CGFloat) {
    // Origin = brim centre.
    let h = w * 0.85
    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: -w * 0.30, y: -h * 0.05))
    cone.addQuadCurve(to: CGPoint(x: w * 0.18, y: -h * 0.95), control: CGPoint(x: -w * 0.10, y: -h * 0.55))
    cone.addQuadCurve(to: CGPoint(x: w * 0.30, y: -h * 0.05), control: CGPoint(x: w * 0.14, y: -h * 0.45))
    cone.closeSubpath()
    c.addPath(cone); c.setFillColor(CGColor(srgbRed: 0.11, green: 0.08, blue: 0.19, alpha: 1)); c.fillPath()
    c.setFillColor(pumpkinOrange.cg()); c.fill(CGRect(x: -w * 0.27, y: -h * 0.2, width: w * 0.54, height: h * 0.1))
    c.setFillColor(CGColor(srgbRed: 0.11, green: 0.08, blue: 0.19, alpha: 1))
    c.fillEllipse(in: CGRect(x: -w / 2, y: -h * 0.09, width: w, height: h * 0.16))
}

func drawSparkle(_ c: CGContext, at p: CGPoint, r: CGFloat, color: RGB, alpha: CGFloat) {
    guard alpha > 0.01 else { return }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: p.x, y: p.y - r))
    path.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: p)
    c.addPath(path); c.setFillColor(color.cg(alpha)); c.fillPath()
}

// MARK: - Bottle

let bottleImage: CGImage = {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("WaterQuest/Assets.xcassets/bottle.imageset/bottle.png")
    guard let img = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { fatalError("run from the repo root") }
    return img
}()

func drawImage(_ c: CGContext, _ img: CGImage, in r: CGRect) {
    c.saveGState(); c.translateBy(x: r.minX, y: r.maxY); c.scaleBy(x: 1, y: -1)
    c.interpolationQuality = .high
    c.draw(img, in: CGRect(origin: .zero, size: r.size)); c.restoreGState()
}

/// Draws the bottle with water in a local frame whose origin is the
/// bottle's top-left (top-left coordinates, like the app).
func drawBottle(_ c: CGContext, size: CGSize, remaining: Double, water: RGB, t: Double, ripple: Double, fizz: Double) {
    let outline = BottleWaterGeometry.outline(size: size)
    if remaining > 0.001 {
        c.saveGState()
        let clip = CGMutablePath(); clip.addLines(between: outline); clip.closeSubpath()
        c.addPath(clip); c.clip()
        let level = CGFloat(BottleWaterGeometry.surfaceY(remaining: remaining, tilt: 0, size: size))
        let amp = size.height * CGFloat(0.006 + 0.02 * ripple)
        func surface(back: Bool) -> CGMutablePath {
            let p = CGMutablePath()
            for i in 0...80 {
                let x = size.width * CGFloat(i) / 80
                let u = Double((x / size.width - 0.25) / 0.486)
                let wave = sin(u * .pi * 2 + t * 3 + (back ? 1.4 : 0)) + 0.3 * sin(u * .pi * 4 - t * 2.1)
                let y = level + amp * CGFloat(wave) * (back ? 0.6 : 1) - (back ? size.height * 0.004 : 0)
                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height)); p.addLine(to: CGPoint(x: 0, y: size.height)); p.closeSubpath()
            return p
        }
        c.addPath(surface(back: true)); c.setFillColor(water.cg(0.34)); c.fillPath()
        let front = surface(back: false)
        c.saveGState(); c.addPath(front); c.clip()
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [water.cg(0.66), water.cg(0.97)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: level), end: CGPoint(x: 0, y: size.height * 0.94), options: [])
        // Bubbles rise faster as the brew fizzes.
        var rng = Rand(s: 7)
        let count = 6 + Int(fizz * 14)
        for i in 0..<count {
            let speed = 0.12 + rng.next() * 0.2 + fizz * 0.25
            let phase = (rng.next() + t * speed).truncatingRemainder(dividingBy: 1)
            let x = size.width * CGFloat(0.30 + rng.next() * 0.40) + CGFloat(sin(t * 3 + Double(i))) * size.width * 0.01
            let y = size.height * 0.93 - CGFloat(phase) * (size.height * 0.93 - level)
            let r = size.width * CGFloat(0.006 + rng.next() * 0.012)
            c.setStrokeColor(white.cg(0.55)); c.setLineWidth(size.width * 0.003)
            c.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        c.restoreGState()
        c.restoreGState()
    }
    drawImage(c, bottleImage, in: CGRect(origin: .zero, size: size))
}

// MARK: - Frame

let starField: [(CGFloat, CGFloat, CGFloat, Double)] = {
    var r = Rand(s: 42)
    return (0..<90).map { _ in (CGFloat(r.next()), CGFloat(r.next() * 0.7), CGFloat(1 + r.next() * 2.2), r.next() * 6.28) }
}()

func renderFrame(_ c: CGContext, _ L: Layout, _ t: Double) {
    let W = L.W, H = L.H, s = L.s
    // Top-left origin.
    c.saveGState(); c.translateBy(x: 0, y: H); c.scaleBy(x: 1, y: -1)

    // Sky
    let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [midnight.cg(), dusk.cg()] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: H), options: [])
    for (i, st) in starField.enumerated() {
        let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * (1.5 + Double(i % 5) * 0.4) + st.3))
        let a = CGFloat(tw * prog(t, 0.2, 1.6))
        c.setFillColor(white.cg(a * 0.85))
        c.fillEllipse(in: CGRect(x: st.0 * W, y: st.1 * H, width: st.2 * s * 2, height: st.2 * s * 2))
    }

    // Moon rises
    let moonT = easeOut(prog(t, 0.0, 3.0))
    let moonX = W * (L.portrait ? 0.78 : 0.83)
    let moonY = lerp(H * 0.45, H * (L.portrait ? 0.11 : 0.18), moonT)
    drawMoon(c, center: CGPoint(x: moonX, y: moonY), r: 70 * s)

    let brew = easeInOut(prog(t, 6.0, 7.4))   // 0 = water, 1 = witch's brew
    let water = lagoon.mix(slime, brew)
    let center = L.bottleCenter

    // Glow behind the bottle: purple, turning green with the brew.
    let bottleIn = prog(t, 2.5, 4.0)
    glow(c, at: center, radius: L.bottleHeight * 0.75, color: potion.mix(slime, brew * 0.8), alpha: CGFloat(0.45 * bottleIn))

    // Drifting fog
    for i in 0..<3 {
        let fx = (CGFloat(i) * 0.4 + CGFloat(t) * 0.02 * CGFloat(i + 1)).truncatingRemainder(dividingBy: 1.4) - 0.2
        glow(c, at: CGPoint(x: fx * W, y: H * 0.80 + CGFloat(i) * 30 * s), radius: 380 * s, color: RGB(r: 0.62, g: 0.55, b: 0.85), alpha: 0.12)
    }

    // Ground
    let ground = CGMutablePath()
    ground.move(to: CGPoint(x: 0, y: L.groundY))
    ground.addQuadCurve(to: CGPoint(x: W, y: L.groundY + 10 * s), control: CGPoint(x: W * 0.5, y: L.groundY - 70 * s))
    ground.addLine(to: CGPoint(x: W, y: H)); ground.addLine(to: CGPoint(x: 0, y: H)); ground.closeSubpath()
    c.addPath(ground); c.setFillColor(CGColor(srgbRed: 0.05, green: 0.03, blue: 0.10, alpha: 1)); c.fillPath()

    // Soft shadow on the ground under the bottle.
    let landed = prog(t, 3.4, 4.0)
    if landed > 0 {
        c.saveGState()
        c.translateBy(x: L.bottleCenter.x, y: L.groundY - 8 * s); c.scaleBy(x: 1, y: 0.18)
        glow(c, at: .zero, radius: L.bottleWidth * 0.75, color: RGB(r: 0, g: 0, b: 0), alpha: CGFloat(0.55 * landed))
        c.restoreGState()
    }

    // Bat flock swoops across (1.0–3.6s)
    for i in 0..<6 {
        let start = 1.0 + Double(i) * 0.18
        let p = prog(t, start, start + 2.2)
        guard p > 0, p < 1 else { continue }
        let x = lerp(-0.15 * W, 1.15 * W, p)
        let baseY = H * (L.portrait ? 0.20 + 0.05 * CGFloat(i % 3) : 0.22 + 0.08 * CGFloat(i % 3))
        let y = baseY + CGFloat(sin(p * 9 + Double(i))) * 40 * s
        let flap = 0.5 + 0.5 * sin(t * 26 + Double(i))
        drawBat(c, center: CGPoint(x: x, y: y), width: (90 + CGFloat(i % 3) * 30) * s, flap: flap, tilt: CGFloat(cos(p * 9 + Double(i))) * 0.25)
    }

    // Bottle: drops in, fills, brews; squashes and wobbles when the hat lands.
    if bottleIn > 0 {
        let dropY = lerp(-H * 0.9, 0, easeOutBack(bottleIn))
        let land = t - 8.0
        let wobble = land > 0 ? 0.10 * exp(-land * 3.2) * sin(land * 15) : 0
        let squash = land > 0 ? 1 - 0.08 * exp(-land * 6) * cos(land * 18) : 1
        let remaining = 0.12 + 0.66 * easeInOut(prog(t, 4.0, 6.5))
        let ripple = max(prog(t, 4.0, 4.3) * (1 - prog(t, 6.3, 7.0)), land > 0 ? exp(-land * 2.5) : 0)
        let fizz = brew
        let size = CGSize(width: L.bottleWidth, height: L.bottleHeight)

        c.saveGState()
        // Pivot at the bottle's base for the wobble and squash.
        let base = CGPoint(x: center.x, y: center.y + size.height / 2 + dropY)
        c.translateBy(x: base.x, y: base.y)
        c.rotate(by: CGFloat(wobble))
        c.scaleBy(x: CGFloat(2 - squash), y: CGFloat(squash))
        c.translateBy(x: -size.width / 2, y: -size.height)
        drawBottle(c, size: size, remaining: remaining, water: water, t: t, ripple: ripple, fizz: fizz)

        // Witch hat lands on the cap (7.2–8.0s).
        let hatT = prog(t, 7.2, 8.0)
        if hatT > 0 {
            let capTop = CGPoint(x: size.width * 0.488, y: size.height * 0.062)
            let fall = (1 - easeOutBounce(hatT)) * Double(H) * 0.6
            c.saveGState()
            c.translateBy(x: capTop.x - size.width * 0.02, y: capTop.y - CGFloat(fall))
            c.rotate(by: -0.14 + CGFloat(wobble) * 0.6)
            drawHat(c, width: size.width * 0.62)
            c.restoreGState()
        }
        c.restoreGState()
    }

    // Sparkle burst as the hat lands, then lingering twinkles.
    if t > 8.0 {
        let bt = t - 8.0
        for i in 0..<12 {
            let a = Double(i) / 12 * .pi * 2
            let dist = CGFloat(easeOut(clamp(bt / 0.9))) * L.bottleHeight * 0.55
            let p = CGPoint(x: center.x + CGFloat(cos(a)) * dist, y: center.y - L.bottleHeight * 0.38 + CGFloat(sin(a)) * dist * 0.8)
            drawSparkle(c, at: p, r: 16 * s, color: i % 2 == 0 ? candle : slime, alpha: CGFloat(1 - clamp(bt / 1.1)))
        }
        var r = Rand(s: 99)
        for i in 0..<10 {
            let p = CGPoint(x: W * CGFloat(0.1 + r.next() * 0.8), y: H * CGFloat(0.1 + r.next() * 0.6))
            let tw = max(0, sin((t - 8.5) * 2.2 + Double(i) * 1.7))
            drawSparkle(c, at: p, r: CGFloat(8 + r.next() * 10) * s, color: candle, alpha: CGFloat(tw * 0.8 * prog(t, 8.5, 9.5)))
        }
    }

    // Jack-o'-lanterns pop up (8.3, 8.75, 9.2s)
    let pumpkins: [(CGFloat, CGFloat, Double)] = L.portrait
        ? [(0.20, 230, 8.3), (0.80, 190, 8.75), (0.52, 140, 9.2)]
        : [(0.17, 230, 8.3), (0.82, 200, 8.75), (0.93, 130, 9.2)]
    for (i, pk) in pumpkins.enumerated() {
        let pop = easeOutBack(prog(t, pk.2, pk.2 + 0.45))
        let flicker = 0.5 + 0.5 * sin(t * 13 + Double(i) * 2) * sin(t * 7.3 + Double(i))
        drawPumpkin(c, base: CGPoint(x: W * pk.0, y: L.groundY + 26 * s - (L.portrait && i == 2 ? 0 : 0)), size: pk.1 * s, scale: pop, flicker: flicker)
    }

    // Bats circle the bottle (11–15s)
    if t > 11.0 {
        let a = prog(t, 11.0, 11.8)
        for i in 0..<3 {
            let ang = t * 1.4 + Double(i) * 2.1
            let rx = L.bottleWidth * 0.95, ry = L.bottleHeight * 0.22
            let p = CGPoint(x: center.x + CGFloat(cos(ang)) * rx, y: center.y - L.bottleHeight * 0.30 + CGFloat(sin(ang)) * ry)
            drawBat(c, center: p, width: 80 * s, flap: 0.5 + 0.5 * sin(t * 24 + Double(i)), tilt: CGFloat(-sin(ang)) * 0.3, alpha: CGFloat(0.92 * a))
        }
    }

    // Friendly ghost floats in and waves (9.6–14.5s)
    if t > 9.6 {
        let enter = easeOut(prog(t, 9.6, 10.8))
        let leave = prog(t, 13.6, 14.6)
        let gx = L.portrait ? lerp(-0.2 * W, 0.24 * W, enter) : lerp(-0.12 * W, 0.30 * W, enter)
        let gy = (L.portrait ? H * 0.26 : H * 0.42) + CGFloat(sin(t * 2.4)) * 18 * s - CGFloat(leave) * H * 0.25
        drawGhost(c, center: CGPoint(x: gx, y: gy), size: 170 * s, t: t, wave: prog(t, 10.8, 11.2) * (1 - prog(t, 12.6, 13.0)), alpha: CGFloat(1 - leave))
    }

    // Fade in from, and back out to, midnight so the loop is seamless.
    let fade = max(1 - prog(t, 0, 0.6), prog(t, duration - 0.6, duration))
    if fade > 0 { c.setFillColor(midnight.cg(CGFloat(fade))); c.fill(CGRect(x: 0, y: 0, width: W, height: H)) }
    c.restoreGState()
}

// MARK: - Soundtrack

func soundtrack(sampleRate sr: Double) -> [Float] {
    let n = Int(duration * sr)
    var out = [Float](repeating: 0, count: n)
    func f(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }
    func add(at start: Double, length: Double, _ gen: (Double) -> Double) {
        let a = Int(start * sr), b = min(n, Int((start + length) * sr))
        guard a < b else { return }
        for i in a..<b { out[i] += Float(gen(Double(i - a) / sr)) }
    }
    // Low drone with tremolo.
    add(at: 0, length: duration) { t in
        let env = clamp(t / 2) * clamp((duration - t) / 1.5)
        return env * 0.05 * (1 + 0.3 * sin(2 * .pi * 4 * t)) * (sin(2 * .pi * f(38) * t) + 0.6 * sin(2 * .pi * f(45) * t))
    }
    // Plucked bass on the beat.
    let bass: [Double] = [50, 45, 41, 45]
    var bt = 0.6, bi = 0
    while bt < duration - 0.8 {
        let freq = f(bass[bi % 4])
        add(at: bt, length: 0.55) { t in exp(-t * 7) * 0.22 * (sin(2 * .pi * freq * t) + 0.4 * sin(4 * .pi * freq * t)) }
        bt += 0.6; bi += 1
    }
    // Music-box melody in D harmonic minor.
    let melody: [Double?] = [74, 77, 81, 80, 81, 77, 74, nil, 76, 77, 76, 74, 73, 74, nil, nil,
                             74, 77, 81, 80, 81, 84, 86, nil, 85, 81, 77, 76, 73, 74, nil, nil]
    var mt = 1.2
    for note in melody + melody.prefix(8) {
        if let note {
            let freq = f(note)
            add(at: mt, length: 0.9) { t in
                exp(-t * 4.5) * 0.16 * (sin(2 * .pi * freq * t) + 0.25 * sin(4 * .pi * freq * t) + 0.08 * sin(6 * .pi * freq * t))
            }
        }
        mt += 0.3
        if mt > duration - 1.2 { break }
    }
    var rng = Rand(s: 5)
    // Bat whoosh (filtered noise with wing flutter).
    var lp = 0.0
    add(at: 1.0, length: 2.6) { t in
        lp += (rng.next() * 2 - 1 - lp) * 0.08
        return lp * 0.5 * sin(.pi * t / 2.6) * (0.6 + 0.4 * sin(2 * .pi * 18 * t))
    }
    // Bottle lands.
    add(at: 3.95, length: 0.35) { t in exp(-t * 14) * 0.35 * sin(2 * .pi * (90 - 40 * t) * t) }
    // Glugs while it fills.
    var gt = 4.05
    while gt < 6.4 {
        let base = 500 + rng.next() * 350
        add(at: gt, length: 0.12) { t in exp(-t * 30) * 0.12 * sin(2 * .pi * (base + 900 * t) * t) }
        gt += 0.11 + rng.next() * 0.08
    }
    // Magic shimmer as it brews.
    for (i, note) in [86.0, 89, 93, 96, 98, 101].enumerated() {
        let freq = f(note)
        add(at: 6.0 + Double(i) * 0.2, length: 1.0) { t in exp(-t * 5) * 0.07 * sin(2 * .pi * freq * t) }
    }
    // Hat "boing".
    add(at: 8.0, length: 0.7) { t in
        let freq = 220 + 140 * exp(-t * 3) * sin(2 * .pi * 11 * t)
        return exp(-t * 4.5) * 0.28 * sin(2 * .pi * freq * t)
    }
    // Pumpkin pops.
    for p in [8.3, 8.75, 9.2] {
        add(at: p, length: 0.12) { t in exp(-t * 35) * 0.3 * sin(2 * .pi * (180 + 4200 * t) * t) }
    }
    // Ghostly "ooo".
    add(at: 9.8, length: 1.6) { t in
        let env = sin(.pi * t / 1.6)
        let freq = 360 - 70 * t / 1.6 + 7 * sin(2 * .pi * 5.5 * t)
        return env * 0.12 * (sin(2 * .pi * freq * t) + 0.3 * sin(4 * .pi * freq * t))
    }
    // Closing chime.
    for note in [74.0, 77, 81, 86] {
        let freq = f(note)
        add(at: 12.2, length: 2.6) { t in exp(-t * 1.6) * 0.07 * (sin(2 * .pi * freq * t) + 0.2 * sin(2 * .pi * freq * 2.76 * t)) }
    }
    // Gentle fades, then normalise.
    for i in 0..<n {
        let t = Double(i) / sr
        out[i] *= Float(clamp(t / 0.3) * clamp((duration - t) / 0.8))
    }
    let peak = out.map(abs).max() ?? 1
    return out.map { $0 * 0.82 / peak }
}

func writeAudio(to url: URL) throws {
    let sr = 44100.0
    let mono = soundtrack(sampleRate: sr)
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(mono.count))!
    buf.frameLength = AVAudioFrameCount(mono.count)
    for i in 0..<mono.count {
        buf.floatChannelData![0][i] = mono[i]
        buf.floatChannelData![1][i] = mono[i]
    }
    try? FileManager.default.removeItem(at: url)
    let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sr,
                                                           AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000],
                               commonFormat: .pcmFormatFloat32, interleaved: false)
    try file.write(from: buf)
}

// MARK: - Output

func makeContext(_ W: Int, _ H: Int, data: UnsafeMutableRawPointer? = nil, bytesPerRow: Int = 0) -> CGContext {
    CGContext(data: data, width: W, height: H, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
}

func writeVideo(width W: Int, height H: Int, audio: URL, to finalURL: URL) throws {
    let L = Layout(W: CGFloat(W), H: CGFloat(H))
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("spooky-\(W)x\(H).mov")
    try? FileManager.default.removeItem(at: tmp)
    let writer = try AVAssetWriter(outputURL: tmp, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 16_000_000,
                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                          AVVideoExpectedSourceFrameRateKey: fps,
                                          AVVideoMaxKeyFrameIntervalKey: fps]])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
    writer.add(input)
    writer.startWriting(); writer.startSession(atSourceTime: .zero)
    let frames = Int(duration * Double(fps))
    for f in 0..<frames {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_32BGRA, nil, &pb)
        CVPixelBufferLockBaseAddress(pb!, [])
        let c = makeContext(W, H, data: CVPixelBufferGetBaseAddress(pb!), bytesPerRow: CVPixelBufferGetBytesPerRow(pb!))
        renderFrame(c, L, Double(f) / Double(fps))
        CVPixelBufferUnlockBaseAddress(pb!, [])
        while !input.isReadyForMoreMediaData { usleep(1000) }
        adaptor.append(pb!, withPresentationTime: CMTime(value: Int64(f), timescale: CMTimeScale(fps)))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }; done.wait()
    guard writer.status == .completed else { throw NSError(domain: "video", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(String(describing: writer.error))"]) }

    // Mux picture and sound into the final .mp4.
    let comp = AVMutableComposition()
    let v = AVURLAsset(url: tmp), a = AVURLAsset(url: audio)
    let vt = v.tracks(withMediaType: .video)[0], at = a.tracks(withMediaType: .audio)[0]
    let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try cv.insertTimeRange(CMTimeRange(start: .zero, duration: v.duration), of: vt, at: .zero)
    let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try ca.insertTimeRange(CMTimeRange(start: .zero, duration: min(a.duration, v.duration)), of: at, at: .zero)
    try? FileManager.default.removeItem(at: finalURL)
    let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
    export.outputURL = finalURL; export.outputFileType = .mp4
    let exported = DispatchSemaphore(value: 0)
    export.exportAsynchronously { exported.signal() }; exported.wait()
    guard export.status == .completed else { throw NSError(domain: "video", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(String(describing: export.error))"]) }
    print("wrote \(finalURL.lastPathComponent)")
}

func writeStill(width W: Int, height H: Int, t: Double, to url: URL) {
    let c = makeContext(W, H)
    renderFrame(c, Layout(W: CGFloat(W), H: CGFloat(H)), t)
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

@main
enum SpookyVideo {
    static func main() throws {
        let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("marketing/events/spooky-season-2026/video")
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--stills"), i + 1 < args.count {
            let dir = args.count > i + 2 ? URL(fileURLWithPath: args[i + 2]) : outDir
            for t in args[i + 1].split(separator: ",").compactMap({ Double($0) }) {
                writeStill(width: 1920, height: 1080, t: t, to: dir.appendingPathComponent("still-card-\(t).png"))
                writeStill(width: 1080, height: 1920, t: t, to: dir.appendingPathComponent("still-details-\(t).png"))
            }
            print("stills written to \(dir.path)")
            return
        }
        let audio = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("spooky-soundtrack.m4a")
        try writeAudio(to: audio)
        try writeVideo(width: 1920, height: 1080, audio: audio, to: outDir.appendingPathComponent("spooky-season-event-card-1920x1080.mp4"))
        try writeVideo(width: 1080, height: 1920, audio: audio, to: outDir.appendingPathComponent("spooky-season-event-details-1080x1920.mp4"))
    }
}
