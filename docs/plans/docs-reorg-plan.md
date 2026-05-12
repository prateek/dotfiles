---
status: archived
doc_type: plan
owner: Prateek
created: 2026-05-11
updated: 2026-05-12
closed: 2026-05-12
current_guidance:
  - ../index.md
  - ../document-lifecycle.md
  - ../../AGENTS.md
  - ../../home/dot_agents/skills/code-gardening/SKILL.md
related:
  - ../document-lifecycle.md
  - ../index.md
  - ../research/self-improving-agents.md
  - ../../home/dot_agents/skills/code-gardening/SKILL.md
status_detail: "Implemented and retained for archaeology. Current docs routing lives in AGENTS.md, docs/index.md, and docs/document-lifecycle.md."
---

# Docs Reorg And Agent-Surface Refresh Plan

## Problem

This repo is primarily authored by LLM coding agents. The current docs surface
mostly works, but session-log forensics show concrete drift between what
`AGENTS.md` claims and how agents actually do the work:

- `docs/plans/` is mixed-class. It holds 4 archived plans, 1 active proposal,
  1 archived research doc, 1 current runbook (`tart-mini-validation.md`),
  and a standalone `.html` artifact. The folder name no longer matches its
  contents.
- Operator-facing references (`chezmoi-architecture.md`,
  `mise-tool-management.md`, `grmrepo.md`) sit at `docs/` root with no
  signaled boundary against routing files (`index.md`, `document-lifecycle.md`).
- `AGENTS.md` says `docs/plans/` is "plans and runbooks for repo changes",
  conflating two lifecycle classes by design.
- The single most-read doc in 423 sampled sessions is the now-deleted
  `docs/plans/chezmoi-migration-plan.md` (44 sessions). Agents read plan docs
  as if they were live specs because lifecycle status alone does not signal
  "this is a plan, not the system of record."
- `AGENTS.md` does not say what content each doc folder should hold, so agents
  place docs by analogy to whatever they last saw.
- 100% of sampled Claude Code sessions that edited `docs/**.md` skipped
  `make test-docs-lifecycle`. The validator exists but is not called out as
  mandatory.
- `home/dot_agents/skills/chezmoi-management/` arrived after about 85 chezmoi
  sessions had already paid the friction cost. There is no automated way to
  notice "this area churns and has no skill yet."
- Subagents inherit the full `AGENTS.md` as a synthetic first user message even
  when their actual task is a focused review. The big file becomes overhead.

## Goals

- Make folder names describe contents so agents place new docs correctly on
  first guess.
- Add explicit per-doc-type guidance in `AGENTS.md` so future agents do not
  re-derive it.
- Tighten lifecycle so a plan doc cannot keep serving as a live spec after
  implementation lands.
- Capture the durable lessons from current and recent sessions so they do not
  repeat.
- Keep `AGENTS.md` under 200 lines, scannable, and routing-shaped.
- Preserve everything the lifecycle validator already enforces.
- Keep the plan implementable as one coherent PR.

## Non-Goals

- Rewriting the existing ADR bodies. Bodies are locked once `accepted`.
- Adopting Quickwit's three-lens framework (ADR / gaps / deviations /
  supplements) at full scope. Lighter pieces only.
- Building a publish-to-website pipeline. Repo-local Markdown stays the surface.
- Mandating `AGENTS.md` files in every subdirectory. The repo is small enough
  that one root file plus skills is the right shape.
- Generating `AGENTS.md` from the codebase. Generated root instructions are an
  observed anti-pattern.

## Research That Drives This Plan

Nine research streams ran in parallel. The full reports live in the agent
transcripts under
`/private/tmp/claude-501/-Users-prateek--superset-worktrees-*/tasks/`.
Highlights that anchor the decisions below:

- **OpenAI / Ryan Lopopolo**: `AGENTS.md` is a table of contents, not an
  encyclopedia. The `docs/` tree is the system of record. Failures should
  produce lint/test/skill fixes, not another root-instruction bullet.
- **OpenAI Codex docs**: Codex reads layered `AGENTS.md` files before work.
  That makes root guidance powerful, but also costly when it turns into a
  wall of policy.
- **Ryan Lopopolo's public writing**: when agents write more code, the durable
  artifact is the repo-owned spec, guardrails, typed boundaries, proof surface,
  and operator workflow.
- **Anthropic guidance**: `CLAUDE.md` works best as short persistent project
  context. Long procedures belong in skills, commands, hooks, or docs.
- **GitHub corpus**: strong repos use root `AGENTS.md` as policy/router, scoped
  `AGENTS.md` only when the subtree needs it, and shared `.agents/skills`
  rather than duplicate branded skill trees.
- **Pattern from the wild**: Cloudflare's `workers-sdk/AGENTS.md` uses a
  `Task | Location` decision table. Zed's `.rules` includes a "Rules Hygiene"
  meta-section. Both apply here.
- **Vercel evals**: in their eval matrix, `AGENTS.md` outperformed
  per-procedure skills. The synthesis is not "avoid skills"; it is "use a
  short `AGENTS.md` for routing and skills for genuinely procedural workflows."
- **Quickwit**: internal docs separate stable decisions, gaps, deviations,
  supplements, formal specs, verification guidance, and scoped `CLAUDE.md`
  files. This repo should copy the separation of concerns, not the exact tree.
- **Diataxis / docs-as-code / ADR practice**: docs should be typed by purpose,
  stored in Git near the code, and validated in CI. Status answers whether to
  trust a doc; type answers how to use it.
- **Session forensics**: concrete recurring misses are source-of-truth drift,
  stale live pointers, old plans treated as current specs, compatibility-wrapper
  bias, skill-loader assumptions, and narrow validation.

## Target Structure

Use purpose-based directories under `docs/`:

```text
docs/
├── index.md
├── document-lifecycle.md
├── adr/
│   └── 0001..0006-*.md
├── plans/
│   ├── betterdisplay-*-plan.md
│   ├── chezmoi-agent-skills-plan.md
│   ├── setup-downstream-fork-plan.md
│   ├── setup-downstream-fork-secrets-plan.md
│   └── zsh-fresh-shell-validator-plan.md
├── references/
│   ├── chezmoi-architecture.md
│   ├── mise-tool-management.md
│   └── grmrepo.md
├── runbooks/
│   └── tart-mini-validation.md
└── research/
    └── agent-skill-management-research.md
```

Root `docs/` keeps routing infrastructure only: `index.md` and
`document-lifecycle.md`.

`docs/index.md` is the routing table. Agents should start there before treating
any doc as guidance.

`docs/adr/` contains decision records. Accepted ADRs explain why a decision was
made; they are not current operating manuals unless they point to current
guidance.

`docs/plans/` contains proposed, active, and historical initiatives. Plans
should not become steady-state references. When implementation finishes, move
durable guidance to `docs/references/`, `docs/runbooks/`, or a skill, then close
the plan as `archived` or `superseded`.

`docs/references/` contains current factual maps: architecture, source ownership,
tooling models, generated artifact ownership, and durable invariants.

`docs/runbooks/` contains current executable procedures: install validation,
release, audits, recovery, and other operator workflows.

`docs/research/` contains research docs. Maintained research can be `active`;
historical research should be `archived` with `current_guidance`.

`docs/plans/zsh-harness-comparison.html` moves out of the repo to
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/` to match the convention
for non-Markdown artifacts. If it must remain in the repo, it needs a sibling
Markdown index and an explicit validator exception.

## Lifecycle Rules

Keep the current lifecycle model from `docs/document-lifecycle.md`:

- `draft`
- `proposed`
- `accepted`
- `active`
- `current`
- `superseded`
- `rejected`
- `archived`

Recommended doc types:

- `adr`
- `plan`
- `runbook`
- `reference`
- `research`
- `convention`
- `index`

Status answers whether to trust a doc. Type answers how to use it.
`superseded_by` and `current_guidance` tell the reader where to go next.

The important invariant: `doc_type: plan` must never become `status: current`.
When a plan is implemented, write or update the current reference, runbook, or
skill and close the plan.

Default maintained steady-state docs to `active`. Keep `current` for routing
and convention docs unless `docs/document-lifecycle.md` later narrows the
state model further.

## Doc Folder Purposes

Add this short section to `AGENTS.md` immediately after Repo Map. The lifecycle
doc remains the canonical source for status semantics and validator rules.

```markdown
## Doc Folder Purposes

| Folder | Contents | `doc_type` | Typical status | Authority |
| --- | --- | --- | --- | --- |
| `docs/` | Routing infrastructure only | `index`, `convention` | `current` | Authoritative for how to navigate docs. |
| `docs/adr/` | Architectural decision records | `adr` | `accepted` once decided; body locked | Authoritative for why a decision was made. Never the live implementation manual. |
| `docs/plans/` | Proposed, active, and historical initiatives | `plan` | `proposed`, `accepted`, `active`, `superseded`, `archived` | Never authoritative for live behavior. |
| `docs/references/` | Steady-state operator references | `reference` | `active` | Authoritative for how live systems work. |
| `docs/runbooks/` | Executable operating procedures | `runbook` | `active` | Authoritative for repeatable procedures. |
| `docs/research/` | Research snapshots and maintained research | `research` | `active`, `archived`, `superseded` | Evidence and context, not current operating guidance unless status is `active`. |

Rules of thumb:

- If you wrote a `plan` and it is now implemented, do not flip it to
  `current`. Create or update a `reference`, `runbook`, or skill and set the
  plan to `superseded` or `archived`.
- New ADRs go in `docs/adr/<NNNN>-<slug>.md`. Never renumber.
- Operator references go in `docs/references/`, not `docs/` root.
- Repeatable procedures go in `docs/runbooks/` or a skill.
- Research goes in `docs/research/`; old research must point to
  `current_guidance`.
- Anything in `docs/plans/` is upcoming, active, or historical. If an agent
  treats a `plans/` doc as the live spec, it is reading the wrong doc.
- If you edit anything under `docs/`, run `make test-docs-lifecycle` before
  handoff.
```

This table is the load-bearing addition. Everything else in this plan supports
it.

## Agent Guidance Model

Root `AGENTS.md` should stay lean. It should answer:

- What kind of repo is this?
- Where are source state, generated state, and runtime projections?
- Which docs index should agents read first?
- Which commands validate common changes?
- Which surfaces must not be duplicated?

`CLAUDE.md` should remain an adapter symlink to `AGENTS.md`, not a second
instruction source.

Repo-local skills belong under `.agents/skills/`. Machine-wide managed skills
belong under `home/dot_agents/skills/` and materialize into the home directory.
Runtime paths such as `~/.agents/skills` are verification targets, not source
state for this repo.

Tool-specific folders should contain only adapter metadata:

```text
.claude/       # Claude-only agents, commands, settings, or symlinks
.codex/        # Codex-only agents, hooks, rules, or settings
.cursor/       # Cursor rules if AGENTS.md is insufficient
.windsurf/     # Windsurf rules/workflows if needed
```

Shared prose and repeatable workflows should not be copied into branded
folders.

## AGENTS.md Content Changes

Keep `AGENTS.md` under 200 lines. Current size: about 100 lines, so there is
room for the additions below.

Add or amend:

1. **Doc Folder Purposes table** above.
2. **Source Surface Overview table** under Repo Map. Three columns:
   surface -> owns -> detailed routing. This stays one layer above individual
   task recipes, so it does not grow every time a new workflow is documented.
   Draft:

   ```markdown
   ## Source Surface Overview

   Use this table to identify the owning surface before opening deeper docs or
   grepping. Detailed task routing belongs in focused references, runbooks, or
   skills.

   | Surface | Owns | Detailed routing |
   | --- | --- | --- |
   | `home/` | Chezmoi source state that materializes into `$HOME`. | [Chezmoi Architecture](docs/references/chezmoi-architecture.md). |
   | `home/.chezmoidata/` | Structured package, secret, license, and template inputs. | Package and secret docs plus `$chezmoi-management`. |
   | `home/.chezmoitemplates/` | Shared templates, Brewfile rendering, macOS defaults, and plist merge fragments. | [Chezmoi Architecture](docs/references/chezmoi-architecture.md) and `$chezmoi-management`. |
   | `home/.chezmoiscripts/` | Idempotent setup hooks run by `chezmoi apply`. | Runbooks and focused tests. |
   | `.agents/` | Repo-local agent surface for this checkout. | Repo-specific skills, adapters, and root `AGENTS.md` / `CLAUDE.md`. |
   | `home/dot_agents/` | Machine-wide agent surface materialized to `~/.agents`. | Shared skills, docs, and workflow conventions. |
   | `docs/` | Routing, decisions, plans, references, runbooks, research, and historical records. | [Docs Index](docs/index.md) and [Docs Lifecycle](docs/document-lifecycle.md). |
   | `scripts/` and `tests/` | Validation helpers, audits, renderers, and tests. | [Test Index](tests/README.md). |
   ```

   Keep task-specific lookup rules in docs or skills. `AGENTS.md` should name
   ownership boundaries, not every operation that can happen inside them.
3. **Mise gotcha** in Common Commands: "Never edit
   `home/.config/mise/config.toml`; add entries to `conf.d/*.toml`."
   Forensics shows this trap caught 6 subagent sessions before global
   `CLAUDE.md` documented it. Repo `AGENTS.md` should carry it too.
4. **Glossary stub** under Chezmoi And App Config. Five terms:
   `modify_` prefix, `chezmoiexternal`, `chezmoiignore`, `chezmoidata`,
   `chezmoiassets`. One sentence each, pointing at one canonical example per
   term.
5. **README-first guard.** Add to `AGENTS.md`: "If you read `README.md`, stop
   and read this file before continuing. `README.md` is a sub-1 minute
   human-facing intro and is not the source of truth for repo conventions." Add
   the inverse to `README.md`: "Coding agents: read `AGENTS.md` instead."
   Forensics: 40% of sessions that read both files hit README first.
6. **Validation rule for `docs/` edits.** Add: "If you edit anything under
   `docs/`, you must run `make test-docs-lifecycle` before handoff."
   Forensics: this was skipped in 5 of 5 sampled Claude Code sessions.
7. **Rules Hygiene meta-section** (Zed-derived). Three criteria for a new rule:
   non-obvious, repeatedly encountered, specific. Add a "no drive-by additions"
   line to anchor future LLM-authored maintenance against bloat.

Do not add architectural prose. The Quickwit lesson and Zed's `.rules` both
warn that architecture descriptions go stale and agents read the code anyway.
`AGENTS.md` rules are traps to avoid, not maps to follow.

## Lifecycle Validator Additions

Keep the lifecycle validator as one self-contained executable file under
`docs/`, for example `docs/validate-doc-lifecycle`. `tests/docs-lifecycle.zsh`
can exercise it, but validation logic should live in that one file.

The validator needs targeted additions:

1. **Forbid `(doc_type=plan AND status=current)`.** Already implied by
   `docs/document-lifecycle.md`'s Type Guidance table; not currently enforced.
   The migration-plan-as-live-spec failure is exactly this.
2. **Frontmatter key allowlist.** Fail on unknown keys. Both
   `setup-downstream-fork-*plan.md` files carry a non-canonical `skill_path:`
   field that drifted in silently. Enforce the keys named in
   `document-lifecycle.md`.
3. **Reject non-Markdown content files in `docs/`**. Allow the lifecycle
   validator itself as the one explicit non-Markdown tooling exception under
   `docs/`. Move captures such as `zsh-harness-comparison.html` out of the
   repo.
4. **Validate index coverage.** `docs/index.md` should list every maintained
   doc or intentionally exclude generated/non-current material.
5. **Validate successor links.** `superseded_by`, `current_guidance`, and
   repo-local `related` links should resolve.
6. **Validate moved-directory references.** After the rename, stale
   `docs/plans/` references should fail or warn.

Backfill `created` / `updated` on:

- `docs/references/grmrepo.md` (has `updated` only)
- `docs/references/mise-tool-management.md` (no dates)
- `docs/plans/betterdisplay-display-modes-plan.md` (has `created` only)

Remove the non-canonical `skill_path:` field from the two
`setup-downstream-fork-*plan.md` files. Use `current_guidance` instead.

## Skill Changes

### `code-gardening`

Update `home/dot_agents/skills/code-gardening/SKILL.md` with docs routing,
lifecycle-frontmatter, and index-maintenance behavior. It should point at the
repo's Doc Folder Purposes table rather than duplicating the taxonomy.

Add a one-paragraph pointer:

> When working in `docs/`, follow the folder purposes table in repo
> `AGENTS.md`. This skill does not duplicate folder rules; it points at them.
> The skill remains the place for ambient gardening conventions such as drift
> detection, frontmatter sync, and fixing small papercuts tied to the task.

Keep procedural guidance in `code-gardening`; keep policy and folder placement
rules in `AGENTS.md`.

### `chezmoi-management`

Make the repo-local `chezmoi-management` skill self-contained. Add a concise
bundled reference, such as
`.agents/skills/chezmoi-management/references/architecture.md`, distilled from
`docs/references/chezmoi-architecture.md`. The skill may link to repo docs for
broader context, but it should not require reading the docs tree before it can
guide a task.

Also update it with the live-path failures seen in history:

- ignored source-state files can still render through chezmoi;
- live symlinks and adapter paths need `readlink` / tree-level checks;
- branch smoke tests do not prove full `chezmoi init/apply/status`;
- plist work needs running-app guards;
- home-vs-repo source ownership must be checked before editing.

### Deferred Skill-Coverage Work

Move skill-coverage, subagent-context, and skill-firing analysis to
[Self-Improving Agents — Part 5](../research/self-improving-agents.md#part-5-open-questions-for-this-repos-harness).
This docs reorg should only preserve the failure pattern and route follow-up
work there.

## Historical Failure Guardrails

The session-history pass found recurring misses that the docs structure should
prevent.

**Source-of-truth drift**: agents read only live config or only repo config. The
docs must say which side owns each surface, and audit workflows must compare
both when behavior comes from both.

**Stale live pointers**: agents audited file diffs and missed directory-level
symlinks. Dotfiles audits need `readlink` and tree-level checks for
`~/.agents`, `~/.codex`, `~/.claude`, and shell startup paths.

**Historical docs treated as current**: agents used old plan bodies and ADRs as
operating manuals. Lifecycle frontmatter and `docs/index.md` must route readers
to current guidance.

**Compatibility-wrapper bias**: agents preserved old local wrappers even after
the desired system moved to native `chezmoi` or a new public command. Guidance
should distinguish deployed/shared interfaces from private, newly-created local
entry points.

**Skill loader assumptions**: agents guessed skill layout and parser behavior.
Skill changes need upstream tree inspection, nested `SKILL.md` checks,
frontmatter validation, and runtime discovery verification.

**Narrow validation**: agents trusted branch smoke tests when the real risk was
apply-time behavior. Dotfiles validation should include ignored source-state
files, direct `master...HEAD` parity where relevant, temp-home chezmoi
apply/status checks, and running-app guards for plist work.

## Migration Steps

Single PR. Estimated diff: about 20 files, mostly mechanical except the
`AGENTS.md` additions and validator changes.

1. **Stage the new folders.**

   ```sh
   git mv docs/dev docs/plans
   mkdir -p docs/references docs/runbooks docs/research
   ```

   Move:

   - `docs/references/chezmoi-architecture.md` -> `docs/references/`
   - `docs/references/mise-tool-management.md` -> `docs/references/`
   - `docs/references/grmrepo.md` -> `docs/references/`
   - `docs/plans/tart-mini-validation.md` -> `docs/runbooks/`
   - `docs/plans/agent-skill-management-research.md` -> `docs/research/`
   - `docs/plans/zsh-harness-comparison.html` -> out of repo, or keep only
     with a sibling Markdown index and validator exception.

2. **Update frontmatter `related` paths.** ADRs that reference `../plans/...`
   should point to `../plans/...`. Frontmatter-only edits do not touch locked
   ADR bodies.

3. **Remove non-canonical `skill_path:`** from the two
   `setup-downstream-fork-*plan.md` files. Replace with
   `current_guidance: [../../home/dot_agents/skills/setup-downstream-fork/]`.

4. **Backfill `created` / `updated`** on the docs flagged in Lifecycle
   Validator Additions.

5. **Update `docs/index.md`** to reflect the new paths. Section ordering stays
   orthogonal to folders: Current Guidance, Proposed Work, Decision Records,
   Historical Records. The index routes by lifecycle, not filesystem.

6. **Rewrite `AGENTS.md`** with the Doc Folder Purposes table, Source Surface
   Overview table, README-first guard, docs validation rule, and rules hygiene
   section. Keep it under 200 lines.

7. **Update `README.md`**. Remove "Plans live in `docs/plans/`; decisions live in
   `docs/adr/`" and add a concise coding-agent pointer to `AGENTS.md`.

8. **Update skill cross-references**:

   - `home/dot_agents/skills/code-gardening/SKILL.md`: add the folder-purposes
     pointer paragraph.
   - `home/dot_agents/skills/setup-downstream-fork/SKILL.md`: update
     `docs/plans/setup-downstream-fork-plan.md` -> `docs/plans/`.
   - `home/dot_agents/skills/setup-downstream-fork/references/architecture.md`:
     replace absolute `~/dotfiles/docs/...` paths with repo-relative paths and
     update `dev/` -> `plans/`.
   - `.agents/skills/chezmoi-management/` and
     `home/dot_agents/skills/chezmoi-management/`: update links to
     `docs/references/chezmoi-architecture.md` -> `docs/references/chezmoi-architecture.md`.
   - `home/dot_agents/skills/trycycle/`: make plan-path selection follow the
     repo's configured plan directory instead of hardcoding one path.

9. **Update tests and fixtures** to use `plans/`, `references/`, `runbooks/`,
   and `research/` instead of `dev/` or root-level docs where appropriate.

10. **Move and extend the validator** as a single self-contained file under
    `docs/`, with these checks:

    - plan-not-current;
    - frontmatter key allowlist failure;
    - non-Markdown content guard, with the validator itself as the only
      explicit tooling exception;
    - index coverage;
    - successor-link resolution;
    - stale moved-directory references.

11. **Run validation**:

    ```sh
    make test-docs-lifecycle
    git diff --check
    chezmoi diff
    chezmoi apply --dry-run --verbose --exclude=scripts
    ```

12. **Commit as one logical change** with a body that lists the moves and
    policy additions. ADR frontmatter edits live in the same commit so
    reviewers see the rename and its consequences together.

## Open Decisions

These are deliberately left for review. Once decided, fold answers into
`AGENTS.md`, `docs/document-lifecycle.md`, or the implementation diff.

1. **Lifecycle doc wording for `active`.** The plan chooses `active` as the
   default status for maintained steady-state references and runbooks. Update
   `docs/document-lifecycle.md` so that rule is explicit.
2. **Validator filename.** Choose the exact self-contained validator path under
   `docs/`, for example `docs/validate-doc-lifecycle`.
3. **Skill coverage timing.** The work is deferred to
   [Self-Improving Agents — Part 5](../research/self-improving-agents.md#part-5-open-questions-for-this-repos-harness);
   decide later whether to build the auditor, reuse
   [khendzel/skills-janitor](https://github.com/khendzel/skills-janitor), or
   keep it as documented follow-up.

## Risks

- **ADR frontmatter edits trip the locked-body rule** if an editor normalizes
  whitespace on save. Mitigation: run `make test-docs-lifecycle` and
  `git diff --check`.
- **Skill cross-references go stale during the rename.** Mitigation: migration
  steps enumerate every known cross-reference, and the validator should catch
  stale `docs/plans/` links.
- **Subagent `AGENTS.md` variant drifts from the main file.** Mitigation:
  define it as a strict subset of always-true rules. The variant should never
  contradict the main file.
- **The validator additions reject docs that currently pass.** Mitigation:
  backfill the flagged frontmatter issues before enabling the new failures.
- **README guard is missed by humans skimming the repo.** Acceptable: humans
  skim; the guard exists for the LLM-author workflow.
- **The plan creates too many folders too early.** Mitigation: the user wants
  `runbooks/` and `research/`; keep each folder's entry in `docs/index.md`
  explicit so empty or near-empty folders do not become junk drawers.

## Validation

- `make test-docs-lifecycle` passes.
- `git diff --check` passes.
- The lifecycle validator is a single self-contained file under `docs/`, with
  tests exercising that file.
- `chezmoi diff` and `chezmoi apply --dry-run --verbose --exclude=scripts`
  show no unexpected changes.
- `docs/index.md` lists every doc and routes to the right place.
- All renamed/relocated ADR frontmatter `related` paths resolve to real files.
- Every skill that referenced `docs/plans/` or `docs/<root>` now references the
  new path; `rg 'docs/plans/' home/dot_agents/ .agents/ docs/ AGENTS.md README.md`
  returns no stale hits.
- A fresh agent session, given the new `AGENTS.md`, answers:
  - "Where do plans go?" -> `docs/plans/`.
  - "Where do operator references go?" -> `docs/references/`.
  - "Where do runbooks go?" -> `docs/runbooks/`.
  - "Where does research go?" -> `docs/research/`.
  - "Where do decision records go?" -> `docs/adr/`.

## Source Links

- OpenAI Codex `AGENTS.md`: https://developers.openai.com/codex/guides/agents-md
- OpenAI Codex skills: https://developers.openai.com/codex/skills
- OpenAI harness engineering: https://openai.com/index/harness-engineering/
- Ryan Lopopolo on code as artifact: https://hyperbo.la/w/code-is-not-the-artifact/
- Ryan Lopopolo on job expectations: https://hyperbo.la/w/what-does-it-mean-to-do-a-good-job/
- Ryan Lopopolo on tool discovery: https://hyperbo.la/w/tool-discovery/
- Claude Code features: https://code.claude.com/docs/en/features-overview
- AGENTS.md convention: https://agents.md/
- Vercel agent evals: https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals
- Quickwit internals: https://github.com/quickwit-oss/quickwit/tree/main/docs/internals
- TiDB `AGENTS.md`: https://github.com/pingcap/tidb/blob/master/AGENTS.md
- OpenClaw `AGENTS.md`: https://github.com/openclaw/openclaw/blob/main/AGENTS.md
- Diataxis: https://diataxis.fr/
- Google Cloud ADRs: https://docs.cloud.google.com/architecture/architecture-decision-records

## Notes For Future Maintenance

This plan is `doc_type: plan`. Once implemented, set `status: superseded` or
`archived` and write a follow-up `docs/references/` doc only if there is
operator-facing guidance worth preserving. The state of the docs tree should be
self-documenting through folder names, frontmatter, and `docs/index.md`.

Quickwit's "Known Pitfalls" table and Lopopolo's MLD framework (`MISTAKES.md` /
`DESIRES.md` / `LEARNINGS.md` as runtime telemetry) are worth considering as
separate follow-up work. Route that through
[Self-Improving Agents](../research/self-improving-agents.md) rather than
expanding this docs reorg.
