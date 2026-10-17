---
status: draft
doc_type: research
summary: "Unresolved product, platform, hosting and automation questions Q01–Q39 plus the capture sheet for later authorized walkthroughs."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Unresolved product decisions and evidence gaps; not a questionnaire that blocks continued capture."
---

# Open questions and further observation

This backlog preserves uncertainty. It does not require answers before collecting more evidence, and it does not turn suggestions into commitments. The [requirements ledger](requirements.md) distinguishes what Prateek explicitly requested; [candidate journeys](candidate-journeys.md) identify possible consequences.

The follow-up settles custom keyboard support, second-brain notes, transcribed outgoing iOS calls to ordinary phone numbers, hooks, XDG dotfiles, on-device history for reprocessing, and optional iCloud sync (U23–U31). Questions below concern how these work, not whether to include them.

## Product and audience

| ID | Question | Why the answer matters |
| --- | --- | --- |
| Q01 | Who is the first primary user: an individual, household, small team, or administrator serving many users? | Ownership, deployment, sharing, identity, and setup complexity. |
| Q02 | Are dictation, meeting notes, and personal voice notes equally central? | Navigation and daily interaction model, without prematurely choosing an MVP. |
| Q03 | What does “best” mean for each reference product in Prateek's actual use? | A public feature list cannot identify personally valuable behavior or friction. |
| Q04 | Which existing workflows/data should migrate into the new product? | Import fidelity, vocabulary, templates, history, attachments, and export completeness. |
| Q05 | Should the product own tasks and external actions, or hand those to other tools? | Scope and interaction complexity as reference products expand. |
| Q06 | Is collaboration/sharing part of the intended product or only reference research? | Single-owner self-hosting differs from permissions across teams and public links. |

## Clients and native quality

| ID | Question | Evidence needed |
| --- | --- | --- |
| Q07 | What macOS/iOS/watchOS minimums and hardware generations matter? | User devices and measured capture/model behavior; avoid selecting by competitor marketing alone. |
| Q08 | Does iOS include iPad, and should Watch work without a paired/nearby phone? | Explicit platform requirements and platform lifecycle experiments. |
| Q09 | Which capture/insertion mechanism delivers the required iOS custom keyboard? | Current keyboard-extension, microphone, app-switching, and App Review guidance plus a focused prototype. |
| Q10 | What should the Mac app do when text insertion cannot be completed? | Observation across editors, browsers, terminals, password fields, and changing focus. |
| Q11 | Which entry points matter: global shortcut, menu bar, Dock, Services, Share Sheet, Shortcuts, widgets, Action button, Watch complication? | Task-specific usability sessions and platform availability. |
| Q12 | What observable bar expresses “mac-assed” and award-level quality? | Apple criteria, accessibility checks, native behavior review, task success, responsiveness, recovery, and sustained daily use. |
| Q13 | Which languages, accents, jargon, code-switching, and speech differences should evaluations cover? | Representative samples obtained with consent and explicit accuracy/intent scoring. |
| Q14 | What capture, processing, insertion, battery, and memory targets matter? | Cold/warm device measurements and user tolerance; no arbitrary threshold yet. |

## Models, data, and self-hosting

| ID | Question | Evidence needed |
| --- | --- | --- |
| Q15 | Which stages must run on each device, on the user's server, or at a commercial API? | A data-destination map for each candidate flow. |
| Q16 | What must work entirely offline on Mac, iPhone, and Watch? | Separate capture, retention, transcription, rewriting, summary, and recall requirements. |
| Q17 | Can any failure automatically route work to another provider? | An explicit user policy for changes of privacy, cost, quality, and latency. |
| Q18 | Are local inference and self-hosted application storage independently configurable? | Desired topology and operational responsibility, beyond “supports Ollama.” |
| Q19 | What is the supported deployment promise for exe.dev, Unraid, and other hosts? | Real install, persistence, TLS, auth, native-client access, update, restore, and hardware tests. |
| Q20 | How should optional iCloud and self-hosted sync coexist with pairing, conflicts, and device revocation? | Threat/ownership model and disconnected-use scenarios. |
| Q21 | Beyond required on-device source/history retention, which context may be collected or sent to each processor? | Explicit per-stage purpose, retention, inspection, and deletion controls. |
| Q22 | How should recoverable deletion and deliberate permanent purge work with required history retention? | A lifecycle policy users can understand and a tested implementation later. |
| Q23 | Which product, dependency, and model licenses allow the intended redistribution? | Version-pinned license review; OSS application licensing does not cover model weights automatically. |
| Q24 | What is the funding/distribution model? | Choices around direct download, App Store, paid convenience distribution, donations, services, and support. |

## Automation and interoperability

| ID | Question | Evidence needed |
| --- | --- | --- |
| Q25 | Which operations/events must compose across apps, CLI, MCP, hooks, and user scripts? | Real scripts/agent tasks, read/write distinctions, input/output examples, and permission boundaries. |
| Q26 | Is the CLI expected on Linux/Windows as well as macOS? | User deployment and scripting environments. |
| Q27 | Beyond required iCloud sync and hooks, which integrations matter: calendars, notes, mail, chat, tasks, filesystem, webhooks? | User workflows and official supported APIs; no implied access to accounts. |
| Q28 | How should long jobs, retries, streaming, cancellation, and results work across app/CLI/MCP? | Client protocol compatibility and durable job expectations. |
| Q29 | Which actions require an explicit review before they leave the product? | Distinguish draft creation, local insertion, sharing, messaging, and third-party mutation. |

## Follow-up detail to resolve

| ID | Question | Evidence needed |
| --- | --- | --- |
| Q30 | Resolved: outbound iOS calls must reach ordinary phone numbers. Which route delivers that? | User confirmed PSTN destination; telephony provider/interconnect, two-sided media, caller identity, regions and costs remain open. |
| Q31 | Which notes structures and layouts make this a useful second brain? | Daily/project/person notes, links/backlinks, inbox, saved views, source inspector, editor and export trials. No graph/canvas assumed. |
| Q32 | Where do hooks run, with which events, inputs, permissions, and replay semantics? | Example personal automations, scripts versus webhooks, execution hosts, failures, and downstream duplicate-effect handling. |
| Q33 | What is the XDG configuration contract across CLI, Mac app, server, and sandboxed mobile clients? | Namespace/format, directory mapping, precedence, validation, GUI/file reconciliation, secrets, migration. |
| Q34 | What exact failures and persistence boundary must satisfy “never any data loss”? | Capturing and saving crash tests, unsaved window, power loss, corruption, full storage, migration, device destruction, and restore. |
| Q35 | Which history stays on the origin device and which material replicates to each other device? | Original audio and revision requirements, Watch capacity, attachment scope, encryption, no automatic expiry, and deliberate purge semantics. |
| Q36 | How does optional iCloud handle existing libraries, account changes, conflicts, quota, and self-hosted sync? | Isolation/merge rules, asset availability, disabling without erasure, and independent backup/recovery. |
| Q37 | What calling details extend beyond initiating and transcribing outgoing calls? | Live transcript versus afterward; incoming calls, caller identity, numbers, voicemail, default-dialer status, and capture/notice behavior. |
| Q38 | Which actions and result types must chain through Tuna/Raycast and iOS automation? | U32–U33 settle support; determine input/output contracts, scripts versus extensions, Shortcuts intents and discoverable recipes. |
| Q39 | How does a workflow wait, resume and retry across app or launcher interruption? | Completion versus launch acknowledgement, durable jobs/intermediate revisions, iOS foreground/lock constraints, and uncertain external effects. |

## Observe what public documentation cannot establish

Each competitor dossier carries product-specific gaps. Use the following capture sheet for a later authorized walkthrough:

1. Record product name, version/build, platform/OS, account tier, model/provider, language, and relevant settings.
2. Select a flow ID and goal. Start from a stated initial condition, not an already-working privileged state.
3. Record the actual screens, controls, sequence, keyboard interactions, focus transitions, and observed feedback. Count actions only after observation.
4. Record permission denial, unavailable network/provider, interrupted recording, canceled processing, full storage, stale credentials, and lost insertion target where safely reproducible.
5. Capture output quality, timing, destination, retention, retry behavior, and source/provenance handling. A documentation claim is not a measured result.
6. Mark the result as observed with evidence and environment, or retain the gap. Record disagreement with public docs without silently overwriting either observation.

Use synthetic or explicitly authorized material. Account-gated pages, installed app state, live recordings, teammates' content, and private notes have not been inspected for this research. App Store screenshots and public demos are reference evidence, not verification of behavior on Prateek's devices.

## Questions for a fresh reader of this corpus

- Can you identify every explicit platform/deployment/UX requirement without reading this conversation?
- Can you distinguish a sourced competitor flow from a proposed product journey?
- Can you find the original source and its platform/version limitations for a claim?
- Can you explain what “local,” “offline,” and “self-hosted” do and do not establish?
- Can you see which workflows are still undocumented or unobserved?
- Does anything accidentally authorize implementation, choose a stack, claim live validation, or imply that a feature count defines the best UX?

This is a discovery corpus. The correct reader answer to “what are the first five implementation tasks?” is that implementation has not been scoped; unresolved product and platform questions must first be converted into a separate proposed plan when requested.

## Meeting integration evidence follow-up

The [REA integration study](meeting-integrations.md) now documents static Zoom/Meet mechanisms and a separate closure table. The remaining work concerns controlled runtime compatibility/accuracy, Monologue's unresolved speaker attribution, the exact native Wispr traversal, and official API eligibility. UI observation, an attendee roster, and acoustic diarization must remain distinct evidence types. Candidate observation-journal requirements are proposed in that study; that pass did not change the then-current 31 explicit requirements. The later workflow statement adds U32–U33.

## Additional reference evidence

The [five-app selection and analysis](additional-apps.md) extends the corpus without changing the explicit requirements. Its most useful unresolved probes map to existing questions:

- **Q09/Q12:** actual Superwhisper and MacWhisper iOS keyboard handoffs, accessibility and focus recovery.
- **Q15/Q18:** Anarlog's optional services versus a fully self-hosted deployment; Reflect's chat endpoint versus cloud transcription; Superwhisper's language-only custom endpoint scope.
- **Q25/Q28/Q32:** app-dependent CLI operations, MCP writes, dropped webhook events, durable retry and replay.
- **Q31/Q34/Q35:** compare linked Markdown notes and editable transcript workspaces; test revision preservation, crash recovery, source-audio retention, Watch transfer acknowledgement and full-storage behavior.
- **Q20/Q36:** Anarlog sync omissions/default contradictions and Reflect conflict archives, backup coverage and unfinished audio segments.
- **Meeting evidence:** none of the new dossiers establishes Zoom/Meet active-speaker extraction merely from speaker labels or Accessibility permission. Target a named unresolved mechanism and pinned build before further REA work.

Just Press Record remains the specialist Watch reserve; Meetily, Tana Outliner and Krisp are reserves for deeper OSS meeting, structured knowledge and audio-routing studies respectively. They were screened, not given full dossiers in this five-app expansion.

The [workflow study](workflow-composition.md) now makes Tuna/Raycast and iOS composition explicit. P-F58–P-F62 explore real output-to-input chaining and resuming failed steps. Exact adapters, an in-app workflow builder and cross-device recipe portability remain open.
