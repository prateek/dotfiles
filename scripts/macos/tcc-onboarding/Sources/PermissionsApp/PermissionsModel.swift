import AppKit
import Combine
import PermissionsCore

@MainActor
final class PermissionsModel: ObservableObject {
    enum SettingsTarget: Equatable { case bootstrap, permission(String) }
    enum Presentation: String, CaseIterable {
        case permissions, apps, shelf
        var title: String { switch self { case .permissions: return "By permission"; case .apps: return "By app"; case .shelf: return "Drag shelf" } }
        var grouping: ReviewGrouping { self == .apps ? .app : .permission }
    }
    @Published var snapshot: InventorySnapshot?
    @Published var error: String?
    @Published var busy = false
    @Published var showAll = false
    @Published var selectedID: String?
    @Published var presentation: Presentation = .permissions { didSet { preferences?.set(presentation.rawValue, forKey: "presentation") } }
    @Published var largeText = false { didSet { preferences?.set(largeText, forKey: "largeText") } }
    @Published var menuBarEnabled = false { didSet { preferences?.set(menuBarEnabled, forKey: "menuBarEnabled"); onChange?() } }
    @Published var pinned = false { didSet { onChange?() } }
    @Published var showSummary = false
    @Published var evidenceOpen: Set<String> = []
    @Published private(set) var deferredIDs: Set<String> = []
    @Published private(set) var checkedAt: Date?
    private let preferences: UserDefaults?
    var onChange: (() -> Void)?
    private var manifestURL = defaultManifest
    private var manifest: Manifest?
    private var selections: [String: URL] = [:]
    private var timer: Timer?
    private var activeObserver: NSObjectProtocol?
    private var queuedRefresh = false
    private var generation = 0
    private let openSettingsURL: (URL) -> Bool

    init(openSettingsURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }, preferences: UserDefaults? = nil) {
        self.openSettingsURL = openSettingsURL
        self.preferences = preferences
        if let preferences {
            presentation = preferences.string(forKey: "presentation").flatMap(Presentation.init(rawValue:)) ?? .permissions
            largeText = preferences.bool(forKey: "largeText")
            menuBarEnabled = preferences.bool(forKey: "menuBarEnabled")
        }
    }

    static var defaultManifest: URL {
        launchManifest(home: FileManager.default.homeDirectoryForCurrentUser, preferences: .standard)
    }

    static func launchManifest(home: URL, preferences: UserDefaults) -> URL {
        let managed = home.appendingPathComponent(".config/dotfiles/tcc.json")
        if FileManager.default.fileExists(atPath: managed.path) { return managed }
        if let path = preferences.string(forKey: "lastManifestPath"), path.hasPrefix("/"),
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return managed
    }
    var needsBootstrap: Bool { snapshot?.blockedDatabases.isEmpty == false }
    var remainingCount: Int { snapshot?.rows.filter { $0.status.state.needsAttention }.count ?? 0 }
    var pendingCount: Int { snapshot?.rows.filter { $0.status.state.needsAttention && !deferredIDs.contains($0.id) }.count ?? 0 }
    var deferredCount: Int { remainingCount - pendingCount }
    var isComplete: Bool {
        guard !needsBootstrap, let snapshot else { return false }
        let targets = snapshot.rows.filter { $0.status.state != .notInstalled }
        return !targets.isEmpty && targets.allSatisfy { $0.status.state == .allowed }
    }
    var isPaused: Bool { !needsBootstrap && remainingCount > 0 && pendingCount == 0 }
    var selectedRow: InventoryRow? { snapshot?.rows.first { $0.id == selectedID } }
    private var reviewSelection: ReviewSelection {
        ReviewSelection(selectedID: selectedID, grouping: presentation.grouping, deferredIDs: deferredIDs)
    }
    var visibleRows: [InventoryRow] {
        guard let snapshot else { return [] }
        return reviewSelection.visibleRows(snapshot, showAll: showAll)
    }
    var visibleApps: [AppReviewGroup] {
        guard let snapshot else { return [] }
        return reviewSelection.appGroups(snapshot, showAll: showAll)
    }
    var visiblePermissions: [PermissionReviewGroup] {
        guard let snapshot else { return [] }
        return reviewSelection.permissionGroups(snapshot, showAll: showAll)
    }
    var hasNext: Bool {
        snapshot?.rows.contains { $0.id != selectedID && $0.status.state.needsAttention && !deferredIDs.contains($0.id) } == true
    }

    func select(_ id: String?) {
        selectedID = id
        showSummary = false
    }

    func selectAdjacent(_ offset: Int) {
        let rows = visibleRows
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selectedID } ?? 0
        select(rows[min(max(index + offset, 0), rows.count - 1)].id)
    }

    func deferPermission(_ id: String) {
        guard snapshot?.rows.contains(where: { $0.id == id && $0.status.state.needsAttention }) == true else { return }
        deferredIDs.insert(id)
        if selectedID == id { nextPermission() }
    }

    func restorePermission(_ id: String) {
        deferredIDs.remove(id)
        select(id)
    }

    func resumeDeferred() {
        deferredIDs = []
        nextPermission()
    }

    func toggleEvidence(_ id: String) {
        if evidenceOpen.contains(id) { evidenceOpen.remove(id) } else { evidenceOpen.insert(id) }
    }

    func load(_ url: URL) {
        let normalized = url.standardizedFileURL
        let preservingSession = manifest != nil && manifestURL.standardizedFileURL == normalized
        generation += 1
        manifestURL = normalized
        if !preservingSession {
            selections = [:]
            deferredIDs = []
            evidenceOpen = []
            showSummary = false
            checkedAt = nil
            selectedID = nil
            snapshot = nil
        }
        do {
            manifest = try Manifest.load(url)
            preferences?.set(normalized.path, forKey: "lastManifestPath")
            error = nil
            refresh()
        } catch {
            manifest = nil
            snapshot = nil
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
        activeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        if let observer = activeObserver { NotificationCenter.default.removeObserver(observer); activeObserver = nil }
    }

    func refresh() {
        guard let manifest else { return }
        guard !busy else { queuedRefresh = true; return }
        busy = true
        let currentGeneration = generation
        let expectations = NativeInventory.expectations(manifest, selections: selections)
        let databases = NativeInventory.databases
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
        checkedAt = Date()
        deferredIDs.formIntersection(Set(result.rows.filter { $0.status.state.needsAttention }.map(\.id)))
        var selection = reviewSelection
        selection.reconcile(result)
        selectedID = selection.selectedID
        if let row = selectedRow, let previous, previous != row.status.state {
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                userInfo: [.announcement: "\(row.name): \(row.status.state.title)", .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        onChange?()
    }

    func nextPermission() {
        guard let snapshot else { return }
        var selection = reviewSelection
        selection.advance(snapshot)
        selectedID = selection.selectedID
        showSummary = false
        onChange?()
    }

    func openSettings(for target: SettingsTarget) {
        let service: PermissionService
        switch target {
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
        onChange?()
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
