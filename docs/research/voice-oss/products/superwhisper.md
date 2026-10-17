---
status: draft
doc_type: research
summary: "Superwhisper flow inventory SW-F01–SW-F30 from official documentation, release notes and the iPhone listing."
created: 2026-10-12
updated: 2026-10-12
---

# Superwhisper: documented product and flow inventory

Superwhisper is a strong additional reference for the proposed OSS Apple voice product because its documented design connects system dictation, optional meeting capture, local models, retained recordings and agent automation. This is a **fit assessment**, not a market-share or accuracy ranking. The scope is public first-party documentation, release notes and the App Store listing read on **2026-10-12**. No app, account, model, CLI or integration was exercised; this pass includes no binary analysis. The inventory contains **30 flows and 33 sources**.

**DOCUMENTED** means first-party procedural or release evidence; **MARKETING** means product positioning; **INFERRED** means this report's interpretation; **UNKNOWN** means the sources did not establish the behavior. Current Mac release notes show **2.19.2, October 5, 2026**. The iPhone listing shows **2.25.2** and requires **iOS 26+**; desktop onboarding requires **macOS 14+**. These are different product release tracks. [SW-S30](https://superwhisper.com/changelog), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415), [SW-S02](https://superwhisper.com/docs/get-started/quickstart).

## Surfaces and components

This is a documented surface inventory, not a visual reconstruction or accessibility audit.

| Surface | Components worth examining | Evidence |
| --- | --- | --- |
| Setup | Permission grants, input/language/model choices, license | [SW-S02](https://superwhisper.com/docs/get-started/quickstart), [SW-S27](https://superwhisper.com/docs/billing/activate) |
| Capture | Menu bar, expanded/mini window, waveform, context indicators, stop/cancel | [SW-S10](https://superwhisper.com/docs/get-started/interface-rec-window) |
| Modes and models | Presets, per-mode routes, custom instructions, app/site rules, model library | [SW-S04](https://superwhisper.com/docs/get-started/choose-your-model), [SW-S05](https://superwhisper.com/docs/modes/modes) |
| History | Search, audio, original/result views, segments/speakers, retry, details | [SW-S12](https://superwhisper.com/docs/get-started/history), [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings) |
| Configuration | Input device, vocabulary/replacements, retention, folder, plugins | [SW-S03](https://superwhisper.com/docs/get-started/essential-settings), [SW-S16](https://superwhisper.com/docs/get-started/settings-advanced) |
| iPhone | Custom keyboard, main-app recording/history, settings, Spotlight/Siri recall | [SW-S21](https://superwhisper.com/docs/get-started/ios), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415) |

## Flow catalogue

All entries below are DOCUMENTED at the public-documentation level. Matching machine-readable records use SW-F01–SW-F30 and SW-S01–SW-S33.

**SW-F01 — Install and authorize dictation** (macOS 14+). Install in Applications; grant microphone and Accessibility; choose language, model and input. **Result:** Dictation can paste into other apps. **Branch/limit:** Denied permissions require system-settings repair. [SW-S02](https://superwhisper.com/docs/get-started/quickstart)

**SW-F02 — Dictate at the cursor** (macOS). Focus a field; use toggle or hold-to-talk; speak and stop. **Result:** Processed text is inserted. **Branch/limit:** Global and per-mode shortcuts may conflict. [SW-S02](https://superwhisper.com/docs/get-started/quickstart), [SW-S03](https://superwhisper.com/docs/get-started/essential-settings)

**SW-F03 — Inspect, stop or cancel capture** (macOS). Inspect main/mini recording window; stop to process or cancel to discard. **Result:** Capture has explicit completion and abandonment paths. **Branch/limit:** Under-30-second cancellation discards immediately; system capture has a stationary waveform. [SW-S10](https://superwhisper.com/docs/get-started/interface-rec-window)

**SW-F04 — Choose local or cloud processing** (macOS). Create a mode; independently choose speech and optional language models; download local models. **Result:** The mode defines processing location. **Branch/limit:** Bundled S1-mini is English-only and limited to Message/Mail. [SW-S04](https://superwhisper.com/docs/get-started/choose-your-model), [SW-S19](https://superwhisper.com/docs/models/language)

**SW-F05 — Select realtime-compatible speech** (macOS; model-dependent). Choose a supported voice model and enable Realtime. **Result:** Words appear during capture. **Branch/limit:** Parakeet/Scribe cannot combine Realtime with Identify Speakers; Whisper/Cohere lack realtime. [SW-S18](https://superwhisper.com/docs/models/voice)

**SW-F06 — Apply a writing preset** (macOS). Create Message, Mail, Note or Super mode; dictate with the desired preset. **Result:** Output follows a communication purpose. **Branch/limit:** A Note preset is not evidence of a linked-note knowledge base. [SW-S06](https://superwhisper.com/docs/modes/built-in)

**SW-F07 — Create a custom transformation** (macOS; iOS settings also documented). Create Custom mode; write instructions, optional examples and needed context choices. **Result:** A reusable transformation processes dictation. **Branch/limit:** Empty instructions are ambiguous; exact platform parity untested. [SW-S08](https://superwhisper.com/docs/modes/custom), [SW-S21](https://superwhisper.com/docs/get-started/ios)

**SW-F08 — Inspect captured context** (macOS). Enable needed context types; dictate with the target active; inspect the prompt in History. **Result:** The user can examine AI input. **Branch/limit:** Context and identity details may reach the chosen language provider. [SW-S08](https://superwhisper.com/docs/modes/custom), [SW-S10](https://superwhisper.com/docs/get-started/interface-rec-window), [SW-S06](https://superwhisper.com/docs/modes/built-in)

**SW-F09 — Switch manually or by app** (macOS). Use mode menu/shortcut, or assign apps and sites in a mode. **Result:** A task-specific mode becomes active. **Branch/limit:** Conflicting auto-activation rules and stale context require testing. [SW-S07](https://superwhisper.com/docs/modes/switching-modes), [SW-S05](https://superwhisper.com/docs/modes/modes)

**SW-F10 — Teach terms and expand phrases** (macOS; iOS vocabulary settings). Add vocabulary hints or a From/To replacement; dictate the term or phrase. **Result:** Recognition is guided or text is replaced deterministically. **Branch/limit:** Hints are not guaranteed corrections; cloud hints accompany audio. [SW-S11](https://superwhisper.com/docs/get-started/interface-vocabulary), [SW-S21](https://superwhisper.com/docs/get-started/ios)

**SW-F11 — Record a meeting with system audio** (macOS; Pro). Grant Screen/System Audio permission; enable system audio in the selected mode; start and stop capture. **Result:** Microphone plus computer playback feeds transcription. **Branch/limit:** Notifications can enter the recording; guide limits app capture to main display; no roster API established. [SW-S23](https://superwhisper.com/docs/common-issues/microphone-and-system-audio), [SW-S05](https://superwhisper.com/docs/modes/modes)

**SW-F12 — Generate meeting minutes** (macOS; Pro). Choose Meeting mode; capture conversation and finish. **Result:** AI structures discussion, decisions and actions. **Branch/limit:** Speaker separation is optional; speaker labels are excluded from automatic summaries. [SW-S06](https://superwhisper.com/docs/modes/built-in)

**SW-F13 — Separate and rename speakers** (macOS; Pro). Enable Identify Speakers; capture or import; open History Segments and rename labels. **Result:** Transcript distinguishes named speaker segments. **Branch/limit:** No automatic meeting-display-name mapping is documented. [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings)

**SW-F14 — Analyze a labeled transcript** (macOS; Pro). Copy the Segments transcript into an editor; invoke a context-enabled Custom mode with an analysis request. **Result:** AI receives speaker labels for follow-up analysis. **Branch/limit:** Separate multi-step workflow; attribution accuracy untested. [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings)

**SW-F15 — Import an existing recording** (macOS; Pro). Select the desired mode; use Transcribe File, Finder Open With, or the CLI import command. **Result:** Existing audio/video enters the processing pipeline. **Branch/limit:** Active mode controls routing; batch queue and interruption guarantees unknown. [SW-S13](https://superwhisper.com/docs/get-started/transcribe-files)

**SW-F16 — Search and replay history** (macOS; iOS has app History). Open History; search original dictated text and inspect a recording. **Result:** Past audio, transcript and processed result remain accessible. **Branch/limit:** Search excludes processed output; immutability and crash durability unproven. [SW-S12](https://superwhisper.com/docs/get-started/history), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415)

**SW-F17 — Reprocess without recording again** (macOS). Open a prior dictation; invoke reprocess and select another mode. **Result:** Saved audio can produce another result. **Branch/limit:** The docs do not guarantee prior result versions survive. [SW-S12](https://superwhisper.com/docs/get-started/history)

**SW-F18 — Recover an AI-processing failure** (macOS). Use pasted raw text; repair network/model/key; retry the saved dictation in History. **Result:** An AI failure need not require repeating speech. **Branch/limit:** This does not establish recovery from missing audio or app termination. [SW-S24](https://superwhisper.com/docs/common-issues/llm-processing-error)

**SW-F19 — Set recording retention** (macOS; Windows also documented). Choose Forever or a shorter period in Configuration; review deletion warning. **Result:** Stored recordings follow the selected retention rule. **Branch/limit:** Default is Forever; enterprise maximum may override; deletion can prevent reprocessing. [SW-S12](https://superwhisper.com/docs/get-started/history), [SW-S29](https://superwhisper.com/docs/enterprise/configuration)

**SW-F20 — Back up and restore the working folder** (macOS). Locate app folder; copy needed configuration and recordings; restore on another computer and restart. **Result:** A manual copy preserves setup and history. **Branch/limit:** No snapshot protocol; iCloud offloading can break active-folder writes. [SW-S17](https://superwhisper.com/docs/get-started/backing-up-settings), [SW-S25](https://superwhisper.com/docs/common-issues/unable-to-create-mode)

**SW-F21 — Sync configuration between Macs** (macOS). Enable Filesync on Macs sharing a license. **Result:** Supported configuration travels through vendor infrastructure. **Branch/limit:** Audio/history are excluded; iOS/Windows configuration sync is unavailable. [SW-S25](https://superwhisper.com/docs/common-issues/unable-to-create-mode), [SW-S20](https://superwhisper.com/docs/security/sensitive-data)

**SW-F22 — Add a provider or self-hosted language endpoint** (macOS Pro; Enterprise endpoint controls). Add BYOK model, or configure enterprise provider, model ID and API URL; assign it to a mode. **Result:** Text processing uses the selected provider. **Branch/limit:** Enterprise custom models are language-only; compatible chat endpoint and TLS required; no self-hosted app backend established. [SW-S19](https://superwhisper.com/docs/models/language), [SW-S29](https://superwhisper.com/docs/enterprise/configuration)

**SW-F23 — Search and export through the CLI** (macOS). Use search/history/read or export JSONL/Markdown from local recordings. **Result:** Shell workflows consume transcription data. **Branch/limit:** Export is documented for text; complete archival audio export unverified. [SW-S15](https://superwhisper.com/docs/get-started/cli), [SW-S32](https://superwhisper.com/blog/cli-mcp)

**SW-F24 — Connect an assistant through MCP** (macOS). Run the CLI MCP server over stdio; configure the assistant to use it. **Result:** Assistant can query history and manage vocabulary/snippets. **Branch/limit:** Queried text leaves the local boundary according to the assistant settings; MCP app-control parity not documented. [SW-S15](https://superwhisper.com/docs/get-started/cli)

**SW-F25 — Control recording through automation** (macOS). Invoke explicit start/stop or mode deep links/CLI controls against the running app. **Result:** External tools steer capture without toggle ambiguity. **Branch/limit:** No generic event-hook contract or XDG directory contract established. [SW-S07](https://superwhisper.com/docs/modes/switching-modes), [SW-S15](https://superwhisper.com/docs/get-started/cli)

**SW-F26 — Answer coding agents by voice** (macOS). Install a detected agent plugin; restart the agent; respond to questions or approval requests in Superwhisper. **Result:** Voice replies and completion notices connect agent work to capture UI. **Branch/limit:** Agent permissions remain separate; no unattended approval behavior inferred. [SW-S14](https://superwhisper.com/docs/get-started/coding-agents)

**SW-F27 — Enable and use the iPhone keyboard** (iPhone; iOS 26+ current listing). Add Superwhisper keyboard and Full Access; select via globe; record; manually return if opened; stop to insert. **Result:** Dictation reaches the current text field. **Branch/limit:** iOS 26.4+ return is manual per vendor; iPad unsupported. [SW-S21](https://superwhisper.com/docs/get-started/ios), [SW-S22](https://superwhisper.com/docs/common-issues/ios-26-keyboard-changes), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415)

**SW-F28 — Recall an iPhone recording** (iPhone). Open app History, or search for a recording through Spotlight/Siri. **Result:** Mobile capture remains discoverable outside the keyboard. **Branch/limit:** Cross-device history sync is not established. [SW-S21](https://superwhisper.com/docs/get-started/ios), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415)

**SW-F29 — Activate Pro across devices** (macOS / iPhone). Purchase or recover a license; enter it on desktop and scan its QR code or enter it on iPhone. **Result:** One entitlement covers supported devices. **Branch/limit:** Free has two non-AI modes; Pro gates system capture, separation, BYOK and imports. [SW-S26](https://superwhisper.com/docs/billing/plans), [SW-S27](https://superwhisper.com/docs/billing/activate)

**SW-F30 — Delete account or local recordings** (macOS / iPhone; service account). Request account deletion separately; remove local recordings or app data when intended. **Result:** Service identity and device data have distinct deletion paths. **Branch/limit:** Uninstall alone retains the data folder; account deletion leaves local history. [SW-S28](https://superwhisper.com/docs/security/account-deletion)

## Meeting integration and speaker mechanism

| Layer | Established behavior | Boundary |
| --- | --- | --- |
| Meeting detection | Manual capture and per-app mode activation are documented. | Calendar/meeting lifecycle detection is UNKNOWN. App activation alone does not prove call detection. [SW-S05](https://superwhisper.com/docs/modes/modes) |
| Audio | Vendor documents microphone plus system playback, Screen/System Audio permission and capture involving the main display. | Native capture API, separated channel persistence, exact app isolation and echo handling are UNKNOWN. [SW-S23](https://superwhisper.com/docs/common-issues/microphone-and-system-audio) |
| Roster and active speaker | No roster connector, Zoom SDK, Meet extension or active-speaker UI parser is established in this bounded documentation review. | Generic Accessibility use for dictation/context must not be promoted into meeting-speaker observation. [SW-S02](https://superwhisper.com/docs/get-started/quickstart), [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings) |
| Diarization | Offline acoustic speaker separation is release-documented since 1.40.0; current guides expose Identify Speakers. | Model identity, thresholds and local/cloud routing of every separation path are UNKNOWN. [SW-S30](https://superwhisper.com/changelog), [SW-S18](https://superwhisper.com/docs/models/voice) |
| Identity and summary | Users rename labels in Segments. Standard Meeting summaries omit those labels; the guide supplies a separate labeled-transcript analysis workflow. | A speaker label is not an authenticated participant identity. [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings), [SW-S06](https://superwhisper.com/docs/modes/built-in) |

The meeting landing page markets capture without a joining bot and says recordings stay on-device. That privacy statement needs configuration qualification: the processing documentation independently routes speech and text, and either stage can use a remote model. [SW-S33](https://superwhisper.com/meeting-transcription), [SW-S20](https://superwhisper.com/docs/security/sensitive-data).

## Local processing, hosting and composability

The strongest documented analogue is a local recording corpus with a programmable client. The CLI reads the app's local database, while commands controlling recording require the app to be running. Its stdio MCP exposes history and vocabulary/snippet operations; this is not evidence of a remote multiuser recording server. The public launch was July 16, 2026. [SW-S15](https://superwhisper.com/docs/get-started/cli), [SW-S32](https://superwhisper.com/blog/cli-mcp).

Local speech engines include Whisper through whisper.cpp, Parakeet through WhisperKit on Mac, and Cohere Transcribe. Their availability does not mean every AI mode is offline: the bundled S1-mini supports English Message/Mail only. Mac release notes mention Ollama custom-model fixes, establishing integration history without specifying a current configuration contract. Enterprise documentation explicitly supports custom language-model endpoints implementing compatible chat completions, with TLS; it excludes custom voice models from that enterprise configuration surface. None of this establishes an OSS license or self-hostable edition of the application/service. [SW-S18](https://superwhisper.com/docs/models/voice), [SW-S19](https://superwhisper.com/docs/models/language), [SW-S30](https://superwhisper.com/changelog), [SW-S29](https://superwhisper.com/docs/enterprise/configuration).

File-based configuration and relocatable directories are useful precedents for composability. Documented default storage is `~/superwhisper`, with older installations under Documents. This is not XDG compliance. Filesync uses vendor infrastructure for configuration, excluding recording content; narrower guidance establishes Mac-to-Mac scope and says Windows/iOS sync is unavailable. Optional iCloud synchronization is therefore not established; the troubleshooting guide specifically redirects active folders away from iCloud when offloading breaks writes. [SW-S17](https://superwhisper.com/docs/get-started/backing-up-settings), [SW-S25](https://superwhisper.com/docs/common-issues/unable-to-create-mode), [SW-S20](https://superwhisper.com/docs/security/sensitive-data).

## Design lessons and requirements fit

**INFERRED lessons:** borrow the separation between raw speech, transformed text and delivery; expose a mode's processing destination; make history a repair surface; give GUI and command-line users the same underlying corpus. Those lessons follow from the documented mode, History and CLI flows rather than any observed performance. [SW-S04](https://superwhisper.com/docs/get-started/choose-your-model), [SW-S12](https://superwhisper.com/docs/get-started/history), [SW-S15](https://superwhisper.com/docs/get-started/cli).

The mini recorder, keyboard control, Finder import, explicit input selection and iPhone search integrations are native interaction patterns worth testing. The immediate short-recording cancel/discard path and silent system-audio waveform are important counterexamples for this project's preserve-everything and visible-capture requirements. The keyboard/main-app return problem is another concrete platform failure state to design for. These are design implications, not a claim that Superwhisper's UX is poor or that our alternative is implemented. [SW-S10](https://superwhisper.com/docs/get-started/interface-rec-window), [SW-S13](https://superwhisper.com/docs/get-started/transcribe-files), [SW-S22](https://superwhisper.com/docs/common-issues/ios-26-keyboard-changes).

**Strong fit:** Mac/iPhone dictation, custom keyboard, model choice, local history/reprocessing, CLI/MCP and specific coding-agent hooks. **Partial fit:** meeting summaries and speaker separation, portable configuration and manual backups. **Not established here:** Apple Watch app, outbound ordinary-number calling, linked second-brain notes/backlinks, optional iCloud history sync, general event hooks, XDG conventions, deployable self-hosted backend, append-only versions, power-loss safety or recovery after disk exhaustion. The absence findings are scoped to the sources surveyed and should not be treated as definitive product-wide negatives.

## Documentation drift and next evidence

- The iPhone guide explicitly rejects iPad support. Broad mobile marketing wording elsewhere must not override the focused platform guide. Mac and iOS version numbers are independent. [SW-S21](https://superwhisper.com/docs/get-started/ios), [SW-S31](https://apps.apple.com/us/app/superwhisper-ai-dictation/id6471464415).
- Generic Filesync wording says all installations under a license; the narrower missing-mode guide restricts available sync to Macs. No recording/audio sync is promised. [SW-S16](https://superwhisper.com/docs/get-started/settings-advanced), [SW-S25](https://superwhisper.com/docs/common-issues/unable-to-create-mode).
- Advanced settings describes replacement of clipboard contents as default; September 3, 2026 release notes say preservation became default. Validate the installed version before reproducing defaults. [SW-S16](https://superwhisper.com/docs/get-started/settings-advanced), [SW-S30](https://superwhisper.com/changelog).
- Speaker-separated guidance introduces the workflow as requiring configuration-file edits, but its actual listed steps use UI and copying. Record the observable workflow before requiring hand-edited configuration. [SW-S09](https://superwhisper.com/docs/modes/speaker-separated-meetings).
- Future artifact/runtime work should isolate capture APIs, the diarizer and timestamp alignment, provider egress, canceled-recording retention, reprocessing version semantics, and restoration under interrupted writes. No such tests occurred in this pass.
