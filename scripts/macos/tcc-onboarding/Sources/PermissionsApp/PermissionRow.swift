import AppKit
import PermissionsCore
import SwiftUI

struct PermissionRow: View {
    let row: InventoryRow
    @ObservedObject var model: PermissionsModel
    @Environment(\.permissionTheme) private var theme
    private var selected: Bool { row.id == model.selectedID }
    private var deferred: Bool { model.deferredIDs.contains(row.id) }
    var body: some View {
        if selected {
            ExpandedPermission(row: row, model: model).padding(.vertical, 4)
        } else {
            Button {
                if deferred { model.restorePermission(row.id) } else { model.select(row.id) }
            } label: {
                HStack(spacing: 10) {
                    AppIcon(url: row.subject?.bundleURL, size: 26)
                    Text(model.presentation == .apps ? row.permission.service.title : row.name).font(theme.body)
                    if deferred { Text("Deferred").font(theme.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 8)
                    StatusLabel(state: row.status.state)
                }.padding(.horizontal, 10).padding(.vertical, 8).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(row.name), \(row.permission.service.title), \(row.status.state.title)\(deferred ? ", deferred; select to resume" : "")")
        }
    }
}

private struct ExpandedPermission: View {
    let row: InventoryRow
    @ObservedObject var model: PermissionsModel
    @Environment(\.permissionTheme) private var theme
    private var task: PermissionTask { PermissionTask(row) }
    private var hasFile: Bool { task.offersFileHandoff }
    private var evidenceShown: Bool { model.evidenceOpen.contains(row.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { identity; Spacer(minLength: 8); StatusLabel(state: row.status.state) }
                VStack(alignment: .leading, spacing: 8) { identity; StatusLabel(state: row.status.state) }
            }
            Text(row.permission.reason).font(theme.body).fixedSize(horizontal: false, vertical: true)
            Text(task.summary).font(theme.label).fixedSize(horizontal: false, vertical: true)
            if !task.steps.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(task.steps, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                }.font(theme.caption).foregroundStyle(.secondary)
            }
            if hasFile, model.presentation != .shelf, let subject = row.subject {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        FileTile(url: subject.codeURL, service: row.permission.service, draggable: true).frame(minWidth: 220 * theme.scale, maxWidth: 260 * theme.scale)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                        destination
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FileTile(url: subject.codeURL, service: row.permission.service, draggable: true)
                        destination
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { primaryAction; secondaryActions }
                VStack(alignment: .leading, spacing: 8) { primaryAction; secondaryActions }
            }
            if evidenceShown { evidence }
            if model.isComplete && !model.showSummary {
                HStack {
                    Spacer()
                    Button("Summary") { model.showSummary = true }.controlSize(.small)
                }
            } else if model.hasNext {
                HStack {
                    Spacer()
                    Button("Next permission") { model.nextPermission() }.controlSize(.small)
                }
            }
        }
        .padding(16)
        .background { PermissionPaper().clipShape(RoundedRectangle(cornerRadius: 12)) }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.60, green: 0.28, blue: 0.16)).frame(width: 3)
                .padding(.vertical, 18).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
    private var identity: some View {
        HStack(spacing: 12) {
            AppIcon(url: row.subject?.bundleURL, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(theme.title).fixedSize(horizontal: false, vertical: true)
                Text(row.permission.service.title).font(theme.body).foregroundStyle(.secondary)
            }
        }
    }
    private var destination: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("System Settings").font(theme.caption).foregroundStyle(.secondary)
            Text(row.permission.service.title).font(theme.label)
        }.padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Destination: System Settings, \(row.permission.service.title)")
    }
    @ViewBuilder private var primaryAction: some View {
        switch task.action {
        case .settings:
            Button("Open Settings…") { model.openSettings(for: .permission(row.id)) }
                .buttonStyle(.bordered).controlSize(.small).keyboardShortcut(.defaultAction)
                .accessibilityLabel("Open \(row.permission.service.title) Settings for \(row.name)")
        case .openApp:
            if let subject = row.subject {
                Button("Open app") { model.openApp(subject) }
                    .buttonStyle(.bordered).controlSize(.small).keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Open \(row.name) to request \(row.permission.service.title)")
            }
        case .chooseApp:
            Button("Choose exact app…") { model.chooseApp(for: row.appID) }.controlSize(.small).keyboardShortcut(.defaultAction)
        case .none: EmptyView()
        }
    }
    private var secondaryActions: some View {
        HStack(spacing: 8) {
            if row.status.state.needsAttention {
                Button("Later") { model.deferPermission(row.id) }.controlSize(.small)
            }
            if row.permission.service.requiresAppRequest, let subject = row.subject {
                if task.action == .openApp {
                    Button("Settings…") { model.openSettings(for: .permission(row.id)) }.controlSize(.small)
                } else if row.status.state.needsAttention {
                    Button("Open app") { model.openApp(subject) }.controlSize(.small)
                }
            }
            Spacer(minLength: 0)
            if hasFile && model.presentation != .shelf, let subject = row.subject { SubjectActions(url: subject.codeURL) }
            Button(evidenceShown ? "Hide evidence" : "Evidence") { model.toggleEvidence(row.id) }
                .buttonStyle(.borderless).font(theme.caption)
                .accessibilityLabel("\(evidenceShown ? "Hide" : "Show") evidence for \(row.name) \(row.permission.service.title)")
        }
    }
    private var evidence: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("\(row.status.state.title) · \(row.status.detail)")
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if let subject = row.subject {
                Text("Exact target: \(subject.codeURL.path)").textSelection(.enabled)
                Text("Client: \(subject.client) · type \(subject.clientType)").textSelection(.enabled)
            }
            Text("Service: \(row.permission.service.tccName)").textSelection(.enabled)
            if let date = model.checkedAt {
                Text("Checked \(date.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            Text("A matching allow record is evidence, not a live test of the app’s feature.")
                .foregroundStyle(.secondary)
        }.font(theme.caption)
    }
}
