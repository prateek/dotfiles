import AppKit
import PermissionsCore
import SwiftUI

struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel
    var body: some View {
        VStack(spacing: 0) {
            PermissionHeader(model: model)
            Divider()
            if model.needsBootstrap {
                BootstrapView(model: model)
            } else if let snapshot = model.snapshot {
                if !snapshot.needsAttention && !model.showAll && (model.showSummary || model.selectedID == nil) {
                    PermissionSummary(snapshot: snapshot)
                } else {
                    PermissionQueue(model: model)
                }
            } else {
                VStack(spacing: 12) {
                    if model.error != nil {
                        Label("Couldn’t load permissions", systemImage: "exclamationmark.triangle")
                        Button("Try again") { model.retryLoad() }
                    } else {
                        ProgressView()
                        Text("Checking app permissions…").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.primary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).padding(16)
                    .accessibilityLabel(error)
            }
        }
        .environment(\.permissionTheme, PermissionTheme(scale: model.largeText ? 1.22 : 1))
        .font(.system(size: model.largeText ? 15.86 : 13))
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct PermissionHeader: View {
    @ObservedObject var model: PermissionsModel
    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 8)
            Menu {
                Button(model.busy ? "Checking permissions…" : "Recheck permissions") { model.refresh() }
                    .disabled(model.busy)
                Divider()
                Menu("View") {
                    Picker("Group permissions", selection: $model.presentation) {
                        ForEach(PermissionsModel.Presentation.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Toggle("Show all permissions", isOn: $model.showAll)
                        .onChange(of: model.showAll) { _, _ in model.showSummary = false }
                    Toggle("Larger text", isOn: $model.largeText)
                    Toggle("Show menu bar icon", isOn: $model.menuBarEnabled)
                }
                Toggle("Keep above Settings", isOn: $model.pinned)
                Divider()
                Button("Help") { model.showHelp() }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("More options")
                .help("Recheck, view options, pinning, and help")
        }.padding(.leading, 80).padding(.trailing, 16).padding(.vertical, 12)
    }
}

private struct PermissionQueue: View {
    @ObservedObject var model: PermissionsModel
    @Environment(\.permissionTheme) private var theme
    @FocusState private var queueFocused: Bool
    @AccessibilityFocusState private var accessibleTask: String?
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if model.isPaused {
                        HStack {
                            Text("Review paused").font(theme.label)
                            Spacer()
                            Button("Resume deferred") { model.resumeDeferred() }.controlSize(.small)
                        }.padding(.vertical, 12)
                    }
                    if model.presentation == .apps {
                        ForEach(model.visibleApps) { app in
                            HStack {
                                AppIcon(url: app.rows.first?.subject?.bundleURL, size: 20)
                                Text(app.name).font(theme.label)
                                Spacer()
                            }.padding(.top, 12).accessibilityAddTraits(.isHeader)
                            ForEach(app.rows) { row in task(row) }
                        }
                    } else {
                        ForEach(model.visiblePermissions) { group in
                            HStack {
                                Text(group.service.title).font(theme.label)
                                Spacer()
                                Text("\(group.rows.filter { $0.status.state.needsAttention }.count) to review")
                                    .font(theme.caption).foregroundStyle(.secondary)
                            }.padding(.top, 12).padding(.bottom, 3).accessibilityAddTraits(.isHeader)
                            if model.presentation == .shelf && group.service.supportsDrag {
                                PermissionShelf(rows: group.rows.filter { $0.status.state.needsAttention && !model.deferredIDs.contains($0.id) })
                            }
                            ForEach(group.rows) { row in task(row) }
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { accessibleTask = id; proxy.scrollTo(id, anchor: nil) }
            }
        }
        .focusable().focused($queueFocused)
        .onKeyPress(.upArrow) {
            guard queueFocused else { return .ignored }
            model.selectAdjacent(-1); return .handled
        }
        .onKeyPress(.downArrow) {
            guard queueFocused else { return .ignored }
            model.selectAdjacent(1); return .handled
        }
        .accessibilityLabel("Permission queue")
    }
    private func task(_ row: InventoryRow) -> some View {
        PermissionRow(row: row, model: model).id(row.id)
            .accessibilityFocused($accessibleTask, equals: row.id)
    }
}

struct PermissionShelf: View {
    let rows: [InventoryRow]
    @Environment(\.permissionTheme) private var theme
    private var targets: [InventoryRow] { rows.filter { PermissionTask($0).offersFileHandoff } }
    var body: some View {
        if !targets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Apps for this pane").font(theme.label)
                ForEach(targets) { row in
                    if let subject = row.subject {
                        HStack(spacing: 8) {
                            FileTile(url: subject.codeURL, service: row.permission.service, draggable: true)
                            SubjectActions(url: subject.codeURL)
                        }
                        if row.status.state == .stale {
                            Text("\(row.name): remove the old entry before adding this copy.")
                                .font(theme.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(12).background { PermissionPaper().clipShape(RoundedRectangle(cornerRadius: 10)) }
        }
    }
}

private struct BootstrapView: View {
    @ObservedObject var model: PermissionsModel
    @Environment(\.permissionTheme) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    AppIcon(url: Bundle.main.bundleURL, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dotfiles Permissions").font(theme.title)
                        Text("Full Disk Access · for this helper").font(theme.caption).foregroundStyle(.secondary)
                    }
                }
                Text("The helper cannot read permission records yet. Full Disk Access lets it check recorded grants; it never changes them.")
                    .font(theme.body).fixedSize(horizontal: false, vertical: true)
                FileTile(url: Bundle.main.bundleURL, service: .fullDiskAccess, draggable: true)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Button("Open Settings…") { model.openSettings(for: .bootstrap) }.buttonStyle(.bordered).keyboardShortcut(.defaultAction)
                        Spacer()
                        SubjectActions(url: Bundle.main.bundleURL)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Open Settings…") { model.openSettings(for: .bootstrap) }.buttonStyle(.bordered)
                        SubjectActions(url: Bundle.main.bundleURL)
                    }
                }
                Text("Privacy & Security → Full Disk Access. Add this exact helper, enable it, then relaunch if macOS asks.")
                    .font(theme.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Relaunch helper") { model.relaunch() }.controlSize(.small)
                DisclosureGroup("Why checks are unavailable") {
                    ForEach(model.snapshot?.blockedDatabases ?? [], id: \.self) { Text($0).textSelection(.enabled) }
                }.font(theme.caption)
            }.padding(16).background { PermissionPaper().clipShape(RoundedRectangle(cornerRadius: 12)) }
                .padding(16)
        }
    }
}

private struct PermissionSummary: View {
    let snapshot: InventorySnapshot
    @Environment(\.permissionTheme) private var theme
    private var installed: [InventoryRow] { snapshot.rows.filter { $0.status.state != .notInstalled } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(installed.isEmpty ? "No installed apps to review" : "Matching records").font(theme.title)
                Text(installed.isEmpty ? "Missing apps are listed in All permissions. Installation stays with your package setup."
                     : "Expected permissions for installed apps have matching allow records. An app may need to relaunch before using its access; records do not prove its live behavior.")
                    .font(theme.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(ReviewSelection().appGroups(snapshot, showAll: true)) { group in
                    HStack {
                        AppIcon(url: group.rows.first?.subject?.bundleURL, size: 24)
                        Text(group.name)
                        Spacer()
                        Text(group.rows.allSatisfy { $0.status.state == .notInstalled } ? "Not installed" : "\(group.rows.filter { $0.status.state == .allowed }.count) recorded")
                            .font(theme.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
