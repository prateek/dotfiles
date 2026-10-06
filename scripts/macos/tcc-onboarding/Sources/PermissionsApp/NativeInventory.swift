import AppKit
import PermissionsCore

enum NativeInventory {
    static func expectations(_ manifest: Manifest, selections: [String: URL] = [:]) -> [Expectation] {
        manifest.apps.sorted { $0.key < $1.key }.map { id, app in
            Expectation(id: id, app: app, resolution: SubjectResolver.resolve(app,
                candidates: NSWorkspace.shared.urlsForApplications(withBundleIdentifier: app.bundleID), selected: selections[id]))
        }
    }

    static var databases: [URL] {
        [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
         URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")]
    }

    static func scan(_ manifest: Manifest) -> InventorySnapshot {
        Inventory.scan(expectations(manifest), databases: databases)
    }
}
