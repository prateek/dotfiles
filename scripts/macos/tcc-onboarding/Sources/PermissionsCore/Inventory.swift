import Foundation
import Security

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
        var identities: [URL: String] = [:]
        for url in existing.sorted(by: { $0.path < $1.path }) {
            guard let identity = Bundle(url: url)?.bundleIdentifier, !identity.isEmpty else {
                return .ambiguous("Cannot read a valid bundle identity at \(url.path). Repair the app or choose a verified copy.")
            }
            identities[url] = identity
        }
        let matching = existing.filter { identities[$0] == app.bundleID }
        if let explicit, !existing.isEmpty, matching.isEmpty {
            return .ambiguous("The bundle at \(explicit.path) does not match \(app.bundleID).")
        }
        guard !matching.isEmpty else { return .missing("No installed bundle with identifier \(app.bundleID).") }
        let ranked = matching.sorted { rank($0) < rank($1) }
        guard let bundle = ranked.first, ranked.count == 1 || sharesDesignatedRequirement(ranked) else {
            return .ambiguous("Multiple installed copies of \(app.bundleID) have different code identities: "
                + ranked.map(\.path).joined(separator: ", ") + ". Choose the app you use or set its path in the manifest.")
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

extension SubjectResolver {
    /// Copies with one designated requirement satisfy the same TCC record, so their verdicts cannot
    /// differ; prefer the user-facing install over support copies such as Orca's terminal host.
    static func rank(_ url: URL) -> (Int, Int, String) {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let preferred = path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
        let support = path.contains("/Library/") || path.contains(".noindex/")
        return (preferred ? 0 : support ? 2 : 1, path.count, path)
    }

    static func sharesDesignatedRequirement(_ urls: [URL]) -> Bool {
        let requirements = urls.map(designatedRequirement)
        guard let first = requirements.first, first != nil else { return false }
        return requirements.allSatisfy { $0 == first }
    }

    private struct RequirementKey: Hashable { let url: URL; let signed: Date? }
    nonisolated(unsafe) private static var requirements: [RequirementKey: String?] = [:]
    private static let requirementsLock = NSLock()

    /// Cached per path and signature date: the GUI resolves on every poll.
    static func designatedRequirement(_ url: URL) -> String? {
        let key = RequirementKey(url: url, signed: CodeRequirementChecker.signatureDate(url))
        if let cached = requirementsLock.withLock({ requirements[key] }) { return cached }
        let requirement = readDesignatedRequirement(url)
        requirementsLock.withLock { requirements[key] = requirement }
        return requirement
    }

    private static func readDesignatedRequirement(_ url: URL) -> String? {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        var text: CFString?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess, let requirement,
              SecRequirementCopyString(requirement, [], &text) == errSecSuccess else { return nil }
        return text as String?
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
    /// `requireAccess` opens the databases even when no target is installed, so a caller can
    /// treat an unreadable database as a failure rather than as nothing to reconcile.
    public static func scan(_ expectations: [Expectation], databases: [URL], requireAccess: Bool = false,
                            checker: RequirementChecking = CodeRequirementChecker()) -> InventorySnapshot {
        let found = expectations.contains { if case .found = $0.resolution { return true }; return false }
        let readers = found || requireAccess ? databases.map(TCCSnapshot.init) : []
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
