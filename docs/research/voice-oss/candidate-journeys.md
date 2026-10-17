---
status: draft
doc_type: research
summary: "Proposed end-to-end journeys P-F01–P-F62 across clients, models, hosting, CLI, MCP, hooks and workflows; all unapproved."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Candidate interaction sequences for explicit requirements and exploration; implementation remains unselected."
---

# Candidate journeys for the new product

These journeys translate the [user requirements](requirements.md) into questions we can explore. Every `P-F` sequence is **PROPOSED**. Capabilities explicitly required in U entries stay required while their exact interactions are explored. Competitor flows have their own product-prefixed IDs in [flows.csv](data/flows.csv); a documented competitor behavior does not automatically become a requirement here.

No platform is presumed to support a flow until its platform constraints are resolved. In particular, an iOS keyboard, a Mac text-insertion utility, a Watch recorder, and a headless server have different capabilities. Consult the [Apple study](apple-platforms-and-ux.md) and [hosting study](self-hosting-and-models.md).

## First successful use and daily dictation

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F01 | Install → choose local device, existing server, or remote provider → grant task-specific permissions → make a short recording. | One comprehensible first result, with its processing destination visible. | Must account creation exist? Model download needed? Can permissions be deferred? What works on unsupported hardware? |
| P-F02 | Inspect model size and requirements → download → verify → load → try → replace or remove. | User understands readiness, disk use, and expected tradeoffs. | Interrupted download, low space, incompatible model, corrupt artifact, unavailable acceleration, first-load delay. |
| P-F03 | Place cursor in another Mac app → invoke capture shortcut → speak → finish → insert. | Intended text appears in the intended destination. | Focus changes, protected fields, inaccessible app, clipboard preservation, permission revoked, destination closed, unintended duplicate insertion. |
| P-F04 | Start a longer hands-free dictation → pause/resume if supported → stop/cancel. | A long thought can be captured without holding a key. | Shortcut collision, accidental toggle, silence, background noise, audio-device change, forgotten recording. |
| P-F05 | Dictate a self-correction or mixed-language phrase → inspect final text → correct it. | The result preserves the user's meaning and chosen language. | Code-switching, jargon, names, punctuation, numbers, code, literal quotations, output language versus spoken language. |
| P-F06 | Choose a style or context rule → dictate in an app/website → inspect adapted output. | Formatting fits the destination without surprising changes of meaning. | Rule precedence, wrong app/URL match, private browsing, missing context, context permissions, literal mode override. |
| P-F07 | Add a name/term or replacement → test it → update/remove it. | A personal vocabulary behaves predictably. | Case sensitivity, language-specific forms, ambiguous sounds, conflicting rules, device sync, accidental overcorrection. |
| P-F08 | Select existing text → speak an editing instruction → preview or apply → undo. | Voice changes an existing passage without losing the original. | Selection disappears, instruction mistaken for dictated content, partial insertion, stale selection, unsupported destination. |
| P-F09 | Inspect retained source audio and history → retry with another model as a new revision → compare → copy/reinsert/export. | Recovery avoids making the user repeat the original speech. | Corrupt/incomplete source, hidden cloud fallback, lost destination, retry charges, duplicate history; preserve originals and edits (U29–U30). |
| P-F10 | Create a reusable spoken expansion or prompt → invoke it → inspect/edit result. | Repeated text or transformations require less effort. | Accidental trigger, variable interpolation, secrets inside expansions, nested prompts, destructive output commands. |

## Meetings, personal notes, and recall

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F11 | Connect a calendar optionally → review an upcoming event → prepare a note or brief → begin capture. | Pre-meeting context stays connected to the meeting. | Calendar unavailable, multiple accounts, duplicate/recurring events, declined/canceled event, recording without a calendar. |
| P-F12 | Start an ad-hoc meeting or in-person note → select available inputs → capture → jot personal notes. | Speech and the user's own notes contribute complementary context. | Capturing only one side, echo, mute, headphones, system-audio permission, microphone switching, interruptions. |
| P-F13 | Notice capture status → pause private discussion → resume → finish. | People retain practical control over recording boundaries. | How are pauses represented? Does capture survive sleep, lock, calls, or app termination? What notice/consent workflow is appropriate? |
| P-F14 | Finish a meeting → retain raw inputs → transcribe → produce structured notes → review. | Human notes, transcript, and generated summary remain distinguishable. | Processing still running, empty or partial audio, speaker uncertainty, hallucinated action, insufficient context, canceled job. |
| P-F15 | Choose/create a summary template → regenerate selected output → compare or restore. | Different meeting purposes can produce useful structures. | Preserve original and prior versions/manual edits; investigate comparison, reprocessing cost, template changes, and unsupported provider features. |
| P-F16 | Read a claim/action in a note → reveal supporting passage and time → inspect context. | A user can establish why the product produced an assertion. | Missing source, ambiguous speaker, cross-meeting evidence, incorrect time, audio absent from an imported source or a deliberately uncaptured interval. |
| P-F17 | Capture a personal thought → title/tag/organize → turn it into a draft or structured note. | Short and long voice notes become useful retained material. | Dictation versus note defaults, rambling speech, sensitive recording, interrupted capture, title/model failure. |
| P-F18 | Import an existing recording or text → choose processing → inspect result and provenance. | Users can work with material created elsewhere. | Supported formats, huge files, duplicates, multi-channel audio, no speech, unsupported codecs, copyrighted or confidential inputs. |
| P-F19 | Search by words/metadata → open a result → narrow the collection → revisit context. | Recall works even when the user does not remember a note's title. | Offline search, reindexing, stale embedding model, deleted/shared notes, result permissions, search versus semantic inference. |
| P-F20 | Ask a question of one note, selected notes, or a collection → inspect cited answer → refine/save. | Answers preserve scope and uncertainty. | Unsupported claims, incomplete retrieval, conflicting notes, revoked access, model outages, prompt-like text inside transcripts. |
| P-F21 | Extract a follow-up or task → edit recipient/destination/content → confirm external action → inspect receipt. | Captured thought can become an intentional action. | Does the product own tasks or export them? Duplicate sends, no permission, stale recipient, partial failure, revocation, undo limits. |
| P-F22 | Organize notes into collections → optionally share selected material → change access → revoke. | Ownership and access are understandable. | Are sharing/collaboration in scope? Transcript versus summary permissions, public links, downloaded copies, copied sources, shared search. |
| P-F23 | Edit/archive/export a note → inspect retained history and linked audio → restore if needed. | Lifecycle controls cover the complete retained object. | Recoverable archive/trash versus deliberate permanent purge; no silent history eviction; index cleanup, sync tombstones, backup retention, external copies, partial export. |

## iPhone, Watch, and movement between devices

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F24 | Install the iPhone app → use its own capture UI → obtain text/note → copy/share. | Useful iPhone operation exists independently of keyboard integration. | Permissions denied, app backgrounded, phone call, screen lock, keyboard not installed, server unavailable. |
| P-F25 | Enable the custom keyboard → use the qualified capture mechanism → return to typing → insert or retry retained text. | Required iOS keyboard support (U23); its capture/insertion mechanism still needs qualification. | Microphone restrictions, app switching, open access, secure fields, session timeout, App Review constraints. Do not assume Mac parity. |
| P-F26 | Launch capture through a Shortcut, widget, Action button, or system intent → see status → finish. | Capture is reachable from native entry points. | Device/OS support, lock state, confirmation, privacy, accidental starts, background execution. Each entry point needs independent feasibility evidence. |
| P-F27 | Start a short Watch recording → receive haptic/visual status → stop → retain locally. | A person can capture without pulling out the phone. | Complication availability, launch delay, microphone permission, battery, gesture conflicts, connection loss, storage exhaustion. |
| P-F28 | Capture while Watch or phone is disconnected → reconnect → transfer → process → acknowledge receipt. | Pending work has a visible, recoverable owner at every stage. | Duplicate transfer, partial file, out-of-order delivery, deleted-on-one-device, both devices offline, relaunch before acknowledgment. |
| P-F29 | Capture on one device → continue reviewing or editing on another. | The destination has the appropriate result and context; optional iCloud is one required sync option (U31). | Audio still uploading, concurrent edits, metadata conflict, unavailable model, device identity, what “handoff” means for active recording. |
| P-F30 | Use an independent Watch or phone with a user-owned server, if feasible. | A companion Mac need not be implicitly required for every operation. | Authentication entry, network/background limits, power use, local capture queue, server reachability, smallest usable settings surface. |

## Models, hosting, ownership, and operations

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F31 | Choose separate providers for transcription, cleanup, summaries, and search → test each. | Users understand which data each stage receives. | Credential storage, API compatibility, model capability, sample disclosure, cost, rate limits, endpoint changed. |
| P-F32 | A selected processor becomes unavailable → preserve capture → explain choices → retry or switch with appropriate consent. | Failure does not silently change the data destination. | Queue ordering, duplicate billing, offline mode, optional fallback, privacy-policy difference, expired credentials. |
| P-F33 | Install a local/LAN deployment → initialize storage and identity → connect first client → produce first result. | A complete local service can be operated deliberately without enabling iCloud. | Port collision, TLS, discovery, model placement, first-run authentication, firewalls, accidental public exposure. |
| P-F34 | Deploy on exe.dev or a comparable host → configure persistence and access → pair clients → verify recovery. | The user can host the product on rented infrastructure. | CPU/GPU capabilities, storage limits, browser login versus native token auth, service restart, cost, backup location. |
| P-F35 | Install on Unraid → map persistent storage → configure optional GPU/model service → pair clients. | Application and data survive container replacement. | Volume ownership, shares, device mapping, reverse proxy, credentials, incompatible GPU runtime, unintended deletion. |
| P-F36 | Back up data/config → restore into a new environment → reconnect devices → verify completeness. | Restore recovers originals and revision history as well as readable results (U29–U30). | Encryption keys, model artifacts versus user data, server identity, attachments, references, incremental backup, incompatible schema. |
| P-F37 | Update app/server/models → inspect compatibility → complete migration or rollback. | Operator understands changed behavior and recovery. | Old client/new server, queued jobs across versions, schema rollback, interrupted migration, model output drift. |
| P-F38 | Add/revoke a device or integration → inspect scope → rotate credentials → verify access removal. | Trust can be changed without rebuilding the installation. | Lost device, stolen token, shared server, retained local copies, offline revocation, audit detail. |
| P-F39 | Diagnose a problem → inspect relevant health and job state → export a redacted support bundle. | Troubleshooting has useful evidence without dumping private content. | Logs containing audio/text/secrets, opaque model errors, disk/memory pressure, tenant leakage, reproducible failure. |

## CLI, MCP, and composable workflows

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F40 | Select a local/remote profile → authenticate → inspect capabilities → submit a file or input stream. | A script can obtain a stable result or job identifier. | Headless credential flow, stdin versus mic capture, JSON stdout versus progress stderr, timeouts, exit codes, retries. |
| P-F41 | List/search/read/export notes or transcripts from a terminal. | Useful personal data can enter ordinary shell workflows. | Pagination, permissions, timestamps, format stability, quoting, redaction, deleted records, full export completeness. |
| P-F42 | Submit a long job → observe progress → cancel/resume/retry → retrieve final output. | Long processing is inspectable without a permanently attached terminal. | Idempotency, disconnect, server restart, canceled work retention, retries charging twice, result expiry. |
| P-F43 | Connect an MCP client → grant a bounded scope → discover available operations → read/search with provenance. | Agents can reason over the user's selected data. | Local versus remote transport, native authentication, tool output size, access revocation, source content treated as instructions. |
| P-F44 | Ask an agent to create/change/process/export something → inspect proposed effects → approve where needed → observe receipt. | Agent actions remain distinguishable from read-only recall. | Write scopes, confirmation ownership, duplicate calls, long jobs, tool/version negotiation, external publication, auditability. |

## Required directions: notes, calls, hooks, history, and iCloud

These candidate sequences expand U24–U31. Keyboard support is covered by P-F25.
See [product behavior and durability](product-behavior.md) for supporting sources and candidate acceptance criteria.

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F45 | Capture into an inbox → turn material into a lasting note → connect it to a topic/person/project → revisit through links or search. | Second-brain organization (U24) with source provenance. | Taxonomy, links/backlinks, moved notes, broken links, attachments, import/export fidelity, duplicate concepts. |
| P-F46 | Open a knowledge workspace → choose a useful layout → review note and source/history → resume the layout later. | Deliberate notes layout (U24) across Mac and iPhone. | Sidebar/list/editor/inspector choices, keyboard navigation, multiple windows, accessibility, restoration, small-screen adaptation. |
| P-F47 | Choose a contact or ordinary phone number in the iOS app → review route and capture state → place call → end → review retained recording and transcript. | Transcribed outbound calls to ordinary phone numbers (U25), linked to a durable note. | Telephony provider/interconnect, caller identity, both audio directions, live versus post-call transcription, notice, cost, offline transcript queue. |
| P-F48 | During a call, mute/hold/change audio route or lose connectivity → inspect state → end/recover partial capture → retry processing. | Call failure preserves captured material (U25/U29/U30). | No answer, voicemail, DTMF, locked phone, Bluetooth, one-sided audio, recording failure while call continues; processing retry must never redial. |
| P-F49 | Declare a hook → inspect event, payload, execution host, and access → run a sample → enable → inspect a real result. | Hooks compose product work with other tools (U26–U27). | Payload/schema versions, secrets, script trust, data exposure, timeouts, hook changes, recursively triggered events. |
| P-F50 | A hook fails or a worker restarts → inspect receipt → retry/replay deliberately → verify downstream result. | Integration failure leaves saved work intact (U27/U29). | Duplicate delivery, external effects, event ordering, bounded retries, dead-letter visibility, hooks that never return. |
| P-F51 | Author XDG-based dotfiles → validate → inspect effective configuration → use from CLI/app → change through UI or file. | Inspectable, portable configuration (U28). | Namespace/format, precedence, environment overrides, relative-path rejection, invalid config, GUI writeback, secrets, Apple sandbox mapping. |
| P-F52 | Interrupt the app or device while capturing/saving → relaunch → inspect recovered segments and the last durable boundary. | Recover partial work and identify any capture gap (U29–U30). | Crash, power loss, damaged final segment, incomplete metadata, update/migration failure, false saved indicators. |
| P-F53 | Open local history → select original material → choose another model/template → reprocess → compare or restore a result. | Reprocessing preserves originals, prior results, and manual edits (U30). | Missing model version, source corruption, provider outage, concurrent edit, provenance, duplicate job, accidental overwrite. |
| P-F54 | Approach storage capacity → inspect warnings → preserve existing history → safely stop/refuse new capture if persistence fails. | Capacity handling does not silently evict history or pretend capture succeeded (U29–U30). | Mid-call exhaustion, full disk, model-cache pressure, partial writes, history encryption, backup capacity, deliberate purge policy. |
| P-F55 | Opt into iCloud → choose replication scope → reconcile existing local/remote libraries → inspect progress on another device. | Optional sync adds to local retention (U31/U30). | Account absent, quota full, duplicate imports, asset upload pending, history/audio scope, encryption, self-hosted coexistence. |
| P-F56 | Disable iCloud, sign out, or switch accounts → retain and isolate local history → deliberately resume or merge into the intended account. | Account changes preserve work and ownership (U31/U29). | Queued changes, unavailable keys, wrong-account upload, shared data ownership, re-enabling after long offline use. |
| P-F57 | Edit a note on two disconnected devices or receive a remote deletion → reconnect → inspect versions/conflict → choose a recoverable resolution. | Sync preserves competing work and history (U31/U29/U30). | Revision identity, tombstones, shared notes, archive versus purge, self-hosted/iCloud loops, no silent winner that destroys edits. |

## State and recovery observation checklist

This is a vocabulary for comparing flows, not a chosen state machine. Record which transitions each product actually exposes:

```text
not ready → permission/model/provider setup → ready
ready → capturing and persisting segments → paused → capturing → stopped
retained local segments → queued/transferring → processing → reviewable
reviewable → edited → inserted/shared/exported
any supported stage → failed/interrupted/canceled → retained and recoverable
retained work → hidden/archived → restored
permanent purge requested → explicit ownership/replica policy (undecided)
```

For each transition, capture the visible feedback, available action, keyboard and accessibility behavior, persistence boundary, network destination, and whether repeating the action duplicates work. Record unobserved transitions as unknown. Never infer successful persistence from a spinner disappearing.

## Workflow composition on Mac and iOS

U32–U33 require action chaining. These sequences and adapter choices remain proposed;
see the [workflow composition study](workflow-composition.md) for sourced platform options.

| ID | User goal and candidate sequence | Outcome to investigate | Recovery and unresolved questions |
| --- | --- | --- | --- |
| P-F58 | Select audio or a note in Tuna → choose a product action → receive its result as an item → choose a destination action. | Mac actions compose around usable inputs and outputs (U26/U32). | Script versus extension, supported item types, completed result versus launch acknowledgement, access to the original selection. |
| P-F59 | Invoke a Raycast recipe → choose local/remote profile → transcribe → summarize → append to a project note → return a link or export. | A reusable chain exposes its settings, progress and results (U26/U28/U32). | Script versus extension, arguments/output, cross-extension permissions, structured errors, host termination, asynchronous completion. |
| P-F60 | Share audio from an iOS app into a Shortcut → import → transcribe → pass resulting text/file to another app. | iOS actions accept supplied content and return reusable results (U07/U33). | Accepted types, file access, provider availability, foreground/lock limits, destination capabilities, long-job continuation. |
| P-F61 | Run an iOS capture Shortcut → save audio → obtain transcript → apply a template → append to a chosen note → return a note link. | Capture, processing and notes compose as separately useful actions (U24/U30/U33). | Recording permission, app handoff, cancellation, offline queue, model readiness, explicit completion and action outputs. |
| P-F62 | A later workflow step fails after transcription succeeded → inspect saved outputs → retry that step → verify the destination. | Resume on Mac or iOS preserves originals and completed work (U27/U29/U30/U32/U33). | Duplicate delivery, unknown external outcome, retry identity, paused host, changed recipe/profile, retained revisions; never repeat a call to retry processing. |

## Shared concepts to investigate

| Concept | Questions to preserve before designing a data model |
| --- | --- |
| Capture session | Who started it, on which device, using which inputs, and where is its current durable copy? |
| Audio segment | Where is its durable on-device copy? How do pauses, corruption, and interrupted transfer affect recovery? |
| Transcript revision | Which model, language, and inputs produced it? Are timestamps and speakers reliable? |
| User-authored note | How is it preserved separately from generated content? |
| Generated result | Which source revisions and prompt/template produced it, and can it be regenerated safely? |
| Dictation insertion | Which destination received which revision, and can a failed insertion be recovered? |
| Vocabulary/style/template | Is it personal, app-specific, shared, versioned, or synchronized? |
| Collection and access grant | Which material is authorized for a query, share, integration, or model request? |
| Job | What is its durable state, cancellation boundary, retry identity, and result lifetime? |
| Device and connection profile | Which server/provider does it trust, and how is that trust revoked? |
| Provider/model configuration | Which capabilities are supported, and where do credentials and request data live? |
| Export/backup | Does it contain enough information for restore, rather than just human-readable output? |
| Call session | Which route and recipient were used, which audio directions were captured, and what gaps remain? |
| Note link and saved layout | Which stable objects and source revisions does a workspace reference? |
| Hook event and receipt | Which revision caused the event, where did it run, and what effects can replay duplicate? |
| Sync account and replica | Which account owns each copy and pending change, and how is a conflict preserved? |
| Workflow recipe and run | Which action versions and profiles were chosen, which inputs/results link the steps, and where can the run resume? |

These concepts describe information the user may need to understand. They are not database tables, API schemas, service boundaries, or permission to implement those systems.
