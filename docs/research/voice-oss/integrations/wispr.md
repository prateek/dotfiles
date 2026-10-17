---
status: draft
doc_type: research
summary: "Static evidence ledger for Wispr Flow 1.6.1102 Zoom/Meet integration, including focused Ghidra decompilation."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence ledger for the static meeting-integration investigation; no live meeting tested."
related:
  - ../meeting-integrations.md
---

# Wispr Flow 1.6.1102: Zoom / Google Meet integration static findings

Scope: official public Apple Silicon macOS DMG, acquired 2026-10-12. No installation or target launch, no account/profile inspection, no audio recording, no backend/network traffic capture. Static packaged JavaScript reading plus REA artifact reconstruction and bounded Ghidra decompilation. All behavior below is shipped-code evidence, not observed execution or proof that account-specific feature flags enable the path.

## Identity and reproduction

Official public help page: https://docs.wisprflow.ai/articles/6203703148-redirect-loops-when-attempting-to-download-the-app-from-the-wispr-flow-website

It links https://dl.wisprflow.ai/mac-apple/latest, which resolved to https://dl.wisprflow.com/wispr-flow/darwin/arm64/dmgs/Flow-v1.6.1102.dmg. App Info.plist and package.json both say 1.6.1102, bundle com.electron.wispr-flow. DMG 302,739,762 bytes, SHA-256 `c8e4f24a3693c4d89debbfad2e43f1cb61743a2a8355c2d9e99b8b959110b0e7`.

ASAR SHA-256 `da64ebcb3d1d48032ac0808b4734a3509596a6cc00a39d84ae0deaf921e9c11d`.
Main JS SHA-256 `24413a433e4cf159816d60f194ad32def76741d7a5e5bed9b27581bb74eebac2`.
Swift helper SHA-256 `21afb12c1c9edd28831358b8b03f8c8b43b716cf49858ec0be11d3a3f5859ca1` (6,032,672 bytes, ARM64).

The [receipt](../data/integrations/wispr-receipt.json) contains identities, local files, REA Evidence IDs and hashes; the [custody mapping](../data/integrations/wispr-custody.json) resolves retained copies. The [anchor index](../data/integrations/wispr-anchors.json) contains source file hashes, exact zero-based character ranges, 1-based lines/0-based columns and hashes for focused code excerpts. Ranges and columns use Unicode code points, not UTF-8 bytes or JavaScript UTF-16 code units. Exact shipped text is retained outside the checkout under the capture root; ignored scratch copies also exist.

REA ASAR Evidence: `ev_4355e5d524252bf83bf6162689801ee09f50f724c5a1493ef990bea542fce258` (`asar-evidence.json`, complete 60 MB JSON). Summary: `ev_d663fb9d6d71291dbeb85f2d60f766014ae01d925d63747bbf7456d58e331e15`. Main asset view: `ev_9baa79f7349441630bb394ac59887ac5dc635ea04cb0a5081912c4889550143f`.

REA parsed 167 JavaScript files / 183 relevant files; application and semantic coverage are PARTIAL. Main-file semantic analysis was not started because the parent reserved capacity for static observations. The main asset has partial AST coverage. Therefore the following code-path claims come from manual reading of exact shipped JS anchored by its REA-observed artifact identity; they are not claims that the automated graph proved end-to-end reachability.

The default ASAR inventory rejected an unpacked node_sqlite3.node integrity mismatch: declared `e476b3077cee91f9e8a679e7d8303fb6e5e0c5815c25aa06033159ae533857c6`, observed `7f0bc70a5f508a80b895a526fdb06f310c2601dc1f32e25fe23d1bbbdc175df0`. Rerun used `record-and-continue`, preserving this contradiction. Deep strict macOS codesign verification passed. This does not explain the discrepancy, prove safety, or establish that all unpacked members match their ASAR declarations.

## Findings

### 1. Meeting-app detection combines microphone ownership and conference URLs — ANSWERED for the speaker-polling gate

**OBSERVED in shipped JS, WF-IMPL-01 / WF-IMPL-02.** `detectActiveMeetingApp` logic inside module 61246 (`Ht`) calls the native helper's `getMicrophoneHolders`, classifies bundle/process identities, then considers current/recent URL context and the meeting's join URL. Native Zoom takes priority, then native Teams, then Slack; browser candidates include Brave, Chrome, Edge and a bounded Arc special case. Meet/Zoom web URLs select platform-specific polling. Conflicting conference URLs are excluded in some branches.

If no eligible meeting app is found, the session defers polling and retries: early attempts rate-limited at 2 seconds for the first 30 seconds, then 10 seconds, with a 90-attempt cap. These are code constants, not measured timing.

**Limit:** This is the gate that starts speaker observation during a meeting session. It is not a complete analysis of all automatic meeting-start/end detection. Calendar association is a separate path; microphone ownership alone is not participant identity.

### 2. Platform-specific native-helper polling carries participant-name observations — PARTLY ANSWERED

**OBSERVED in shipped JS, WF-IMPL-02 / 03 / 07.** When gated on, the session sends `StartSpeakerPolling` to its Swift helper with platform, anchored-discovery flag, marker classes, tile-root classes, whether to collect speaker names, optional target native process ID, and optional bind-report diagnostics. Defaults supplied for Google Meet are marker class `kssMZb` and tile-root class `oZRSLe`; these can be overridden through the meeting feature payload. These are configured UI selectors, not a Zoom/Meet API contract.

`MeetingSpeakerChange` helper events contain timestamps, attribution state, discovery tier, speaker name, speaking-name set, muted-name set, self name, reason/source/evidence kind. The JS validates/normalizes and records them only with an active meeting tracker and enabled participant-name preference. Additional helper events report source availability and window binding. Source categories in shipped schema/config distinguish Zoom main/compact and Meet tab/side surfaces; reasons include hidden/occluded sources, unrecognized/conflicting labels, and partial coverage.

**Native corroboration:** Ghidra recovered a `MeetingSpeakerPoller` method at `0x10022a364` that reads its polling-active state, platform strategy, target Zoom PID, collect-speaker-names state and bound window, and calls strategy operations / rebuild paths. Evidence `ev_2dd037cbe5907d9bad4eff4e6dd0ad2ca11f45112b6cac5923893b21b9dae6ac`. The binary imports AXUIElement attribute APIs and contains native platform strategy types for Zoom and Google Meet. This supports an accessibility/window-observation architecture, but this bounded pass did not resolve all virtual dispatches down to the exact AX traversal/attribute reads.

**UNKNOWN:** Exact native Zoom window/title/label matching; exact Meet AX-tree traversal and DOM-class exposure; all platform strategy priority rules, visibility behavior, accessibility-tree refresh/poll cadence; current compatibility with Zoom/Meet updates. Do not claim runtime support or browser injection from selector strings. No claim that all integration paths avoid provider SDK/API calls.

### 3. Speech diarization IDs and visible participant names are different inputs — ANSWERED for local live mapping

**OBSERVED in shipped JS, WF-IMPL-04 / 05.** `handleTokens` treats microphone and system audio separately. Nonfinal tokens clear their speaker. Final mic tokens receive a mic-source speaker ID but no name in this path. Final system tokens receive a system-source ID; when name attribution is enabled, the code looks up the latest helper speaker observation at or before the token's start time, translated into the session clock. Observations older than 1,500 ms are stale. Only `matched` state supplies fresh trusted name evidence; ambiguous/unknown data is not directly stamped as trusted.

A separate system-speaker identity map associates a diarization ID with a canonical display name. The shipped default config requires 3 qualifying token-level evidence updates to promote a name; changing an established name requires 5 conflicting updates and respects a 30-second cooldown after a remap. These counters advance per token mapping call, without distinct UI-event deduplication: several tokens can reuse one fresh helper observation. Existing canonical names can be held through unavailable evidence. A hint can link an unmapped ID to an already-known canonical name, so the freshness check is not a universal prohibition on showing a retained name.

**INFERENCE:** It fuses acoustic segmentation identifiers with UI-derived name evidence, smoothing unstable indicators rather than treating the last visible name as ground truth. The presence of one system audio capture stream and separate speaker IDs is consistent with diarization downstream of capture, not one captured OS stream per remote participant.

**UNKNOWN:** Server-side diarization model, confidence, overlap handling, whether specific server routes choose different providers, and postprocessing accuracy. Do not attribute model names merely from enumerated provider strings.

### 4. Native speaking-label predicate is real code, with bounded attribution — ANSWERED only as a helper predicate

REA followed the `active speaker` string references and decompiled function `0x100222848`. It lowercases a supplied string and tests for the substrings `talking`, `speaking`, or `active speaker`. Its direct wrapper `0x10022297c` loads an optional string from a record and calls that predicate.

Evidence: `ev_943c607c77f7aca4cf4edc1e7f84e8d54251a012e7be262706b3a5526f0b1b20` (string search); `ev_cd4caf8e82ca084183c52411bd812db34f28576b85d1b4a0625e4730ae2678b0` (xref); `ev_0618078ff92742ef2c9556e1225601606463aee9423657995357df6a7cb16c20` (predicate); `ev_589c053feb904615808c86e04bc910d64b0bb2aad82bd0581ff46d42ec095089` (wrapper).

**Limit:** The wrapper is referenced through data; this pass did not resolve which platform strategy invokes it. It is not evidence that every Zoom/Meet speaker name is found through English label matching.

### 5. Capture uses separate microphone and system-audio paths, independent of speaker UI — ANSWERED at Electron boundary

**OBSERVED in shipped JS, WF-IMPL-08 / 09 / 11 / 12.** Main process registers a display-media request handler. macOS capability selection is process tap on >=14.4, ScreenCaptureKit on 13–14.3, and unsupported below13. The process-tap branch returns `loopbackAllDevices`; ScreenCaptureKit obtains a screen source and pairs it with loopback audio. Renderer capture requests `getDisplayMedia({audio:true,video:false})`, removes any video tracks, checks audio tracks, and connects an audio worklet. Mic capture is separate. IPC connects start/stop system-capture requests to renderer methods.

**Limit:** This observes the Electron boundary and selected Chromium feature flags. It does not decompile Electron's loopback implementation, prove actual macOS permissions were granted, or prove which speakers/apps are included by a live capture. It does not show a Zoom bot joining the call.

### 6. Name evidence has a persisted, timestamped sidecar and later upload path — ANSWERED in local code

**OBSERVED in shipped JS, WF-IMPL-06 / 10.** A per-session NDJSON observation log is first created in a temporary observations directory, later bound to a meeting as `speakers.observations.ndjson`. It records metadata (platform/client/OS/app version, marker classes, recording clock), participant IDs/names/self flags, changed speaking/muted sets, reason/source/evidence kind, pause/resume events. The writer deduplicates unchanged state, serializes flushes, retains failed append data for retry, and merges resume segments using names/participant IDs and a recording-time boundary. The format explicitly distinguishes unknown/null from empty sets.

A refinement coordinator conditionally uploads this sidecar via a presigned S3 upload route, with retries. Cloud-sync disabled or non-attributed refinement takes a gated path that deletes the local observation artifact. The upload-size limiter progressively drops metadata/muted-only observations and eventually older observations. These are important differences from our project's explicit never-lose/reprocess-history requirement; borrowing the sidecar concept does not imply copying its retention policy.

**UNKNOWN:** Backend consumption/correlation algorithm and complete retention/deletion lifecycle. No presigned URL or API was fetched; no real participant data was read.

## Design implications to carry forward (PROPOSED, not decisions)

- Keep audio capture, call/meeting detection, diarization, displayed-name observations and canonical identity matching as separate interfaces.
- Record timestamped raw observations with source/provenance, uncertainty, simultaneous speakers, visibility/coverage and versioned parser identity. Retain them alongside original audio for reprocessing.
- Treat UI names as noisy evidence: fresh/matched, ambiguous, hidden, occluded, stale, changed display names, and repeated duplicate names need distinct states. Avoid promising named attribution merely because transcript text exists.
- Test native Zoom main/compact windows, Meet active/background tabs and side panels, browser variations, localization, permissions, overlapping speech, screen sharing, meeting switches, leave/rejoin, and display-name changes in a controlled test meeting.
- Exact speaker attribution quality still requires controlled runtime validation; static code does not establish it.


[Return to the integration study](../meeting-integrations.md).
