import Foundation

struct ReconcileRequest {
    static let scheme = "dotfiles-permissions"
    let manifestURL: URL

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == Self.scheme, parts.host == "reconcile",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.path.isEmpty, parts.fragment == nil,
              let items = parts.queryItems, items.count == 1,
              items[0].name == "manifest", let path = items[0].value,
              path.hasPrefix("/"), !path.contains("\0") else { return nil }
        manifestURL = URL(fileURLWithPath: path).standardizedFileURL
    }
}

struct LaunchReview {
    enum Effect: Equatable { case none, show, terminate }
    private var awaitingScan = false
    private var reconcile = false
    var hasPresentedWindow = false

    mutating func request(reconcile: Bool) -> Effect {
        self.reconcile = reconcile
        awaitingScan = true
        if reconcile { return .none }
        hasPresentedWindow = true
        return .show
    }

    mutating func scanFinished(needsAttention: Bool, windowIsVisible: Bool) -> Effect {
        guard awaitingScan else { return .none }
        awaitingScan = false
        if reconcile && needsAttention && !windowIsVisible {
            hasPresentedWindow = true
            return .show
        }
        return hasPresentedWindow ? .none : .terminate
    }
}
