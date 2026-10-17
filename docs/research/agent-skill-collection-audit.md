---
status: active
doc_type: research
summary: "Remaining manual collection lists, native marketplace candidates, intentional subsets, and customized upstream copies."
created: 2026-10-12
updated: 2026-10-12
related:
  - ../references/agent-marketplace.md
  - ../adr/0049-official-agent-plugin-marketplaces.md
status_detail: "Audit retained with subsequent UI/UX, Crit, and Better Writing adoption recorded below; derivative and discovery recommendations remain open."
---

# Remaining agent skill collections

Two remaining adapters enumerate their complete upstream skill collection:
UI/UX Pro Max in `design` (seven skills) and Crit (three skills). Convert those
lists to collection payload imports. The existing patches can remain, and this
will let the adapters follow additions and removals in the upstream published
collection. UI/UX Pro Max also has an official Claude marketplace, but replacing
our patched adapter with its native plugin requires a decision about the local
icon fixes. Better Writing has an official marketplace too; its local adapter
currently enforces explicit invocation.

The audit phase changed documentation only. Subsequent adoption is recorded
below; the original findings describe the inputs inspected at audit time.

## Scope and evidence

Inspected all 15 local package selection files, all 21 locked dependency
entries from 20 maintainer repositories, and the current upstream Git trees and
available catalog/plugin manifests. The remaining local selections have 24
explicit skill rows and five whole-collection payloads. Also checked the 43
locally stored package skills and six repo-local maintenance skills for copied
upstream collection provenance.

GitHub API tree responses were complete (`truncated: false`). Branch heads were
resolved before reading metadata at those commit IDs. No repositories were
cloned. Snapshot JSON and comparison evidence are disposable files under
`agent-marketplace/build/collection-audit/`. A catalog establishes an install
candidate, not successful installation or equivalent behavior; no new native
installation tests were performed for this audit.

## Confirmed collection conversions

| Adapter | Current selection | Upstream evidence | Recommendation |
| --- | --- | --- | --- |
| UI/UX Pro Max in `design` | Seven `[[skills]]` rows equal all seven directories in the accepted `.apm/skills` collection. | The [plugin manifest](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/67803eac81/.claude-plugin/plugin.json) declares the entire `.claude/skills/` directory. Its [maintainer catalog](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/67803eac81/.claude-plugin/marketplace.json) offers `ui-ux-pro-max@ui-ux-pro-max-skill`. | Replace the seven rows with one collection payload. Retain the license payload, authored `devtool-ui` skill, and icon patches. A later native Claude switch should split the authored skill and address the patch difference. |
| Crit Codex adapter | Three `[[skills]]` rows equal all three directories in the accepted `.apm/skills` collection. | The [Claude catalog](https://github.com/tomasz-tomczyk/crit/blob/e48627e960/.claude-plugin/marketplace.json) points to the complete `integrations/claude-code` plugin. | Replace the three rows with one collection payload. Retain the hooks payload and existing patches. Claude already consumes the native upstream plugin. |

Both changes use the existing supported shape, with the dependency specific to
each adapter:

```toml
[[payloads]]
dependency = "<existing dependency>"
path = ".apm/skills"
target = "skills"
```

At the audited pins this changes selection policy without expanding the current
skill set. Validate the built payload comparison, patches, ownership, and native
version policy before applying either conversion. Future additions become part
of an accepted cache update, rather than requiring another manual list edit.

## Native plugin candidates and compatibility boundaries

Better Writing publishes [`better-writing@forjd`](https://github.com/forjd/better-writing/blob/8e45d0b241/.claude-plugin/marketplace.json).
Our `core` adapter applies paired explicit-only invocation controls, and the
local writing router uses that skill. Native installation is a candidate for
Claude/OMP/Pi, but removing the adapter from those clients must preserve the
chosen invocation behavior and avoid duplicate skill exposure. The upstream
plugin still contains one skill; this is a distribution improvement, not a
missing collection.

Crit and SwiftUI Expert have native Codex plugin manifests, but their inspected
repositories do not contain a Codex marketplace catalog. Crit's
[Codex plugin](https://github.com/tomasz-tomczyk/crit/blob/e48627e960/integrations/codex/plugin/crit/.codex-plugin/plugin.json)
also requests hooks, whereas the shared renderer currently suppresses Codex
hooks. A manifest alone does not establish a drop-in native marketplace
replacement. Keep this compatibility boundary explicit instead of treating
these projects as having no Codex plugin at all.

Apple HIG's old repository URL now resolves to
[`raintree-technology/hig-doctor`](https://github.com/raintree-technology/hig-doctor).
It remains maintainer-owned. Its separate `plugin/` Codex manifest describes
HIG Doctor with an audit skill and MCP server; the existing adapter imports the
14-skill HIG corpus. Switching to that plugin would change the product surface,
not simply remove a manual list. The old URL can be canonicalized in a future
source refresh; it is not a third-party mirror.

## Why the other explicit imports remain selections

| Source | Audited shape | Disposition |
| --- | --- | --- |
| `199-biotechnologies/claude-deep-research-skill` | One root skill, no plugin catalog. | Keep the single-skill import. |
| `forjd/better-writing` | One skill plus an official Claude plugin. | Native candidate with the invocation-control exception above. |
| `Cygnusfear/claude-stuff` | 41 skill roots; only the writing skill is selected. No repository-wide native marketplace catalog. | Keep intentional writing-skill curation; importing all would add unrelated engineering workflows. |
| `wiseiodev/skills` | 12 skills; only `code-principles` is selected. No native marketplace catalog. | Keep curation. A full collection would add review, shipping, issue, and work-log workflows. |
| `openai/skills` | 44 skill files across curated/system directories; only `cli-creator` is selected here. | Keep the selected producer skill. This is OpenAI's own upstream repository; the directory name `.curated` does not make it a third-party aggregator. |
| `danshapiro/trycycle` | One entry skill with four nested subskills. | Already imported as a complete root tree: all five `SKILL.md` files occur in the built payload. Do not promote its implementation subskills into separate collection entries. |
| `AvdLee/SwiftUI-Agent-Skill` | Published plugin contains SwiftUI Expert. A second `.agents/skills/update-swiftui-apis` skill is repository maintenance tooling. | Keep the one published-skill adapter. Do not count the maintenance skill as a missing end-user skill. |
| `efremidze/swift-patterns-skill` | One published skill. | Keep the single-skill adapter; Claude already uses its native plugin. |
| `conorluddy/ios-simulator-skill` | One published skill. | Keep the single-skill adapter; Claude already uses its native plugin. |
| `hefgi/skills` | Three skills with separate Claude catalog entries; only Shortcut is selected. | Keep Shortcut selection. Ponder and Review Workflow are separate choices, not omitted members of the Shortcut plugin. |
| `openclaw/acpx` | One runtime skill under `skills/`; two additional skills under `.agents/skills/` serve repo development. | Keep the runtime skill, aliased to `acpx-cli`; no runtime collection is missing. |
| `stablyai/agent-slack` | One runtime skill. | Keep the single-skill import. |
| `stablyai/orca` | Eight runtime skill roots; two are selected. An unrelated resources plugin has its own manifest, without a shared skills catalog. | Treat the two selected workflows as curation. Do not replace them with the whole application repository or silently add the other integrations. |

These classifications were checked against each repository's current tree,
including root `plugin.json` files, client catalogs, and repo-maintenance skills.
Representative primary sources are the [Trycycle installation instructions](https://github.com/danshapiro/trycycle/blob/eb25b51411/README.md),
[SwiftUI plugin selection](https://github.com/AvdLee/SwiftUI-Agent-Skill/blob/204dba7c67/.claude-plugin/plugin.json),
[Shortcut marketplace](https://github.com/hefgi/skills/blob/d22289fff7/.claude-plugin/marketplace.json),
[WiseIO skill tree](https://github.com/wiseiodev/skills/tree/25fac09888),
[Cygnusfear skill tree](https://github.com/Cygnusfear/claude-stuff/tree/32efa59eb5/skills),
and [OpenAI producer repository](https://github.com/openai/skills/tree/49f948faa9).

## Collections already following upstream publication

Matt Pocock, Pstack, Kepano Obsidian, Obsidian Wiki, and Apple HIG already use
collection payloads. Their scope is the upstream published collection, which
can differ from every `SKILL.md` in the repository. For example, Matt's
[plugin manifest](https://github.com/mattpocock/skills/blob/49dd158d10/.claude-plugin/plugin.json)
publishes 27 skills, while its Git tree has 38 including in-progress and misc
skills. Those 11 extra files are not omissions from our manual list.

## Locally stored upstream derivatives

A separate provenance pass found three customized upstream copies stored as
local authored skills. They should have either declared upstream acquisition
with reviewed patches or an explicit intentional-derivative decision. Their
existence does not justify activating their maintainers' entire repositories.

| Local skill | Confirmed source and native collection status | Recommendation |
| --- | --- | --- |
| `core/doc-coauthoring` | Initial local commit `2380856c` is byte-identical to [Anthropic's original](https://github.com/anthropics/skills/blob/dbd4588f9e1033efb41dad4bef2f7947c8993d44/skills/doc-coauthoring/SKILL.md). The [official catalog](https://github.com/anthropics/skills/blob/dbd4588f9e1033efb41dad4bef2f7947c8993d44/.claude-plugin/marketplace.json) includes it in the 12-skill `example-skills` collection. | Preserve the substantial local rewrite as a patch or intentional derivative. Whole-collection adoption would add eleven other skills and change this workflow. |
| `experimental/find-skills` | Historical local copy in `0db6c051` closely matches [Vercel's maintainer skill](https://github.com/vercel-labs/skills/blob/13e4063a1cf913f5606d57d42ab83a86f5001e04/skills/find-skills/SKILL.md); no native catalog was found in that repository tree. | Declare the selected upstream skill or record the local rewrite. Its leaderboard/popularity and aggregator-first discovery instructions should follow the maintainer-first rule already used in `skills-searcher`. |
| `utils-human/markdown-converter` | Initial local copy in `02b83d3f` closely matches [steipete's original](https://github.com/steipete/agent-scripts/blob/bd47c356371b5f0d2cd0381cd3962bad8a9a8cf1/skills/markdown-converter/SKILL.md). The current maintainer has skills.sh group listings but no native catalog in the inspected tree. | Declare the selected upstream skill with patches for explicit invocation and the local workflow. Current upstream uses `markitdown[all]`; the local instructions use bare `markitdown`. Runtime effects of that drift were not tested. |

Anthropic's [official code-simplifier plugin](https://github.com/anthropics/claude-plugins-official/tree/f359d43b406057f1a8cdbc4ea93b827642c162e6/plugins/code-simplifier)
provides an agent, not the same skill interface. Focused historical comparison
found no copying evidence for the local code-simplifier skill. Keep it unless
choosing that different interface deliberately.

The local provenance pass used linked-source scans and focused Git history. It
found no further evidence of an entire upstream collection copied into the
other local directories, but this is not an exhaustive originality or license
audit. Unrecorded inspiration remains unknown.

## Recommended follow-up order

1. Convert the Crit and UI/UX adapters' complete manual lists to collection
   payloads, preserving patches and comparing resulting payloads.
2. Align `find-skills` discovery with the maintainer-first policy. Review the
   three undeclared customized derivatives for direct imports plus patches or
   explicit ownership decisions.
3. Evaluate native UI/UX and Better Writing installs only after deciding how to
   retain the icon fixes and explicit invocation controls. Check native versions,
   disabled defaults, and duplicate exposure before removing wrappers.
4. Keep single-skill and intentional subset selections. Do not import unrelated
   workflows or repository-maintenance skills solely to eliminate lists.

## Subsequent adoption

The user selected the three marketplace candidates: UI/UX Pro Max, Crit, and
Better Writing. The [completed follow-up](../plans/additional-upstream-agent-plugins-plan.md)
records the implementation and host verification. Claude/OMP/Pi use their
maintainers' catalogs; Codex retains split compatibility adapters. UI/UX and
Crit manual listings were converted to collection payloads. The writing router
now discovers Better Writing from the client catalog. Native installations use
upstream behavior; Codex retains the local icon and explicit-invocation patches.

Recommendations about the three customized derivatives, `find-skills` discovery,
and unrelated selected subsets were not implemented by that follow-up.
