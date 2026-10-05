import XCTest
@testable import PermissionsApp
@testable import PermissionsCore

final class ReviewModelTests: XCTestCase {
    func row(_ id: String, state: GrantState) -> InventoryRow {
        let url = URL(fileURLWithPath: "/Applications/\(id).app")
        return InventoryRow(id: id, appID: id, name: id,
            permission: Permission(service: .accessibility, reason: "Manage windows"),
            subject: PermissionSubject(codeURL: url, bundleURL: url, client: id, clientType: 0),
            status: GrantStatus(state, "Sample diagnostic"))
    }

    @MainActor
    func testSettingsFailurePreservesExpandedTaskAndIsVisibleOnUpdate() async {
        let model = PermissionsModel(openSettingsURL: { _ in false })
        model.snapshot = InventorySnapshot(rows: [row("A", state: .stale)], blockedDatabases: [])
        var visibleFailure: String?
        model.onChange = { visibleFailure = model.error }
        model.openSettings(for: .permission("A"))
        XCTAssertEqual(model.selectedID, "A")
        XCTAssertTrue(visibleFailure?.contains("Couldn’t open System Settings") == true)
    }

    @MainActor
    func testNextPermissionAdvancesAndFinishesWithoutChangingGrants() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.snapshot = InventorySnapshot(rows: [row("A", state: .allowed), row("B", state: .denied)], blockedDatabases: [])
        model.selectedID = "A"
        model.nextPermission()
        XCTAssertEqual(model.selectedID, "B")
        model.snapshot = InventorySnapshot(rows: [row("A", state: .allowed), row("B", state: .allowed)], blockedDatabases: [])
        model.nextPermission()
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.snapshot?.rows.map(\.status.state), [.allowed, .allowed])
    }

    @MainActor
    func testBootstrapDoesNotExposeTargetTasksWhileRecordsAreUnreadable() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.snapshot = InventorySnapshot(rows: [row("A", state: .unknown)], blockedDatabases: ["unreadable"])
        XCTAssertTrue(model.needsBootstrap)
        model.showAll = true
        XCTAssertTrue(model.visibleRows.isEmpty)
        model.snapshot = InventorySnapshot(rows: [row("A", state: .denied)], blockedDatabases: [])
        XCTAssertFalse(model.needsBootstrap)
        XCTAssertEqual(model.visibleRows.map(\.id), ["A"])
    }
    @MainActor
    func testRetryPreservesCustomManifestAfterInitialReadFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("custom.json")
        try Data("invalid".utf8).write(to: url)
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.load(url)
        XCTAssertTrue(model.error?.contains(url.path) == true)
        try Data(#"{"version":1,"apps":{}}"#.utf8).write(to: url)
        let loaded = expectation(description: "Custom manifest retried")
        model.onChange = { loaded.fulfill() }
        model.retryLoad()
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.snapshot?.rows.count, 0)
    }

    @MainActor
    func testAccessLossHidesTasksAndRecoverySelectsFirstUnresolvedPermission() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .denied)], blockedDatabases: []))
        XCTAssertEqual(model.selectedID, "A")
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .unknown)], blockedDatabases: ["unreadable"]))
        XCTAssertNil(model.selectedID)
        XCTAssertTrue(model.visibleRows.isEmpty)
        XCTAssertTrue(model.visibleApps.isEmpty)
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .denied), row("B", state: .denied)], blockedDatabases: []))
        XCTAssertEqual(model.selectedID, "A")
    }
}
