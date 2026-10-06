// keymap-overlay [--opacity <0.1-1>] <image>: float an image over everything without
// taking focus. Click it, or kill the process, to dismiss. Karabiner's nav layer toggles it.
import AppKit

final class DismissOnClick: NSImageView {
    override func mouseDown(with event: NSEvent) { exit(0) }
}

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: keymap-overlay [--opacity <0.1-1>] <image>\n".utf8))
    exit(64)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var opacity = 1.0
if arguments.first == "--opacity" {
    guard arguments.count >= 2, let value = Double(arguments[1]), (0.1...1).contains(value) else { usage() }
    opacity = value
    arguments.removeFirst(2)
}
guard arguments.count == 1, let image = NSImage(contentsOfFile: arguments[0]) else { usage() }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let pointer = NSEvent.mouseLocation
guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else {
    exit(1)
}
let area = screen.visibleFrame
let scale = min(1, area.width * 0.8 / image.size.width, area.height * 0.8 / image.size.height)
let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
let origin = NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)

// A non-activating panel keeps keyboard focus in the app being navigated.
let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.level = .statusBar
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = true
panel.alphaValue = opacity
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

let view = DismissOnClick(image: image)
view.imageScaling = .scaleProportionallyUpOrDown
panel.contentView = view
panel.orderFrontRegardless()
app.run()
