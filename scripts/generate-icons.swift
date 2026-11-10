#!/usr/bin/env swift
// Generates the Elsewhere app icon, onboarding logo and menubar template glyph.
// Usage: swift scripts/generate-icons.swift <Assets.xcassets path>

import AppKit

let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Elsewhere/Assets.xcassets")

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    draw(context, CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

let accent = color(0xFFB347)

/// Orbit mark: a centre dot for "here", a ring, and a dot on the ring for "elsewhere".
func drawMark(_ context: CGContext, center: CGPoint, radius: CGFloat, stroke: CGFloat, ink: CGColor, planet: CGColor) {
    let angle = CGFloat.pi / 4
    let planetCenter = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    let planetRadius = stroke * 1.55
    let gap = planetRadius + stroke * 0.9

    context.setStrokeColor(ink)
    context.setLineWidth(stroke)
    context.setLineCap(.round)
    let gapAngle = 2 * asin(min(1, gap / (2 * radius)))
    context.addArc(center: center, radius: radius, startAngle: angle + gapAngle, endAngle: angle - gapAngle + 2 * .pi, clockwise: false)
    context.strokePath()

    context.setFillColor(ink)
    context.fillEllipse(in: CGRect(x: center.x - stroke * 1.1, y: center.y - stroke * 1.1, width: stroke * 2.2, height: stroke * 2.2))

    context.setFillColor(planet)
    context.fillEllipse(in: CGRect(x: planetCenter.x - planetRadius, y: planetCenter.y - planetRadius, width: planetRadius * 2, height: planetRadius * 2))
}

func appIcon(size: CGFloat, context: CGContext) {
    let scale = size / 1024
    let rect = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let path = CGPath(roundedRect: rect, cornerWidth: 185 * scale, cornerHeight: 185 * scale, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 28 * scale, color: color(0x000000, 0.35))
    context.addPath(path)
    context.setFillColor(color(0x2B2370))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0x6A5CFF), color(0x2B1F78)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    context.restoreGState()

    drawMark(context, center: CGPoint(x: size / 2, y: size / 2), radius: 250 * scale, stroke: 46 * scale, ink: color(0xFFFFFF), planet: accent)
}

func write(_ data: Data, to path: String) {
    try! data.write(to: assets.appendingPathComponent(path))
}

// App icon
let appIconDir = "AppIcon.appiconset"
for file in (try? FileManager.default.contentsOfDirectory(atPath: assets.appendingPathComponent(appIconDir).path)) ?? [] where file.hasSuffix(".png") {
    try? FileManager.default.removeItem(at: assets.appendingPathComponent("\(appIconDir)/\(file)"))
}
var images: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        write(render(size: pixels) { appIcon(size: $1, context: $0) }, to: "\(appIconDir)/\(name)")
        images.append("""
            {
              "filename" : "\(name)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(points)x\(points)"
            }
        """)
    }
}
write(Data("""
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

""".utf8), to: "\(appIconDir)/Contents.json")

// Onboarding logo
try? FileManager.default.removeItem(at: assets.appendingPathComponent("Logo.imageset/ThereIcon.png"))
for scale in [1, 2, 3] {
    write(render(size: 72 * scale) { appIcon(size: $1, context: $0) }, to: "Logo.imageset/Logo@\(scale)x.png")
}
write(Data("""
{
  "images" : [
    { "filename" : "Logo@1x.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "Logo@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "Logo@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

""".utf8), to: "Logo.imageset/Contents.json")

// Menubar template glyph (black on transparent, macOS tints it)
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    let size = 18 * scale
    write(render(size: size) { context, side in
        drawMark(context, center: CGPoint(x: side / 2, y: side / 2), radius: side * 0.36, stroke: side * 0.095, ink: color(0x000000), planet: color(0x000000))
    }, to: "appIcon.imageset/iconTemplate\(suffix).png")
}

print("Icons written to \(assets.path)")
