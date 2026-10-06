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

    func testStaleRecoveryDiffersFromDenialAndAppOwnedRecovery() {
        let stale = PermissionTask(row("Example", state: .stale))
        XCTAssertEqual(stale.action, .settings)
        XCTAssertTrue(stale.offersFileHandoff)
        XCTAssertTrue(PermissionTask(row("Example", state: .missing)).offersFileHandoff)
        XCTAssertFalse(PermissionTask(row("Example", state: .allowed)).offersFileHandoff)
        XCTAssertEqual(stale.summary, "The saved permission does not match this installed copy.")
        XCTAssertEqual(stale.steps.first, "Remove the old entry from Accessibility.")
        XCTAssertFalse(PermissionTask(row("Example", state: .denied)).steps.contains(stale.steps[0]))
        let camera = PermissionTask(row("Example", state: .stale, service: .camera))
        XCTAssertEqual(camera.action, .settings)
        XCTAssertTrue(camera.steps.contains { $0.contains("only if Settings offers") })
    }

    func testTargetRequestAndAmbiguousCopyHaveDistinctPrimaryActions() {
        XCTAssertEqual(PermissionTask(row("Example", state: .missing, service: .microphone)).action, .openApp)
        XCTAssertEqual(PermissionTask(row("Example", state: .denied, service: .microphone)).action, .settings)
        XCTAssertEqual(PermissionTask(row("Example", state: .unknown, service: .microphone)).action, .settings)
        XCTAssertEqual(PermissionTask(row("Example", state: .missing, service: .screenRecording)).action, .openApp)
        XCTAssertFalse(PermissionService.screenRecording.supportsDrag)
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
    func testChecklistGroupsPermissionsByAppAndRetainsSelectedSuccess() {
        func permission(_ service: PermissionService, state: GrantState) -> InventoryRow {
            let source = row("Example", state: state, service: service)
            return InventoryRow(id: service.rawValue, appID: source.appID, name: source.name,
                permission: source.permission, subject: source.subject, status: source.status)
        }
        let snapshot = InventorySnapshot(rows: [row("Other", state: .denied),
            permission(.fullDiskAccess, state: .allowed), permission(.accessibility, state: .denied)], blockedDatabases: [])
        let groups = ReviewSelection(selectedID: PermissionService.fullDiskAccess.rawValue).appGroups(snapshot, showAll: false)
        XCTAssertEqual(groups.map(\.name), ["Example", "Other"])
        XCTAssertEqual(groups[0].rows.map { $0.permission.service }, [.accessibility, .fullDiskAccess])
        XCTAssertEqual(groups[0].rows.map { $0.status.state }, [.denied, .allowed])
        XCTAssertEqual(ReviewSelection().appGroups(snapshot, showAll: false)[0].rows.count, 1)
    }

    func testPermissionQueueFinishesCurrentPaneBeforeChangingPanes() {
        func target(_ name: String, _ service: PermissionService) -> InventoryRow {
            let source = row(name, state: .missing, service: service)
            return InventoryRow(id: name + ":" + service.rawValue, appID: name, name: name,
                permission: source.permission, subject: source.subject, status: source.status)
        }
        let snapshot = InventorySnapshot(rows: [target("Alpha", .microphone), target("Beta", .accessibility),
            target("Alpha", .accessibility)], blockedDatabases: [])
        var selection = ReviewSelection(grouping: .permission)
        selection.reconcile(snapshot)
        XCTAssertEqual(selection.selectedID, "Alpha:accessibility")
        selection.advance(snapshot)
        XCTAssertEqual(selection.selectedID, "Beta:accessibility")
        selection.advance(snapshot)
        XCTAssertEqual(selection.selectedID, "Alpha:microphone")
        XCTAssertEqual(selection.permissionGroups(snapshot, showAll: false).map(\.service), [.accessibility, .microphone])
    }

    func testDeferredRowsRemainVisibleButAreSkippedWhenAdvancing() {
        let snapshot = InventorySnapshot(rows: [row("A", state: .missing), row("B", state: .stale)], blockedDatabases: [])
        var selection = ReviewSelection(selectedID: "A", grouping: .permission, deferredIDs: ["B"])
        selection.advance(snapshot)
        XCTAssertEqual(selection.selectedID, "A")
        XCTAssertEqual(selection.visibleRows(snapshot, showAll: false).map(\.id), ["A", "B"])
        selection.deferredIDs.insert("A")
        selection.advance(snapshot)
        XCTAssertNil(selection.selectedID)
    }

    func testUncertainAndDeniedEvidenceDoNotPrescribeAddingOrGranting() {
        for service in PermissionService.allCases {
            let unknown = PermissionTask(row("Example", state: .unknown, service: service))
            XCTAssertFalse(unknown.steps.contains { $0.lowercased().contains("enable") || $0.lowercased().contains("approve") || $0.lowercased().contains("drag") })
            XCTAssertTrue(unknown.steps.contains { $0.contains("Evidence") })
            XCTAssertFalse(unknown.offersFileHandoff)
            let denied = PermissionTask(row("Example", state: .denied, service: service))
            XCTAssertFalse(denied.steps.contains { $0.contains("Drag") || $0.contains("Approve") })
            XCTAssertTrue(denied.steps.contains { $0.contains("existing entry") })
            XCTAssertFalse(denied.offersFileHandoff)
        }
    }

}
