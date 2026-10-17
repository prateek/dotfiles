---
status: draft
doc_type: research
summary: "MacWhisper flow inventory MW-F01–MW-F30 with direct, Mac App Store and iOS edition differences retained."
created: 2026-10-12
updated: 2026-10-12
---

# MacWhisper: native transcription workspace and automation reference

MacWhisper is a strong additional reference because one Mac workspace spans file transcription, microphone and meeting capture, dictation, local models, AI processing and automation. It particularly informs the requested local-model, composability and preservation requirements. This is product analysis, not a claim that it is the best performer. Research date: **2026-10-12**; **30 flows, 24 primary-source records**. No software was installed, account accessed, binary inspected or runtime behavior tested during this pass.

**Evidence:** DOCUMENTED means first-party procedures or specific release behavior; MARKETING means product-listing claims; INFERRED marks our interpretation; UNKNOWN means the inspected evidence did not settle the question. Public documentation can lag the shipped product.

## Identity and version boundaries

Good Snooze/Jordi Bruin distributes **MacWhisper** directly and **Whisper Transcription** through the Mac and iOS App Stores. The direct Mac edition adds system dictation, automatic meeting prompts and CLI access. Its external license is not an App Store unlock. Mobile local models are free; Assistant is optional and BYOK is available. [MW-S02](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)

Observed listings differ: direct-product text says **15.2**, the Mac App Store history says **15.5**, and mobile says **5.2**. These are separate evidence snapshots; shared branding does not establish version or feature parity. The public Mac price is €64 once, while App Store/Assistant purchases differ. [MW-S23](https://goodsnooze.gumroad.com/l/macwhisper/), [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac), [MW-S04](https://apps.apple.com/nl/app/whisper-transcription/id1668083311?l=en-GB), [MW-S01](https://www.macwhisper.com/)

## Documented surfaces

| ID | Surface | Components and states to study | Evidence |
| --- | --- | --- | --- |
| MW-UI01 | Home and model management | File drop, recording entry points, model picker, download/preparation | [Models](https://docs.macwhisper.com/article/29-switching-to-a-whisperkit-model), [product](https://www.macwhisper.com/) |
| MW-UI02 | Transcript workspace | Editable segments, speaker sidebar, playback, search, Transcript/AI/Translations/Info/Export tabs | [Keyboard guide](https://docs.macwhisper.com/article/28-keyboard-shortcuts), [speaker guide](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper) |
| MW-UI03 | Batch queue and output presets | Multiple files, total duration, several output layouts | [Batch](https://docs.macwhisper.com/article/19-batch-transcription) |
| MW-UI04 | Global panel and Dictation | Shortcut activation, floating capture, auto-copy versus text insertion | [Global](https://docs.macwhisper.com/article/16-global), [Dictation](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature) |
| MW-UI05 | Meeting notifications and recorder | Observed-app selection, detected-call prompt, start/stop and history | [Meeting guide](https://docs.macwhisper.com/article/30-record-meetings) |
| MW-UI06 | Settings and integrations | Separate transcription/AI providers, prompt assignments, watch folders, connection tests | [AI providers](https://docs.macwhisper.com/article/58-setting-up-ai-providers-in-macwhisper), [integrations](https://docs.macwhisper.com/article/53-integrating-macwhisper-with-other-services) |
| MW-UI07 | Mobile recording and transcript | Share-extension import, model download, recorder, transcript and chat | [iOS guide](https://docs.macwhisper.com/article/33-macwhisper-for-ios) |

These are documentation-derived surfaces, not observed screenshots or verified focus/accessibility states.

## Zoom, Google Meet and speaker attribution

| Stage | What the evidence establishes | Confidence and unresolved mechanism |
| --- | --- | --- |
| Detect meeting | Configurable observed apps include Zoom and browsers; user accepts a recording notification. | DOCUMENTED user behavior; microphone-process, AX, browser URL or SDK detection mechanism UNKNOWN. Browser inclusion alone does not prove a Meet-specific detector. [MW-S08](https://docs.macwhisper.com/article/30-record-meetings) |
| Acquire audio | Mac 15.4 release notes specify CoreAudio on macOS 26+, replacing ScreenCaptureKit and enabling echo cancellation. | DOCUMENTED release behavior, not artifact/runtime verification; direct-build parity unverified. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac) |
| Separate speakers | Current Mac notes offer Nemotron or Pyannote for local files; Nemotron has an eight-speaker ceiling. | DOCUMENTED acoustic path; model choice for live meetings needs separate verification. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac) |
| Name people | Speaker labels can be renamed, merged and chosen from saved-name suggestions. | DOCUMENTED correction; saved-name autocomplete is not a voiceprint or meeting-roster match. [MW-S07](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper) |
| Explain active speaker | Live meeting controls highlight a speaker. | No primary evidence of Zoom/Meet roster, DOM/AX speaking-indicator extraction or platform active-speaker events. Acoustic output can explain the UI without those signals; that is an inference, not established implementation. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac) |

The July 2025 meeting guide says remote participants share one label; newer Mac releases document live speaker work. Retain the old statement as historical evidence, not a current product limitation. The older speaker guide's WhisperKit-only local coverage is similarly stale. A future REA pass should test detection, audio routing and participant naming separately. [Meeting guide](https://docs.macwhisper.com/article/30-record-meetings), [speaker guide](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper)

## Flow catalogue

The records below distinguish capture, transcription, AI processing and delivery. IDs resolve to the accompanying JSON flow catalogue and source registry.

**MW-F01 — Choose distribution and entitlement** (macOS / iPhone / iPad; DOCUMENTED). Choose direct MacWhisper or store Whisper Transcription; activate the matching purchase. **Result:** Correct client and entitlement. **Limit:** Direct licenses do not unlock store purchases; direct-only features differ. [MW-S02](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)

**MW-F02 — Download and select a local model** (macOS; engine-dependent; DOCUMENTED). Open Manage Models, filter by engine, download and activate. **Result:** Local transcription model ready. **Limit:** WhisperKit requires Apple Silicon; first preparation can take time. [MW-S05](https://docs.macwhisper.com/article/29-switching-to-a-whisperkit-model)

**MW-F03 — Transcribe an imported recording** (macOS; MARKETING). Drop an audio/video file; select language and model; transcribe. **Result:** Editable transcript. **Limit:** Format/model coverage varies; no accuracy benchmark. [MW-S01](https://www.macwhisper.com/)

**MW-F04 — Batch-process a backlog** (macOS Pro; DOCUMENTED). Open several files together; add export formats; process the batch. **Result:** Several recordings become several output formats. **Limit:** URL batches undocumented in current version; partial failure recovery untested. [MW-S12](https://docs.macwhisper.com/article/19-batch-transcription)

**MW-F05 — Capture a quick voice memo globally** (macOS Pro; DOCUMENTED). Configure shortcut; invoke floating Global panel; record and optionally auto-copy. **Result:** Microphone transcript available across apps. **Limit:** Global is distinct from automatic text-field insertion and system-audio capture. [MW-S11](https://docs.macwhisper.com/article/16-global)

**MW-F06 — Record app or system audio** (macOS; DOCUMENTED). Choose app/system audio and optional microphone; grant capture permission; record. **Result:** Local recording available. **Limit:** Mac 15.4 documents CoreAudio on macOS 26+; older path ScreenCaptureKit. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac)

**MW-F07 — Accept a meeting capture prompt** (Direct macOS; DOCUMENTED). Enable meeting notifications and observed apps; accept detected-call prompt; stop after meeting. **Result:** Recording appears in history. **Limit:** Browser detection is documented, exact Zoom/Meet signal is not; old guide labels beta. [MW-S08](https://docs.macwhisper.com/article/30-record-meetings)

**MW-F08 — Follow and correct a live meeting** (macOS Pro; compatible model; DOCUMENTED). Enable live transcription; follow transcript; rename or merge speakers. **Result:** Readable live speaker turns. **Limit:** Highlighting a speaker does not prove Zoom/Meet identity extraction. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac)

**MW-F09 — Review and name diarized speakers** (macOS; compatible model; DOCUMENTED). Inspect numbered speakers; rename, merge duplicates and choose colors. **Result:** Corrected speaker labels. **Limit:** Suggested existing names are not proof of persistent voice recognition. [MW-S07](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper)

**MW-F10 — Correct transcript segments with the keyboard** (macOS; DOCUMENTED). Navigate playback; edit/split text; use number keys to reassign selected speaker segments. **Result:** Transcript and attribution corrected. **Limit:** Undo depth and preserved correction history unknown. [MW-S19](https://docs.macwhisper.com/article/28-keyboard-shortcuts)

**MW-F11 — Build a transcript from separate podcast tracks** (macOS; MARKETING). Import individual speaker tracks into Transcribe Podcast. **Result:** Track-based speaker separation. **Limit:** This path assumes each track represents one speaker; not acoustic diarization. [MW-S01](https://www.macwhisper.com/), [MW-S07](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper)

**MW-F12 — Review text against original media** (macOS; MARKETING). Play synchronized audio/video; search text, adjust speed and mark passages. **Result:** Review stays anchored to recording. **Limit:** Playback responsiveness and corrupted-media handling untested. [MW-S23](https://goodsnooze.gumroad.com/l/macwhisper/), [MW-S19](https://docs.macwhisper.com/article/28-keyboard-shortcuts)

**MW-F13 — Use a remote transcription provider** (macOS; DOCUMENTED). Add provider key or compatible custom endpoint in transcription settings; select it in model picker. **Result:** Audio transcribed remotely. **Limit:** Provider limits and network errors vary; older help ceilings are stale. [MW-S06](https://docs.macwhisper.com/article/18-cloud-transcription)

**MW-F14 — Connect a local or self-hosted text model** (macOS; DOCUMENTED). Start Ollama/LM Studio or compatible server; add endpoint and model; select in AI picker. **Result:** Transcript prompts processed by chosen server. **Limit:** Text-AI choice does not change audio-transcription routing; server compatibility varies. [MW-S16](https://docs.macwhisper.com/article/58-setting-up-ai-providers-in-macwhisper)

**MW-F15 — Summarize, ask questions or translate** (Mac / iOS; entitlement differs; DOCUMENTED). Open transcript; choose summary, chat or supported translation; use Assistant or BYOK. **Result:** Derived text for reading or reuse. **Limit:** Hosted mode sends content off-device; citation and hallucination behavior untested. [MW-S22](https://docs.macwhisper.com/article/22-assistant)

**MW-F16 — Dictate into another Mac app** (Direct macOS; DOCUMENTED). Complete Dictation setup; bind shortcut; speak into focused text field. **Result:** Recognized text inserted. **Limit:** AI cleanup uses separate prompt/provider setup; secure-field and focus behavior untested. [MW-S09](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature)

**MW-F17 — Use app-specific writing transformations** (Direct macOS; DOCUMENTED). Add running apps in Dictation settings; assign saved prompts; dictate there. **Result:** Per-app tone or transformation applied. **Limit:** App identity granularity and fallback when app is missing untested. [MW-S10](https://docs.macwhisper.com/article/31-app-specific-dictation-prompts)

**MW-F18 — Maintain reusable vocabulary corrections** (macOS; DOCUMENTED). Add replacement pairs and match rules; import/export the list as JSON. **Result:** Future transcripts use replacements. **Limit:** Not retroactive; substring matching can alter unintended words. [MW-S18](https://docs.macwhisper.com/article/37-find-and-replace-in-transcriptions)

**MW-F19 — Create subtitles and video review outputs** (macOS; MARKETING). Open media; transcribe; view synchronized subtitles and export chosen format. **Result:** Shareable subtitles or document. **Limit:** Translation/model limits and precise export fidelity require sample files. [MW-S01](https://www.macwhisper.com/), [MW-S23](https://goodsnooze.gumroad.com/l/macwhisper/)

**MW-F20 — Import an online video** (macOS; DOCUMENTED). Paste a YouTube URL and submit. **Result:** Online media becomes a transcript. **Limit:** Age, country and some live-video restrictions apply. [MW-S20](https://docs.macwhisper.com/article/51-how-to-transcribe-youtube-videos)

**MW-F21 — Automate imports through watched folders** (macOS Pro; DOCUMENTED). Add folder; choose automatic processing or notification; configure export presets. **Result:** New recordings trigger processing. **Limit:** Readiness, interrupted copies and replay need tests; old guide is beta. [MW-S13](https://docs.macwhisper.com/article/35-automatically-transcribing-files-in-watch-folders)

**MW-F22 — Send completed transcripts to a webhook** (macOS Pro; DOCUMENTED). Configure n8n/Zapier/Make/custom destination; send test; enable automatic delivery. **Result:** Endpoint receives transcript payload. **Limit:** Retries, duplicate suppression and offline backlog are unspecified. [MW-S14](https://docs.macwhisper.com/article/53-integrating-macwhisper-with-other-services)

**MW-F23 — Send transcripts into Obsidian** (macOS Pro; DOCUMENTED). Configure local REST plugin and token; add endpoint in MacWhisper; test. **Result:** Markdown note created or updated. **Limit:** Plugin required; same-title overwrite and transport settings need verification. [MW-S14](https://docs.macwhisper.com/article/53-integrating-macwhisper-with-other-services)

**MW-F24 — Compose transcription from the terminal** (Direct macOS; DOCUMENTED). Install mw from Advanced settings; transcribe files to stdout/JSON or pipe results onward. **Result:** Scriptable app-backed transcription. **Limit:** App runs behind local socket; --persist opts into history, --overwrite into replacement. [MW-S15](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

**MW-F25 — Keep a portable recording project** (macOS; MARKETING). Save/export a .whisper archive after editing. **Result:** Original audio and transcript edits travel together. **Limit:** Archive export is not automatic backup or versioned history. [MW-S23](https://goodsnooze.gumroad.com/l/macwhisper/)

**MW-F26 — Recover and reprocess saved work** (macOS; DOCUMENTED). Reopen history and retranscribe; restore eligible deleted transcripts. **Result:** Saved work can be revisited. **Limit:** Release notes report safeguards; crash durability and immutable versions unproven. [MW-S03](https://apps.apple.com/us/app/whisper-transcription/id1668083311?platform=mac)

**MW-F27 — Capture or import on iPhone and iPad** (iOS / iPadOS; DOCUMENTED). Record in-app or share a media file; choose local model or cloud provider. **Result:** Mobile transcript with summary/chat options. **Limit:** Older help hardware limits differ from current store listing; local download required. [MW-S21](https://docs.macwhisper.com/article/33-macwhisper-for-ios), [MW-S02](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)

**MW-F28 — Dictate through an iOS keyboard** (iOS / iPadOS; DOCUMENTED). Set up keyboard; select via Globe; follow recording handoff; return to destination. **Result:** Text enters another app. **Limit:** Release 4.1 says return requires manual swipe; current handoff reliability untested. [MW-S04](https://apps.apple.com/nl/app/whisper-transcription/id1668083311?l=en-GB)

**MW-F29 — Find mobile history through Apple surfaces** (iOS / iPadOS; DOCUMENTED). Search history or use supported Shortcuts/Siri/Spotlight actions. **Result:** Saved transcripts reusable outside app. **Limit:** Indexing can be disabled; cross-device sync is not established. [MW-S04](https://apps.apple.com/nl/app/whisper-transcription/id1668083311?l=en-GB)

**MW-F30 — Apply inspectable managed settings** (Direct macOS; DOCUMENTED). Deploy profile or fallback plist; inspect Loaded From in MDM settings. **Result:** Policies and providers configured predictably. **Limit:** Profile precedence is documented; not an XDG configuration contract. [MW-S24](https://docs.macwhisper.com/article/27-deploying-macwhisper-with-mdm)

## Local processing, self-hosting and data ownership

MacWhisper documents local transcription and speaker processing. Cloud transcription sends audio away; remote AI prompting sends transcript text; remote translation is another independent route. Local Ollama/LM Studio can keep text processing nearby, and custom compatible endpoints can target another machine. This establishes **local inference and BYO inference**, not a deployable OSS product server. Nothing inspected establishes a Linux service, an Unraid/exe.dev distribution, or a self-hosted multi-device library. [Privacy](https://docs.macwhisper.com/article/52-keeping-transcriptions-private), [providers](https://docs.macwhisper.com/article/58-setting-up-ai-providers-in-macwhisper)

The CLI shares the GUI's engines and settings through a local socket. It launches the Mac app when necessary, so it is not an independent headless transcription backend. Its stdout/stderr separation, structured output and explicit overwrite policy are useful composition patterns. **History persistence is opt-in for CLI runs**, a direct mismatch with this project's always-retain requirement unless deliberately changed. No MCP server or XDG path contract was established in the inspected official corpus. [CLI](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

The portable `.whisper` archive is a useful ownership affordance because the vendor says it includes source audio and edits. It does not establish immutable originals, complete result-version history, crash-safe writes or recovery after disk failure. Reprocessing should produce a new artifact in our design exploration, with the old result still inspectable. This is an analysis recommendation derived from U29–U30, not MacWhisper behavior. [Portable projects](https://goodsnooze.gumroad.com/l/macwhisper/)

Integrations can pass a transcript into a self-hosted automation engine or a local Obsidian vault. Those are external delivery routes, not proof the app itself is self-hosted. The documented webhook payload and connection test are a starting point; no retry queue, replay identity or exactly-once contract is specified. [Integrations](https://docs.macwhisper.com/article/53-integrating-macwhisper-with-other-services)

## What to learn and what to avoid

These are **INFERRED design lessons** based on the documented interactions:

- **Make model capabilities visible before a job starts.** A model picker should explain supported languages, speaker separation, location, memory and first-load work. Avoid a generic “local” label that hides where later AI steps run. [Models](https://docs.macwhisper.com/article/29-switching-to-a-whisperkit-model), [privacy](https://docs.macwhisper.com/article/52-keeping-transcriptions-private)
- **Keep review close to source material.** Fast playback, editable segments and keyboard speaker correction matter when recognition is imperfect. Our version should retain correction provenance rather than treating the corrected text as the only truth. [Shortcuts](https://docs.macwhisper.com/article/28-keyboard-shortcuts), [speaker correction](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper)
- **Give small and large tasks distinct entry points.** Global capture, dictation and batch work share recognition but need different attention and output behavior. Do not make “record” ambiguously mean microphone, system audio, automatic paste and meeting capture. [Global](https://docs.macwhisper.com/article/16-global), [Dictation](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature), [batch](https://docs.macwhisper.com/article/19-batch-transcription)
- **Make automation observable.** Connection tests, clear output formats and an inspectable configuration source reduce operator guesswork. Extend these ideas with durable job IDs, delivery history and replay for the requested hooks. [Integrations](https://docs.macwhisper.com/article/53-integrating-macwhisper-with-other-services), [MDM](https://docs.macwhisper.com/article/27-deploying-macwhisper-with-mdm)
- **Treat platform variants as product contracts.** The same app-family branding can hide direct-versus-store limitations. Our docs and onboarding should disclose feature availability before purchase or setup. [Distribution differences](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)

## Fit to the stated requirements

| Requirement family | Value as a reference | Boundary |
| --- | --- | --- |
| Native Mac and iOS (U07–U08, U18–U20) | Broad native workflow, keyboard control, platform sharing | UX quality is not proven by feature lists; no hands-on accessibility evaluation |
| Local/remote models (U12–U15) | Separate speech and text-AI providers; local and custom endpoints | Endpoint compatibility is not an entire self-hosted product |
| CLI/composition/hooks (U10–U11, U26–U28) | CLI, file watching, webhooks, structured exports and managed preferences | No established MCP, XDG or generic lifecycle hook contract |
| iOS keyboard (U23) | Existing keyboard workflow and documented handoff constraints | Keyboard recording mechanics and focus recovery need on-device study |
| Second-brain notes (U24) | Searchable transcript workspace and external Obsidian route | Backlinks, relationship graph, journal/project semantics and cross-note reasoning not established |
| Retention/reprocessing (U29–U30) | Portable audio-plus-edit projects, history and recovery work | No always-retain guarantee; CLI is transient by default |
| Watch, PSTN calling and optional iCloud sync (U09, U25, U31) | No qualifying workflow established | iCloud file import/watch behavior must not be represented as library sync |

The fit assessment is our synthesis of the cited flows, not a claim that these requirements are implemented by either product.

## Data concepts and remaining questions

**INFERRED domain map:** a media source feeds transcription jobs; a job references an engine/model/language and produces timestamped segments and speaker clusters. User corrections, labels, favorites and AI outputs belong to the resulting project. Export presets, watched folders, provider configurations and delivery destinations compose around that project. A portable archive can package source and edits, while external integrations create downstream copies. This is a proposed analytical vocabulary, not MacWhisper's database schema.

The highest-value follow-up questions are:

1. Does a new transcription preserve the previous text, timestamps, speaker edits and model metadata, or merely replace the visible result after success?
2. Which original files remain after cancellation, failed import, crash, storage exhaustion, deliberate deletion and restoring a project archive?
3. Does meeting detection use microphone activity, AX, browser signals or something else, and how does it distinguish a call from arbitrary playback?
4. Does any path resolve meeting participant identities, or are live labels exclusively acoustic clusters plus human names?
5. Can hooks retry and replay without duplicated notes, and can users inspect pending or failed exports?
6. How does mobile keyboard capture handle denied access, app termination, a changed destination and local-model memory pressure?
7. What is the actual cross-device story? Importing an iCloud file does not establish synchronized projects, conflicts, offline edits or recovery copies.

**Coverage limit:** all 30 entries are bounded public-source reconnaissance. Checkout, subscription cancellation, account-gated assistant behavior, every export preset, full model catalogue, translations and device-specific failure screens were not exercised. The Gumroad product body was available through search extraction while direct page extraction was empty; use its claims as marketing evidence. A separately discovered indexed 15.2 announcement returned 404 at its clean URL and was not used as an authoritative ledger entry.
