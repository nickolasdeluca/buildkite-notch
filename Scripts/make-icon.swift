// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift Scripts/make-icon.swift [preview.png]
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Arc from 12 o'clock going clockwise, `fraction` of a full turn (AppKit coordinates).
func arc(center: CGPoint, radius: CGFloat, fraction: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
    return path
}

func ring(center: CGPoint, radius: CGFloat, width: CGFloat, fraction: CGFloat, color ringColor: NSColor, track: NSColor) {
    let trackPath = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    trackPath.lineWidth = width
    track.setStroke()
    trackPath.stroke()

    let progress = arc(center: center, radius: radius, fraction: fraction)
    progress.lineWidth = width
    progress.lineCapStyle = .round
    ringColor.setStroke()
    progress.stroke()
}

/// Notch hanging from `top`, with concave flares, same geometry as the app's NotchShape.
func notchPath(centerX: CGFloat, top: CGFloat, width: CGFloat, depth: CGFloat, flare: CGFloat, radius: CGFloat) -> NSBezierPath {
    let left = centerX - width / 2
    let right = centerX + width / 2
    let bottom = top - depth
    let path = NSBezierPath()
    path.move(to: CGPoint(x: left, y: top))
    path.curve(to: CGPoint(x: left + flare, y: top - flare),
               controlPoint1: CGPoint(x: left + flare * 0.55, y: top),
               controlPoint2: CGPoint(x: left + flare, y: top - flare * 0.45))
    path.line(to: CGPoint(x: left + flare, y: bottom + radius))
    path.curve(to: CGPoint(x: left + flare + radius, y: bottom),
               controlPoint1: CGPoint(x: left + flare, y: bottom + radius * 0.45),
               controlPoint2: CGPoint(x: left + flare + radius * 0.45, y: bottom))
    path.line(to: CGPoint(x: right - flare - radius, y: bottom))
    path.curve(to: CGPoint(x: right - flare, y: bottom + radius),
               controlPoint1: CGPoint(x: right - flare - radius * 0.45, y: bottom),
               controlPoint2: CGPoint(x: right - flare, y: bottom + radius * 0.45))
    path.line(to: CGPoint(x: right - flare, y: top - flare))
    path.curve(to: CGPoint(x: right, y: top),
               controlPoint1: CGPoint(x: right - flare, y: top - flare * 0.45),
               controlPoint2: CGPoint(x: right - flare * 0.55, y: top))
    path.close()
    return path
}

func drawIcon(in context: NSGraphicsContext) {
    // macOS icon grid: 824pt tile centered on a 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    // Drop shadow under the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x15181D).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Background: charcoal gradient with a soft green glow behind the ring.
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(starting: color(0x2A2F38), ending: color(0x0D0F13))?.draw(in: tile, angle: -90)
    let ringCenter = CGPoint(x: tile.midX, y: tile.midY - 50)
    NSGradient(colors: [color(0x2EE59D, 0.28), color(0x2EE59D, 0)])?
        .draw(fromCenter: ringCenter, radius: 0, toCenter: ringCenter, radius: 340, options: [])

    // The notch, hanging from the top edge of the tile.
    let notchTop = tile.maxY
    let notch = notchPath(centerX: tile.midX, top: notchTop, width: 430, depth: 138, flare: 34, radius: 54)
    NSColor.black.setFill()
    notch.fill()

    // Mini status rings inside the notch: passed, running, blocked.
    let miniY = notchTop - 66
    let miniRadius: CGFloat = 27
    for (index, spec) in [(color(0x2EE59D), CGFloat(1)), (color(0xFFD23F), CGFloat(0.62)), (color(0xB57BFF), CGFloat(1))].enumerated() {
        let x = tile.midX + CGFloat(index - 1) * 104
        ring(center: CGPoint(x: x, y: miniY), radius: miniRadius, width: 11, fraction: spec.1,
             color: spec.0, track: NSColor.white.withAlphaComponent(0.16))
    }

    // Main progress ring with a check: a deploy that passed.
    let bigRadius: CGFloat = 196
    let track = NSBezierPath(ovalIn: CGRect(x: ringCenter.x - bigRadius, y: ringCenter.y - bigRadius,
                                            width: bigRadius * 2, height: bigRadius * 2))
    track.lineWidth = 58
    NSColor.white.withAlphaComponent(0.09).setStroke()
    track.stroke()

    // Gradient-stroked progress arc (clip to the stroked outline, then fill a gradient).
    let progress = arc(center: ringCenter, radius: bigRadius, fraction: 0.78)
    NSGraphicsContext.saveGraphicsState()
    let cg = context.cgContext
    cg.addPath(progress.cgPath)
    cg.setLineWidth(58)
    cg.setLineCap(.round)
    cg.replacePathWithStrokedPath()
    cg.clip()
    NSGradient(starting: color(0x6BF5C0), ending: color(0x13B26B))?
        .draw(in: CGRect(x: ringCenter.x - bigRadius - 40, y: ringCenter.y - bigRadius - 40,
                         width: bigRadius * 2 + 80, height: bigRadius * 2 + 80), angle: -60)
    NSGraphicsContext.restoreGraphicsState()

    // Check mark.
    let check = NSBezierPath()
    check.move(to: CGPoint(x: ringCenter.x - 78, y: ringCenter.y + 2))
    check.line(to: CGPoint(x: ringCenter.x - 22, y: ringCenter.y - 56))
    check.line(to: CGPoint(x: ringCenter.x + 86, y: ringCenter.y + 64))
    check.lineWidth = 52
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor.white.setStroke()
    check.stroke()

    // Subtle top highlight on the tile edge.
    NSGraphicsContext.restoreGraphicsState()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), xRadius: 184, yRadius: 184)
    rim.lineWidth = 3
    NSColor.white.withAlphaComponent(0.08).setStroke()
    rim.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawIcon(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let arguments = CommandLine.arguments
if arguments.count > 1 {
    try render(pixels: 1024).write(to: URL(fileURLWithPath: arguments[1]))
    exit(0)
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "AppIcon.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: iconset.appending(path: "icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: iconset.appending(path: "icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
