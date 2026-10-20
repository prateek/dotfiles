import Foundation

/// `$XDG_CONFIG_HOME/dotfiles/tcc.json`, falling back to ~/.config when the variable is unset or
/// relative, as GUI launches without it in the launchd environment are.
public enum ManifestLocation {
    public static func url(environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        let base = environment["XDG_CONFIG_HOME"].flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0, isDirectory: true) : nil }
            ?? home.appendingPathComponent(".config", isDirectory: true)
        return base.appendingPathComponent("dotfiles/tcc.json")
    }
}

public enum ExitCode {
    public static let ok: Int32 = 0
    public static let deviations: Int32 = 2
    public static let inconclusive: Int32 = 3
    public static let usage: Int32 = 64
    public static let manifest: Int32 = 65
    public static let failure: Int32 = 70
    public static let noAccess: Int32 = 77
}

/// How TCC attributes this process. `helper` means it disclaimed the caller, so database access
/// reflects the helper's own grant rather than the terminal's.
public enum Responsibility: String, Sendable { case helper, inherited }

public struct DatabaseAccess: Sendable {
    public let path: String
    public let readable: Bool
    public init(path: String, readable: Bool) { self.path = path; self.readable = readable }
}

public protocol CLIHost {
    var version: String { get }
    var bundlePath: String? { get }
    var responsibility: Responsibility { get }
    func expectations(_ manifest: Manifest) -> [Expectation]
    func scan(_ manifest: Manifest) -> InventorySnapshot
    func probeDatabases() -> [DatabaseAccess]
    func openURL(_ url: URL) -> Bool
    func openGUI() -> Bool
}

public struct CLIResult: Equatable, Error {
    public let status: Int32
    public let stdout: String
    public let stderr: String
}

public enum CLI {
    public static let name = "dotfiles-permissions"
    /// Commands that read TCC and therefore must run under the helper's own responsibility.
    public static let tccCommands: Set<String> = ["doctor", "audit", "grants"]
    public static let commands: Set<String> = ["doctor", "audit", "grants", "apps", "manifest", "settings", "gui", "help"]
    public static let valueOptions: Set<String> = ["--manifest", "--app"]

    /// Positional words with option values removed, so `--manifest PATH audit` yields `["audit"]`.
    public static func commandWords(_ arguments: [String]) -> [String] {
        var words: [String] = []
        var index = 0
        while index < arguments.count {
            if valueOptions.contains(arguments[index]) { index += 1 }
            else if !arguments[index].hasPrefix("-") { words.append(arguments[index]) }
            index += 1
        }
        return words
    }

    public static func wantsHelp(_ arguments: [String]) -> Bool {
        arguments.contains { ["-h", "--help", "--version"].contains($0) } || commandWords(arguments).first == "help"
    }

    public static let help = """
    Usage: \(name) [--json] [--manifest PATH] <command>

    Compare expected macOS privacy permissions with read-only TCC records. Never changes grants.

    Commands:
      doctor                  Check the helper, manifest, and the helper's own TCC database access
      audit                   Report expected grants that need attention (quiet when everything matches)
      grants list [--app ID]  List every expected grant and its recorded state
      apps list               List manifest apps and the installed copy each resolves to
      manifest path           Print the manifest path
      manifest validate       Validate the manifest
      settings open SERVICE   Open System Settings → Privacy & Security for one service
      gui                     Open the Dotfiles Permissions window for a guided review

    Options:
      --json             Print stable JSON on stdout; diagnostics go to stderr
      --manifest PATH    Manifest to read (default: $XDG_CONFIG_HOME/dotfiles/tcc.json, else ~/.config/dotfiles/tcc.json)
      -h, --help         Show this help
      --version          Print the version

    Services: \(PermissionService.allCases.map(\.rawValue).joined(separator: ", "))

    Exit status: 0 ok; 2 audit found deviations; 3 audit evidence inconclusive; 64 usage error;
    65 invalid or unreadable manifest; 70 other failure; 77 the helper cannot read the TCC databases.

    """

    public static func run(_ arguments: [String], host: CLIHost,
                           environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: URL = FileManager.default.homeDirectoryForCurrentUser) -> CLIResult {
        var json = false
        var manifestPath: String?
        var app: String?
        var words: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json": json = true
            case "-h", "--help", "help": return CLIResult(status: ExitCode.ok, stdout: help, stderr: "")
            case "--version": return CLIResult(status: ExitCode.ok, stdout: json ? encode(["version": host.version]) : "\(host.version)\n", stderr: "")
            case "--manifest", "--app":
                guard index + 1 < arguments.count else { return usage("\(argument) needs a value", json: json) }
                index += 1
                if argument == "--manifest" { manifestPath = arguments[index] } else { app = arguments[index] }
            default:
                if argument.hasPrefix("-") { return usage("Unknown option: \(argument)", json: json) }
                words.append(argument)
            }
            index += 1
        }
        let manifestURL = manifestPath.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
            ?? ManifestLocation.url(environment: environment, home: home)
        let context = Context(host: host, json: json, manifestURL: manifestURL)
        if app != nil && words.prefix(2) != ["grants", "list"] { return usage("--app applies only to grants list", json: json) }
        switch words {
        case []:
            return json ? CLIResult(status: ExitCode.usage, stdout: error("usage", "Missing command. Run \(name) --help."), stderr: "")
                        : CLIResult(status: ExitCode.usage, stdout: "", stderr: help)
        case ["doctor"]: return context.doctor()
        case ["audit"]: return context.audit()
        case ["grants", "list"]: return context.grants(app: app)
        case ["apps", "list"]: return context.apps()
        case ["manifest", "path"]:
            return CLIResult(status: ExitCode.ok, stdout: json ? encode(["path": manifestURL.path]) : "\(manifestURL.path)\n", stderr: "")
        case ["manifest", "validate"]: return context.validate()
        case ["gui"]:
            guard host.openGUI() else { return context.fail(ExitCode.failure, "gui_unavailable", "Cannot open the Dotfiles Permissions app. Install it with chezmoi apply or scripts/macos/install-tcc-onboarding.") }
            return CLIResult(status: ExitCode.ok, stdout: json ? encode(["opened": true]) : "", stderr: "")
        default:
            if words.count == 3, words[0] == "settings", words[1] == "open" { return context.openSettings(words[2]) }
            return usage("Unknown command: \(words.joined(separator: " "))", json: json)
        }
    }

    static func usage(_ message: String, json: Bool) -> CLIResult {
        json ? CLIResult(status: ExitCode.usage, stdout: error("usage", message), stderr: "")
             : CLIResult(status: ExitCode.usage, stdout: "", stderr: "\(name): \(message)\nRun \(name) --help.\n")
    }

    static func error(_ code: String, _ message: String, extra: [String: Any] = [:]) -> String {
        var body: [String: Any] = ["code": code, "message": message]
        body.merge(extra) { _, new in new }
        return encode(["error": body])
    }

    static func encode(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return "{}\n" }
        return text + "\n"
    }

    static func accessHelp(bundlePath: String?) -> String {
        let app = bundlePath ?? "Dotfiles Permissions.app"
        return """
        Grant Full Disk Access to \(app): run `\(name) gui` and drag its tile into Privacy & Security → Full Disk Access, \
        or run `\(name) settings open fullDiskAccess` and add the app. If it is already listed, the grant belongs to an \
        earlier build: remove it with −, add the app again, and rerun.
        """
    }

    struct Context {
        let host: CLIHost
        let json: Bool
        let manifestURL: URL

        func fail(_ status: Int32, _ code: String, _ message: String, extra: [String: Any] = [:]) -> CLIResult {
            json ? CLIResult(status: status, stdout: CLI.error(code, message, extra: extra), stderr: "")
                 : CLIResult(status: status, stdout: "", stderr: "\(CLI.name): \(message)\n")
        }

        func load() -> Result<Manifest, CLIResult> {
            do { return .success(try Manifest.load(manifestURL)) }
            catch { return .failure(fail(ExitCode.manifest, "manifest_invalid", manifestProblem(error))) }
        }

        func manifestProblem(_ error: Error) -> String {
            "Cannot read manifest \(manifestURL.path): \(error.localizedDescription)"
        }

        func blocked(_ paths: [String]) -> CLIResult {
            fail(ExitCode.noAccess, "tcc_unreadable",
                 "The helper cannot read \(paths.joined(separator: " or ")). \(CLI.accessHelp(bundlePath: host.bundlePath))",
                 extra: ["databases": paths, "responsibility": host.responsibility.rawValue])
        }

        func doctor() -> CLIResult {
            let databases = host.probeDatabases()
            var manifest: [String: Any] = ["path": manifestURL.path, "exists": FileManager.default.fileExists(atPath: manifestURL.path)]
            var manifestOK = false
            do {
                manifest["apps"] = try Manifest.load(manifestURL).apps.count
                manifestOK = true
            } catch { manifest["error"] = manifestProblem(error) }
            manifest["valid"] = manifestOK
            let unreadable = databases.filter { !$0.readable }.map(\.path)
            var next: [String] = []
            if !manifestOK { next.append("Render the manifest with chezmoi apply, or pass --manifest PATH.") }
            if !unreadable.isEmpty { next.append(CLI.accessHelp(bundlePath: host.bundlePath)) }
            if host.responsibility == .inherited { next.append("Database access reflects the calling process, not the helper. Run the installed helper.") }
            let status = !manifestOK ? ExitCode.manifest : !unreadable.isEmpty ? ExitCode.noAccess : ExitCode.ok
            if json {
                return CLIResult(status: status, stdout: CLI.encode([
                    "ok": status == ExitCode.ok, "version": host.version, "bundle": host.bundlePath ?? NSNull(),
                    "responsibility": host.responsibility.rawValue, "manifest": manifest,
                    "databases": databases.map { ["path": $0.path, "readable": $0.readable] }, "next_steps": next,
                ]), stderr: "")
            }
            var lines = ["\(CLI.name) \(host.version)",
                         "helper:         \(host.bundlePath ?? "not running from an app bundle")",
                         "responsibility: \(host.responsibility.rawValue)",
                         "manifest:       \(manifestOK ? "ok" : "invalid") \(manifestURL.path)"]
            if let error = manifest["error"] as? String { lines.append("                \(error)") }
            for database in databases { lines.append("database:       \(database.readable ? "readable" : "unreadable") \(database.path)") }
            lines += next.map { "next: \($0)" }
            return CLIResult(status: status, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
        }

        func audit() -> CLIResult {
            let manifest: Manifest
            switch load() { case .success(let loaded): manifest = loaded; case .failure(let result): return result }
            let snapshot = host.scan(manifest)
            if !snapshot.blockedDatabases.isEmpty { return blocked(snapshot.blockedDatabases) }
            let attention = snapshot.rows.filter { $0.status.state.needsAttention }
            let status = attention.contains { $0.status.state == .unknown } ? ExitCode.inconclusive
                : attention.isEmpty ? ExitCode.ok : ExitCode.deviations
            if json {
                return CLIResult(status: status, stdout: CLI.encode([
                    "manifest": manifestURL.path, "responsibility": host.responsibility.rawValue,
                    "summary": summary(snapshot.rows), "grants": attention.map(row), "gui_command": "\(CLI.name) gui",
                ]), stderr: "")
            }
            guard status != ExitCode.ok else { return CLIResult(status: status, stdout: "", stderr: "") }
            var lines = ["Permission audit (recorded TCC state):"]
            lines += attention.map { "  \($0.name) / \($0.permission.service.title): \($0.status.state.rawValue) — \($0.status.detail)" }
            lines.append("Details: \(CLI.name) grants list. Guided review (optional): \(CLI.name) gui")
            return CLIResult(status: status, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
        }

        func grants(app: String?) -> CLIResult {
            let manifest: Manifest
            switch load() { case .success(let loaded): manifest = loaded; case .failure(let result): return result }
            if let app, manifest.apps[app] == nil { return fail(ExitCode.usage, "unknown_app", "No app \(app) in \(manifestURL.path).") }
            let snapshot = host.scan(manifest)
            if !snapshot.blockedDatabases.isEmpty { return blocked(snapshot.blockedDatabases) }
            let rows = snapshot.rows.filter { app == nil || $0.appID == app }
            if json { return CLIResult(status: ExitCode.ok, stdout: CLI.encode(["manifest": manifestURL.path, "summary": summary(rows), "grants": rows.map(row)]), stderr: "") }
            let lines = rows.map { "\($0.appID)\t\($0.permission.service.rawValue)\t\($0.status.state.rawValue)\t\($0.status.detail)" }
            return CLIResult(status: ExitCode.ok, stdout: lines.map { $0 + "\n" }.joined(), stderr: "")
        }

        func apps() -> CLIResult {
            let manifest: Manifest
            switch load() { case .success(let loaded): manifest = loaded; case .failure(let result): return result }
            let entries: [[String: Any]] = host.expectations(manifest).map { expectation in
                var entry: [String: Any] = ["id": expectation.id, "name": expectation.app.name, "bundle_id": expectation.app.bundleID,
                                            "permissions": expectation.app.permissions.map(\.service.rawValue)]
                switch expectation.resolution {
                case .found(let subject): entry["installed"] = "found"; entry["path"] = subject.codeURL.path
                case .missing(let reason): entry["installed"] = "missing"; entry["detail"] = reason
                case .ambiguous(let reason): entry["installed"] = "ambiguous"; entry["detail"] = reason
                }
                return entry
            }
            if json { return CLIResult(status: ExitCode.ok, stdout: CLI.encode(["manifest": manifestURL.path, "apps": entries]), stderr: "") }
            let lines = entries.map { entry in
                "\(entry["id"]!)\t\(entry["installed"]!)\t\((entry["path"] ?? entry["detail"])!)"
            }
            return CLIResult(status: ExitCode.ok, stdout: lines.map { $0 + "\n" }.joined(), stderr: "")
        }

        func validate() -> CLIResult {
            switch load() {
            case .success(let manifest):
                return CLIResult(status: ExitCode.ok, stdout: json ? CLI.encode(["path": manifestURL.path, "valid": true, "apps": manifest.apps.count]) : "", stderr: "")
            case .failure(let result): return result
            }
        }

        func openSettings(_ name: String) -> CLIResult {
            guard let service = PermissionService(rawValue: name) else {
                return CLI.usage("Unknown service \(name). Use one of: \(PermissionService.allCases.map(\.rawValue).joined(separator: ", "))", json: json)
            }
            guard host.openURL(service.settingsURL) else {
                return fail(ExitCode.failure, "settings_unavailable", "Cannot open System Settings. Open Privacy & Security → \(service.title) manually.")
            }
            return CLIResult(status: ExitCode.ok, stdout: json ? CLI.encode(["opened": service.settingsURL.absoluteString]) : "", stderr: "")
        }

        func summary(_ rows: [InventoryRow]) -> [String: Int] {
            Dictionary(rows.map { ($0.status.state.rawValue, 1) }, uniquingKeysWith: +)
        }

        func row(_ row: InventoryRow) -> [String: Any] {
            var entry: [String: Any] = ["app": row.appID, "name": row.name, "service": row.permission.service.rawValue,
                                        "reason": row.permission.reason, "state": row.status.state.rawValue, "detail": row.status.detail]
            if let subject = row.subject { entry["path"] = subject.codeURL.path; entry["client"] = subject.client }
            return entry
        }
    }
}
