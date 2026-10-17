---
status: draft
doc_type: research
summary: "Wispr Flow flow inventory WF-F01–WF-F41 covering dictation and newer notes, meeting and agent workflows."
created: 2026-10-12
updated: 2026-10-12
---

# Wispr Flow: public user-flow evidence

Public documentation snapshot: 2026-10-12. Forty-one primary pages were read, two through direct public HTML after tool timeouts. No hands-on validation occurred; this records evidence, not priorities.

**DOCUMENTED** denotes first-party instructions; **MARKETING**, promotional claims; **INFERRED**, this report's model; **UNKNOWN**, missing/conflicting evidence. Platform/plan statements do not guarantee universal rollout. [Sources](../data/sources.jsonl) and [flows](../data/flows.json) preserve IDs.

## Documented flows

### WF-F01 — Install and authorize the Mac app

**DOCUMENTED · macOS.** Preconditions: macOS 12+, correct Intel or Apple Silicon installer. Path: Move Wispr Flow.app directly into an accepted Applications folder; launch; grant Accessibility and Microphone; continue. **Outcome:** App can proceed to setup. **Branches/limits:** Wrong location or architecture exits; retry timed-out permission requests. Install guide limits Input Monitoring to standalone Caps Lock, unlike S05. [Install (WF-S01)](https://docs.wisprflow.ai/articles/7682075140-how-to-install-wispr-flow-on-mac)

### WF-F02 — Create an account and finish onboarding

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Installed app; internet and an identity provider. Path: Use browser sign-in on desktop or mobile sign-in; complete permissions, microphone test, shortcut/language choices, practice and data preference. **Outcome:** Hub or mobile Home opens; unfinished setup can resume. **Branches/limits:** Google, Apple, Microsoft, SSO and email/password supported; provider mismatch and expired verification require restarting sign-in. Organization screens vary. [Onboarding (WF-S02)](https://docs.wisprflow.ai/articles/3152211871)

### WF-F03 — Dictate into another app

**DOCUMENTED · macOS, Windows.** Preconditions: Setup complete; text field focused. Path: Hold the dictation shortcut, speak, release, then review inserted text. **Outcome:** Completed text appears at the cursor after stopping. **Branches/limits:** Default Mac Fn becomes Ctrl+Option without Apple Fn. Desktop output is not a live word-by-word transcript; transcription requires connectivity. [Dictation (WF-S03)](https://docs.wisprflow.ai/articles/2772472373-what-is-flow)

### WF-F04 — Change activation and recovery shortcuts

**DOCUMENTED · macOS, Windows.** Preconditions: Settings accessible; supported keyboard or mouse. Path: Open General → Shortcuts → Change; select a binding; record keys; release to save; finish with Done. **Outcome:** Device-specific binding replaces or supplements the old one. **Branches/limits:** Three-key maximum; four bindings per action except Cancel. Reserved/duplicate combinations fail. Reset has no undo; bindings do not sync. [Shortcuts (WF-S04)](https://docs.wisprflow.ai/articles/2612050838-Supported-&-Unsupported-Keyboard-Hotkey-Shortcuts)

### WF-F05 — Run hands-free and recover a failed insertion

**DOCUMENTED · macOS, Windows.** Preconditions: Signed in; permissions and word allowance. Path: Press Fn+Space on Mac, double-tap push-to-talk, or click Flow Bar; speak; stop. Use Paste Last Transcript or History recovery after failure. **Outcome:** Text pastes; retained audio can be retried. **Branches/limits:** Esc/X cancels; rapid triple-tap cancels. Recording ends at 20 minutes. Offline recording may save audio, but retry requires retained audio; never-store prevents recovery. [Hands-free (WF-S05)](https://docs.wisprflow.ai/articles/6391241694-use-flow-hands-free)

### WF-F06 — Choose writing style

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Personalization available; iPhone external-app trial completed. Path: Open Style; complete guided categories; choose a style card. In iPhone Default Sound layout choose the card and Save. **Outcome:** New dictations use chosen capitalization and punctuation. **Branches/limits:** Desktop categories are Personal, Work, Email, Other; iPhone has alternate layouts. Formal/Casual and category-dependent Very casual/Excited differ. Notices limit style formatting to English. [Styles (WF-S06)](https://docs.wisprflow.ai/articles/2368263928-how-to-setup-flow-styles)

### WF-F07 — Use or disable app context

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Dictation target provides readable context. Path: Dictate normally for automatic app/category adaptation; desktop Data and Privacy can disable Context awareness. **Outcome:** Names, casing and formatting adapt to nearby text. **Branches/limits:** Desktop still sends app/domain and locally matches surrounding text when disabled. iPhone has no switch. Standard password fields are excluded; custom/web fields may not be. [App context (WF-S07)](https://docs.wisprflow.ai/articles/4678293671-Context-Awareness)

### WF-F08 — Select languages and regional spelling

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Language settings accessible. Path: Choose Auto-detect or selected languages; desktop saves explicitly, iPhone saves each tap; start another dictation. **Outcome:** Saved choices constrain recognition and spelling/script. **Branches/limits:** Docs specify one detected language per dictation; Hinglish requires explicit selection. Wrong-language output suggests selecting one language. Mixed-sentence onboarding claims remain unresolved. [Languages (WF-S08)](https://docs.wisprflow.ai/articles/3191899797-use-flow-with-multiple-languages)

### WF-F09 — Correct yourself while speaking

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Active dictation. Path: Speak naturally, self-correct with context, or name punctuation/paragraph breaks; finish dictation. **Outcome:** Smart Formatting removes clear false starts and creates structure. **Branches/limits:** Backtrack is contextual, not a guaranteed literal command. Misheard words need other correction. Original and formatted versions can differ; some punctuation names may fail. [Backtrack (WF-S09)](https://docs.wisprflow.ai/articles/5373093536-How-do-I-use-Smart-Formatting-&-Backtrack)

### WF-F10 — Control cleanup and restore the original

**DOCUMENTED · macOS, Windows.** Preconditions: Auto Cleanup beta available. Path: Open Style → Auto Cleanup; choose None, Light or Medium. For unwanted changes, use Home row menu → Undo AI edit. **Outcome:** Next dictation changes cleanup level; original text can be recovered. **Branches/limits:** None preserves fillers; Light is default; Medium can reword. AI-app/command paths and formatting failures may bypass cleanup. Recovery still depends on retained history. [Cleanup (WF-S10)](https://docs.wisprflow.ai/articles/4283510616-auto-cleanup-control-how-much-flow-edits-your-dictation-beta)

### WF-F11 — Teach vocabulary and exact replacements

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Dictionary unlocked. Path: Add a word; optionally enable Correct a misspelling and provide the wrong form; save and dictate again. Edit or delete entries later. **Outcome:** Vocabulary improves recognition; corrections replace matching words. **Branches/limits:** Desktop fields allow 60 characters, iPhone 59. Corrections are literal. Eligible manual edits can auto-teach terms; deleting a learned desktop word prevents automatic re-addition. [Dictionary (WF-S11)](https://docs.wisprflow.ai/articles/4052411709-Teach-Flow-your-words-with-the-dictionary)

### WF-F12 — Expand reusable spoken snippets

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Snippets unlocked; personal snippets include Basic. Path: Add a distinctive trigger and expansion; save; speak the trigger during dictation. **Outcome:** Saved text replaces the trigger. **Branches/limits:** Desktop expansion limit is 4,000 characters; variables are unsupported. Duplicate/conflicting triggers and rich-text destination support matter. Failed iPhone edits can remove the local original. [Snippets (WF-S12)](https://docs.wisprflow.ai/articles/5784437944-create-and-use-snippets)

### WF-F13 — Import vocabulary or snippets

**DOCUMENTED · macOS, Windows.** Preconditions: Eligible paid/trial account; Experimental Bulk import enabled. Path: Open library Import; choose personal/team destination; upload dictionary CSV or snippet JSON; inspect preview/skips; confirm. **Outcome:** Valid entries enter the selected library and sync when allowed. **Branches/limits:** Files max 3 MB; max 1,000 valid nonduplicate entries. Malformed rows skip; failed imports return to upload. Team sharing can move personal entries. [Bulk import (WF-S13)](https://docs.wisprflow.ai/articles/8955301725-How-Do-I-Bulk-Import-Dictionary-Items-and-Snippets)

### WF-F14 — Inspect, copy or remove dictation history

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: A locally retained dictation exists. Path: Open Home history; find an entry; copy its text or retry retained audio. On iPhone long-press → Delete → confirm. **Outcome:** Transcript can be reused or removed. **Branches/limits:** History is device-specific; deletion is permanent and may not remove cloud copies. iPhone swipe exposes actions but does not delete. Report submits transcript/audio/logs. [Navigation (WF-S14)](https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android)

### WF-F15 — Issue a spoken edit or search command

**DOCUMENTED · macOS, Windows; limited iPhone.** Preconditions: Eligible paid/trial access; Command Mode enabled in Experimental. Path: Focus editable text; hold Fn+Ctrl on Mac; speak an instruction; release. **Outcome:** Text changes in place; search can open Perplexity. **Branches/limits:** Current field and selection accompany the request. No usable text can produce no edit; no editable field yields a notification. iPhone in-place editing is explicitly not working. [Command Mode (WF-S15)](https://docs.wisprflow.ai/articles/4816967992-how-to-use-command-mode)

### WF-F16 — Rewrite with Transforms and custom prompts

**DOCUMENTED · macOS, Windows; iPhone Polish.** Preconditions: Transforms available and opted in. Path: Run guided sample; select text and activate Polish or a saved prompt; inspect View Diff; copy, retry or undo. **Outcome:** Rewrite replaces text or opens in Scratchpad. **Branches/limits:** Desktop accepts 1–1,000 words; iPhone Polish 10–1,000. Custom name/prompt/shortcut required. Auto Apply runs after dictation; failure falls back to original text. Organization policy can disable it. [Transforms (WF-S16)](https://docs.wisprflow.ai/articles/8068950331-how-to-use-transforms-beta)

### WF-F17 — Install the iPhone keyboard

**DOCUMENTED · iPhone.** Preconditions: Flow installed, opened and signed in. Path: iOS Settings → General → Keyboard → Keyboards → Add New Keyboard; add Flow, enable Full Access; allow microphone in Flow; choose Flow with globe. **Outcome:** Keyboard can dictate into standard text fields. **Branches/limits:** Missing permissions replace controls with setup guidance. Custom fields may reject third-party keyboards; number/phone/email fields switch keyboards. Calls or headset changes stop capture. [iPhone keyboard (WF-S17)](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone)

### WF-F18 — Start, finish and recover an iPhone session

**DOCUMENTED · iPhone.** Preconditions: Flow keyboard active; microphone and Full Access granted. Path: Tap Start Flow; return automatically or swipe along bottom edge; speak; stop with primary control; wait for insertion. **Outcome:** Text returns to the active field. **Branches/limits:** Busy sessions block a new start; pressing during processing cancels. Exact-place versus app-only return differs between docs. Disable Flow after exists, but timer choices/session semantics were not established. [iPhone sessions (WF-S18)](https://docs.wisprflow.ai/articles/6269634092-adapting-to-ios-26-4), [Navigation (WF-S14)](https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android)

### WF-F19 — Launch capture with iPhone system actions

**DOCUMENTED · iPhone.** Preconditions: Microphone, Full Access and required Live Activities enabled. Path: Assign Flow action to Action Button, Back Tap, Shortcuts/Siri or Control Center; trigger; speak; trigger again or stop in Live Activity. **Outcome:** Action inserts into active Flow keyboard or returns/copies/saves text according to action. **Branches/limits:** Without active keyboard, clipboard and note actions differ. Starts can require Live Activities; stopping is not blocked. Action Button and Dynamic Island depend on device. [iPhone shortcuts (WF-S19)](https://docs.wisprflow.ai/articles/1986921789-How-to-Set-Up-Flow-Shortcuts-for-iPhone)

### WF-F20 — Capture and manage iPhone notes

**DOCUMENTED · iPhone.** Preconditions: Scratchpad unlocked; first note requires keyboard setup. Path: Create note; dictate using editor mic; stop; wait for text; leave editor. Quick capture instead requires explicit Save. **Outcome:** In-app edits autosave; saved notes can be searched, copied or shared. **Branches/limits:** Leaving during dictation discards unfinished speech. Quick capture never autosaves. Delete propagates through sync; clearing title and body can delete without confirmation. Restricted accounts may remain local. [iPhone notes (WF-S20)](https://docs.wisprflow.ai/articles/3529886556-Using-Notes-in-Wispr-Flow-for-iOS)

### WF-F21 — Draft in desktop Scratchpad

**DOCUMENTED · macOS, Windows.** Preconditions: Scratchpad enabled by organization. Path: Create note; type or dictate; use tabs, pins and search; restore a saved version if needed. **Outcome:** Draft autosaves and can sync independently of dictation storage. **Branches/limits:** Five tabs per window; up to 50 versions. Pins stay local. Deletion permanently removes history; images have separate upload and platform limits. [Scratchpad (WF-S21)](https://docs.wisprflow.ai/articles/9618237082-using-the-scratchpad-to-save-and-edit-notes)

### WF-F22 — Use the same account across devices

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Devices online and signed into same original account/provider. Path: Confirm matching email/plan; change a dictionary entry on one device; wait and check the other; refresh/restart if needed. **Outcome:** Dictionary, snippets and supported preferences sync. **Branches/limits:** Shortcuts, microphone and sounds stay local; history lists local dictations. Concurrent preference changes can overwrite each other. Sign-out destroys local-only content; sync latency is not guaranteed. [Device sync (WF-S22)](https://docs.wisprflow.ai/articles/5284722493-sync-flow-across-your-devices)

### WF-F23 — Set training, cloud and local-data preferences

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Signed in; policy permits changes. Path: Open Data and Privacy; independently set model improvement, dictation cloud storage, context and local retention; confirm destructive retention changes. **Outcome:** Chosen controls alter separate data uses. **Branches/limits:** Opting out of training does not disable cloud processing. Local options include 24-hour deletion and never-store. BAA/policy locks apply; meeting storage and Scratchpad follow separate rules. [Data settings (WF-S23)](https://docs.wisprflow.ai/articles/9609615338-private-cloud-sync-and-data-sharing-preferences-in-wispr-flow)

### WF-F24 — Export retained account data

**DOCUMENTED · macOS, Windows.** Preconditions: Data export allowed for account. Path: Data and Privacy → Download your data → Request a copy; wait for readiness email; download ZIP. **Outcome:** Export contains retained dictations, meetings, notes and settings. **Branches/limits:** Preparation can be cancelled; download expires after 30 days. Never-uploaded/local-only history is absent. Organization restrictions, cooldowns or large accounts can block export. [Data export (WF-S24)](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq)

### WF-F25 — Manage identity, sign out or delete account

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Account accessible; save needed local work. Path: Edit profile in Account; sign out to change identity. Delete account requires confirmation and exact email on desktop. **Outcome:** Profile updates or account-deletion request is submitted. **Branches/limits:** Email/provider changes are not normal profile edits. Sign-out clears local data. iPhone sign-out does not prove deletion succeeded; store subscriptions require separate cancellation and other-device local history can remain. [Account management (WF-S25)](https://docs.wisprflow.ai/articles/7339517111-manage-your-flow-account)

### WF-F26 — Publish and govern team vocabulary

**DOCUMENTED · Desktop/iPhone membership; web administration.** Preconditions: Active eligible team membership; admin role for policy. Path: Use shared library for team entries; administrators select Unrestricted or Department only in Organization settings. **Outcome:** Shared words/snippets become usable within allowed scope. **Branches/limits:** Department only blocks nonadmin org-wide changes, preserving existing entries. Team imports do not create org-wide entries. Save failures roll settings back; plan naming varies. [Team policies (WF-S26)](https://docs.wisprflow.ai/articles/7133384604-restrict-org-wide-snippet-and-dictionary-sharing-snippet-sharing-policy), [Dictionary (WF-S11)](https://docs.wisprflow.ai/articles/4052411709-Teach-Flow-your-words-with-the-dictionary)

### WF-F27 — Choose, trial or purchase a plan

**DOCUMENTED · Desktop, iPhone, web.** Preconditions: Correct account and billing owner. Path: Open Plans and Billing; select individual/team plan or eligible student claim; complete provider checkout. **Outcome:** Subscription grants plan features across devices. **Branches/limits:** Pro list price is $15/month or $144/year. Student free claim is desktop-only. Growth/Enterprise, trials and Notetaker access differ by organization; paid Notetaker documents a 150-meeting weekly cap. [Plan comparison (WF-S27)](https://docs.wisprflow.ai/articles/9559327591)

### WF-F28 — Handle allowance warnings or stale usage

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Free plan or unexpected limit. Path: Inspect usage and plan; restart/refresh; upgrade or wait for reset; contact support if inconsistent. **Outcome:** Allowance or paid access becomes usable when confirmed. **Branches/limits:** Desktop soft/hard caps: 2,000/5,000 words; shared mobile pool: 1,000/1,500. Help specifies Sunday 23:45 UTC despite midnight-PT UI wording. Clearing history does not renew allowance. [Word limits (WF-S28)](https://docs.wisprflow.ai/articles/3715544288-weekly-word-limit-not-resetting-troubleshooting-guide)

### WF-F29 — Dictate quietly

**MARKETING · Platforms marketed by Wispr.** Preconditions: Suitable microphone proximity. Path: Use ordinary dictation while speaking quietly. **Outcome:** Vendor claims recognition down to whisper volume. **Branches/limits:** No separate Whisper Mode toggle, calibration path, noise threshold or measured whisper accuracy was established. Treat this as positioning, not a verified mode. [Quiet speech (WF-S29)](https://wisprflow.ai/)

### WF-F30 — Navigate without a pointer or with a screen reader

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: Keyboard/screen reader available. Path: Use Tab/Shift+Tab, arrows and activation keys; navigate history and settings; enable system Reduce Motion if desired. **Outcome:** Supported controls expose keyboard and assistive labels. **Branches/limits:** Vendor reports Mac VoiceOver testing, but documents mouse-only Flow Bar menus, unnamed icons, hover-only explanations and incomplete older dialogs. iPhone key labels ignore accessibility text sizing. [Accessibility (WF-S30)](https://docs.wisprflow.ai/articles/3941699399-keyboard-and-screen-reader-accessibility-in-wispr-flow)

### WF-F31 — Diagnose silence, unavailable input or missing text

**DOCUMENTED · macOS, Windows, iPhone.** Preconditions: A dictation fails or captures no speech. Path: Check mute and permissions; test another recorder; select/test desktop input; inspect saved audio; retry transcription or contact support. **Outcome:** Separates capture failure from transcription failure. **Branches/limits:** Never-captured or never-stored audio cannot recover. iPhone interruptions require restarting capture. Closing a recording bubble may not stop capture; explicitly stop before microphone recovery. [Microphone troubleshooting (WF-S31)](https://docs.wisprflow.ai/articles/4351452717-troubleshooting-mic-issues)

### WF-F32 — Connect or revoke a calendar/Slack integration

**DOCUMENTED · macOS, Windows.** Preconditions: Connector offered and allowed. Path: Settings → Connectors → Connect; authenticate in browser and grant requested access; confirm connected row. Use row menu to disconnect. **Outcome:** Calendar reminders/context or Slack context becomes available. **Branches/limits:** Partial calendar authorization needs completion; changing accounts can require disconnection. Admin-disabled existing connections remain authorized but unavailable. Disconnect can affect briefs; existing meeting-linked calendar events remain. [Connectors (WF-S32)](https://docs.wisprflow.ai/articles/9962971864-connectors-in-wispr-flow-connect-disconnect-and-organization-blocked-connectors)

### WF-F33 — Capture and stop a meeting

**DOCUMENTED · macOS 13+, Windows.** Preconditions: Notetaker access, onboarding, consent and audio permissions. Path: Open New note or scheduled Join and record; follow live transcript and personal notes; explicitly Stop; await saved transcript/summary. **Outcome:** Meeting becomes reviewable; closing notepad alone keeps recording. **Branches/limits:** One meeting at a time. Optional auto-start requires detection and rollout access. Default limit two hours; configurable 30 minutes–three hours. Short meetings may need Generate summary; BAA/policy can block. [Meeting recording (WF-S33)](https://docs.wisprflow.ai/articles/9238501024-recording-a-meeting-with-notetaker-beta)

### WF-F34 — Review speakers, summary and meeting questions

**DOCUMENTED · macOS, Windows.** Preconditions: Saved or active accessible meeting. Path: Open Transcript/Summary/My thoughts; assign speaker names; edit notes or summary; ask a question or explicit edit through Ask anything. **Outcome:** Meeting context becomes readable and reusable. **Branches/limits:** Transcript is not editable. Updated summary replaces manual summary edits; personal notes stay separate. Sending another question stops prior reply. Markdown copy includes private notes and chat, unlike normal sharing. [Meeting editor (WF-S34)](https://docs.wisprflow.ai/articles/9406970664-Meeting-notes-and-the-editor-in-Notetaker)

### WF-F35 — Share a meeting or folder

**DOCUMENTED · macOS, Windows; recipient web/app.** Preconditions: Sharing permitted; saved meeting accessible. Path: Open Share; add people, choose visibility and copy link; alternatively file into a shared folder. **Outcome:** Invited users or link recipients access permitted meeting content. **Branches/limits:** Links expose summaries; transcript access needs direct invitation and owner policy. Shared folders have contributors, no view-only role. Policy blocks sharing; failed changes roll back. Cloud Sync wording is internally inconsistent. [Meeting sharing (WF-S35)](https://docs.wisprflow.ai/articles/5073796184-sharing-meeting-notes-from-notetaker-beta)

### WF-F36 — Set meeting retention or delete a meeting

**DOCUMENTED · macOS, Windows.** Preconditions: Meeting ownership; retention policy editable. Path: Choose retention interval in Data and Privacy and confirm shortening; or select past meeting delete and confirm. **Outcome:** Old transcripts expire or whole meeting disappears. **Branches/limits:** Transcript retention leaves notes/summary; uploaded audio separately expires after seven days. Whole-meeting deletion removes associated content irreversibly. Failed deletion can make the row reappear. [Meeting retention (WF-S36)](https://docs.wisprflow.ai/articles/1761520520-transcript-retention-syncing-and-deleting-meetings-in-notetaker-beta)

### WF-F37 — Read meeting knowledge from an AI client

**DOCUMENTED · macOS/Windows setup; remote MCP client.** Preconditions: Notetaker/MCP access and allowed account policy. Path: Settings → MCP; open client setup or copy server URL; authorize correct account; ask about a known meeting. **Outcome:** Client reads allowed meeting, note, calendar and task data. **Branches/limits:** Read-only; no dictation-history access. Account-wide consent, not per meeting. Disconnect in client. BAA or organizational restrictions block access; displayed client card does not prove authorization. [MCP connection (WF-S37)](https://docs.wisprflow.ai/articles/9551372685-connect-an-mcp-client-to-wispr-flow-remote-mcp-server)

### WF-F38 — Import previous meetings

**DOCUMENTED · macOS, Windows.** Preconditions: Signed in; import source enabled; provider export obtained. Path: Notetaker import card → Granola/Otter → upload supported export; keep Flow open; inspect completion and transcript progress. **Outcome:** Past text notes/summaries/transcripts enter Flow. **Branches/limits:** No audio or calendar linkage imported. Partial/skipped records require checking; background transcript work can continue after meeting rows appear. Cloud upload has separate policy implications; reimport can restore deleted records. [Meeting import (WF-S38)](https://docs.wisprflow.ai/articles/4484290718-import-your-past-meetings-from-granola-or-otter-into-notetaker)

### WF-F39 — View upcoming meetings on iPhone

**DOCUMENTED · iPhone.** Preconditions: Calendar connected, online, eligible non-Enterprise account. Path: Open Notetaker Home and inspect upcoming/imminent events. **Outcome:** Next five events and countdowns provide schedule context. **Branches/limits:** Tapping an upcoming card does not start recording. Page labels content as desktop-recorded yet mentions Start/record controls; full iPhone recording path and rollout are UNKNOWN. [iPhone meetings (WF-S39)](https://docs.wisprflow.ai/articles/3693950131-upcoming-meetings-in-notetaker-on-ios)

### WF-F40 — Continue capture without internet

**DOCUMENTED · macOS, Windows.** Preconditions: Notetaker eligible; working local storage. Path: Start offline; when prompted choose Record offline. Reconnect for later transcription/processing. **Outcome:** Audio is retained locally pending processing. **Branches/limits:** Offline mode is not offline transcription. Refusing prompt cancels start; inability to save locally blocks or stops offline capture. Complete retry/backoff behavior was not captured. [Offline recording (WF-S40)](https://docs.wisprflow.ai/articles/5810080970-offline-meeting-recording-in-notetaker)

### WF-F41 — Cancel renewal or retrieve invoices

**DOCUMENTED · Desktop/web, iPhone store settings.** Preconditions: Know purchasing provider and authorized billing role. Path: Open personal Stripe, team admin billing, or Apple subscription management; cancel renewal or download invoice/receipt there. **Outcome:** Provider manages renewal/payment records. **Branches/limits:** Store purchases cannot be managed in desktop Stripe. Mobile app has no invoice viewer; deleting account/signing out does not cancel store subscriptions. Verify provider confirmation. [Billing management (WF-S41)](https://docs.wisprflow.ai/articles/4152811715)

## UI surface and component inventory

Documented surfaces; availability varies. [Navigation](https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android)

| Surface | Documented components |
| --- | --- |
| Desktop entry | Menu-bar menu, browser sign-in return, sequential permission cards, microphone meter, shortcut recorder, practice editor. |
| Desktop dictation | Movable Flow Bar, recording/processing state, stop/cancel controls, microphone picker, notification recovery actions. |
| Hub | Home/history, Meetings, Insights, Dictionary, Snippets, Style, Transforms, Notes, Tasks, Extensions; Settings and Help. |
| Libraries | Personal/shared tabs, search, rows, edit sheets, duplicate validation, import preview and bulk actions. |
| iPhone | Home and feature tabs, side menu, custom keyboard, globe, mic/Start/checkmark, error actions, style sheet, Live Activity. |
| Meeting workspace | Upcoming list, floating notepad, Transcript/Summary/My thoughts/Docs tabs, speaker chips, Ask chat, sharing dialog/folders. |
| Administration | Organization policies, billing portal, per-connector switches and account-dependent locks. |

## Data concepts and boundaries

**INFERRED model:** identity, device preferences, membership, subscription/allowance, dictation session, original/formatted transcript, audio, context, vocabulary, correction, snippet, style, transform, note/version/image, meeting/speaker/summary/chat, share grant, connector and retention/export job. Schemas were not inspected.

Do not collapse training consent, cloud processing, cloud retention, local history, or cross-device visibility into one privacy switch. Wispr explicitly describes cloud transcription and separate data controls. Its security overview distinguishes service encryption from end-to-end encryption. [Data controls](https://docs.wisprflow.ai/articles/9609615338-private-cloud-sync-and-data-sharing-preferences-in-wispr-flow), [security overview](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq)

## Coverage gaps and conflicting evidence

- **UNKNOWN release coherence:** pages mix layouts, plan names and gated features; one build containing every capability was not established.
- **UNKNOWN input permission boundary:** installation says Input Monitoring is for standalone Caps Lock; hands-free instructions request it generally. [Install](https://docs.wisprflow.ai/articles/7682075140-how-to-install-wispr-flow-on-mac), [hands-free](https://docs.wisprflow.ai/articles/6391241694-use-flow-hands-free)
- **UNKNOWN language behavior:** onboarding permits mixing languages in one sentence; the language guide says detection is per dictation. The homepage mentions a Flow Bar language picker while the guide explicitly says none exists. [Setup](https://docs.wisprflow.ai/articles/3152211871), [languages](https://docs.wisprflow.ai/articles/3191899797-use-flow-with-multiple-languages)
- **UNKNOWN iPhone handoff guarantee:** keyboard/iOS-26.4 pages promise the original location; hands-free says the app is restored and location depends on iOS. Session timeout values, background battery cost, offline-backup eligibility, and edit-last-dictation controls need focused evidence. [Keyboard](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone), [hands-free](https://docs.wisprflow.ai/articles/6391241694-use-flow-hands-free)
- **UNKNOWN sync presentation:** cloud storage promises cross-device access; navigation/sync describe device-specific history. [Sync](https://docs.wisprflow.ai/articles/5284722493-sync-flow-across-your-devices), [storage](https://docs.wisprflow.ai/articles/9609615338-private-cloud-sync-and-data-sharing-preferences-in-wispr-flow)
- **Unmapped depth:** Tasks, Extensions, Insights/voice profiles, IDE tagging, enterprise provisioning, calendar notice delivery, shared-folder membership edge cases, and all Notetaker question/summary variants require additional focused passes. Native architecture, models, accuracy, latency and battery use remain unverified. Public help-center coverage is not exhaustive.
