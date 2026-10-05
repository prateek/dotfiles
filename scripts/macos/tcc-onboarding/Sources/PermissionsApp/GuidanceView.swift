import AppKit
import PermissionsCore
import SwiftUI

struct GrantGuidanceView: View {
    @ObservedObject var model: PermissionsModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.error { ActionError(message: error).padding([.top, .horizontal], 16) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch model.companionTask {
                    case .bootstrap: bootstrap
                    case .permission(let id):
                        if let row = model.snapshot?.rows.first(where: { $0.id == id }) {
                            permission(row)
                        } else { Text("This permission is no longer in the inventory.").foregroundStyle(.secondary) }
                    case nil: Text("Return to the inventory to choose a permission.").foregroundStyle(.secondary)
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("All Permissions", action: onBack)
                Spacer()
                primaryAction.fixedSize(horizontal: true, vertical: false)
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Check permissions again").disabled(model.busy)
            }.padding(14)
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private var bootstrap: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.needsBootstrap {
                Text("Allow permission checks").font(.headline)
                Text("Give Dotfiles Permissions Full Disk Access so it can read permission records.")
                    .foregroundStyle(.secondary)
                TaskSteps(steps: ["Add this helper to Full Disk Access and enable it.",
                                  "Relaunch the helper if access is still unavailable."])
                FileTile(url: Bundle.main.bundleURL, service: .fullDiskAccess, draggable: true)
                SubjectActions(url: Bundle.main.bundleURL)
                Button("Open Full Disk Access") { model.openSettings(for: .bootstrap) }
            } else {
                Label("Permission checks enabled", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.primary)
                Text("The permission records are readable. You can now review your apps.").foregroundStyle(.secondary)
            }
        }
    }

    private func permission(_ row: InventoryRow) -> some View {
        let task = PermissionTask(row)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppIcon(url: row.subject?.bundleURL, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name).font(.headline)
                    Text(row.permission.service.title).font(.caption).foregroundStyle(.secondary)
                }
            }
            StatusLabel(state: row.status.state)
            Text(task.summary).font(.callout).foregroundStyle(.secondary)
            TaskSteps(steps: task.steps)
            if row.status.state.needsAttention, let subject = row.subject {
                FileTile(url: subject.codeURL, service: row.permission.service, draggable: row.permission.service.supportsDrag)
                SubjectActions(url: subject.codeURL)
                if task.action == .openApp {
                    Button("Open \(row.permission.service.title) Settings") { model.openSettings(for: .permission(row.id)) }
                } else {
                    Button("Open App") { model.openApp(subject) }
                }
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch model.companionTask {
        case .bootstrap:
            if model.needsBootstrap {
                Button("Relaunch Helper") { model.relaunch() }
                    .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            } else {
                Button(model.remainingCount > 0 ? "Review Apps" : "Done") { model.continueAfterBootstrap() }
                    .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            }
        case .permission(let id):
            if let row = model.snapshot?.rows.first(where: { $0.id == id }), row.status.state.needsAttention {
                TaskPrimaryAction(task: PermissionTask(row), model: model, compact: true)
            } else if let row = model.snapshot?.rows.first(where: { $0.id == id }) {
                let hasNext = model.snapshot?.rows.contains { $0.id != row.id && $0.status.state.needsAttention } == true
                Button(hasNext ? "Next Permission" : "Done") {
                    if hasNext { model.nextPermission(from: row.id) }
                    else { model.selectedID = nil; onBack() }
                }.buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            }
        case nil: EmptyView()
        }
    }
}
