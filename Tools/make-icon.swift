// Génère Resources/AppIcon.icns : swift Tools/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // Fond : carré arrondi à dégradé indigo -> violet (marge de 100 px comme les icônes macOS).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.16, green: 0.38, blue: 0.95, alpha: 1),
        CGColor(red: 0.55, green: 0.25, blue: 0.90, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    ctx.restoreGState()

    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.setStrokeColor(white); ctx.setFillColor(white); ctx.setLineCap(.round)

    // Capsule du micro.
    let cap = CGRect(x: 432, y: 430, width: 160, height: 290)
    ctx.addPath(CGPath(roundedRect: cap, cornerWidth: 80, cornerHeight: 80, transform: nil)); ctx.fillPath()
    // Arceau.
    ctx.setLineWidth(34)
    ctx.addArc(center: CGPoint(x: 512, y: 520), radius: 118, startAngle: .pi, endAngle: 0, clockwise: false)
    ctx.strokePath()
    // Pied.
    ctx.move(to: CGPoint(x: 512, y: 402)); ctx.addLine(to: CGPoint(x: 512, y: 330)); ctx.strokePath()
    ctx.move(to: CGPoint(x: 440, y: 330)); ctx.addLine(to: CGPoint(x: 584, y: 330)); ctx.strokePath()

    // Ondes sonores de chaque côté.
    for (i, r) in [CGFloat(215), 275].enumerated() {
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: i == 0 ? 0.75 : 0.4))
        ctx.setLineWidth(26)
        for sign in [CGFloat(1), -1] {
            let a: CGFloat = 0.62
            let (start, end) = sign > 0 ? (-a, a) : (.pi - a, .pi + a)
            ctx.addArc(center: CGPoint(x: 512, y: 575), radius: r, startAngle: start, endAngle: end, clockwise: false)
            ctx.strokePath()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: dir)
try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, px) in [("16", 16), ("16@2x", 32), ("32", 32), ("32@2x", 64), ("128", 128), ("128@2x", 256),
                   ("256", 256), ("256@2x", 512), ("512", 512), ("512@2x", 1024)] {
    let base = name.replacingOccurrences(of: "@2x", with: "")
    let file = name.contains("@2x") ? "icon_\(base)x\(base)@2x.png" : "icon_\(base)x\(base).png"
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/\(file)"))
}
