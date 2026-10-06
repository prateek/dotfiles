import Foundation

public enum PermissionService: String, Codable, CaseIterable, Sendable {
    case accessibility, inputMonitoring, fullDiskAccess, screenRecording, microphone, camera

    public var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .fullDiskAccess: return "Full Disk Access"
        case .screenRecording: return "Screen Recording"
        case .microphone: return "Microphone"
        case .camera: return "Camera"
        }
    }

    public var tccName: String {
        switch self {
        case .accessibility: return "kTCCServiceAccessibility"
        case .inputMonitoring: return "kTCCServiceListenEvent"
        case .fullDiskAccess: return "kTCCServiceSystemPolicyAllFiles"
        case .screenRecording: return "kTCCServiceScreenCapture"
        case .microphone: return "kTCCServiceMicrophone"
        case .camera: return "kTCCServiceCamera"
        }
    }

    public var settingsURL: URL {
        let pane: String
        switch self {
        case .accessibility: pane = "Accessibility"
        case .inputMonitoring: pane = "ListenEvent"
        case .fullDiskAccess: pane = "AllFiles"
        case .screenRecording: pane = "ScreenCapture"
        case .microphone: pane = "Microphone"
        case .camera: pane = "Camera"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)")!
    }

    public var supportsDrag: Bool {
        [.accessibility, .inputMonitoring, .fullDiskAccess].contains(self)
    }

    public var requiresAppRequest: Bool { self == .microphone || self == .camera || self == .screenRecording }
}

public struct Permission: Codable, Sendable {
    public let service: PermissionService
    public let reason: String
}

public struct AppDeclaration: Codable, Sendable {
    public let name: String
    public let bundleID: String
    public let path: String?
    public let helperPath: String?
    public let permissions: [Permission]
    public let sources: [String]

    enum CodingKeys: String, CodingKey {
        case name, permissions, path, sources
        case bundleID = "bundle_id", helperPath = "helper_path"
    }
}

public struct Manifest: Codable, Sendable {
    public let version: Int
    public let apps: [String: AppDeclaration]

    public static func load(_ url: URL) throws -> Manifest {
        try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> Manifest {
        let raw = try JSONSerialization.jsonObject(with: data)
        try checkKeys(raw, allowed: ["version", "apps"], context: "manifest")
        if let root = raw as? [String: Any], let apps = root["apps"] as? [String: Any] {
            for (id, value) in apps {
                try checkKeys(value, allowed: ["name", "bundle_id", "path", "helper_path", "permissions", "sources"], context: id)
                if let app = value as? [String: Any], let permissions = app["permissions"] as? [Any] {
                    for permission in permissions {
                        try checkKeys(permission, allowed: ["service", "reason"], context: "\(id) permission")
                    }
                }
            }
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.version == 1 else { throw ManifestError("Unsupported manifest version: \(manifest.version)") }
        for (id, app) in manifest.apps {
            guard !id.isEmpty, !app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !app.bundleID.isEmpty, !app.bundleID.contains(where: { $0.isWhitespace }),
                  !app.permissions.isEmpty else { throw ManifestError("\(id): name, bundle_id and permissions are required") }
            if let path = app.path, !path.hasPrefix("/") && !path.hasPrefix("~/") {
                throw ManifestError("\(id): path must be absolute or start with ~/")
            }
            if let helper = app.helperPath {
                guard helper.hasPrefix("Contents/"), !helper.split(separator: "/").contains("..") else {
                    throw ManifestError("\(id): helper_path must stay inside Contents/")
                }
            }
            guard Set(app.permissions.map(\.service)).count == app.permissions.count else {
                throw ManifestError("\(id): duplicate permission")
            }
            guard app.permissions.allSatisfy({ !$0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw ManifestError("\(id): each permission needs a reason")
            }
        }
        return manifest
    }

    private static func checkKeys(_ object: Any, allowed: Set<String>, context: String) throws {
        guard let dictionary = object as? [String: Any] else { throw ManifestError("\(context): expected an object") }
        let unknown = Set(dictionary.keys).subtracting(allowed)
        guard unknown.isEmpty else { throw ManifestError("\(context): unknown keys: \(unknown.sorted().joined(separator: ", "))") }
    }
}

public struct ManifestError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
