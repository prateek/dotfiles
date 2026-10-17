---
status: draft
doc_type: research
summary: "Apple platform constraints and native UX questions for Mac, iOS and Watch clients: keyboards, audio, accessibility and design quality."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Apple platform evidence and exploratory UX flows; no implementation or architecture selected."
---

# Apple platforms and native voice UX

The opportunity is to make speaking feel like a dependable part of each device's
normal workflow. Apple’s platforms offer useful capture, presentation, and
automation surfaces, but they do not offer equivalent powers. A Mac can pursue
cross-app text insertion; an iPhone keyboard extension has material restrictions;
an independent Watch experience cannot depend on its paired phone being present.
These differences belong in the product exploration before visual design hardens.

This brief records documentation checked on **2026-10-12**. **Documented** means
supported by the cited Apple source, not exercised on hardware. **Candidate** and
**question** identify original research proposals, not competitor capabilities,
accepted requirements, or a selected architecture. No app was installed, no
account or device was accessed, and no latency, battery, recognition quality, or
App Review outcome was measured. The evidence ledger is
[source registry](data/sources.jsonl).

## What the design ambition means

Apple’s 2026 Design Awards recognize Delight and Fun, Inclusivity, Innovation,
Interaction, Social Impact, and Visuals and Graphics. Its Interaction category
emphasizes controls and interfaces suited to their platform; Inclusivity includes
abilities, languages, and backgrounds. These are public category descriptions,
not a published scoring formula or a promise that adopting particular APIs wins
an award. [Apple Design Awards, AX-S01](https://developer.apple.com/design/awards/)

**Research interpretation:** “truly mac-assed” should be investigated as quality
of behavior: keeping the person's place, making commands discoverable, preserving
editable text, recovering from failure, and cooperating with other apps. A
beautiful recording animation cannot compensate for inserting into the wrong
document. An ambitious cross-device product might feel consistent because it
preserves intent and explains progress, while its screens differ substantially.

Questions for prototype reviews include: Can someone finish the primary task
without learning product vocabulary? Do repeated sessions become simpler? Does
the interface remain understandable without hearing a chime or seeing a waveform?
Does a failure leave the person with something useful? Can they explain where
their audio went? These are proposed evaluation questions; their answers are
currently unknown.

## macOS: capture belongs beside the work

### Native surfaces and focus

Apple’s Mac guidance prioritizes keyboard commands, the menu bar, flexible
windows, comfortable information density, and smooth movement between apps.
It favors using a large display to reduce unnecessary navigation and modality.
[Designing for macOS, AX-S03](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)

**Candidate:** explore a compact recording surface near the current task, a menu
bar entry for discoverability and session status, and an ordinary resizable window
for reviewing recordings, corrections, and settings. Compare whether the small
surface should accept focus or leave it in the destination app. A menu bar icon
alone may conceal an unfinished recording or error; a permanent floating window
may compete with the user's work. Neither option has been chosen.

Mac-native review could include selectable text, standard editing commands,
familiar menus, meaningful window titles, and a Settings window with predictable
navigation. Investigate whether transcript history behaves more naturally as a
list of sessions or as documents. Test multiple displays, full-screen apps, Spaces,
window tiling, and return from sleep before claiming the capture surface is
reliably available.

### Permissions and insertion are separate problems

Microphone capture requires explicit authorization, a microphone usage
description, and the applicable macOS audio-input entitlement. Apple recommends
checking authorization before capture and requesting it in the context of the
feature. [Media capture authorization, AX-S07](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)

**Candidate:** first use demonstrates recording in the app, then explains
cross-app insertion when the person tries it. Investigate separate, recoverable
states for microphone unavailable, permission denied, and text destination
unavailable. Permission to record is not evidence that delivery into another app
will work.

The Accessibility setter can fail because the target lacks an attribute, exposes
an invalid element, fails messaging, or does not fully implement Accessibility.
This is a documented compatibility boundary, not a universal insertion contract.
[AXUIElementSetAttributeValue, AX-S05](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue)

**Candidate:** evaluate direct insertion where supported, followed by an explicit
Copy action when it is unavailable. Clipboard fallback raises its own questions:
whether existing contents should be preserved, how to avoid overwriting a newer
copy, what sensitive text remains, and how to distinguish “copied” from “inserted.”
Automated paste is a separate experiment, not an assumed reliable fallback.
Inspect rich text, browser editors, terminals, Electron apps, selection replacement,
secure fields, and focus changes during transcription. Investigate host undo
behavior rather than promising a universal Command-Z reversal.

### Hotkeys and system audio

Apple’s archived event-monitor guide distinguishes global monitors, which observe
other apps, from local monitors. Global monitors cannot consume or modify events;
the guide also describes Accessibility trust for observing key events. This does
**not** establish that every hotkey mechanism needs that permission, or settle
current Input Monitoring behavior for a chosen API.
[Monitoring Events, AX-S04](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)

**Question:** which supported shortcut mechanism gives predictable press, release,
toggle, cancellation, and conflict handling on the intended OS versions? Compare
hold-to-talk with a toggle and an onscreen alternative, including modifier-only
shortcuts, international layouts, assistive shortcuts, and missed key-up events.

ScreenCaptureKit provides selective screen/audio capture and recommends its
system content picker; its current overview specifies screen-capture
authorization. This makes it a documented candidate for capturing computer
output, distinct from microphone-only dictation.
[ScreenCaptureKit, AX-S06](https://developer.apple.com/documentation/screencapturekit)

**Question:** what permission wording and capture scope does an audio-only
implementation actually expose on each supported macOS version? Evaluate system
audio separately from personal dictation, including visible source selection,
source disappearance, loopback/echo, exclusion of the app's own sounds, and ending
capture. This research does not select ScreenCaptureKit over other supported
audio APIs or verify capture of any particular meeting app.

## iPhone and iPad: distinguish recording from keyboard insertion

U23 now makes a custom iOS keyboard an explicit requirement. The extension's capture mechanism remains a feasibility question. U25 also requires transcribed calls initiated in the iOS app, and U31 requires optional iCloud sync. See [product behavior and durability](product-behavior.md) for call-media, local-retention, and account-change evidence.

### The keyboard boundary is consequential

Apple’s current open-access documentation describes a separately sandboxed
keyboard process. Without full access it has no network access and read-only
access to the containing app's shared containers. Full access enables network and
shared-container capabilities after the person enables it in Settings. The same
current guide explicitly excludes microphone and speaker access; enabling full
access retains those restrictions.
[Keyboard open access, AX-S08](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)

The archived extension guide also excludes microphone capture, excludes custom
keyboards from secure and phone-pad fields, and permits host apps to
reject them. It describes text insertion through the document proxy, but text
selection remains the host's responsibility. Its age matters: use it to identify
constraints to verify against current SDKs, not as evidence for an untested
workaround. [Custom Keyboard, AX-S09](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)

Current App Review guideline 4.4.1 requires keyboard input, keyboard switching,
and functionality without full access; it prohibits launching apps other than
Settings. Therefore a keyboard button that launches a recording app is not an
established compliant flow. Guideline 2.5.4 limits background services to their
intended purposes. Guideline 2.5.14 requires consent and a clear recording
indication; 5.1.2(i) requires disclosure and permission before sharing personal data
with third parties, including third-party AI.
[App Review Guidelines, AX-S10](https://developer.apple.com/app-store/review/guidelines/)

**Candidate comparison:** investigate recording in the main app followed by
explicit copy/share; starting the main app through a user-invoked system action;
and, separately, a keyboard that inserts an already-produced result. A background
recording session paired with a keyboard requires its own API, lifecycle,
privacy, and review investigation. Competitor demonstrations, if found elsewhere,
would establish observed product behavior, not permission to reproduce its
mechanism. No keyboard-to-app escape hatch or persistent background microphone
has been validated here.

### Audio sessions make interruptions part of the experience

Apple documents background continuation for recording when the `audio`
background mode is declared. Its `record` category can silence other audio and
does not prevent calls, alarms, or incompatible audio sessions from interrupting
capture; the reference suggests considering `playAndRecord` when silencing output
is unnecessary. [Recording audio category, AX-S11](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record)

**Research implication:** the UI needs an investigated distinction between
recording, interrupted, and finished. Compare keeping the partial recording,
offering resume, and starting a new segment; do not silently present an
interruption as a successful complete transcript. Examine lock/unlock, app
switching, calls, alarms, Bluetooth route changes, and the user explicitly
terminating the app. A permitted background mode does not prove perpetual
microphone availability or uninterrupted transcription.

### System entry points are useful, but different

App Intents can expose actions and data to Siri, Shortcuts, Spotlight, widgets,
controls, and supported Action-button workflows. It provides a way to describe
actions, not proof that every recording task can run in every invocation context.
[App Intents, AX-S12](https://developer.apple.com/documentation/appintents)

Widgets provide glanceable content, timeline-driven updates, and links into an
app. Apple also documents redaction of sensitive widget and complication content.
[Creating a widget extension, AX-S18](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

Live Activities support ongoing status and quick actions. They cannot directly
access the network; updates come through the app or ActivityKit pushes. Apple
documents an eight-hour active lifetime, possible Lock Screen retention for four
additional hours, and a combined 4 KB static/dynamic data limit. Dismissing the
activity does not inherently cancel its underlying task.
[Live Activities, AX-S13](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

**Candidate:** test a recording entry point, an ongoing capture/processing status,
and a recent-result widget as three distinct experiences. Status should explain
what is happening without exposing dictated content on a locked display. A
control labeled Stop needs observed completion semantics; removing a status view
must not be mistaken for stopping the microphone. None of these surfaces grants
cross-app text insertion or an unrestricted recording runtime.

## Apple Watch: confidence in a brief interaction

Apple emphasizes focused, glanceable Watch interactions, shallow navigation,
Digital Crown use, and complications that lead into useful tasks. The watch app
should make sense independently of its related surfaces.
[Designing for watchOS, AX-S14](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)

**Candidate:** one obvious capture action, a legible recording state, an accessible
Stop action, and a concise confirmation. Explore haptic acknowledgement alongside
visible state rather than forcing the person to stare at a waveform. A
complication might open capture or indicate pending work; whether it displays
recording state accurately requires investigation. A useful Watch interaction
may end with “Saved on Watch” while transcription happens later.

Apple’s frontmost-state documentation distinguishes lowering the wrist from
explicitly leaving the app. It also documents audio-recording sessions continuing
in the background. The page includes older UI and device examples, so its exact
presentation and lifecycle descriptions require current-device validation.
[Frontmost app state, AX-S17](https://developer.apple.com/documentation/watchkit/taking-advantage-of-frontmost-app-state)

Independent apps must be able to handle their own setup, permissions, and data
access without the companion iPhone app. WatchConnectivity may enhance an
independent app but cannot be its principal data dependency.
[Independent watchOS apps, AX-S15](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps)

Apple’s Watch data-transfer session distinguishes reachable interactive messages
from queued user-info/file transfers. Background delivery timing depends on
system conditions. WatchConnectivity links the Watch and paired iPhone, not the
Mac directly. It is unsuitable as the mechanism for a Family Setup app. Apple
also emphasizes deferring transfers when possible to preserve battery and avoiding
unnecessary data on the Watch.
[Watch data transfer, AX-S16](https://developer.apple.com/videos/play/wwdc2021/10003/)

**Questions:** can a recording survive a failed transfer and be retried without
duplication? Can users see where the only copy currently lives? What remains
useful without phone, Wi-Fi, cellular service, or account access? How much capture,
processing, and transfer energy is acceptable on actual hardware? There is no
measured battery budget or selected recording duration here. Mac support for an
on-device model does not establish its watchOS availability, memory fit, speed,
or energy cost. Offline capture and offline transcription are separate claims.

## Candidate end-to-end flows

These are original experience sketches. Their IDs support later research and
comparison; none denotes a shipped competitor feature or an implementation
commitment.

| ID | Proposed journey | Decisive uncertainty |
| --- | --- | --- |
| AX-F01 | In a Mac editor, invoke capture, speak, stop, review if needed, insert at the intended selection, and correct or undo. | Destination identity, supported editors, focus changes, and host undo. |
| AX-F02 | Dictate on Mac while insertion permission is unavailable; keep the result visible and explicitly copy it for manual paste. | Clipboard ownership, sensitive text, and explaining incomplete delivery. |
| AX-F03 | Choose a Mac audio source, capture a session, distinguish microphone from computer output, then review/export text. | Actual capture scope, permission presentation, interruption, and source changes. |
| AX-F04 | Invoke iPhone recording from the app or a system action, stop, review, then copy/share into the intended destination. | Invocation context, app switching, interruption, and number of user steps. |
| AX-F05 | Open a custom keyboard to insert a completed result produced elsewhere in the app. | Current extension constraints, full-access-off behavior, stale results, and host exclusions. |
| AX-F06 | Capture a thought on Watch, receive saved-state confirmation, lower the wrist, and later review the transcript on iPhone or Mac. | Local durability, delayed transfer, duplicate delivery, and a separately established Mac path. |
| AX-F07 | Capture without network access; show which operations remain possible and resume a chosen remote operation after connectivity returns. | Model availability, queue survival, user consent, and stale credentials. |
| AX-F08 | Supply an existing recording through CLI or an explicitly invoked MCP tool, follow progress, and retrieve text or open its review UI. | Automation contract, cancellation, credential scope, and unambiguous errors. |

For AX-F08, input/output examples and commands remain undesigned. A research
prototype could compare machine-readable progress with quiet pipeline output,
and distinguish transcription from sending the result elsewhere. The native app
should not have to open merely to explain a routine automation failure; equally,
an automated caller should not silently start ambient recording because a tool
name is ambiguous. Apple sources above do not validate MCP protocol behavior.

## Accessibility, feedback, and trust to investigate

Apple recommends adjustable text, VoiceOver descriptions, keyboard access,
alternatives to gestures, information conveyed through more than color or sound,
and reduced repetitive motion when Reduce Motion is enabled. Its guidance also
warns against controls that disappear before someone can use them.
[Accessibility HIG, AX-S02](https://developer.apple.com/design/human-interface-guidelines/accessibility)

**Candidate state vocabulary:** ready, recording, interrupted, processing, saved
here, waiting to transfer, available elsewhere, inserted, and failed. Test whether
people distinguish these without reading help. A moving waveform is only an
input indication; it cannot certify that storage or recognition succeeded.
Compare subtle animation with static state for reduced-motion users. Try
VoiceOver announcements that communicate transitions without speaking over the
dictation or announcing every partial token.

Latency research should separate invocation-to-listening, stop-to-result,
result-to-insertion, and cross-device availability. Observe their distributions
alongside correction effort and perceived confidence. No acceptable millisecond
threshold has been established. An honest processing state and usable partial
result might matter more than a decorative claim of immediacy.

Investigate empty states independently: first use, no detected speech, permission
denied, unavailable model, no network, and no pending recordings are different
situations. Preserve recoverable work where possible, explain the next action,
and distinguish cancelling processing from deleting the recording. Explore
undoable edits and explicit retry before designing destructive cleanup.

Provider visibility is an experience question as well as a settings question.
Compare concise indications such as processing on this device, on a named
user-controlled computer, or with a named remote provider. Audio recognition and
text rewriting may use different destinations. Test whether a person understands
that difference before choosing a fallback; a silent change of destination would
undermine the meaning of an offline or local preference. U30 requires retained
on-device source material and history for reprocessing. Replication scope,
capacity handling, and deliberate permanent purge across replicas remain design
questions; successful sync must preserve the local history.

## Validation matrix and unresolved evidence

The following is a proposed validation program, not a report of completed tests.
Choose supported OS versions and representative hardware before claiming a
coverage envelope. Record exact builds, permissions, inputs, expected outcomes,
and observed results; keep screenshots and traces separate from conclusions.

| Area | Cases to exercise | Evidence needed |
| --- | --- | --- |
| Mac delivery | Native text, web rich text, terminal, Electron, secure field, moved selection, closed destination | Correct destination and text; recognizable unsupported cases; observed undo and fallback behavior. |
| Mac invocation | App active/inactive, Spaces, full screen, multiple displays, conflicting shortcut, missing release, sleep/wake | Start/stop reliability, focus preservation, and understandable recovery. |
| Permissions | Fresh grant, denial, later revocation; capture and insertion separately | Actual prompts and behavior, including useful operation after partial denial. |
| iOS lifecycle | Foreground, lock, app switch, interruption, Bluetooth changes, termination | Whether capture continues; what survives; accurate partial/final status. |
| Keyboard | Full access on/off, secure/phone fields, host rejection, extension restart | Current API behavior, usable baseline input, and no dependence on an unapproved launch mechanism. |
| Watch lifecycle | Wrist down, Crown exit, lock, low-power state, no paired phone, no network | Saved-data survival and accurate local versus remote status. |
| Transfer | Delayed, repeated, interrupted, or cancelled delivery; device unavailable | Recoverability, deduplication, and eventual-state consistency without false success. |
| Accessibility | VoiceOver, enlarged text, keyboard-only use, Switch Control, contrast, Reduce Motion | Completion of the same meaningful tasks, readable status, reachable controls. |
| Trust and automation | Provider unavailable, local model missing, expired credentials, CLI pipe, MCP cancellation | No unexplained destination changes; explicit errors and retained work. |

The largest unresolved issues are iOS keyboard ergonomics within current rules,
cross-app Mac insertion fidelity, Watch durability and power use, and how to make
cross-device completion understandable without promising immediate transfer.
They need focused prototypes and user observation. The reviewed documents
establish platform opportunities and boundaries; they establish no product's
runtime quality, distribution approval, or readiness for implementation.
