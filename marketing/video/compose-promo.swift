import AVFoundation
import AppKit
import CoreText

// Usage: compose <config.json> <out.mp4>
struct Segment: Decodable { let file: String; let start: Double; let end: Double; let title: String; let subtitle: String }
struct Config: Decodable { let icon: String; let segments: [Segment] }

let args = CommandLine.arguments
let config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)

let W = 1080, H = 1920, fps = 30.0
let titleDur = 2.8, endDur = 3.2, xfade = 0.35

// MARK: colours
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
let lagoon = rgb(0.169, 0.420, 1.0)
let ink = rgb(0.039, 0.102, 0.184)
let deep = rgb(0.016, 0.040, 0.085)
let paleText = rgb(0.96, 0.975, 0.99)
let mutedText = rgb(0.70, 0.76, 0.86)

// MARK: source frames
var generators: [String: AVAssetImageGenerator] = [:]
func frame(_ file: String, _ t: Double) -> CGImage? {
    let g = generators[file] ?? {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: file)))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        g.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        generators[file] = g
        return g
    }()
    return try? g.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
}
let icon = NSImage(contentsOfFile: config.icon)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!

// MARK: text
func font(_ size: CGFloat, weight: NSFont.Weight, serif: Bool = false) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if serif, let d = base.fontDescriptor.withDesign(.serif) { return NSFont(descriptor: d, size: size)! }
    return base
}
func drawText(_ ctx: CGContext, _ s: String, font: NSFont, color: CGColor, centerX: CGFloat, topY: CGFloat, maxWidth: CGFloat, alpha: CGFloat = 1, kern: CGFloat = 0) -> CGFloat {
    let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 4
    let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor(cgColor: color)!.withAlphaComponent(alpha), .paragraphStyle: para, .kern: kern])
    let fs = CTFramesetterCreateWithAttributedString(attr)
    let size = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: maxWidth, height: .greatestFiniteMagnitude), nil)
    // Context is flipped (origin top-left); draw text in an unflipped sub-frame.
    let rect = CGRect(x: centerX - maxWidth / 2, y: topY, width: maxWidth, height: ceil(size.height))
    ctx.saveGState()
    ctx.translateBy(x: 0, y: rect.maxY + rect.minY)
    ctx.scaleBy(x: 1, y: -1)
    let path = CGPath(rect: rect, transform: nil)
    CTFrameDraw(CTFramesetterCreateFrame(fs, CFRange(), path, nil), ctx)
    ctx.restoreGState()
    return ceil(size.height)
}

// MARK: easing
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func ease(_ x: Double) -> Double { let t = clamp(x); return t * t * (3 - 2 * t) }

// MARK: scene pieces
func background(_ ctx: CGContext, glow: CGFloat) {
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [ink, deep] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H), options: [])
    let glowGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0.169, 0.420, 1.0, 0.42 * glow), rgb(0.169, 0.420, 1.0, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glowGrad, startCenter: CGPoint(x: W / 2, y: 1130), startRadius: 0,
                           endCenter: CGPoint(x: W / 2, y: 1130), endRadius: 760, options: [])
}

let deviceW: CGFloat = 800
let srcAspect: CGFloat = 2034.0 / 1398.0
let screenRect = CGRect(x: (CGFloat(W) - deviceW) / 2, y: 545, width: deviceW, height: deviceW * srcAspect)

func device(_ ctx: CGContext, images: [(CGImage, CGFloat)], scale: CGFloat, alpha: CGFloat) {
    ctx.saveGState()
    ctx.setAlpha(alpha)
    let c = CGPoint(x: screenRect.midX, y: screenRect.midY)
    ctx.translateBy(x: c.x, y: c.y); ctx.scaleBy(x: scale, y: scale); ctx.translateBy(x: -c.x, y: -c.y)
    let bezel = screenRect.insetBy(dx: -16, dy: -16)
    ctx.setShadow(offset: CGSize(width: 0, height: 30), blur: 70, color: rgb(0, 0, 0, 0.6))
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 64, cornerHeight: 64, transform: nil))
    ctx.setFillColor(rgb(0.07, 0.08, 0.10)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.addPath(CGPath(roundedRect: bezel.insetBy(dx: 2, dy: 2), cornerWidth: 62, cornerHeight: 62, transform: nil))
    ctx.setStrokeColor(rgb(0.30, 0.33, 0.38)); ctx.setLineWidth(2.5); ctx.strokePath()
    ctx.addPath(CGPath(roundedRect: screenRect, cornerWidth: 50, cornerHeight: 50, transform: nil))
    ctx.clip()
    ctx.setFillColor(rgb(0, 0, 0)); ctx.fill(screenRect)
    for (img, a) in images {
        ctx.setAlpha(alpha * a)
        // Flip image draw for top-left context.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: screenRect.maxY + screenRect.minY); ctx.scaleBy(x: 1, y: -1)
        ctx.draw(img, in: screenRect)
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

/// The icon art is the bottle on transparency; present it on a white
/// rounded tile, like the App Store icon.
func drawIcon(_ ctx: CGContext, rect: CGRect, alpha: CGFloat) {
    ctx.saveGState(); ctx.setAlpha(alpha)
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: rgb(0, 0, 0, 0.45))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil))
    ctx.setFillColor(rgb(0.985, 0.985, 0.98)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let aspect = CGFloat(icon.width) / CGFloat(icon.height)
    // The art has wide transparent margins; enlarge it and clip to the tile.
    let h = rect.height * 1.25, w = h * aspect
    let art = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)); ctx.clip()
    ctx.translateBy(x: 0, y: art.maxY + art.minY); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(icon, in: art)
    ctx.restoreGState()
}

// MARK: timeline
let segDurs = config.segments.map { $0.end - $0.start }
let footageTotal = segDurs.reduce(0, +)
let total = titleDur + footageTotal + endDur
let frameCount = Int((total * fps).rounded())

// MARK: writer
let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting(); writer.startSession(atSourceTime: .zero)

for f in 0..<frameCount {
    let T = Double(f) / fps
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    let buffer = pb!
    CVPixelBufferLockBaseAddress(buffer, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    // Top-left origin.
    ctx.translateBy(x: 0, y: CGFloat(H)); ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high

    let footageStart = titleDur, footageEnd = titleDur + footageTotal
    let introOut = ease((T - (titleDur - 0.5)) / 0.6)          // title -> footage
    let outroIn = ease((T - footageEnd + 0.3) / 0.6)            // footage -> end card
    background(ctx, glow: CGFloat(0.6 + 0.4 * introOut * (1 - outroIn)))

    // Title card
    if T < titleDur + 0.2 {
        let a = CGFloat(ease(T / 0.5) * (1 - introOut))
        let rise = CGFloat(1 - ease(T / 0.8)) * 30
        drawIcon(ctx, rect: CGRect(x: CGFloat(W) / 2 - 110, y: 560 + rise, width: 220, height: 220), alpha: a)
        _ = drawText(ctx, "Sipli", font: font(110, weight: .semibold, serif: true), color: paleText, centerX: CGFloat(W) / 2, topY: 830 + rise, maxWidth: 900, alpha: a)
        let a2 = CGFloat(ease((T - 0.45) / 0.6) * (1 - introOut))
        _ = drawText(ctx, "Now unfolds on iPhone Duo.", font: font(58, weight: .medium), color: lagoon, centerX: CGFloat(W) / 2, topY: 1000 + rise, maxWidth: 960, alpha: a2)
    }

    // Footage
    if T >= footageStart - 0.5 && T < footageEnd + 0.4 {
        let local = min(max(T - footageStart, 0), footageTotal - 0.001)
        var idx = 0, acc = 0.0
        while idx < segDurs.count - 1 && local >= acc + segDurs[idx] { acc += segDurs[idx]; idx += 1 }
        let seg = config.segments[idx]
        let into = local - acc
        var layers: [(CGImage, CGFloat)] = []
        if idx > 0 && into < xfade, let prev = frame(config.segments[idx - 1].file, config.segments[idx - 1].end) {
            layers.append((prev, 1))
        }
        if let img = frame(seg.file, seg.start + into) {
            layers.append((img, idx > 0 && into < xfade ? CGFloat(ease(into / xfade)) : 1))
        }
        let scale = CGFloat(0.9 + 0.1 * introOut) * CGFloat(1 - 0.06 * outroIn)
        device(ctx, images: layers, scale: scale, alpha: CGFloat(introOut * (1 - outroIn)))

        // Caption
        let ca = CGFloat(ease(into / 0.45) * ease((segDurs[idx] - into) / 0.3 + (idx == segDurs.count - 1 ? 1 : 0)) * (1 - outroIn) * introOut)
        let slide = CGFloat(1 - ease(into / 0.5)) * 24
        let h = drawText(ctx, seg.title, font: font(72, weight: .bold), color: paleText, centerX: CGFloat(W) / 2, topY: 170 + slide, maxWidth: 960, alpha: ca)
        _ = drawText(ctx, seg.subtitle, font: font(40, weight: .regular), color: mutedText, centerX: CGFloat(W) / 2, topY: 170 + h + 22 + slide, maxWidth: 940, alpha: ca)
    }

    // End card
    if T >= footageEnd - 0.3 {
        let a = CGFloat(outroIn)
        let rise = CGFloat(1 - outroIn) * 30
        drawIcon(ctx, rect: CGRect(x: CGFloat(W) / 2 - 120, y: 520 + rise, width: 240, height: 240), alpha: a)
        _ = drawText(ctx, "Sipli", font: font(120, weight: .semibold, serif: true), color: paleText, centerX: CGFloat(W) / 2, topY: 800 + rise, maxWidth: 900, alpha: a)
        _ = drawText(ctx, "Hydration that fits your day.", font: font(52, weight: .medium), color: mutedText, centerX: CGFloat(W) / 2, topY: 975 + rise, maxWidth: 960, alpha: a)
        let a2 = CGFloat(ease((T - footageEnd - 0.4) / 0.6))
        // Pill
        let pill = CGRect(x: CGFloat(W) / 2 - 330, y: 1150, width: 660, height: 112)
        ctx.saveGState(); ctx.setAlpha(a2)
        ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 56, cornerHeight: 56, transform: nil)); ctx.setFillColor(lagoon); ctx.fillPath()
        ctx.restoreGState()
        _ = drawText(ctx, "Available on the App Store", font: font(42, weight: .semibold), color: paleText, centerX: CGFloat(W) / 2, topY: 1180, maxWidth: 640, alpha: a2)
        _ = drawText(ctx, "Optimised for iPhone Duo · inner & cover displays", font: font(32, weight: .regular), color: mutedText, centerX: CGFloat(W) / 2, topY: 1310, maxWidth: 960, alpha: a2)
    }

    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(fps)))
    if f % 90 == 0 { print("frame \(f)/\(frameCount)") }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("status", writer.status.rawValue, writer.error?.localizedDescription ?? "", "duration", total)
