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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = PermissionsModel()
    private var window: NSPanel?
    private var guidance: NSPanel?
    private var started = false
    private var visible = false
    private var launchReconcile = CommandLine.arguments.contains("--reconcile")

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onChange = { [weak self] in self?.scanFinished() }
        model.onOpenSettings = { [weak self] service, url in self?.showGuidance(service, url: url) }
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
        else if !visible { NSApp.terminate(nil) }
    }

    private func showWindow() {
        if window == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 650, height: 650),
                                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = "Dotfiles Permissions"
            panel.contentView = NSHostingView(rootView: PermissionsView(model: model))
            panel.minSize = NSSize(width: 520, height: 420)
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.delegate = self
            panel.center()
            window = panel
        }
        visible = true
        guidance?.orderOut(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.startPolling()
    }

    private func showGuidance(_ service: PermissionService, url: URL?) {
        let panel = guidance ?? NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
                                        styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = service.title
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: GrantGuidanceView(model: model, service: service, url: url) { [weak self] in
            self?.showWindow()
        })
        if let screen = window?.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 16, y: frame.minY + 16))
        }
        guidance = panel
        window?.orderOut(nil)
        panel.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
}
