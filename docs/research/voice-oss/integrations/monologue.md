---
status: draft
doc_type: research
summary: "Offline REA evidence ledger for Monologue's Zoom/Meet integration; speaker-naming path unresolved."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Static artifact and LLVM evidence; REA native decompilation timed out. No live meeting tested."
related:
  - ../meeting-integrations.md
---

# Monologue Zoom/Meet integration: offline REA investigation

Version: 1.5.2 (105). REA Evidence only for actual REA output. LLVM/plist/code-signing records are separately labeled shell static evidence. No runtime verification.

Current status: complete bounded static pass; native REA decompilation unresolved after two startup timeouts; LLVM call paths inspected

Artifacts, paths and hashes: [artifact identity](../data/integrations/monologue-artifact.json). Full raw captures: `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/monologue`.

## Findings

### MO-I01 — Meeting detection starts from microphone activity in other processes

**OBSERVED_STATIC_CALL_PATH**. 0x10009c5b8 calls 0x1000a2528 to read CoreAudio process list, then reads process PID, input-running flag and bundle ID. It skips invalid PIDs, its own process ID, and input-inactive processes; results feed application/window matching at 0x1000a5b74.

Interpretation: This detects local call activity, not which remote participant is speaking. Muted local microphone behavior still needs runtime testing.

Anchors:

- `0x1000a25a8..0x1000a25d0: property address loaded from 0x1010c2868, AudioObjectGetPropertyDataSize`
- `0x1000a26c0..0x1000a26dc: AudioObjectGetPropertyData for list`
- `0x10009c610..0x10009c73c: property reads; 0x1010c2848=ppid/glob, 0x1010c2850=piri/glob, 0x1010c2858=pbid/glob`
- `0x10009c6c4..0x10009c700: exclude own PID and inactive input`
- `0x10009c808..0x10009c828: running-app/window metadata to matcher`

Unknowns: Polling cadence and grace thresholds; Mute/device transition behavior in actual Zoom/Meet.

### MO-I02 — Zoom catalog and browser meeting identity use application/URL/window clues

**OBSERVED_STATIC_CALL_PATH**. Catalog initializer 0x100092938 constructs Zoom/us.zoom.xos. Activity matcher calls browser signal cache 0x10009b3ec. Cache calls active-browser URL utility 0x1006fcef0, feeds URL parser/classifier, and has a separate window-based fallback plus a Date+5-second expiry. Classifier compares lowercased URL host against meet.google.com and zoom.us/.zoom.us/zoomgov.com hosts, examines path components. A related title helper matches meet plus a meeting-code regex.

Interpretation: Browser meeting identity combines URL and window clues with mic activity. Five seconds is observed cache expiry, not a proved detection or speaker-switch latency.

Anchors:

- `0x100092980..0x1000929ac: Swift short-string words decode us.zoom.xos and Zoom`
- `0x1000a5e68..0x1000a5e7c -> 0x10009b3ec`
- `0x10009b5a0..0x10009b5fc -> 0x1006fcef0 -> 0x1000a59e8; fallback 0x1000a3090`
- `0x10009b658..0x10009b668: addingTimeInterval(5)`
- `0x1000a4a24..0x1000a4a64: meet.google.com comparison; 0x1000a4c6c..0x1000a4cf4: Zoom domain checks`
- `0x1000a16f4..0x1000a1854: lowercased meet check, NSRegularExpression matching [a-z]{3}-[a-z]{4}-[a-z]{3}`
- `0x1000a2efc..0x1000a2f04: CGWindowListCopyWindowInfo`

Unknowns: Full fallback precedence and all helper normalization rules; Multiple-tab/browser windows edge cases; No participant-DOM or active-speaker selector path established.

### MO-I03 — Browser URL collection invokes AppleScript

**OBSERVED_STATIC_CALL_PATH**. Active-browser URL routine recognizes browser bundle IDs, builds a browser script at 0x1006faf88, passes thunk 0x1000915f0 to Dispatch.sync, then consumes the script result. Thunk calls 0x1006f6630 which allocates NSAppleScript, initializes source, and invokes executeAndReturnError:. Embedded script resources request active/front tab URL.

Interpretation: This is local browser context acquisition, not a Meet server API integration.

Anchors:

- `0x1006fd01c..0x1006fd0b4: browser bundle mapping`
- `0x1006fd38c..0x1006fd3d0 -> script builder and dispatch thunk`
- `0x1000915f8..0x1000915fc -> 0x1006f6630`
- `0x1006f6668..0x1006f66b0 -> NSAppleScript initWithSource:/executeAndReturnError:`
- `0x1010a3cc4 and 0x1010a1404 selector references`

Unknowns: AppleEvents permission prompts/recovery and browser version compatibility were not exercised; No active-speaker DOM scraping path proved.

### MO-I04 — System audio capture uses a mixed mono CoreAudio process tap

**OBSERVED_STATIC_CALL_PATH**. Function 0x1006e96c4 configures tap description properties exclusive=true, mixdown=true, mono=true, private=true, muteBehavior=0, then calls AudioHardwareCreateProcessTap at 0x1006e9a18. The same path includes macOS14.2 availability failure, tap creation status handling and downstream aggregate-device setup.

Interpretation: The inspected tap yields mixed system audio, which does not by itself carry remote participant identity or isolated per-participant channels.

Anchors:

- `0x1006e9874..0x1006e98b8: macOS14.2 error branch`
- `0x1006e9940..0x1006e996c -> setExclusive,setMixdown,setMono,setPrivate`
- `0x1006e99e4..0x1006e9a18 -> setMuteBehavior(0), AudioHardwareCreateProcessTap`
- `selector trampolines 0x1010a9980,0x1010aa600,0x1010aa680,0x1010aae20,0x1010aa6e0`
- `0x1006ea130 -> AudioHardwareCreateAggregateDevice; subsequent function 0x1006ea548 -> AudioDeviceCreateIOProcIDWithBlock and 0x1006ea5ac -> AudioDeviceStart`

Unknowns: Exact process exclusion list was not fully reconstructed; Notes mix/render channel layout and local-versus-system timing alignment need deeper tracing; No runtime capture or permission checks performed.

### MO-I05 — Audio-capture permission differs from the public guide wording

**OBSERVED_METADATA_WITH_DOCUMENTATION_TENSION**. Info.plist declares NSAudioCaptureUsageDescription specifically for voice-note system audio; NSScreenCaptureUsageDescription describes screen context for transcription. Public note guide currently calls optional system audio Screen Recording permission.

Interpretation: Document this as version/platform wording tension; do not assume a runtime permission dialog solely from metadata.

Anchors:

- `current/Monologue.app/Contents/Info.plist keys NSAudioCaptureUsageDescription,NSScreenCaptureUsageDescription`
- `https://www.monologue.to/docs/voice-notes/record-a-note`

Unknowns: Exact TCC authorization flow on each supported macOS release.

### MO-I06 — Remote active speaker identification, diarization, names and utterance timing

**UNRESOLVED**. Inspected detection/browser/tap paths do not establish a real-time remote active-speaker source. Public docs describe post-recording speaker labels, manual naming/marking self and transcript segments. Binary bundles diarizer/speaker types, but no Notes-to-local-diarizer call chain has been proved.

Interpretation: Do not equate meeting detection, local input activity, or bundled audio-model symbols with participant-aware active-speaker extraction.

Anchors:

- `https://www.monologue.to/docs/voice-notes/organize-edit-and-share`
- `https://www.monologue.to/docs/public-api/notes`
- `strings-current.txt: DiarizerManager,SpeakerManager,activeSpeakers are seeds only`

Unknowns: Whether Notes diarizes on server or device in this build; How named labels are assigned before manual correction; Whether any alternate Zoom/Meet-specific active-speaker path exists; Speaker event/transcript timestamp reconciliation.

## REA records

- `ev_aa769012ed9aef12de271159f9ce526e9018c415de49d2a4d151d54f80d6e360` — `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/monologue/artifact-current-dmg.json`
- `ev_7277a340b1d8817429803f46ac27e2fadb637a6fba7cb6e7c23ea601d332c11a` — `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/monologue/006-macho.json`
- `ev_069b58901342928b0a3da1c43df6a1ebb05d8f3c6727fa4264e1ee3cf2d68e88` — `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/monologue/plist-valid.json`

## Method limits

- REA Ghidra initial startup timed out after330000ms; one retry with supported per-process startup limit timed out after600000ms. No further native retry. Both retained error records. Ghidra decompilation/search coverage remains unavailable.
- LLVM disassembly independently anchored function calls and instruction-encoded constants against hash-pinned ARM64 bytes.
- No deep native negative search is exhaustive; untraced functionality remains unknown.
- codesign --verify --deep --strict passed on original extracted 1.5.2 bundle; this establishes on-disk signature validity/designated requirement, not notarization or runtime safety.

No installation, app launch, account access, microphone/meeting capture or private endpoint access occurred.

Cleanup: Timed-out analysis sessions ended via owned MCP process shutdown; no process with target-952e7bdf13ae remained. A final lightweight REA metadata session exported Evidence and completed close_binary successfully.


[Return to the integration study](../meeting-integrations.md).
