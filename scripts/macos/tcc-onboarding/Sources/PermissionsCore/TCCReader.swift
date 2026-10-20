import Foundation
import SQLite3

public struct TCCRecord: Equatable {
    let value: Int64?
    let requirement: Data?
    var malformed = false
}

/// Copies the access table into memory and closes the database immediately, so tccd never waits
/// on this reader while code signatures are evaluated.
public final class TCCSnapshot {
    private struct Key: Hashable { let service: String; let client: String; let clientType: Int32 }
    public let url: URL
    public private(set) var accessBlocked = false
    private var rows: [Key: [TCCRecord]] = [:]
    private var problem: String?

    public init(url: URL) {
        self.url = url
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            accessBlocked = true
            problem = "Cannot read \(url.path). Full Disk Access may be needed."
            return
        }
        sqlite3_busy_timeout(database, 400)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "SELECT service, client, client_type, auth_value, csreq FROM access", -1, &statement, nil) == SQLITE_OK else {
            problem = "Unsupported or unreadable TCC schema in \(url.path)."
            return
        }
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return }
            guard result == SQLITE_ROW else {
                rows = [:]
                problem = "Cannot read TCC records in \(url.path). Try Refresh."
                return
            }
            guard let service = sqlite3_column_text(statement, 0), let client = sqlite3_column_text(statement, 1) else { continue }
            let key = Key(service: String(cString: service), client: String(cString: client), clientType: sqlite3_column_int(statement, 2))
            rows[key, default: []].append(Self.record(statement))
        }
    }

    /// A malformed row is kept as a nil value so the query for its subject reports it.
    private static func record(_ statement: OpaquePointer?) -> TCCRecord {
        let value: Int64? = sqlite3_column_type(statement, 3) == SQLITE_INTEGER ? sqlite3_column_int64(statement, 3) : nil
        let size = sqlite3_column_bytes(statement, 4)
        var requirement: Data?
        if size > 1_048_576 { return TCCRecord(value: value, requirement: nil, malformed: true) }
        if sqlite3_column_type(statement, 4) == SQLITE_BLOB, let bytes = sqlite3_column_blob(statement, 4), size > 0 {
            requirement = Data(bytes: bytes, count: Int(size))
        }
        return TCCRecord(value: value, requirement: requirement, malformed: value == nil)
    }

    private func records(service: PermissionService, subject: PermissionSubject) throws -> [TCCRecord] {
        if let problem { throw ManifestError(problem) }
        let records = rows[Key(service: service.tccName, client: subject.client, clientType: subject.clientType)] ?? []
        if records.contains(where: \.malformed) { throw ManifestError("Unrecognized authorization value or code requirement in \(url.path).") }
        return records
    }

    public static func status(service: PermissionService, subject: PermissionSubject, snapshots: [TCCSnapshot],
                              checker: RequirementChecking) -> GrantStatus {
        guard !snapshots.isEmpty else { return GrantStatus(.unknown, "No TCC databases were supplied.") }
        do {
            var evidence: [(record: TCCRecord, source: String)] = []
            for snapshot in snapshots {
                evidence += try snapshot.records(service: service, subject: subject).map { ($0, snapshot.url.path) }
            }
            guard let first = evidence.first else { return GrantStatus(.missing, "No recorded decision for this client. Open the app or review System Settings.") }
            guard evidence.allSatisfy({ $0.record == first.record }) else {
                return GrantStatus(.unknown, "Conflicting TCC records. Review System Settings; no permissive record was preferred.")
            }
            let source = "Source: \(first.source)."
            switch first.record.value {
            case 0: return GrantStatus(.denied, "macOS records a denial. \(source)")
            case 2:
                let result = checker.check(subject.codeURL, requirement: first.record.requirement)
                switch result {
                case .matches: return GrantStatus(.allowed, "The recorded grant matches the installed code. Restart the target app if it has not adopted the change. \(source)")
                case .mismatch: return GrantStatus(.stale, "The stored grant does not match this app's code identity. Remove and re-add this exact app in Settings where supported, then relaunch it. \(source)")
                case .unverifiable(let reason): return GrantStatus(.unknown, "\(reason) \(source)")
                }
            default: return GrantStatus(.unknown, "The recorded authorization is limited or unsupported (\(first.record.value.map(String.init) ?? "none")). \(source)")
            }
        } catch { return GrantStatus(.unknown, error.localizedDescription) }
    }
}
