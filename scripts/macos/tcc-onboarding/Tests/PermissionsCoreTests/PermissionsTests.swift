import Foundation
import Security
import SQLite3
import XCTest
@testable import PermissionsCore

final class PermissionsTests: XCTestCase {
    var directory: URL!
    let subject = PermissionSubject(codeURL: URL(fileURLWithPath: "/unused/Test.app"),
                                    bundleURL: URL(fileURLWithPath: "/unused/Test.app"),
                                    client: "com.example.test'quoted", clientType: 0)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func manifest(_ changes: [String: Any] = [:]) throws -> Manifest {
        var app: [String: Any] = ["name": "Test", "bundle_id": subject.client, "sources": [],
                                 "permissions": [["service": "accessibility", "reason": "Manage windows"]]]
        app.merge(changes) { _, new in new }
        return try Manifest.decode(JSONSerialization.data(withJSONObject: ["version": 1, "apps": ["test": app]]))
    }

    func database(_ name: String = "TCC.db", value: Int? = nil, client: String? = nil,
                  service: String = "kTCCServiceAccessibility", clientType: Int = 0,
                  requirement: Data? = Data([1])) throws -> URL {
        let url = directory.appendingPathComponent(name)
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE access (service TEXT, client TEXT, client_type INTEGER, auth_value INTEGER, csreq BLOB)", nil, nil, nil), SQLITE_OK)
        if let value { try insert(url, value: value, client: client ?? subject.client, service: service, clientType: clientType, requirement: requirement) }
        return url
    }

    func insert(_ url: URL, value: Int, client: String? = nil, service: String = "kTCCServiceAccessibility",
                clientType: Int = 0, requirement: Data? = Data([1])) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, "INSERT INTO access VALUES (?, ?, ?, ?, ?)", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, service, -1, transient)
        sqlite3_bind_text(statement, 2, client ?? subject.client, -1, transient)
        sqlite3_bind_int(statement, 3, Int32(clientType))
        sqlite3_bind_int64(statement, 4, Int64(value))
        if let requirement { _ = requirement.withUnsafeBytes { sqlite3_bind_blob(statement, 5, $0.baseAddress, Int32($0.count), transient) } }
        else { sqlite3_bind_null(statement, 5) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }

    struct Checker: RequirementChecking {
        let result: RequirementResult
        func check(_ url: URL, requirement: Data?) -> RequirementResult { result }
    }

    func status(_ urls: [URL], result: RequirementResult = .matches,
                service: PermissionService = .accessibility) -> GrantStatus {
        let snapshots = urls.map(TCCSnapshot.init)
        defer { snapshots.forEach { $0.close() } }
        return TCCSnapshot.status(service: service, subject: subject, snapshots: snapshots, checker: Checker(result: result))
    }

    func testOnlyExactAllowWithMatchingCodeSatisfiesExpectation() throws {
        for (value, expected) in [(0, GrantState.denied), (1, .unknown), (2, .allowed), (3, .unknown), (99, .unknown), (4_294_967_298, .unknown)] {
            let url = try database("\(value).db", value: value)
            XCTAssertEqual(status([url]).state, expected)
        }
        let allowed = directory.appendingPathComponent("2.db")
        XCTAssertEqual(status([allowed], result: .mismatch).state, .stale)
        XCTAssertEqual(status([allowed], result: .unverifiable("invalid code")).state, .unknown)
    }

    func testMissingDecisionIsDistinctFromConflictingEvidence() throws {
        let user = try database("user.db")
        let system = try database("system.db", value: 2)
        XCTAssertEqual(status([user]).state, .missing)
        XCTAssertEqual(status([user, system]).state, .allowed)
        try insert(user, value: 0)
        XCTAssertEqual(status([user, system]).state, .unknown)
        XCTAssertEqual(status([system, user]).state, .unknown)
        try insert(system, value: 0)
        XCTAssertEqual(status([system]).state, .unknown)
    }

    func testReadFailuresAreNotDenialsOrGrantsAndNeverCreateDatabase() throws {
        let missing = directory.appendingPathComponent("missing.db")
        let allowed = try database(value: 2)
        XCTAssertEqual(status([allowed, missing]).state, .unknown)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let corrupt = directory.appendingPathComponent("corrupt.db")
        try Data("not sqlite".utf8).write(to: corrupt)
        XCTAssertEqual(status([corrupt]).state, .unknown)
        let unsupported = directory.appendingPathComponent("unsupported.db")
        try Data().write(to: unsupported)
        XCTAssertEqual(status([unsupported]).state, .unknown)
    }

    func testQueriesMatchExactClientTypeAndServiceWithoutMutatingDatabase() throws {
        let url = try database(value: 0, client: "other")
        try insert(url, value: 0, clientType: 1)
        try insert(url, value: 0, service: "kTCCServiceMicrophone")
        try insert(url, value: 2)
        let before = try Data(contentsOf: url)
        XCTAssertEqual(status([url]).state, .allowed)
        XCTAssertEqual(status([url], service: .microphone).state, .denied)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testInventoryDoesNotOpenDatabasesWhenNoTargetsAreInstalled() throws {
        let manifest = try manifest()
        let missing = directory.appendingPathComponent("missing.db")
        let result = Inventory.scan([Expectation(id: "test", app: manifest.apps["test"]!, resolution: .missing("not installed"))], databases: [missing])
        XCTAssertFalse(result.needsAttention)
        XCTAssertTrue(result.blockedDatabases.isEmpty)
        XCTAssertEqual(result.rows.first?.status.state, .notInstalled)
    }

    func testRefreshObservesChangesInsteadOfCachingGrants() throws {
        let url = try database()
        XCTAssertEqual(status([url]).state, .missing)
        try insert(url, value: 2)
        XCTAssertEqual(status([url]).state, .allowed)
    }

    func testManifestRejectsTyposDuplicateServicesAndEscapingHelperPaths() throws {
        XCTAssertThrowsError(try manifest(["bundle_path": "/Applications/Test.app"]))
        XCTAssertThrowsError(try manifest(["helper_path": "Contents/../../bin/tool"]))
        XCTAssertThrowsError(try manifest(["path": "relative/Test.app"]))
        XCTAssertThrowsError(try manifest(["permissions": [["service": "unknown", "reason": "x"]]]))
        XCTAssertThrowsError(try manifest(["permissions": [["service": "camera", "reason": " "]]]))
        XCTAssertThrowsError(try manifest(["permissions": [["service": "camera", "reason": "x"], ["service": "camera", "reason": "y"]]]))
        XCTAssertThrowsError(try Manifest.decode(Data(#"{"version":2,"apps":{}}"#.utf8)))
    }

    func makeApp(_ name: String, id: String) throws -> URL {
        let app = directory.appendingPathComponent("\(name).app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id, "CFBundlePackageType": "APPL"], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    func testResolverRequiresUniqueVerifiedIdentityAndConfinesHelpers() throws {
        let a = try makeApp("A", id: subject.client)
        let b = try makeApp("B", id: subject.client)
        let app = try manifest().apps["test"]!
        if case .ambiguous = SubjectResolver.resolve(app, candidates: [a, b]) {} else { XCTFail("Duplicate copies must require selection") }
        if case .found(let selected) = SubjectResolver.resolve(app, candidates: [a, b], selected: b) {
            XCTAssertEqual(selected.codeURL, b.resolvingSymlinksInPath())
        } else { XCTFail("Explicit selection should resolve") }
        let other = try makeApp("Other", id: "other")
        if case .ambiguous = SubjectResolver.resolve(app, candidates: [], selected: other) {} else { XCTFail("Wrong bundle identity must fail") }
        try FileManager.default.createSymbolicLink(at: a.appendingPathComponent("Contents/outside"), withDestinationURL: URL(fileURLWithPath: "/usr/bin/true"))
        let helper = try manifest(["helper_path": "Contents/outside"]).apps["test"]!
        if case .ambiguous = SubjectResolver.resolve(helper, candidates: [a]) {} else { XCTFail("Escaping symlink must fail") }
    }

    func run(_ program: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: program)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: data, as: UTF8.self))
    }

    func testRealCodeRequirementsDetectStaleIdentityWithoutRejectingMatchingUpdates() throws {
        let code = directory.appendingPathComponent("signed-tool")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: code)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "com.example.permissions", code.path])
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString("identifier \"com.example.permissions\"" as CFString, [], &requirement), errSecSuccess)
        var blob: CFData?
        XCTAssertEqual(SecRequirementCopyData(requirement!, [], &blob), errSecSuccess)
        let data = blob! as Data
        XCTAssertEqual(CodeRequirementChecker().check(code, requirement: data), .matches)
        try FileManager.default.removeItem(at: code)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/false"), to: code)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "com.example.permissions", code.path])
        XCTAssertEqual(CodeRequirementChecker().check(code, requirement: data), .matches)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "com.example.changed", code.path])
        XCTAssertEqual(CodeRequirementChecker().check(code, requirement: data), .mismatch)
        var damaged = try Data(contentsOf: code)
        damaged[4096] ^= 1
        try damaged.write(to: code)
        if case .unverifiable = CodeRequirementChecker().check(code, requirement: data) {} else {
            XCTFail("Damaged code must not be called a stale identity")
        }
        for requirement in [nil, Data([0, 1, 2])] {
            if case .unverifiable = CodeRequirementChecker().check(code, requirement: requirement) {} else { XCTFail("Missing/corrupt requirements must remain unknown") }
        }
    }
}
