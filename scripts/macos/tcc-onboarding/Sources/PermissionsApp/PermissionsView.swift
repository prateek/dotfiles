import AppKit
import PermissionsCore
import SwiftUI

struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("App permissions").font(.title2.bold())
                    Text("Review access in System Settings. You control each change.").foregroundStyle(.secondary)
                }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            if let error = model.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            if let snapshot = model.snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !snapshot.blockedDatabases.isEmpty { bootstrap }
                        if !snapshot.needsAttention {
                            Text("No installed apps need attention in the recorded permission inventory.")
                                .foregroundStyle(.green)
                        }
                        ForEach(PermissionService.allCases, id: \.self) { service in
                            let rows = snapshot.rows.filter { $0.permission.service == service && (model.showAll || $0.status.state.needsAttention) }
                            if !rows.isEmpty {
                                Text(service.title).font(.headline)
                                ForEach(rows) { row in permissionRow(row) }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if model.error == nil { Text("Reading permission inventory…").foregroundStyle(.secondary) }
            Divider()
            HStack {
                Toggle("Show all expected permissions", isOn: $model.showAll).toggleStyle(.checkbox)
                Spacer()
                Button("Refresh") { model.refresh() }.disabled(model.busy)
                Button(model.snapshot?.needsAttention == false ? "Done" : "Later") { NSApp.terminate(nil) }
                    .keyboardShortcut(.cancelAction)
            }
            Text("Recorded grants may require an app restart. Unreadable or uncertain records stay unresolved.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20)
    }

    private var bootstrap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Allow this helper to read permission records", systemImage: "lock.shield").font(.headline)
            Text("Give Dotfiles Permissions Full Disk Access, then relaunch this helper if the records are still unreadable. It only reads permission records; macOS applies your changes.")
            dragTile(Bundle.main.bundleURL)
            HStack {
                Button("Open Full Disk Access") { model.openSettings(.fullDiskAccess, subjectURL: Bundle.main.bundleURL) }
                Button("Relaunch helper") { model.relaunch() }
            }
        }.padding().background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func permissionRow(_ row: InventoryRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.name).font(.headline)
                Spacer()
                Text(row.status.state.title).foregroundStyle(row.status.state == .allowed ? .green : .secondary)
            }
            Text(row.permission.reason)
            if let subject = row.subject {
                if row.status.state.needsAttention {
                    if row.permission.service.supportsDrag { dragTile(subject.codeURL) }
                    else { Text(subject.codeURL.path).font(.caption).textSelection(.enabled) }
                    if row.permission.service.requiresAppRequest {
                        Text("Open the target app and use the feature to request access, then review its entry in Settings.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Open \(row.permission.service.title)") { model.openSettings(row.permission.service, subjectURL: subject.codeURL) }
                        Button("Open app") { model.openApp(subject) }
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([subject.codeURL]) }
                    }
                }
            } else if row.status.state == .unknown {
                Button("Choose app…") { model.chooseApp(for: row.appID) }
            }
            DisclosureGroup("Details") { Text(row.status.detail).font(.caption).textSelection(.enabled) }
        }.padding().background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func dragTile(_ url: URL) -> some View {
        HStack {
            FileDragSource(url: url).frame(width: 48, height: 48)
            VStack(alignment: .leading) {
                Text("Drag this icon into the permission list, then enable it.").font(.callout)
                Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }.padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct FileDragSource: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> DragIcon { DragIcon(url: url) }
    func updateNSView(_ view: DragIcon, context: Context) { view.url = url }
}

private final class DragIcon: NSImageView, NSDraggingSource {
    var url: URL { didSet { image = NSWorkspace.shared.icon(forFile: url.path) } }
    private var origin = NSPoint.zero

    init(url: URL) {
        self.url = url
        super.init(frame: .zero)
        image = NSWorkspace.shared.icon(forFile: url.path)
        imageScaling = .scaleProportionallyUpOrDown
        setAccessibilityLabel("Drag \(url.lastPathComponent) to System Settings")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func mouseDown(with event: NSEvent) { origin = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - origin.x, point.y - origin.y) > 3 else { return }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}

struct GrantGuidanceView: View {
    @ObservedObject var model: PermissionsModel
    let service: PermissionService
    let url: URL?
    let onBack: () -> Void

    private var status: String {
        guard let url else { return "Review the permission in System Settings." }
        if url == Bundle.main.bundleURL {
            return model.snapshot?.blockedDatabases.isEmpty == true
                ? "Permission records are now readable."
                : "Enable Full Disk Access, then relaunch the helper if needed."
        }
        return model.snapshot?.rows.first { $0.subject?.codeURL == url && $0.permission.service == service }?.status.state.title ?? "Needs review"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url {
                HStack {
                    if service.supportsDrag { FileDragSource(url: url).frame(width: 48, height: 48) }
                    Text(url.lastPathComponent).font(.headline)
                }
                Text(service.supportsDrag ? "Drag the icon into the permission list and enable it."
                     : "Enable the app's entry in System Settings. Open the app to request access if it is absent.")
                Text(url.path).font(.caption).lineLimit(2).textSelection(.enabled)
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Text(status).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("All permissions", action: onBack)
                Spacer()
                Button("Refresh") { model.refresh() }.disabled(model.busy)
            }
        }.padding(16).frame(width: 328)
    }
}
