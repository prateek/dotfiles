---
status: draft
doc_type: research
summary: "Static REA and pinned-source findings on how the original five apps detect Zoom/Meet meetings and attribute speakers, with evidence boundaries."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Version-pinned static artifact/source investigation using REA, with primary platform documentation. No live meeting or account tested."
related:
  - README.md
  - product-behavior.md
  - discovery-plan.md
---

# Zoom, Google Meet, and speaker identity

The user asked us to use REA to establish how the five reference apps integrate with Zoom and Google Meet, especially active-speaker detection. **Granola and Wispr ship desktop UI observation paths that combine speaker metadata with separately captured audio. Ghost Pepper's inspected source uses post-call acoustic diarization and saved voice identities. Monologue's confirmed path detects microphone activity and captures mixed audio; its automatic speaker-naming mechanism remains unresolved. No equivalent meeting integration was established for the inspected VoiceInk version.**

This investigation extends the [discovery corpus](README.md); it does not select architecture or implement a product. Evidence is dated **2026-10-12**, version-pinned below, and static unless explicitly labelled DOCUMENTED. No target app or extension was installed, launched, logged into, or used in a meeting. The apps' server configuration, account eligibility, accuracy, and live compatibility were not tested.

## Keep these signals distinct

| Signal | What it can tell us | What it cannot establish alone |
| --- | --- | --- |
| Meeting detection | A known app is active, a microphone is in use, or a matching tab/window is present. | Whether a real meeting was joined, or who spoke. |
| Audio capture | Microphone, mixed system output, or authorized participant media. | A person's real name. |
| Participant roster | Display names and, sometimes, stable meeting IDs. | Which participant spoke at a timestamp. |
| Active-speaker UI/event | The meeting interface or service thinks a participant is speaking. | Exact audio boundaries, isolated voice tracks, or reliable overlap handling. |
| Acoustic diarization | Audio segments likely belong to the same voice. | That “Speaker 2” is a particular person. |
| Identity resolution | Evidence links a voice/turn to a participant or saved person. | Permanent certainty; names, devices, rooms, and participants can change. |

## Reference implementation map

| Product and inspected version | Zoom / Meet connection | Audio and naming path established | Evidence and limits |
| --- | --- | --- | --- |
| **Granola 7.637.0**, Companion **0.4.18** | Zoom desktop through native Accessibility bridge. Meet through Chrome Accessibility or an optional Chromium extension reading rendered tiles/styles. | Mic/system channels are separate from UI speaker events. Desktop maintains a timed speaker history, filters self, and assigns names to system transcript chunks/words. | Official docs plus shipped JavaScript, extension AST/manual reading, and native bridge evidence. Feature/workspace gates exist. [Desktop](integrations/granola-desktop.md), [extension](integrations/granola-extension.md), [native bridge](integrations/granola-native.md). |
| **Wispr Flow 1.6.1102** | Desktop detects microphone-using apps/browser conference URLs and requests native speaker polling for Zoom/Meet. | Separately captures mic/system audio; correlates speaker events with transcript times and diarized speaker IDs. | Shipped Electron code and focused native investigation; static code may exceed public rollout/docs. [Wispr ledger](integrations/wispr.md). |
| **Monologue 1.5.2 (105)** | Native microphone-activity detection with supported-app/browser identity handling. | A CoreAudio mixed system tap exists; public docs describe mic plus optional system capture and subsequent speaker naming. | Confirmed static call paths and docs; no demonstrated remote active-speaker/name extraction. [Monologue ledger](integrations/monologue.md). |
| **Ghost Pepper 2.4.4 (22)** | Frontmost native-app IDs or browser window-title patterns; calendar/OCR for attendee candidates. | Mic = Me, system = Others live. After stop, supported FluidAudio models diarize remote audio; saved voice embeddings can supply names. | Pinned OSS source, installed-binary identity/import corroboration. OCR roster is separate from acoustic assignment. [OSS ledger](integrations/oss.md). |
| **VoiceInk 2.13 (213)** | No meeting/speaker path established in 333 searched first-party Swift files. | Selected-input dictation and screenshot OCR context. | Pinned OSS source and native metadata. A ScreenCaptureKit import is not proof of meeting audio capture. Bounded absence, not an all-version/product claim. [OSS ledger](integrations/oss.md). |

These mechanisms can coexist. An app can use acoustic speaker IDs and UI names together; discovering either does not establish that every session uses it.

## Granola: visible speaking state becomes timed attribution

The Meet extension scans participant tiles in the main page and Document Picture-in-Picture. It reads names from tile/accessibility text and infers speaking state from computed colored borders/outlines or narrow activity bars. It filters self using several independent hints, coalesces DOM changes for 100 ms, refreshes periodically, and delays clearing a speaker by 500 ms. It picks the first qualifying remote tile; this is a heuristic with layout and overlap limitations, not a per-person audio feed. Its manifest targets Meet/Google Chat, not Zoom. [Packaged-code findings GE01–GE06](integrations/granola-extension.md)

The extension sends `active-speaker-changed` through Chrome Native Messaging to `com.granola.app`. The background adds a wall-clock timestamp, but the inspected desktop handler passes only ID/name into its shared timeline, which then uses desktop receipt time. Native AX records take a different path and pass their own timestamps plus configurable lag adjustments. This is a concrete reason to trace both ends of an integration. [GE06](integrations/granola-extension.md), [G-D02–G-D05](integrations/granola-desktop.md)

The desktop filters the local participant, keeps a bounded event timeline, limits stale intervals, and compares intervals with transcript timing. Native two-person fallback naming is qualified by self identity, roster size and freshness; it is separate from voice recognition. The extension's sole-remote fallback uses a cached participant, with no expiry check in the inspected accessor; it must not inherit the native freshness guarantee. Attribution is applied to system audio. The public docs corroborate Zoom desktop Accessibility and the two Meet routes; Zoom web is unsupported for these speaker tags. [G-D06](integrations/granola-desktop.md), [official speaker tags](https://docs.granola.ai/help-center/taking-notes/speaker-attribution), [Zoom](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-zoom), [Meet](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-google-meet)

## Wispr: correlate desktop observations with acoustic speaker IDs

The shipped desktop path asks its native helper to poll speaker state, supplying a platform, target process and Meet marker/tile classes. JavaScript receives `MeetingSpeakerChange`, aligns observations to transcription timing, rejects stale or unmatched observations for naming, and maintains a mapping from system-audio speaker IDs to display names. It retains an observation log and includes qualification before promoting or changing a name mapping. This is stronger evidence of implementation than merely finding Zoom or Meet strings in a binary. [Wispr findings](integrations/wispr.md)

Public Wispr guides describe both a simple live You/Them experience with post-stop refinement and a live transcript that can show numbered or named speakers when available. Preserve this documentation/rollout uncertainty: the presence of a shipped path does not mean it is enabled for every account. [Official-docs study](integrations/platform-docs.md)

## Ghost Pepper, Monologue, and VoiceInk: avoid false equivalence

Ghost Pepper's pinned source establishes two independent name systems: calendar/OCR attendee candidates and acoustic saved-voice identity. The followed diarization function receives audio and session identity, not the OCR attendee list or Zoom participant IDs. Its live capture is Me/Others, with remote speaker tagging after stop. This is useful for an OSS local-model design, but it does not reproduce Granola's live UI-based attribution. [GP-I01–GP-I05](integrations/oss.md)

Monologue's shipped calls establish microphone activity discovery and a mixed CoreAudio system tap. Neither proves remote active-speaker tracking. Bundled diarizer classes and product claims alone do not establish the invoked model, timing, or automatic real-name mapping. VoiceInk's OCR path gathers writing context rather than meeting participants; its bounded source search found no meeting attribution pipeline. [Monologue](integrations/monologue.md), [VI-I01–VI-I02](integrations/oss.md)

## Official platform options

The following are DOCUMENTED alternatives for our evaluation, **not evidence that a reference app uses them**. The [platform study](integrations/platform-docs.md) preserves access requirements, exact methods and sources.

| Interface | What is documented | Boundary for our product |
| --- | --- | --- |
| Zoom Apps SDK | `onActiveSpeakerChange` supplies timestamped users; role restrictions apply. | Runs as a Zoom App in its embedded browser. It is not a generic observer for an arbitrary external process. |
| Zoom Meeting SDK | Embeds a meeting client; custom UI can follow an active speaker in that joined session. | Current overview directs AI notetaker/realtime-media use toward RTMS. Do not assume this observes an independent Zoom Workplace process. |
| **Zoom Plugin SDK** | Native IPC with separately installed Zoom Workplace, plus participant roster APIs. Requires supported Workplace and OAuth scope. | Promising direct native route. This pass did not establish a documented active-speaker callback or raw-media stream; mute state is insufficient. |
| Zoom RTMS | Realtime media and `ACTIVE_SPEAKER_CHANGE` with user ID/name/timestamp. | Requires an authorized platform integration and applicable account/host/policy access; adds a service path. |
| Meet REST / Workspace Events | Conference, participant and artifact lifecycle. | The inspected event list does not offer active-speaker-change events. |
| Meet Media API | Realtime media with participant/source mappings. | Current developer preview is closed to new signups; not an immediately available general-purpose dependency. |

Sources: [Zoom Apps](https://appssdk.zoom.us/classes/ZoomSdk.ZoomSdk.html#onActiveSpeakerChange), [Meeting SDK](https://developers.zoom.us/docs/meeting-sdk/macos/), [Plugin SDK](https://developers.zoom.us/docs/plugin-sdk/macos/), [RTMS](https://developers.zoom.us/docs/rtms/), [Meet events](https://developers.google.com/workspace/events/guides/events-meet), [Meet Media API](https://developers.google.com/workspace/meet/media-api/guides/overview).

## Candidate requirements for our product

These are **PROPOSED implications**, not new user commitments or selected architecture. They build on the user's explicit local history, reprocessing, composability and self-hosting requirements.

1. Preserve separate capture channels and a timestamped observation journal before deriving a transcript. Record clock domain, source time, receipt time, adapter/version, participant ID/name, confidence and blind/stale reasons.
2. Keep acoustic speaker identity, meeting participant identity and saved person identity separate. Store corrections and supporting evidence; retain unknown speakers when a mapping is weak.
3. Make meeting detection, audio capture, roster extraction and speaking-state observation independent capabilities. A broken name adapter must not stop durable audio capture or hide a missing system channel.
4. Allow local AX/DOM adapters and optional authorized platform connectors behind the same observation contract. Local capture/processing and remote/self-hosted processing should consume the same retained inputs.
5. Expose observation/reprocessing events through documented hooks, CLI and MCP without making an integration's transient UI state the only retained source of truth.
6. Show degraded states clearly: microphone only, name observation unavailable, stale roster, overlap ambiguous, or queued for reprocessing. A plausible-looking wrong name is worse than a visible unknown.

A browser/native companion remains necessary for a DOM/AX route even when inference runs on exe.dev or Unraid. A hosted model cannot inspect the user's local meeting UI without a local producer. These are architectural implications of the observed boundaries, not a deployment decision.

## Question closure and next validation

| Question | Status in this pass | Remaining evidence needed |
| --- | --- | --- |
| How do Granola/Wispr get candidate active speaker names? | Partially answered: extension extraction and desktop transport/mapping established; native extraction incomplete. | Granola Zoom active-speaker predicate/version gate, Wispr native Zoom/Meet traversal; live supported-version/layout tests and account feature availability. |
| How does audio become a named transcript? | Granola/Wispr timing paths and Ghost Pepper source pipeline answered statically. | Real overlap, diarization and timing accuracy; Monologue's remaining attribution path. |
| Does a calendar/OCR roster prove active-speaker attribution? | Answered: no; Ghost Pepper's inspected routes are separate. | Any future path linking those identities requires its own evidence. |
| Does every reference app use a Zoom/Meet SDK? | No such general claim is supported. | Bounded findings cannot prove absence across all backends/dependencies. |
| Can official APIs replace UI observation? | Partially answered; platform access/capabilities vary. | Zoom Plugin SDK speaker callback/media capability spike; actual RTMS eligibility; Meet preview access. |
| Is the mechanism robust enough for our requirements? | Unresolved; no runtime quality claim. | Controlled synthetic calls and fault/recovery tests. |

Useful controlled cases: two participants, a third joining/leaving, duplicate display names, rename, shared microphone/room, overlapping speech, pinned speaker/gallery/Picture-in-Picture, minimized/hidden windows, two Meet tabs, multiple browser profiles, localized UI, denied/revoked permissions, helper/extension disconnect, sleep/wake, audio-device changes, unrelated system playback, disk-full and interrupted writes. Measure audio sample time versus UI/service observation time, wrong-name rate, unknown rate, and retained recovery inputs. These tests have not been run.

## Evidence preservation and limitations

The [integration manifest](data/integrations/manifest.json) links pinned sources, artifact identities, REA Evidence IDs, native addresses and byte anchors. Raw proprietary packages, decompiled output and captured excerpts stay in local capture storage outside the public repository. The original 188-flow subset remains a public-document/source discovery snapshot; this static investigation has a separate source/evidence registry. The later [five-app expansion](additional-apps.md) brings the catalogue to 328 flows, using documentation and pinned OSS source without extending this binary/REA investigation to the new products.

REA produced useful artifact identity, AST and native evidence, but large JavaScript analyses have explicit resource and semantic-coverage limits. Manual inert code-path reading supplies the narrowed mechanism findings where REA graph expansion was incomplete. ASAR native-member integrity discrepancies are retained, not silently treated as validated. Matching source tags and installed version strings do not prove reproducible binary/source equivalence. Full ledgers state each boundary.
