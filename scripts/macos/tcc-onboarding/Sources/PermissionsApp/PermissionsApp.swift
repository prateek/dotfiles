import AppKit
import PermissionsCore
import SwiftUI

@main
enum PermissionsApp {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--audit" {
            let result = AuditCommand.run(args, scan: NativeInventory.scan)
            FileHandle.standardOutput.write(Data(result.output.utf8))
            exit(result.status)
        }
        if args.first == "--validate" {
            guard args.count == 2 else { fail("Usage: DotfilesPermissions --validate <manifest.json>") }
            do { _ = try Manifest.load(URL(fileURLWithPath: args[1])); return }
            catch { fail(error.localizedDescription) }
        }
        if args.first == "--is-running" {
            exit(NSRunningApplication.runningApplications(withBundleIdentifier: "com.prateek.DotfilesPermissions")
                .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier } ? 0 : 1)
        }
        if let first = args.first, first.hasPrefix("--"), !["--manifest", "--reconcile"].contains(first) {
            fail("Unknown option: \(first)")
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Dotfiles Permissions: \(message)\n".utf8))
        exit(1)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = PermissionsModel(preferences: .standard)
    private var window: NSWindow?
    private var started = false
    private var launch = LaunchReview()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onChange = { [weak self] in self?.scanFinished() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateWindowLevel() }
        }
        if !started {
            let args = CommandLine.arguments
            let manifest = args.firstIndex(of: "--manifest").flatMap { index in
                args.indices.contains(index + 1) ? URL(fileURLWithPath: args[index + 1]) : nil
            } ?? PermissionsModel.defaultManifest
            requestReview(manifest, reconcile: args.contains("--reconcile"))
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard filenames.count == 1, let filename = filenames.first else {
            model.error = "Open one permission manifest at a time."
            showWindow()
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        let reconcile = !started && CommandLine.arguments.contains("--reconcile")
        requestReview(URL(fileURLWithPath: filename), reconcile: reconcile)
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.count == 1, let file = urls.first, file.isFileURL {
            requestReview(file, reconcile: !started && CommandLine.arguments.contains("--reconcile"))
            return
        }
        guard urls.count == 1, let request = ReconcileRequest(url: urls[0]) else {
            model.error = "Invalid permission review request. Open a local permission manifest instead."
            showWindow()
            return
        }
        requestReview(request.manifestURL, reconcile: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        model.refresh()
        return true
    }

    private func requestReview(_ url: URL, reconcile: Bool) {
        started = true
        model.onChange = { [weak self] in self?.scanFinished() }
        perform(launch.request(reconcile: reconcile))
        model.load(url)
    }

    private func scanFinished() {
        if !model.busy && (model.snapshot != nil || model.error != nil) {
            let visible = window?.isVisible == true && window?.isMiniaturized == false && !NSApp.isHidden
            perform(launch.scanFinished(needsAttention: model.error != nil || model.snapshot?.needsAttention == true,
                                        windowIsVisible: visible))
        }
        updateWindowLevel()
        updateStatusItem()
    }

    private func perform(_ effect: LaunchReview.Effect) {
        switch effect {
        case .none: break
        case .show: showWindow()
        case .terminate: NSApp.terminate(nil)
        }
    }

    private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            installMenus()
            let main = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            main.title = "Dotfiles Permissions"
            main.titleVisibility = .hidden
            main.titlebarAppearsTransparent = true
            let content = NSHostingView(rootView: PermissionsView(model: model))
            content.sizingOptions = []
            main.contentView = content
            main.minSize = NSSize(width: 420, height: 520)
            main.isReleasedWhenClosed = false
            main.delegate = self
            main.setFrameAutosaveName("PermissionsWorkbench")
            if !main.setFrameUsingName("PermissionsWorkbench") { main.center() }
            window = main
        }
        launch.hasPresentedWindow = true
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.startPolling()
    }

    private func updateWindowLevel() {
        window?.level = model.pinned ? .floating : .normal
    }

    func windowWillClose(_ notification: Notification) {
        model.stopPolling()
    }

    func windowDidMiniaturize(_ notification: Notification) { model.stopPolling() }
    func windowDidDeminiaturize(_ notification: Notification) { model.startPolling(); model.refresh() }

    private func updateStatusItem() {
        if !model.menuBarEnabled {
            if let item = statusItem { NSStatusBar.system.removeStatusItem(item); statusItem = nil }
            return
        }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Dotfiles Permissions")
            item.button?.image?.isTemplate = true
            let menu = NSMenu()
            let open = NSMenuItem(title: "Open Dotfiles Permissions", action: #selector(showInventory), keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit Dotfiles Permissions", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
            item.menu = menu
            statusItem = item
        }
        statusItem?.button?.toolTip = model.needsBootstrap ? "Permission checks are unavailable" : "Review app permission records"
    }

    private func installMenus() {
        let bar = NSMenu()
        func addMenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu
            bar.addItem(item)
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target
            menu.addItem(item)
        }
        let app = addMenu("Dotfiles Permissions")
        add(app, "About Dotfiles Permissions", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        let services = NSMenu()
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        app.addItem(servicesItem)
        NSApp.servicesMenu = services
        app.addItem(.separator())
        add(app, "Hide Dotfiles Permissions", #selector(NSApplication.hide(_:)), "h")
        add(app, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h")
        app.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(app, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
        app.addItem(.separator())
        add(app, "Quit Dotfiles Permissions", #selector(NSApplication.terminate(_:)), "q")
        let edit = addMenu("Edit")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        let view = addMenu("View")
        add(view, "Refresh Permissions", #selector(refresh), "r", target: self)
        add(view, "Show All Permissions", #selector(toggleAll), "a", target: self)
        view.items.last?.keyEquivalentModifierMask = [.command, .shift]
        add(view, "Next Permission", #selector(nextPermission), "]", target: self)
        add(view, "Open Permission Inventory", #selector(showInventory), "0", target: self)
        add(view, "By Permission", #selector(permissionPresentation), "1", target: self)
        add(view, "By App", #selector(appPresentation), "2", target: self)
        add(view, "Drag Shelf", #selector(shelfPresentation), "3", target: self)
        add(view, "Larger Text", #selector(toggleLargeText), "+", target: self)
        add(view, "Show Menu Bar Icon", #selector(toggleMenuBar), target: self)
        add(view, "Keep Window Above Others", #selector(togglePin), target: self)
        let windows = addMenu("Window")
        add(windows, "Close", #selector(NSWindow.performClose(_:)), "w")
        add(windows, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, "Zoom", #selector(NSWindow.performZoom(_:)))
        add(windows, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        NSApp.windowsMenu = windows
        let help = addMenu("Help")
        add(help, "Permission Onboarding Help", #selector(showHelp), target: self)
        NSApp.helpMenu = help
        NSApp.mainMenu = bar
    }

    @objc private func refresh() { model.refresh() }
    @objc private func toggleAll() { model.showAll.toggle(); model.showSummary = false }
    @objc private func permissionPresentation() { model.presentation = .permissions }
    @objc private func appPresentation() { model.presentation = .apps }
    @objc private func shelfPresentation() { model.presentation = .shelf }
    @objc private func toggleLargeText() { model.largeText.toggle() }
    @objc private func toggleMenuBar() { model.menuBarEnabled.toggle() }
    @objc private func togglePin() { model.pinned.toggle() }
    @objc private func nextPermission() { model.nextPermission() }
    @objc private func showInventory() { showWindow() }
    @objc private func showHelp() { model.showHelp() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(refresh) { return !model.busy }
        if menuItem.action == #selector(toggleAll) {
            menuItem.state = model.showAll ? .on : .off
            return !model.needsBootstrap && model.snapshot != nil
        }
        if menuItem.action == #selector(nextPermission) { return !model.needsBootstrap && model.hasNext }
        if menuItem.action == #selector(toggleLargeText) { menuItem.state = model.largeText ? .on : .off }
        if menuItem.action == #selector(toggleMenuBar) { menuItem.state = model.menuBarEnabled ? .on : .off }
        if menuItem.action == #selector(togglePin) { menuItem.state = model.pinned ? .on : .off }
        return true
    }
}
