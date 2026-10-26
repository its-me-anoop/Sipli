// Sipli 6.0 — iPhone Duo App Store screenshots.
//
// Run from this folder:
//   swift render.swift
//
// Writes opaque 8-bit RGB PNGs at Apple's iPhone Duo sizes:
//   outer/  1398 × 2034  (outer display, portrait)
//   inner/  2007 × 2853  (inner display, portrait)
// App captures in source/ are drawn at their native aspect ratio and clipped
// only by the Duo's own screen masks. Frames are the Duo simulator artwork.
import Foundation
import AppKit
import CoreImage
import CoreText
import ImageIO
import UniformTypeIdentifiers

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// MARK: - Tokens (same palette and type as release-5.0.2)

func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let paper = hex(0xF7F3ED), ink = hex(0x0F1925), blue = hex(0x174EBA), mist = hex(0xDEE7F2)
let navy = hex(0x122336), muted = hex(0x445160), skyOnNavy = hex(0x91B7FE)

enum Theme { case paper, mist, navy, blue }
func colors(_ t: Theme) -> (bg: CGColor, text: CGColor, em: CGColor, sub: CGColor, shadow: CGFloat) {
    switch t {
    case .paper: return (paper, ink, blue, muted, 0.38)
    case .mist: return (mist, ink, blue, muted, 0.38)
    case .navy: return (navy, paper, skyOnNavy, hex(0xD5DCE6), 0.75)
    case .blue: return (blue, paper, paper, hex(0xE6ECF8), 0.6)
    }
}

// MARK: - Drawing helpers (y-down)

func makeCtx(_ w: Int, _ h: Int, opaque: Bool = false) -> CGContext {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1); c.interpolationQuality = .high
    return c
}
func drawImage(_ c: CGContext, _ img: CGImage, _ r: CGRect) {
    c.saveGState(); c.translateBy(x: 0, y: r.minY + r.maxY); c.scaleBy(x: 1, y: -1); c.draw(img, in: r); c.restoreGState()
}
func loadPDF(_ name: String) -> CGPDFPage { CGPDFDocument(root.appendingPathComponent("assets/chrome/" + name) as CFURL)!.page(at: 1)! }
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
func loadImage(_ path: String) -> CGImage { NSImage(contentsOfFile: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
func rotatedCCW(_ img: CGImage) -> CGImage {
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let c = makeCtx(img.height, img.width)
    c.translateBy(x: h / 2, y: w / 2); c.rotate(by: -.pi / 2)
    drawImage(c, img, CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
    return c.makeImage()!
}

// MARK: - iPhone Duo devices

struct Device { let frame: CGImage; let shadow: CGImage; let canvas: CGSize; let screen: CGRect; let mask: CGImage }
let K: CGFloat = 3.2, M: CGFloat = 12, shadowPad: CGFloat = 120

func grayMask(_ p: CGPDFPage, _ w: Int, _ h: Int, rotate: Bool) -> CGImage {
    let c = makeCtx(w, h)
    if rotate {
        c.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2); c.rotate(by: -.pi / 2)
        drawPDF(c, p, CGRect(x: -CGFloat(h) / 2, y: -CGFloat(w) / 2, width: CGFloat(h), height: CGFloat(w)))
    } else { drawPDF(c, p, CGRect(x: 0, y: 0, width: w, height: h)) }
    let g = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let src = c.data!.assumingMemoryBound(to: UInt8.self), dst = g.data!.assumingMemoryBound(to: UInt8.self)
    for y in 0..<h { for x in 0..<w { dst[y * w + x] = src[y * c.bytesPerRow + x * 4 + 3] } }
    return g.makeImage()!
}
func makeShadow(_ frame: CGImage, _ canvas: CGSize) -> CGImage {
    let s: CGFloat = 0.25, fw = canvas.width + 2 * shadowPad, fh = canvas.height + 2 * shadowPad
    let w = Int(fw * s), h = Int(fh * s)
    let c = makeCtx(w, h); c.scaleBy(x: s, y: s)
    drawImage(c, frame, CGRect(x: shadowPad, y: shadowPad, width: canvas.width, height: canvas.height))
    c.setBlendMode(.sourceIn); c.setFillColor(hex(0x050B16)); c.fill(CGRect(x: 0, y: 0, width: fw, height: fh))
    let ci = CIImage(cgImage: c.makeImage()!).clampedToExtent().applyingGaussianBlur(sigma: Double(34 * s))
        .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    return CIContext().createCGImage(ci, from: CGRect(x: 0, y: 0, width: w, height: h))!
}
let volPDF = loadPDF("Vol BTN.pdf"), powerPDF = loadPDF("X_Power BTN.pdf")

func buildFolded() -> Device {
    let cs = CGSize(width: 514 + 2 * M, height: 706 + 2 * M)
    let c = makeCtx(Int(cs.width * K), Int(cs.height * K)); c.scaleBy(x: K, y: K)
    drawPDF(c, volPDF, CGRect(x: M + 236, y: M - 4, width: 66, height: 16))
    drawPDF(c, volPDF, CGRect(x: M + 316, y: M - 4, width: 66, height: 16))
    drawPDF(c, powerPDF, CGRect(x: M + 514 - 12, y: M + 202, width: 16, height: 113))
    drawPDF(c, loadPDF("PhoneComposite.pdf"), CGRect(x: M, y: M, width: 514, height: 706))
    let frame = c.makeImage()!
    let screen = CGRect(x: M + 26, y: M + 14, width: 466, height: 678)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen,
                  mask: grayMask(loadPDF("cover-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: false))
}
/// Folded Duo turned on its side (spine at the bottom).
func buildFoldedLandscape(_ f: Device) -> Device {
    let cs = CGSize(width: f.canvas.height, height: f.canvas.width)
    let screen = CGRect(x: f.screen.minY, y: f.canvas.width - f.screen.maxX, width: f.screen.height, height: f.screen.width)
    return Device(frame: rotatedCCW(f.frame), shadow: rotatedCCW(f.shadow), canvas: cs, screen: screen,
                  mask: grayMask(loadPDF("cover-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: true))
}
let innerBody = CGSize(width: 709, height: 991), bezel: CGFloat = 20, innerRadius: CGFloat = 83
func buildInnerFrame() -> (CGImage, CGSize) {
    let cs = CGSize(width: innerBody.width + 2 * M, height: innerBody.height + 2 * M)
    let c = makeCtx(Int(cs.width * K), Int(cs.height * K)); c.scaleBy(x: K, y: K)
    drawPDFRot(c, volPDF, CGRect(x: M - 4, y: M + 127, width: 16, height: 66))
    drawPDFRot(c, volPDF, CGRect(x: M - 4, y: M + 207, width: 16, height: 66))
    drawPDFRot(c, powerPDF, CGRect(x: M + 203, y: M - 4, width: 113, height: 16))
    let o = CGRect(x: M, y: M, width: innerBody.width, height: innerBody.height)
    c.setFillColor(hex(0xC7C7C9)); c.addPath(rounded(o, innerRadius)); c.fillPath()
    c.setFillColor(hex(0x2E2E30)); c.addPath(rounded(o.insetBy(dx: 1.1, dy: 1.1), innerRadius - 1.1)); c.fillPath()
    c.setFillColor(hex(0x000000)); c.addPath(rounded(o.insetBy(dx: 4.6, dy: 4.6), innerRadius - 4.6)); c.fillPath()
    c.setFillColor(hex(0x8C8C91))
    c.fill(CGRect(x: M, y: M + innerBody.height / 2 - 0.8, width: 4.6, height: 1.6))
    c.fill(CGRect(x: M + innerBody.width - 4.6, y: M + innerBody.height / 2 - 0.8, width: 4.6, height: 1.6))
    return (c.makeImage()!, cs)
}
func buildUnfolded() -> Device {
    let (frame, cs) = buildInnerFrame()
    let screen = CGRect(x: M + bezel, y: M + bezel, width: 669, height: 951)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen,
                  mask: grayMask(loadPDF("inner-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: false))
}
func buildLandscape() -> Device {
    let (portrait, pcs) = buildInnerFrame()
    let frame = rotatedCCW(portrait), cs = CGSize(width: pcs.height, height: pcs.width)
    let screen = CGRect(x: M + bezel, y: M + bezel, width: 951, height: 669)
    return Device(frame: frame, shadow: makeShadow(frame, cs), canvas: cs, screen: screen,
                  mask: grayMask(loadPDF("inner-screen-mask.pdf"), Int(screen.width * K), Int(screen.height * K), rotate: true))
}

/// Draws a device whose body (not canvas) has its top-left at `bodyOrigin`, at `s` px per pt.
func drawDevice(_ c: CGContext, _ d: Device, bodyOrigin: CGPoint, _ s: CGFloat, shadow: CGFloat, _ shot: CGImage) {
    c.saveGState()
    c.translateBy(x: bodyOrigin.x - M * s, y: bodyOrigin.y - M * s); c.scaleBy(x: s, y: s)
    let cw = d.canvas.width, ch = d.canvas.height
    c.saveGState(); c.setAlpha(shadow)
    drawImage(c, d.shadow, CGRect(x: -shadowPad, y: -shadowPad + 26, width: cw + 2 * shadowPad, height: ch + 2 * shadowPad))
    c.restoreGState()
    drawImage(c, d.frame, CGRect(x: 0, y: 0, width: cw, height: ch))
    // Native aspect check: the capture must fit the Duo screen rect exactly.
    let ar = CGFloat(shot.width) / CGFloat(shot.height), sr = d.screen.width / d.screen.height
    precondition(abs(ar - sr) < 0.002, "screen aspect mismatch \(ar) vs \(sr)")
    c.saveGState(); c.clip(to: d.screen, mask: d.mask); drawImage(c, shot, d.screen); c.restoreGState()
    c.restoreGState()
}

// MARK: - Text

func font(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }
func ctLine(_ s: String, _ f: CTFont, _ color: CGColor, _ kern: CGFloat) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): kern]))
}
/// Draws a line with its baseline at y. Returns its width.
@discardableResult
func text(_ c: CGContext, _ s: String, _ f: CTFont, _ color: CGColor, x: CGFloat, y: CGFloat, kern: CGFloat = 0, alignRight: Bool = false) -> CGFloat {
    let l = ctLine(s, f, color, kern)
    let w = CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
    c.saveGState(); c.textMatrix = .identity
    c.translateBy(x: alignRight ? x - w : x, y: y); c.scaleBy(x: 1, y: -1); c.textPosition = .zero
    CTLineDraw(l, c); c.restoreGState()
    return w
}

// MARK: - Slides

struct Spec {
    let name: String, eyebrow: String, line1: String, line2: String, sub: String, theme: Theme
    let layout: Layout
}
enum Layout { case outer(String), inner(String), landscapes(String, String), both(String, String) }

let icon = loadImage(root.appendingPathComponent("assets/app-icon.png").path)
let folded = buildFolded(), foldedLandscape = buildFoldedLandscape(folded), unfolded = buildUnfolded(), landscape = buildLandscape()
func shot(_ n: String) -> CGImage { loadImage(root.appendingPathComponent("source/\(n).png").path) }

struct Metrics { let W: Int, H: Int, margin: CGFloat, brandTop: CGFloat, brandSize: CGFloat, eyebrowSize: CGFloat
    let headSize: CGFloat, headTop: CGFloat, subSize: CGFloat }
let outerM = Metrics(W: 1398, H: 2034, margin: 100, brandTop: 86, brandSize: 50, eyebrowSize: 26, headSize: 132, headTop: 196, subSize: 42)
let innerM = Metrics(W: 2007, H: 2853, margin: 140, brandTop: 120, brandSize: 70, eyebrowSize: 36, headSize: 186, headTop: 282, subSize: 58)

func render(_ spec: Spec, _ m: Metrics) -> (CGImage, CGFloat) {
    let c = makeCtx(m.W, m.H, opaque: true)
    let col = colors(spec.theme)
    c.setFillColor(col.bg); c.fill(CGRect(x: 0, y: 0, width: m.W, height: m.H))
    let W = CGFloat(m.W)

    // Brand row: icon + wordmark, eyebrow on the right.
    let iconSize = m.brandSize * 1.5
    drawImage(c, icon, CGRect(x: m.margin - iconSize * 0.18, y: m.brandTop - iconSize * 0.12, width: iconSize, height: iconSize))
    text(c, "Sipli", font("AvenirNext-DemiBold", m.brandSize), col.text, x: m.margin + iconSize * 0.78,
         y: m.brandTop + m.brandSize * 0.98, kern: -m.brandSize * 0.035)
    text(c, spec.eyebrow.uppercased(), font("AvenirNext-DemiBold", m.eyebrowSize), col.text, x: W - m.margin,
         y: m.brandTop + m.brandSize * 0.92, kern: m.eyebrowSize * 0.09, alignRight: true)

    // Headline: roman line, italic accent line. Then supporting line.
    let lead = m.headSize * 0.98
    let b1 = m.headTop + m.headSize * 0.78
    var widest = text(c, spec.line1, font("Baskerville", m.headSize), col.text, x: m.margin - 4, y: b1, kern: -m.headSize * 0.033)
    widest = max(widest, text(c, spec.line2, font("Baskerville-Italic", m.headSize), col.em, x: m.margin - 4, y: b1 + lead, kern: -m.headSize * 0.03))
    let subY = b1 + lead + m.headSize * 0.32 + m.subSize * 1.25
    widest = max(widest, text(c, spec.sub, font("AvenirNext-Regular", m.subSize), col.sub, x: m.margin, y: subY))
    precondition(widest < W - 2 * m.margin + 8, "\(spec.name): text too wide (\(widest))")
    let textBottom = subY + m.subSize * 0.4

    // Devices.
    var deviceTop: CGFloat = 0
    switch spec.layout {
    case .outer(let n):
        let s: CGFloat = 1.86, bw = 514 * s
        deviceTop = textBottom + 92
        drawDevice(c, folded, bodyOrigin: CGPoint(x: (W - bw) / 2 + 6, y: deviceTop), s, shadow: col.shadow, shot(n))
    case .inner(let n):
        let s: CGFloat = 1.99, bw = innerBody.width * s
        deviceTop = textBottom + 120
        drawDevice(c, unfolded, bodyOrigin: CGPoint(x: (W - bw) / 2, y: deviceTop), s, shadow: col.shadow, shot(n))
    case .landscapes(let inner, let closing):
        let s: CGFloat = 1.74, bw = innerBody.height * s
        deviceTop = textBottom + 170
        drawDevice(c, landscape, bodyOrigin: CGPoint(x: (W - bw) / 2, y: deviceTop), s, shadow: col.shadow, shot(inner))
        let lines = closing.components(separatedBy: "\n"), size = m.headSize * 0.5
        for (i, l) in lines.enumerated() {
            text(c, l, font("Baskerville", size), col.text, x: m.margin,
                 y: CGFloat(m.H) - 170 - CGFloat(lines.count - 1 - i) * size * 1.18, kern: -size * 0.02)
        }
    case .both(let inner, let outer):
        deviceTop = textBottom + 120
        let su: CGFloat = 1.72
        drawDevice(c, unfolded, bodyOrigin: CGPoint(x: m.margin + 10, y: deviceTop), su, shadow: col.shadow, shot(inner))
        let sf: CGFloat = 1.5
        drawDevice(c, folded, bodyOrigin: CGPoint(x: W - m.margin - 514 * sf + 20, y: CGFloat(m.H) - 706 * sf - 130),
                   sf, shadow: col.shadow, shot(outer))
    }
    return (c.makeImage()!, deviceTop - textBottom)
}

func writePNG(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); precondition(CGImageDestinationFinalize(dest))
}

let outerSlides = [
    Spec(name: "01-see-whats-left", eyebrow: "Daily water tracker", line1: "See what\u{2019}s", line2: "left to drink.",
         sub: "Your daily goal, right on the cover screen.", theme: .paper, layout: .outer("outer-today")),
    Spec(name: "02-log-a-drink", eyebrow: "Quick log", line1: "Every drink,", line2: "logged in a tap.",
         sub: "Pick an amount and a drink, then save.", theme: .navy, layout: .outer("outer-log")),
    Spec(name: "03-watch-your-habit", eyebrow: "Insights", line1: "Watch your", line2: "habit grow.",
         sub: "Weekly intake and goal days, at a glance.", theme: .mist, layout: .outer("outer-insights")),
    Spec(name: "04-your-daily-diary", eyebrow: "Diary", line1: "Your days,", line2: "in a diary.",
         sub: "Look back on any day\u{2019}s water.", theme: .paper, layout: .outer("outer-diary")),
    Spec(name: "05-hydration-coach", eyebrow: "Hydration coach", line1: "A gentle", line2: "nudge to sip.",
         sub: "Hydration tips through the day.", theme: .blue, layout: .outer("outer-today-coach")),
]
let innerSlides = [
    Spec(name: "01-made-for-iphone-duo", eyebrow: "iPhone Duo", line1: "Made for", line2: "iPhone Duo.",
         sub: "Sipli opens up on the inner display.", theme: .paper, layout: .inner("inner-home")),
    Spec(name: "02-turn-it-sideways", eyebrow: "Landscape", line1: "Turn it", line2: "sideways.",
         sub: "Two columns put your whole day in view.", theme: .blue,
         layout: .landscapes("inner-home-landscape", "Quests, coach and weather,\nright beside your bottle.")),
    Spec(name: "03-log-a-drink", eyebrow: "Quick log", line1: "Every drink,", line2: "logged in a tap.",
         sub: "Amount, drink and save, all in one sheet.", theme: .navy, layout: .inner("inner-log")),
    Spec(name: "04-the-bigger-picture", eyebrow: "Insights", line1: "See the", line2: "bigger picture.",
         sub: "Trends, goal breakdown and drinks side by side.", theme: .mist, layout: .inner("inner-insights")),
    Spec(name: "05-folded-or-open", eyebrow: "Both displays", line1: "Folded", line2: "or open.",
         sub: "Sipli feels at home on both screens.", theme: .paper, layout: .both("inner-home-tabs", "outer-today")),
]

for (dir, m, slides) in [("outer", outerM, outerSlides), ("inner", innerM, innerSlides)] {
    for spec in slides {
        let (img, gap) = render(spec, m)
        let url = root.appendingPathComponent("\(dir)/\(spec.name)-\(m.W)x\(m.H).png")
        writePNG(img, url)
        print("\(dir)/\(url.lastPathComponent)  text→device gap \(Int(gap))px")
    }
}

// MARK: - Creative assets (product page header + search results)
//   creative/header-3840x1646.png         21:9 product page header, text-free, centred focal point
//   creative/search-results-3840x2560.png 3:2 search results asset
try? fm.createDirectory(at: root.appendingPathComponent("creative"), withIntermediateDirectories: true)
do {
    let W = 3840, H = 1646
    let c = makeCtx(W, H, opaque: true)
    c.setFillColor(navy); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let glow = CGGradient(colorsSpace: space, colors: [hex(0x2A5BD0, 0.30), hex(0x2A5BD0, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(glow, startCenter: CGPoint(x: 1920, y: 760), startRadius: 0,
                         endCenter: CGPoint(x: 1920, y: 760), endRadius: 1500, options: [])
    // Open Duo in landscape, folded Duo in front: one centred idea.
    // iPad shows only a wide middle band (about y 330–1320), so keep both devices inside it.
    let sl: CGFloat = 1.22, lw = innerBody.height * sl, lh = innerBody.width * sl
    let lx = 1920 - lw / 2 - 150, ly = (CGFloat(H) - lh) / 2 - 10
    drawDevice(c, landscape, bodyOrigin: CGPoint(x: lx, y: ly), sl, shadow: 0.8, shot("inner-home-landscape"))
    let sf: CGFloat = 1.08
    drawDevice(c, folded, bodyOrigin: CGPoint(x: lx + lw - 514 * sf * 0.42, y: ly + lh - 706 * sf + 50), sf,
               shadow: 0.85, shot("outer-today"))
    writePNG(c.makeImage()!, root.appendingPathComponent("creative/header-3840x1646.png"))
    print("creative/header-3840x1646.png")
}
do {
    let W = 3840, H = 2560
    let c = makeCtx(W, H, opaque: true)
    c.setFillColor(paper); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // Centred headline, the app's purpose at a glance.
    let size: CGFloat = 230
    let a = ctLine("See what\u{2019}s ", font("Baskerville", size), ink, -size * 0.033)
    let b = ctLine("left to drink.", font("Baskerville-Italic", size), blue, -size * 0.03)
    let wa = CGFloat(CTLineGetTypographicBounds(a, nil, nil, nil)), wb = CGFloat(CTLineGetTypographicBounds(b, nil, nil, nil))
    let x0 = (CGFloat(W) - wa - wb) / 2, base: CGFloat = 400
    text(c, "See what\u{2019}s ", font("Baskerville", size), ink, x: x0, y: base, kern: -size * 0.033)
    text(c, "left to drink.", font("Baskerville-Italic", size), blue, x: x0 + wa, y: base, kern: -size * 0.03)
    let sub = ctLine("Your daily water goal, folded or open.", font("AvenirNext-Regular", 76), muted, 0)
    let ws = CGFloat(CTLineGetTypographicBounds(sub, nil, nil, nil))
    text(c, "Your daily water goal, folded or open.", font("AvenirNext-Regular", 76), muted, x: (CGFloat(W) - ws) / 2, y: base + 150)
    let su: CGFloat = 1.72, uw = innerBody.width * su
    let sf: CGFloat = 1.5, fw = 514 * sf
    let groupW = uw + fw - 250
    let ux = (CGFloat(W) - groupW) / 2, uy: CGFloat = 760
    drawDevice(c, unfolded, bodyOrigin: CGPoint(x: ux, y: uy), su, shadow: 0.38, shot("inner-home"))
    drawDevice(c, folded, bodyOrigin: CGPoint(x: ux + uw - 250, y: uy + 520), sf, shadow: 0.4, shot("outer-today"))
    writePNG(c.makeImage()!, root.appendingPathComponent("creative/search-results-3840x2560.png"))
    print("creative/search-results-3840x2560.png")
}

// MARK: - Siri custom product page (iPhone 6.9", 1320 × 2868)
// Real captures from an iPhone 17 Pro Max simulator (iOS 27.2) in source-siri/.
try? fm.createDirectory(at: root.appendingPathComponent("siri"), withIntermediateDirectories: true)
let siriM = Metrics(W: 1320, H: 2868, margin: 96, brandTop: 92, brandSize: 48, eyebrowSize: 25, headSize: 146, headTop: 250, subSize: 42)
func siriSlide(_ name: String, eyebrow: String, _ l1: String, _ l2: String, sub: String, theme: Theme, shotName: String) {
    let m = siriM, c = makeCtx(m.W, m.H, opaque: true), col = colors(theme), W = CGFloat(m.W)
    c.setFillColor(col.bg); c.fill(CGRect(x: 0, y: 0, width: m.W, height: m.H))
    let iconSize = m.brandSize * 1.5
    drawImage(c, icon, CGRect(x: m.margin - iconSize * 0.18, y: m.brandTop - iconSize * 0.12, width: iconSize, height: iconSize))
    text(c, "Sipli", font("AvenirNext-DemiBold", m.brandSize), col.text, x: m.margin + iconSize * 0.78, y: m.brandTop + m.brandSize * 0.98, kern: -1.7)
    text(c, eyebrow.uppercased(), font("AvenirNext-DemiBold", m.eyebrowSize), col.text, x: W - m.margin, y: m.brandTop + m.brandSize * 0.92, kern: m.eyebrowSize * 0.09, alignRight: true)
    let b1 = m.headTop + m.headSize * 0.78, lead = m.headSize * 0.98
    var widest = text(c, l1, font("Baskerville", m.headSize), col.text, x: m.margin - 4, y: b1, kern: -5)
    widest = max(widest, text(c, l2, font("Baskerville-Italic", m.headSize), col.em, x: m.margin - 4, y: b1 + lead, kern: -4.5))
    let subY = b1 + lead + m.headSize * 0.32 + m.subSize * 1.25
    widest = max(widest, text(c, sub, font("AvenirNext-Regular", m.subSize), col.sub, x: m.margin, y: subY))
    precondition(widest < W - 2 * m.margin + 8, "\(name): text too wide (\(widest))")
    // iPhone in the 5.0.2 style: dark rounded bezel around the unedited capture.
    let shotImg = shot(shotName)
    let sw: CGFloat = 880, sh = sw * CGFloat(shotImg.height) / CGFloat(shotImg.width), pad: CGFloat = 13
    let top = subY + 130, x = (W - sw) / 2
    let outer = CGRect(x: x - pad, y: top - pad, width: sw + 2 * pad, height: sh + 2 * pad)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -24), blur: 70, color: hex(0x0F1925, theme == .navy ? 0.5 : 0.22))
    c.setFillColor(theme == .navy ? hex(0x0A121C) : ink); c.addPath(rounded(outer, 92)); c.fillPath(); c.restoreGState()
    c.saveGState(); c.addPath(rounded(CGRect(x: x, y: top, width: sw, height: sh), 80)); c.clip()
    drawImage(c, shotImg, CGRect(x: x, y: top, width: sw, height: sh)); c.restoreGState()
    writePNG(c.makeImage()!, root.appendingPathComponent("siri/\(name)-1320x2868.png"))
    print("siri/\(name)-1320x2868.png  device bottom \(Int(top + sh + pad)) of 2868")
}
siriSlide("01-log-with-your-voice", eyebrow: "Siri", "Log a drink", "with your voice.",
          sub: "Siri logs it and shows how much is left.", theme: .paper, shotName: "../source-siri/iphone-siri-result-badge")
siriSlide("02-just-say-it", eyebrow: "Siri & Shortcuts", "Just say", "\u{201C}Log a coffee.\u{201D}",
          sub: "Settings lists every phrase Siri knows.", theme: .mist, shotName: "../source-siri/iphone-settings-siri")
siriSlide("03-voice-activated", eyebrow: "Badges", "Earn a badge", "for it, too.",
          sub: "Voice Activated unlocks on your first Siri log.", theme: .navy, shotName: "../source-siri/iphone-badge-voice-activated")
