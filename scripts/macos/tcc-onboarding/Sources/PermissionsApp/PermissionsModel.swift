import AppKit
import Combine
import PermissionsCore

@MainActor
final class PermissionsModel: ObservableObject {
    @Published var snapshot: InventorySnapshot?
    @Published var error: String?
    @Published var busy = false
    @Published var showAll = false
    var onChange: (() -> Void)?
    var onOpenSettings: ((PermissionService, URL?) -> Void)?
    private var manifestURL = defaultManifest
    private var manifest: Manifest?
    private var selections: [String: URL] = [:]
    private var timer: Timer?
    private var queuedRefresh = false
    private var generation = 0

    static var defaultManifest: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/dotfiles/tcc.json")
    }

    func load(_ url: URL) {
        generation += 1
        manifestURL = url
        selections = [:]
        do {
            manifest = try Manifest.load(url)
            error = nil
            refresh()
        } catch {
            manifest = nil
            snapshot = nil
            self.error = "Cannot read \(url.path): \(error.localizedDescription)"
            onChange?()
        }
    }

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
                    self.snapshot = result
                    self.onChange?()
                }
                if self.queuedRefresh {
                    self.queuedRefresh = false
                    self.refresh()
                }
            }
        }
    }

    func openSettings(_ service: PermissionService, subjectURL: URL? = nil) {
        onOpenSettings?(service, subjectURL)
        if !NSWorkspace.shared.open(service.settingsURL) {
            error = "Could not open System Settings. Open Privacy & Security → \(service.title) manually."
        }
    }

    func chooseApp(for id: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose the installed app"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selections[id] = url
        refresh()
    }

    func openApp(_ subject: PermissionSubject) {
        NSWorkspace.shared.openApplication(at: subject.bundleURL, configuration: .init()) { [weak self] _, error in
            if let error {
                Task { @MainActor in self?.error = "Cannot open the app: \(error.localizedDescription)" }
            }
        }
    }

    func relaunch() {
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
}
