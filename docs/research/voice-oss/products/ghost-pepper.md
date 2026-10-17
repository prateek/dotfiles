---
status: draft
doc_type: research
summary: "Ghost Pepper flow inventory GP-F01–GP-F26 from public project material and version-pinned OSS source."
created: 2026-10-12
updated: 2026-10-12
---

# Ghost Pepper: public user-flow research

Ghost Pepper combines Mac dictation with a meeting and local-knowledge workspace. The user confirmed the target as [matthartman/ghost-pepper](https://github.com/matthartman/ghost-pepper); identity confidence is high. This report maps public evidence, not a proposed product specification.

Research date: 2026-10-12. The latest release endpoint returned **v2.4.4**, published 2026-07-27; its tag resolves to `c212bcc108f178c4a0f184d9da4bdbcb9a205448`. Public source reads below use that release. Current main was `5a5b53aadbc1c1f76968cd1c8a9aff690d076887`, eight commits later. Release notes and website claims are kept separate from code evidence. [GP-S03](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.4)

The 23 retained sources cover 26 flows. DOCUMENTED means explicit official instructions or release notes; MARKETING means a first-party positioning claim; SOURCE-DERIVED means a public-source reading without execution; INFERRED means a conclusion drawn from evidence; UNKNOWN means the reviewed material does not establish a path. No app was installed, account connected, recording made or runtime privacy audit performed. There are no observed screenshots or measured tap counts.

## Boundaries and documentation conflicts

The advertised product requires macOS 14+ and Apple Silicon M1 or later, with an MIT license and no account for core use. No supported iPhone, iPad, Watch, Intel Mac, Windows or Linux product was established. API availability annotations in shared source do not establish an iOS app. RAM and storage requirements beyond model sizes are not comprehensively documented. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S02](https://matthartman.github.io/ghost-pepper/)

Three differences materially affect reconstruction:

- The website/README teaches Control; released onboarding and defaults use Right Command + Right Option. Existing customized bindings add another variable. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S12](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/OnboardingWindow.swift), [GP-S17](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/AppState.swift)
- v2.4.0 announced Anthropic-backed meeting Q&A. v2.4.4 source routes that interaction through a local provider, while optional cloud routes remain. The older release description cannot establish the latest backend. [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0), [GP-S17](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/AppState.swift)
- Main's README lists Nemotron streaming models. The inspected v2.4.4 speech catalog lacks them, so they are not treated as verified released choices. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S14](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Transcription/SpeechModelCatalog.swift)

The website's broad privacy language is MARKETING. The repository's audit narrows the claim to core local functions and identifies network exceptions. Its recorded review date is 2026-04-13, the commit field is unfilled, and it is an AI-generated self-audit. That supports a maintainer claim, not independent verification of the October release surface. [GP-S02](https://matthartman.github.io/ghost-pepper/), [GP-S11](https://github.com/matthartman/ghost-pepper/blob/main/PRIVACY_AUDIT.md)

## Flow catalogue

All flows target the Mac app. Version-specific OS gates appear in the individual descriptions. Preconditions include an installed app and ready models unless the flow is installation or recovery.

### GP-F01: Install and launch

**DOCUMENTED.** Trigger: first use on an Apple Silicon Mac running macOS 14+. Download the DMG, drag the application to Applications, then launch it. The website advertises no required account. The README describes a Privacy & Security override if Gatekeeper blocks opening; v2.4.4 is described as signed and notarized. Intel Macs and other operating systems are outside the documented product boundary. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S02](https://matthartman.github.io/ghost-pepper/), [GP-S03](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.4)

### GP-F02: Complete setup and download models

**SOURCE-DERIVED.** Trigger: first launch. Setup requests Microphone and Accessibility, offers microphone selection with a level check, and loads speech/cleanup models. Continue depends on permissions and required model readiness. A failed download exposes Retry. Screen Recording is optional here; the practice step can be skipped. The optional Granola step appears when Granola is detected. [GP-S12](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/OnboardingWindow.swift), [GP-S05](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.1)

### GP-F03: Choose and test a microphone

**SOURCE-DERIVED.** Trigger: incorrect input or a newly connected device. General settings provides a microphone picker, rescan action and start/stop test dictation. Outcome is an in-settings transcript or error. Release notes confirm the selected mic applies to tests and aggregate devices no longer change the system default. Hardware-specific reliability remains unobserved. [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift), [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0), [GP-S08](https://github.com/matthartman/ghost-pepper/releases/tag/v2.2.0)

### GP-F04: Dictate with hold or toggle

**SOURCE-DERIVED.** Trigger: a text insertion point is ready. Released defaults hold Right Command + Right Option to record; releasing finishes. Toggle adds Space and starts/stops on successive activations. Settings can record replacement shortcuts; conflicting bindings report an error. The README's Control instruction conflicts with released defaults, so it cannot define the current shortcut reliably. [GP-S17](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/AppState.swift), [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift), [GP-S01](https://github.com/matthartman/ghost-pepper)

### GP-F05: Insert text or recover through clipboard

**SOURCE-DERIVED.** Trigger: transcription completes. The paste path checks the focused editor, an enabled Paste menu item, or an allowed application before simulating Command-V. It normally restores earlier clipboard contents afterward. If it cannot establish a paste target or create the keystroke, output remains on the clipboard. This supports manual recovery, but does not establish universal app compatibility. [GP-S16](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Input/TextPaster.swift), [GP-S03](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.4)

### GP-F06: Clean dictated text and customize corrections

**DOCUMENTED.** Trigger: dictation with cleanup enabled. A local model removes disfluencies and resolves spoken corrections. Settings exposes enable/disable, prompt editing/reset and correction hints; hints guide generation rather than deterministic replacement. Optional screen context can inform cleanup. The recorded evidence does not establish language-specific cleanup fidelity or how often meaning changes. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift)

### GP-F07: Choose, download and remove models

**SOURCE-DERIVED.** Trigger: change speed, language coverage or disk use. Select a speech model and cleanup model; inventory indicates preparation, download or readiness. Download controls appear for missing models; removal is restricted to eligible loaded, unselected entries. The website advertises cleanup Qwen sizes from roughly 535 MB to 2.8 GB. Download completion and advertised timings were not benchmarked. [GP-S14](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Transcription/SpeechModelCatalog.swift), [GP-S23](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ModelInventoryViews.swift), [GP-S02](https://matthartman.github.io/ghost-pepper/)

### GP-F08: Dictate in another language

**SOURCE-DERIVED.** Trigger: non-English speech. The released catalog contains English Whisper variants, multilingual Whisper, Parakeet v3 and Qwen3-ASR; Qwen requires macOS 15+. Apple SpeechAnalyzer is gated to macOS 26. Settings offers automatic/system language or an explicit language and warns about non-English selection with English-only Whisper. Code-switching quality and per-model language equivalence are unknown. [GP-S14](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Transcription/SpeechModelCatalog.swift), [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift)

### GP-F09: Recover from permission or input errors

**SOURCE-DERIVED.** Trigger: failed hotkey or recording. Menu-bar errors can offer the relevant Input Monitoring, Accessibility or Microphone settings page; hotkey failures expose Retry, and some input errors expose Reload Audio Input. A no-sound overlay can lead to microphone settings. Exact macOS recovery prompts and persistence after permission revocation require runtime validation. [GP-S15](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MenuBarView.swift), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0)

### GP-F10: Keep, revisit or delete dictation history

**DOCUMENTED.** Trigger: retaining voice-to-text work. Recording history is opt-in; enable it in Settings, then use History to inspect saved work. Releases document search, individual deletion and clearing all history. Released UI distinguishes dictation audio retention from separately saved meeting Markdown. Turning retention off is not documented as deleting older entries. [GP-S09](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.1), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0), [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift)

### GP-F11: Detect a meeting and accept transcription

**DOCUMENTED.** Trigger: a supported calling or video app becomes active, with meeting detection enabled. Ghost Pepper offers transcription; releases list Zoom/Teams and several other native or browser contexts. Meeting transcription became enabled by default in v2.3. Detection also supports manually initiated recordings. Supported-app announcements do not establish behavior for every app version or browser layout. [GP-S08](https://github.com/matthartman/ghost-pepper/releases/tag/v2.2.0), [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0)

### GP-F12: Start an ad hoc recording with participant notice

**SOURCE-DERIVED.** Trigger: a meeting outside detection. Open the meeting workspace from the menu bar and create an ad hoc meeting. A notice dialog offers a copyable participant message, confirmation or cancellation; users can suppress future notices. Start failures can remain in that dialog. This describes the application's UI, not a legal consent determination. [GP-S18](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MeetingTranscriptWindow.swift), [GP-S15](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MenuBarView.swift)

### GP-F13: Capture microphone and system audio, then stop

**SOURCE-DERIVED.** Trigger: an active meeting. Two audio streams feed chunked transcription. The session writes an initial document, saves periodically, warns after sustained silence, and processes remaining audio when stopping before final save. Releases document Zoom auto-stop on window closure. Screen Recording permission is required for system audio; losing one stream may therefore affect participant coverage. [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift) [GP-S19](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Meeting/MeetingSession.swift), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0)

### GP-F14: Identify attendees and speakers

**DOCUMENTED.** Trigger: an active or completed meeting. Detect reads meeting-window information and OCRs participant names; retry passes can catch late joiners. Attendees appear as chips. Voice profiles persist locally to recognize speakers across recordings. These are distinct concepts: a detected attendee list is not proof that every utterance is correctly attributed. [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0), [GP-S08](https://github.com/matthartman/ghost-pepper/releases/tag/v2.2.0)

### GP-F15: Generate and customize a meeting summary

**DOCUMENTED.** Trigger: a completed transcript. Summary supports local generation, a customization control for prompt/model choice and regeneration. User notes can guide topic emphasis. Released UI shows progress, prevents generation while already busy and disables initial generation without transcript segments. Long-meeting truncation, interrupted generation and factual fidelity were not measured. [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0), [GP-S18](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MeetingTranscriptWindow.swift)

### GP-F16: Take meeting notes or create a personal note

**DOCUMENTED.** Trigger: a meeting is open or a standalone thought needs capture. Write in the Notes surface alongside transcript/summary tabs. Quick Notes starts from the sidebar; later releases add Command-N for a personal note. This provides a path to authored material without requiring a recording. Rich-text fidelity, attachments and conflict handling are not established. [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0), [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0)

### GP-F17: Browse and search the library

**DOCUMENTED.** Trigger: return to previous material. The workspace supports multiple open meeting tabs, sidebar name filtering, Command-F within tabs and a Command-K palette across meetings, notes and people. Keyboard navigation is documented for the palette. Neither these announcements nor a source listing establishes full-text search ranking or behavior in very large libraries. [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0), [GP-S09](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.1), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0)

### GP-F18: Use Markdown outside the app

**SOURCE-DERIVED.** Trigger: reuse or archive a meeting. Documents live under the chosen directory in date folders. The writer emits title/date, attendees, user notes, optional summary and timestamped speaker-labelled transcript sections; it also parses Markdown for reopening. This is a file-based interchange path. Dedicated PDF, DOCX, subtitle or audio export was not established. [GP-S20](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Meeting/MeetingMarkdownWriter.swift), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0)

### GP-F19: Import previous Granola meetings

**SOURCE-DERIVED.** Trigger: bring existing Granola content into the library. The released importer asks for a personal API key, fetches notes/transcripts, shows progress and allows background continuation. Success reports counts and adds meetings to the sidebar; errors offer key entry again. v2.4.1 explicitly changed import to API-only, superseding earlier local-cache instructions. [GP-S21](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/GranolaImportView.swift), [GP-S05](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.1), [GP-S09](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.1)

### GP-F20: Connect calendar and start from an event

**DOCUMENTED.** Trigger: a calendar-backed meeting. Releases document today's events, multiple calendars, cached offline data and refresh after recording stops. The connection requires optional Google authorization; v2.4.2 defers token access rather than reading Keychain merely to render connection state. Current source also signals build/beta restrictions, so universal calendar availability remains uncertain. [GP-S18](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MeetingTranscriptWindow.swift) [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0), [GP-S04](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.2)

### GP-F21: Ask questions across meeting knowledge

**SOURCE-DERIVED.** Trigger: a question in the meeting workspace. v2.4.4 routes Q&A through a local model and local knowledge search; a missing runnable model returns an instruction to download one. This supersedes v2.4.0's Anthropic-backed description for this route. Multi-turn interaction is release-documented. Answer quality and complete source attribution were not tested. [GP-S17](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/AppState.swift), [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0)

### GP-F22: Build indexes, dossiers and derived knowledge

**DOCUMENTED.** Trigger: enough meeting material exists to organize. v2.4.0 documents people/topic indexes, Markdown dossiers, tabs and linked navigation, plus a two-stage action that applies Q&A findings to a dossier. Released source exposes a broader generated-knowledge review/save surface. Legacy indexing can still require a Claude key; the complete backend boundary is not proven by these excerpts. [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0), [GP-S18](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MeetingTranscriptWindow.swift)

### GP-F23: Bundle voice and screen context

**SOURCE-DERIVED.** Trigger: Context Bundler is enabled. Activate capture, speak and optionally click windows to collect context; activate the shortcut again to finish. Review captured content and choose clipboard copy, Zo submission or configured Trello submission. The UI also supports clearing context, copying responses and saving a note. Cloud actions require separate privacy consideration from local dictation. [GP-S22](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ContextBubbleView.swift), [GP-S08](https://github.com/matthartman/ghost-pepper/releases/tag/v2.2.0)

### GP-F24: Work offline and understand privacy boundaries

**INFERRED.** Trigger: local-core use after models are available. The published audit describes on-device inference and local files, while model downloads and update checks use the network. Offline operation after preparation is a reasonable inference, not an observed result. Optional integrations create additional network paths. The audit is dated, self-published and leaves its audited commit unspecified. [GP-S11](https://github.com/matthartman/ghost-pepper/blob/main/PRIVACY_AUDIT.md), [GP-S01](https://github.com/matthartman/ghost-pepper)

### GP-F25: Update, launch at login and quit

**DOCUMENTED.** Trigger: regular operation or an update notice. The menu provides update checking, installation when available and Quit; launch-at-login is configurable and documented as initially enabled. v2.4.4 specifically repairs automatic paste. v2.4.2 addresses premature Keychain prompts. Updating is an operational recovery path, but no rollback or migration guarantees were established. [GP-S15](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MenuBarView.swift), [GP-S03](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.4), [GP-S04](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.2), [GP-S01](https://github.com/matthartman/ghost-pepper)

### GP-F26: Invoke external automation

**UNKNOWN.** Trigger: use Ghost Pepper from Shortcuts, AppleScript, a CLI or a URL handler. The reviewed user documentation establishes keyboard shortcuts and in-app actions, but supplies no public automation contract. No programmatic call sequence is asserted. This remains a coverage gap rather than evidence that automation cannot exist. [GP-S01](https://github.com/matthartman/ghost-pepper), [GP-S15](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MenuBarView.swift)

## Surfaces and components

| Surface | Public evidence |
| --- | --- |
| Menu-bar resident | Settings, optional Context Bundler, meeting workspace entry, stop-meeting action, statuses/errors, updater and Quit. [GP-S15](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MenuBarView.swift) |
| Setup | Permission rows, microphone level indicator, model progress, practice transcription and optional Granola import. [GP-S12](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/OnboardingWindow.swift) |
| Settings | General; Cleanup; Models; Model Experiment; History; Recognized Voices; Context Bundler; Meeting Transcript. Controls do not establish end-to-end success. [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift) |
| Meeting workspace | Sidebar/library, multiple document tabs, notes/transcript/summary surfaces, attendee chips, recording notice, calendar and generated knowledge pages. [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0), [GP-S10](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.0), [GP-S18](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/MeetingTranscriptWindow.swift) |
| Model inventory | Selection state, model size, loading/progress indicators, download and eligible removal. [GP-S23](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ModelInventoryViews.swift) |
| Context bubble | Capture preview, removable context, destination actions, conversation output and copy/save actions. [GP-S22](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ContextBubbleView.swift) |

The source exposes more than the introductory website documents, including model experiments and derived knowledge review. Those surfaces are recorded without inventing a complete workflow from isolated button labels. Visual design, accessibility navigation and responsive window behavior remain unobserved.

## Data concepts

These are analytical concepts inferred from the cited evidence, not a proposed schema:

- Dictation is a short recording transformed into raw and cleaned text, with optional retained history. Its retention is separate from meeting documents. [GP-S09](https://github.com/matthartman/ghost-pepper/releases/tag/v2.1.1), [GP-S13](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/SettingsWindow.swift)
- A meeting document carries a name, timing, attendees and authored notes; its transcript consists of timestamped speaker-labelled segments, with an optional generated summary. [GP-S20](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Meeting/MeetingMarkdownWriter.swift)
- A recognized voice is a reusable local identity. An attendee detected from a window is a different piece of evidence from an identified voice. [GP-S07](https://github.com/matthartman/ghost-pepper/releases/tag/v2.3.0)
- Models are selected runtime resources with download/readiness states; speech and cleanup are distinct roles. [GP-S14](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/Transcription/SpeechModelCatalog.swift), [GP-S23](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ModelInventoryViews.swift)
- Dossiers and generated knowledge are derived material associated with source meetings. A Q&A turn combines a question, generated response and conversation context. [GP-S06](https://github.com/matthartman/ghost-pepper/releases/tag/v2.4.0), [GP-S17](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/AppState.swift)
- A context bundle combines dictated intent with selected screen material and has an explicit destination. [GP-S22](https://raw.githubusercontent.com/matthartman/ghost-pepper/v2.4.4/GhostPepper/UI/ContextBubbleView.swift)

## Coverage gaps and validation boundary

The strongest evidence is the install/dictation/meeting narrative and named release changes. The most precise recovery paths come from released source. This is neither an exhaustive source audit nor proof that every declared control works in the distributed binary.

Unresolved areas include interrupted downloads, missing disk space, microphone reconnection, screen-capture denial during an active session, sleep/wake and crash recovery, long-meeting limits, model fallback, cleanup fidelity, speaker attribution, keyboard-only accessibility, library scale, and data deletion across every retained artifact. No quantitative latency or accuracy result is claimed.

The reviewed materials do not fully specify file-import formats, pause/resume, external automation, structured export, cloud payload disclosure, per-integration consent, authentication failure recovery, collaborative sharing, or cross-device synchronization. Local files may be placed in a user-synchronized folder, but that would not establish an app-managed sync feature. Calendar beta/build restrictions and the exact boundary between local generated knowledge and legacy cloud indexing need targeted runtime or fuller source work.

The evidence ledger preserves source URLs and limitations; the flow JSON preserves stable IDs for later comparison. No implementation choices or feature priorities are implied.
