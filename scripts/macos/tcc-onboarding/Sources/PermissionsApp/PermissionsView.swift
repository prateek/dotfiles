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
                checklist(snapshot)
            } else {
                VStack(spacing: 16) {
                    if let error = model.error {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundStyle(.orange)
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

    private func checklist(_ snapshot: InventorySnapshot) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.remainingCount == 0 ? "Your app permissions" : "\(model.remainingCount) permissions to review")
                        .font(.title3.weight(.semibold))
                    Text("You approve each permission in macOS.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Needs Attention") { model.showAll = false }
                    Button("All Permissions") { model.showAll = true }
                } label: { Text(model.showAll ? "All Permissions" : "Needs Attention").font(.callout) }
                    .menuStyle(.borderlessButton).fixedSize()
            }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 18)
            Divider()
            if !snapshot.needsAttention, model.selectedID == nil, !model.showAll {
                completion(snapshot).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(model.visibleApps) { app in
                                AppPermissionSection(app: app, model: model).id("app:" + app.id)
                            }
                        }.padding(.horizontal, 24).padding(.vertical, 8)
                    }
                    .onAppear {
                        if let target = selectedScrollTarget { proxy.scrollTo(target, anchor: .top) }
                    }
                    .onChange(of: model.selectedID) { _, id in
                        if id != nil, let target = selectedScrollTarget { proxy.scrollTo(target, anchor: .top) }
                    }
                }
            }
            if let error = model.error {
                ActionError(message: error).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            Divider()
            HStack {
                Button("Later") { NSApp.terminate(nil) }.keyboardShortcut(.cancelAction)
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                if let row = model.selectedRow {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.name).font(.caption.weight(.medium))
                        Text(row.permission.service.title).font(.caption2).foregroundStyle(.secondary)
                    }.lineLimit(1).frame(maxWidth: 150, alignment: .trailing)
                }
                if let row = model.selectedRow, row.status.state.needsAttention {
                    TaskPrimaryAction(task: PermissionTask(row), model: model)
                } else if model.hasNext {
                    Button("Next Permission") { model.nextPermission() }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") { NSApp.terminate(nil) }.keyboardShortcut(.defaultAction)
                }
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }
    }

    private var selectedScrollTarget: String? {
        guard let row = model.selectedRow else { return nil }
        let first = model.visibleApps.first { $0.id == row.appID }?.rows.first
        return first?.id == row.id ? "app:" + row.appID : "permission:" + row.id
    }

    private func completion(_ snapshot: InventorySnapshot) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
            Text("Permission review complete").font(.title3.weight(.semibold))
            Text(snapshot.rows.allSatisfy({ $0.status.state == .notInstalled })
                 ? "None of the apps in this inventory are installed."
                 : "All installed apps in this inventory have recorded grants.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("An app may need to restart before adopting a change.").font(.caption).foregroundStyle(.secondary)
        }.padding(32).frame(maxWidth: 420)
    }
}

struct AppPermissionSection: View {
    let app: AppReviewGroup
    @ObservedObject var model: PermissionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppIcon(url: app.rows.first?.subject?.bundleURL, size: 32)
                Text(app.name).font(.system(size: 15, weight: .semibold))
                Spacer()
            }.padding(.top, 16)
            ForEach(app.rows) { row in
                VStack(alignment: .leading, spacing: 0) {
                    Button { model.selectedID = row.id } label: {
                        HStack(spacing: 10) {
                            Text(row.permission.service.title).fontWeight(.medium)
                            Spacer(minLength: 12)
                            StatusLabel(state: row.status.state).font(.caption)
                            Image(systemName: model.selectedID == row.id ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 10).padding(.horizontal, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(app.name), \(row.permission.service.title), \(row.status.state.title)")
                        .accessibilityValue(model.selectedID == row.id ? "Expanded" : "Collapsed")
                    if model.selectedID == row.id {
                        PermissionDetail(row: row, model: model).padding(.horizontal, 12).padding(.bottom, 14)
                    }
                }
                .background(model.selectedID == row.id ? Color.accentColor.opacity(0.045) : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .id("permission:" + row.id)
            }
            Divider().padding(.top, 6)
        }
    }
}

struct PermissionDetail: View {
    let row: InventoryRow
    @ObservedObject var model: PermissionsModel

    var body: some View {
        let task = PermissionTask(row)
        VStack(alignment: .leading, spacing: 12) {
            Text(row.permission.reason).font(.callout).foregroundStyle(.secondary)
            Text(task.summary).font(.callout)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(task.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 12, alignment: .leading).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(step).fixedSize(horizontal: false, vertical: true)
                            if index == 1, row.permission.service.supportsDrag,
                               row.status.state.needsAttention, let subject = row.subject {
                                FileTile(url: subject.codeURL, service: row.permission.service, draggable: true)
                                SubjectActions(url: subject.codeURL)
                            }
                        }
                    }.accessibilityElement(children: .contain)
                }
            }.font(.callout)
            if !row.permission.service.supportsDrag, let subject = row.subject {
                SubjectActions(url: subject.codeURL)
            }
            HStack {
                if let subject = row.subject, row.status.state.needsAttention {
                    Menu("More") {
                        Button("Open \(row.name)") { model.openApp(subject) }
                        Button("Open \(row.permission.service.title) Settings") { model.openSettings(for: .permission(row.id)) }
                    }.menuStyle(.borderlessButton).fixedSize()
                }
                DisclosureGroup("Details") {
                    Text(row.status.detail).textSelection(.enabled).padding(.top, 6)
                }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct BootstrapView: View {
    @ObservedObject var model: PermissionsModel
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 10) {
                        AppIcon(url: Bundle.main.bundleURL, size: 48)
                        Text("Allow permission checks").font(.title2.weight(.semibold))
                        Text("Full Disk Access lets this helper read macOS permission records. You approve each app’s access in System Settings.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                    TaskSteps(steps: ["Open Privacy & Security → Full Disk Access.",
                                      "Add this helper to the list and enable it."])
                    FileTile(url: Bundle.main.bundleURL, service: .fullDiskAccess, draggable: true)
                    SubjectActions(url: Bundle.main.bundleURL)
                    Text("macOS grants broad disk access. This helper uses it to read permission records and never changes them.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Still can’t read the records?").font(.caption).foregroundStyle(.secondary)
                        Button("Relaunch Helper") { model.relaunch() }
                            .buttonStyle(.link).font(.caption)
                    }
                }.padding(28).frame(maxWidth: 460).frame(maxWidth: .infinity)
            }
            if let error = model.error { ActionError(message: error).padding(.horizontal, 24).padding(.bottom, 12) }
            Divider()
            HStack {
                Button("Later") { NSApp.terminate(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open Full Disk Access") { model.openSettings(for: .bootstrap) }
                    .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }
    }
}

struct TaskPrimaryAction: View {
    let task: PermissionTask
    @ObservedObject var model: PermissionsModel
    var body: some View {
        switch task.action {
        case .settings:
            Button("Open Settings") { model.openSettings(for: .permission(task.row.id)) }
                .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
                .accessibilityLabel("Open \(task.row.permission.service.title) Settings for \(task.row.name)")
        case .openApp:
            if let subject = task.row.subject {
                Button("Open App") { model.openApp(subject) }
                    .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Open \(task.row.name) to request \(task.row.permission.service.title)")
            }
        case .chooseApp:
            Button("Choose App…") { model.chooseApp(for: task.row.appID) }
                .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
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
