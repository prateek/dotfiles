import AppKit
import PermissionsCore
import SwiftUI

struct FileTile: View {
    let url: URL
    let service: PermissionService
    let draggable: Bool
    var body: some View {
        FileTileSurface(url: url, service: service, draggable: draggable)
            .frame(height: 58)
            .help(url.path)
            .accessibilityLabel("\(url.lastPathComponent). \(draggable ? "Drag to " + service.title : "Permission target"). \(url.path)")
    }
}

private struct FileTileContent: View {
    let url: URL
    let service: PermissionService
    let draggable: Bool
    var body: some View {
        HStack(spacing: 12) {
            AppIcon(url: url, size: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(url.lastPathComponent).fontWeight(.medium).lineLimit(1)
                Text(draggable ? "Drag to \(service.title)" : "Permission target")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: draggable ? "line.3.horizontal" : "app.badge.checkmark")
                .foregroundStyle(.secondary).frame(width: 12, height: 14)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
    }
}

private struct FileTileSurface: NSViewRepresentable {
    let url: URL
    let service: PermissionService
    let draggable: Bool
    func makeNSView(context: Context) -> DragSurface { DragSurface(url: url, service: service, draggable: draggable) }
    func updateNSView(_ view: DragSurface, context: Context) { view.update(url: url, service: service, draggable: draggable) }
}

private final class DragSurface: NSView, NSDraggingSource {
    private var url: URL
    private var draggable: Bool
    private var origin = NSPoint.zero
    private let host: NSHostingView<FileTileContent>

    init(url: URL, service: PermissionService, draggable: Bool) {
        self.url = url
        self.draggable = draggable
        host = NSHostingView(rootView: FileTileContent(url: url, service: service, draggable: draggable))
        super.init(frame: .zero)
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor), host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)])
        update(url: url, service: service, draggable: draggable)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func update(url: URL, service: PermissionService, draggable: Bool) {
        self.url = url
        self.draggable = draggable
        window?.invalidateCursorRects(for: self)
        host.rootView = FileTileContent(url: url, service: service, draggable: draggable)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("\(url.lastPathComponent), \(draggable ? "drag to " + service.title : "permission target")")
        setAccessibilityHelp("Use Show in Finder or Copy Path for a keyboard alternative.")
    }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(convert(point, from: superview)) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { draggable }
    override func resetCursorRects() {
        if draggable { addCursorRect(bounds, cursor: .openHand) }
    }
    override func mouseDown(with event: NSEvent) { origin = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard draggable, hypot(point.x - origin.x, point.y - origin.y) > 3 else { return }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(NSRect(x: 10, y: 13, width: 32, height: 32), contents: NSWorkspace.shared.icon(forFile: url.path))
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}

struct SubjectActions: View {
    let url: URL
    @State private var showPath = false
    var body: some View {
        HStack(spacing: 14) {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .buttonStyle(.link)
            Menu("File") {
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button("Exact Path and Keyboard Help") { showPath = true }
            }.menuStyle(.borderlessButton).fixedSize()
                .popover(isPresented: $showPath) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exact permission target").font(.headline)
                        Text(url.path).textSelection(.enabled)
                        Text("Where Settings has an add (+) button, use it, then press ⌘⇧G and paste the copied path.")
                            .font(.callout).foregroundStyle(.secondary)
                    }.padding(20).frame(width: 320)
                }
        }.font(.caption)
    }
}
