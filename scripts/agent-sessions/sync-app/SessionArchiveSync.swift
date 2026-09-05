import AppKit
import Darwin

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data("Session Archive Sync: \(message)\n".utf8))
    exit(code)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.isEmpty || arguments == ["--check-access"] else {
    fail("usage: SessionArchiveSync [--check-access]", code: 64)
}

func runSync() -> Never {
    let files = FileManager.default
    let home = files.homeDirectoryForCurrentUser
    let repo = home.appendingPathComponent("code/github.com/prateek/wiki-agent-sessions")
    let script = repo.appendingPathComponent(".agents/skills/session-sync/scripts/sync-sessions")
    let checking = arguments == ["--check-access"]

    do {
        _ = try files.contentsOfDirectory(atPath: repo.path)
        guard let uv = ["/opt/homebrew/bin/uv", "/usr/local/bin/uv"].first(where: files.isExecutableFile) else {
            fail("uv is not installed in Homebrew's bin directory.", code: 69)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: uv)
        process.arguments = ["run", "--script", script.path]
        if checking {
            process.arguments! += ["--print-session-sources", repo.path, ""]
        }
        process.currentDirectoryURL = home
        var environment = [
            "HOME": home.path,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "USER": NSUserName(),
            "LOGNAME": NSUserName(),
        ]
        for key in ["SSH_AUTH_SOCK", "LANG", "LC_CTYPE"] {
            environment[key] = ProcessInfo.processInfo.environment[key]
        }
        process.environment = environment
        process.standardOutput = checking ? FileHandle.nullDevice : FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        if checking && process.terminationStatus == 0 {
            FileHandle.standardOutput.write(Data("Archive access verified through uv and Python.\n".utf8))
        }
        exit(process.terminationStatus)
    } catch {
        fail("\(error.localizedDescription) Check the SSD mount and this app's Files & Folders permission.", code: 74)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.global(qos: .utility).async {
            runSync()
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
