---
status: draft
doc_type: research
summary: "Granola flow inventory GR-F01–GR-F56 from official help, integration guides and lifecycle documentation."
created: 2026-10-12
updated: 2026-10-12
---

# Granola: documented product and flow inventory

This is requirements reconnaissance for a native Apple voice/meeting product. It captures Granola's public behavior without selecting features, designing a replacement, or asserting implementation. Research date: **2026-10-12**. The 61 source records and 56 machine-readable flows accompany this document in [source registry](../data/sources.jsonl) and [flow catalogue](../data/flows.json).

**Evidence:** DOCUMENTED means first-party procedural documentation or concrete release behavior; MARKETING means a first-party product claim; INFERRED means analysis rather than stated behavior; UNKNOWN means public evidence did not settle the question. No app was installed or exercised, no account was accessed, and no screen, performance, accuracy, privacy implementation or payment was validated hands-on. Flow gaps are questions or limitations, not proposed requirements.

Granola combines deliberate device-audio capture, optional manual notes, transcription and AI enhancement. Its desktop clients support macOS and Windows; its mobile clients include iPhone and Android. The Apple listing names iOS/iPadOS 18+, visionOS 2+ and watchOS 11+ compatibility, while the Mac setup guide requires macOS 14+. Compatibility does not establish equal feature coverage. The browser views existing notes and cannot capture meetings. [Setup](https://docs.granola.ai/help-center/getting-started/setting-up-granola-for-the-first-time), [Apple listing](https://apps.apple.com/us/app/granola-ai-meeting-notes/id6739429409), [transcription](https://docs.granola.ai/help-center/taking-notes/transcription).

## Surfaces and components

These are documented surfaces, not a pixel-level screen reconstruction.

| Surface | Components to account for | Evidence |
| --- | --- | --- |
| Entry and settings | Provider sign-in, calendar consent, audio permissions, demo; Profile, Preferences, Calendar, Connectors, Billing, Workspace | [GR-S01](https://docs.granola.ai/help-center/getting-started/setting-up-granola-for-the-first-time) |
| Home and navigation | Coming up, note list, New Note, workspace switcher, spaces/folders, Shared with me, People/Companies | [GR-S19](https://docs.granola.ai/help-center/people-and-companies), [GR-S60](https://www.granola.ai/updates/shared-with-me) |
| Meeting note | Raw/enhanced editor, template picker, attendee/event context, transcript panel, waveform/timer, sharing, floating indicator | [GR-S04](https://docs.granola.ai/help-center/taking-notes/transcription), [GR-S06](https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes) |
| Context and actions | Chat composer, scope, model/attachment controls, recipes, citation links; brief panel; email/event/message draft review | [GR-S13](https://docs.granola.ai/help-center/getting-more-from-your-notes/chatting-with-your-meetings), [GR-S14](https://docs.granola.ai/help-center/getting-more-from-your-notes/workflows-in-chat) |
| Mobile and Watch | Note cards, phone dialer, profile, Live Activity/Dynamic Island; watch complication, timer and transfer states | [GR-S20](https://docs.granola.ai/help-center/ios/getting-started), [GR-S23](https://docs.granola.ai/help-center/ios/apple-watch) |

## Flow catalogue

Each entry states its trigger/preconditions in the path or platform column, then its successful outcome and meaningful branch/limit. All entries are DOCUMENTED except GR-F19, which remains MARKETING. Source IDs resolve to the dated JSONL ledger.

### Entry, capture and note quality

**GR-F01 — Install and authorize** (macOS / Windows). First use: install, open, sign in, grant microphone/system-audio permissions on Mac, then run the demonstration meeting. **Result:** Home contains the tutorial note. **Branch/limit:** Mac requires 14+; denial recovery needs device testing. [GR-S01](https://docs.granola.ai/help-center/getting-started/setting-up-granola-for-the-first-time)

**GR-F02 — Sign in or switch identity** (Desktop). Choose Google, Microsoft or Enterprise SSO; complete browser authentication and calendar consent; return to Granola. Sign out in Settings to change accounts. **Result:** Account and calendar are linked. **Branch/limit:** Cloud Microsoft 365 only; organizational approval may block entry. [GR-S02](https://docs.granola.ai/help-center/signing-in-and-connecting-your-calendar)

**GR-F03 — Select calendars** (Desktop; settings sync to iOS). With a connected provider, open Calendar settings and enable additional calendars; share external calendars into that provider with event-detail access. **Result:** Coming up reflects eligible events. **Branch/limit:** No Apple Calendar; declined/focus/out-of-office entries are excluded. [GR-S03](https://docs.granola.ai/help-center/getting-started/syncing-your-calendars)

**GR-F04 — Respond to meeting prompts** (Desktop). For a calendar meeting or detected call, open Granola's prompt to launch the call/note; adjust all-app or per-app notifications in Settings. **Result:** Capture begins from a deliberate prompt interaction. **Branch/limit:** Calendar prompts require multiple attendees; popups are Granola windows. [GR-S12](https://docs.granola.ai/help-center/taking-notes/notifications)

**GR-F05 — Prepare with briefs** (Mac / Windows / iOS; paid). Open an upcoming external meeting's note and expand its brief; optionally connect Gmail for prior email context. **Result:** Preparation combines meeting history, calendar and external sources. **Branch/limit:** Google Calendar required; sparse context or internal meetings yield no brief. [GR-S07](https://docs.granola.ai/help-center/taking-notes/pre-meeting-briefs)

**GR-F06 — Start scheduled or ad-hoc capture** (Desktop). Open a started calendar meeting or New Note; an upcoming opened note begins capture at its scheduled start. **Result:** Microphone and system audio feed the note. **Branch/limit:** Merely running Granola does not capture; web cannot transcribe. [GR-S04](https://docs.granola.ai/help-center/taking-notes/transcription)

**GR-F07 — Inspect and control live capture** (Desktop). Open waveform panel to inspect channels, search/copy/delete transcript chunks, or Stop/Resume. The floating indicator returns to the note. **Result:** Capture state and textual evidence remain inspectable. **Branch/limit:** Sleep, silence or call-end detection can stop capture. [GR-S04](https://docs.granola.ai/help-center/taking-notes/transcription)

**GR-F08 — Steer the summary with raw notes** (Desktop). During a meeting, type optional headings, bullets, checkboxes and emphasis; paste or drop JPEG/PNG images. **Result:** Manual context guides enhancement. **Branch/limit:** Blank raw notes are allowed; image accessibility untested. [GR-S05](https://docs.granola.ai/help-center/taking-notes/taking-notes-in-granola)

**GR-F09 — Name speakers** (Mac / Windows). Configure supported Meet/Zoom/Teams speaker tags using the documented extension or accessibility route, then transcribe and inspect names. **Result:** Transcript segments gain participant display names. **Branch/limit:** No historical relabeling; shared-room devices and overlapping speech remain ambiguous. [GR-S11](https://docs.granola.ai/help-center/taking-notes/speaker-attribution)

**GR-F10 — Capture presentation snapshots** (Mac 14+). Enable shared-screen snapshots, authorize Accessibility and Screen Recording, then inspect/remove images from the Images stack. **Result:** Presented content joins note context. **Branch/limit:** Supported apps only; hidden windows pause capture; own shares excluded. [GR-S10](https://docs.granola.ai/help-center/taking-notes/capture-shared-screens)

**GR-F11 — Finish and enhance** (Desktop). End transcription manually or let detected call completion trigger enhancement from transcript, raw notes and calendar context. **Result:** Structured notes appear automatically. **Branch/limit:** Latency and failure recovery require observation. [GR-S06](https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes)

**GR-F12 — Inspect summary evidence** (Desktop). After enhancement, use the magnifying-glass control beside a point to inspect its raw-note or transcript origin. **Result:** A claim can be checked against captured text. **Branch/limit:** No retained-audio playback established. [GR-S06](https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes)

**GR-F13 — Correct or regenerate** (Desktop). Edit enhanced notes, or revise raw notes and regenerate with a template or Chat. **Result:** The current meeting's output changes. **Branch/limit:** Edits do not train future note style; version rollback unknown. [GR-S06](https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes)

**GR-F14 — Create, apply and share templates** (Desktop). Select a template from the note/menu; author structure and instructions in Manage templates; optionally share with the organization. **Result:** Notes regenerate into the chosen format. **Branch/limit:** Company-domain sharing; focused guide and feature-request page conflict on preselection. [GR-S09](https://docs.granola.ai/help-center/taking-notes/customise-notes-with-templates), [GR-S53](https://docs.granola.ai/help-center/feature-requests)

**GR-F15 — Choose transcription/summary language** (Desktop; mobile differs). Set English or multilingual transcription and English/Auto summary language; regenerate existing summaries if needed. **Result:** Language behavior matches selected preferences. **Branch/limit:** Mobile selects one language; old transcripts cannot be re-transcribed by changing settings. [GR-S42](https://docs.granola.ai/help-center/customising-granola/multi-language)

**GR-F16 — Personalize profile and release channel** (Desktop; partial iOS). Add professional context in Profile; opt into or leave the beta channel through Preferences/Labs. **Result:** Summary guidance and update channel change. **Branch/limit:** Effect on note quality and rollout timing unmeasured. [GR-S43](https://docs.granola.ai/help-center/customising-granola/profile-and-preferences)

**GR-F17 — Teach vocabulary** (Desktop; workspace admin). Enter personal terms in Language, or add shared workspace jargon as admin. **Result:** Recognition receives personal and team vocabulary. **Branch/limit:** 30 personal/50 workspace terms; no deterministic word substitution. [GR-S44](https://docs.granola.ai/help-center/customising-granola/customising-transcription)

### Recall and follow-through

**GR-F18 — Chat about one or many meetings** (Desktop / iPhone). Ask from a note, home, folder or selected meetings; attach extra files on desktop; use explicit rewrite prompts to edit notes. **Result:** Answers or edits use the selected context. **Branch/limit:** Basic history is 30 days; no iPad/Android Chat; threads remain private. [GR-S13](https://docs.granola.ai/help-center/getting-more-from-your-notes/chatting-with-your-meetings)

**GR-F19 — Check Chat's citations** (Desktop; release claim). Ask across personal/shared/team notes, inspect inline citations and redirect the referenced note set when needed. **Result:** Answer provenance is exposed for review. **Branch/limit:** Citation completeness and factual accuracy not tested. [GR-S58](https://www.granola.ai/blog/granola-chat-just-got-smarter)

**GR-F20 — Dictate a Chat question** (Desktop). Click the Chat microphone, speak a short question, then checkmark to submit or X to cancel. **Result:** Speech becomes a Chat request. **Branch/limit:** This does not start meeting capture or type into other apps. [GR-S45](https://docs.granola.ai/help-center/getting-more-from-your-notes/granola-chat-dictation-vs-transcription)

**GR-F21 — Save and reuse recipes** (Desktop). Create a named prompt, choose single- or multiple-meeting context, save, then invoke via slash menu; share or remix others' recipes. **Result:** Repeatable prompts run on selected meeting context. **Branch/limit:** Static prompts lack variables; one context type per recipe. [GR-S15](https://docs.granola.ai/help-center/getting-more-from-your-notes/recipes)

**GR-F22 — Review suggested follow-up email** (Google paid/trial; desktop flow). Connect same-account Gmail with read/send permissions; open a suggested external-meeting draft, edit and send; use brief Undo if necessary. **Result:** A reviewed follow-up is sent. **Branch/limit:** At most 10 attendees; device-local edits and unsaved attachments; Outlook unsupported. [GR-S08](https://docs.granola.ai/help-center/taking-notes/follow-up-emails)

**GR-F23 — Act through connected Chat** (Desktop). Connect Gmail, Slack or Google Calendar; request an action, review/edit its destination and content, then Send/Create event or dismiss. **Result:** Email, Slack message or calendar event is created. **Branch/limit:** Google-only email/calendar; calendar domain limits; interrupted drafts require retry. [GR-S14](https://docs.granola.ai/help-center/getting-more-from-your-notes/workflows-in-chat)

### Organization and collaboration

**GR-F24 — Find people, companies and old notes** (Desktop). Search the automatic People/Companies directory, open a record and inspect/chat with associated notes; use note search for history. **Result:** Related conversations become navigable. **Branch/limit:** Calendar attendance seeds directories; no manual additions; offline search is release-documented. [GR-S19](https://docs.granola.ai/help-center/people-and-companies), [GR-S57](https://www.granola.ai/updates)

**GR-F25 — Organize folders and recurring meetings** (Desktop). Create a folder in a space; add selected notes; nest owned folders one level; accept recurring-series auto-add when offered. **Result:** Notes form reusable collections. **Branch/limit:** Multiple-folder membership; removing recurring membership cancels its rule. [GR-S16](https://docs.granola.ai/help-center/sharing/folders/spaces-and-folders)

**GR-F26 — Share a collection** (Desktop / recipient web). In folder settings choose space, members and link access; invite recipients to use the collection. **Result:** Authorized people access the collection. **Branch/limit:** Web omits full transcripts; folder roles and note-edit roles differ. [GR-S16](https://docs.granola.ai/help-center/sharing/folders/spaces-and-folders)

**GR-F27 — Share or request a single note** (Desktop / web). After enhancement, invite/copy link, assign Viewer or Collaborator; a blocked recipient can Request access for owner approval. **Result:** Recipient can read, chat or edit as permitted. **Branch/limit:** Sharing creates no workspace seat; exact transcript-role boundaries need verification. [GR-S17](https://docs.granola.ai/help-center/sharing/sharing-notes)

**GR-F28 — Set sharing defaults and ceilings** (Desktop; Enterprise admin). Set future-note default visibility, adjust an individual note, or enforce workspace sharing restrictions and approved domains. **Result:** Link exposure follows the applicable policy. **Branch/limit:** User defaults are prospective; enterprise restrictions apply retroactively; iPhone links can still be unusable. [GR-S18](https://docs.granola.ai/help-center/consent-security-privacy/sharing-controls)

**GR-F29 — Discover shared notes and notify teammates** (Desktop; release-documented). Open Shared with me to find received notes; type an @mention in a note and optionally email its link. **Result:** Shared context reaches relevant teammates. **Branch/limit:** Mention-notification permission semantics and current UI require verification. [GR-S59](https://www.granola.ai/updates/whats-new-2025-12-19), [GR-S60](https://www.granola.ai/updates/shared-with-me)

**GR-F30 — Manage workspace membership** (Desktop; mobile switching disputed). Create/join/switch workspaces; invite members, assign roles, remove members, or leave after moving needed notes. **Result:** Personal and team contexts remain separate. **Branch/limit:** Removal revokes access; paid joins add seats; last-admin and deletion prerequisites apply. [GR-S32](https://docs.granola.ai/help-center/workspaces)

**GR-F31 — Provision organizational identity** (Desktop + identity provider; Enterprise). Configure SSO, test sign-in and optionally enforce it; connect SCIM and assign users/groups in the identity provider. **Result:** Identity provisioning governs workspace membership. **Branch/limit:** Company domain and 50-seat minimum; directory-owned users cannot be removed manually. [GR-S52](https://docs.granola.ai/help-center/sso-setup-guide)

**GR-F32 — Grant access through groups** (Enterprise admin). Create a manual group or sync one through SCIM, then grant it Space/folder Viewer or Collaborator access. **Result:** Membership changes update permissions. **Branch/limit:** Synced groups are edited at the identity provider. [GR-S51](https://docs.granola.ai/help-center/sharing/user-groups)

### Connected systems

**GR-F33 — Send a note to Notion** (Paid desktop). Connect Notion using its developer-provided database template; after enhancement, send a note from its menu. **Result:** A page appears in the dedicated database. **Branch/limit:** No native bulk/automatic sync or arbitrary destination; reauthorization handles permission errors. [GR-S35](https://docs.granola.ai/help-center/sharing/notion), [GR-S61](https://www.granola.ai/pricing)

**GR-F34 — Post notes to Slack** (Desktop; business identity). Connect matching Slack identity; choose a channel for one note or configure future folder additions to auto-post. **Result:** Slack receives link and summary. **Branch/limit:** Private channels need app access; later Granola restriction does not retract posted text. [GR-S36](https://docs.granola.ai/help-center/sharing/integrations/slack)

**GR-F35 — Automate through Zapier** (Paid desktop). Choose manual-share or future-folder-add trigger, select workspace, test sample notes and configure downstream actions. **Result:** Meeting data drives the Zap. **Branch/limit:** Payload includes raw notes and full transcript; no retroactive folder trigger. [GR-S37](https://docs.granola.ai/help-center/sharing/integrations/zapier)

**GR-F36 — Sync HubSpot records** (Paid desktop; business identity). Authorize HubSpot, choose Meeting/Note entity type, then select contact/company/deal or configure folder matching. **Result:** Summary attaches to selected/matching CRM records. **Branch/limit:** No matching attendee email means no auto-created data; inspect last-sync error. [GR-S48](https://docs.granola.ai/help-center/sharing/integrations/hub-spot), [GR-S61](https://www.granola.ai/pricing)

**GR-F37 — Sync Attio records** (Paid desktop). Connect Attio; review suggested people/company records for one note, or configure matching future folder additions. **Result:** CRM receives a note on matching records. **Branch/limit:** Existing folder contents do not backfill; unmatched emails produce no record. [GR-S49](https://docs.granola.ai/help-center/sharing/integrations/attio), [GR-S61](https://www.granola.ai/pricing)

**GR-F38 — Send to Affinity** (Paid desktop). Generate a personal Affinity key, connect it in Granola, review suggested/search additional records and save. **Result:** New notes attach to chosen CRM records. **Branch/limit:** Per-user key; existing CRM notes are not edited or deleted. [GR-S50](https://docs.granola.ai/help-center/sharing/integrations/affinity), [GR-S61](https://www.granola.ai/pricing)

**GR-F39 — Connect an external AI through MCP** (MCP client + Granola account). Authorize via browser OAuth or enterprise-managed authorization, select active workspace and query authorized notes. **Result:** External assistants retrieve meeting context. **Branch/limit:** Basic recent personal scope; paid shared/public access; enterprise transcript controls apply. [GR-S24](https://docs.granola.ai/help-center/sharing/integrations/mcp)

**GR-F40 — Create a scoped API key** (Business / Enterprise desktop). Open Connectors/API keys, choose personal/public note scopes, generate and copy a key for an integration. **Result:** Programmatic access follows selected scopes. **Branch/limit:** Admin policy may disable scopes; no API exercise performed. [GR-S25](https://docs.granola.ai/help-center/sharing/integrations/granola-api)

### Mobile and portable history

**GR-F41 — Capture an in-person mobile meeting** (iPhone / Android). Start a meeting/New Note, inspect timer/bars, pause/resume and End; after processing open/share its transcript. **Result:** Mobile microphone conversation becomes enhanced notes. **Branch/limit:** No other-app call audio; Bluetooth may select the wrong microphone. [GR-S20](https://docs.granola.ai/help-center/ios/getting-started), [GR-S21](https://docs.granola.ai/help-center/ios/transcription)

**GR-F42 — Capture an outbound phone call** (iOS only). Open dialer, verify your number by call/code, optionally grant contacts, dial a contact/number and end normally. **Result:** Call summary arrives after processing. **Branch/limit:** No inbound capture; one account per number; regional and carrier restrictions. [GR-S22](https://docs.granola.ai/help-center/ios/phone-calls)

**GR-F43 — Record from Apple Watch** (watchOS 11+ with iPhone). Install companion/complication, start a meeting or new recording and End; monitor saved/sync/upload/generation states. **Result:** Watch audio becomes phone/desktop notes. **Branch/limit:** Offline recording works; mandatory chime; retry partial sync, but interrupted capture cannot resume. [GR-S23](https://docs.granola.ai/help-center/ios/apple-watch)

**GR-F44 — Continue mobile notes on desktop** (Mobile + desktop account). Finish mobile transcription and summary; open the completed note on desktop for templates, integrations and editing. **Result:** Notes, transcripts and later edits synchronize. **Branch/limit:** In-progress/pre-meeting mobile notes do not sync; wait for processing. [GR-S55](https://docs.granola.ai/help-center/ios/syncing-with-desktop)

**GR-F45 — Export owned history** (Desktop; policy permitting). In Profile choose Generate CSV and workspaces; open emailed download while signed into the requesting account. **Result:** CSV contains owned summarized notes and transcripts, including older Basic history. **Branch/limit:** 24-hour link/request limits; excludes deleted or unsummarized notes; no admin-wide export. [GR-S26](https://docs.granola.ai/help-center/sharing/exporting-notes)

**GR-F46 — Delete and restore notes** (Desktop / Android; iPhone deletion). Move a note to trash; restore from trash or permanently delete. **Result:** Accidental deletion remains recoverable before expiry. **Branch/limit:** Trash expires after 30 days; iPhone restoration requires another supported app. [GR-S27](https://docs.granola.ai/help-center/taking-notes/deleting-notes)

**GR-F47 — Set transcript retention** (Individual desktop / Enterprise policy). Select a retention period and confirm; individuals receive a week cooldown, enterprise activation can delete old transcripts immediately. **Result:** Transcripts expire while notes remain. **Branch/limit:** Irreversible; regeneration stops and Chat loses transcript detail. [GR-S29](https://docs.granola.ai/help-center/consent-security-privacy/transcript-auto-deletion)

### Account lifecycle and recovery

**GR-F48 — Opt out of model improvement** (Desktop / iOS; Enterprise admin). Disable the model-improvement setting; Enterprise enforces organization-level policy. **Result:** Future training use follows the opt-out. **Branch/limit:** Vendor says providers cannot train; prior anonymized use remains unverified; no BYO models. [GR-S28](https://docs.granola.ai/help-center/consent-security-privacy/model-training), [GR-S41](https://docs.granola.ai/help-center/consent-security-privacy/security-privacy-data-faqs)

**GR-F49 — Move between workspaces** (Desktop). Choose a member destination, inspect bulk-transfer preview and confirm; use per-note Move for a subset. **Result:** Notes change workspace with eligible private folders. **Branch/limit:** Admin controls may hide transfer; shared folders, templates and billing differ. [GR-S46](https://docs.granola.ai/help-center/transfer-notes-between-workspaces)

**GR-F50 — Move from another Granola account** (Desktop). From destination Profile start import, enter source email and verify its code. **Result:** Notes/transcripts move rather than copy. **Branch/limit:** Old-email access and source-policy permission required; no third-party import; billing stays behind. [GR-S47](https://docs.granola.ai/help-center/transfer-notes-between-accounts)

**GR-F51 — Upgrade and manage billing** (Workspace billing surface / Stripe). Select Business/Enterprise upgrade, complete checkout or share checkout link; manage invoices/payment details in the portal. **Result:** Workspace entitlement and active-seat billing update. **Branch/limit:** Basic is free, Business $14, Enterprise from $35 per user/month; no mixed tier within workspace. [GR-S30](https://docs.granola.ai/help-center/managing-your-account/subscriptions-and-billing), [GR-S61](https://www.granola.ai/pricing)

**GR-F52 — Cancel a subscription** (Workspace billing admin / Stripe). Open billing management and cancel; retain paid access through the current billing period. **Result:** Workspace returns to Basic. **Branch/limit:** Older notes remain stored but become inaccessible in-app; charges belong to each workspace. [GR-S31](https://docs.granola.ai/help-center/understanding-granolas-subscription-cancellation-terms), [GR-S30](https://docs.granola.ai/help-center/managing-your-account/subscriptions-and-billing)

**GR-F53 — Delete account or workspace** (Desktop / account web fallback). Export/transfer wanted content; use account deletion or satisfy workspace deletion prerequisites and confirm. **Result:** Owned content is permanently removed. **Branch/limit:** Shared folder containers may survive account deletion; transferred ownership survives; legal-hold interaction unverified. [GR-S33](https://docs.granola.ai/help-center/deleting-your-account), [GR-S32](https://docs.granola.ai/help-center/workspaces)

**GR-F54 — Repair missing audio** (Desktop). Inspect microphone/system channels, Stop/Resume, select the correct mic, verify OS permissions and run network check. **Result:** Capture fault narrows to routing, permissions or connectivity. **Branch/limit:** Live transcription requires network; VDI and Bluetooth introduce documented limits. [GR-S38](https://docs.granola.ai/help-center/troubleshooting/transcription-issues)

**GR-F55 — Recover failed or missing notes** (Desktop / mobile support). Retry/regenerate when a transcript exists; otherwise check account, workspace, membership and whether capture started. **Result:** Existing data is found or generation retried. **Branch/limit:** Uncaptured audio is unrecoverable; exact interruption/offline recovery remains untested. [GR-S39](https://docs.granola.ai/help-center/troubleshooting/notes-not-generating), [GR-S54](https://docs.granola.ai/help-center/troubleshooting/missing-notes)

**GR-F56 — Disclose active transcription** (Desktop; Free / Business or Enterprise policy). In Transparency preferences enable automated meeting-chat notice, or install/select Granola Watermark camera in the meeting app. **Result:** Participants receive a visible transcription signal. **Branch/limit:** Meet uses an extension; Slack huddles require Mac Accessibility; notice delivery and consent are not verified. [GR-S40](https://docs.granola.ai/help-center/consent-security-privacy/transparency-solutions/for-individuals)

## Data concepts and privacy boundaries

**INFERRED domain map:** identity belongs to one or more workspaces; workspaces contain spaces, folders and owned notes. A note relates to a calendar event/attendees, raw writing, transcript segments, images and enhanced output. Templates structure enhancement; recipes structure Chat prompts. Chat threads, connector credentials, sharing grants, recurring filing rules, exports, retention policy and billing seats are separate concepts. This is an analytical vocabulary, not Granola's database schema. [Workspaces](https://docs.granola.ai/help-center/workspaces), [folders](https://docs.granola.ai/help-center/sharing/folders/spaces-and-folders), [recipes](https://docs.granola.ai/help-center/getting-more-from-your-notes/recipes).

Granola states that cloud data is stored in the US, completed notes are cached locally for offline editing, and temporary audio is deleted after transcription. These are vendor statements, not an independent audit. Local capture therefore does not establish local-only processing. Transcript retention, Basic's visibility limit and deletion are distinct mechanisms. [Privacy FAQ](https://docs.granola.ai/help-center/consent-security-privacy/security-privacy-data-faqs).

## Coverage gaps and contradictory evidence

- **Documentation drift:** the mobile guide allows workspace switching, while the workspace guide says iOS workspaces are unsupported. The focused template guide permits selection during a call; the feature-request page says it is unavailable. Preserve both until product observation resolves them. [Mobile](https://docs.granola.ai/help-center/ios/getting-started), [workspaces](https://docs.granola.ai/help-center/workspaces), [templates](https://docs.granola.ai/help-center/taking-notes/customise-notes-with-templates), [requests](https://docs.granola.ai/help-center/feature-requests).
- **Scope drift:** current MCP documentation includes authorized shared notes; older help pages described owner-only access. Current Chat workflows use connected Gmail although the generic Chat page still says email is outside its data boundary. Historical transcript-toggle and recent-40-note limits should not be imported into the new Chat model. [MCP](https://docs.granola.ai/help-center/sharing/integrations/mcp), [Chat](https://docs.granola.ai/help-center/getting-more-from-your-notes/chatting-with-your-meetings), [actions](https://docs.granola.ai/help-center/getting-more-from-your-notes/workflows-in-chat).
- **UNKNOWN:** edit history/rollback, simultaneous-editor conflicts, capture crash recovery, granular offline retries, speaker-correction UI, accessibility behavior, all keyboard shortcuts, exact web/mobile permission parity, integration delivery guarantees and legal-hold effects on deletion. Transcript text editing is explicitly unavailable, despite supported chunk deletion. [Feature requests](https://docs.granola.ai/help-center/feature-requests).
- **Boundary of this inventory:** public end-user and core admin flows are mapped. Exact SSO-provider screens, every regional telephony exception, enterprise procurement, API endpoint/webhook/audit/legal-hold operations, referral/affiliate programs and dormant experiments need separate inventories if included in scope. No claim of exhaustive account-gated coverage is made.
