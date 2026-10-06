import XCTest
@testable import PermissionsApp
@testable import PermissionsCore

final class ReviewModelTests: XCTestCase {
    @MainActor
    func testSuccessfulDocumentOpenSurvivesNextLaunchAndInvalidOpen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "permissions-registry-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("custom.json")
        try Data(#"{"version":1,"apps":{}}"#.utf8).write(to: url)
        let model = PermissionsModel(preferences: preferences)
        let loaded = expectation(description: "Document loaded")
        model.onChange = { loaded.fulfill() }
        model.load(url)
        await fulfillment(of: [loaded], timeout: 5)
        model.onChange = nil
        XCTAssertEqual(preferences.string(forKey: "lastManifestPath"), url.path)
        model.load(directory.appendingPathComponent("absent.json"))
        XCTAssertEqual(preferences.string(forKey: "lastManifestPath"), url.path)
        XCTAssertEqual(PermissionsModel.launchManifest(home: directory, preferences: preferences), url)
        let managed = directory.appendingPathComponent(".config/dotfiles/tcc.json")
        try FileManager.default.createDirectory(at: managed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version":1,"apps":{}}"#.utf8).write(to: managed)
        XCTAssertEqual(PermissionsModel.launchManifest(home: directory, preferences: preferences), managed)
        try FileManager.default.removeItem(at: managed)
        try FileManager.default.removeItem(at: url)
        XCTAssertEqual(PermissionsModel.launchManifest(home: directory, preferences: preferences), managed)
    }

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
    @MainActor
    func testDeferringLastUnresolvedPermissionPausesRatherThanCompletes() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .allowed), row("B", state: .missing)], blockedDatabases: []))
        model.deferPermission("B")
        XCTAssertTrue(model.isPaused)
        XCTAssertFalse(model.isComplete)
        XCTAssertEqual(model.remainingCount, 1)
        XCTAssertEqual(model.deferredCount, 1)
        XCTAssertEqual(model.visibleRows.map(\.id), ["B"])
        XCTAssertEqual(model.snapshot?.rows.map(\.status.state), [.allowed, .missing])
        model.resumeDeferred()
        XCTAssertEqual(model.selectedID, "B")
        XCTAssertFalse(model.isPaused)
    }

    @MainActor
    func testFinalMatchingTaskStaysSelectedUntilExplicitAdvance() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .missing)], blockedDatabases: []))
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .allowed)], blockedDatabases: []))
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.selectedID, "A")
        XCTAssertFalse(model.showSummary)
        XCTAssertEqual(model.visibleRows.map(\.id), ["A"])
        model.nextPermission()
        XCTAssertNil(model.selectedID)
    }

    @MainActor
    func testExternalMatchingGrantClearsDeferralAndLaterRevocationNeedsReview() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .missing)], blockedDatabases: []))
        model.deferPermission("A")
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .allowed)], blockedDatabases: []))
        XCTAssertTrue(model.deferredIDs.isEmpty)
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .denied)], blockedDatabases: []))
        XCTAssertEqual(model.pendingCount, 1)
        XCTAssertFalse(model.isPaused)
    }

    @MainActor
    func testPresentationChangePreservesSelectedIdentityAndEvidence() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .stale), row("B", state: .missing)], blockedDatabases: []))
        model.select("B")
        model.toggleEvidence("B")
        model.presentation = .apps
        XCTAssertEqual(model.selectedID, "B")
        XCTAssertTrue(model.evidenceOpen.contains("B"))
        model.presentation = .shelf
        XCTAssertEqual(model.selectedID, "B")
        XCTAssertTrue(model.evidenceOpen.contains("B"))
    }

    @MainActor
    func testMissingOrAmbiguousTargetsDoNotClaimRecordedCompletion() async {
        let model = PermissionsModel(openSettingsURL: { _ in true })
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .notInstalled)], blockedDatabases: []))
        XCTAssertFalse(model.isComplete)
        model.updateInventory(InventorySnapshot(rows: [row("A", state: .unknown)], blockedDatabases: []))
        XCTAssertFalse(model.isComplete)
    }

    @MainActor
    func testPresentationPreferencesPersistWithoutSessionDeferral() async throws {
        let suite = "permissions-tests-" + UUID().uuidString
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let model = PermissionsModel(preferences: preferences)
        model.presentation = .shelf
        model.largeText = true
        model.menuBarEnabled = true
        let next = PermissionsModel(preferences: preferences)
        XCTAssertEqual(next.presentation, .shelf)
        XCTAssertTrue(next.largeText)
        XCTAssertTrue(next.menuBarEnabled)
        XCTAssertTrue(next.deferredIDs.isEmpty)
    }

    @MainActor
    func testReopeningSameRegistryRetainsReviewSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("registry.json")
        func registry(reason: String) throws -> Data {
            let apps = Dictionary(uniqueKeysWithValues: ["A", "B"].map { id in
                (id, ["name": id, "bundle_id": "com.example.fixture.\(directory.lastPathComponent).\(id)",
                      "path": directory.path, "sources": [],
                      "permissions": [["service": "accessibility", "reason": reason]]] as [String: Any])
            })
            return try JSONSerialization.data(withJSONObject: ["version": 1, "apps": apps])
        }
        try registry(reason: "Original reason").write(to: url)
        let model = PermissionsModel(openSettingsURL: { _ in true })
        let loaded = expectation(description: "Ambiguous fixtures loaded without reading TCC")
        model.onChange = { loaded.fulfill() }
        model.load(url)
        await fulfillment(of: [loaded], timeout: 5)
        model.onChange = nil
        XCTAssertNil(model.error)
        XCTAssertEqual(model.snapshot?.rows.map(\.status.state), [.unknown, .unknown])
        model.deferPermission("B:accessibility")
        model.toggleEvidence("A:accessibility")
        try registry(reason: "Updated reason").write(to: url)
        let refreshed = expectation(description: "Same registry reloaded")
        model.onChange = { refreshed.fulfill() }
        model.load(url)
        await fulfillment(of: [refreshed], timeout: 5)
        XCTAssertEqual(model.selectedID, "A:accessibility")
        XCTAssertEqual(model.deferredIDs, ["B:accessibility"])
        XCTAssertEqual(model.evidenceOpen, ["A:accessibility"])
        XCTAssertEqual(model.selectedRow?.permission.reason, "Updated reason")
    }

}
