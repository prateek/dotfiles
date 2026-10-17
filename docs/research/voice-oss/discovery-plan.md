---
status: active
doc_type: plan
summary: "Scope, completed passes and boundary of the Voice OSS discovery initiative; implementation and architecture remain unselected."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Ongoing discovery; the first public-source capture is complete. Implementation and architecture are unselected."
related:
  - README.md
  - requirements.md
---

# Voice OSS discovery plan

Capture a transferable research corpus for an unnamed OSS voice product inspired by Granola, Monologue by Every, Wispr Flow, Ghost Pepper, and VoiceInk. Preserve the explicit goals for Mac, iOS, Watch, CLI, MCP, local and remote models, self-hosting, and exceptional native UX.

The [research index](README.md) is the entry point. The [requirements ledger](requirements.md) owns user intent; product dossiers own competitor facts. This is a discovery initiative in the dotfiles worktree, not implementation of the eventual application inside dotfiles.

## Capture work

1. Resolve product identities and record the user's actual requirements.
2. Inventory each product's public flows, surfaces, platform and version limitations, and important error/recovery paths. Preserve source links and explicit evidence levels.
3. Research native Apple constraints and operator/model/deployment journeys using first-party documentation.
4. Assemble a searchable flow catalogue, cross-product comparison, source registry, and unresolved questions.
5. Check link integrity, evidence references, lifecycle metadata, and whether a fresh reader can distinguish requirements, observations, inferences, and proposals.

## Completion boundary for this pass

The first pass was completed on 2026-10-12: five product dossiers, 22 explicit requirements, 188 flow records, 251 source URLs, platform/hosting studies, and a searchable catalogue. Record consistency, local links, documentation lifecycle, catalogue DOM behavior, and independent reader review were checked. Further device observation and product decisions remain in the [question backlog](open-questions.md).

The same-day follow-up records nine additional explicit requirements (31 total), thirteen more candidate journeys (57 total), and five further sources (256 total). It covers required keyboards, second-brain notes/layout, transcribed outbound calls, hooks/XDG, retained local history, and optional iCloud. The [behavior study](product-behavior.md) preserves concrete recovery and integration questions.

The pass is complete when all five confirmed products have evidence-backed dossiers; every explicit user requirement has an identifier; native and self-hosting questions are captured; machine-readable flow/source records resolve; and the limitations and next observation work are explicit. Public-document coverage is not proof that every live screen, account tier, or failure state has been inspected.

No architecture, MVP, implementation schedule, infrastructure deployment, app-account access, or automated app recording is part of this discovery pass. No ADR is needed until an architectural decision is actually proposed. Related tool setup is environment preparation, not evidence that any target product has been observed.

## Zoom / Meet implementation follow-up

The user requested REA investigation of the reference apps' meeting integrations and active-speaker detection. The [integration study](meeting-integrations.md) separates meeting detection, capture, participant rosters, active-speaker observations, acoustic diarization and real-name resolution. Shipped package/static native evidence supplements pinned OSS source and official platform documentation. The integration registry is separate from the original 188-flow catalogue. Its closure table records answered mechanisms, partial paths and runtime questions. No target execution or live call was performed; no product architecture was selected.

## Additional reference apps

The user subsequently requested five strong apps not in the original set. The [selection study](additional-apps.md) screens sixteen candidates and selects Superwhisper, MacWhisper, Anarlog, Reflect Open and Fireflies for distinct relevance to the existing brief. Five new dossiers add 140 flows and 178 source URLs including selection/context, for 328 flows and 434 URLs across ten products. The original records and 31 explicit requirements remain intact. This pass uses primary documentation and pinned public source, with release/edition boundaries; it does not rank measured accuracy or extend binary/REA analysis to the new apps.

## Workflow composition follow-up

The user explicitly adds action chaining through Tuna/Raycast and similar Mac tools, and equivalent composition on iOS. U32–U33 preserve that intent; the [workflow study](workflow-composition.md) records sourced integration surfaces and proposed input/output, job and recovery behavior. Five proposed journeys and nine sources bring the current totals to 33 requirements, 62 proposed journeys and 443 source URLs. The 328 competitor flows are unchanged. No workflow runner, adapter or platform integration is implemented.
