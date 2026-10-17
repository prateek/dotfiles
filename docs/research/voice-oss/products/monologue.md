---
status: draft
doc_type: research
summary: "Monologue by Every flow inventory MO-F01–MO-F34 from official guides, public API, changelog and App Store material."
created: 2026-10-12
updated: 2026-10-12
---

# Monologue by Every: public user-flow inventory

This inventory covers the user-confirmed **Monologue by Every** at monologue.to, operated by Every Media, Inc. It records behavior for voice-OSS research without implementation or priority decisions. See the [company contact page](https://www.monologue.to/contact) (MO-S01).

Sources were opened on **2026-10-12**. No app, account, microphone, or authenticated API was exercised. DOCUMENTED means official guides/release notes; MARKETING means product examples or launch narratives; INFERRED means our synthesis; UNKNOWN means unresolved. Nothing was runtime-tested.

The [US App Store listing](https://apps.apple.com/us/app/monologue-smart-dictation/id6755956193) (MO-S43) specifies iOS/iPadOS 17.6 and watchOS 10.6 minimums. The [platform guide](https://www.monologue.to/docs/getting-started/platform-availability) (MO-S05) limits local transcription to Apple silicon and explicitly excludes native Windows/Android apps. Browser Notes remains a separate surface.

The [pricing page](https://www.monologue.to/pricing) (MO-S39) offers a trial of 1,000 dictation words and 10 recorded Notes; Pro advertises unlimited dictation/Notes at $15 monthly or $144 annually and is included with Every. Account entitlements were not verified.

**MO-F01 · Install and authorize Mac** — DOCUMENTED; macOS.

Trigger/preconditions: First installation; an account and microphone are needed. Download, move to Applications, open and sign in. Grant Microphone and Accessibility. Optional Screen Recording enables richer context; restart after permission changes. Try the selected shortcut in an editable field. Outcome: A recording starts and text can be inserted. Branches/limits: Exact onboarding screens and minimum macOS version remain unverified. [MO-S02](https://www.monologue.to/docs/getting-started/mac)

**MO-F02 · Manage account identity and recovery** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: A new device, missing entitlement, lost login, or account change. Reuse the original email/Google/Apple/Every login; check account email and plan. Recover through that provider. Mac email changes require a code; active Every Bundle blocks self-service. iOS offers Delete Account; Mac deletion uses support. Outcome: Access restored or account changed/deleted. Branches/limits: Apple relay identities can split accounts; deletion is permanent. iOS email-change availability has conflicting evidence. [MO-S29](https://www.monologue.to/docs/account-and-privacy/sign-in-and-account-recovery)

**MO-F03 · Dictate and control recording** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: An editable field has focus and recording permissions are granted. On Mac hold right Option and release, or use a separate hands-free toggle. Cancel discards insertion. Settings records keyboard or supported mouse bindings; right Shift opens modes. On mobile tap the keyboard microphone, speak, then stop. Outcome: Cleaned text appears at the cursor. Branches/limits: Keep the destination focused; shortcut conflicts need separate testing. Exact supported mouse buttons are unspecified. [MO-S04](https://www.monologue.to/docs/getting-started/first-dictation), [MO-S06](https://www.monologue.to/docs/dictation/shortcuts)

**MO-F04 · Choose input and media behavior** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: Changing microphones or controlling other audio. In Mic & Audio choose automatic selection or order preferred inputs; check the live meter. Configure sounds and keep/mute/pause media, including per-output choices. Mobile Preferences can prefer the built-in microphone. Outcome: Expected input and audio behavior selected. Branches/limits: Bluetooth activation can clip starts or reduce playback quality; reconnect or test built-in input. [MO-S07](https://www.monologue.to/docs/dictation/microphones-and-audio)

**MO-F05 · Choose language and local processing** — DOCUMENTED; Apple-silicon macOS; iOS; iPadOS.

Trigger/preconditions: Dictating multilingual speech or needing offline transcription. Choose Auto Detect or up to three languages. On Apple-silicon Mac choose Local under Transcription source, download, and wait for installed status; the same control removes the model. Outcome: Raw local transcription works offline; remote service provides smart formatting. Branches/limits: Local accuracy may differ. Mobile local processing, arbitrary model endpoints, and complete offline cleanup are not documented. [MO-S08](https://www.monologue.to/docs/dictation/languages-and-models), [MO-S05](https://www.monologue.to/docs/getting-started/platform-availability)

**MO-F06 · Configure style and app/site activation** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: A recurring writing task needs consistent output. Select or edit a mode. On Mac assign apps or domains and optionally Override default. Configure Auto enter with the target send key. Blazing Fast bypasses usual cleanup and can have separate activations. Outcome: The active mode shapes dictation and may submit it. Branches/limits: Conflicting activation precedence is incomplete; Auto enter can submit before review. Blazing Fast preserves rough speech. [MO-S15](https://www.monologue.to/docs/personalize/modes-and-instructions)

**MO-F07 · Teach and import vocabulary** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: Names or technical words transcribe incorrectly. Open Dictionary, add exact spelling and optional spoken-to-written replacement. Import through the source-app prompts for Aqua Voice, Wispr Flow, Superwhisper, or Willow Voice. Correct duplicate/conflicting entries and retry. Outcome: Personal vocabulary informs future dictation. Branches/limits: Import merge rules, bulk export, and correction-learning mechanics are unspecified. [MO-S14](https://www.monologue.to/docs/personalize/dictionary)

**MO-F08 · Set regional English spelling** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: English transcription needs British or Australian conventions. Keep English as the recording language; add the regional preference in Dictation Instructions. Repeat it in overriding modes when necessary; use Dictionary for individual spellings. Outcome: Normal dictations follow the requested convention. Branches/limits: No separate British/Australian recording-language choice; wrong results can be reported from the affected item. [MO-S16](https://www.monologue.to/docs/personalize/australian-or-british-english)

**MO-F09 · Enable contextual dictation** — DOCUMENTED; macOS.

Trigger/preconditions: Relevant screen text may improve names or references. Enable Deep context in Data & Privacy and grant screen-capture permission. Dictate with relevant material visible; optional access can be revoked through macOS settings. Outcome: Supported on-screen content informs the result. Branches/limits: Exact capture region, exclusion rules, and behavior for inaccessible windows are undocumented. Coding accuracy examples remain marketing claims. [MO-S28](https://www.monologue.to/docs/account-and-privacy/permissions-and-privacy), [MO-S45](https://www.monologue.to/dictation)

**MO-F10 · Recover a dictation or failed paste** — DOCUMENTED; macOS.

Trigger/preconditions: Text missed its destination or an earlier result is needed. Open History; copy, replay available audio, retry a recoverable failure, delete, reveal an available file, or send feedback. Paste last transcript inserts again while preserving prior clipboard contents. Copied/App changed permits manual paste. Outcome: A usable transcript can be recovered. Branches/limits: History retention duration is unknown. Home/Dictations labels differ by source; secure fields can block insertion. [MO-S09](https://www.monologue.to/docs/dictation/history), [MO-S30](https://www.monologue.to/docs/troubleshooting/dictation-and-pasting)

**MO-F11 · Set indicator and background behavior** — DOCUMENTED; macOS.

Trigger/preconditions: Choosing recording visibility or system integration. Settings exposes recording indicators, idle/per-app visibility, launch at login, Dock presence, prevent-sleep behavior, attribution, and compatibility insertion. Newer releases add Dot near the writing field. Outcome: Recording state remains visible in the preferred form. Branches/limits: Guide says Mini; newer release says Dot. Their exact relationship and app-switch paste behavior require runtime inspection. [MO-S10](https://www.monologue.to/docs/dictation/mac-preferences), [MO-S42](https://www.monologue.to/changelog)

**MO-F12 · Install and use the mobile keyboard** — DOCUMENTED; iOS; iPadOS.

Trigger/preconditions: Monologue onboarding is complete. In system Keyboard settings add Monologue and enable Full Access; allow Microphone in the app. Switch via the globe key, record, and stop to insert. Keyboard settings configure typing feedback and correction behavior. Outcome: Dictation works within supported host text fields. Branches/limits: Password/payment fields can force Apple's keyboard; Full Access is required for cross-app dictation. [MO-S03](https://www.monologue.to/docs/getting-started/iphone-and-ipad), [MO-S11](https://www.monologue.to/docs/iphone-and-ipad/keyboard-and-full-access)

**MO-F13 · Reactivate the mobile microphone session** — DOCUMENTED; iOS; iPadOS.

Trigger/preconditions: Keyboard shows Start Monologue or stops responding. Start Monologue opens the main app to activate its microphone session, then attempts to return. Switch back manually if needed. Reopen after force-quit; restore permissions or try Built-in Microphone when levels stay flat. Outcome: The keyboard can record again. Branches/limits: Timeout, calls, interruptions, and route changes can end the session; automatic return is not guaranteed. [MO-S31](https://www.monologue.to/docs/troubleshooting/iphone-and-ipad)

**MO-F14 · Tune mobile modes and activity status** — DOCUMENTED; iOS; iPadOS.

Trigger/preconditions: Changing dictation behavior outside the main app. Preferences selects languages, quiet-recording timeout, microphone, audio behavior, sounds, and haptics. Dictation Instructions edits modes; Blazing Fast skips usual instructions. Enable Live Activities for keyboard dictation or Notes. Outcome: Recording progress appears on Lock Screen or supported Dynamic Island. Branches/limits: Quick Dictation ignores Pause Other Audio. Available timeout values are not listed. [MO-S12](https://www.monologue.to/docs/iphone-and-ipad/preferences-and-modes)

**MO-F15 · Use Action Button or Shortcuts** — DOCUMENTED; supported iPhone; iOS; iPadOS.

Trigger/preconditions: Keyboard, microphone, and Live Activities are configured. Use Monologue's guided Action Button setup to add Dictation to Clipboard, then assign it in iOS. Hold to start and again to finish; selected Monologue keyboard enables cursor insertion. Shortcuts offers dictation modes and Record Note. Outcome: Hardware or automation starts voice capture. Branches/limits: Replacing an existing Action Button assignment changes its prior behavior; shortcut options vary by action. [MO-S13](https://www.monologue.to/docs/iphone-and-ipad/action-button-and-shortcuts)

**MO-F16 · Capture a note or meeting** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: A longer recording should become a saved Note. Open Notes or its shortcut; record, pause/resume, stop and upload. Mac sources include microphone and optional system audio; denied screen permission leaves microphone-only capture. Meeting detection can offer start/end reminders. Mac limits offer 30m/1h/2h/3h/4h/6h, with warning before auto-save. Outcome: A saved recording enters processing. Branches/limits: Meeting detection does not establish automatic recording. Its supported-app list and non-Mac duration limits are unspecified. [MO-S17](https://www.monologue.to/docs/voice-notes/record-a-note), [MO-S42](https://www.monologue.to/changelog)

**MO-F17 · Recover and retry saved recordings** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: A recording is interrupted or processing stalls. Reopen and follow available recovery prompts; check duration and let upload finish. Notes distinguish Uploading, Processing, Completed, and error/retry states. When stuck, reconnect, retry from the note, then report that item. Outcome: Recovered audio can proceed to transcript and summary. Branches/limits: Recovery is conditional, not a lossless guarantee. Do not remove pending local audio; mobile recovery export is separately advertised. [MO-S18](https://www.monologue.to/docs/voice-notes/processing-and-recovery), [MO-S43](https://apps.apple.com/us/app/monologue-smart-dictation/id6755956193)

**MO-F18 · Refine a completed note** — DOCUMENTED; native apps; web.

Trigger/preconditions: A processed Note is available. Edit title/summary; listen alongside the transcript, name speakers, and mark yourself. Regenerate the summary after speaker changes. About Me supplies context for future summaries and allows up to 10,000 characters. Outcome: A clearer saved record and personalized future summaries. Branches/limits: Regeneration overwrites manual summary edits. Editing availability varies by device; transcript-text editing is not established. [MO-S19](https://www.monologue.to/docs/voice-notes/organize-edit-and-share)

**MO-F19 · Organize with tags** — DOCUMENTED; native apps; web.

Trigger/preconditions: A user wants reusable note categories. Create tags before recording. Processing may assign one existing tag from title/summary matching; otherwise leaves the note untagged. Add, replace, remove, rename, or delete tags manually. Outcome: Notes can be categorized and filtered. Branches/limits: Automatic tagging never creates categories; dictation mode instructions do not control tag selection. [MO-S20](https://www.monologue.to/docs/voice-notes/automatic-note-tagging)

**MO-F20 · Find and review Notes on the web** — DOCUMENTED; web.

Trigger/preconditions: A native recording has uploaded to the account. Open Notes, search title/content, filter tags, and paginate older results. Inspect summary, speaker transcript, available recording, status, tags, duration, and date. If missing, finish device upload and refresh. Outcome: Synced recordings are reviewable in a browser. Branches/limits: The web app does not record new Notes. Offline browser access is undocumented. [MO-S21](https://www.monologue.to/docs/web-app/notes)

**MO-F21 · Edit, share, revoke, and save shared Notes** — DOCUMENTED; web; macOS; iOS.

Trigger/preconditions: A completed Note or received public link exists. Web title/summary changes autosave. Copy text/Markdown or speaker transcript; create a link after processing. Recipients can read without accounts or sign in to Save to Monologue. Turn off sharing to revoke access. Outcome: Shared with me retains read-only access and is available through MCP. Branches/limits: Saving preserves a reference, not a copy; owner revocation still applies. Deletion is permanent. [MO-S22](https://www.monologue.to/docs/web-app/edit-organize-and-share)

**MO-F22 · Manage keys and connected applications** — DOCUMENTED; web; macOS.

Trigger/preconditions: An external tool needs account access. Create a personal key, copy its one-time secret, and later revoke it in API Keys. Connected apps exposes granted scopes and revocation. Webhooks management, when available, includes tests, delivery inspection, pause/resume, rotation, and deletion. Outcome: External access can be granted and withdrawn. Branches/limits: Account/backend flags may hide sections; revoking the current web authorization signs the user out. [MO-S23](https://www.monologue.to/docs/web-app/settings-and-connections)

**MO-F23 · Connect an AI agent through MCP** — DOCUMENTED; macOS setup; compatible agent clients.

Trigger/preconditions: Saved Notes and a compatible AI client exist. Open Settings → Notes → Connect an AI Agent, select the tool, use the current setup, authorize in browser, then ask for a recent note. Revoke and repeat the scoped setup if the connection fails. Outcome: Hosted MCP enables read-only search and retrieval. Branches/limits: Some clients need a helper. Exact current command/client matrix is in-app; create/edit/delete are unavailable. [MO-S25](https://www.monologue.to/docs/integrations/mcp), [MO-S24](https://www.monologue.to/docs/integrations/choose-a-connection)

**MO-F24 · Use the CLI from a terminal** — DOCUMENTED; CLI; macOS setup.

Trigger/preconditions: A trusted terminal and personal Notes API key are available. Copy the current install command from Mac Notes settings; provide the key to monologue onboarding and verify. Use notes list, query search, or notes get with an optional transcript field. Outcome: Scripts or local agents retrieve saved content. Branches/limits: CLI cannot create/edit/delete Notes. Revoking a reused key disconnects every tool using it; installed-version behavior was not tested. [MO-S26](https://www.monologue.to/docs/integrations/cli)

**MO-F25 · Retrieve Notes and original audio by API** — DOCUMENTED; HTTP API.

Trigger/preconditions: An account with Notes and a notes:read token exists. List/search/filter Notes, follow pagination, then fetch a note's detail for transcript segments and recording URL. Download the signed audio URL separately; refresh it after expiry. Outcome: Owner-authorized metadata, transcripts, and existing original audio are available. Branches/limits: Unknown/inaccessible Notes return 404. Public API docs say owner-only, unlike MCP's shared-note description; audio may be unavailable. [MO-S35](https://www.monologue.to/docs/public-api), [MO-S37](https://www.monologue.to/docs/public-api/notes)

**MO-F26 · Receive processing events** — DOCUMENTED; HTTPS server; account gated.

Trigger/preconditions: Webhooks is enabled and a public HTTPS receiver exists. Create an endpoint, receive ping, then processed/failed events. Verify signatures on raw bytes, acknowledge promptly, and deduplicate event IDs. Settings supports test delivery and signing-secret rotation. Outcome: A user's server reacts to note completion or failure. Branches/limits: Private addresses are rejected. Deliveries may repeat or arrive out of order; repeated failures can disable delivery. [MO-S36](https://www.monologue.to/docs/public-api/webhooks)

**MO-F27 · Record from Apple Watch and return on desktop** — MARKETING; watchOS; Apple devices.

Trigger/preconditions: A configured Watch app and synced Monologue account are assumed. Every describes starting a Watch recording, keeping the phone pocketed, and retrieving the resulting Note with an agent at the computer. Mobile release notes describe background Watch uploads and recovery. Outcome: A mobile thought becomes shared account context. Branches/limits: Exact Watch start/stop controls, installation/sign-in, cellular independence, offline limits, and phone-free capture guarantees remain unknown. [MO-S44](https://every.to/on-every/introducing-monologue-notes-record-every-meeting-call-and-voice-memo), [MO-S43](https://apps.apple.com/us/app/monologue-smart-dictation/id6755956193)

**MO-F28 · Check entitlement and manage billing** — DOCUMENTED; macOS; iOS; iPadOS; billing web.

Trigger/preconditions: Trial allowance is exhausted or subscription management is needed. Check Plan & Billing on Mac or Subscription on mobile. Manage through the listed purchase source: Apple, direct portal, Every, or team administrator. Confirm account identity before purchasing again. Outcome: Subscription access or cancellation is handled by its owner. Branches/limits: Canceling one source does not cancel another; credits/refunds do not necessarily transfer. Trial reset cadence and expiry behavior are unspecified. [MO-S27](https://www.monologue.to/docs/account-and-privacy/account-and-billing), [MO-S39](https://www.monologue.to/pricing)

**MO-F29 · Control local history and cloud data** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: A user reviews retained data or contribution settings. Data & Privacy deletes device-local dictation data and controls optional transcript sharing. Vendor privacy materials distinguish ephemeral Dictation processing from stored Notes audio/transcripts/summaries and synced personalization. Outcome: Local data or sharing preferences change without implying account deletion. Branches/limits: Zero-retention claims are vendor assertions. Policy includes opt-in storage exceptions; Note deletion timing, backups, and encryption details remain unresolved. [MO-S28](https://www.monologue.to/docs/account-and-privacy/permissions-and-privacy), [MO-S40](https://www.monologue.to/data-privacy), [MO-S41](https://www.monologue.to/privacy)

**MO-F30 · Diagnose errors and send contextual feedback** — DOCUMENTED; macOS; iOS; iPadOS.

Trigger/preconditions: Recording, quality, performance, or connectivity fails. Save active work before restarting. Test a short example; isolate language/dictionary from mode formatting. Run Check connection in Help; it uploads synthetic test data and reports network performance. Send item-specific feedback or requested logs. Outcome: Support receives a reproducible example and relevant diagnostics. Branches/limits: A passing connection test cannot prove every backend works. Feedback can attach the affected dictation or Note. [MO-S32](https://www.monologue.to/docs/troubleshooting/performance-and-crashes), [MO-S33](https://www.monologue.to/docs/troubleshooting/language-and-unexpected-words), [MO-S34](https://www.monologue.to/docs/troubleshooting/connection-and-diagnostics)

**MO-F31 · Compose or edit text by voice** — DOCUMENTED; macOS beta.

Trigger/preconditions: Beta Mode is enabled on a release offering Compose. The September 2026 release notes announce voice writing/editing with Compose. Outcome: A beta editing capability is claimed. Branches/limits: Invocation, selection scope, preview, accept/reject, undo, and error recovery are not publicly specified in examined guides. [MO-S42](https://www.monologue.to/changelog)

**MO-F32 · Find Notes through system discovery** — DOCUMENTED; iOS 27; iOS app v1.2.

Trigger/preconditions: Synced Notes are available on the documented OS/app version. Release notes describe asking Siri AI to find/open Notes, discovering them in Spotlight, and accessing them through Shortcuts. Outcome: Saved context can be opened from system entry points. Branches/limits: Exact utterances, indexing/privacy settings, and failed-search handling are undocumented. [MO-S43](https://apps.apple.com/us/app/monologue-smart-dictation/id6755956193)

**MO-F33 · Integrate enterprise dictation** — DOCUMENTED; approved organizations; HTTP/WebSocket.

Trigger/preconditions: Monologue approves an organization and provisions credentials. The separate private-beta API offers batch audio/text formatting and realtime audio streaming; onboarding starts through Monologue support. Outcome: An approved application can use the dictation pipeline. Branches/limits: This is not the public Notes API. Self-service signup, pricing, hosted-region choices, and self-hosted deployment are not established. [MO-S38](https://www.monologue.to/docs/enterprise-api)

**MO-F34 · Use context-sensitive writing in coding and communication apps** — MARKETING; macOS; iOS; iPadOS.

Trigger/preconditions: An editable app field and relevant context are available. Product examples show technical prompts, structured updates, conversational messages, and formatted email; cleanup retains final intent after spoken self-correction. Outcome: Text is shaped for the current task. Branches/limits: Exact app coverage, latency, error rate, selected-text rewriting, and preservation of identifiers are untested. [MO-S45](https://www.monologue.to/dictation), [MO-S46](https://www.monologue.to/)

**Documented surfaces/components.** Mac: onboarding, permissions, sidebar/history cards, menu bar, floating indicators, shortcut capture, microphone meter/selection, modes, privacy/billing/help. Mobile: custom keyboard, host-app handoff, Live Activities, Action Button setup, recovery. Notes: searchable/filterable list, processing statuses, transcript/audio detail, speaker controls, editable summary, sharing, connections. This inventory derives from the cited text; appearance was not inspected.

**Data concepts — INFERRED.** Product vocabulary includes Dictation results, persisted Notes, recordings, transcript segments, summaries, speakers, modes/activation rules, dictionary replacements, tags, entitlements, share references, API keys/authorizations, and webhook deliveries. Internal schema is UNKNOWN.

**Public coverage gaps and contradictions.**

- The [History guide](https://www.monologue.to/docs/dictation/history) still uses Home; the [changelog](https://www.monologue.to/changelog) renames it Dictations. Indicator naming and destination retention also differ between guides and Dot release notes. Preserve both accounts pending an installed-app walkthrough.
- The [account guide](https://www.monologue.to/docs/account-and-privacy/sign-in-and-account-recovery) directs mobile email changes to support, while earlier [iOS release notes](https://www.monologue.to/changelog) announced that action. Current mobile availability is UNKNOWN.
- The [Notes API](https://www.monologue.to/docs/public-api/notes) restricts reads to owned Notes; the [sharing guide](https://www.monologue.to/docs/web-app/edit-organize-and-share) includes saved shared Notes in MCP. Do not assume identical authorization scope.
- [Privacy policy](https://www.monologue.to/privacy) wording, effective October 2025, includes opt-in storage/contribution exceptions. The newer [privacy overview](https://www.monologue.to/data-privacy) distinguishes stored Notes from Dictation. Neither demonstrates observed retention, backup deletion, or encryption architecture.
- UNKNOWN: self-hosted backend, user-supplied remote/model endpoints, model licensing, local iOS/Watch inference, full offline Notes processing, explicit translation mode, arbitrary audio import, calendar-linked meeting workflows, complete bulk export, undo/version history, team administration, and accessibility conformance. These may exist without public documentation.
- Watch exact controls and standalone operation, Compose editing transitions, paywall exhaustion/renewal failures, concurrent edits, dictionary merge behavior, and cross-device sync conflicts need targeted firsthand validation.

Machine-readable companions: [source ledger](../data/sources.jsonl) and [flow inventory](../data/flows.json). 46 sources; 34 flows.
