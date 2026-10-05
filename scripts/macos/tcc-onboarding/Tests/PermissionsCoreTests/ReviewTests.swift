import XCTest
@testable import PermissionsCore

final class ReviewTests: XCTestCase {
    func row(_ id: String, state: GrantState, service: PermissionService = .accessibility,
             installed: Bool = true) -> InventoryRow {
        let url = URL(fileURLWithPath: "/Applications/\(id).app")
        return InventoryRow(id: id, appID: id, name: id,
            permission: Permission(service: service, reason: "Use a feature"),
            subject: installed ? PermissionSubject(codeURL: url, bundleURL: url, client: id, clientType: 0) : nil,
            status: GrantStatus(state, "Diagnostic details"))
    }

    func testStaleRecoveryDiffersFromDenialAndSurvivesInEitherSurface() {
        let stale = PermissionTask(row("Example", state: .stale))
        XCTAssertEqual(stale.action, .settings)
        XCTAssertEqual(stale.summary, "The saved permission does not match this installed copy.")
        XCTAssertEqual(stale.steps.first, "Remove the old entry from Accessibility.")
        XCTAssertFalse(PermissionTask(row("Example", state: .denied)).steps.contains(stale.steps[0]))
        let camera = PermissionTask(row("Example", state: .stale, service: .camera))
        XCTAssertEqual(camera.action, .openApp)
        XCTAssertTrue(camera.steps.contains { $0.contains("only if Settings offers") })
    }

    func testTargetRequestAndAmbiguousCopyHaveDistinctPrimaryActions() {
        XCTAssertEqual(PermissionTask(row("Example", state: .unknown, service: .microphone)).action, .openApp)
        XCTAssertEqual(PermissionTask(row("Example", state: .denied, service: .microphone)).action, .settings)
        XCTAssertEqual(PermissionTask(row("Example", state: .unknown, installed: false)).action, .chooseApp)
        XCTAssertEqual(PermissionTask(row("Example", state: .notInstalled, installed: false)).action, .none)
        XCTAssertEqual(PermissionTask(row("Example", state: .allowed)).action, .none)
    }

    func testResolvedSelectionStaysVisibleUntilUserAdvances() {
        var selection = ReviewSelection()
        selection.reconcile(InventorySnapshot(rows: [row("B", state: .denied), row("A", state: .denied)], blockedDatabases: []))
        XCTAssertEqual(selection.selectedID, "A")
        let refreshed = InventorySnapshot(rows: [row("A", state: .allowed), row("B", state: .denied)], blockedDatabases: [])
        selection.reconcile(refreshed)
        XCTAssertEqual(selection.selectedID, "A")
        XCTAssertEqual(selection.visibleRows(refreshed, showAll: false).map(\.id), ["A", "B"])
        selection.advance(refreshed)
        XCTAssertEqual(selection.selectedID, "B")
        let complete = InventorySnapshot(rows: [row("B", state: .allowed)], blockedDatabases: [])
        selection.reconcile(complete)
        XCTAssertEqual(selection.selectedID, "B")
        selection.advance(complete)
        XCTAssertNil(selection.selectedID)
    }
}
