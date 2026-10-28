// Renders Sipli's app icon and in-app brand mark from the Home bottle: the
// same glass bottle artwork with water drawn by the same geometry Home uses
// (BottleWaterGeometry), in the brand lagoon blue.
//
// Build & run from the repo root:
//   swiftc -O scripts/app-icon/render.swift WaterQuest/Components/BottleWaterModel.swift \
//     -o /tmp/sipli-icon-render && /tmp/sipli-icon-render
//
// Writes transparent 1024×1024 PNGs; Icon Composer supplies the icon
// background and its dark/tinted variants.
import AppKit
import SwiftUI

private let lagoon = Color(red: 0.169, green: 0.420, blue: 1.0)            // Theme.lagoon #2B6BFF
private let highlight = Color(red: 0.9619, green: 0.9779, blue: 0.9900)    // BottleOptics.highlight
private let bottleAspect = 1240.0 / 1748.0
/// How full the icon bottle looks: generous, with a clear surface line.
private let remaining = 0.74

/// Still water with a gentle, frozen wave — Home's drawing at rest.
private struct Water: View {
    var body: some View {
        Canvas { context, size in
            var bottle = Path()
            bottle.addLines(BottleWaterGeometry.outline(size: size))
            bottle.closeSubpath()
            context.clip(to: bottle)

            let level = BottleWaterGeometry.surfaceY(remaining: remaining, tilt: 0, size: size)
            let amplitude = size.height * 0.008
            func surface(back: Bool) -> Path {
                var path = Path()
                for index in 0...120 {
                    let x = size.width * Double(index) / 120
                    let u = (x / size.width - 0.25) / 0.486
                    let phase = 0.9
                    let wave = sin(u * .pi * 2 + phase + (back ? 1.4 : 0)) + 0.3 * sin(u * .pi * 4 - phase * 0.7)
                    let y = level + amplitude * wave * (back ? 0.6 : 1) + (back ? -size.height * 0.004 : 0)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
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
            let rear = surface(back: true), front = surface(back: false)
            context.fill(filled(rear), with: .color(lagoon.opacity(0.32)))
            context.fill(filled(front), with: .linearGradient(
                Gradient(colors: [lagoon.opacity(0.62), lagoon.opacity(0.96)]),
                startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height * 0.94)))
            context.stroke(rear, with: .color(highlight.opacity(0.36)), lineWidth: size.width * 0.003)
            context.stroke(front, with: .color(highlight.opacity(0.86)), lineWidth: size.width * 0.005)

            context.clip(to: filled(front))
            let light = Path(CGRect(x: size.width * 0.34, y: 0, width: size.width * 0.09, height: size.height))
            context.fill(light, with: .linearGradient(
                Gradient(colors: [.clear, highlight.opacity(0.22), .clear]),
                startPoint: CGPoint(x: size.width * 0.34, y: 0), endPoint: CGPoint(x: size.width * 0.43, y: 0)))
            for index in 0..<5 {
                let x = size.width * (0.31 + Double(index) * 0.083)
                let y = level + (size.height * 0.94 - level) * (0.25 + 0.14 * Double((index * 3) % 5))
                let r = size.width * (index.isMultiple(of: 2) ? 0.007 : 0.011)
                context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                               with: .color(highlight.opacity(0.5)), lineWidth: size.width * 0.0025)
            }
        }
    }
}

private struct FilledBottle: View {
    let glass: NSImage
    var body: some View {
        ZStack {
            Water()
            Image(nsImage: glass).resizable().interpolation(.high)
        }
        .aspectRatio(bottleAspect, contentMode: .fit)
    }
}

/// `heightFraction` of the 1024 canvas; nudged left so the strap balances.
private struct Canvas1024: View {
    let glass: NSImage
    let heightFraction: Double
    var body: some View {
        FilledBottle(glass: glass)
            .frame(height: 1024 * heightFraction)
            .offset(x: -1024 * 0.012, y: 1024 * 0.004)
            .frame(width: 1024, height: 1024)
    }
}

@main
enum RenderAppIcon {
    @MainActor static func write(_ view: some View, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = false
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { fatalError("render failed: \(path)") }
        try! png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) \(cg.width)x\(cg.height)")
    }

    @MainActor static func main() {
        let root = FileManager.default.currentDirectoryPath
        guard let glass = NSImage(contentsOfFile: "\(root)/WaterQuest/Assets.xcassets/bottle.imageset/bottle.png")
        else { fatalError("run from the repo root") }
        let out = "\(root)/scripts/app-icon"
        // App icon foreground: large, inside the icon grid's safe area.
        write(Canvas1024(glass: glass, heightFraction: 0.84), to: "\(out)/sipli-app-icon-1024.png")
        // In-app mark (launch screen, onboarding, paywall, splash): tighter crop.
        write(Canvas1024(glass: glass, heightFraction: 0.94), to: "\(out)/sipli-mark-1024.png")
    }
}
