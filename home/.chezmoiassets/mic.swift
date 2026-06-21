#!/usr/bin/env swift
//
// mic — show or change the mute state of a CoreAudio input device.
//
// `mic` with no arguments lists every input device and its mute state, marking
// the current default with "*". The change verbs act on the default input
// device (or a -d target), following whatever is currently selected.
//
// Usage:
//   mic [status]                List all input devices and their mute state.
//   mic mute | unmute | toggle  Change the default input device's mute state.
//   mic -d "Shure MV7+" [cmd]   Target a named device (substring match).
//   mic -f, --format text|json  Output format (default: text).
//   mic -h, --help              Show this help.
//
// Environment:
//   MIC_DEVICE   Device name to target (overridden by -d/--device).
//
// Output:  Tab-separated columns on stdout: <state> <default?> <device>, where
//          the default device is marked "*" and the rest "-". `--format json`
//          emits one object (single device) or an array (full list). Failures
//          go to stderr with a nonzero exit.
//
// The mute is the device's real CoreAudio mute (kAudioDevicePropertyMute on the
// input scope), not an input-gain trick, so apps see a genuinely silent device.

import CoreAudio
import Foundation

let system = AudioObjectID(kAudioObjectSystemObject)

func die(_ msg: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data("mic: \(msg)\n".utf8))
    exit(code)
}

// Mute lives on the input scope's master element for every real device we've seen.
var muteAddr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyMute,
    mScope: kAudioObjectPropertyScopeInput,
    mElement: kAudioObjectPropertyElementMain)

func name(of id: AudioObjectID) -> String {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var cf = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let st = withUnsafeMutablePointer(to: &cf) {
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
    }
    return st == noErr ? (cf as String) : "device \(id)"
}

func inputChannelCount(of id: AudioObjectID) -> Int {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(0)
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(
        byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
    let lists = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return lists.reduce(0) { $0 + Int($1.mNumberChannels) }
}

func inputDevices() -> [AudioObjectID] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(0)
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.filter { inputChannelCount(of: $0) > 0 }
}

func defaultInputDevice() -> AudioObjectID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var id = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
    return id
}

func muteSupported(_ id: AudioObjectID) -> Bool {
    guard AudioObjectHasProperty(id, &muteAddr) else { return false }
    var settable = DarwinBoolean(false)
    return AudioObjectIsPropertySettable(id, &muteAddr, &settable) == noErr && settable.boolValue
}

func isMuted(_ id: AudioObjectID) -> Bool? {
    guard AudioObjectHasProperty(id, &muteAddr) else { return nil }
    var value = UInt32(0)
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(id, &muteAddr, 0, nil, &size, &value) == noErr else { return nil }
    return value != 0
}

func setMuted(_ id: AudioObjectID, _ on: Bool) -> Bool {
    var value: UInt32 = on ? 1 : 0
    return AudioObjectSetPropertyData(
        id, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
}

// Find an input device by case-insensitive exact match, then substring match.
func findInput(named query: String) -> AudioObjectID? {
    let devices = inputDevices()
    let q = query.lowercased()
    if let exact = devices.first(where: { name(of: $0).lowercased() == q }) { return exact }
    return devices.first(where: { name(of: $0).lowercased().contains(q) })
}

// --- Rendering -------------------------------------------------------------

enum Format { case text, json }

func stateWord(_ id: AudioObjectID) -> String {
    guard let muted = isMuted(id) else { return "n/a" }
    return muted ? "muted" : "unmuted"
}

// "<state>\t<*|->\t<device>" — columns line up in a default 8-wide tab stop.
func textRow(_ id: AudioObjectID, default def: AudioObjectID?) -> String {
    let marker = id == def ? "*" : "-"
    return "\(stateWord(id))\t\(marker)\t\(name(of: id))"
}

func jsonObject(_ id: AudioObjectID, default def: AudioObjectID?) -> [String: Any] {
    return [
        "name": name(of: id),
        "muted": isMuted(id).map { $0 as Any } ?? NSNull(),
        "default": id == def,
        "can_mute": muteSupported(id),
    ]
}

func emitJSON(_ value: Any) -> Never {
    guard let data = try? JSONSerialization.data(
        withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else {
        die("failed to encode JSON", 2)
    }
    FileHandle.standardOutput.write(data)
    print()
    exit(0)
}

let help = """
mic — show or change the mute state of a CoreAudio input device.

Usage:
  mic [status]                List all input devices and their mute state.
  mic mute | unmute | toggle  Change the default input device's mute state.
  mic -d "Shure MV7+" [cmd]   Target a named device (substring match).
  mic -f, --format text|json  Output format (default: text).
  mic -h, --help              Show this help.

Environment:
  MIC_DEVICE   Device name to target (overridden by -d/--device).

Output:  Tab-separated columns: <state> <default?> <device>, default marked "*".
         --format json emits an object (one device) or array (full list).
Exit:    0 ok · 1 device not found · 2 mute unsupported or set failed
"""

// --- Parse arguments -------------------------------------------------------

var command = "status"
var deviceQuery = ProcessInfo.processInfo.environment["MIC_DEVICE"]
var format: Format = .text

var args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    let arg = args[i]
    switch arg {
    case "-h", "--help":
        print(help)
        exit(0)
    case "-d", "--device":
        i += 1
        guard i < args.count else { die("\(arg) requires a device name", 1) }
        deviceQuery = args[i]
    case "-f", "--format":
        i += 1
        guard i < args.count else { die("\(arg) requires text or json", 1) }
        switch args[i] {
        case "text": format = .text
        case "json": format = .json
        default: die("unknown format: \(args[i]) (use text or json)", 1)
        }
    case "status", "mute", "unmute", "toggle":
        command = arg
    default:
        die("unknown argument: \(arg) (try --help)", 1)
    }
    i += 1
}

// --- Resolve target --------------------------------------------------------
// A device is "selected" via -d/--device or $MIC_DEVICE. Without one, `status`
// lists everything and the change verbs act on the current default input.

var selected: AudioObjectID? = nil
if let query = deviceQuery, !query.isEmpty {
    guard let found = findInput(named: query) else { die("no input device matching \"\(query)\"", 1) }
    selected = found
}

let def = defaultInputDevice()

func report(_ id: AudioObjectID) -> Never {
    switch format {
    case .text: print(textRow(id, default: def))
    case .json: emitJSON(jsonObject(id, default: def))
    }
    exit(0)
}

// --- Execute ---------------------------------------------------------------

switch command {
case "status":
    if let device = selected {
        report(device)
    } else {
        let devices = inputDevices()
        switch format {
        case .text: for id in devices { print(textRow(id, default: def)) }
        case .json: emitJSON(devices.map { jsonObject($0, default: def) })
        }
    }
case "mute", "unmute", "toggle":
    guard let device = selected ?? def else { die("no default input device", 1) }
    let label = name(of: device)
    guard muteSupported(device) else { die("\"\(label)\" cannot be muted (mute is not settable)", 2) }
    let target: Bool
    switch command {
    case "mute":   target = true
    case "unmute": target = false
    default:       target = !(isMuted(device) ?? false)  // toggle
    }
    guard setMuted(device, target) else { die("failed to set mute on \"\(label)\"", 2) }
    report(device)
default:
    die("unknown command: \(command)", 1)
}
