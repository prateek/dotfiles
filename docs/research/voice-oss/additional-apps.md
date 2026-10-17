---
status: draft
doc_type: research
summary: "Selection of Superwhisper, MacWhisper, Anarlog, Reflect Open and Fireflies from sixteen candidates, with analyses and screened alternatives."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Five additional reference apps selected for this project's requirements. Primary documentation and pinned source; no hands-on quality ranking."
related:
  - README.md
  - requirements.md
  - meeting-integrations.md
  - discovery-plan.md
---

# Five additional reference apps

**Superwhisper, MacWhisper, Anarlog, Reflect Open, and Fireflies** are the five strongest additions from this survey for the proposed OSS voice-and-knowledge product. They extend the original Granola, Monologue, Wispr Flow, Ghost Pepper, and VoiceInk set. This is a selection of the most useful products to study for the brief, not a measured ranking of transcription accuracy or an instruction to buy them.

The selection is dated **2026-10-12**. We screened sixteen candidates across dictation, transcription, meeting intelligence, and voice-enabled personal knowledge. Each selected app contributes a different part of the intended experience. Public documentation and version-pinned OSS source establish described or implemented paths; no account, app installation, live call, performance test, or private data was used. The original five's binary/REA evidence remains separately scoped in the [meeting-integration study](meeting-integrations.md).

## Why these five

Selection prioritized four things: relevance to the explicit Apple/voice/notes requirements; local ownership, reprocessing and interoperability; depth of publicly inspectable workflows; and additional learning beyond the existing reference set. Maturity and evidence quality are stated separately. A beta with a close data-ownership model can be worth studying without being the safest daily-driver recommendation. No arbitrary numerical score or vendor accuracy claim determines the shortlist.

| Additional app | Distinct reason to study it | Main question it helps answer | Important qualification |
| --- | --- | --- | --- |
| [Superwhisper](products/superwhisper.md) | Configurable dictation, iPhone keyboard, local history, and developer interfaces | How do modes, model choices, recovery and automation coexist around a fast capture loop? | Desktop/mobile behavior differs; local transcription does not imply every AI mode is offline. |
| [MacWhisper](products/macwhisper.md) | Transcript editing, imports, speaker correction and processing tools | What does a useful original-audio and reprocessing workbench look like? | Direct Mac, Mac App Store and iOS products have distinct capabilities/releases. |
| [Anarlog, formerly Hyprnote](products/anarlog.md) | The closest added OSS local meeting-notebook reference | How do human notes, model providers, local agents and optional remote services fit together? | Distinct from Char; community/enterprise, released/beta, sync and cloud API boundaries matter. |
| [Reflect Open](products/reflect-open.md) | Local Markdown second brain with voice capture, optional AI and file-based sync | How can captured speech become connected, user-owned notes that remain useful outside the app? | Distinct from Reflect Classic; code-supported features and beta/mobile availability need qualification. |
| [Fireflies](products/fireflies.md) | Broad meeting-to-action lifecycle and agent integrations in both directions | How do capture, live assistance, corrections, search and downstream tools form one workflow? | A cloud-service benchmark. Capture modes differ materially in media retention and speaker labels. |

The dossiers contain the source-linked screen inventories, flow records, evidence labels, failure/recovery questions and specific requirements comparisons. The [searchable catalogue](data/catalogue.html) includes the original and additional products together.

## What each adds to the product brief

### Superwhisper: modes and recoverable dictation

Its documentation exposes a short capture loop with distinct speech and language-model choices, modes, history, an iPhone keyboard, and a local CLI/MCP surface. That combination closely matches the desired configurable tool without reducing the product to a settings panel. The useful comparison is how a person returns to a recording, changes processing, and gets a different result. [History](https://superwhisper.com/docs/get-started/history), [CLI/MCP](https://superwhisper.com/docs/get-started/cli), [iOS](https://superwhisper.com/docs/get-started/ios)

The limits are equally useful. Speaker separation does not by itself establish meeting participant names or Zoom/Meet active-speaker extraction. Some speaker-labelled output remains in History rather than automatically feeding the meeting summary. Device-specific configuration and keyboard handoff friction need their own flows. [Speaker-separated meetings](https://superwhisper.com/docs/modes/speaker-separated-meetings), [full dossier](products/superwhisper.md)

**Proposed lesson:** make capture fast by default, then expose stage-specific models, context and reprocessing where the user needs them. Keep the original and each derived result distinguishable.

### MacWhisper: the transcript is an editable working document

MacWhisper adds a detailed transcript lifecycle: files and batches, audio-aligned text, speaker correction, summaries, structured export and a CLI that uses the running application. Local and remote provider choices are separate from storage and output policy. These are useful references for people who need to inspect and repair a transcript rather than accept a summary. [Product](https://www.macwhisper.com/), [speaker correction](https://docs.macwhisper.com/article/32-automatic-speaker-recognition-in-macwhisper), [CLI](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

Older meeting help and newer release notes describe different capabilities. The dossier keeps their versions and distribution channels attached instead of declaring the older remote-speaker limitation universal. The CLI's transient-result default also needs deliberate reconsideration for our retained-history requirement. [Version and mechanism analysis](products/macwhisper.md)

**Proposed lesson:** make timing, speakers, corrections, processing jobs and output versions first-class parts of the note experience; expose the same operations to scripts.

### Anarlog: a close OSS architecture and workflow reference

The current community repository is Anarlog, formerly Hyprnote. The older website leads to Char, a separate product direction. Anarlog documents local meeting notes, independent transcription/intelligence providers, local CLI/MCP access and optional remote facilities. That makes it especially useful for studying where a local application ends and a cloud or self-hosted service begins. [Repository](https://github.com/fastrepl/anarlog), [models](https://docs.anarlog.so/models-and-providers), [MCP](https://docs.anarlog.so/agents/mcp)

Several defaults and limits matter more than a feature checklist: saved audio has a retention policy; re-transcription can replace current text; desktop webhook delivery depends on the app running; encrypted sync and agent-readable cloud snapshots are different products. The dossier records contradictory setup/sync documentation and gated integrations. None is a guarantee of lossless recovery. [Data/privacy](https://docs.anarlog.so/data-and-privacy), [webhooks](https://docs.anarlog.so/reference/webhooks), [dossier](products/anarlog.md)

**Proposed lesson:** define local storage, model execution, sync, remote agent access and event delivery as separate capabilities with explicit health and recovery states.

### Reflect Open: speech becomes a file-based second brain

Reflect Open is a distinct rewrite from Reflect Classic. The official site and repository describe local Markdown notes, daily capture, backlinks, user-selected sync and optional provider access. Audio memos become part of a graph the user can inspect and use with other tools. Its CLI and file model are particularly relevant to the requested dotfiles/hooks/composability direction. [Official site](https://reflect.app/), [repository](https://github.com/team-reflect/reflect-open)

Local note ownership does not make transcription local: the dossier separates supported chat endpoints from the narrower transcription-provider path. It also distinguishes retained completed audio segments and conflict archives from an absolute no-loss guarantee. Current source, release channels and mobile listing disagree in places, so availability is qualified. [Source-backed dossier](products/reflect-open.md)

**Proposed lesson:** make notes, attachments, audio and derived transcripts legible outside the GUI; provide backlinks and daily capture as views over owned data, with recovery states that the user can inspect.

### Fireflies: capture modes and connected actions

Fireflies adds a broader service workflow: meeting bots, desktop capture, live assistance, review, integrations, and both an MCP server for accessing meeting knowledge and a client path for invoking connected tools. It is a useful benchmark for what happens after the transcript exists. [Desktop guide](https://guide.fireflies.ai/articles/1208704416-getting-started-with-the-fireflies-desktop-app), [dossier](products/fireflies.md)

The capture-mode distinction is essential. Its desktop no-bot mode documents no saved audio/video and no named speaker labels; the bot path has different outputs. “Bot-free” therefore cannot stand in for local processing, retained originals, or identified speakers. The Chrome extension and mobile flows must also be assessed separately. [Capture-mode guide](https://guide.fireflies.ai/articles/7066927951-bot-vs-no-bot-which-capture-am-i-using)

**Proposed lesson:** make capture capabilities and retained outputs visible before recording, and make external actions reviewable with a durable record of what was requested and completed.

## Other candidates considered

These are screened alternatives, not additional full dossiers. Their inclusion makes the five-app selection reviewable. Unknowns describe this survey's evidence boundary, not proven absence.

| Candidate | Useful reference value | Why it did not displace the selected five |
| --- | --- | --- |
| [Meetily](https://github.com/Zackriya-Solutions/meetily) | Local meeting capture, local models and a distinct Pro developer surface. | Strongest alternate if OSS meeting coverage takes priority over breadth. Community and Pro differ; [developer interfaces](https://docs.meetily.ai/developers) must not be attributed wholesale to the MIT app. |
| [Handy](https://github.com/cjpais/Handy) | Small OSS offline dictation baseline. | Useful implementation simplicity, but overlaps the already deep VoiceInk/Superwhisper dictation coverage. |
| [Amical](https://amical.ai/) | Advertised open-source local/cloud dictation across several platforms. | Mobile/release parity, history and integration guarantees were less established in this bounded survey. |
| [Voibe](https://www.getvoibe.com/) | Offline desktop dictation and a separate meeting workflow. | Adds less new coverage; local dictation and cloud meeting processing require separate treatment. |
| [Krisp](https://help.krisp.ai/hc/en-us/articles/8214720684956-AI-Meeting-Assistant-overview) | Audio routing, noise reduction and capture controls. | Strongest reserve for an audio-quality/device-routing study. Fireflies adds more distinct downstream tool workflows to this set; no audio-quality comparison was performed. |
| [Otter](https://help.otter.ai/hc/en-us/articles/35973988280215-Otter-Desktop-App-Mac-Windows) | Broad meeting review, exports and hosted MCP. | Credible mainstream benchmark, with more overlap after Granola/Wispr/Fireflies. Local-model and self-hosted-server fit was not established. |
| [Fathom](https://help.fathom.video/en/articles/449088) | Capture policy, review and evolving bot-free/mobile flows. | Useful reserve; current rollout and platform limits need care. It contributes less distinct ownership/composability information than the selected set. |
| [Tana Outliner](https://outliner.tana.inc/learn/features/local-api-mcp) | Typed, connected knowledge and [voice-to-workflow patterns](https://outliner.tana.inc/learn/features/tana-meeting-notetaker), including [mobile memos](https://outliner.tana.inc/learn/features/mobile-voice-memos). | Strong second-brain reserve; Reflect Open is a closer file-ownership fit. Tana's current collaboration product and Outliner must not be conflated. |
| [Notion AI Meeting Notes](https://www.notion.com/help/ai-meeting-notes) | Meetings embedded in a block/database workspace. | Useful layout reference; its cloud/workspace emphasis adds less to the local-owned reference set than Reflect/Anarlog. |
| [Just Press Record](https://www.openplanetsoftware.com/just-press-record/) | Dedicated Watch capture, phone transfer, playback and optional iCloud storage. | Strongest specialist Watch reference. Narrower than the five selected combined voice/processing/knowledge tools; retain it for the Watch design phase. |
| [Aiko](https://sindresorhus.com/aiko) | Local Apple-device transcription, Shortcuts and clear export boundaries. | Strong small-tool reference, but less breadth than MacWhisper. Its own FAQ leaves live meetings and speaker identification unsupported. |

The Watch requirement remains explicit. Selecting these five does not establish that five mature Watch implementations exist, or that source code for a Watch target proves a distributed app is available.

## Cross-cutting design questions to carry forward

1. **Originals and revisions:** which actions overwrite a transcript, delete audio, expire conflict archives, or silently stop retaining evidence? Our explicit retained-history requirement needs a stronger contract than “there is a History screen.”
2. **Capture capability:** keep mic/system channels, participant names, acoustic speaker IDs and model output separate. Explain degraded capture without presenting guesses as names.
3. **Local versus hosted:** distinguish local files, local inference, custom model endpoints, a localhost automation API, optional sync, customer-owned cloud storage, and a self-hostable application service.
4. **Composable operation:** distinguish UI automation from a stable CLI/API, client-side hooks from durable webhooks, and an MCP server exposing our data from an MCP client able to change another system.
5. **Apple interaction:** study keyboard-first correction, unobtrusive capture, keyboard-extension handoffs, Share/Shortcuts entry points, and device-specific capture/recovery. These patterns still need hands-on usability and accessibility validation.
6. **Knowledge continuity:** manual notes, raw transcript, speaker corrections, linked notes and summaries should retain provenance as independently useful objects. Reprocessing should not erase the user's previous work.

These are proposed implications. This expansion preserved the then-current 31 explicit requirements and 57 candidate journeys; a later [workflow-composition follow-up](workflow-composition.md) brings the current ledgers to [33 requirements](requirements.md) and [62 journeys](candidate-journeys.md). This research does not choose an implementation stack, MVP, service provider or migration.

## Evidence boundary and continuation

This expansion added **140 flow records and 178 source URLs**: 162 sources for the five dossiers and 16 for selection/context. Its completion snapshot covered **10 products, 328 flows and 434 distinct source URLs**; the subsequent workflow study adds nine sources. The original 188 flow records and 256 source records are preserved; the separate static integration registry is outside these totals. The [expansion manifest](data/expansion-manifest.json) records selection, source pins and the original snapshot; the [research index](README.md) reports current totals.

Each flow records what the source supports, how the user reaches the outcome, and unresolved failure states. Version/release documentation can lead or lag packaged behavior; source-only findings do not prove binary equivalence. “Native Mac app” is not a measured UX score or proof of a particular UI framework. No unsupported click counts, latency measurements or accuracy rankings are supplied.

The next useful probes are controlled loss/recovery tests, actual keyboard handoffs, source-to-speaker alignment, transcript revision preservation, and authenticated automation boundaries. New artifact/REA work should start with a particular unresolved mechanism and a pinned build; this expansion does not claim the original five's native analysis was repeated for the new five.
