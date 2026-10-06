import Foundation

public struct PermissionTask: Sendable {
    public enum Action: Sendable { case settings, openApp, chooseApp, none }
    public let row: InventoryRow
    public init(_ row: InventoryRow) { self.row = row }

    public var action: Action {
        guard row.status.state.needsAttention else { return .none }
        guard row.subject != nil else { return .chooseApp }
        return row.permission.service.requiresAppRequest && row.status.state == .missing ? .openApp : .settings
    }

    public var summary: String {
        switch row.status.state {
        case .allowed: return "The recorded permission matches this installed app."
        case .stale: return "The saved permission does not match this installed copy."
        case .denied: return "macOS records this permission as off."
        case .missing: return "No permission decision is recorded for this installed copy."
        case .unknown:
            return row.subject == nil ? "Choose the installed copy you use before reviewing its access."
                : "We couldn’t confirm this permission. Review the app’s entry in System Settings."
        case .notInstalled: return "This app or its declared helper is not installed. No action is needed."
        }
    }

    public var offersFileHandoff: Bool {
        row.subject != nil && row.permission.service.supportsDrag && [.missing, .stale].contains(row.status.state)
    }

    public var steps: [String] {
        let service = row.permission.service
        if row.status.state == .allowed { return ["Quit and reopen \(row.name) if it hasn’t adopted the change."] }
        guard row.status.state.needsAttention, row.subject != nil else { return [] }
        if row.status.state == .unknown {
            return ["Check Evidence to understand why this permission cannot be confirmed.",
                    "Review the existing entry in \(service.title) before deciding whether to change access.",
                    "Recheck after resolving the uncertainty."]
        }
        if row.status.state == .denied {
            return ["Review the existing entry in \(service.title).",
                    "If you want this app to have the declared access, turn on that entry.",
                    "Quit and reopen \(row.name) after changing access, then recheck."]
        }
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

public struct AppReviewGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rows: [InventoryRow]
}

public enum ReviewGrouping: String, Sendable { case app, permission }

public struct PermissionReviewGroup: Identifiable, Sendable {
    public let service: PermissionService
    public let rows: [InventoryRow]
    public var id: String { service.rawValue }
}

public struct ReviewSelection: Sendable {
    public var selectedID: String?
    public var grouping: ReviewGrouping
    public var deferredIDs: Set<String>

    public init(selectedID: String? = nil, grouping: ReviewGrouping = .app, deferredIDs: Set<String> = []) {
        self.selectedID = selectedID
        self.grouping = grouping
        self.deferredIDs = deferredIDs
    }

    public mutating func reconcile(_ snapshot: InventorySnapshot) {
        guard snapshot.blockedDatabases.isEmpty else { selectedID = nil; return }
        if let selectedID, snapshot.rows.contains(where: { $0.id == selectedID }) { return }
        selectedID = ordered(snapshot.rows).first { pending($0) }?.id
    }

    public mutating func advance(_ snapshot: InventorySnapshot) {
        guard snapshot.blockedDatabases.isEmpty else { selectedID = nil; return }
        let rows = ordered(snapshot.rows)
        let index = rows.firstIndex { $0.id == selectedID } ?? -1
        let rotated = Array(rows.dropFirst(index + 1)) + Array(rows.prefix(index + 1))
        selectedID = rotated.first { pending($0) }?.id
    }

    public func visibleRows(_ snapshot: InventorySnapshot, showAll: Bool) -> [InventoryRow] {
        guard snapshot.blockedDatabases.isEmpty else { return [] }
        return ordered(snapshot.rows).filter { showAll || $0.status.state.needsAttention || $0.id == selectedID }
    }

    public func appGroups(_ snapshot: InventorySnapshot, showAll: Bool) -> [AppReviewGroup] {
        let appSelection = ReviewSelection(selectedID: selectedID, grouping: .app, deferredIDs: deferredIDs)
        var groups: [AppReviewGroup] = []
        for row in appSelection.visibleRows(snapshot, showAll: showAll) {
            if let last = groups.last, last.id == row.appID {
                groups[groups.count - 1] = AppReviewGroup(id: last.id, name: last.name, rows: last.rows + [row])
            } else { groups.append(AppReviewGroup(id: row.appID, name: row.name, rows: [row])) }
        }
        return groups
    }

    public func permissionGroups(_ snapshot: InventorySnapshot, showAll: Bool) -> [PermissionReviewGroup] {
        let rows = visibleRows(snapshot, showAll: showAll)
        return PermissionService.allCases.compactMap { service in
            let matching = rows.filter { $0.permission.service == service }
            return matching.isEmpty ? nil : PermissionReviewGroup(service: service, rows: matching)
        }
    }

    private func pending(_ row: InventoryRow) -> Bool {
        row.status.state.needsAttention && !deferredIDs.contains(row.id)
    }

    private func ordered(_ rows: [InventoryRow]) -> [InventoryRow] {
        let rank = Dictionary(uniqueKeysWithValues: PermissionService.allCases.enumerated().map { ($1, $0) })
        return rows.sorted {
            let left = rank[$0.permission.service]!
            let right = rank[$1.permission.service]!
            if grouping == .permission && left != right { return left < right }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if $0.appID != $1.appID { return $0.appID < $1.appID }
            if left != right { return left < right }
            return $0.id < $1.id
        }
    }
}
