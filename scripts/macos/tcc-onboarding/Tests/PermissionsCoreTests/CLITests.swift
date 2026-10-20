import Foundation
import XCTest
@testable import PermissionsCore

final class CLITests: XCTestCase {
    final class Host: CLIHost {
        var snapshot = InventorySnapshot(rows: [], blockedDatabases: [])
        var databases = [DatabaseAccess(path: "/user/TCC.db", readable: true), DatabaseAccess(path: "/system/TCC.db", readable: true)]
        var responsibility = Responsibility.helper
        var scans = 0
        var opened: [URL] = []
        var guiOpened = false
        let version = "1.0 (cli 2)"
        let bundlePath: String? = "/Users/me/Applications/Dotfiles Permissions.app"
        func expectations(_ manifest: Manifest) -> [Expectation] {
            manifest.apps.map { Expectation(id: $0.key, app: $0.value, resolution: .missing("No installed bundle with identifier \($0.value.bundleID).")) }
        }
        func scan(_ manifest: Manifest) -> InventorySnapshot { scans += 1; return snapshot }
        func probeDatabases() -> [DatabaseAccess] { databases }
        func openURL(_ url: URL) -> Bool { opened.append(url); return true }
        func openGUI() -> Bool { guiOpened = true; return true }
    }

    var directory: URL!
    var manifest: URL!
    let host = Host()

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        manifest = directory.appendingPathComponent("tcc.json")
        try Data(#"{"version":1,"apps":{"test":{"name":"Test","bundle_id":"com.example.test","sources":[],"permissions":[{"service":"accessibility","reason":"Windows"}]}}}"#.utf8).write(to: manifest)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func run(_ arguments: [String]) -> CLIResult {
        CLI.run(arguments + ["--manifest", manifest.path], host: host)
    }

    func json(_ result: CLIResult) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
    }

    func row(_ state: GrantState) -> InventoryRow {
        InventoryRow(id: "test:accessibility", appID: "test", name: "Test", permission: Permission(service: .accessibility, reason: "Windows"),
                     subject: nil, status: GrantStatus(state, "Evidence reason"))
    }

    func testManifestFollowsXDGConfigHome() {
        let home = URL(fileURLWithPath: "/Users/me")
        XCTAssertEqual(ManifestLocation.url(environment: [:], home: home).path, "/Users/me/.config/dotfiles/tcc.json")
        XCTAssertEqual(ManifestLocation.url(environment: ["XDG_CONFIG_HOME": "/xdg"], home: home).path, "/xdg/dotfiles/tcc.json")
        XCTAssertEqual(ManifestLocation.url(environment: ["XDG_CONFIG_HOME": "relative"], home: home).path, "/Users/me/.config/dotfiles/tcc.json")
        XCTAssertEqual(CLI.run(["manifest", "path"], host: host, environment: ["XDG_CONFIG_HOME": "/xdg"]).stdout, "/xdg/dotfiles/tcc.json\n")
    }

    func testAuditSeparatesDeviationsFromInconclusiveAndPointsAtGUI() {
        let cases: [(GrantState, Int32)] = [(.allowed, ExitCode.ok), (.notInstalled, ExitCode.ok), (.missing, ExitCode.deviations),
                                            (.denied, ExitCode.deviations), (.stale, ExitCode.deviations), (.unknown, ExitCode.inconclusive)]
        for (state, expected) in cases {
            host.snapshot = InventorySnapshot(rows: [row(state)], blockedDatabases: [])
            let result = run(["audit"])
            XCTAssertEqual(result.status, expected, "\(state)")
            if expected == ExitCode.ok { XCTAssertEqual(result.stdout, "") }
            else {
                XCTAssertTrue(result.stdout.contains("Test / Accessibility: \(state.rawValue) — Evidence reason"))
                XCTAssertTrue(result.stdout.contains("dotfiles-permissions gui"))
            }
        }
    }

    func testUnreadableDatabasesAreAnErrorWithRecoveryEvenWithoutTargets() throws {
        host.snapshot = InventorySnapshot(rows: [], blockedDatabases: ["/system/TCC.db"])
        for command in [["audit"], ["grants", "list"]] {
            let result = run(command)
            XCTAssertEqual(result.status, ExitCode.noAccess)
            XCTAssertEqual(result.stdout, "")
            XCTAssertTrue(result.stderr.contains("Full Disk Access"))
            XCTAssertTrue(result.stderr.contains("remove it"))
        }
        let result = run(["--json", "audit"])
        XCTAssertEqual(result.status, ExitCode.noAccess)
        let error = try XCTUnwrap(try json(result)["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? String, "tcc_unreadable")
        XCTAssertEqual(error["databases"] as? [String], ["/system/TCC.db"])
    }

    func testScanCanRequireDatabaseAccessWithNoInstalledTargets() {
        let missing = directory.appendingPathComponent("absent/TCC.db")
        let expectation = Expectation(id: "test", app: try! Manifest.load(manifest).apps["test"]!, resolution: .missing("absent"))
        XCTAssertEqual(Inventory.scan([expectation], databases: [missing]).blockedDatabases, [])
        XCTAssertEqual(Inventory.scan([expectation], databases: [missing], requireAccess: true).blockedDatabases, [missing.path])
    }

    func testJSONAuditShapeOnStdout() throws {
        host.snapshot = InventorySnapshot(rows: [row(.missing), row(.allowed)], blockedDatabases: [])
        let result = run(["audit", "--json"])
        XCTAssertEqual(result.status, ExitCode.deviations)
        XCTAssertEqual(result.stderr, "")
        let body = try json(result)
        XCTAssertEqual(body["summary"] as? [String: Int], ["missing": 1, "allowed": 1])
        XCTAssertEqual((body["grants"] as? [[String: Any]])?.map { $0["state"] as? String }, ["missing"])
        XCTAssertEqual(body["gui_command"] as? String, "dotfiles-permissions gui")
        XCTAssertEqual(body["responsibility"] as? String, "helper")
    }

    func testInvalidInputNeverScans() throws {
        try Data("{".utf8).write(to: manifest)
        XCTAssertEqual(run(["audit"]).status, ExitCode.manifest)
        XCTAssertEqual(run(["manifest", "validate"]).status, ExitCode.manifest)
        XCTAssertEqual(try json(run(["--json", "grants", "list"]))["error"].flatMap { ($0 as? [String: Any])?["code"] as? String }, "manifest_invalid")
        for arguments in [[], ["audit", "--bogus"], ["frobnicate"], ["apps", "list", "--app", "test"], ["--manifest"]] {
            XCTAssertEqual(CLI.run(arguments, host: host).status, ExitCode.usage, "\(arguments)")
        }
        XCTAssertEqual(host.scans, 0)
    }

    func testCommandWordsSkipOptionValues() {
        XCTAssertEqual(CLI.commandWords(["--manifest", "/x/audit", "audit", "--json"]), ["audit"])
        XCTAssertEqual(CLI.commandWords(["--app", "doctor", "grants", "list"]), ["grants", "list"])
        XCTAssertTrue(CLI.wantsHelp(["audit", "--help"]))
        XCTAssertFalse(CLI.wantsHelp(["--app", "help", "grants", "list"]))
    }

    func testGrantsListFiltersByApp() throws {
        host.snapshot = InventorySnapshot(rows: [row(.allowed)], blockedDatabases: [])
        XCTAssertEqual(run(["grants", "list", "--app", "test"]).stdout, "test\taccessibility\tallowed\tEvidence reason\n")
        XCTAssertEqual(run(["grants", "list", "--app", "other"]).status, ExitCode.usage)
    }

    func testDoctorReportsHelperAccessAndResponsibility() throws {
        XCTAssertEqual(run(["doctor"]).status, ExitCode.ok)
        host.databases = [DatabaseAccess(path: "/system/TCC.db", readable: false)]
        host.responsibility = .inherited
        let result = run(["--json", "doctor"])
        XCTAssertEqual(result.status, ExitCode.noAccess)
        let body = try json(result)
        XCTAssertEqual(body["ok"] as? Bool, false)
        XCTAssertEqual(body["responsibility"] as? String, "inherited")
        XCTAssertEqual((body["next_steps"] as? [String])?.count, 2)
    }

    func testSettingsAndGUI() {
        XCTAssertEqual(run(["settings", "open", "fullDiskAccess"]).status, ExitCode.ok)
        XCTAssertEqual(host.opened, [PermissionService.fullDiskAccess.settingsURL])
        XCTAssertEqual(run(["settings", "open", "disk"]).status, ExitCode.usage)
        XCTAssertEqual(run(["gui"]).status, ExitCode.ok)
        XCTAssertTrue(host.guiOpened)
    }
}
