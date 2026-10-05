import AppKit
import Combine
import PermissionsCore

@MainActor
final class PermissionsModel: ObservableObject {
    enum CompanionTask: Equatable { case bootstrap, permission(String) }
    @Published var snapshot: InventorySnapshot?
    @Published var error: String?
    @Published var busy = false
    @Published var showAll = false
    @Published var selectedID: String?
    @Published var companionTask: CompanionTask?
    var onChange: (() -> Void)?
    var onOpenCompanion: (() -> Void)?
    var onFinishCompanion: (() -> Void)?
    private var manifestURL = defaultManifest
    private var manifest: Manifest?
    private var selections: [String: URL] = [:]
    private var timer: Timer?
    private var queuedRefresh = false
    private var generation = 0
    private let openSettingsURL: (URL) -> Bool

    init(openSettingsURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.openSettingsURL = openSettingsURL
    }

    static var defaultManifest: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/dotfiles/tcc.json")
    }
    var needsBootstrap: Bool { snapshot?.blockedDatabases.isEmpty == false }
    var remainingCount: Int { snapshot?.rows.filter { $0.status.state.needsAttention }.count ?? 0 }
    var selectedRow: InventoryRow? { snapshot?.rows.first { $0.id == selectedID } }
    var visibleRows: [InventoryRow] {
        guard let snapshot else { return [] }
        return ReviewSelection(selectedID: selectedID).visibleRows(snapshot, showAll: showAll)
    }
    var hasNext: Bool { snapshot?.rows.contains { $0.id != selectedID && $0.status.state.needsAttention } == true }

    func load(_ url: URL) {
        generation += 1
        manifestURL = url
        selections = [:]
        selectedID = nil
        companionTask = nil
        snapshot = nil
        do {
            manifest = try Manifest.load(url)
            error = nil
            refresh()
        } catch {
            manifest = nil
            self.error = "Cannot read \(url.path): \(error.localizedDescription)"
            onChange?()
        }
    }

    func retryLoad() { load(manifestURL) }

    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard let manifest else { return }
        guard !busy else { queuedRefresh = true; return }
        busy = true
        let currentGeneration = generation
        let expectations = manifest.apps.sorted { $0.key < $1.key }.map { id, app in
            Expectation(id: id, app: app, resolution: SubjectResolver.resolve(app,
                candidates: NSWorkspace.shared.urlsForApplications(withBundleIdentifier: app.bundleID), selected: selections[id]))
        }
        let databases = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
        ]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Inventory.scan(expectations, databases: databases)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                if self.generation == currentGeneration {
                    self.updateInventory(result)
                }
                if self.queuedRefresh {
                    self.queuedRefresh = false
                    self.refresh()
                }
            }
        }
    }

    func updateInventory(_ result: InventorySnapshot) {
        let previous = selectedRow?.status.state
        snapshot = result
        var selection = ReviewSelection(selectedID: selectedID)
        selection.reconcile(result)
        selectedID = selection.selectedID
        if needsBootstrap, companionTask != nil { companionTask = .bootstrap }
        if let row = selectedRow, let previous, previous != row.status.state {
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                userInfo: [.announcement: "\(row.name): \(row.status.state.title)", .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        onChange?()
    }

    func nextPermission(from id: String? = nil) {
        guard let snapshot else { return }
        if let id { selectedID = id }
        var selection = ReviewSelection(selectedID: selectedID)
        selection.advance(snapshot)
        selectedID = selection.selectedID
        if let selectedID, companionTask != nil { companionTask = .permission(selectedID) }
        else { companionTask = nil; onFinishCompanion?() }
        onChange?()
    }

    func continueAfterBootstrap() {
        guard let snapshot else { return }
        var selection = ReviewSelection()
        selection.reconcile(snapshot)
        selectedID = selection.selectedID
        if let selectedID { companionTask = .permission(selectedID) }
        else { companionTask = nil; onFinishCompanion?() }
    }

    func openSettings(for task: CompanionTask) {
        let service: PermissionService
        switch task {
        case .bootstrap: service = .fullDiskAccess
        case .permission(let id):
            guard let row = snapshot?.rows.first(where: { $0.id == id }) else { return }
            service = row.permission.service
            selectedID = id
        }
        error = nil
        if !openSettingsURL(service.settingsURL) {
            error = "Couldn’t open System Settings. Open Privacy & Security → \(service.title) manually, or try again."
        }
        companionTask = task
        onOpenCompanion?()
    }

    func chooseApp(for id: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose the installed app"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        func accept(_ response: NSApplication.ModalResponse) {
            guard response == .OK, let url = panel.url else { return }
            selections[id] = url
            refresh()
        }
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: accept) }
        else { accept(panel.runModal()) }
    }

    func openApp(_ subject: PermissionSubject) {
        error = nil
        NSWorkspace.shared.openApplication(at: subject.bundleURL, configuration: .init()) { [weak self] _, error in
            if let error { Task { @MainActor in self?.error = "Cannot open the app: \(error.localizedDescription)" } }
        }
    }

    func relaunch() {
        error = nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--manifest", manifestURL.path]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.error = "Cannot relaunch the helper: \(error.localizedDescription)" }
                else { NSApp.terminate(nil) }
            }
        }
    }

    func showHelp() {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "html"), NSWorkspace.shared.open(url) else {
            error = "Permission help is unavailable. Review the dotfiles TCC onboarding runbook."
            return
        }
    }
}
