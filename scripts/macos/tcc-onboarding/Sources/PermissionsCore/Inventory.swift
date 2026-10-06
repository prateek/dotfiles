import Foundation

public enum GrantState: String, Sendable {
    case allowed, denied, stale, missing, unknown, notInstalled

    public var title: String {
        switch self {
        case .allowed: return "Recorded allow"
        case .denied: return "Not allowed"
        case .stale: return "Identity changed"
        case .missing: return "Needs a grant"
        case .unknown: return "Cannot check"
        case .notInstalled: return "Not installed"
        }
    }

    public var needsAttention: Bool { self != .allowed && self != .notInstalled }
}

public struct GrantStatus: Sendable, Equatable {
    public let state: GrantState
    public let detail: String
    public init(_ state: GrantState, _ detail: String) { self.state = state; self.detail = detail }
}

public struct PermissionSubject: Hashable, Sendable {
    public let codeURL: URL
    public let bundleURL: URL
    public let client: String
    public let clientType: Int32

    public init(codeURL: URL, bundleURL: URL, client: String, clientType: Int32) {
        self.codeURL = codeURL; self.bundleURL = bundleURL; self.client = client; self.clientType = clientType
    }
}

public enum SubjectResolution: Sendable {
    case found(PermissionSubject), missing(String), ambiguous(String)
}

public enum SubjectResolver {
    public static func resolve(_ app: AppDeclaration, candidates: [URL], selected: URL? = nil) -> SubjectResolution {
        let explicit = selected ?? app.path.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
        let urls = explicit.map { [$0] } ?? candidates
        let existing = Set(urls.map { $0.resolvingSymlinksInPath().standardizedFileURL })
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        let matching = existing.filter { Bundle(url: $0)?.bundleIdentifier == app.bundleID }
        if let explicit, !existing.isEmpty, matching.isEmpty {
            return .ambiguous("The bundle at \(explicit.path) does not match \(app.bundleID).")
        }
        guard !matching.isEmpty else { return .missing("No installed bundle with identifier \(app.bundleID).") }
        guard matching.count == 1, let bundle = matching.first else {
            return .ambiguous("Multiple installed copies match \(app.bundleID). Choose the app you use or set its path in the manifest.")
        }
        if let relative = app.helperPath {
            let helper = bundle.appendingPathComponent(relative).resolvingSymlinksInPath()
            guard helper.path.hasPrefix(bundle.path + "/") else { return .ambiguous("The helper resolves outside its app bundle.") }
            guard FileManager.default.isExecutableFile(atPath: helper.path) else { return .missing("The declared helper is missing: \(helper.path)") }
            return .found(PermissionSubject(codeURL: helper, bundleURL: bundle, client: helper.path, clientType: 1))
        }
        return .found(PermissionSubject(codeURL: bundle, bundleURL: bundle, client: app.bundleID, clientType: 0))
    }
}

public struct Expectation: Sendable {
    public let id: String
    public let app: AppDeclaration
    public let resolution: SubjectResolution
    public init(id: String, app: AppDeclaration, resolution: SubjectResolution) {
        self.id = id; self.app = app; self.resolution = resolution
    }
}

public struct InventoryRow: Identifiable, Sendable {
    public let id: String
    public let appID: String
    public let name: String
    public let permission: Permission
    public let subject: PermissionSubject?
    public let status: GrantStatus
}

public struct InventorySnapshot: Sendable {
    public let rows: [InventoryRow]
    public let blockedDatabases: [String]
    public var needsAttention: Bool { rows.contains { $0.status.state.needsAttention } }
}

public enum Inventory {
    public static func scan(_ expectations: [Expectation], databases: [URL],
                            checker: RequirementChecking = CodeRequirementChecker()) -> InventorySnapshot {
        let found = expectations.contains { if case .found = $0.resolution { return true }; return false }
        let readers = found ? databases.map(TCCSnapshot.init) : []
        defer { readers.forEach { $0.close() } }
        let blocked = readers.filter(\.accessBlocked).map { $0.url.path }
        var rows: [InventoryRow] = []
        for expectation in expectations {
            for permission in expectation.app.permissions {
                let status: GrantStatus
                var subject: PermissionSubject?
                switch expectation.resolution {
                case .missing(let reason): status = GrantStatus(.notInstalled, reason)
                case .ambiguous(let reason): status = GrantStatus(.unknown, reason)
                case .found(let resolved):
                    subject = resolved
                    status = TCCSnapshot.status(service: permission.service, subject: resolved, snapshots: readers, checker: checker)
                }
                rows.append(InventoryRow(id: "\(expectation.id):\(permission.service.rawValue)", appID: expectation.id,
                                         name: expectation.app.name, permission: permission, subject: subject, status: status))
            }
        }
        return InventorySnapshot(rows: rows, blockedDatabases: blocked)
    }
}
