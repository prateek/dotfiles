---
status: draft
doc_type: research
summary: "Ledger of Prateek's explicit requirements U01–U33 with provenance, derived candidates to validate, and decisions still open."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Discovery record. Explicit requests are captured; derived ideas and unresolved choices are not approved implementation requirements."
---

# Voice OSS: requirements and intent

This is the requirement ledger for an unnamed open-source voice product. `voice-oss` is the working research label, not a selected product name. Read the [research index](README.md) for competitor evidence and the [candidate journeys](candidate-journeys.md) for questions these requirements create.

## What Prateek actually asked for

The authoritative input is the 2026-10-12 conversation:

> we want to create an oss project that takes the best of granola, mmonologue, wisprflow, ghostpepper, voiceink. -- we want ios/mac/watch apps, cli+mcp, integration with local models or remote, incredible ux and truly mac-assed. worthy of an apple design award! aimed at self-hosted - be it locally or on popular providers like exe.dev/… or unraid/…. help document all the user flows from all the apps i mentioned. and all my requirements. we’re trying to just capture all the info we can

Prateek subsequently confirmed Monologue by Every and [matthartman/ghost-pepper](https://github.com/matthartman/ghost-pepper).

A second requirement statement on the same date adds:

> def want custom keyboards in ios, 2nd brain style notes/layout. ability to make calls from ios app which are transcribed; very composable tool (beyond cli, mcp -- we want hooks, xdg based dotfiles, etc) ;; never any data loss, we always retain history on device for reprocessing as needed; icloud integration (optional) for sync;

Prateek then clarified the call destination as **“Ordinary phone numbers”** (`USER-2026-10-12-03`).

A later statement makes workflow composition explicit (`USER-2026-10-12-04`):

> we want to be able to chain actions and compose workflows on osx using tuna/raycast/etc; similarly on ios too

These statements are user requirements, not conclusions drawn from competitor features. The second statement settles keyboard support, on-device retention, and optional iCloud support; their implementation remains open.

| ID | Explicit requirement | Meaning retained for discovery | Decision still open |
| --- | --- | --- | --- |
| U01 | Create an OSS project. | Open-source product is the intended outcome. | Project name, repository, license, governance, contributor process, and distribution funding. |
| U02 | Take the best of Granola. | Include its meeting, notes, recall, and other documented workflows in the reference set. | Which behaviors to adopt, adapt, or omit. |
| U03 | Take the best of Monologue by Every. | Include the confirmed product's dictation, notes, and broader workflows. | Which parts define the desired experience. |
| U04 | Take the best of Wispr Flow. | Include its current documented surface, beyond historical dictation positioning. | Which features are essential versus inspiration. |
| U05 | Take the best of Ghost Pepper. | Use the confirmed upstream project as a reference. | Behavioral inspiration versus permitted source reuse. |
| U06 | Take the best of VoiceInk. | Include local/cloud dictation, customization, and its current supported platforms. | Behavioral inspiration versus permitted source reuse. |
| U07 | iOS app. | A deliberate iPhone experience belongs in the product vision. | iPad, minimum OS, keyboard mechanism (support is required by U23), offline scope, and launch order. |
| U08 | Mac app. | macOS is a first-class product surface. | Minimum OS, Intel support, distribution, and framework choices. |
| U09 | Watch app. | watchOS is explicitly requested. | Independent Watch operation, phone dependency, offline processing, and supported hardware. |
| U10 | CLI. | Terminal and scripted access are product requirements. | Supported OSes, commands, output contracts, package distribution, and authentication. |
| U11 | MCP. | Agents must have an intentional integration surface. | Read/write operations, scopes, transports, job model, and client support. |
| U12 | Local models. | The product must integrate with local inference. | Which stages and which devices run locally; model families and hardware minimums. |
| U13 | Remote models. | Remote inference is also part of the vision. | User-hosted endpoints, commercial APIs, credentials, protocols, and routing policy. |
| U14 | Self-hosted orientation. | Self-hosting is an intended audience and deployment mode. | Single user, household, team, or all three; optional managed service. |
| U15 | Run locally. | A local deployment must be considered. | Standalone device, localhost service, LAN server, or multiple supported arrangements. |
| U16 | Popular hosting providers, such as exe.dev. | Investigate deployment beyond the user's own hardware. | Exact provider support matrix; exe.dev is a named example, not a proven target. |
| U17 | Unraid and similar home-server environments. | Home-server operation belongs in the deployment research. | Distribution format, application template, GPU support, upgrades, and storage conventions. |
| U18 | Incredible UX. | Quality of the experience is a central product goal. | Measurable usability, reliability, responsiveness, and accessibility criteria. |
| U19 | “Truly mac-assed.” | Preserve the user's phrase: a product that feels deeply at home on the Mac. | Specific native interactions and technical implementation; do not reduce this to visual styling. |
| U20 | Worthy of an Apple Design Award. | Record this as an ambition for craft and experience. | Evaluation criteria and quality process; no award outcome is promised. |
| U21 | Document all flows from the five products. | Seek broad coverage, including setup, recovery, administration, and secondary journeys. | Account-gated, device-only, and undocumented behavior requires further observation. |
| U22 | Capture all requirements and as much information as possible now. | This phase builds a reusable evidence corpus and question backlog. | No implementation scope, MVP, architecture, schedule, or feature priority has been chosen. |
| U23 | Custom keyboards on iOS. | Ship custom keyboard support as a deliberate product surface. Users may choose whether to enable it. | Capture/handoff mechanism, extension limits, supported fields/apps, full-access behavior, and review feasibility. |
| U24 | Second-brain-style notes and layout. | Notes form a lasting personal knowledge workspace with intentional organization and reading/editing layouts. | Navigation, links/backlinks, daily/project/person views, graph/canvas, editor format, and migration. These examples are candidates. |
| U25 | Call ordinary phone numbers from the iOS app and transcribe them. | Initiate outgoing calls to the public telephone network (PSTN) within the product and retain a useful transcript linked to the call. | Media path, provider, caller identity, two-sided capture, live versus post-call transcript, and region support. |
| U26 | A highly composable tool beyond CLI and MCP. | Core work should participate in user-authored workflows through documented interfaces. | Event/API/pipe/file contracts, permissions, platform availability, and compatibility policy. |
| U27 | Hooks. | User-configurable hooks are an explicit integration requirement. | Events, payloads, execution location, read/write authority, failure handling, retries, and replay. |
| U28 | XDG-based dotfiles. | Support portable, inspectable configuration with XDG directory conventions where applicable. | App namespace, text format, precedence, GUI/CLI reconciliation, secrets references, and sandboxed-platform mapping. |
| U29 | “Never any data loss.” | Treat preservation of captured and authored work as a product invariant to design and validate. | Durability boundary, crash/power-loss coverage, storage exhaustion, corruption, device loss, recovery copies, and deliberate permanent deletion. This is a requirement, not a verified absolute guarantee. |
| U30 | Always retain history on device for reprocessing. | Retain the original material needed for reprocessing and prior results on the capturing device. Successful inference, upload, insertion, or sync must not silently evict it. | Exact history contents, encryption, capacity planning, per-device replication scope, and user-directed deletion. |
| U31 | Optional iCloud integration for sync. | Provide iCloud sync that users can opt into; local use and self-hosting remain available without it. | Sync mechanism, artifact selection, conflicts, account changes, self-hosted coexistence, and key handling. |
| U32 | Chain actions and compose workflows on macOS through Tuna, Raycast and similar tools. | Product operations must accept inputs and pass useful results into subsequent steps in user-authored workflows. Tuna and Raycast are named integration targets. | Exact actions, adapter packaging, typed results, completion contracts, permissions, and additional launchers. |
| U33 | Support equivalent action chaining and workflow composition on iOS. | People must be able to combine product actions with other apps and automation on iOS. | Shortcuts/App Intents, Share Sheet and URL handoffs are candidate mechanisms; execution, foreground, lock-state and long-job behavior need qualification. |

U01–U22 have provenance `USER-2026-10-12-01`; U23–U31 have provenance `USER-2026-10-12-02`, with U25 clarified by `USER-2026-10-12-03`. U32–U33 have provenance `USER-2026-10-12-04` and make the action-chaining aspect of U26 explicit on both platforms. “Explicit” means the user stated the direction; it does not mean its engineering details are settled. [Product behavior and durability](product-behavior.md) and [workflow composition](workflow-composition.md) expand these directions into candidate behavior and evidence questions.

## Interpretations to validate

These are useful implications to investigate, not additional user commitments.

| ID | Derived candidate | Why it follows | What would establish the requirement |
| --- | --- | --- | --- |
| D01 | Distinguish capture, transcription, rewriting, summarization, indexing, and storage destinations. | A single “local” switch can conceal remote processing in another stage. | Agree which stages must support which execution locations. |
| D02 | Let people understand a result's source and transformation history. | Meeting recall and AI cleanup can change meaning or add unsupported conclusions. | Decide provenance, comparison, correction, and source-link behavior. |
| D03 | Promoted to explicit requirements U29–U30: preserve work and retain on-device history. | The follow-up makes durability and reprocessing requirements. | Explore persistence, versioning, recovery, capacity, and deliberate deletion; retention itself is settled. |
| D04 | Make capture state unmistakable and controllable. | A polished voice tool must communicate when it is listening, paused, working, or finished. | Validate visual, audible, and haptic feedback with people in real contexts. |
| D05 | Make cloud use an explicit routing decision. | Local/self-hosted positioning creates expectations about data movement. | Decide what may leave each device and whether any automatic fallback is allowed. |
| D06 | Offer coherent data portability. | OSS and self-hosting make migration, inspection, backup, and recovery important. | Select export/import formats and prove complete round trips. |
| D07 | Treat accessibility as part of ordinary use. | Exceptional native UX must include more than a visual mockup. | Agree VoiceOver, keyboard, motor, hearing, text-size, contrast, and reduced-motion coverage. |
| D08 | Give apps, CLI, MCP, and hooks coherent access to the same underlying work (U26–U28). | Separate product surfaces should not create incompatible copies of notes or jobs. | Define operation semantics, identities, scopes, and result contracts. |
| D09 | Make self-hosting understandable to a non-specialist owner. | Great UX also applies to pairing, TLS, updates, model downloads, and restores. | Observe successful install-to-first-result and recovery journeys. |
| D10 | Support movement between devices without silently losing or duplicating work. | Mac, iPhone, and Watch create handoff and disconnected-use cases. | Support optional iCloud (U31); decide conflict handling, device identities, replication scope, and ownership. |
| D11 | Keep human control over publication and consequential automation. | Competitor flows extend from capturing words to sending messages and changing external records. | Select which operations exist and how review, confirmation, undo, and audit work. |
| D12 | Preserve a coherent product rather than accumulating every competitor option. | “Best of” requires evaluation of the complete experience. | Compare alternatives through task completion and user research; do not select winners from feature counts. |

## Product dimensions that must remain separate

**Open source, local inference, offline use, and self-hosting are different properties.** Source availability says nothing by itself about what happens to audio. A Mac can call a local model but store results remotely. A self-hosted server can still send inference requests to a commercial provider. An offline Watch can capture without being capable of offline transcription. The research must record these differences for each flow.

**Native experience is not a framework selection.** AppKit, SwiftUI, shared business logic, embedded web content, and backend languages remain undecided. Research should specify the interaction to evaluate: focus behavior, menu commands, keyboard shortcuts, window restoration, editing, text insertion, sharing, and accessibility. A framework name alone does not establish quality.

**Cross-platform does not imply identical screens.** A Mac dictation shortcut, an iPhone keyboard session, and a Watch capture action can contribute to the same user goal through different platform mechanisms. A Watch should not inherit a desktop settings interface simply because the features share data.

**“Remote” has at least two meanings here.** Inference can run on the user's own LAN/VPS or at a third-party model API. Hosting the application, storing its data, and running its models need separate answers. Provider selection cannot stand in for a complete deployment design.

## Quality ambitions to turn into observable evidence

The following are evaluation dimensions, with no invented latency or accuracy thresholds yet:

- Capture affordance is discoverable; a person can tell which microphone is active and stop immediately.
- Short dictation preserves intent, names, punctuation, and self-corrections; edits remain understandable.
- Insertion behaves predictably when focus changes, the destination rejects text, or accessibility permission disappears.
- Meeting notes preserve the distinction between what someone said, what the user wrote, and what a model inferred.
- Loading, first-model download, no-network, no-space, and provider-failure states are useful parts of the product.
- Apple-platform conventions, accessibility, and human-scale information hierarchy survive across the whole journey.
- A user can discover the destination and retention of their audio, transcript, context, and generated results.
- A self-hosting operator can diagnose and recover a failure without exposing secrets or losing recordings.

The [Apple platform study](apple-platforms-and-ux.md) grounds native interaction questions in platform documentation. The [hosting study](self-hosting-and-models.md) grounds operator questions in supported deployment mechanisms. These are discovery inputs, not an adopted technical specification.

## Not yet decided

No product name, fork strategy, source reuse policy, license, business model, primary persona, team model, default provider, deployment architecture, minimum hardware, accuracy benchmark, latency budget, permanent-deletion semantics, model redistribution policy, implementation roadmap, or release order is approved. Windows/Android/web administration may appear in competitor research; that does not add them to the user's requested client platform list.

On-device history retention, custom keyboard support, second-brain notes, transcribed outgoing iOS calls, hooks, XDG configuration, optional iCloud sync, and action chaining on macOS/iOS are explicit directions. Tuna and Raycast are named Mac integrations. Exact interaction and implementation choices remain open.

The next capture pass should preserve additional user statements as new U entries or explicit revisions, link them to the relevant journeys, and leave older decisions traceable. See [open questions and observation work](open-questions.md).
