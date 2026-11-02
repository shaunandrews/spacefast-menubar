// Draws Resources/AppIcon.icns, a placeholder until there's a designed icon:
//   swift tools/make-icon.swift
// macOS icon grid: an 824pt squircle centered on a 1024pt canvas, with a shadow.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(_ size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = size / 1024
    let tile = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * scale, yRadius: 185 * scale)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.shadowBlurRadius = 24 * scale
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(white: 0.16, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(white: 0.30, alpha: 1), NSColor(white: 0.11, alpha: 1)])!.draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: 400 * scale, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    let glyph = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let box = NSRect(x: tile.midX - glyph.size.width / 2, y: tile.midY - glyph.size.height / 2 - 6 * scale,
                     width: glyph.size.width, height: glyph.size.height)
    glyph.draw(in: box)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try! draw(CGFloat(points)).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try! draw(CGFloat(points * 2)).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appending(path: "Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print("Resources/AppIcon.icns")
