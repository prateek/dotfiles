---
status: draft
doc_type: research
summary: "Candidate behavior and qualification questions for custom keyboards, second-brain notes, transcribed calls, hooks/XDG, retained history and optional iCloud."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Explicit follow-up directions with candidate interactions and qualification questions; no implementation selected."
related:
  - requirements.md
  - candidate-journeys.md
  - apple-platforms-and-ux.md
  - self-hosting-and-models.md
---

# Product behavior and durability

Prateek's second requirement statement makes the iOS keyboard, second-brain notes,
transcribed outgoing iOS calls, hooks, XDG configuration, retained local history,
and optional iCloud sync explicit product directions. The [requirements ledger](requirements.md)
preserves the statement as U23–U31. The behavior below is a proposed interpretation
to refine; it does not select a storage engine, calling provider, editor, or sync protocol.

## Custom keyboard is a required iOS surface

U23 settles whether the product includes a custom keyboard. Installation remains
the person's choice. Explore onboarding, enabling and switching keyboards,
inserting a completed result, correcting it, and recovering after the destination
app or capture session disappears. Keyboard users need a useful path when full
access is off or a field excludes third-party keyboards.

The capture mechanism still needs qualification. Apple's current documentation
excludes microphone/speaker access inside the keyboard extension, including with
full access. The main app's recording session and the keyboard's insertion surface
must therefore be investigated separately. This constraint does not demote the
keyboard requirement to an optional product idea.
[AX-S08: keyboard open access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard).
The [Apple study](apple-platforms-and-ux.md) retains the app-switching and review questions.

## Notes are a personal knowledge workspace

U24 asks for second-brain notes and layout. Explore a capture inbox that leads into
an organized workspace where the person can connect ideas and revisit their sources.
Candidate structures include daily notes, projects, people, topics, saved views,
links and backlinks. A graph, canvas, block editor, or particular folder taxonomy
has not been requested or selected.

Candidate Mac layout: a navigable sidebar, a note/list workspace, and an optional
source/history inspector. Preserve selection, scroll position, and open context
while moving between a note, transcript passage, and recording. Compare that with
an iPhone layout that supports quick capture and readable review without squeezing
the desktop panes onto a small screen. Multiple windows, keyboard navigation,
accessible structure, and restoration of the working layout need evaluation.

Voice notes, meetings, and calls should be explored as inputs to the same knowledge
workspace. Keep human writing distinguishable from generated summaries. A useful
question is whether a person can follow a saved idea back to the exact source and
revision without losing their place. File formats, stable links, attachments,
interoperability with other note systems, and import fidelity remain open.

## Outgoing calls belong in the iOS app

U25 means initiating a call through the product and transcribing it. Importing a
recording later does not by itself satisfy that requirement. Prateek confirmed that calls must reach ordinary phone numbers on the public
telephone network (PSTN). App-to-app calling alone does not satisfy U25.

Apple describes CallKit as the native calling interface for an app's VoIP service;
the application supplies the backend communication. It is a candidate integration
surface, not evidence that the app can obtain the audio of an arbitrary carrier
call. Calling-service connectivity and access to both media directions require
their own investigation. [PD-S01: CallKit](https://developer.apple.com/documentation/callkit).

Candidate sequence: choose a contact or enter an ordinary phone number, inspect the calling route,
start the call with clear capture/notice state, speak, end, then review the retained
audio and transcript in a call-linked note. Whether text appears live or only
afterward remains open. Show calling, connected, recording, locally saved, and
transcribed as separate states; a connected call does not prove successful recording.

Explore no answer, busy, voicemail, mute, hold, DTMF, Bluetooth changes, lock,
interruption, lost connectivity, and a missing audio direction. Keep partial
material and visibly identify capture gaps. A retry of transcription must never
place another call. Required ordinary-number support needs a qualified telephony route,
identity/number management, regions, and costs. Investigate an owned calling service
with a telephony interconnect and a hosted calling backend as candidate routes.
Self-hosting the notes/models does not establish independent access to the telephone network. Incoming calls,
number porting, and default-dialer status remain separate scope questions.

## Composability includes hooks and dotfiles

U32–U33 explicitly add action chaining through Tuna/Raycast on Mac and equivalent
workflow composition on iOS. The [workflow study](workflow-composition.md) records
candidate input/output contracts, platform adapters and recovery criteria. The
next action must be able to consume a result; opening another app alone does not
establish a completed chain.

U26–U28 make composability a product property. Candidate operations such as capture,
import, transcribe, organize, reprocess, and export should expose consistent
identities and results across the interfaces that support them. Investigate pipes,
structured input/output, documented events, stable links, and inspectable files
alongside CLI and MCP. These are interface candidates, not a commitment to every
transport on every client.

For hooks, investigate events such as capture persisted, transcription completed,
note revised, export completed, and job failed. Specify which device or server
runs a hook, what data it receives, what it can change, and how failures appear.
Candidate contracts include versioned payloads, event/job IDs, timeouts,
deduplication, bounded retries, replay, and an inspectable result log. A broken
hook must not undo a saved recording or block core recovery. Replays must account
for external side effects; an event ID alone cannot guarantee exactly-once delivery.
Hook scripts and transcripts are executable code and data respectively: text
inside a transcript must not become a shell command by accidental interpolation.

For XDG configuration, the specification separates configuration, durable data,
restart-persistent state, disposable cache, and session-lifetime runtime objects.
It requires absolute environment-variable paths and defines defaults for unset or
empty variables. [PD-S05: XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/).

Proposed application mapping:

| Location | Candidate contents |
| --- | --- |
| `$XDG_CONFIG_HOME/<app>` (default `~/.config/<app>`) | Inspectable settings, model profiles, hook declarations, templates, and secret references. |
| `$XDG_DATA_HOME/<app>` (default `~/.local/share/<app>`) | Irreplaceable recordings, notes, revision history, and source metadata. |
| `$XDG_STATE_HOME/<app>` (default `~/.local/state/<app>`) | Operational cursors, hook receipts, and device-specific view state, with backup needs defined separately. |
| `$XDG_CACHE_HOME/<app>` (default `~/.cache/<app>`) | Only rebuildable derivatives or downloadable artifacts; never the sole copy of captured work. |
| `$XDG_RUNTIME_DIR/<app>` | Temporary sockets and process coordination; never retained history. |

`<app>` is a placeholder. The configuration format and namespace are undecided.
Define effective-setting precedence, validation, schema migration, and how GUI
changes interact with user-maintained dotfiles. Keep credentials out of ordinary
version-controlled settings. macOS sandboxing and the containers available to iOS
and Watch need a deliberate mapping; XDG support does not imply unrestricted
filesystem or script execution on every Apple client.

## Preserve originals and history through failure and reprocessing

U29 preserves the user's absolute ambition: “never any data loss.” U30 makes local
retention a requirement even after successful processing or synchronization.
The engineering contract needs observable failure boundaries before the product
can claim to satisfy that ambition. No reliability implementation has been tested.

Candidate acceptance criteria:

- Persist recoverable audio while capturing, not only when Stop is pressed.
  Record incomplete segments and capture gaps honestly after interruption.
- Show “saved on this device” only after the defined durable-write boundary.
  Distinguish local persistence from server receipt and completed synchronization.
- Retain originals and prior transcript/note revisions. Reprocessing creates a
  result tied to its input, model, settings, and template; it preserves manual edits.
- Successful insertion, upload, sync, cache cleanup, or a retention timer must not
  silently delete local source material or revision history.
- Cancellation of processing preserves captured work. Relaunch, update, failed
  migration, conflicting edits, and hook errors must leave recoverable state.
- Warn before storage fills. If continued capture cannot be persisted, stop with
  a visible failure and preserve what was saved; never hide the problem by
  evicting older recordings. Measure the unsaved capture window explicitly.
- Keep recoverable history through hide/archive/delete actions. Permanent purge
  and its effect on every replica require a separately defined, deliberate action.
- Validate backup and restore with originals, revisions, attachments, and keys.
  Restoring a readable summary alone does not establish complete recovery.

Local retention protects against processing and network failures; a single device
cannot preserve its only copy after destruction or unrecoverable storage failure.
The product still needs a documented independent-copy strategy for those cases,
including when iCloud is off. Optional synchronization alone is not a demonstrated
backup/restore guarantee. Capacity, key recovery, and deliberate erasure are open
design questions, not reasons to quietly weaken the retention requirement.

## iCloud is an opt-in synchronization path

U31 requires iCloud integration while preserving local-only and self-hosted use.
Candidates include enabling sync for an existing library, joining another device,
choosing which artifacts replicate, inspecting pending changes, resolving conflicts,
and disabling sync while retaining locally owned history. Replicating every
recording to every device, including Watch, is not yet a selected policy.

Apple documents separate approaches for files, lightweight preferences, and model
objects; choosing iCloud integration does not select CloudKit, iCloud Documents,
or Core Data. Its documentation also distinguishes device backup from app sync.
[PD-S02: iCloud storage and sync options](https://developer.apple.com/documentation/cloudkit/deciding-whether-cloudkit-is-right-for-your-app).

As one candidate, CKSyncEngine handles scheduled sync and some transient failures,
but leaves application-specific conflicts to the app. Its schedule depends on
system conditions and an available account.
[PD-S03: CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5).
On account change it resets internal pending-change state, so the product must
preserve its own durable content and handle account boundaries explicitly.
[PD-S04: account changes](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange).

Investigate iCloud disabled, no account, quota full, network unavailable, concurrent
edits, remote deletion, and account switching. Local history must not be silently
erased, and one account's material must not be uploaded into another account without
an explicit ownership/merge decision. Syncing a hook declaration must not silently
execute it on another device. Coexistence with self-hosted sync needs a defined
replication and conflict model; no dual-writer architecture is assumed.

The [journey inventory](candidate-journeys.md) and [question backlog](open-questions.md)
carry these directions forward without choosing implementation order.
