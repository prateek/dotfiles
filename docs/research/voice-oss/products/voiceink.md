---
status: draft
doc_type: research
summary: "VoiceInk flow inventory VI-F01–VI-F31 from product help, public repository documentation, appcast and App Store."
created: 2026-10-12
updated: 2026-10-12
---

# VoiceInk public workflow inventory

VoiceInk documents configurable dictation, transcript management, and text automation on Mac, plus a separate iPhone/iPad companion. This inventory captures public evidence accessed on 2026-10-12; it does not claim installation, permission testing, successful transcription, or measured accuracy. No private account, binary inspection, or application source inspection was used. The repository README identifies the Mac app as native and GPLv3. Its published build and purchased distribution are distinct routes. [VI-S02](https://github.com/Beingpax/VoiceInk)

**Evidence vocabulary:** DOCUMENTED means an official operational description; MARKETING means a vendor capability or commercial claim without a complete procedure; SOURCE-DERIVED would mean application-code evidence, unused here; INFERRED identifies interpretation; UNKNOWN identifies missing or conflicting evidence. DOCUMENTED does not mean runtime-verified.

Unless specified otherwise, flows below concern the native macOS app with an active trial/license, suitable permissions, and the selected model available. Cloud flows additionally require connectivity, provider access, and separately funded API usage. The machine-readable companions are [sources](../data/sources.jsonl) and [flows](../data/flows.json).

## Surfaces and concepts

The documented main-window surfaces are Dashboard/Insights, Modes, AI Models, Dictionary, Audio, History, Transcribe, Settings, and VoiceInk Pro. Transient surfaces include the Notch/Mini recorder, Assistant panel, Quick History, dictionary quick-add/review panels, provider/model dialogs, and import previews. Menu-bar operation, appearance, interface language, login startup, updates, and onboarding reset are settings. [VI-S03](https://tryvoiceink.com/docs/introduction), [VI-S25](https://tryvoiceink.com/docs/settings-general)

**INFERRED conceptual model:** a Mode joins triggers, transcription model/language, formatting, optional enhancement provider/model/prompt/context, and output destination. Other entities are downloaded model assets, provider credentials, vocabulary terms, grouped replacement rules, pending corrections, transcript/audio records, Assistant turns, text-free session metrics, license activations, and selective settings archives. These are user-facing concepts, not a proposed schema. [VI-S12](https://tryvoiceink.com/docs/modes), [VI-S31](https://tryvoiceink.com/docs/privacy-and-data)

## Publicly documented flows

### VI-F01 — Install and complete onboarding · DOCUMENTED

On a qualifying Mac, download VoiceInk, move it to Applications, launch, and follow onboarding. Grant Microphone and Accessibility; Screen Recording supports optional screen context, and browser URL reading can request Automation. Choose a shortcut, make a model available, and select a Mode; onboarding starts with Parakeet V3. Begin the seven-day trial or activate. Permission changes may require restart. Documentation says macOS 15+, with cloud recommended on Intel; homepage requirements conflict. [VI-S04](https://tryvoiceink.com/docs/installation)

### VI-F02 — Purchase, activate, recover, or move a license · DOCUMENTED / MARKETING

After purchase, open VoiceInk Pro, enter the key, and Activate with network access. Retrieve missing keys through Polar using the checkout email, including any relay address. Deactivate and confirm before freeing this Mac's slot. At access time, the homepage advertises lifetime Mac tiers of $25/one device, $39/two, and $49/three; provider usage is separate. Mac licenses do not activate iOS. Trial-expiry and offline revalidation behavior remain UNKNOWN. [VI-S05](https://tryvoiceink.com/docs/license-management), [VI-S01](https://tryvoiceink.com/), [VI-S41](https://tryvoiceink.com/docs/ios-macos-license-confusion)

### VI-F03 — Download or import local transcription models · DOCUMENTED

For local dictation, open AI Models → Local, download a model, then choose it under a Mode's Transcription → Model. Catalog families include Parakeet, Nemotron, Whisper, Cohere, SenseVoice, and Apple Speech. The card menu deletes or reveals assets. Import Local Model accepts whisper.cpp-compatible `.bin` files only. Language availability varies by model; Apple Speech needs macOS 26 and system-managed language assets. Interrupted downloads and disk-full recovery are UNKNOWN. [VI-S06](https://tryvoiceink.com/docs/local-models)

### VI-F04 — Connect a cloud provider with BYOK · DOCUMENTED

With a provider account/key, choose AI Models → Cloud → provider, enter the key, Verify, then select its transcription or enhancement model in a Mode. Keys reside in Keychain. Capability differs: some providers supply only one stage; OpenAI has no built-in transcription integration. OpenRouter refreshes separate catalogs. Revoking a key makes dependent workflows unavailable. Provider quotas, charges, and errors remain provider-specific. [VI-S07](https://tryvoiceink.com/docs/cloud-providers)

### VI-F05 — Add a custom endpoint · DOCUMENTED

For an existing compatible service, open AI Models → Custom and add transcription or enhancement definitions with name, full endpoint, key, and exact model ID. Transcription also records multilingual capability. Test is optional; Save alone does not verify connectivity. Select the saved definition in a Mode. Custom transcription is batch-only; deleting a definition removes its saved key. Despite its label, enhancement Base URL requires the full chat-completions path. [VI-S08](https://tryvoiceink.com/docs/custom-models)

### VI-F06 — Record with global shortcuts · DOCUMENTED

Assign primary/secondary keyboard, modifier, or supported mouse shortcuts in Settings → Shortcuts, each with Toggle, Push to Talk, Hybrid, or Double Tap behavior. Focus a destination field, trigger, speak, then stop/release according to that behavior. Hybrid uses a 0.5-second hold threshold. Cancel through an assigned shortcut or two Escapes when unassigned. Left/right mouse clicks are excluded. Shortcut conflicts and locked-screen operation are UNKNOWN. [VI-S11](https://tryvoiceink.com/docs/shortcuts), [VI-S03](https://tryvoiceink.com/docs/introduction)

### VI-F07 — Display transcription while speaking · DOCUMENTED

Choose a streaming-capable model and enable Real-time in its Mode. Settings → Interface → Live Text Display independently controls partial text in either recorder style. Partial words can change; finishing still applies final processing. Whisper and custom endpoints lack this path; Nemotron requires it for live recording. Cloud streaming sends audio during recording. Imported files use batch processing regardless. [VI-S17](https://tryvoiceink.com/docs/realtime-transcription)

### VI-F08 — Paste, send, and repair insertion · DOCUMENTED

With Paste output and a focused field, finishing copies final text to the clipboard and invokes Command+V. Settings → Pasting controls clipboard restoration, delay, and Default/AppleScript delivery. For missing insertion, verify focus, Accessibility, and output choice; increase delay if old clipboard content appears. Auto Send requires choosing a send key and ending recording with Return; ordinary shortcut completion only pastes. Respond and Custom Command deliver elsewhere. [VI-S37](https://tryvoiceink.com/docs/clipboard-issues)

### VI-F09 — Create, select, duplicate, or disable Modes · DOCUMENTED

Create task-specific Modes with transcription, enhancement, context, and output settings. Starter choices cover dictation, enhancement, email, rewrite, and Assistant. Select manually, assign a shortcut, or configure triggers. Disable preserves configuration. Duplication copies processing/output but clears triggers, shortcut, and default status. Change the default before deleting it; Respond cannot be default. Current docs call this surface Modes; a distinct current “Power Mode” flow was not established. [VI-S12](https://tryvoiceink.com/docs/modes)

### VI-F10 — Apply app, website, and spoken profiles · DOCUMENTED

Edit Modes → Triggers → plus; choose installed apps, websites, suggested groups, or spoken phrases. At recording start, app/default selection can be superseded by a matching website. Overlapping websites use first match, not longest match; Firefox URL detection is unsupported. A phrase at the transcript's beginning/end can switch processing Mode and is removed, but does not retranscribe audio with another model/language. File import ignores spoken triggers. [VI-S13](https://tryvoiceink.com/docs/mode-triggers)

### VI-F11 — Configure AI enhancement and custom prompts · DOCUMENTED

With an available enhancement connection, enable AI Enhancement in a Mode, select provider/model and prompt, then save. Prompt → Add New accepts a name/instructions and optional shared system template. Dictate to obtain transformed text. A separate shared short-input threshold can skip enhancement; timeout handling supports immediate failure or up to three attempts. Ordinary failure can preserve the original with a warning. Refine has different controls. [VI-S14](https://tryvoiceink.com/docs/mode-settings), [VI-S33](https://tryvoiceink.com/docs/prompt-management), [VI-S10](https://tryvoiceink.com/docs/model-settings)

### VI-F12 — Rewrite selected text or use surrounding context · DOCUMENTED

Enable Selected Text, Clipboard, or Screen in an enhanced Mode; select content and dictate the requested transformation. Prompts can distinguish speech, selection, clipboard, window OCR, and vocabulary through tags. Missing Accessibility/Screen Recording causes corresponding context to be skipped. Context is snapshotted locally at recording start; switches govern request inclusion, not every local read. Screen payload is extracted text rather than the screenshot. Imported files capture no live context. [VI-S15](https://tryvoiceink.com/docs/context-awareness), [VI-S34](https://tryvoiceink.com/docs/custom-prompts)

### VI-F13 — Clean up locally with Refine · DOCUMENTED

On Apple Silicon with at least 16 GB RAM, download Refine under AI Models → Local, enable enhancement in a Mode, choose Refine, and use Paste or Custom Command output. A separate transcription model remains necessary. Downloaded Refine cleans punctuation, hesitation, repetition, formatting, and spoken corrections locally without an API key. It offers neither custom prompts/context nor Respond; short-input skipping can apply. [VI-S09](https://tryvoiceink.com/docs/voiceink-refine)

### VI-F14 — Ask an Assistant and continue a conversation · DOCUMENTED

Configure a compatible enhancement provider, Assistant prompt, and Advanced → Output → Respond. Record a question; the answer stays inside the recorder. While its response is visible and idle, recording again or typing continues that session. Closing resets the active conversation but preserves saved turns. This returns text; it does not automatically operate apps. Refine and default-Mode selection are excluded. [VI-S16](https://tryvoiceink.com/docs/assistant-mode)

### VI-F15 — Add vocabulary · DOCUMENTED

For a name or specialized term, open Dictionary → Vocabulary, enter text, and press Return/plus; comma-separated input adds multiple terms. Sort or remove chips afterward. Terms guide supported transcription/enhancement models rather than enforce exact substitution. A configured Quick Add shortcut exposes a smaller entry panel. Recognition success across every provider/language is UNKNOWN. [VI-S22](https://tryvoiceink.com/docs/vocabulary), [VI-S21](https://tryvoiceink.com/docs/word-replacements)

### VI-F16 — Replace phrases and remove fillers · DOCUMENTED

Open Dictionary → Word Replacements, enter original and replacement, then add. Multiple originals can share one result; matching is case-insensitive and considers longer phrases first. Rules can correct spelling or expand boilerplate. Separately, AI Models → gear → Transcription → Remove Filler Words edits cleanup chips. Removing every chip disables this cleanup; meaningful standalone words can otherwise disappear. [VI-S21](https://tryvoiceink.com/docs/word-replacements), [VI-S40](https://tryvoiceink.com/docs/filler-words)

### VI-F17 — Learn from corrections · DOCUMENTED, with version conflict

With Accessibility and a configured review provider, correct recently inserted text. Auto Learn detects reusable corrections; it is enabled by default and has provider settings independent of Modes. Dictionary → gear offers immediate application or manual Review Now followed by approval. Suggestions may become vocabulary, replacements, both, or neither; edit/apply/dismiss them. Provider failures remain pending for Retry; inaccessible fields cannot be observed. Changed passages and limited neighboring words reach the review provider. Local CLI eligibility conflicts with release notes. [VI-S20](https://tryvoiceink.com/docs/auto-learn-dictionary), [VI-S42](https://github.com/Beingpax/VoiceInk/blob/main/appcast.xml)

### VI-F18 — Exchange dictionary data · DOCUMENTED

Under Dictionary → gear → Dictionary Data, export JSON or import a file, inspect counts/conflicts, then confirm Merge or Replace. Merge skips incompatible duplicates; Replace removes existing entries after confirmation. Invalid/empty files are rejected. The archive carries vocabulary/replacements, not pending corrections, provider setup, history, or recordings. [VI-S23](https://tryvoiceink.com/docs/import-export-dictionary)

### VI-F19 — Find, replay, export, or retry a result · DOCUMENTED

Open History, search original/enhanced text, expand a row, and copy, replay retained audio, or inspect metadata. Select rows for CSV export or timing analysis. Quick History supports keyboard search/paste and detail/retry. The Retry Last shortcut reprocesses saved audio with the current Mode, creates another entry, and copies without automatic insertion. Audio cleanup disables replay/retry. Exported audio and subtitle formats remain UNKNOWN. [VI-S18](https://tryvoiceink.com/docs/transcription-history), [VI-S11](https://tryvoiceink.com/docs/shortcuts)

### VI-F20 — Delete history or configure retention · DOCUMENTED

Use History Settings for transcript-plus-audio deletion or audio-only cleanup; these policies are mutually exclusive. Changing duration does not immediately clean; Run Cleanup Now removes eligible old items. Immediate retention still writes a record before removing it. Bulk deletion has confirmation, but enabling transcript cleanup does not. Text-free statistics can remain; application deletion does not promise forensic erasure. [VI-S18](https://tryvoiceink.com/docs/transcription-history), [VI-S31](https://tryvoiceink.com/docs/privacy-and-data)

### VI-F21 — Transcribe audio/video files · DOCUMENTED

Open Transcribe, drag media or choose files, select an enabled Mode, and Start the sequential queue. Supported extensions include common audio/video containers; a batch-capable model is required. Expand completed rows and copy/save original or enhanced text. Results and converted audio also enter History; source files remain untouched. Cancel returns in-progress work to pending; Clear removes queue items but retained history survives. Context, spoken triggers, paste, Respond, commands, and Auto Send do not run. [VI-S19](https://tryvoiceink.com/docs/transcribe-audio-files)

### VI-F22 — Select microphones and recording feedback · DOCUMENTED

In Audio, pin System Default/a device or rank Priority Order for fallback. Refresh when a new input is missing and check macOS Sound → Input levels. Configure recording sounds, temporary audio mute/media pause, and resume delay. The docs describe microphone selection, not a verified system-audio meeting-capture path. Mid-recording disconnection recovery is UNKNOWN. [VI-S24](https://tryvoiceink.com/docs/audio-input)

### VI-F23 — Deliver speech to a command · DOCUMENTED

Select Custom Command output and configure a nonempty command/template, then dictate. Final text reaches stdin and `VOICEINK_TRANSCRIPT`; the recorder closes before execution. Templates include journal append, web search, and paste variants. Commands run with user permissions and a ten-second timeout. Output is diagnostic, not replacement text; failures have no in-app success/error message. Inspect delivery logs. Imported files never execute this output. [VI-S27](https://tryvoiceink.com/docs/custom-commands)

### VI-F24 — Enhance through a local CLI · DOCUMENTED, with version conflict

Install/authenticate the external CLI, open AI Models → Local → Local CLI, choose a template or command, configure timeout, and select it as a Mode's enhancement provider. Prompt input produces final stdout text; errors, empty output, or timeout fail enhancement. Default timeout is 45 seconds. A local process may call a hosted model. This generates text, unlike Custom Command delivery. Auto Learn eligibility remains unresolved. [VI-S28](https://tryvoiceink.com/docs/local-cli)

### VI-F25 — Back up or restore settings · DOCUMENTED

Use Settings → Backup to export JSON; import a file and choose categories. Modes/prompts replace collections; dictionary data merges. Credentials, activations, history/audio, metrics, downloaded models, custom enhancement definitions, and CLI command templates are excluded. On another Mac, reconnect and download those dependencies separately. This is selective configuration portability, not a complete device migration. [VI-S26](https://tryvoiceink.com/docs/backup-and-restore)

### VI-F26 — Configure an on-device workflow · DOCUMENTED

Prepare local speech assets, choose local transcription, and disable enhancement or use a compatible local option. Independently disable Auto Learn or select local Ollama review. Verify commands/endpoints do not route to hosted services. Local records can still retain audio, results, and request context. Provider retention applies to cloud requests. This is a documented configuration path, not a network-audit result; activation/downloads have separate network needs. [VI-S31](https://tryvoiceink.com/docs/privacy-and-data), [VI-S32](https://tryvoiceink.com/privacy)

### VI-F27 — Invoke iOS Quick Dictation · DOCUMENTED

On iOS/iPadOS 18+, complete setup with microphone permission, a ready Mode/model, and Live Activities. In VoiceInk Settings → Shortcuts, Add Shortcut and install Quick Dictation. Assign it to a supported iPhone Action Button or Back Tap. Trigger once, speak, trigger again; vibration signals copied text. Focus the destination and Paste manually. This is not automatic Mac-style insertion. [VI-S29](https://tryvoiceink.com/docs/quick-dictation)

### VI-F28 — Use iOS keyboard or media sharing · MARKETING / DOCUMENTED capability; path UNKNOWN

The App Store documents a voice keyboard, searchable transcripts, local/BYOK models, and Modes. Release notes add sharing audio into the app, sharing completed transcripts, custom models, vocabulary/replacements, and keyboard suggestions. Exact keyboard-enable/full-access steps, app switching, interruption handling, and share-sheet choices were not established. Listing compatibility is iOS/iPadOS 17+, whereas Quick Dictation requires 18+. The companion page advertises free beta followed by a one-time purchase. [VI-S30](https://apps.apple.com/np/app/voiceink-ai-dictation/id6751431158), [VI-S43](https://tryvoiceink.com/ios)

### VI-F29 — Diagnose missing output and collect support evidence · DOCUMENTED

For a failed recording, check permissions/restart, selected microphone/input levels, active Mode, language, model availability, and intended destination. Confirm complete custom endpoints and streaming/batch compatibility. For escalation, Settings → Diagnostics → Export Logs → Export creates an archive; Show in Finder locates it. Dashboard can copy system information. Review logs before sharing; gathering evidence does not submit support automatically. [VI-S38](https://tryvoiceink.com/docs/transcription-failing), [VI-S36](https://tryvoiceink.com/docs/diagnostics)

### VI-F30 — Review usage and model performance · DOCUMENTED

Open Dashboard → View Insights, choose a time range, and inspect activity, model usage, and separate transcription/enhancement timings. Time saved assumes 40 typing words/minute, and token counts are estimates rather than bills. These local text-free metrics are separate from transcript history and may remain after its deletion. The documentation does not establish a metrics-deletion control. [VI-S35](https://tryvoiceink.com/docs/dashboard)

### VI-F31 — Change language and app behavior · DOCUMENTED

For another spoken language, edit the Mode's language/model; multilingual labels do not guarantee every language. For interface language, use Settings → Interface and restart. Settings also exposes Notch/Mini, menu-bar-only operation, Launch at Login, manual/automatic updates, and onboarding reset. Reset repeats onboarding without clearing all settings. Translation and mixed-language reliability are UNKNOWN rather than inferred from multilingual support. [VI-S39](https://tryvoiceink.com/docs/recommended-models), [VI-S25](https://tryvoiceink.com/docs/settings-general)

## Conflicts and coverage gaps

- **Version/hardware:** the homepage says Apple Silicon/macOS 14.4; installation docs and README say macOS 15, and docs discuss Intel cloud use. The appcast identifies 2.21 dated September 28, 2026 with minimum 15.0. A specific downloaded artifact was not checked. [VI-S01](https://tryvoiceink.com/), [VI-S04](https://tryvoiceink.com/docs/installation), [VI-S42](https://github.com/Beingpax/VoiceInk/blob/main/appcast.xml)
- **Auto Learn:** 2.21 release text says Local CLI support was added; current Auto Learn and Local CLI docs exclude it. Eligibility is UNKNOWN for the installed build. [VI-S42](https://github.com/Beingpax/VoiceInk/blob/main/appcast.xml), [VI-S28](https://tryvoiceink.com/docs/local-cli)
- **Privacy wording:** broad homepage local-only language is narrower than documented cloud transcription and separate review/enhancement paths. App Store disclosures mention audio data and are developer-reported, not an Apple verification. No network or storage audit occurred. [VI-S01](https://tryvoiceink.com/), [VI-S32](https://tryvoiceink.com/privacy), [VI-S30](https://apps.apple.com/np/app/voiceink-ai-dictation/id6751431158)
- **Meeting workflows UNKNOWN:** inspected sources do not establish calendar joining, meeting detection, system/microphone channel mixing, speaker labels, timestamp editing, consent indicators, action-item extraction, team sharing, or meeting search. File transcription and generic prompt customization do not prove these workflows. [VI-S19](https://tryvoiceink.com/docs/transcribe-audio-files), [VI-S33](https://tryvoiceink.com/docs/prompt-management)
- **Remaining UNKNOWN:** crash recovery of unsaved audio; maximum session/file sizes; model download resumption; export schemas beyond CSV/text; sync between Apple devices; rollback of app updates; full iOS provider/permission parity; Mac automation URL schemes or App Intents. The releases page timed out; official appcast and App Store release notes supplied release evidence instead.
