import Foundation

public struct AuditReport {
    public let snapshot: InventorySnapshot
    public init(_ snapshot: InventorySnapshot) { self.snapshot = snapshot }

    public var exitStatus: Int32 {
        if snapshot.rows.contains(where: { $0.status.state == .unknown }) || !snapshot.blockedDatabases.isEmpty { return 3 }
        return snapshot.needsAttention ? 2 : 0
    }

    public var output: String {
        guard exitStatus != 0 else { return "" }
        var lines = ["[dotfiles] Permission audit (CLI context; recorded state):"]
        for path in snapshot.blockedDatabases {
            lines.append("  Cannot read \(path). Full Disk Access may be needed; the GUI must check its own access.")
        }
        for row in snapshot.rows where row.status.state.needsAttention {
            lines.append("  \(row.name) / \(row.permission.service.title): \(row.status.state.rawValue) — \(row.status.detail)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

public enum AuditCommand {
    public static func run(_ arguments: [String], scan: (Manifest) -> InventorySnapshot) -> (status: Int32, output: String) {
        guard arguments.count == 2, arguments.first == "--audit" else {
            return (64, "Usage: DotfilesPermissions --audit <manifest.json>\n")
        }
        do {
            let report = AuditReport(scan(try Manifest.load(URL(fileURLWithPath: arguments[1]))))
            return (report.exitStatus, report.output)
        } catch {
            return (64, "Dotfiles Permissions: Cannot audit manifest: \(error.localizedDescription)\n")
        }
    }
}
