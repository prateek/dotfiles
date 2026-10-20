import AppKit
import Darwin
import PermissionsCore

/// Private libsystem call (also used by Chromium). Resolved at run time so its absence fails
/// only the TCC commands, not the whole binary.
private typealias SetDisclaim = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32
private let setDisclaim: SetDisclaim? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim")
    .map { unsafeBitCast($0, to: SetDisclaim.self) }

enum CLIEntry {
    static let disclaimedKey = "DOTFILES_PERMISSIONS_DISCLAIMED"

    /// The `dotfiles-permissions` symlink is always the command line. The bundle executable is the
    /// command line only when given a CLI command or option, so AppKit launch arguments
    /// (`-AppleLanguages`, `-NSDocumentRevisionsDebugMode`) still open the GUI.
    static func isCommandLine(_ arguments: [String]) -> Bool {
        let invokedAs = URL(fileURLWithPath: arguments.first ?? "").lastPathComponent
        let rest = Array(arguments.dropFirst())
        guard invokedAs == "DotfilesPermissions" else { return true }
        if let word = CLI.commandWords(rest).first, CLI.commands.contains(word) { return true }
        return rest.contains { ["--json", "-h", "--help", "--version"].contains($0) || CLI.valueOptions.contains($0) }
    }

    static func run(_ arguments: [String]) -> Never {
        let rest = Array(arguments.dropFirst())
        // The marker carries the parent's pid, so an exported variable cannot fake a disclaimed run.
        let disclaimed = ProcessInfo.processInfo.environment[disclaimedKey] == String(getppid())
        if !disclaimed, let command = CLI.commandWords(rest).first, CLI.tccCommands.contains(command), !CLI.wantsHelp(rest) {
            exit(respawnDisclaimed(arguments))
        }
        let result = CLI.run(rest, host: NativeCLIHost(responsibility: disclaimed ? .helper : .inherited))
        FileHandle.standardOutput.write(Data(result.stdout.utf8))
        FileHandle.standardError.write(Data(result.stderr.utf8))
        exit(result.status)
    }

    /// Re-executes this binary as its own responsible process. TCC then evaluates the helper's grant
    /// instead of inheriting the terminal's, which is the access the GUI and apply depend on.
    private static func respawnDisclaimed(_ arguments: [String]) -> Int32 {
        guard let executable = executablePath() else {
            FileHandle.standardError.write(Data("\(CLI.name): Cannot locate the helper executable.\n".utf8))
            return ExitCode.failure
        }
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        guard let setDisclaim, setDisclaim(&attributes, 1) == 0 else {
            FileHandle.standardError.write(Data("\(CLI.name): Cannot run the helper under its own TCC identity.\n".utf8))
            return ExitCode.failure
        }
        var environment = ProcessInfo.processInfo.environment
        environment[disclaimedKey] = String(getpid())
        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }
        var pid: pid_t = 0
        let spawned = posix_spawn(&pid, executable, nil, &attributes, argv, envp)
        guard spawned == 0 else {
            FileHandle.standardError.write(Data("\(CLI.name): Cannot start the helper (\(String(cString: strerror(spawned)))).\n".utf8))
            return ExitCode.failure
        }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
        if status & 0x7f == 0 { return (status >> 8) & 0xff }
        return 128 + (status & 0x7f)
    }

    static func executablePath() -> String? {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath().path
    }

    static var bundleURL: URL? {
        guard let executable = executablePath() else { return nil }
        let bundle = URL(fileURLWithPath: executable).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return bundle.pathExtension == "app" ? bundle : nil
    }
}

struct NativeCLIHost: CLIHost {
    let responsibility: Responsibility

    var version: String {
        let info = CLIEntry.bundleURL.flatMap { Bundle(url: $0)?.infoDictionary }
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let cli = info?["DotfilesPermissionsCLIVersion"].map { "\($0)" } ?? "?"
        return "\(short) (cli \(cli))"
    }

    var bundlePath: String? { CLIEntry.bundleURL?.path }

    func expectations(_ manifest: Manifest) -> [Expectation] { NativeInventory.expectations(manifest) }

    func scan(_ manifest: Manifest) -> InventorySnapshot {
        Inventory.scan(NativeInventory.expectations(manifest), databases: NativeInventory.databases, requireAccess: true)
    }

    func probeDatabases() -> [DatabaseAccess] {
        NativeInventory.databases.map { DatabaseAccess(path: $0.path, readable: !TCCSnapshot(url: $0).accessBlocked) }
    }

    func openURL(_ url: URL) -> Bool { NSWorkspace.shared.open(url) }

    func openGUI() -> Bool {
        guard let bundle = CLIEntry.bundleURL else { return false }
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", bundle.path]
        guard (try? open.run()) != nil else { return false }
        open.waitUntilExit()
        return open.terminationStatus == 0
    }
}
