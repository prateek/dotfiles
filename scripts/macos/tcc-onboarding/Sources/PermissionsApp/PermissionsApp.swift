import AppKit
import PermissionsCore
import SwiftUI

@main
enum PermissionsApp {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--validate" {
            guard args.count == 2 else { fail("Usage: DotfilesPermissions --validate <manifest.json>") }
            do { _ = try Manifest.load(URL(fileURLWithPath: args[1])); return }
            catch { fail(error.localizedDescription) }
        }
        if args.first == "--is-running" {
            exit(NSRunningApplication.runningApplications(withBundleIdentifier: "com.prateek.DotfilesPermissions")
                .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier } ? 0 : 1)
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation {
    let model = PermissionsModel()
    private var window: NSWindow?
    private var guidance: NSPanel?
    private var started = false
    private var visible = false
    private var companionPresented = false
    private var launchReconcile = CommandLine.arguments.contains("--reconcile")
    private let filter = NSSegmentedControl(labels: ["Needs Attention", "All"], trackingMode: .selectOne, target: nil, action: nil)
    private let filterID = NSToolbarItem.Identifier("inventoryFilter")
    private let refreshID = NSToolbarItem.Identifier("refresh")

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onChange = { [weak self] in self?.scanFinished() }
        model.onOpenCompanion = { [weak self] in self?.showGuidance() }
        model.onFinishCompanion = { [weak self] in self?.showWindow() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateCompanionVisibility() }
        }
        if !started {
            let args = CommandLine.arguments
            let manifest = args.firstIndex(of: "--manifest").flatMap { index in
                args.indices.contains(index + 1) ? URL(fileURLWithPath: args[index + 1]) : nil
            } ?? PermissionsModel.defaultManifest
            request(manifest, reconcile: args.contains("--reconcile"))
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard filenames.count == 1, let filename = filenames.first else {
            model.error = "Open one permission manifest at a time."
            showWindow()
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        let reconcile = launchReconcile
        launchReconcile = false
        request(URL(fileURLWithPath: filename), reconcile: reconcile)
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        model.refresh()
        return true
    }

    private func request(_ url: URL, reconcile: Bool) {
        started = true
        model.onChange = { [weak self] in self?.scanFinished() }
        if !reconcile { showWindow() }
        model.load(url)
    }

    private func scanFinished() {
        if !visible && (model.error != nil || model.snapshot?.needsAttention == true) { showWindow() }
        else if !visible { NSApp.terminate(nil); return }
        window?.subtitle = model.snapshot == nil ? "Couldn’t load inventory" : model.needsBootstrap ? "Allow permission checks"
            : model.remainingCount == 0 ? "Review complete" : "\(model.remainingCount) permissions remaining"
        filter.isEnabled = !model.needsBootstrap && model.snapshot != nil
        filter.selectedSegment = model.showAll ? 1 : 0
        switch model.companionTask {
        case .bootstrap: guidance?.title = PermissionService.fullDiskAccess.title
        case .permission(let id):
            if let row = model.snapshot?.rows.first(where: { $0.id == id }) { guidance?.title = row.permission.service.title }
        case nil: break
        }
    }

    private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            installMenus()
            let main = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            main.title = "App Permissions"
            let content = NSHostingView(rootView: PermissionsView(model: model))
            content.sizingOptions = []
            main.contentView = content
            main.minSize = NSSize(width: 680, height: 480)
            main.isReleasedWhenClosed = false
            main.delegate = self
            main.setFrameAutosaveName("PermissionWorkbench")
            if !main.setFrameUsingName("PermissionWorkbench") { main.center() }
            let toolbar = NSToolbar(identifier: "PermissionToolbar")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            main.toolbar = toolbar
            main.toolbarStyle = .unified
            window = main
        }
        visible = true
        dismissCompanion()
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.startPolling()
    }

    private func showGuidance() {
        if guidance == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
                                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.minSize = NSSize(width: 360, height: 320)
            let content = NSHostingView(rootView: GrantGuidanceView(model: model) { [weak self] in self?.showWindow() })
            content.sizingOptions = []
            panel.contentView = content
            panel.setFrameAutosaveName("PermissionCompanion")
            if !panel.setFrameUsingName("PermissionCompanion"), let screen = window?.screen ?? NSScreen.main {
                let frame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 16, y: frame.minY + 16))
            }
            guidance = panel
        }
        if case .permission(let id) = model.companionTask,
           let row = model.snapshot?.rows.first(where: { $0.id == id }) { guidance?.title = row.permission.service.title }
        else { guidance?.title = "Full Disk Access" }
        companionPresented = true
        updateCompanionVisibility()
    }

    private func updateCompanionVisibility() {
        guard companionPresented else { return }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == "com.apple.systempreferences" || front?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            guidance?.level = .floating
            guidance?.orderFrontRegardless()
        } else {
            guidance?.level = .normal
            guidance?.orderOut(nil)
        }
    }

    private func dismissCompanion() {
        companionPresented = false
        guidance?.orderOut(nil)
        model.companionTask = nil
    }

    func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow, closing === guidance { dismissCompanion() }
        else { NSApp.terminate(nil) }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [filterID, .flexibleSpace, refreshID] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [filterID, .flexibleSpace, refreshID] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if id == filterID {
            filter.selectedSegment = 0
            filter.target = self
            filter.action = #selector(changeFilter)
            item.label = "Inventory"
            item.view = filter
        } else if id == refreshID {
            item.label = "Refresh"
            item.toolTip = "Check permissions again (⌘R)"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh permissions")
            item.target = self
            item.action = #selector(refresh)
        } else { return nil }
        return item
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
        add(view, "Show Permission Inventory", #selector(showInventory), "1", target: self)
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
    @objc private func changeFilter() { model.showAll = filter.selectedSegment == 1 }
    @objc private func toggleAll() { model.showAll.toggle(); filter.selectedSegment = model.showAll ? 1 : 0 }
    @objc private func nextPermission() { model.nextPermission() }
    @objc private func showInventory() { showWindow() }
    @objc private func showHelp() { model.showHelp() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(refresh) { return !model.busy }
        if menuItem.action == #selector(toggleAll) {
            menuItem.state = model.showAll ? .on : .off
            return !model.needsBootstrap && model.snapshot != nil
        }
        if menuItem.action == #selector(nextPermission) { return !model.needsBootstrap && model.remainingCount > 0 }
        return true
    }
}
