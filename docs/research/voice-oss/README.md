---
status: draft
doc_type: research
summary: "Entry point for the Voice OSS discovery corpus: requirements, ten product dossiers, flow catalogue, studies, datasets, and evidence labels."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Public-source discovery plus static meeting-integration research. No competitor runtime walkthrough or product implementation has occurred."
---

# Voice OSS: discovery corpus

An unnamed open-source voice product inspired by **Granola, Monologue by Every, Wispr Flow, Ghost Pepper, and VoiceInk**. Prateek wants deliberate **Mac, iOS, and Watch apps; CLI and MCP; local and remote models; self-hosting locally, on providers such as exe.dev, and on Unraid; exceptional native UX worthy of an Apple Design Award**.

The follow-up requires **custom iOS keyboards, second-brain notes and layout, transcribed outgoing iOS calls to ordinary phone numbers, hooks, XDG dotfiles, preserved on-device history for reprocessing, and optional iCloud sync**.

Action chaining is also explicit: **compose workflows through Tuna, Raycast and similar tools on Mac, with equivalent composition on iOS**. The [workflow study](workflow-composition.md) covers proposed actions, useful outputs and recovery across steps.

The flow catalogue captures that intent and the reference products' public behavior as of **2026-10-12**. It contains **33 explicit requirements, 328 competitor flow records across 10 products, 443 distinct primary-source URLs, and 62 proposed product journeys**. Eight additional Apple-platform journeys and fourteen operator/model journeys explore platform and hosting questions. These categories are separate: a proposed sequence does not settle the implementation of a required capability, and a documented competitor flow is not a hands-on verification.

The [five additional reference apps](additional-apps.md)—Superwhisper, MacWhisper, Anarlog, Reflect Open and Fireflies—were selected from sixteen candidates for this brief. They extend the original five's 188 records with 140 more. This is a source-backed fit assessment, not a hands-on accuracy or UX ranking.

A separate [REA meeting-integration investigation](meeting-integrations.md) examines the original five's shipped Zoom/Meet speaker-attribution paths. It has its own version-pinned artifact and source registry; its static findings do not turn catalogue flows into runtime observations.

## Start here

| Document | What it answers |
| --- | --- |
| [Searchable flow catalogue](data/catalogue.html) | Browse all 328 competitor flows by product, evidence type, or text; follow original sources. Works as a local HTML file. |
| [Five additional reference apps](additional-apps.md) | Selection rationale, five analyses, eleven screened alternatives, and lessons for the brief. |
| [Requirements and intent](requirements.md) | What Prateek explicitly requested, what we inferred, and what is undecided. |
| [Zoom/Meet integration internals](meeting-integrations.md) | REA and pinned-source evidence for meeting detection, capture, active speakers, naming, and official platform alternatives. |
| [Product behavior and durability](product-behavior.md) | Keyboard, second-brain notes, transcribed calls, hooks/XDG, retained history, and optional iCloud; candidate acceptance criteria. |
| [Workflow composition](workflow-composition.md) | Tuna/Raycast on Mac, iOS action chaining, candidate action inputs/outputs, and continuation after failure. |
| [Cross-product map](comparison.md) | Which experiences overlap, which distinctions matter, and which claims conflict. |
| [Candidate product journeys](candidate-journeys.md) | Possible end-to-end journeys across clients, models, hosting, CLI, MCP, and hooks; exact sequences remain proposed. |
| [Apple platforms and native UX](apple-platforms-and-ux.md) | Native interaction opportunities, accessibility, keyboard/audio constraints, Watch, and design-quality questions. |
| [Self-hosting and models](self-hosting-and-models.md) | Local/VPS/Unraid topologies, model placement, pairing, updates, backup/restore, and automation. |
| [Open questions and observation work](open-questions.md) | Unresolved choices, account/device evidence still needed, and the next capture sheet. |

## Product dossiers

| Product | Flow IDs | Records | Sources | Scope of evidence |
| --- | --- | --- | --- | --- |
| [Granola](products/granola.md) | GR-F01–GR-F56 | 56 | 61 | Official help, platform/integration guides, privacy and lifecycle documentation. |
| [Monologue by Every](products/monologue.md) | MO-F01–MO-F34 | 34 | 46 | Official guides, public API, changelog, App Store and first-party launch material. |
| [Wispr Flow](products/wispr-flow.md) | WF-F01–WF-F41 | 41 | 41 | Official help covering dictation and newer notes/meeting/agent workflows; rollout caveats preserved. |
| [Ghost Pepper](products/ghost-pepper.md) | GP-F01–GP-F26 | 26 | 23 | Official public project material plus explicitly labelled, version-pinned OSS source inspection. |
| [VoiceInk](products/voiceink.md) | VI-F01–VI-F31 | 31 | 44 | Official product/help, public repository documentation, appcast and App Store. |
| [Superwhisper](products/superwhisper.md) | SW-F01–SW-F30 | 30 | 33 | Official documentation, release notes and iPhone listing; no new runtime or binary analysis. |
| [MacWhisper](products/macwhisper.md) | MW-F01–MW-F30 | 30 | 24 | Direct Mac, Mac App Store and iOS documentation, with edition/version differences retained. |
| [Anarlog](products/anarlog.md) | AN-F01–AN-F25 | 25 | 35 | Current docs and pinned community OSS source; Char, enterprise and mobile/Watch boundaries explicit. |
| [Reflect Open](products/reflect-open.md) | RF-F01–RF-F25 | 25 | 32 | Official docs, releases and pinned OSS source; distinct from Classic and source-to-release parity unverified. |
| [Fireflies](products/fireflies.md) | FF-F01–FF-F30 | 30 | 38 | Official capture, review, model, integration and developer docs; capture modes kept separate. |

An additional 36 sources support the Apple-platform and hosting studies, five support the first follow-up product directions, sixteen support the new reference selection/context, and nine support workflow composition. Product identities for Monologue by Every and `matthartman/ghost-pepper` were explicitly confirmed by Prateek. The additional five were selected through research; they are not newly asserted user requirements.

## Portable data

- [flows.csv](data/flows.csv): spreadsheet-ready records containing IDs, platform, evidence status, steps, outcome, gaps, source IDs, and URLs.
- [flows.json](data/flows.json): the same competitor inventory with source lists preserved as arrays.
- [sources.jsonl](data/sources.jsonl): one source record per line, with stable IDs, URL, access date, source kind, support summary, and limitations.
- [run-manifest.json](data/run-manifest.json): research scope, counts, methodology, and validation boundary.
- [expansion-manifest.json](data/expansion-manifest.json): sixteen-candidate selection, five additional products, pinned source revisions, and preserved original snapshot.

The Markdown studies live here; their portable datasets and catalogue live in [`data/`](data/). The files do not require the ignored local skill clones, scratch work, or machine-specific REA setup to be readable. The [discovery plan](discovery-plan.md) records the work boundary. No source code for the proposed product exists here.

## How to read the evidence

| Label | Meaning | What it does not prove |
| --- | --- | --- |
| DOCUMENTED | A first-party source describes the behavior. | That it works on a particular device, account tier, release channel, or current installed version. |
| MARKETING | A vendor advertises a capability or example. | Exact UI steps, measured quality, latency, reliability, or coverage of edge cases. |
| SOURCE-DERIVED | Public OSS implementation at the cited revision supports an interpretation. | That a distributed binary matches it or that the full flow works at runtime. |
| OBSERVED-STATIC | Shipped artifact bytes, inert code paths, or native disassembly support a finding. | Runtime reachability, account rollout, measured accuracy, or complete automated analysis. |
| INFERRED | A synthesis grounded in stated evidence. | A vendor commitment or an observed result. |
| UNKNOWN | Evidence is missing, incomplete, contradictory, or outside the inspection boundary. | That a feature is absent. |
| PROPOSED | A possible journey or design consideration for the new product. | User approval, implementation priority, architecture, or an existing competitor feature. |

Mixed evidence labels preserve uncertainty within a single flow. Detailed notes take precedence over the short catalogue label. Version and platform qualifiers remain attached to claims. No flow is labelled runtime-verified.

## What the first pass establishes

The reference set spans dictation into other apps; human-assisted meeting notes; voice-note capture; editing and transformation; personal vocabulary and application context; search and source-grounded recall; sharing and external actions; account/data lifecycle; and developer interfaces. The [cross-product map](comparison.md) points to the supporting flow IDs rather than treating the applications as five isolated feature lists.

Self-hosting, local inference, offline use, and open-source licensing are tracked independently. A native-feeling client and an understandable operator experience are both part of the intended quality inquiry. Interface parity, Watch independence, required keyboard/call mechanics, notes layout, sync coexistence, deployment support, and model choice remain questions to resolve.

## Validation of this capture

The initial 188-record capture passed JSON/CSV, source-reference, local-link and repository lifecycle checks. An independent reader reviewed its requirements coverage, evidence boundaries, and material claims from five official-source areas. One Apple-source attribution was clarified following that review. A fresh reader checked the follow-up directions, including ordinary-number calling and retained history; an older sentence that left retention defaults open was corrected. The expanded 328-record catalogue passes JSON/CSV and source-reference checks, preserves the original records, and its current form has 449 checked local links. A separate independent audit checked material claims for every new product and source-pin consistency, with no actionable findings. The workflow follow-up validates the two new requirements, five proposed journeys and nine sources while preserving all competitor records. The run and expansion manifests record the exact scope.

The catalogue passes JavaScript syntax and DOM checks for filtering, search, expansion, source links, reset, and empty results. Its rendered appearance has not been browser-reviewed. These checks validate the research artifacts; they do not validate any competitor's runtime behavior. The [run manifest](data/run-manifest.json) records the check scope and artifact hashes.

## Limits and continuation

This is a broad first public-source capture, not a claim that every user flow has been observed. No competitor account, private note, microphone session, payment, authenticated integration, or device UI was exercised. Public documentation can be stale, contradictory, gated, or ahead of a general release; those cases remain visible in the dossiers. No reliable click counts, accuracy scores, latency measurements, or subjective “best UX” ranking can be derived from this evidence alone.

The next useful additions are Prateek's examples of favorite/frustrating flows, authorized version-labelled walkthroughs, safe interruption/recovery observations, and focused feasibility probes for the mobile and hosting questions. New findings should extend the existing IDs and source records. The explicit product directions are recorded; architecture, implementation, prioritization, and the eventual standalone repository are later decisions.
