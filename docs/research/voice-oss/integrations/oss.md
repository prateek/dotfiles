---
status: draft
doc_type: research
summary: "Evidence ledger for Ghost Pepper and VoiceInk Zoom/Meet and speaker handling from pinned OSS source and artifacts."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence ledger for the static meeting-integration investigation; no live meeting tested."
related:
  - ../meeting-integrations.md
---

# Ghost Pepper and VoiceInk: Zoom / Meet / speaker integration

Date: 2026-10-12. Scope: offline installed-artifact identity and capability corroboration through REA 6.4.0; ordinary inspection of first-party public source at matching version tags. No app launched, permissions granted, account/private app storage read, recording made, or traffic intercepted. No packaged Secrets content inspected. This is not runtime verification or a reproducible-build comparison.

## Result

Ghost Pepper has a concrete source-visible meeting pipeline, but its Zoom/Meet connection is desktop observation plus ordinary audio capture. Native Zoom is identified by bundle ID, browser Meet by window-title patterns. Participant names are harvested from calendar metadata / frontmost-window OCR, independently of who is speaking. Live transcript channels are microphone = Me and system audio = Others. After stop, supported FluidAudio models can diarize the remote audio and map acoustic embeddings to saved voices. This is not evidence of a live Zoom/Meet active-speaker event feed.

VoiceInk v2.13 has no meeting-specific path established by this examination. Its first-party Swift source implements selected-input-device dictation and frontmost-window OCR context. The bounded source search found no Zoom/Meet/diarization/active-speaker handling. Its ScreenCaptureKit dependency alone must not be read as meeting audio capture: the followed code invokes a screenshot manager. This conclusion is bounded to the pinned version and searched first-party source; it does not rule out future features, external virtual audio routing, providers with unexposed capabilities, or another platform build.

## Version and artifact identity

| App | Installed identity (REA plist) | Public source pin | Native byte identity |
| --- | --- | --- | --- |
| Ghost Pepper | `com.github.matthartman.ghostpepper`, 2.4.4 build 22 | `v2.4.4`, `c212bcc108f178c4a0f184d9da4bdbcb9a205448` | Installed arm64 main executable SHA-256 `c3ddf242bc8f435b97856e589c2e934227fca7da97aed1475f1dd4a1546386ed` |
| VoiceInk | `com.prakashjoshipax.VoiceInk`, 2.13 build 213 | annotated `v2.13` tag object `1143b64f37ccdebca5330d95dda8b3873dd9b8cf`, peeled commit `68b871e79e2b1ec4c3b4914cccd2e0907d94237a` | Installed universal main SHA-256 `cb0c14d5e6cab348c8840541d8e29f31d411e6d9ef5f7d83b60d26b8adcb8ea1`; derived arm64 slice `9bc7044b40617014043042092c20a3632c0cbe7212e53371fc6aedd90a6fbb5a` |

VoiceInk's original universal Mach-O was rejected by this REA/Ghidra target admission (`architecture_unsupported`). `/usr/bin/lipo original -thin arm64 -output derived` created a copy in the capture directory, preserving the installed app. REA then inspected that slice. Plist inspection used the installed original `Contents/Info.plist` explicitly; the Evidence subject is the derived slice, and the plist's source path is separately recorded. The transform receipt retains both SHA-256 values.

Matching human version strings do not establish that the installed binary was compiled from these exact commits. Framework imports corroborate primitive availability; they do not prove a call path executes. Native code was not decompiled because complete source settled the scoped implementation questions, consistent with the skill's source-analysis route.

## REA evidence

All complete raw Evidence is retained under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/oss/`. Machine-readable [artifact index](../data/integrations/oss-artifacts.json); [original executable custody](../data/integrations/oss-custody.json). No inspection opened an active native analysis database, so no `close_binary` session was outstanding.

| Label | Operation and complete file | REA Evidence ID |
| --- | --- | --- |
| GP-MACHO | `inspect-macho`, `GhostPepper-inspect-macho.json` | `ev_e360275407a349a05d080b3b0e50b7651aaee7a898fd601343eacc6ec1a8b303` |
| GP-SIGN | `inspect-signature`, `GhostPepper-inspect-signature.json` | `ev_33970e33ab9f44e51cb7c7fa9823fb47d01edc5dc4c0ed6da268a1548de2a93e` |
| GP-PLIST | `inspect-plist`, `GhostPepper-inspect-plist.json` | `ev_42e90c0c8aa00e3210ef76b9c7876ad026dd034cf930f538b7dc9ad3263f3dec` |
| VI-MACHO | `inspect-macho`, `VoiceInk-arm64-inspect-macho.json` | `ev_e802394b8367efa43f3d61341a551980eed79486f5b957df54cd1196593daa4e` |
| VI-SIGN | `inspect-signature`, `VoiceInk-arm64-inspect-signature.json` | `ev_fb0d8115bdd82b8e60c6a6b9c222100046dc367240caf82b6041faf6913ee227` |
| VI-PLIST | `inspect-plist`, `VoiceInk-arm64-inspect-plist.json` | `ev_1dffe5beab92654a4f218936a5c9febe0c1038e9ff4a406e1ecb89724fa8a39b` |

GP-MACHO includes ScreenCaptureKit, ApplicationServices, CoreAudio and Vision dependencies; imports `SCStream`, `SCStreamConfiguration`, `SCScreenshotManager`; exported FluidAudio Sortformer symbols. VI-MACHO includes `SCStreamConfiguration` and `SCScreenshotManager` imports; that distinguishes screenshot infrastructure from proof of system audio capture. Both import/export inventories say non-exhaustive. Both signatures declare microphone input; signatures were described, not trust-validated. GP team is `BBVMGXR9AY`, VI team `V6J6A3VWY2`.

## Finding ledger

### GP-I01 — Meeting detection is an opt-in frontmost-app heuristic (SOURCE-DERIVED)

`MeetingDetector.start()` polls every five seconds and immediately. `checkForMeetingApps()` checks `NSWorkspace.shared.frontmostApplication`; Zoom bundle IDs are `us.zoom.xos` and `us.zoom.videomeeting`. It fires for a known frontmost app even when a real active meeting has not been established. Dismissals suppress subsequent prompts for that app in the session. Browser recognition checks Accessibility window titles for `meet.google.com`, `google meet`, `meet -`, and Zoom meeting URL patterns. `AccessibilityWindowTitles.all()` reads `AXWindows` / `AXTitle`. The address-bar reader in this file is used by its video-site branch; the meeting branch shown does not read a DOM or an actual Meet transport.

Sources: [MeetingDetector.swift L27-L51](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingDetector.swift#L27-L51), [L84-L153](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingDetector.swift#L84-L153), [L221-L235](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingDetector.swift#L221-L235), [AccessibilityWindowTitles.swift L4-L23](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/AccessibilityWindowTitles.swift#L4-L23).

Inference: title changes/localization, frontmost app selection, and denied Accessibility permission can weaken detection. Browser-title matching is not proof the user joined a call.

### GP-I02 — Audio is microphone plus all-system output, not participant tracks (SOURCE-DERIVED; primitives corroborated by GP-MACHO)

`DualStreamCapture` starts `AudioRecorder` and `SystemAudioRecorder`, tags chunks `.mic` or `.system`, and timestamps callback receipt against a common start date. System capture obtains the first display, creates `SCContentFilter(display:excludingApplications:[],exceptingWindows:[])`, enables audio and excludes its own process. Configuration requests mono Float32 16 kHz; visual configuration is reduced to 2×2 at one frame per second, and the registered stream output is `.audio`. No per-Zoom/Meet process filter or participant ID enters this path. If system capture throws, capture continues with microphone only after a log message.

Sources: [DualStreamCapture.swift L23-L75](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Audio/DualStreamCapture.swift#L23-L75), [SystemAudioRecorder.swift L17-L54](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Audio/SystemAudioRecorder.swift#L17-L54).

Inference: unrelated system playback may enter a meeting recording; acoustic speakerphone leakage may cause duplicated local/remote audio. Neither outcome was runtime tested. Whether a warning beyond the generic audio warning surfaces for a failed system stream was not exhaustively traced.

### GP-I03 — Live attribution is Me/Others; remote diarization occurs after stop (SOURCE-DERIVED)

`MeetingSession.start()` maps `.mic` chunks to `.me` and `.system` to `.remote(name:nil)`. The pipeline defaults to 30-second transcription chunks. `stop()` stops capture, drains the pipeline, then invokes `applyRemoteSpeakerTaggingIfAvailable()`. That method reconstructs the system channel from saved chunks and calls the supplied remote tagger. It replaces generic remote transcript segments with tagged ones while retaining local and already named segments. `remote` here means the other participants' channel, not cloud inference.

Sources: [MeetingSession.swift L85-L113](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L85-L113), [L194-L211](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L194-L211), [L231-L355](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L231-L355), [ChunkedTranscriptionPipeline.swift L49-L54](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Transcription/ChunkedTranscriptionPipeline.swift#L49-L54).

### GP-I04 — Speaker turns and names come from acoustic models and saved voices (SOURCE-DERIVED; model linkage corroborated by GP-MACHO)

`AppState.createMeetingSession` supplies `remoteSpeakerTaggedTranscript`; it calls `ModelManager.transcribeWithSpeakerTagging`. That is gated by `supportsSpeakerFiltering`, which is true only for FluidAudio-backed ASR models in this tag. It loads a Sortformer model, processes chunks, finalizes speaker spans, and obtains per-speaker text via `FluidAudioSpeechSession`. The single-speaker case has a VAD rescue path. Model load failure returns nil, retaining the existing transcript.

Names are resolved by acoustic embeddings, previous local profiles, and `RecognizedVoiceProfile`. Resolver defaults are one second minimum embedding audio and cosine distance ≤0.45. Unmatched voices are created; display placeholders are converted to “Speaker N” for the meeting. The traced function receives audio/session ID, not OCR attendees or Zoom participant IDs. This establishes a separation of roster extraction and voice identification in the inspected source.

Sources: [AppState.swift L1782-L1793](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/AppState.swift#L1782-L1793), [L1929-L2007](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/AppState.swift#L1929-L2007), [L2884-L2929](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/AppState.swift#L2884-L2929), [ModelManager.swift L313-L363](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Transcription/ModelManager.swift#L313-L363), [SpeechModelCatalog.swift L40-L44](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Transcription/SpeechModelCatalog.swift#L40-L44), [SpeakerIdentityResolver.swift L16-L25](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/SpeakerIdentity/SpeakerIdentityResolver.swift#L16-L25), [L85-L120](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/SpeakerIdentity/SpeakerIdentityResolver.swift#L85-L120), [L134-L153](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/SpeakerIdentity/SpeakerIdentityResolver.swift#L134-L153).

Unknown: real overlap accuracy, voice identity error rate, speaker-count limit in the selected underlying model, and latency on actual hardware. Package.resolved pins FluidAudio 0.13.6, revision `57551cd90e0bbec342766244358bcf08afb05290`; this pass did not audit the dependency's full algorithm.

### GP-I05 — Attendees are calendar records and OCR candidate names (SOURCE-DERIVED)

Start schedules title/OCR refreshes after 3, 15, 30, and 60 seconds. Calendar auto-match fills title/attendees if connected, while an explicitly chosen calendar event suppresses auto-match. OCR merges unique names and retains existing calendar versions. It captures the frontmost application window through `SCScreenshotManager` and recognizes text with Apple's Vision. The parser accepts two to four capitalized Latin-word candidates, strips parenthetical suffixes, filters UI words/numbers/URLs. The manual Detect action activates the meeting app, waits 800ms, captures, then returns to Ghost Pepper. These are candidate roster entries, not active speaker observations.

Sources: [MeetingSession.swift L152-L167](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L152-L167), [L444-L484](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L444-L484), [L487-L611](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L487-L611), [WindowCaptureService.swift L10-L32](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Context/WindowCaptureService.swift#L10-L32), [OCRRequestFactory.swift L10-L63](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Context/OCRRequestFactory.swift#L10-L63).

Inference/weakness: automatic OCR can sample whichever app is currently frontmost. The OCR factory joins observations with spaces but the attendee parser splits on newlines, so multi-label screenshots warrant a targeted regression test. The stated name heuristic also excludes many valid naming conventions. None was exercised against a real call in this pass.

### GP-I06 — Automatic meeting end is Zoom-native-only in this tag (SOURCE-DERIVED)

A five-second timer starts only when detected app name is Zoom and the bundle ID begins `us.zoom.`. It requests stop if Zoom disappears, or after two consecutive polls lacking meeting-like Accessibility titles. The title heuristic excludes known home/settings/internal titles but treats other nonempty titles as active. The same auto-end route is not enabled for Google Meet in this inspected code.

Sources: [MeetingSession.swift L632-L680](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L632-L680), [MeetingWindowHeuristics.swift L29-L85](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingWindowHeuristics.swift#L29-L85).

### GP-I07 — Existing chunk retention does not meet our lossless requirement by itself (SOURCE-DERIVED → design implication)

Meeting audio chunks live under `FileManager.default.temporaryDirectory/GhostPepper/meeting-<UUID>/chunks`. Each chunk is serialized before transcription; writes use `try?`, and callbacks can still run after an unsuccessful write. Markdown is saved incrementally, but its failure branch logs an error. This is useful recovery structure, not proof that captured audio is durably retained. It also waits for a chunk drain before writing audio, so audio may still be in memory when a process dies.

Sources: [MeetingSession.swift L85-L93](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L85-L93), [ChunkedTranscriptionPipeline.swift L174-L192](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Transcription/ChunkedTranscriptionPipeline.swift#L174-L192), [MeetingSession.swift L616-L629](https://github.com/matthartman/ghost-pepper/blob/c212bcc108f178c4a0f184d9da4bdbcb9a205448/GhostPepper/Meeting/MeetingSession.swift#L616-L629).

No forced crash/storage failure was induced; this is a static durability limitation, not a witnessed incident.

### VI-I01 — Followed capture path records a selected input device (SOURCE-DERIVED)

`Recorder.startRecording` resolves an input device, then uses `CoreAudioRecorder`; AUHAL enables input element 1, disables output element 0, binds the selected device, and converts output to 16 kHz mono PCM Int16. This is an input-device dictation path. It does not itself establish capture of the other side of a Zoom/Meet call. A virtual input device could be selected by a user, but that configuration was not inspected or tested.

Sources: [Recorder.swift L50-L98](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/Recorder.swift#L50-L98), [CoreAudioRecorder.swift L364-L438](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/CoreAudioRecorder.swift#L364-L438), [L462-L471](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/CoreAudioRecorder.swift#L462-L471).

### VI-I02 — ScreenCaptureKit supports OCR context, not a demonstrated meeting stream (SOURCE-DERIVED; primitives corroborated by VI-MACHO)

`RecordingContextCaptureService` collects selection, clipboard and, with screen permission, OCR screen text. `ScreenCaptureService` uses Accessibility for the frontmost window title/frame, selects a matching `SCWindow`, captures one image with `SCScreenshotManager`, and appends OCR text to Active Window / Application context. No participant list, turn timeline, or active-speaker field is produced by this path. Its transcript model stores flat text/enhancedText/audio file metadata, without speaker turns in the inspected definition.

Sources: [RecordingContextSnapshot.swift L34-L55](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/Services/RecordingContextSnapshot.swift#L34-L55), [ScreenCaptureService.swift L68-L95](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/Services/ScreenCaptureService.swift#L68-L95), [L98-L145](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/Services/ScreenCaptureService.swift#L98-L145), [Transcription.swift L11-L32](https://github.com/Beingpax/VoiceInk/blob/68b871e79e2b1ec4c3b4914cccd2e0907d94237a/VoiceInk/Models/Transcription.swift#L11-L32).

### OSS-I01 — Negative searches and remaining scope (BOUNDED NEGATIVE / UNKNOWN)

The [bounded search index](../data/integrations/bounded-source-searches.json) records regexes, matching locations and searched file counts; complete matching lines remain in the local raw capture/scratch ledger: 133 first-party GhostPepper Swift files, 333 VoiceInk Swift files, excluding paths containing Secrets. Searches for `active.?speaker` returned zero in both; VoiceInk also had zero matches for Zoom/Meet URL, `diariz`, `CATapDescription`, `SCStream(`, `capturesAudio`, and SDK/speaker-ID terms. Ghost Pepper has the source paths described above. No Zoom/Meet SDK or browser DOM active-speaker route was established. These are search boundaries, not proof every distributed dependency or backend lacks an integration.

Answered: pinned source capture path, meeting detection route (GP), roster mechanism (GP), live vs final speaker attribution (GP), artifact versions/hashes/declared primitives (both).

Partially answered: binary-source agreement (matching versions and compatible imports; no reproducible build/decompilation match), retention behavior (source only), VoiceInk meeting capability (bounded negative first-party source investigation).

Unresolved: real Zoom/Meet version compatibility, overlapping speech, multilingual participant names, minimized/hidden browser behavior, false-positive/negative detection, call audio mixed with media, sleep/device/permission interruption, measured timing/diarization accuracy, and newer VoiceInk build features.

## Product implications to consider, not architecture decisions

Keep five independently sourced concepts: call detection, audio capture source, participant roster, acoustic speaker turn, and resolved person identity. Record provenance/confidence with each identity link. Preserve separate raw channels and observations before derivation. Model an active-speaker event as timestamped evidence, not a definitive transcript attribution: call UI can lag and overlap is possible. When no reliable person mapping exists, retain an unknown speaker that can be corrected later. Expose degraded capture explicitly and verify durable audio retention independently of transcription success.


[Return to the integration study](../meeting-integrations.md).
