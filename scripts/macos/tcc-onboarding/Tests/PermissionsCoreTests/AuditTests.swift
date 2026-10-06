import Foundation
import XCTest
@testable import PermissionsCore

final class AuditTests: XCTestCase {
    func testReportsDeviationsAndKeepsUnknownDistinct() throws {
        let manifest = try Manifest.decode(Data(#"{"version":1,"apps":{"test":{"name":"Test","bundle_id":"com.example.test","sources":[],"permissions":[{"service":"accessibility","reason":"Windows"}]}}}"#.utf8))
        let permission = manifest.apps["test"]!.permissions[0]
        for (state, expected) in [(GrantState.allowed, Int32(0)), (.notInstalled, 0), (.missing, 2), (.denied, 2), (.stale, 2), (.unknown, 3)] {
            let row = InventoryRow(id: "test:accessibility", appID: "test", name: "Test", permission: permission,
                                   subject: nil, status: GrantStatus(state, "Evidence reason"))
            let report = AuditReport(InventorySnapshot(rows: [row], blockedDatabases: []))
            XCTAssertEqual(report.exitStatus, expected)
            if expected == 0 { XCTAssertEqual(report.output, "") }
            else {
                XCTAssertTrue(report.output.contains("Test / Accessibility: \(state.rawValue)"))
                XCTAssertTrue(report.output.contains("Evidence reason"))
            }
        }
        let blocked = AuditReport(InventorySnapshot(rows: [], blockedDatabases: ["/unreadable.db"]))
        XCTAssertEqual(blocked.exitStatus, 3)
        XCTAssertTrue(blocked.output.contains("GUI must check its own access"))
    }

    func testInvalidManifestAndArgumentsNeverScan() {
        for args in [["--audit"], ["--audit", "/nonexistent/manifest.json"], ["--audit", "a", "b"]] {
            let result = AuditCommand.run(args) { _ in XCTFail("Invalid input must not scan"); return InventorySnapshot(rows: [], blockedDatabases: []) }
            XCTAssertEqual(result.status, 64)
            XCTAssertFalse(result.output.isEmpty)
        }
    }
}
