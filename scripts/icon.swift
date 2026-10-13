// Draws the app icon: a horn-tweeter speaker on copper, 1024×1024 with no alpha.
// Usage: swift scripts/icon.swift KlipschControl/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let s = 1024.0
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(s), height: Int(s), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, 1])! }
func gradient(_ a: CGColor, _ b: CGColor) -> CGGradient { CGGradient(colorsSpace: cs, colors: [a, b] as CFArray, locations: [0, 1])! }

// Background: copper gradient, top to bottom (CG origin is bottom-left).
ctx.drawLinearGradient(
    gradient(rgb(0.86, 0.47, 0.24), rgb(0.55, 0.23, 0.10)),
    start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Cabinet with a soft shadow.
let cab = CGRect(x: 292, y: 150, width: 440, height: 724)
let cabPath = CGPath(roundedRect: cab, cornerWidth: 64, cornerHeight: 64, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 60, color: rgb(0.2, 0.07, 0.02).copy(alpha: 0.6))
ctx.addPath(cabPath)
ctx.setFillColor(rgb(0.12, 0.11, 0.11))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(cabPath)
ctx.clip()
ctx.drawLinearGradient(
    gradient(rgb(0.20, 0.19, 0.19), rgb(0.09, 0.08, 0.08)),
    start: CGPoint(x: 0, y: cab.maxY), end: CGPoint(x: 0, y: cab.minY), options: [])
ctx.restoreGState()

// Horn tweeter: rounded-square mouth flaring down to a round throat, drawn as
// nested shapes that shrink fast near the mouth (the horn's curve) and darken with depth.
func horn(center c: CGPoint, width w: Double, height h: Double) {
    func shape(_ sw: Double, _ sh: Double, _ r: Double) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: c.x - sw / 2, y: c.y - sh / 2, width: sw, height: sh),
            cornerWidth: r, cornerHeight: r, transform: nil)
    }
    // Bevel around the mouth.
    ctx.addPath(shape(w + 24, h + 24, 52))
    ctx.setFillColor(rgb(0.32, 0.31, 0.31))
    ctx.fillPath()
    ctx.addPath(shape(w + 8, h + 8, 44))
    ctx.setFillColor(rgb(0.05, 0.05, 0.05))
    ctx.fillPath()
    let throat = 64.0
    let steps = 60
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let k = pow(1 - t, 2.2)  // 1 at mouth → 0 at throat
        let sw = throat + (w - throat) * k
        let sh = throat + (h - throat) * k
        let r = min(sw, sh) / 2 * (1 - k) + 40 * k  // rounded square → circle
        let g = 0.30 * (1 - t) + 0.03 * t
        ctx.addPath(shape(sw, sh, r))
        ctx.setFillColor(rgb(g, g, g * 0.98))
        ctx.fillPath()
    }
    // Edges where the horn walls meet: corner to throat, fading inward.
    let inset = 12.0  // corners are rounded, so start just inside them
    for (dx, dy) in [(-1.0, -1.0), (-1, 1), (1, -1), (1, 1)] {
        let from = CGPoint(x: c.x + dx * (w / 2 - inset), y: c.y + dy * (h / 2 - inset))
        let to = CGPoint(x: c.x + dx * throat / 2 * 0.7, y: c.y + dy * throat / 2 * 0.7)
        ctx.saveGState()
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.setLineWidth(5)
        ctx.setLineCap(.round)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(
            gradient(rgb(0.62, 0.60, 0.58), rgb(0.06, 0.06, 0.06)), start: from, end: to, options: [])
        ctx.restoreGState()
    }
    // Phase plug at the throat.
    let p = 22.0
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - p, y: c.y - p, width: p * 2, height: p * 2))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(rgb(0.55, 0.53, 0.52), rgb(0.12, 0.12, 0.12)),
        start: CGPoint(x: c.x, y: c.y + p), end: CGPoint(x: c.x, y: c.y - p), options: [])
    ctx.restoreGState()
}

// Woofer: black trim ring, rolled rubber surround, spun copper cone, domed copper dust cap.
func woofer(center c: CGPoint, radius r: Double) {
    func circle(_ rad: Double) -> CGRect { CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2) }
    func radial(_ inner: Double, _ outer: Double, _ colors: [CGColor], _ locs: [CGFloat], at o: CGPoint? = nil) {
        ctx.saveGState()
        ctx.addEllipse(in: circle(outer))
        ctx.addEllipse(in: circle(inner))
        ctx.clip(using: .evenOdd)
        let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
        ctx.drawRadialGradient(
            g, startCenter: o ?? c, startRadius: inner, endCenter: c, endRadius: outer, options: [])
        ctx.restoreGState()
    }
    // Trim ring.
    radial(r * 0.93, r, [rgb(0.30, 0.29, 0.29), rgb(0.08, 0.08, 0.08)], [0, 1])
    // Surround: dark at both edges, lit along the top of the roll.
    radial(
        r * 0.74, r * 0.93,
        [rgb(0.03, 0.03, 0.03), rgb(0.30, 0.29, 0.29), rgb(0.03, 0.03, 0.03)], [0, 0.45, 1])
    // Cone: copper, lit from the top, then fine spun rings.
    ctx.saveGState()
    ctx.addEllipse(in: circle(r * 0.74))
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(rgb(0.95, 0.62, 0.38), rgb(0.55, 0.25, 0.10)),
        start: CGPoint(x: c.x - r * 0.4, y: c.y + r * 0.74), end: CGPoint(x: c.x + r * 0.4, y: c.y - r * 0.74),
        options: [])
    ctx.setLineWidth(1.5)
    var rad = r * 0.30
    var i = 0
    while rad < r * 0.74 {
        ctx.setStrokeColor(i % 2 == 0 ? rgb(1, 0.85, 0.7).copy(alpha: 0.10)! : rgb(0.3, 0.1, 0).copy(alpha: 0.12)!)
        ctx.strokeEllipse(in: circle(rad))
        rad += 4
        i += 1
    }
    ctx.restoreGState()
    // Shadow where the cone meets the dust cap.
    radial(
        r * 0.30, r * 0.38, [rgb(0.25, 0.09, 0.02).copy(alpha: 0.7)!, rgb(0.25, 0.09, 0.02).copy(alpha: 0)!],
        [0, 1])
    // Dust cap: convex dome, highlight upper-left.
    ctx.saveGState()
    ctx.addEllipse(in: circle(r * 0.30))
    ctx.clip()
    let cap = CGGradient(
        colorsSpace: cs, colors: [rgb(1, 0.84, 0.66), rgb(0.82, 0.45, 0.22), rgb(0.45, 0.18, 0.06)] as CFArray,
        locations: [0, 0.5, 1])!
    ctx.drawRadialGradient(
        cap, startCenter: CGPoint(x: c.x - r * 0.10, y: c.y + r * 0.12), startRadius: 0,
        endCenter: c, endRadius: r * 0.30, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}

horn(center: CGPoint(x: 512, y: 702), width: 290, height: 250)
woofer(center: CGPoint(x: 512, y: 362), radius: 178)

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
precondition(CGImageDestinationFinalize(dest))
