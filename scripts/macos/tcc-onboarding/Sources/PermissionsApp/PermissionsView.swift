import AppKit
import PermissionsCore
import SwiftUI

extension GrantState {
    var symbol: String {
        switch self {
        case .allowed: return "checkmark.circle.fill"
        case .stale: return "exclamationmark.triangle.fill"
        case .denied: return "minus.circle"
        case .unknown: return "questionmark.circle"
        case .notInstalled: return "app.dashed"
        }
    }
    var tint: Color { self == .allowed ? .green : self == .stale ? .orange : .secondary }
}

struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel

    var body: some View {
        Group {
            if model.needsBootstrap {
                BootstrapView(model: model)
            } else if let snapshot = model.snapshot {
                HSplitView {
                    sidebar(snapshot).frame(minWidth: 210, idealWidth: 230, maxWidth: 280)
                    VStack(spacing: 0) {
                        if let error = model.error { ActionError(message: error).padding([.top, .horizontal], 24) }
                        if let row = model.selectedRow {
                            ScrollView {
                                PermissionDetail(row: row, model: model).padding(28)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            taskFooter(row)
                        } else {
                            completion(snapshot).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }.frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    if let error = model.error {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundStyle(.orange)
                        Text("Couldn’t load permissions").font(.title2.weight(.semibold))
                        Text(error).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Try Again") { model.retryLoad() }
                    } else {
                        ProgressView()
                        Text("Checking app permissions…").foregroundStyle(.secondary)
                    }
                }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebar(_ snapshot: InventorySnapshot) -> some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedID) {
                ForEach(PermissionService.allCases, id: \.self) { service in
                    let rows = model.visibleRows.filter { $0.permission.service == service }
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { row in
                                HStack(spacing: 10) {
                                    AppIcon(url: row.subject?.bundleURL, size: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(row.name).lineLimit(1)
                                        Label(row.status.state.title, systemImage: row.status.state.symbol)
                                            .font(.caption).labelStyle(.titleAndIcon)
                                    }
                                }.padding(.vertical, 3).tag(row.id)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(row.name), \(service.title), \(row.status.state.title)")
                            }
                        } header: {
                            HStack {
                                Text(service.title)
                                Spacer()
                                let count = snapshot.rows.filter { $0.permission.service == service && $0.status.state.needsAttention }.count
                                if count > 0 { Text("\(count)").monospacedDigit() }
                            }
                        }
                    }
                }
            }.listStyle(.sidebar)
            Divider()
            HStack {
                Text(model.remainingCount == 0 ? "Review complete" : "\(model.remainingCount) permissions remaining")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }.padding(14)
        }
    }

    private func completion(_ snapshot: InventorySnapshot) -> some View {
        VStack(spacing: 16) {
            Image(systemName: snapshot.needsAttention ? "sidebar.left" : "checkmark.seal")
                .font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
            Text(snapshot.needsAttention ? "Choose a permission" : "Permission review complete")
                .font(.title2.weight(.semibold))
            Text(snapshot.needsAttention ? "Select an app in the sidebar to review its access."
                 : snapshot.rows.allSatisfy({ $0.status.state == .notInstalled })
                 ? "None of the apps in this inventory are installed."
                 : "All installed apps in this inventory have recorded grants.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if !snapshot.needsAttention {
                Text("An app may need to restart before adopting a change.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Done") { NSApp.terminate(nil) }.keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(maxWidth: 420)
    }

    private func taskFooter(_ row: InventoryRow) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Finish Later") { NSApp.terminate(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                if row.status.state.needsAttention {
                    TaskPrimaryAction(task: PermissionTask(row), model: model)
                } else {
                    Button(model.hasNext ? "Next Permission" : "Done") {
                        if model.hasNext { model.nextPermission() } else { NSApp.terminate(nil) }
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(16)
        }
    }
}

struct PermissionDetail: View {
    let row: InventoryRow
    @ObservedObject var model: PermissionsModel

    var body: some View {
        let task = PermissionTask(row)
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                AppIcon(url: row.subject?.bundleURL, size: 56)
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.name).font(.title2.weight(.semibold))
                    Text(row.permission.service.title).foregroundStyle(.secondary)
                }
            }
            Text(row.permission.reason).font(.body)
            VStack(alignment: .leading, spacing: 10) {
                StatusLabel(state: row.status.state)
                Text(task.summary).foregroundStyle(.secondary)
                TaskSteps(steps: task.steps)
            }
            if let subject = row.subject, row.status.state.needsAttention {
                FileTile(url: subject.codeURL, service: row.permission.service,
                         draggable: row.permission.service.supportsDrag)
                SubjectActions(url: subject.codeURL)
            }
            if row.subject != nil, row.status.state.needsAttention {
                HStack {
                    if task.action == .openApp {
                        Button("Open \(row.permission.service.title) Settings") { model.openSettings(for: .permission(row.id)) }
                    } else if let subject = row.subject {
                        Button("Open App") { model.openApp(subject) }
                    }
                }.font(.callout)
            }
            DisclosureGroup("Technical Details") {
                Text(row.status.detail).font(.caption).textSelection(.enabled).padding(.top, 6)
            }.font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct BootstrapView: View {
    @ObservedObject var model: PermissionsModel
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        AppIcon(url: Bundle.main.bundleURL, size: 64)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Allow permission checks").font(.title2.weight(.semibold))
                            Text("Before reviewing your apps, this helper needs access to macOS permission records.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("macOS grants Full Disk Access. This helper uses it to read permission records and never changes them.")
                    TaskSteps(steps: ["Open Privacy & Security → Full Disk Access.",
                                      "Drag Dotfiles Permissions into the list and enable it.",
                                      "Relaunch this helper if the records are still unreadable."])
                    FileTile(url: Bundle.main.bundleURL, service: .fullDiskAccess, draggable: true)
                    SubjectActions(url: Bundle.main.bundleURL)
                    if let error = model.error { ActionError(message: error) }
                    HStack {
                        Button("Relaunch Helper") { model.relaunch() }
                        Button("Check Again") { model.refresh() }.disabled(model.busy)
                    }.font(.callout)
                }
                .padding(28).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                Button("Finish Later") { NSApp.terminate(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open Full Disk Access") { model.openSettings(for: .bootstrap) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.padding(16)
        }
    }
}

struct TaskPrimaryAction: View {
    let task: PermissionTask
    @ObservedObject var model: PermissionsModel
    var compact = false
    var body: some View {
        if compact { buttons.buttonStyle(.bordered) }
        else { buttons.buttonStyle(.borderedProminent) }
    }

    @ViewBuilder
    private var buttons: some View {
        switch task.action {
        case .settings:
            Button(compact ? "Open Settings" : "Open \(task.row.permission.service.title) Settings") { model.openSettings(for: .permission(task.row.id)) }
                .keyboardShortcut(.defaultAction)
        case .openApp:
            if let subject = task.row.subject {
                Button("Open App") { model.openApp(subject) }
                    .keyboardShortcut(.defaultAction)
                    .help("Open \(task.row.name)")
            }
        case .chooseApp:
            Button("Choose App…") { model.chooseApp(for: task.row.appID) }
                .keyboardShortcut(.defaultAction)
        case .none: EmptyView()
        }
    }
}

struct StatusLabel: View {
    let state: GrantState
    var body: some View {
        Label {
            Text(state.title).fontWeight(.medium)
        } icon: {
            Image(systemName: state.symbol).foregroundStyle(state.tint)
        }.accessibilityLabel(state.title)
    }
}

struct TaskSteps: View {
    let steps: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)").font(.caption.weight(.semibold)).monospacedDigit()
                        .frame(width: 20, height: 20).background(.quaternary, in: Circle())
                        .accessibilityHidden(true)
                    Text(step).fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
            }
        }.font(.callout)
    }
}

struct ActionError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.callout).foregroundStyle(.red).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AppIcon: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
              ?? NSImage(named: NSImage.applicationIconName)!)
            .resizable().interpolation(.high).scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
