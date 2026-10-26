// Sipli × iPhone Duo — landscape motion graphic.
//
// Build & run from this folder:
//   swiftc -O -swift-version 5 render.swift -o /tmp/sipli-duo-motion
//   /tmp/sipli-duo-motion                      # full 4K60 film + soundtrack
//   /tmp/sipli-duo-motion --stills 3,8,13      # preview stills only
//
// Device frames are the iPhone Duo's own simulator artwork (assets/chrome):
// the folded shell is DeviceKit's PhoneComposite vector, the inner shell is
// built from the Duo's inner-screen mask, rim style and button art.
import Foundation
import AppKit
import AVFoundation
import CoreImage
import CoreText
import CoreVideo

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let screensDir = ProcessInfo.processInfo.environment["DUO_SCREENS"] ?? (NSHomeDirectory() + "/Desktop/iphone Duo Screenshots")
let args = CommandLine.arguments
let stillsArg: String? = args.firstIndex(of: "--stills").map { args[$0 + 1] }

let PX = 3840, PY = 2160
let DW: CGFloat = 1920, DH: CGFloat = 1080, SC: CGFloat = 2
let fps = 60
let duration = 34.0
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// MARK: - Math

func clamp(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double { max(a, min(b, v)) }
func prog(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func easeIn(_ x: Double) -> Double { x * x * x }
func easeOutBack(_ x: Double) -> Double { let c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2) }
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
func S(_ x: Double) -> CGFloat { CGFloat(sin(x)) }

// MARK: - Colors

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    rgb(CGFloat((h >> 16) & 255) / 255, CGFloat((h >> 8) & 255) / 255, CGFloat(h & 255) / 255, a)
}
let white = hex(0xFFFFFF)
let accent = hex(0x5A86FF)
let soft = hex(0xA7B4D2)

// MARK: - Drawing helpers (all contexts are y-down)

func makeCtx(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    c.interpolationQuality = .high
    return c
}
func drawImage(_ c: CGContext, _ img: CGImage, _ r: CGRect) {
    c.saveGState(); c.translateBy(x: 0, y: r.minY + r.maxY); c.scaleBy(x: 1, y: -1); c.draw(img, in: r); c.restoreGState()
}
func loadPDF(_ name: String) -> CGPDFPage {
    CGPDFDocument(root.appendingPathComponent("assets/chrome/" + name) as CFURL)!.page(at: 1)!
}
func drawPDF(_ c: CGContext, _ p: CGPDFPage, _ r: CGRect) {
    let b = p.getBoxRect(.mediaBox)
    c.saveGState(); c.translateBy(x: r.minX, y: r.maxY); c.scaleBy(x: r.width / b.width, y: -r.height / b.height)
    c.translateBy(x: -b.minX, y: -b.minY); c.drawPDFPage(p); c.restoreGState()
}
func drawPDFRot(_ c: CGContext, _ p: CGPDFPage, _ r: CGRect) {
    c.saveGState(); c.translateBy(x: r.midX, y: r.midY); c.rotate(by: .pi / 2)
    drawPDF(c, p, CGRect(x: -r.height / 2, y: -r.width / 2, width: r.height, height: r.width)); c.restoreGState()
}
func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
func loadImage(_ path: String) -> CGImage {
    NSImage(contentsOfFile: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
func resized(_ img: CGImage, _ f: CGFloat) -> CGImage {
    let w = Int(CGFloat(img.width) * f), h = Int(CGFloat(img.height) * f)
    let c = makeCtx(w, h); drawImage(c, img, CGRect(x: 0, y: 0, width: w, height: h)); return c.makeImage()!
}
func rotatedCCW(_ img: CGImage) -> CGImage {
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let c = makeCtx(img.height, img.width)
    c.translateBy(x: h / 2, y: w / 2); c.rotate(by: -.pi / 2)
    drawImage(c, img, CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
    return c.makeImage()!
}

// MARK: - iPhone Duo devices

struct Device { let frame: CGImage; let shadow: CGImage; let canvas: CGSize; let screen: CGRect; let mask: CGImage }
let K: CGFloat = 2.7      // cached pixels per point
let M: CGFloat = 12       // canvas margin (pt) for side buttons
let shadowPad: CGFloat = 120

/// Grey clip mask (white = screen) from the Duo's own framebuffer mask PDF.
func grayMask(_ p: CGPDFPage, _ w: Int, _ h: Int, rotate: Bool) -> CGImage {
    let c = makeCtx(w, h)
    if rotate {
        c.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2); c.rotate(by: -.pi / 2)
        drawPDF(c, p, CGRect(x: -CGFloat(h) / 2, y: -CGFloat(w) / 2, width: CGFloat(h), height: CGFloat(w)))
    } else { drawPDF(c, p, CGRect(x: 0, y: 0, width: w, height: h)) }
    let g = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let src = c.data!.assumingMemoryBound(to: UInt8.self), dst = g.data!.assumingMemoryBound(to: UInt8.self)
    let bpr = c.bytesPerRow
    for y in 0..<h { for x in 0..<w { dst[y * w + x] = src[y * bpr + x * 4 + 3] } }
    return g.makeImage()!
}
func makeShadow(_ frame: CGImage, _ canvas: CGSize) -> CGImage {
    let s: CGFloat = 0.25
    let fw = canvas.width + 2 * shadowPad, fh = canvas.height + 2 * shadowPad
    let w = Int(fw * s), h = Int(fh * s)
    let c = makeCtx(w, h); c.scaleBy(x: s, y: s)
    drawImage(c, frame, CGRect(x: shadowPad, y: shadowPad, width: canvas.width, height: canvas.height))
    c.setBlendMode(.sourceIn); c.setFillColor(rgb(0, 0.01, 0.05)); c.fill(CGRect(x: 0, y: 0, width: fw, height: fh))
    let ci = CIImage(cgImage: c.makeImage()!).clampedToExtent().applyingGaussianBlur(sigma: Double(38 * s))
        .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    return CIContext().createCGImage(ci, from: CGRect(x: 0, y: 0, width: w, height: h))!
}

let volPDF = loadPDF("Vol BTN.pdf"), powerPDF = loadPDF("X_Power BTN.pdf")

func buildFolded() -> Device {
    // DeviceKit phone15 chrome: 514×706 pt body, screen inset L26 T14 R22 B14.
    let cs = CGSize(width: 514 + 2 * M, height: 706 + 2 * M)
    let c = makeCtx(Int(cs.width * K), Int(cs.height * K)); c.scaleBy(x: K, y: K)
    drawPDF(c, volPDF, CGRect(x: M + 236, y: M - 4, width: 66, height: 16))
    drawPDF(c, volPDF, CGRect(x: M + 316, y: M - 4, width: 66, height: 16))
    drawPDF(c, powerPDF, CGRect(x: M + 514 - 12, y: M + 202, width: 16, height: 113))
    drawPDF(c, loadPDF("PhoneComposite.pdf"), CGRect(x: M, y: M, width: 514, height: 706))
    let frame = c.makeImage()!
    let screen = CGRect(x: M + 26, y: M + 14, width: 466, height: 678)
    let mask = grayMask(loadPDF("cover-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: false)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen, mask: mask)
}

let innerBody = CGSize(width: 709, height: 991), bezel: CGFloat = 20, innerRadius: CGFloat = 83
func buildInnerFrame() -> (CGImage, CGSize) {
    let cs = CGSize(width: innerBody.width + 2 * M, height: innerBody.height + 2 * M)
    let c = makeCtx(Int(cs.width * K), Int(cs.height * K)); c.scaleBy(x: K, y: K)
    // Buttons, as Device Hub places them on the open Duo: volume left, power top.
    drawPDFRot(c, volPDF, CGRect(x: M - 4, y: M + 127, width: 16, height: 66))
    drawPDFRot(c, volPDF, CGRect(x: M - 4, y: M + 207, width: 16, height: 66))
    drawPDFRot(c, powerPDF, CGRect(x: M + 203, y: M - 4, width: 113, height: 16))
    // Rim matches PhoneComposite: light edge, graphite band, black bezel.
    let o = CGRect(x: M, y: M, width: innerBody.width, height: innerBody.height)
    c.setFillColor(rgb(0.78, 0.78, 0.79)); c.addPath(rounded(o, innerRadius)); c.fillPath()
    c.setFillColor(rgb(0.18, 0.18, 0.19)); c.addPath(rounded(o.insetBy(dx: 1.1, dy: 1.1), innerRadius - 1.1)); c.fillPath()
    c.setFillColor(rgb(0, 0, 0)); c.addPath(rounded(o.insetBy(dx: 4.6, dy: 4.6), innerRadius - 4.6)); c.fillPath()
    // Hinge marks at the fold line.
    c.setFillColor(rgb(0.55, 0.55, 0.57))
    c.fill(CGRect(x: M, y: M + innerBody.height / 2 - 0.8, width: 4.6, height: 1.6))
    c.fill(CGRect(x: M + innerBody.width - 4.6, y: M + innerBody.height / 2 - 0.8, width: 4.6, height: 1.6))
    return (c.makeImage()!, cs)
}
func buildUnfolded() -> Device {
    let (frame, cs) = buildInnerFrame()
    let screen = CGRect(x: M + bezel, y: M + bezel, width: 669, height: 951)
    let mask = grayMask(loadPDF("inner-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: false)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen, mask: mask)
}
func buildLandscape() -> Device {
    let (portrait, pcs) = buildInnerFrame()
    let frame = rotatedCCW(portrait)
    let cs = CGSize(width: pcs.height, height: pcs.width)
    let screen = CGRect(x: M + bezel, y: M + bezel, width: 951, height: 669)
    let mask = grayMask(loadPDF("inner-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: true)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen, mask: mask)
}

func drawDevice(_ c: CGContext, _ d: Device, _ center: CGPoint, _ s: CGFloat, angle: CGFloat = 0, alpha: Double = 1,
                shadowAlpha: CGFloat = 0.8, content: (CGContext, CGRect) -> Void) {
    guard alpha > 0.002 else { return }
    c.saveGState()
    c.translateBy(x: center.x, y: center.y); c.rotate(by: angle); c.scaleBy(x: s, y: s)
    let cw = d.canvas.width, ch = d.canvas.height
    let local = CGRect(x: -cw / 2, y: -ch / 2, width: cw, height: ch)
    let layered = alpha < 0.998
    if layered {
        c.clip(to: local.insetBy(dx: -shadowPad, dy: -shadowPad))
        c.setAlpha(CGFloat(alpha)); c.beginTransparencyLayer(auxiliaryInfo: nil)
    }
    let off = 30 / s
    let ox = off * CGFloat(sin(Double(angle))), oy = off * CGFloat(cos(Double(angle)))
    c.saveGState(); c.setAlpha(shadowAlpha)
    drawImage(c, d.shadow, CGRect(x: local.minX - shadowPad + ox, y: local.minY - shadowPad + oy,
                                  width: cw + 2 * shadowPad, height: ch + 2 * shadowPad))
    c.restoreGState()
    drawImage(c, d.frame, local)
    let sr = d.screen.offsetBy(dx: local.minX, dy: local.minY)
    c.saveGState(); c.clip(to: sr, mask: d.mask); content(c, sr); c.restoreGState()
    if layered { c.endTransparencyLayer() }
    c.restoreGState()
}

// MARK: - Assets

print("Building device frames…")
let folded = buildFolded(), unfolded = buildUnfolded(), landscape = buildLandscape()
let shotFiles = try fm.contentsOfDirectory(atPath: screensDir).filter { $0.lowercased().hasSuffix(".png") }.sorted()
precondition(shotFiles.count >= 13, "expected 13 screenshots in \(screensDir)")
var scrTmp: [Int: CGImage] = [:]
for (i, f) in shotFiles.enumerated() {
    let img = loadImage(screensDir + "/" + f)
    let inner = max(img.width, img.height) > 2500
    scrTmp[i + 1] = resized(img, inner ? 0.68 : 0.85)
}
let scr = scrTmp
let icon = loadImage(root.appendingPathComponent("assets/app-icon.png").path)

// MARK: - Text

func font(_ size: CGFloat, _ weight: NSFont.Weight, serif: Bool = false, italic: Bool = false) -> CTFont {
    var f = NSFont.systemFont(ofSize: size, weight: weight)
    if serif, let d = f.fontDescriptor.withDesign(.serif) { f = NSFont(descriptor: d, size: size) ?? f }
    if italic { f = NSFont(descriptor: f.fontDescriptor.withSymbolicTraits(.italic), size: size) ?? f }
    return f as CTFont
}
let fEyebrow = font(21, .semibold)
let fHead = font(88, .semibold, serif: true)
let fHeadMid = font(64, .semibold, serif: true)
let fSub = font(30, .regular)
let fSubSmall = font(27, .regular)
let fLabel = font(23, .semibold)
let fLogo = font(86, .bold, serif: true)
let fLogoBig = font(124, .bold, serif: true)
let fTag = font(56, .medium, serif: true, italic: true)
let fMeta = font(25, .medium)

struct Seg { let s: String; let color: CGColor; init(_ s: String, _ color: CGColor = white) { self.s = s; self.color = color } }

func ctLine(_ s: String, _ f: CTFont, _ color: CGColor, _ kern: CGFloat) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): kern]))
}
func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }

/// Word-by-word rise-in, fade-out line of text. `y` is the baseline; align 0 = left, 0.5 = centre.
func drawLine(_ c: CGContext, _ segs: [Seg], _ f: CTFont, x: CGFloat, y: CGFloat, t: Double, start: Double, end: Double,
              align: CGFloat = 0, kern: CGFloat = 0, stagger: Double = 0.05, rise: CGFloat = 34) {
    if t < start - 0.01 || t > end + 0.6 { return }
    var tokens: [(CTLine, CGFloat)] = []
    var cursor: CGFloat = 0
    for seg in segs {
        var words = seg.s.components(separatedBy: " ")
        for i in 0..<(words.count - 1) { words[i] += " " }
        for w in words where !w.isEmpty {
            let l = ctLine(w, f, seg.color, kern)
            tokens.append((l, cursor)); cursor += width(l)
        }
    }
    let x0 = x - cursor * align
    for (i, (l, dx)) in tokens.enumerated() {
        let p = easeOut(prog(t, start + Double(i) * stagger, start + Double(i) * stagger + 0.75))
        let q = easeIn(prog(t, end + Double(i) * 0.02, end + Double(i) * 0.02 + 0.4))
        let a = p * (1 - q)
        if a <= 0.002 { continue }
        c.saveGState(); c.setAlpha(CGFloat(a))
        c.textMatrix = .identity
        c.translateBy(x: x0 + dx, y: y + (1 - CGFloat(p)) * rise - CGFloat(q) * 18)
        c.scaleBy(x: 1, y: -1); c.textPosition = .zero
        CTLineDraw(l, c); c.restoreGState()
    }
}

/// Left-column caption block: eyebrow, serif headline lines, supporting lines.
func textBlock(_ c: CGContext, _ t: Double, start: Double, end: Double, eyebrow: String,
               head: [[Seg]], sub: [String], x: CGFloat = 150) {
    if t < start - 0.01 || t > end + 0.8 { return }
    let h: CGFloat = 60 + CGFloat(head.count) * 100 + 22 + CGFloat(sub.count) * 42
    var y = 540 - h / 2
    y += 22
    drawLine(c, [Seg(eyebrow, accent)], fEyebrow, x: x + 2, y: y, t: t, start: start, end: end, kern: 4.5, stagger: 0.02, rise: 16)
    y += 38
    for (i, line) in head.enumerated() {
        y += 88
        drawLine(c, line, fHead, x: x, y: y, t: t, start: start + 0.1 + 0.12 * Double(i), end: end + 0.04 * Double(i))
        y += 12
    }
    y += 22
    for (i, s) in sub.enumerated() {
        y += 34
        drawLine(c, [Seg(s, soft)], fSub, x: x, y: y, t: t, start: start + 0.4 + 0.08 * Double(i), end: end + 0.06,
                 stagger: 0.02, rise: 20)
        y += 8
    }
}

// MARK: - Background

struct Bubble { let x: CGFloat; let speed: Double; let r: CGFloat; let phase: Double; let alpha: CGFloat }
var seed: UInt64 = 0x51F1D0
func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
let bubbles: [Bubble] = (0..<46).map { _ in
    Bubble(x: CGFloat(rnd()) * DW, speed: 18 + rnd() * 46, r: CGFloat(2 + rnd() * rnd() * 11),
           phase: rnd() * 2000, alpha: CGFloat(0.05 + rnd() * 0.12))
}
let bgGrad = CGGradient(colorsSpace: space, colors: [hex(0x0C1A38), hex(0x070E21), hex(0x040814)] as CFArray, locations: [0, 0.55, 1])!
let glowBlue = CGGradient(colorsSpace: space, colors: [rgb(0.22, 0.42, 1.0, 0.34), rgb(0.22, 0.42, 1.0, 0)] as CFArray, locations: [0, 1])!
let glowViolet = CGGradient(colorsSpace: space, colors: [rgb(0.50, 0.32, 0.98, 0.20), rgb(0.50, 0.32, 0.98, 0)] as CFArray, locations: [0, 1])!
let glowCyan = CGGradient(colorsSpace: space, colors: [rgb(0.25, 0.75, 1.0, 0.12), rgb(0.25, 0.75, 1.0, 0)] as CFArray, locations: [0, 1])!
let iconGlow = CGGradient(colorsSpace: space, colors: [rgb(0.30, 0.50, 1.0, 0.55), rgb(0.30, 0.50, 1.0, 0)] as CFArray, locations: [0, 1])!

func drawBackground(_ c: CGContext, _ t: Double) {
    c.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: 0, y: DH), options: [])
    let g1 = CGPoint(x: 1450 + 160 * S(t * 0.21), y: 330 + 90 * S(t * 0.17 + 1))
    let g2 = CGPoint(x: 330 + 140 * S(t * 0.16 + 2), y: 860 + 70 * S(t * 0.23))
    let g3 = CGPoint(x: 960 + 300 * S(t * 0.11 + 4), y: 1000)
    c.drawRadialGradient(glowBlue, startCenter: g1, startRadius: 0, endCenter: g1, endRadius: 980, options: [])
    c.drawRadialGradient(glowViolet, startCenter: g2, startRadius: 0, endCenter: g2, endRadius: 820, options: [])
    c.drawRadialGradient(glowCyan, startCenter: g3, startRadius: 0, endCenter: g3, endRadius: 700, options: [])
    c.setLineWidth(1.3)
    for b in bubbles {
        let travel = Double(DH + 80)
        let y = DH + 40 - CGFloat((t * b.speed + b.phase).truncatingRemainder(dividingBy: travel))
        let x = b.x + 14 * S(t * 0.7 + b.phase)
        let r = CGRect(x: x - b.r, y: y - b.r, width: 2 * b.r, height: 2 * b.r)
        c.setStrokeColor(rgb(0.75, 0.85, 1, b.alpha)); c.strokeEllipse(in: r)
        c.setFillColor(rgb(0.6, 0.75, 1, b.alpha * 0.35)); c.fillEllipse(in: r)
    }
}

// MARK: - Screen content helpers

func show(_ c: CGContext, _ r: CGRect, _ img: CGImage, _ a: Double = 1) {
    if a <= 0.002 { return }
    c.saveGState(); c.setAlpha(CGFloat(a)); drawImage(c, img, r); c.restoreGState()
}
func drawIcon(_ c: CGContext, _ r: CGRect, _ a: Double) {
    if a <= 0.002 { return }
    c.saveGState(); c.setAlpha(CGFloat(a)); drawImage(c, icon, r); c.restoreGState()
}
func label(_ c: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ t: Double, _ start: Double, _ end: Double) {
    drawLine(c, [Seg(s, soft)], fLabel, x: x, y: y, t: t, start: start, end: end, align: 0.5, kern: 0.5, rise: 14)
}

// MARK: - Scenes

// A · logo sting (0 – 2.4)
func sceneA(_ c: CGContext, _ t: Double) {
    guard t < 2.6 else { return }
    let a = min(easeOut(prog(t, 0.1, 0.7)), 1 - easeIn(prog(t, 1.9, 2.4)))
    let pop = easeOutBack(prog(t, 0.1, 0.95))
    let up = -CGFloat(easeIn(prog(t, 1.9, 2.4))) * 50
    let size = 330 * CGFloat(0.72 + 0.28 * pop)
    let ctr = CGPoint(x: 960, y: 450 + up)
    c.saveGState(); c.setAlpha(CGFloat(a))
    c.drawRadialGradient(iconGlow, startCenter: ctr, startRadius: 0, endCenter: ctr, endRadius: 360, options: [])
    c.restoreGState()
    drawIcon(c, CGRect(x: ctr.x - size / 2, y: ctr.y - size / 2, width: size, height: size), a)
    drawLine(c, [Seg("Sipli")], fLogo, x: 960, y: 680 + up, t: t, start: 0.45, end: 1.85, align: 0.5)
}

// Unfolded device placement shared by scenes B–D.
let uS: CGFloat = 0.9
let uC = CGPoint(x: 1290, y: 540)
let fMatchS = innerBody.height * uS / 706
let fMatchX = (uC.x - innerBody.width * uS / 2) + 514 * fMatchS / 2

// B · folded hero (2.2 – 6.0) and C · unfold (6.0 – 7.9) — folded cover
func sceneBC(_ c: CGContext, _ t: Double) {
    guard t > 2.1 && t < 11.6 else { return }
    textBlock(c, t, start: 2.65, end: 5.6, eyebrow: "NEW IN SIPLI 6.0",
              head: [[Seg("Made for")], [Seg("iPhone Duo.", accent)]],
              sub: ["Your hydration companion,", "folded or open."])
    textBlock(c, t, start: 6.4, end: 10.9, eyebrow: "INNER DISPLAY",
              head: [[Seg("Open it up.")]],
              sub: ["Sipli spreads out to fill", "the larger inner screen."])
    let flip = easeInOut(prog(t, 6.9, 7.9))
    guard flip < 0.999 else { return }
    let enter = easeOut(prog(t, 2.2, 3.4))
    let morph = easeInOut(prog(t, 6.0, 6.8))
    let floatAmp = 1 - prog(t, 5.3, 6.0)
    let fs = lerp(1.10, fMatchS, morph)
    let fx = lerp(1290, fMatchX, morph)
    let fy = 540 + (1 - CGFloat(enter)) * 780 + CGFloat(floatAmp) * 10 * S(t * 1.4)
    let ang = -CGFloat(1 - enter) * 0.2
    let alpha = prog(t, 2.2, 2.75) * (1 - easeIn(prog(flip, 0.55, 1.0)))
    let left = fx - 514 * fs / 2
    c.saveGState()
    c.translateBy(x: left, y: 0); c.scaleBy(x: max(CGFloat(cos(flip * .pi / 2)), 0.002), y: 1); c.translateBy(x: -left, y: 0)
    drawDevice(c, folded, CGPoint(x: fx, y: fy), fs, angle: ang, alpha: alpha) { c, r in
        show(c, r, scr[1]!)
        if flip > 0 { c.setFillColor(rgb(0, 0, 0, CGFloat(flip) * 0.55)); c.fill(r) }
    }
    c.restoreGState()
}

// C/D · inner display, rotate to landscape, quick log (6.8 – 17.5)
func sceneD(_ c: CGContext, _ t: Double) {
    guard t > 6.8 && t < 17.6 else { return }
    textBlock(c, t, start: 11.55, end: 14.25, eyebrow: "LANDSCAPE",
              head: [[Seg("Turn it")], [Seg("sideways.", accent)]],
              sub: ["Two columns put your", "whole day at a glance."])
    textBlock(c, t, start: 14.65, end: 16.85, eyebrow: "QUICK LOG",
              head: [[Seg("Log a sip")], [Seg("in a tap.", accent)]],
              sub: ["Add a drink without", "losing your place."])
    let appear = prog(t, 6.85, 7.35)
    let grow = easeOut(prog(t, 6.9, 7.9))
    let rot = easeInOut(prog(t, 11.3, 12.5))
    let exit = easeIn(prog(t, 16.9, 17.5))
    let s = lerp(uS * (0.955 + 0.045 * CGFloat(grow)), 1.0, rot)
    let cx = lerp(uC.x, 1255, rot) - 360 * CGFloat(exit)
    let cy = uC.y + 22 * CGFloat(rot) + 7 * S(t * 1.2) * CGFloat(prog(t, 8.0, 9.2))
    let alpha = appear * (1 - exit)
    if rot < 0.999 {
        drawDevice(c, unfolded, CGPoint(x: cx, y: cy), s, angle: -.pi / 2 * CGFloat(rot), alpha: alpha) { c, r in
            show(c, r, scr[5]!)
            // Like iOS: old layout dims to the app background, new one fades in upright.
            let dim = easeInOut(prog(rot, 0.12, 0.45))
            if dim > 0 { c.setFillColor(rgb(0.07, 0.12, 0.2, CGFloat(dim))); c.fill(r) }
            let q = easeOut(prog(rot, 0.6, 0.97))
            if q > 0 {
                c.saveGState(); c.setAlpha(CGFloat(q))
                c.translateBy(x: r.midX, y: r.midY); c.rotate(by: .pi / 2)
                drawImage(c, scr[6]!, CGRect(x: -r.height / 2, y: -r.width / 2, width: r.height, height: r.width))
                c.restoreGState()
            }
        }
    } else {
        drawDevice(c, landscape, CGPoint(x: cx, y: cy), s, alpha: alpha) { c, r in
            show(c, r, scr[6]!)
            let q = easeOut(prog(t, 14.55, 15.25))
            if q > 0 {
                c.saveGState(); c.setAlpha(CGFloat(q))
                drawImage(c, scr[13]!, r.offsetBy(dx: 0, dy: r.height * 0.07 * CGFloat(1 - q)))
                c.restoreGState()
            }
        }
    }
}

// E · three inner screens (17.2 – 23.1)
func sceneE(_ c: CGContext, _ t: Double) {
    guard t > 17.1 && t < 23.4 else { return }
    drawLine(c, [Seg("Every screen, rebuilt for "), Seg("more room.", accent)], fHeadMid,
             x: 960, y: 175, t: t, start: 17.45, end: 22.45, align: 0.5)
    let shots = [8, 9, 10], names = ["Home", "Insights", "Log a drink"]
    let s: CGFloat = 0.68
    for i in 0..<3 {
        let st = 17.35 + 0.14 * Double(i)
        let p = easeOut(prog(t, st, st + 0.95))
        let ex = easeIn(prog(t, 22.5 + 0.06 * Double(i), 23.1 + 0.06 * Double(i)))
        let cx = 960 + CGFloat(i - 1) * 540
        let cy = 605 + (1 - CGFloat(p)) * 560 + CGFloat(ex) * 90 + 6 * S(t * 1.1 + Double(i) * 1.7)
        drawDevice(c, unfolded, CGPoint(x: cx, y: cy), s, alpha: prog(t, st, st + 0.45) * (1 - ex)) { c, r in
            show(c, r, scr[shots[i]]!)
        }
        label(c, names[i], cx, 605 + innerBody.height * s / 2 + 56, t, st + 0.5, 22.4 + 0.06 * Double(i))
    }
}

// F · cover-screen lineup (23.0 – 28.7)
func sceneF(_ c: CGContext, _ t: Double) {
    guard t > 22.9 && t < 29.0 else { return }
    drawLine(c, [Seg("Closed? "), Seg("Still all Sipli.", accent)], fHeadMid,
             x: 960, y: 165, t: t, start: 23.3, end: 28.1, align: 0.5)
    drawLine(c, [Seg("The cover screen keeps every tab a tap away.", soft)], fSubSmall,
             x: 960, y: 225, t: t, start: 23.6, end: 28.15, align: 0.5, stagger: 0.02, rise: 18)
    let shots = [2, 3, 4, 12], names = ["Today", "Insights", "Diary", "Log"]
    let s: CGFloat = 0.70
    let drift = -32 * CGFloat(prog(t, 23.3, 28.7))
    for i in 0..<4 {
        let st = 23.35 + 0.12 * Double(i)
        let p = easeOut(prog(t, st, st + 0.95))
        let ex = easeIn(prog(t, 28.1 + 0.05 * Double(i), 28.7 + 0.05 * Double(i)))
        let cx = 960 + (CGFloat(i) - 1.5) * 440 + (1 - CGFloat(p)) * 420 + drift
        let cy = 632 + 5 * S(t * 1.2 + Double(i)) + CGFloat(ex) * 80
        drawDevice(c, folded, CGPoint(x: cx, y: cy), s, alpha: prog(t, st, st + 0.45) * (1 - ex)) { c, r in
            show(c, r, scr[shots[i]]!)
        }
        label(c, names[i], 960 + (CGFloat(i) - 1.5) * 440 + drift, 632 + 706 * s / 2 + 56, t, st + 0.55, 28.05 + 0.05 * Double(i))
    }
}

// G · end card (28.6 – 34)
func sceneG(_ c: CGContext, _ t: Double) {
    guard t > 28.6 else { return }
    let pi = easeOutBack(prog(t, 28.9, 29.6))
    let isz = 230 * CGFloat(0.8 + 0.2 * pi)
    drawIcon(c, CGRect(x: 100 + (230 - isz) / 2, y: 255 + (230 - isz) / 2, width: isz, height: isz), easeOut(prog(t, 28.9, 29.4)))
    drawLine(c, [Seg("Sipli")], fLogoBig, x: 146, y: 600, t: t, start: 29.05, end: 99)
    drawLine(c, [Seg("Hydration, "), Seg("unfolded.", accent)], fTag, x: 150, y: 684, t: t, start: 29.3, end: 99)
    drawLine(c, [Seg("Sipli 6.0  ·  Made for iPhone Duo", soft)], fMeta, x: 152, y: 760, t: t, start: 29.6, end: 99,
             kern: 0.6, stagger: 0.03, rise: 16)
    let p1 = easeOut(prog(t, 28.8, 30.0)), p2 = easeOut(prog(t, 29.15, 30.35))
    drawDevice(c, unfolded, CGPoint(x: 1270, y: 556 + (1 - CGFloat(p1)) * 640 + 6 * S(t * 1.1)), 0.78,
               alpha: prog(t, 28.8, 29.3)) { c, r in show(c, r, scr[5]!) }
    drawDevice(c, folded, CGPoint(x: 1640, y: 650 + (1 - CGFloat(p2)) * 640 + 6 * S(t * 1.1 + 2)), 0.74,
               alpha: prog(t, 29.15, 29.65)) { c, r in show(c, r, scr[1]!) }
}

func render(_ c: CGContext, _ t: Double) {
    c.saveGState()
    c.translateBy(x: 0, y: CGFloat(PY)); c.scaleBy(x: SC, y: -SC)
    c.interpolationQuality = .high
    drawBackground(c, t)
    sceneA(c, t); sceneD(c, t); sceneBC(c, t); sceneE(c, t); sceneF(c, t); sceneG(c, t)
    let fadeIn = 1 - easeOut(prog(t, 0, 0.45)), fadeOut = easeIn(prog(t, duration - 0.8, duration))
    let k = max(fadeIn, fadeOut)
    if k > 0 { c.setFillColor(rgb(0.01, 0.015, 0.04, CGFloat(k))); c.fill(CGRect(x: 0, y: 0, width: DW, height: DH)) }
    c.restoreGState()
}

func newRawCtx(_ data: UnsafeMutableRawPointer?, _ bpr: Int) -> CGContext {
    CGContext(data: data, width: PX, height: PY, bitsPerComponent: 8, bytesPerRow: bpr, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
}

// MARK: - Stills

if let stillsArg {
    let outDir = root.appendingPathComponent("previews"); try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
    for ts in stillsArg.split(separator: ",") {
        let t = Double(ts)!
        let c = newRawCtx(nil, 0); render(c, t)
        let half = resized(c.makeImage()!, 0.5)
        let rep = NSBitmapImageRep(cgImage: half)
        try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])!
            .write(to: outDir.appendingPathComponent(String(format: "t%05.2f.jpg", t)))
        print("still", t)
    }
    exit(0)
}

// MARK: - Soundtrack (original, synthesized)

func synthSoundtrack(_ url: URL) throws {
    let sr = 48000.0, n = Int(duration * sr)
    var L = [Float](repeating: 0, count: n), R = [Float](repeating: 0, count: n)
    func mtof(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }
    let bar = 2.5, eighth = bar / 8
    let chords: [[Double]] = [[50, 57, 61, 64, 66], [47, 54, 57, 61, 62], [43, 50, 54, 57, 59], [45, 52, 54, 59, 61]]
    func add(_ i: Int, _ v: Double, pan: Double) { if i >= 0 && i < n { L[i] += Float(v * (1 - pan)); R[i] += Float(v * (1 + pan)) } }
    let bars = Int(ceil(duration / bar))
    for b in 0..<bars {
        let ch = chords[b % 4], t0 = Double(b) * bar
        // pad
        for (vi, m) in ch.dropFirst().enumerated() {
            let f = mtof(m), len = bar + 1.4, pan = (Double(vi) - 1.5) * 0.25
            for k in 0..<Int(len * sr) {
                let tt = Double(k) / sr
                let e = min(tt / 0.8, 1) * min(1, max(0, (len - tt) / 1.2))
                let s = sin(2 * .pi * f * tt) + 0.35 * sin(2 * .pi * f * 1.0035 * tt + 1) + 0.18 * sin(2 * .pi * f * 2 * tt)
                add(Int((t0 + tt) * sr), 0.026 * e * s, pan: pan)
            }
        }
        // bass
        let fb = mtof(ch[0] - 12)
        for k in 0..<Int(bar * sr) {
            let tt = Double(k) / sr
            let e = min(tt / 0.02, 1) * (0.45 + 0.55 * exp(-tt * 1.6)) * min(1, (bar - tt) / 0.2)
            add(Int((t0 + tt) * sr), 0.11 * e * sin(2 * .pi * fb * tt), pan: 0)
        }
        // water-drop arpeggio, from the first device entrance
        if t0 >= 2.0 && t0 < duration - 3 {
            let pattern = [0, 2, 1, 3, 2, 4, 3, 1]
            for (j, idx) in pattern.enumerated() {
                let f = mtof(ch[idx] + 12), st = t0 + Double(j) * eighth, pan = j % 2 == 0 ? -0.35 : 0.35
                for k in 0..<Int(0.9 * sr) {
                    let tt = Double(k) / sr
                    let glide = 1 + 0.03 * exp(-tt * 40)
                    let e = min(tt / 0.004, 1) * exp(-tt * 5.5)
                    add(Int((st + tt) * sr), 0.055 * e * (sin(2 * .pi * f * glide * tt) + 0.25 * sin(4 * .pi * f * tt)), pan: pan)
                }
            }
        }
    }
    // droplet + swell accents on each transition
    var noiseSeed: UInt64 = 7
    func noise() -> Double { noiseSeed = noiseSeed &* 6364136223846793005 &+ 1; return Double(noiseSeed >> 11) / Double(1 << 52) - 1 }
    for hit in [2.2, 6.9, 11.3, 17.3, 23.3, 28.8] {
        var lp = 0.0
        for k in 0..<Int(0.7 * sr) {
            let tt = Double(k) / sr
            lp += 0.05 * (noise() - lp)
            let e = pow(tt / 0.7, 2.2)
            add(Int((hit - 0.7 + tt) * sr), 0.16 * e * lp, pan: sin(tt * 6) * 0.5)
        }
        var ph = 0.0
        for k in 0..<Int(0.35 * sr) {
            let tt = Double(k) / sr
            let f = 480 + 1100 * exp(-tt * 28)
            ph += 2 * .pi * f / sr
            add(Int((hit + tt) * sr), 0.13 * exp(-tt * 14) * sin(ph), pan: 0)
        }
    }
    // stereo echo
    let dL = Int(0.375 * sr), dR = Int(0.469 * sr)
    for i in 0..<n {
        if i >= dL { L[i] += 0.28 * R[i - dL] }
        if i >= dR { R[i] += 0.28 * L[i - dR] }
    }
    var peak: Float = 0
    for i in 0..<n {
        let tt = Double(i) / sr
        let g = Float(min(tt / 0.4, 1) * min(1, (duration - tt) / 2.2))
        L[i] *= g; R[i] *= g; peak = max(peak, abs(L[i]), abs(R[i]))
    }
    let norm = 0.84 / peak
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
    buf.frameLength = AVAudioFrameCount(n)
    for i in 0..<n { buf.floatChannelData![0][i] = L[i] * norm; buf.floatChannelData![1][i] = R[i] * norm }
    try? fm.removeItem(at: url)
    let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sr,
                                                           AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256000],
                               commonFormat: .pcmFormatFloat32, interleaved: false)
    try file.write(from: buf)
}

// MARK: - Film

let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
let videoURL = tmpDir.appendingPathComponent("sipli-duo-motion-video.mov")
let audioURL = tmpDir.appendingPathComponent("sipli-duo-motion-audio.m4a")
let finalURL = root.appendingPathComponent("sipli-iphone-duo-motion-4k.mp4")

print("Synthesizing soundtrack…")
try synthSoundtrack(audioURL)

try? fm.removeItem(at: videoURL)
let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: PX, AVVideoHeightKey: PY,
    AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 48_000_000,
                                      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoExpectedSourceFrameRateKey: fps,
                                      AVVideoMaxKeyFrameIntervalKey: fps]])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: PX, kCVPixelBufferHeightKey as String: PY])
writer.add(input)
writer.startWriting(); writer.startSession(atSourceTime: .zero)

let totalFrames = Int(duration * Double(fps))
let batch = 12
let started = Date()
var f0 = 0
while f0 < totalFrames {
    let count = min(batch, totalFrames - f0)
    var buffers = [CVPixelBuffer?](repeating: nil, count: count)
    for i in 0..<count {
        CVPixelBufferCreate(nil, PX, PY, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &buffers[i])
    }
    let base = f0
    buffers.withUnsafeMutableBufferPointer { bufs in
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let pb = bufs[i]!
            CVPixelBufferLockBaseAddress(pb, [])
            let c = newRawCtx(CVPixelBufferGetBaseAddress(pb), CVPixelBufferGetBytesPerRow(pb))
            render(c, Double(base + i) / Double(fps))
            CVPixelBufferUnlockBaseAddress(pb, [])
        }
    }
    for i in 0..<count {
        while !input.isReadyForMoreMediaData { usleep(2000) }
        adaptor.append(buffers[i]!, withPresentationTime: CMTime(value: Int64(f0 + i), timescale: CMTimeScale(fps)))
    }
    f0 += count
    if f0 % (fps * 2) < batch {
        print(String(format: "frame %d/%d  (%.0fs elapsed)", f0, totalFrames, Date().timeIntervalSince(started)))
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }; done.wait()
guard writer.status == .completed else { fatalError("writer failed: \(String(describing: writer.error))") }

print("Muxing…")
let comp = AVMutableComposition()
let vAsset = AVURLAsset(url: videoURL), aAsset = AVURLAsset(url: audioURL)
let vTrack = vAsset.tracks(withMediaType: .video)[0], aTrack = aAsset.tracks(withMediaType: .audio)[0]
let range = CMTimeRange(start: .zero, duration: vAsset.duration)
let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try cv.insertTimeRange(range, of: vTrack, at: .zero)
let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
try ca.insertTimeRange(CMTimeRange(start: .zero, duration: min(aAsset.duration, vAsset.duration)), of: aTrack, at: .zero)
try? fm.removeItem(at: finalURL)
let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
export.outputURL = finalURL; export.outputFileType = .mp4
let exported = DispatchSemaphore(value: 0)
export.exportAsynchronously { exported.signal() }; exported.wait()
guard export.status == .completed else { fatalError("export failed: \(String(describing: export.error))") }
print("Done → \(finalURL.path)  (\(Int(Date().timeIntervalSince(started)))s)")
