// Renders the Spooky Season in-app event artwork (no text: App Store adds it).
// Run: swift marketing/events/spooky-season-2026/render.swift <output-dir>
import SwiftUI
import AppKit

let pumpkin = Color(red: 1.0, green: 0.478, blue: 0.102)
let potion = Color(red: 0.482, green: 0.247, blue: 0.894)
let slime = Color(red: 0.533, green: 0.894, blue: 0.333)
let midnight = Color(red: 0.106, green: 0.082, blue: 0.188)
let dusk = Color(red: 0.24, green: 0.13, blue: 0.45)

struct BatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var path = Path()
        path.move(to: p(0.5, 0.30))
        path.addLine(to: p(0.46, 0.12)); path.addLine(to: p(0.44, 0.30))
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

struct Pumpkin: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Ellipse().fill(pumpkin.opacity(0.82)).frame(width: size * 0.55, height: size * 0.78).offset(x: -size * 0.2, y: size * 0.1)
            Ellipse().fill(pumpkin.opacity(0.82)).frame(width: size * 0.55, height: size * 0.78).offset(x: size * 0.2, y: size * 0.1)
            Ellipse().fill(pumpkin).frame(width: size * 0.5, height: size * 0.82).offset(y: size * 0.09)
            Capsule().fill(slime.opacity(0.9)).frame(width: size * 0.1, height: size * 0.24).rotationEffect(.degrees(12)).offset(y: -size * 0.36)
        }
        .frame(width: size, height: size * 0.85)
        .shadow(color: pumpkin.opacity(0.45), radius: size * 0.25)
    }
}

/// A round potion flask filled with glowing purple liquid and bubbles.
struct Flask: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(potion.opacity(0.35)).frame(width: size * 1.5).blur(radius: size * 0.3)
            // neck
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(Color.white.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: size * 0.05).stroke(Color.white.opacity(0.5), lineWidth: size * 0.015))
                .frame(width: size * 0.28, height: size * 0.36)
                .offset(y: -size * 0.52)
            Capsule().fill(Color(red: 0.55, green: 0.38, blue: 0.25)).frame(width: size * 0.34, height: size * 0.12).offset(y: -size * 0.72)
            // body
            Circle().fill(Color.white.opacity(0.12)).frame(width: size)
            Circle()
                .fill(LinearGradient(colors: [potion.opacity(0.85), Color(red: 0.32, green: 0.12, blue: 0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: size)
                .mask(Rectangle().frame(width: size, height: size * 0.7).offset(y: size * 0.15))
            ForEach(0..<9, id: \.self) { i in
                let d = Double(i)
                Circle().fill(Color.white.opacity(0.55 - d * 0.04))
                    .frame(width: size * (0.03 + 0.012 * Double(i % 3)))
                    .offset(x: size * (sin(d * 2.1) * 0.28), y: size * (0.32 - d * 0.07))
            }
            Circle().stroke(Color.white.opacity(0.55), lineWidth: size * 0.018).frame(width: size)
            Circle().trim(from: 0.55, to: 0.7).stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
                .frame(width: size * 0.78).rotationEffect(.degrees(-10))
        }
        .frame(width: size * 1.2, height: size * 1.6)
    }
}

struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        let disc = Path(ellipseIn: CGRect(x: rect.minX, y: rect.minY, width: d, height: d))
        let bite = Path(ellipseIn: CGRect(x: rect.minX + d * 0.35, y: rect.minY - d * 0.09, width: d * 0.86, height: d * 0.86))
        return disc.subtracting(bite)
    }
}

struct Moon: View {
    let size: CGFloat
    var body: some View {
        Crescent()
            .fill(Color(red: 1.0, green: 0.86, blue: 0.62))
            .frame(width: size, height: size)
            .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.5).opacity(0.5), radius: size * 0.3)
    }
}

struct Scene: View {
    let w: CGFloat, h: CGFloat
    var body: some View {
        let s = min(w, h)
        ZStack {
            LinearGradient(colors: [midnight, dusk], startPoint: .top, endPoint: .bottom)
            Circle().fill(potion.opacity(0.45)).frame(width: s * 1.1).blur(radius: s * 0.22).position(x: w * 0.78, y: h * 0.15)
            Circle().fill(pumpkin.opacity(0.25)).frame(width: s * 1.0).blur(radius: s * 0.25).position(x: w * 0.12, y: h * 0.95)
            ForEach(0..<40, id: \.self) { i in
                let d = Double(i)
                Circle().fill(Color.white.opacity(0.25 + (d.truncatingRemainder(dividingBy: 4)) * 0.1))
                    .frame(width: 2 + CGFloat(i % 3) * 1.5)
                    .position(x: w * CGFloat((d * 0.618).truncatingRemainder(dividingBy: 1)),
                              y: h * 0.55 * CGFloat((d * 0.377 + 0.05).truncatingRemainder(dividingBy: 1)))
            }
            Moon(size: s * 0.22).position(x: w > h ? w * 0.82 : w * 0.76, y: h * (w > h ? 0.24 : 0.14))
            ForEach(0..<6, id: \.self) { i in
                let d = Double(i)
                let bw = s * (0.07 + 0.025 * CGFloat(i % 3))
                BatShape().fill(Color.black.opacity(0.75))
                    .frame(width: bw, height: bw / 2)
                    .rotationEffect(.degrees(sin(d) * 12))
                    .position(x: w * (0.12 + 0.15 * CGFloat(i)) , y: h * (w > h ? 0.18 + 0.1 * CGFloat(sin(d * 1.7)) : 0.3 + 0.06 * CGFloat(sin(d * 1.7))))
            }
            Flask(size: s * (w > h ? 0.42 : 0.5)).position(x: w * 0.5, y: h * (w > h ? 0.58 : 0.58))
            Pumpkin(size: s * 0.3).position(x: w * (w > h ? 0.24 : 0.22), y: h * (w > h ? 0.82 : 0.84))
            Pumpkin(size: s * 0.22).position(x: w * (w > h ? 0.76 : 0.8), y: h * (w > h ? 0.85 : 0.86))
            Pumpkin(size: s * 0.15).position(x: w * (w > h ? 0.88 : 0.62), y: h * (w > h ? 0.88 : 0.9))
            Rectangle().fill(LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .center, endPoint: .bottom))
        }
        .frame(width: w, height: h)
        .clipped()
    }
}

@MainActor func render(_ w: CGFloat, _ h: CGFloat, to url: URL) {
    let r = ImageRenderer(content: Scene(w: w, h: h))
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.lastPathComponent) \(cg.width)x\(cg.height)")
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
MainActor.assumeIsolated {
    render(1920, 1080, to: out.appendingPathComponent("event-card-1920x1080.png"))
    render(1080, 1920, to: out.appendingPathComponent("event-details-1080x1920.png"))
}
