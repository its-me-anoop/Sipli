// Renders Sipli's alternate app icons: each is a full-bleed background layer
// plus the Home bottle with themed water, written as Icon Composer `.icon`
// folders, and a small preview image for the in-app icon picker.
//
// Build & run from the repo root:
//   swiftc -O -parse-as-library scripts/app-icon/render-variants.swift \
//     WaterQuest/Components/BottleWaterModel.swift -o /tmp/sipli-icon-variants && /tmp/sipli-icon-variants
import AppKit
import SwiftUI

private func rgb(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}
private let highlight = Color(red: 0.9619, green: 0.9779, blue: 0.9900)
private let bottleAspect = 1240.0 / 1748.0

struct Variant {
    let id: String              // AppIcon-<id>
    let background: [Color]     // top → bottom
    let glow: Color
    let water: Color
    var spooky = false
}

private let variants: [Variant] = [
    Variant(id: "Midnight", background: [rgb(0x12284F), rgb(0x050B18)], glow: rgb(0x2B6BFF), water: rgb(0x5A9BFF)),
    Variant(id: "Ocean", background: [rgb(0x4A8DFF), rgb(0x1340C2)], glow: rgb(0x9FE3FF), water: rgb(0x8FE6FF)),
    Variant(id: "Mint", background: [rgb(0xEFFCF8), rgb(0xBDEFE3)], glow: rgb(0x6FE3D2), water: rgb(0x12B5A0)),
    Variant(id: "Sunrise", background: [rgb(0xFFD27A), rgb(0xFF7A66)], glow: rgb(0xFFF1C9), water: rgb(0x2B6BFF)),
    Variant(id: "Berry", background: [rgb(0xF7EAFF), rgb(0xE2C6FF)], glow: rgb(0xFFFFFF), water: rgb(0xC2338A)),
    // Slime-green brew: purple water would vanish into the purple sky.
    Variant(id: "Spooky", background: [rgb(0x1B1530), rgb(0x3D2173)], glow: rgb(0x7B3FE4), water: rgb(0x7CDB3A), spooky: true),
]

// MARK: - Drawing

private struct Water: View {
    let color: Color
    let remaining = 0.74
    var body: some View {
        Canvas { context, size in
            var bottle = Path(); bottle.addLines(BottleWaterGeometry.outline(size: size)); bottle.closeSubpath()
            context.clip(to: bottle)
            let level = BottleWaterGeometry.surfaceY(remaining: remaining, tilt: 0, size: size)
            func surface(back: Bool) -> Path {
                var p = Path()
                for i in 0...120 {
                    let x = size.width * Double(i) / 120
                    let u = (x / size.width - 0.25) / 0.486
                    let wave = sin(u * .pi * 2 + 0.9 + (back ? 1.4 : 0)) + 0.3 * sin(u * .pi * 4 - 0.63)
                    let y = level + size.height * 0.008 * wave * (back ? 0.6 : 1) + (back ? -size.height * 0.004 : 0)
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
                return p
            }
            func filled(_ s: Path) -> Path {
                var p = s; p.addLine(to: CGPoint(x: size.width, y: size.height)); p.addLine(to: CGPoint(x: 0, y: size.height)); p.closeSubpath(); return p
            }
            let rear = surface(back: true), front = surface(back: false)
            context.fill(filled(rear), with: .color(color.opacity(0.34)))
            context.fill(filled(front), with: .linearGradient(Gradient(colors: [color.opacity(0.66), color.opacity(0.97)]),
                startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height * 0.94)))
            context.stroke(rear, with: .color(highlight.opacity(0.36)), lineWidth: size.width * 0.003)
            context.stroke(front, with: .color(highlight.opacity(0.86)), lineWidth: size.width * 0.005)
            context.clip(to: filled(front))
            context.fill(Path(CGRect(x: size.width * 0.34, y: 0, width: size.width * 0.09, height: size.height)),
                with: .linearGradient(Gradient(colors: [.clear, highlight.opacity(0.22), .clear]),
                    startPoint: CGPoint(x: size.width * 0.34, y: 0), endPoint: CGPoint(x: size.width * 0.43, y: 0)))
            for i in 0..<5 {
                let x = size.width * (0.31 + Double(i) * 0.083)
                let y = level + (size.height * 0.94 - level) * (0.25 + 0.14 * Double((i * 3) % 5))
                let r = size.width * (i.isMultiple(of: 2) ? 0.007 : 0.011)
                context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                               with: .color(highlight.opacity(0.5)), lineWidth: size.width * 0.0025)
            }
        }
    }
}

private struct BatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var path = Path()
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
}

private struct WitchHat: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.22, y: h * 0.82))
                    p.addQuadCurve(to: CGPoint(x: w * 0.62, y: 0), control: CGPoint(x: w * 0.42, y: h * 0.3))
                    p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.82), control: CGPoint(x: w * 0.62, y: h * 0.4))
                    p.closeSubpath()
                }.fill(rgb(0x1B1530))
                Rectangle().fill(rgb(0xFF7A1A)).frame(width: w * 0.54, height: h * 0.1).offset(y: -h * 0.18)
                Capsule().fill(rgb(0x1B1530)).frame(width: w, height: h * 0.18)
            }
        }
    }
}

private struct Background: View {
    let v: Variant
    var body: some View {
        ZStack {
            LinearGradient(colors: v.background, startPoint: .top, endPoint: .bottom)
            Circle().fill(v.glow.opacity(v.spooky ? 0.55 : 0.35)).frame(width: 760).blur(radius: 150).offset(y: 40)
            if v.spooky {
                Circle().fill(rgb(0xFF7A1A).opacity(0.28)).frame(width: 620).blur(radius: 160).offset(x: -260, y: 420)
                ForEach(0..<4, id: \.self) { i in
                    let pos: [(CGFloat, CGFloat, CGFloat)] = [(-330, -330, 120), (300, -300, 96), (-360, 40, 74), (350, 120, 84)]
                    BatShape().fill(Color.black.opacity(0.55))
                        .frame(width: pos[i].2, height: pos[i].2 / 2)
                        .rotationEffect(.degrees(Double(i % 2 == 0 ? -10 : 12)))
                        .offset(x: pos[i].0, y: pos[i].1)
                }
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

/// Transparent 1024 foreground: the bottle (and hat for Spooky).
private struct Foreground: View {
    let v: Variant
    let glass: NSImage
    var body: some View {
        // Spooky leaves headroom for the hat.
        let height = 1024 * (v.spooky ? 0.70 : 0.80)
        ZStack {
            ZStack {
                Water(color: v.water)
                Image(nsImage: glass).resizable().interpolation(.high)
            }
            .aspectRatio(bottleAspect, contentMode: .fit)
            .frame(height: height)
            if v.spooky {
                // Sits on the cap; the bottle art's cap top is ~0.47 of its height above centre.
                WitchHat().frame(width: 270, height: 225).rotationEffect(.degrees(-8))
                    .offset(x: -14, y: -height * 0.47 - 62)
            }
        }
        .offset(x: -1024 * 0.012, y: v.spooky ? 1024 * 0.085 : 1024 * 0.004)
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Output

@MainActor private func png(_ view: some View, scale: CGFloat = 1) -> Data {
    let r = ImageRenderer(content: view); r.scale = scale; r.isOpaque = false
    return NSBitmapImageRep(cgImage: r.cgImage!).representation(using: .png, properties: [:])!
}

private func iconJSON() -> String {
    // Two groups, front to back: the bottle, then the full-bleed background.
    """
    {
      "fill" : "automatic",
      "groups" : [
        {
          "layers" : [
            { "image-name" : "bottle.png", "name" : "bottle", "glass" : false }
          ],
          "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
          "translucency" : { "enabled" : false, "value" : 0.5 }
        },
        {
          "layers" : [
            { "image-name" : "background.png", "name" : "background", "glass" : false }
          ],
          "shadow" : { "kind" : "none", "opacity" : 0 },
          "translucency" : { "enabled" : false, "value" : 0.5 }
        }
      ],
      "supported-platforms" : {
        "squares" : [ "iOS" ]
      }
    }

    """
}

@main
enum RenderVariants {
    @MainActor static func main() throws {
        let root = FileManager.default.currentDirectoryPath
        guard let glass = NSImage(contentsOfFile: "\(root)/WaterQuest/Assets.xcassets/bottle.imageset/bottle.png")
        else { fatalError("run from the repo root") }
        let fm = FileManager.default
        for v in variants {
            let icon = "\(root)/WaterQuest/AppIcons/AppIcon-\(v.id).icon"
            try? fm.removeItem(atPath: icon)
            try fm.createDirectory(atPath: "\(icon)/Assets", withIntermediateDirectories: true)
            try png(Background(v: v)).write(to: URL(fileURLWithPath: "\(icon)/Assets/background.png"))
            try png(Foreground(v: v, glass: glass)).write(to: URL(fileURLWithPath: "\(icon)/Assets/bottle.png"))
            try iconJSON().write(toFile: "\(icon)/icon.json", atomically: true, encoding: .utf8)

            print("wrote AppIcon-\(v.id)")
            // Picker preview: the flattened icon at 240px (80pt @3x). Spooky
            // isn't pickable (it follows the event), so it has none.
            guard !v.spooky else { continue }
            let set = "\(root)/WaterQuest/Assets.xcassets/IconPreview-\(v.id).imageset"
            try? fm.removeItem(atPath: set)
            try fm.createDirectory(atPath: set, withIntermediateDirectories: true)
            let flat = ZStack { Background(v: v); Foreground(v: v, glass: glass) }.frame(width: 1024, height: 1024)
            try png(flat.scaleEffect(240.0 / 1024).frame(width: 240, height: 240)).write(to: URL(fileURLWithPath: "\(set)/preview.png"))
            try """
            {
              "images" : [ { "filename" : "preview.png", "idiom" : "universal" } ],
              "info" : { "author" : "xcode", "version" : 1 }
            }

            """.write(toFile: "\(set)/Contents.json", atomically: true, encoding: .utf8)
        }
        // Preview for the default (Classic) icon: today's icon on its automatic white fill.
        let set = "\(root)/WaterQuest/Assets.xcassets/IconPreview-Classic.imageset"
        try? fm.removeItem(atPath: set)
        try fm.createDirectory(atPath: set, withIntermediateDirectories: true)
        let classic = NSImage(contentsOfFile: "\(root)/WaterQuest/AppIcon.icon/Assets/sipli-bottle.png")!
        let flat = ZStack { Color.white; Image(nsImage: classic).resizable() }.frame(width: 1024, height: 1024)
        try png(flat.scaleEffect(240.0 / 1024).frame(width: 240, height: 240)).write(to: URL(fileURLWithPath: "\(set)/preview.png"))
        try """
        {
          "images" : [ { "filename" : "preview.png", "idiom" : "universal" } ],
          "info" : { "author" : "xcode", "version" : 1 }
        }

        """.write(toFile: "\(set)/Contents.json", atomically: true, encoding: .utf8)
        print("wrote IconPreview-Classic")
    }
}
