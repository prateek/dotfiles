import Foundation

public struct PermissionTask: Sendable {
    public enum Action: Sendable { case settings, openApp, chooseApp, none }
    public let row: InventoryRow
    public init(_ row: InventoryRow) { self.row = row }

    public var action: Action {
        guard row.status.state.needsAttention else { return .none }
        guard row.subject != nil else { return .chooseApp }
        return row.permission.service.requiresAppRequest && row.status.state != .denied ? .openApp : .settings
    }

    public var summary: String {
        switch row.status.state {
        case .allowed: return "The recorded permission matches this installed app."
        case .stale: return "The saved permission does not match this installed copy."
        case .denied: return "macOS records this permission as off."
        case .unknown:
            return row.subject == nil ? "Choose the installed copy you use before reviewing its access."
                : "We couldn’t confirm this permission. Review the app’s entry in System Settings."
        case .notInstalled: return "This app or its declared helper is not installed. No action is needed."
        }
    }

    public var steps: [String] {
        let service = row.permission.service
        if row.status.state == .allowed { return ["Quit and reopen \(row.name) if it hasn’t adopted the change."] }
        guard row.status.state.needsAttention, row.subject != nil else { return [] }
        if row.status.state == .stale {
            if service.supportsDrag {
                return ["Remove the old entry from \(service.title).",
                        "Drag this exact copy into the list, then enable it.",
                        "Quit and reopen \(row.name)."]
            }
            return ["Review the existing entry in \(service.title); remove it only if Settings offers that option.",
                    "Open \(row.name) and use the feature to request access again.",
                    "Quit and reopen the app after changing access."]
        }
        if service.requiresAppRequest {
            return ["Open \(row.name) and use the feature that needs \(service.title.lowercased()) access.",
                    "Approve its request, or enable its existing entry in \(service.title)."]
        }
        if service.supportsDrag {
            return ["Open Privacy & Security → \(service.title).",
                    "Drag this app into the list and enable it.",
                    "Quit and reopen \(row.name) if needed."]
        }
        return ["Open \(row.name) and use the screen-sharing or recording feature to request access.",
                "Enable its entry in \(service.title), then restart the app if needed."]
    }
}

public struct ReviewSelection: Sendable {
    public var selectedID: String?
    public init(selectedID: String? = nil) { self.selectedID = selectedID }

    public mutating func reconcile(_ snapshot: InventorySnapshot) {
        guard snapshot.blockedDatabases.isEmpty else { selectedID = nil; return }
        if let selectedID, snapshot.rows.contains(where: { $0.id == selectedID }) { return }
        selectedID = Self.ordered(snapshot.rows).first { $0.status.state.needsAttention }?.id
    }

    public mutating func advance(_ snapshot: InventorySnapshot) {
        guard snapshot.blockedDatabases.isEmpty else { selectedID = nil; return }
        selectedID = Self.ordered(snapshot.rows).first { $0.id != selectedID && $0.status.state.needsAttention }?.id
    }

    public func visibleRows(_ snapshot: InventorySnapshot, showAll: Bool) -> [InventoryRow] {
        guard snapshot.blockedDatabases.isEmpty else { return [] }
        return Self.ordered(snapshot.rows).filter { showAll || $0.status.state.needsAttention || $0.id == selectedID }
    }

    private static func ordered(_ rows: [InventoryRow]) -> [InventoryRow] {
        rows.sorted {
            let services = PermissionService.allCases
            let left = services.firstIndex(of: $0.permission.service)!
            let right = services.firstIndex(of: $1.permission.service)!
            if left != right { return left < right }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id < $1.id
        }
    }
}
