import Foundation
import SQLite3

public struct TCCRecord: Equatable {
    let value: Int64
    let requirement: Data?
}

public final class TCCSnapshot {
    public let url: URL
    public private(set) var accessBlocked = false
    private var database: OpaquePointer?
    private var problem: String?

    public init(url: URL) {
        self.url = url
        let result = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK else {
            accessBlocked = true
            problem = "Cannot read \(url.path). Full Disk Access may be needed."
            close()
            return
        }
        sqlite3_busy_timeout(database, 400)
        guard sqlite3_exec(database, "BEGIN", nil, nil, nil) == SQLITE_OK else {
            problem = "Cannot take a read snapshot of \(url.path). Try Refresh."
            return
        }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "SELECT service, client, client_type, auth_value, csreq FROM access LIMIT 0", -1, &statement, nil) == SQLITE_OK else {
            problem = "Unsupported or unreadable TCC schema in \(url.path)."
            return
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            problem = "Cannot read TCC records in \(url.path). Try Refresh."
            return
        }
    }

    deinit { close() }

    public func close() {
        if let database { sqlite3_close(database) }
        database = nil
    }

    private func records(service: PermissionService, subject: PermissionSubject) throws -> [TCCRecord] {
        if let problem { throw ManifestError(problem) }
        guard let database else { throw ManifestError("TCC snapshot is closed.") }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let sql = "SELECT auth_value, csreq FROM access WHERE service = ? AND client = ? AND client_type = ?"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ManifestError("Cannot query \(url.path).")
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, service.tccName, -1, transient)
        sqlite3_bind_text(statement, 2, subject.client, -1, transient)
        sqlite3_bind_int(statement, 3, subject.clientType)
        var records: [TCCRecord] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return records }
            guard result == SQLITE_ROW else { throw ManifestError("TCC query failed in \(url.path). Try Refresh.") }
            guard sqlite3_column_type(statement, 0) == SQLITE_INTEGER else {
                throw ManifestError("Unrecognized authorization value in \(url.path).")
            }
            let size = sqlite3_column_bytes(statement, 1)
            guard size <= 1_048_576 else { throw ManifestError("Unrecognized code requirement in \(url.path).") }
            let requirement: Data?
            if sqlite3_column_type(statement, 1) == SQLITE_BLOB, let bytes = sqlite3_column_blob(statement, 1), size > 0 {
                requirement = Data(bytes: bytes, count: Int(size))
            } else {
                requirement = nil
            }
            records.append(TCCRecord(value: sqlite3_column_int64(statement, 0), requirement: requirement))
        }
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
            default: return GrantStatus(.unknown, "The recorded authorization is limited or unsupported (\(first.record.value)). \(source)")
            }
        } catch { return GrantStatus(.unknown, error.localizedDescription) }
    }
}
