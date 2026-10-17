---
status: draft
doc_type: research
summary: "Anarlog flow inventory AN-F01–AN-F25 from current docs and pinned community source; Char, enterprise and mobile boundaries explicit."
created: 2026-10-12
updated: 2026-10-12
---

# Anarlog (formerly Hyprnote): documented product and flow inventory

Anarlog is the strongest additional open-source meeting-notebook reference found in this expansion: it combines on-device capture, personal memos, editable transcripts, model choice and agent interfaces. This is an assessment of reference value against this project's requirements, not an accuracy or UX benchmark. Research date: **2026-10-12**. The companion catalogue contains **25 flows and 35 sources**.

**Evidence:** DOCUMENTED means first-party procedural documentation. SOURCE-DERIVED means behavior read from pinned public source or an in-repository change record; it does not prove a shipped build exhibits it. MARKETING means a vendor product claim. INFERRED marks analysis. No app/account, binary, live meeting, microphone or user data was accessed. No runtime or performance validation occurred.

## Identity and availability

The former `fastrepl/hyprnote` repository redirects to `fastrepl/anarlog`. Its current README identifies a maintained MIT community meeting notetaker and separately licensed commercial enterprise components. The team is also building **Char**, whose private-beta website describes a broader agentic notepad. Char's demonstrations are not Anarlog capabilities. The source examined here is pinned to desktop release **1.4.30**, commit **fd841ca6b9d42f3c34a287a346726a7d1dd3805a**, released October 11. [AN-S01](https://github.com/fastrepl/anarlog), [AN-S02](https://github.com/fastrepl/anarlog/releases/tag/desktop_v1.4.30), [AN-S34](https://char.com/).

macOS builds support Intel and Apple Silicon on macOS 15+. Windows and Linux are explicitly beta. iOS TestFlight and Android beta are documented. The repository includes a Watch companion and mobile 0.1.5 change record; this study did not establish a publicly shipped Watch app. Desktop uses Tauri/React/Rust, so “native capture” must not be mistaken for a wholly AppKit/SwiftUI interface. [AN-S03](https://docs.anarlog.so/desktop-installation), [AN-S01](https://github.com/fastrepl/anarlog).

## Surfaces and components

These are documented functional surfaces and source-derived mobile surfaces, not a visual reconstruction.

| Surface | Components and important states | Sources |
| --- | --- | --- |
| Setup and demo | Permissions, optional account, Welcome demo, provider setup | AN-S03, AN-S04 |
| Library and calendar | Upcoming/recent notes, tabs, calendar links, folder rules, people/organizations | AN-S04, AN-S05, AN-S35 |
| Meeting workspace | Memos, Summary, Transcript, record/stop/resume, source warning and Retry | AN-S06, AN-S08, AN-S10 |
| Transcript correction | Write mode, segment/word selection, speaker picker, Apply to all, re-transcribe | AN-S10 |
| Summary and Chat | Templates/Auto format, dictionary, suggested prompts, expandable activity, proposed changes | AN-S11, AN-S15 |
| Sharing | Suggested invitees, access levels, link replacement, optional audio, anchored comments | AN-S16 |
| Settings | Independent AI stages, retention, calendar, sync/key/device states, imports, developer tools | AN-S05, AN-S09, AN-S17, AN-S18 |
| Automation builder | Starter library, ordered actions, result preview, destination, enabled/last-run/error states | AN-S25 |
| Mobile beta | Note list, create/listen controls, memo/output views, retry and sync state | AN-S26, AN-S27 |
| Watch source | Record control, meter, microphone errors, pending transfer count and account/transfer state | AN-S28, AN-S29 |

## Flow catalogue

**AN-F01 — Install and try a private demo** (macOS 15+; Windows/Linux beta; DOCUMENTED). Install matching build; grant microphone/system audio; optionally sign in; open Welcome note; Join & record; stop and inspect views. **Result:** Demo creates a concrete note/transcript/summary experience. **Limit:** Local provider setup still needed for offline processing; no permissions or demo tested. [AN-S03](https://docs.anarlog.so/desktop-installation), [AN-S04](https://docs.anarlog.so/quickstart).

**AN-F02 — Connect calendars and recurring filing** (Desktop; Apple Calendar on Mac; DOCUMENTED). Connect Apple Calendar or authorize Google/Outlook; enable calendars; open an event; assign a folder and optionally Auto-add future recurrences. **Result:** Event links and participant context accompany meeting notes. **Limit:** Cloud calendars require sign-in; folder rules remain device-local; removing an account preserves existing notes. [AN-S05](https://docs.anarlog.so/calendar).

**AN-F03 — Record a scheduled or ad-hoc conversation** (Desktop; DOCUMENTED). Open event or New Note; choose Join & record or Record; write Memos while microphone and computer audio are captured. **Result:** One note contains personal writing and captured conversation. **Limit:** No participant bot; recording depends on OS access and selected engine. [AN-S06](https://docs.anarlog.so/meetings).

**AN-F04 — Configure automatic start and meeting reminders** (macOS/Linux detection; desktop scheduling; DOCUMENTED). Enable scheduled start/join or sustained-microphone reminders; choose delay/exclusions; optionally stop on microphone release and capture/disclose chat. **Result:** Calendar starts or reminders reduce missed meetings. **Limit:** Overlaps are skipped; microphone reminders do not auto-record; auto-stop can misfire on device changes. [AN-S07](https://docs.anarlog.so/automatic-capture).

**AN-F05 — Finish and resume an existing conversation** (Desktop; DOCUMENTED). Stop listening; review completed output; later choose Resume listening from Transcript. **Result:** Related recording continues in the same meeting note. **Limit:** Retention may remove audio; multiple-session timeline behavior untested. [AN-S06](https://docs.anarlog.so/meetings), [AN-S10](https://docs.anarlog.so/notes).

**AN-F06 — Repair one failed audio source** (Desktop 1.4.30+; DOCUMENTED). Inspect unavailable mic/system-source warning; correct device or permission; press Retry. **Result:** Working channel keeps recording while failed source restarts. **Limit:** Retry cannot recover audio never captured; no crash/storage fault tests performed. [AN-S08](https://docs.anarlog.so/troubleshooting).

**AN-F07 — Choose local or remote models independently** (Desktop; local choices hardware-dependent; DOCUMENTED). Select Transcription provider/model; independently configure Intelligence; use on-device speech plus local LLM server when desired. **Result:** Capture, transcription and generation have explicit processing destinations. **Limit:** Some engines are after-recording only; model/language/timestamp support differs; hosted web search can still send queries. [AN-S09](https://docs.anarlog.so/models-and-providers).

**AN-F08 — Steer and regenerate a summary** (Desktop; DOCUMENTED). Write memo context; choose named template or edit Auto format; add dictionary terms; explicitly regenerate. **Result:** Summary follows selected structure and available context. **Limit:** Changing template alone does not regenerate; quality and version rollback untested. [AN-S11](https://docs.anarlog.so/customize-summaries).

**AN-F09 — Correct transcript words and speaker assignments** (Desktop after capture; DOCUMENTED). Enter Write mode; edit words; save; select labels or a text range to reassign speaker; apply globally where appropriate. **Result:** Human corrections repair transcript content and speaker mapping. **Limit:** Correction fidelity and cross-generation history untested. [AN-S10](https://docs.anarlog.so/notes).

**AN-F10 — Re-transcribe retained audio** (Desktop; DOCUMENTED). Preserve wanted transcript externally; right-click Transcript; re-transcribe with selected engine; review replacement. **Result:** Existing recording produces a new current transcript. **Limit:** Current transcript is permanently replaced; deleted audio cannot be used; immutable generations not established. [AN-S10](https://docs.anarlog.so/notes), [AN-S18](https://docs.anarlog.so/data-and-privacy).

**AN-F11 — Import audio or timed text** (Desktop; DOCUMENTED). Create/open empty note; upload or drop audio, or upload SRT/VTT; keep app open while configured providers process it. **Result:** External media or timed transcript becomes a meeting note. **Limit:** Transcript-only import contains no audio; absent provider or unsupported file blocks processing. [AN-S12](https://docs.anarlog.so/import-recordings).

**AN-F12 — Migrate another meeting library** (Desktop; DOCUMENTED). Export supported source data; open Imports; choose files or supported official connection; review imported/matched/conflict/error counts. **Result:** Available text metadata and speakers enter the library without duplicating matches. **Limit:** Text-based migration does not copy original audio/video; conflicts require review. [AN-S13](https://docs.anarlog.so/imports).

**AN-F13 — Import Zoom cloud meeting text** (Desktop; approved Zoom test accounts; DOCUMENTED). Sign in; connect recording-owner Zoom account through Imports; authorize; keep app open or Sync now; inspect imported notes. **Result:** Available cloud-recording transcripts/summaries become notes. **Limit:** External access awaits Zoom review; scans about six months; no audio/video copied; not a live speaker API. [AN-S14](https://docs.anarlog.so/zoom).

**AN-F14 — Recall and organize meeting context with Chat** (Desktop; DOCUMENTED). Open note and Chat; ask or drag another meeting as context; inspect Activity; ask for history or folder organization; review proposed edits. **Result:** Answers and follow-up drafts use selected meeting context. **Limit:** No removable context chips; new chat needed to reset history; answer correctness untested. [AN-S15](https://docs.anarlog.so/chat).

**AN-F15 — Share a summary with controlled access** (Desktop/web; Pro; DOCUMENTED). Open Share on summarized note; review invitees and access; invite/email/link; optionally add retained audio; later revoke or replace link. **Result:** Others receive an authorized summary with optional collaboration. **Limit:** Private memo excluded; opening panel alone sends nothing; suggested attendees must be reviewed before Invite. [AN-S16](https://docs.anarlog.so/sharing).

**AN-F16 — Export a portable meeting** (Desktop; DOCUMENTED). Choose Export with desired sections and PDF/text/Markdown/Org, or use CLI complete Markdown/JSON export. **Result:** A meeting becomes a portable artifact. **Limit:** Export content differs between GUI and CLI; full raw-audio backup is separate. [AN-S10](https://docs.anarlog.so/notes), [AN-S21](https://docs.anarlog.so/reference/cli).

**AN-F17 — Sync notes and add another device** (Desktop and supported mobile beta; Pro; DOCUMENTED). Sign in on new device; keep existing synced device online for encrypted key transfer; wait for notes; configure providers separately. **Result:** Supported note/transcript/participant data becomes available on the new device. **Limit:** Fresh Pro login auto-enables sync; saved audio/attachments and new folders/tags/daily notes do not sync; lost keys unrecoverable. [AN-S17](https://docs.anarlog.so/sync).

**AN-F18 — Control audio retention and preserve originals** (Desktop; DOCUMENTED). Choose audio retention from no-save through Forever; copy required recording before expiry. **Result:** Retained local audio remains available for future processing. **Limit:** Temporary recovery is bounded; deletion leaves text but removes repair input; on-device storage alone is not a backup. [AN-S18](https://docs.anarlog.so/data-and-privacy).

**AN-F19 — Dictate into another app and recover failed insertion** (Desktop; Pro; DOCUMENTED). Enable Dictation; choose shortcut/mic/provider; hold-release or toggle; if insertion fails choose Copy last dictation and paste. **Result:** Speech enters focused accessible text field. **Limit:** Five-minute cap; paused during meetings; last result is in memory until disable/quit; CLI/MCP do not start dictation. [AN-S19](https://docs.anarlog.so/dictation).

**AN-F20 — Query history through the CLI** (Desktop CLI; DOCUMENTED). Install bundled CLI or build source; run doctor; query meetings; read bounded transcript pages or export complete record with JSON output. **Result:** Scripts access local meeting data with explicit source/path options. **Limit:** GUI initializes DB; local and cloud differ; no XDG compliance established. [AN-S20](https://docs.anarlog.so/installation), [AN-S21](https://docs.anarlog.so/reference/cli).

**AN-F21 — Connect an agent and review staged edits** (Local stdio MCP; optional hosted OAuth; DOCUMENTED). Connect local MCP or explicitly enable readable Cloud API snapshots; list/read context; stage local memo/summary proposal; review/apply in desktop. **Result:** Agent context and edits have source and review boundaries. **Limit:** Hosted MCP read-only; readable cloud snapshots are separate from encrypted sync; no arbitrary desktop control. [AN-S22](https://docs.anarlog.so/agents/mcp), [AN-S23](https://docs.anarlog.so/reference/api-cloud).

**AN-F22 — Subscribe to signed meeting events** (Desktop; all plans; DOCUMENTED). Add HTTPS endpoint in Developers→Webhooks; save secret; test; receive completed/enhanced events; verify signature and deduplicate. **Result:** External automation receives meeting payloads. **Limit:** App must run; closed-app events dropped; retries limited; delivery not tested. [AN-S24](https://docs.anarlog.so/reference/webhooks).

**AN-F23 — Automate follow-up and Markdown vault export** (Desktop; Pro; DOCUMENTED). Choose starter or build trigger/actions; configure destination; review preview; Save & enable; inspect last run and retry failures. **Result:** Meetings produce local Markdown or connected-service updates. **Limit:** App must run; no closed-app queue/backfill for Drive; unrelated-file collisions rejected; exported content can be overwritten on regeneration. [AN-S25](https://docs.anarlog.so/automations).

**AN-F24 — Capture and recover a mobile beta note** (iOS/Android beta; SOURCE-DERIVED). Use Start listening or create a note; review/edit memo and outputs; retry transcription/summary when needed; allow background sync to finish. **Result:** Mobile conversation and edits can join the note library. **Limit:** Source/release-note evidence only; not device-tested; mobile0.1.5 needs compatible sync versions and iOS background time is bounded. [AN-S03](https://docs.anarlog.so/desktop-installation), [AN-S26](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/packages/changelog/content/mobile/0.1.5.md), [AN-S27](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/apps/mobile/src/app/index.tsx).

**AN-F25 — Record on Watch and transfer after phone acknowledgement** (watchOS companion source; SOURCE-DERIVED). Grant mic; start/stop local recording; queue file through WatchConnectivity; retain pending entry until phone import acknowledgement. **Result:** Source implements recording plus acknowledged handoff. **Limit:** No public shipped watch release established; deletes watch file after acknowledgement; crash durability and duplicate-import behavior untested. [AN-S28](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/apps/watch/apple/AnarlogWatch/RecordingController.swift), [AN-S29](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/apps/watch/apple/AnarlogWatch/WatchSyncController.swift).

## Zoom and Google Meet: mechanisms and evidence limits

| Layer | What this study established | What remains unknown |
| --- | --- | --- |
| Meeting detection | Docs describe sustained microphone activity and calendar timing. Mac needs Accessibility for meeting detection/mute sync. Source exposes platform, PID, window title, active-call and remote-screen-share inspection. | Runtime browser/app/version coverage and false detection rates. |
| Audio | Documented microphone plus computer audio, without joining the call. | Exact capture API/routing in the installed release; packet loss, echo and disconnect behavior. |
| Attendee identity | Calendar events provide participant metadata; transcript UI permits participant assignment. | Whether names from visible meeting tiles are ever used elsewhere in the app. |
| Live active speaker | No active-speaker-name event/result was found in the bounded AX files inspected. Those interfaces cover active call, visible chat and screen sharing. | This does not prove global absence. A complete call graph/runtime trace is still needed before claiming no active-speaker pipeline. |
| Zoom mute state | Pinned `zoom.rs` reads AX menu labels for Mute/Unmute Audio and polls at one-second intervals while Zoom uses the microphone. | Localization/app-version compatibility; mute state is not the identity of a remote speaker. |
| Diarization | Docs describe provider-dependent speaker labels, on-device embeddings and local after-call refinement. Pinned batch code plans mic/system channels, passes known voice embeddings into acoustic diarization and applies labels. | Accuracy, shared-room behavior and voice-to-person match quality. |
| Zoom import | A separate OAuth connection imports text from cloud recordings. Access is limited to approved test accounts pending Zoom review. | General marketplace availability. This path is not live speaker observation. |

The AX API's result fields are at `crates/detect/src/meeting_ax/types.rs:60`; `meeting_ax.rs` exposes inspection and chat capture/send. Zoom's menu reader starts at `zoom.rs:72`. The batch diarizer's `plan_channel` starts at `diarize.rs:82`, and known-voice input plus label application are around lines 287–324. These code anchors establish concrete bounded behavior without treating an API name as a verified live integration. [AN-S30](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/crates/detect/src/meeting_ax/types.rs), [AN-S31](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/crates/detect/src/meeting_ax.rs), [AN-S32](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/crates/detect/src/zoom.rs), [AN-S33](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/crates/listener2-core/src/batch/diarize.rs). Detection and recording claims above come from [AN-S07](https://docs.anarlog.so/automatic-capture), [AN-S06](https://docs.anarlog.so/meetings), roster from [AN-S05](https://docs.anarlog.so/calendar), diarization from [AN-S09](https://docs.anarlog.so/models-and-providers), and import from [AN-S14](https://docs.anarlog.so/zoom).

## Local processing, self-hosting and composability

Anarlog separates audio transcription from text intelligence. Local selections can use supported on-device models or compatible local-network services. Optional hosted AI, calendars, collaboration, sync and remote agents introduce separate egress boundaries. Local app operation and source availability are established; a turnkey independently deployable equivalent of all hosted services on exe.dev/Unraid is **not** established. [AN-S09](https://docs.anarlog.so/models-and-providers), [AN-S01](https://github.com/fastrepl/anarlog).

The CLI/local MCP are useful composability references: explicit database paths, source selection, JSON contracts, bounded reads and proposals. They are not universal command coverage: desktop dictation is excluded. Current CLI docs additionally describe managed-preservation exports and conditional deletion, but those specialized contracts were not implemented or tested here. Documented webhooks have finite retries and drop closed-app events. These limitations matter if the proposed product promises durable hooks. [AN-S21](https://docs.anarlog.so/reference/cli), [AN-S22](https://docs.anarlog.so/agents/mcp), [AN-S24](https://docs.anarlog.so/reference/webhooks), [AN-S19](https://docs.anarlog.so/dictation).

There is no established iOS custom keyboard, outbound PSTN calling, XDG dotfile contract, or iCloud integration in this bounded inventory. Folder/Markdown export and CLI path overrides should not be relabeled as those features.

## Retention and recovery implications

**INFERRED design lessons:** keep original audio and every derived generation separate; make raw capture health visible per source; retain a local transcription backlog through provider failure; treat sync and original-audio backup as distinct products; require durable event queues when promising reliable automation.

Anarlog offers retained audio but permits immediate/aged deletion; re-transcription replaces current text. Watch source persists a pending queue and removes the local file only after an import acknowledgement. That acknowledges a useful transfer boundary, but does not meet this user's stronger “always retain history on device” requirement on Watch and does not establish crash-proof persistence. [AN-S18](https://docs.anarlog.so/data-and-privacy), [AN-S10](https://docs.anarlog.so/notes), [AN-S29](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/apps/watch/apple/AnarlogWatch/WatchSyncController.swift).

## Native UX and second-brain reference value

**INFERRED:** the strongest ideas are a note useful before/during/after a call, independent human memo and generated content, keyboard transcript repair, reviewed diffs for agent edits, source-aware recall, calendar-linked filing and one-way vault export. Contacts and organizations give meetings durable human context; the CRM enrichment UI fills missing fields while preserving user-entered values. [AN-S04](https://docs.anarlog.so/quickstart), [AN-S10](https://docs.anarlog.so/notes), [AN-S15](https://docs.anarlog.so/chat), [AN-S25](https://docs.anarlog.so/automations), [AN-S35](https://docs.anarlog.so/contacts).

These are flow references. Menu behavior, typography, animation, VoiceOver, Dynamic Type, keyboard completeness, energy use and small-screen polish remain untested. The research does not establish Apple Design Award-level execution.

## Conflicts and next evidence gaps

- **Sync default differs by source.** README describes cloud as optional/off by default; the dedicated sync guide says a fresh Pro sign-in starts sync automatically. Preserve the account-specific behavior rather than claim an unconditional off default. [AN-S01](https://github.com/fastrepl/anarlog), [AN-S17](https://docs.anarlog.so/sync).
- **Storage setup drift.** Quickstart says choose local storage; the dedicated sync guide says app-managed storage is current and describes migration from earlier custom folders. Use the dedicated guide as the documented current behavior while retaining the conflict. [AN-S04](https://docs.anarlog.so/quickstart), [AN-S17](https://docs.anarlog.so/sync).
- **Sync is narrower than the library.** Audio/files remain local, as do new daily notes/folders/tags in the current rollout. Mobile change records discuss background recording uploads but do not establish universal desktop attachment sync. [AN-S17](https://docs.anarlog.so/sync), [AN-S26](https://github.com/fastrepl/anarlog/blob/fd841ca6b9d42f3c34a287a346726a7d1dd3805a/packages/changelog/content/mobile/0.1.5.md).
- **Distribution versus source.** Desktop has a dated release; mobile has beta links/change records; Watch was studied from source. None was installed. No private-beta Char behavior was borrowed.
- **Unknown recovery.** Crash/power-loss recovery, low-disk behavior, provider-retry deduplication, migration rollback, editable history integrity and simultaneous multi-device conflicts need fault-injection or hands-on tests. No zero-loss claim is justified.
- **Scope.** This inventory covers the requested capture/notes/model/automation/recovery surfaces. It does not exhaust billing, enterprise administration, collaboration policy, every connector or every command. Open-source license scope should be reviewed per component before reuse.
