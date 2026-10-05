import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = destination.deletingLastPathComponent().appendingPathComponent("Permissions.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let outline = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 190, yRadius: 190)
NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.20, blue: 0.30, alpha: 1),
           ending: NSColor(srgbRed: 0.28, green: 0.40, blue: 0.52, alpha: 1))!.draw(in: outline, angle: 90)
NSColor.white.withAlphaComponent(0.18).setStroke()
outline.lineWidth = 2
outline.stroke()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor(srgbRed: 0.95, green: 0.97, blue: 0.99, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 210, y: 242, width: 604, height: 546), xRadius: 48, yRadius: 48).fill()
NSGraphicsContext.restoreGraphicsState()
for (index, y) in [620.0, 482.0, 344.0].enumerated() {
    NSColor(srgbRed: 0.26, green: 0.38, blue: 0.51, alpha: 0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: 270, y: y, width: 56, height: 56), xRadius: 14, yRadius: 14).fill()
    NSColor(srgbRed: 0.25, green: 0.33, blue: 0.43, alpha: 0.75).setFill()
    NSBezierPath(roundedRect: NSRect(x: 352, y: y + 29, width: 192 - Double(index) * 24, height: 14), xRadius: 7, yRadius: 7).fill()
    NSColor(srgbRed: 0.45, green: 0.52, blue: 0.61, alpha: 0.32).setFill()
    NSBezierPath(roundedRect: NSRect(x: 352, y: y + 5, width: 142, height: 11), xRadius: 5.5, yRadius: 5.5).fill()
    (index == 1 ? NSColor(srgbRed: 0.66, green: 0.70, blue: 0.75, alpha: 1)
     : NSColor(srgbRed: 0.24, green: 0.61, blue: 0.49, alpha: 1)).setFill()
    NSBezierPath(roundedRect: NSRect(x: 650, y: y + 3, width: 104, height: 50), xRadius: 25, yRadius: 25).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: index == 1 ? 656 : 709, y: y + 9, width: 38, height: 38)).fill()
}
NSColor(srgbRed: 0.24, green: 0.61, blue: 0.49, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 674, y: 150, width: 190, height: 190)).fill()
NSColor.white.setStroke()
let check = NSBezierPath()
check.lineWidth = 18
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: 725, y: 245))
check.line(to: NSPoint(x: 756, y: 216))
check.line(to: NSPoint(x: 813, y: 276))
check.stroke()
image.unlockFocus()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", destination.path, iconset.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: iconset)
