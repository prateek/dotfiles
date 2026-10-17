---
status: draft
doc_type: research
summary: "Documentary evidence from Zoom and Google Meet platform documentation on rosters, active speakers and official APIs."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence ledger for the static meeting-integration investigation; no live meeting tested."
related:
  - ../meeting-integrations.md
---

# Zoom / Google Meet documentary evidence

Accessed 2026-10-12. This branch inspected official public documentation and release notes only. No accounts, live meetings, backend calls, installed apps, or proprietary binary internals were inspected. Parent/other branches own artifact evidence. DOCUMENTED means vendor documentation supports the statement; it is not runtime verification.

## Keep these signals separate

1. **Meeting detection:** a call app using a microphone, a matching window/tab, or an upcoming calendar event. This can suggest when to offer capture without identifying the speaker.
2. **Audio source separation:** microphone versus system output. This identifies the capture source, not each remote participant.
3. **Diarization:** audio processing groups speech by speaker. Speaker 1 need not yet have a real name.
4. **Active-speaker metadata:** a meeting app's current-speaker UI or API signal. It is time-varying and can be incomplete during overlap or shared-room participation.
5. **Identity mapping:** connecting a source/cluster/platform participant to a display name/contact. Calendar invitees provide candidates, not proof they attended or spoke.

The last sentence is an analytical distinction, not a claim about a particular proprietary implementation.

## Granola

**DOCUMENTED: direct interface-derived speaker attribution.** Granola explicitly says speaker tags read participant display names and active-speaker information from meeting interfaces. macOS Accessibility supplies this information; its Meet extension is an alternative. The permission is not the mechanism for audio capture. Without tags, Me/Them represent microphone/system audio. Shared-room speakers and overlap remain ambiguous. Names do not retroactively appear in older transcripts. [Speaker tags](https://docs.granola.ai/help-center/taking-notes/speaker-attribution)

**DOCUMENTED: Zoom desktop only for this feature.** Zoom Workplace on macOS/Windows is supported; Zoom web is not. macOS requires Accessibility, and no browser extension is needed. The docs explicitly attribute names to Zoom's current-speaker and display-name signals, without documenting exact accessibility attributes or timing rules. [Zoom setup](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-zoom)

**DOCUMENTED: Meet has two paths.** Accessibility supports Google Meet in Google Chrome. The extension supports Chrome and supported Chromium browsers, including Edge, Arc, Brave. It must be installed in the same profile as the call, with Granola desktop open. Either path suffices. Missing clear active-speaker information can leave segments unnamed. [Meet setup](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-google-meet)

**Artifact acquisition lead:** official help links to [Granola Companion on Chrome Web Store](https://chromewebstore.google.com/detail/granola-companion/opaadbjlebbbnmjjgdmdllingedoleml), ID `opaadbjlebbbnmjjgdmdllingedoleml`. Store page reports version `0.4.18`, updated September 18, 2026. This is an official publisher-linked artifact, not an unrelated extension.

**DOCUMENTED: detection is another layer.** Ad-hoc prompts arise when the microphone is in use, with the calling app named. Calendar prompts open the event's call URL and note. A call within 15 minutes after a scheduled meeting can be associated with that calendar event. This does not establish utterance identity from the calendar. [Notifications](https://docs.granola.ai/help-center/taking-notes/notifications)

**DOCUMENTED: capture differs from metadata.** Granola captures microphone and combined system audio, rather than isolating each application's output. Docs say audio is passed to a transcription provider without saved recordings. Auto-stop combines call software/microphone state, transcript length, and optionally calendar end time; back-to-back calls can be merged if mic use persists. These choices conflict with this project's retained-original requirement. [Transcription](https://docs.granola.ai/help-center/taking-notes/transcription)

**UNKNOWN from docs:** exact accessibility attributes/tree traversal, DOM selectors, extension-native transport, clocks and drift handling, active-speaker smoothing, transcript association logic, or fallback diarization implementation.

## Monologue by Every

**DOCUMENTED:** Notes on Mac can capture microphone plus optional system audio. System audio requires Screen Recording permission; without it capture can continue mic-only. Meeting reminders trigger when a supported calling app starts using the microphone and can be suppressed per app. [Record a Voice Note](https://www.monologue.to/docs/voice-notes/record-a-note)

**DOCUMENTED:** completed Notes let people name detected speakers, identify themselves, and regenerate summaries. [Organize, edit, share](https://www.monologue.to/docs/voice-notes/organize-edit-and-share)

**UNKNOWN:** reviewed documentation does not establish Zoom/Meet active-speaker UI scraping, a platform SDK, participant roster extraction, diarization model, or automatic real-name mapping. “Detected speakers” is insufficient to prove those mechanisms.

## Wispr Flow

**DOCUMENTED:** Notetaker supports microphone/system capture with distinct failure states; mic failure can leave only other participants recorded. Optional meeting detection/auto-start has availability gates and can be cancelled by a missing browser meeting tab or lost meeting signal. Docs do not identify the exact app-detection implementation. [Recording a meeting](https://docs.wisprflow.ai/articles/9238501024-recording-a-meeting-with-notetaker-beta)

**DOCUMENTED, with documentation tension:** the editor guide describes live Them/You and names after post-stop refinement. Unmatched speakers remain numbered; users can assign contacts, and calendar attendees can populate contacts where meeting details are absent. Shared microphones and identical meeting-app names impede identification. [Meeting editor](https://docs.wisprflow.ai/articles/9406970664-Meeting-notes-and-the-editor-in-Notetaker)

The separate transcript guide says live views may use You/Others or numbered speakers, replacing numbers with names when available; after resume one person can receive a new number. Do not flatten these into a universal live-naming guarantee. [Live transcript](https://docs.wisprflow.ai/articles/4091106439-The-live-transcript-in-Notetaker)

**UNKNOWN:** whether any automatic name inference uses AX, DOM, SDK, cloud inference, or a combination. Current docs alone do not prove implementation or a specific diarization model.

## Ghost Pepper

**DOCUMENTED, release-specific:** v2.3.0 notes say Detect reads Zoom/Teams meeting window titles and OCRs names from video tiles, retrying at 3/15/30/60 seconds. Separately they advertise persistent local speaker profiles, voice recognition, speaker-tagged transcription reruns and diarization fixes. The OCR attendee list is not proof of time-aligned active-speaker detection. [v2.3.0](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0)

v2.2.0 also describes Zoom-window-close auto-stop and detecting native meeting apps during manually started recording. [v2.2.0](https://github.com/matthartman/ghost-pepper/releases/tag/v2.2.0)

**UNKNOWN from release notes:** exact attribution pipeline, whether Google Meet uses an equivalent path, or whether active-speaker visual indicators are tracked. Use other branch's pinned source evidence for those claims.

## VoiceInk

**DOCUMENTED:** file import/batch transcription exists. That path does not establish live conference capture or speaker identity. [File transcription](https://tryvoiceink.com/docs/transcribe-audio-files)

**UNKNOWN:** reviewed official product/help sources establish no Zoom/Meet active-speaker integration. This is scoped absence of evidence, not proof none exists in shipped/current code.

## Official Zoom integration choices

### Zoom Apps SDK: embedded Zoom App, role-gated

**DOCUMENTED:** `zoomSdk.onActiveSpeakerChange` returns active speakers; reference lists Host/Co-Host, no Guest Mode. `onMyActiveSpeakerChange` reports the current user's speech and allows Participant/Panelist too. This JavaScript SDK runs against APIs exposed by Zoom's embedded browser. It is not a generic API injected into an arbitrary external browser/app. [SDK reference](https://appssdk.zoom.us/classes/ZoomSdk.ZoomSdk.html#onActiveSpeakerChange)

The event includes `timestamp` and `users`, with each user's `screenName`, `participantUUID`, and timestamp. [Event type](https://appssdk.zoom.us/types/ZoomSdkTypes.OnActiveSpeakerChangeEvent.html)

### Zoom Meeting SDK: in-app meeting session

**DOCUMENTED:** macOS Meeting SDK puts a Zoom meeting client inside your app. Current overview explicitly directs AI notetakers/realtime media use to RTMS and says the SDK is for human use cases, not bots/AI notetakers. [Meeting SDK overview](https://developers.zoom.us/docs/meeting-sdk/macos/)

Its custom-UI `ZoomSDKActiveVideoElement` follows an active speaker after the app joins a meeting; that capability does not prove an external app can observe the already-running separate Zoom client with Meeting SDK. [Render video](https://developers.zoom.us/docs/meeting-sdk/macos/custom-ui/basic-features/render-user-video/)

### Zoom Plugin SDK: important distinct native IPC path

**DOCUMENTED:** Zoom now offers Plugin SDK to connect a native macOS/Windows app directly to separately installed Zoom Workplace over IPC, without bundling the meeting client. Thus a blanket statement that every official integration requires a separately embedded meeting session is wrong. [Plugin SDK overview](https://developers.zoom.us/docs/plugin-sdk/)

Requirements documented: Zoom Marketplace developer account, Workplace 7.0.2+, Xcode 16.1+. [Download/setup](https://developers.zoom.us/docs/plugin-sdk/macos/get-started/)

Authentication uses an OAuth access token with `plugin_sdk:read:connection_meta`, `ZoomToolSuiteAuthContext`, and `ZoomToolSuiteAPI.initSDK(..., listener:)`. [Authentication, official Markdown](https://developers.zoom.us/docs/plugin-sdk/macos/start-join-mtg-webinar/authentication.md)

After joining a meeting, roster access uses `ZoomToolSuiteAPI.Meeting.MeetingAPI.getParticipantsList()`, `ZoomToolSuiteAPI.Meeting.Participants.getMySelf()` / `getUserByUserID`, and `ZoomToolSuiteEventListenerProtocol.onUserStatusChanged`. `ZoomToolSuiteUser` exposes `iUserID`, `strUserName`, `bMyself`; roster action types include add/leave/sync. [User information](https://developers.zoom.us/docs/plugin-sdk/macos/add-features/in-meeting-user-info/)

Audio documentation exposes audio type/mute state and device controls. **UNKNOWN:** this review did not locate a documented Plugin SDK active-speaker callback or raw audio-stream interface. Mute state is not a speech-activity signal. Do not transfer callbacks from Meeting SDK to Plugin SDK by name similarity. [Audio controls](https://developers.zoom.us/docs/plugin-sdk/macos/add-features/in-meeting-audio/)

### Zoom RTMS: explicitly supported realtime streams, access gates

**DOCUMENTED:** signaling event `ACTIVE_SPEAKER_CHANGE = 2` carries `timestamp`, `user_id`, `user_name` with `msg_type: 6`. It describes the primary speaker highlighted in the meeting. Participant join/leave are separate event types. [Session events](https://developers.zoom.us/docs/rtms/event-reference/session-events/), [Data types](https://developers.zoom.us/docs/rtms/data-types/)

Apps need RTMS configuration, subscriptions/scopes and Developer Pack credits. Optional in-client `startRTMS()` and REST session initiation exist. Host policies can allow, require approval, or disallow guest auto-start. The REST path has narrower invitee/already-joined requirements. Continuous media and metadata arrive over established connections; this is no arbitrary local-client observation API. [Stream lifecycle](https://developers.zoom.us/docs/rtms/meetings/work-with-streams/), [Add features](https://developers.zoom.us/docs/rtms/meetings/add-features/)

RTMS participants see disclosure/activity notifications and app names associated with active sharing. [Participant UX](https://developers.zoom.us/docs/rtms/meetings/ux-participant/)

## Official Google Meet integration choices

### Meet REST / Workspace Events: metadata and artifacts

**DOCUMENTED:** REST exposes conference records, participant/session metadata, transcripts and granular transcript entries. A `TranscriptEntry` references a participant and carries text/start/end times. These records can support attributed import, distinct from observing a real-time active-speaker UI. [REST overview](https://developers.google.com/workspace/meet/api/guides/overview), [TranscriptEntry](https://developers.google.com/workspace/meet/api/reference/rest/v2/conferenceRecords.transcripts.entries)

Workspace Events supports conference start/end, participant join/leave, recording/transcript/smart-note lifecycle. The inspected supported-event list has no active-speaker-change event. Invitees have a narrower event set than meeting-space owners. [Meet subscriptions](https://developers.google.com/workspace/events/guides/events-meet)

### Meet Media API: realtime protocol, currently closed preview enrollment

**DOCUMENTED:** the current overview (updated Oct 1 2026) states Developer Preview no longer accepts new signups. API clients connect to conferences for real-time audio/video and participant metadata, subject to admin/host/consenter controls. It is not a generally available arbitrary-browser-observer interface. [Media overview](https://developers.google.com/workspace/meet/media-api/guides/overview)

The API uses WebRTC with `spaces.connectActiveConference()` offer/answer signaling and resource data channels. Current concepts require exactly three receive-only audio descriptions. [Concepts](https://developers.google.com/workspace/meet/media-api/guides/concepts)

Audio `CSRC` identifies the real media source as virtual streams are reassigned; `MediaEntry.audioCsrc`, `participant`, `participantKey`, and `session` connect audio source to participant/session metadata. This is a protocol-level identity path, different from diarizing a mixed system recording. [Media overview](https://developers.google.com/workspace/meet/media-api/guides/overview), [MediaEntry reference](https://developers.google.com/workspace/meet/media-api/reference/dc/media_api.mediaentry)

**UNKNOWN:** suitability and availability for a new OSS application, future preview replacement, complete all-speaker coverage under stream selection, and any live tested behavior. Do not design around access being granted.

## Implications for the project, not architectural decisions

- Preserve separate timestamped evidence for audio channels, UI/API active-speaker observations, roster/name changes, diarization segments, calendar candidates and human corrections. Derivations can be rerun without treating an old guess as ground truth.
- Keep anonymous speaker clusters usable when UI/API/roster permission fails. “Mic captured” and “participant name known” are separate capability/health states.
- Compare an AX/extension local companion path against optional authorized platform connectors. Zoom Plugin SDK merits a targeted capability spike; no approval, login or meeting was performed here.
- Evaluate overlap, duplicate names, renamed users, one room device/multiple humans, hidden/minimized windows, view/layout changes, unsupported browser profiles, back-to-back calls and clock drift.
- User's retained-original requirement differs materially from Granola's documented no-audio-retention behavior. Preserve raw capture plus observation history on device before reprocessing; do not adopt competitor retention by imitation.


[Return to the integration study](../meeting-integrations.md).
