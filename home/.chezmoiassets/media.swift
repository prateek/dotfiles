// media — control whatever app currently owns the system "now playing" session,
// via the private MediaRemote framework (the same mechanism Ghost Pepper uses to
// pause media on dictation start).
//
// Usage:  media [toggle|play|pause|is-playing|check]   (default: toggle)
// Exit:   0 ok (is-playing: playing) · 1 bad usage · 2 MediaRemote unavailable
//         · 3 is-playing: not playing
//
// MediaRemote's read APIs are restricted on macOS 15.4+, so `is-playing` may
// report unavailable even though the send commands still dispatch. `check`
// resolves the send symbol without sending, for diagnostics.
import Foundation

let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
let handle = dlopen(frameworkPath, RTLD_LAZY)

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data("media: \(message)\n".utf8))
    exit(code)
}

func symbol(_ name: String) -> UnsafeMutableRawPointer? {
    guard let handle else { return nil }
    return dlsym(handle, name)
}

// MRMediaRemoteSendCommand(command, userInfo) -> Bool
func resolveSendCommand() -> (@convention(c) (Int, CFDictionary?) -> Bool)? {
    guard let s = symbol("MRMediaRemoteSendCommand") else { return nil }
    return unsafeBitCast(s, to: (@convention(c) (Int, CFDictionary?) -> Bool).self)
}

// MRMediaRemoteGetNowPlayingApplicationIsPlaying(queue, ^(Bool)) -> void
// Returns true=playing, false=not playing, nil=symbol missing or timed out.
func nowPlayingIsPlaying() -> Bool? {
    guard let s = symbol("MRMediaRemoteGetNowPlayingApplicationIsPlaying") else { return nil }
    typealias Fn = @convention(c) (DispatchQueue, @escaping @convention(block) (Bool) -> Void) -> Void
    let fn = unsafeBitCast(s, to: Fn.self)
    let sem = DispatchSemaphore(value: 0)
    var playing = false
    fn(DispatchQueue.global()) { value in playing = value; sem.signal() }
    return sem.wait(timeout: .now() + 2.0) == .timedOut ? nil : playing
}

let command: Int
switch CommandLine.arguments.dropFirst().first ?? "toggle" {
case "play":                command = 0
case "pause":               command = 1
case "toggle", "playpause": command = 2
case "is-playing":
    switch nowPlayingIsPlaying() {
    case .some(true):  exit(0)
    case .some(false): exit(3)
    case .none:        die("now-playing state unavailable", 2)
    }
case "check":
    resolveSendCommand() != nil ? exit(0) : die("MediaRemote unavailable", 2)
case "-h", "--help":
    print("usage: media [toggle|play|pause|is-playing|check]   (default: toggle)")
    exit(0)
default:
    die("unknown command: \(CommandLine.arguments.dropFirst().first ?? "") (use toggle|play|pause|is-playing|check)", 1)
}

guard let send = resolveSendCommand() else { die("MediaRemote unavailable", 2) }
_ = send(command, nil)
