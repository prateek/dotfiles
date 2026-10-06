import XCTest
@testable import PermissionsApp

final class LaunchReviewTests: XCTestCase {
    func testReconcileRequestCarriesIntentWithoutProcessArguments() throws {
        let url = try XCTUnwrap(URL(string: "dotfiles-permissions://reconcile?manifest=%2Ftmp%2FSpace%20%26%20%E2%9C%93%2Fregistry%3F%23%2B.json"))
        XCTAssertEqual(try XCTUnwrap(ReconcileRequest(url: url)).manifestURL.path, "/tmp/Space & ✓/registry?#+.json")
        for invalid in ["https://reconcile?manifest=/tmp/a.json", "dotfiles-permissions://review?manifest=/tmp/a.json",
                        "dotfiles-permissions://reconcile?manifest=relative.json", "dotfiles-permissions://reconcile?manifest=/a&manifest=/b",
                        "dotfiles-permissions://reconcile?manifest=/a&other=b", "dotfiles-permissions://reconcile?manifest=/a#fragment"] {
            XCTAssertNil(ReconcileRequest(url: try XCTUnwrap(URL(string: invalid))))
        }
    }

    func testColdReconcileDoesNotPresentMatchingInventory() {
        var launch = LaunchReview()
        XCTAssertEqual(launch.request(reconcile: true), .none)
        XCTAssertEqual(launch.scanFinished(needsAttention: false, windowIsVisible: false), .terminate)
    }

    func testRepeatReconcilePreservesClosedSessionAndOnlyPresentsWhenNeeded() {
        var launch = LaunchReview()
        XCTAssertEqual(launch.request(reconcile: false), .show)
        XCTAssertEqual(launch.scanFinished(needsAttention: true, windowIsVisible: true), .none)
        XCTAssertEqual(launch.request(reconcile: true), .none)
        XCTAssertEqual(launch.scanFinished(needsAttention: false, windowIsVisible: false), .none)
        XCTAssertEqual(launch.request(reconcile: true), .none)
        XCTAssertEqual(launch.scanFinished(needsAttention: true, windowIsVisible: false), .show)
    }

    func testReconcileDoesNotActivateAnAlreadyVisibleReview() {
        var launch = LaunchReview()
        _ = launch.request(reconcile: false)
        _ = launch.scanFinished(needsAttention: true, windowIsVisible: true)
        XCTAssertEqual(launch.request(reconcile: true), .none)
        XCTAssertEqual(launch.scanFinished(needsAttention: true, windowIsVisible: true), .none)
    }

    func testManualOpenAlwaysPresentsAndDoesNotInheritReconcileMode() {
        var launch = LaunchReview()
        _ = launch.request(reconcile: true)
        _ = launch.scanFinished(needsAttention: true, windowIsVisible: false)
        XCTAssertEqual(launch.request(reconcile: false), .show)
        XCTAssertEqual(launch.scanFinished(needsAttention: false, windowIsVisible: true), .none)
        XCTAssertEqual(launch.scanFinished(needsAttention: true, windowIsVisible: false), .none)
    }
}
