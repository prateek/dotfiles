---
status: draft
doc_type: research
summary: "Cross-product map of overlapping experiences, meaningful distinctions and conflicting claims across the ten reference products."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence-linked comparison and candidate lessons; no feature ranking or implementation selection."
---

# Cross-product map

“Take the best” should be tested against complete user tasks. Feature counts cannot establish which experience is better. This map links the [ten dossiers](README.md#product-dossiers) and [328 flow records](data/flows.csv), highlighting behaviors worth comparing and uncertainties worth retaining. The original five appear first; the additional references extend the comparison below.

## Experience families

| Family | Evidence to compare | Question for the new product |
| --- | --- | --- |
| In-place dictation | Monologue MO-F03–MO-F11; Wispr WF-F03–WF-F16; Ghost Pepper GP-F04–GP-F10; VoiceInk VI-F06–VI-F20. | How can capture, intentional cleanup, insertion, correction, and recovery feel like one reliable action? |
| Meeting capture with human notes | Granola GR-F03–GR-F17; Monologue MO-F16–MO-F19; Wispr WF-F32–WF-F36; Ghost Pepper GP-F11–GP-F18. | How do human notes steer generated results while the transcript remains inspectable? |
| Personal voice notes and drafts | Monologue MO-F16–MO-F21/MO-F27; Wispr WF-F20–WF-F21; Ghost Pepper GP-F16–GP-F18; mobile Granola GR-F41–GR-F44. | Is capture destined for the current text field, a durable note, or both, and how does the user know? |
| Vocabulary and personalization | Granola GR-F16–GR-F17; Monologue MO-F06–MO-F09; Wispr WF-F06–WF-F13; Ghost Pepper GP-F06; VoiceInk VI-F09–VI-F18. | Which context improves output, who chooses it, and how are rules, learned corrections, and privacy explained? |
| Recovery and lifecycle | Granola GR-F45–GR-F55; Monologue MO-F10/MO-F17; Wispr WF-F05/WF-F14/WF-F23–WF-F25/WF-F40; Ghost Pepper GP-F09–GP-F10; VoiceInk VI-F19–VI-F20/VI-F25/VI-F29. | What remains recoverable after interruption, failed insertion, failed processing, sign-out, retention expiry, or deletion? |
| Recall and trust | Granola GR-F12/GR-F18–GR-F24; Monologue MO-F18–MO-F25; Wispr WF-F34/WF-F37; Ghost Pepper GP-F17/GP-F21–GP-F22. | Can the person inspect sources, distinguish inference, scope a query, and correct a mistaken conclusion? |
| Sharing and connected actions | Granola GR-F22–GR-F40; Monologue MO-F21–MO-F26; Wispr WF-F26/WF-F32/WF-F35/WF-F37. | How do sharing and mutation stay intentional, revocable, and separate from personal capture? |
| Mobile and Watch | Granola GR-F41–GR-F44; Monologue MO-F12–MO-F15/MO-F27; Wispr WF-F17–WF-F20/WF-F39; VoiceInk VI-F27–VI-F28. | Which tasks belong on each device, and what happens while the network, phone, or app session is unavailable? |
| Automation and model control | Granola GR-F39–GR-F40; Monologue MO-F22–MO-F26; Wispr WF-F37; VoiceInk VI-F03–VI-F05/VI-F23–VI-F26; Ghost Pepper GP-F07/GP-F24/GP-F26. | Can local, remote, CLI, and agent use share coherent outcomes without assuming identical permissions or API coverage? |

The ranges above are navigation aids, not proof of parity. Exact platform, entitlement, release, and unknown-state details are in each record. Absence from a family does not establish that a product lacks that capability.

## Distinctive patterns worth evaluating

**Granola: raw notes as a signal, evidence as a follow-up.** Its documented workflow combines the user's notes and the meeting transcript, then exposes ways to inspect supporting material and query collections. Templates, recipes, sharing, and connected actions extend the lifecycle after capture. Candidate lesson: assess the entire path from attention during the meeting to trustworthy reuse afterward. [Granola dossier, GR-F08/GR-F12/GR-F14/GR-F18–GR-F23](products/granola.md)

**Monologue: one voice entry point with several destinations.** The docs cover app-aware dictation, long Notes, cross-device availability, and read-only developer access. Local raw transcription and online smart formatting have different processing boundaries. Candidate lesson: explore coherent movement from ephemeral dictation to durable knowledge without hiding which mode or processor is active. [Monologue dossier, MO-F05/MO-F06/MO-F16–MO-F27](products/monologue.md)

**Wispr Flow: context and correction around a ubiquitous shortcut.** Its documentation describes style categories, dictionary/snippets, adjustable cleanup, original-text recovery, and newer meeting/notes workflows. Several capabilities are beta, entitlement-specific, or organizationally controlled. Candidate lesson: compare the benefits of automatic adaptation with the user's ability to predict, inspect, and reverse it. [Wispr dossier, WF-F06–WF-F16/WF-F20–WF-F23/WF-F32–WF-F40](products/wispr-flow.md)

**Ghost Pepper: local capture and useful files.** Public project evidence joins dictation with meeting capture and local Markdown use. Source-derived findings at v2.4.4 clarify several differences from the website and historical release notes. Candidate lesson: examine whether a locally owned library and open files simplify everyday use as well as interoperability. [Ghost Pepper dossier, GP-F04–GP-F07/GP-F13–GP-F24](products/ghost-pepper.md)

**VoiceInk: explicit processing and workflow customization.** Its docs distinguish transcription from enhancement, expose local/cloud/custom endpoint choices, and describe Modes, context profiles, local command routes, and history recovery. Candidate lesson: investigate how much configurability can be made understandable without becoming a prerequisite to a good first dictation. [VoiceInk dossier, VI-F03–VI-F05/VI-F09–VI-F14/VI-F19/VI-F23–VI-F26](products/voiceink.md)

These are research hypotheses about useful patterns. No product was benchmarked, no UX winner was selected, and none of these passages recommends copying branding, screens, or proprietary implementation.

## Five additional reference patterns

The [selection study](additional-apps.md) explains why these five complement the original set. All lessons are proposals; their linked dossiers qualify platform, version, release status and evidence.

| Reference | Flows to compare | Contribution and limit |
| --- | --- | --- |
| [Superwhisper](products/superwhisper.md) | SW-F01–SW-F30 | Configurable capture and processing, history and agent interfaces. Local speech, local text processing, configuration sync and retained recordings have distinct boundaries. |
| [MacWhisper](products/macwhisper.md) | MW-F01–MW-F30 | Transcript workbench, import/export, correction and automation. CLI persistence is opt-in; direct and store editions differ. |
| [Anarlog](products/anarlog.md) | AN-F01–AN-F25 | OSS meeting notebook with independent providers and local agents. Sync omits some data; re-transcription replaces current text; mobile/Watch maturity is qualified. |
| [Reflect Open](products/reflect-open.md) | RF-F01–RF-F25 | Voice into daily/linked Markdown notes, optional iCloud and files/CLI. Cloud voice processing remains separate from local notes or chat endpoints. |
| [Fireflies](products/fireflies.md) | FF-F01–FF-F30 | Meeting-to-action breadth and MCP in both directions. Desktop no-bot capture discards media; private storage does not self-host processing. |

Across these references, retain the distinction between original recording, corrected transcript, speaker identity map and generated notes. A History screen, reprocess button or cloud-storage option does not establish immutable history or lossless recovery.

## Keep contradictory evidence visible

| Product/area | Evidence conflict or qualification | Consequence for further research |
| --- | --- | --- |
| Granola workspace/template behavior | Different official pages disagree on mobile workspace switching and during-call template selection. | Observe a named app build/account before writing a definitive interaction specification. |
| Granola connected Chat | Broad Chat boundary language is narrower than focused connected Gmail/action guides. | Model ordinary note recall and explicitly connected external actions as separate evidence scopes. |
| Monologue processing | Local raw transcription is documented; smart formatting still uses an online service. | A “local model” claim must identify the stage, device, and remaining network dependencies. |
| Monologue integrations | Public Notes API is owner-only/read-only; MCP documentation includes shared Notes. | API and MCP access rules are not interchangeable. |
| Monologue UI labels | History/Home/Dictations and Mini/Dot descriptions differ across guide and changelog. | Use task names in the catalogue; exact labels need versioned observation. |
| Wispr mobile/context | Return-to-app behavior and context controls vary by platform and between pages. | Preserve separate mobile and desktop paths instead of deriving one generic flow. |
| Wispr retention | Training preference, cloud storage, local history, meeting storage, and Scratchpad have separate controls. | “Privacy mode” alone cannot describe data lifecycle or recovery availability. |
| Ghost Pepper local/cloud | v2.4.0 release notes describe cloud Q&A; v2.4.4 source describes local Q&A while optional cloud/legacy paths remain. | Pin both feature and backend claims to a version; do not reuse the old cloud claim as current fact. |
| Ghost Pepper shortcut/models | Website/README shortcuts differ from released defaults; main documents models absent from the inspected released catalog. | Main, public documentation, and the installed binary are distinct evidence sources. |
| VoiceInk platform requirements | Homepage, installation docs, README, appcast, and feature-specific iOS guidance have different minimums. | Establish the exact distributed build and feature-specific requirements. |
| VoiceInk Auto Learn | Appcast and current help disagree on local CLI eligibility. | Treat eligibility as unresolved until qualified at a specific version. |
| iOS keyboard strategy | Competitor instructions describe app handoffs; Apple platform/review documentation places restrictions on extensions. | Successful published competitors are precedent to investigate, not proof that an arbitrary implementation is permitted or supported. |

Each product row is sourced in its [dossier](README.md#product-dossiers); the keyboard row is grounded in the [Apple study](apple-platforms-and-ux.md). Contradictions are not silently resolved by choosing the newest-looking URL.

## What is not established by this comparison

No evidence here establishes equal accuracy, lossless interruption recovery, consistent click counts, independent Watch inference, unrestricted iOS background recording, self-hosting for the commercial products, or exact parity between public APIs and MCP. “Open source” does not establish permission to combine code under any chosen license. Read-only source inspection does not demonstrate the installed UX.

The proposed product adds an explicit self-hosted, multi-client ambition to this reference set. Its [operator/model journeys](self-hosting-and-models.md) and [62 candidate journeys](candidate-journeys.md) therefore include questions the competitor catalogue cannot answer. Their exact sequences remain proposed. Follow-ups explicitly require keyboard support, second-brain notes, transcribed outbound calls, hooks, XDG configuration, local history, optional iCloud sync, and Mac/iOS action chaining; see [product behavior and durability](product-behavior.md) and [workflow composition](workflow-composition.md).
