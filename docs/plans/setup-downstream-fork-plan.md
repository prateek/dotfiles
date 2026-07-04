---
status: archived
doc_type: plan
owner: Prateek
updated: 2026-07-03
closed: 2026-05-15
current_guidance:
  - ../adr/0015-downstream-fork-daily-driver.md
  - ../../.agents/skills/fork-lifecycle/SKILL.md
related:
  - ../adr/0001-downstream-fork-architecture.md
status_detail: "Historical implementation plan for the deleted setup-downstream-fork skill. The downstream-fork skill and ADR 0015 replaced the whole approach."
---

# setup-downstream-fork — plan

## Problem

Prateek regularly wants to use an upstream OSS project (CLI, app, library) with local customizations while still tracking upstream automatically. Doing this by hand — merge, rebase, fix conflicts, rebuild, retest — is tedious and error-prone, and drift quickly makes a fork unmaintainable. The goal is a skill that spins up a new downstream fork in one shot, then keeps it on cruise control with an LLM resolving the boring conflicts and humans only getting paged for genuine design calls.

## Goals

- One-shot setup: clone upstream, scaffold `.fork/`, create the GitHub repo, wire up secrets and branch protection, kick off the first sync.
- Self-contained repo: upstream's full git history present from day one (clone-as-base). Durable rollback via `upstream-sync/<date>-<sha>` and `sync/<date>-<sha>-merged` tags.
- Cruise control by default: cron-driven sync, LLM resolves conflicts, Mergify auto-merges on green CI, escalate to a human only when the LLM bails.
- LLM-native repo: generated repo ships its own agent skills under `.fork/skills/` so any coding agent (Claude Code, Cursor) can operate it without prior briefing.
- Provider choice: the conflict resolver works with Claude or OpenAI, configured by env.
- Two modes: `setup` for greenfield, `doctor` for auditing/fixing an existing fork.
- Scales from small CLIs to mid-size projects. Chromium-scale is out of scope for the default layout; see non-goals.

## Non-goals

- Not a general-purpose PR-authoring agent.
- Not a dependency upgrader (that's `renovate`/`dependabot`).
- Not trying to handle hostile upstream changes (license flips, repo takeovers) — those are human decisions.
- Not converting non-fork repos to fork layout.
- Not Chromium-scale out of the box. For >2GB upstreams we switch to Option D (patch-stack-only, no vendoring) — separate decision, not yet scoped.

## Architecture

Chosen: **Option C** — clone-as-base with `.fork/` inverted subdir, patches as git commits carrying a `Fork-Patch:` trailer, derived `.fork/patches/` flat-file inventory. Full rationale and the options compared (A, B, B′ subrepo, C, D) live in [../adr/0001-downstream-fork-architecture.md](../adr/0001-downstream-fork-architecture.md). Summary:

- Repo is `git clone <upstream>`. Upstream's full git history is present.
- Two branches:
  - `upstream` — pristine mirror, force-updated to upstream's HEAD on every sync.
  - `main` — default branch; upstream + fork patches applied as commits with `Fork-Patch: <slug>` trailer. **Never force-pushed.**
- Each sync runs on a short-lived `sync/<date>-<sha>` branch, rebased onto the new upstream. The sync branch is merged into `main` only after CI passes. `main` moves append-only via PR merges.
- Scaffolding under `.fork/`: AGENTS.md, README.md, upstream-AGENTS.md, revision.txt, patches/, snapshots/, references/, tools/, skills/, `.llm-cache/` (gitignored).
- `.github/workflows/` at root uses `fork-*.yml` prefix to avoid collision with upstream's workflow names; pre-flight detects collisions and fails loudly.

## Where "upstream + patches applied" lives

On `main`. There is no separate `published` branch. `main` IS the built tree — upstream code with patches applied as commits on top. Users clone and build from `main`. Release tags `release/<upstream-tag>` snapshot `main` at each upstream version boundary.

## State of the fork at any moment

Two files answer "what upstream + what patches are we on" instantly:

```
$ cat .fork/revision.txt
upstream = 01e92e3 (v1.2.3)
synced   = 2026-04-17T10:33:00Z
tag      = upstream-sync/2026-04-17-01e92e3

$ ls .fork/patches/
series
0001-quiet-flag.patch
0002-disable-telemetry.patch
0003-custom-theme.patch
```

Each patch file has a `Reason:` header explaining why it exists. Both views always exist and always agree: `patches/` is `git format-patch upstream..main --grep='Fork-Patch:'` regenerated on every sync; `revision.txt` is refreshed from the `upstream` branch's HEAD. If you prefer the commit-level view:

```
$ git log upstream..main --grep='Fork-Patch:' --oneline
a1b2c3d feat(cli): add --quiet flag            [Fork-Patch: quiet-flag]
e4f5g6h feat(privacy): disable telemetry       [Fork-Patch: disable-telemetry]
i7j8k9l feat(ui): custom theme                 [Fork-Patch: custom-theme]
```

## Separating upstream commits from fork commits

Both are in `main`'s history. Three ways to tell them apart:

```
# upstream's full linear history (from the mirror branch)
$ git log upstream --oneline
01e92e3 docs: expand README (revision B)
e92daae initial: revision A

# your fork's patches only (commits with Fork-Patch: trailer on main)
$ git log --grep='Fork-Patch:' --oneline
a1b2c3d feat(cli): add --quiet flag
...

# everything on main since your fork diverged from upstream
$ git log upstream..main --oneline
# → your patches + any sync merge commits
```

Upstream's per-commit history is preserved unsquashed on the `upstream` branch; `git log upstream` walks it exactly as upstream has it.

## Generated repo layout

```
<fork-name>/                     # defaults to the upstream repo's name
├── <upstream's files at root — paths match upstream, contents carry fork patches>
├── AGENTS.md                    # ROOT pointer — "this is a fork, see .fork/AGENTS.md"
├── CLAUDE.md                    # ROOT pointer (symlink → AGENTS.md)
├── .claude/
│   └── skills/  →  ../.fork/skills    # symlink for Claude Code discovery
├── .agents/
│   └── skills/  →  ../.fork/skills    # symlink for Codex / generic agent discovery
├── .fork/
│   ├── AGENTS.md                # full fork contract — read by any LLM doing work here
│   ├── README.md                # fork-specific human docs
│   ├── upstream-AGENTS.md       # preserved copy of upstream's AGENTS.md (if any)
│   ├── revision.txt             # current upstream SHA + tag + ISO date
│   ├── patches/                 # DERIVED: git format-patch --grep='Fork-Patch:'
│   │   ├── series
│   │   ├── 0001-<slug>.patch
│   │   └── 0002-<slug>.patch
│   ├── snapshots/               # per-sync audit log (JSON)
│   │   └── 2026-04-17-01e92e3.json  # name format: <date>-<sha>.json
│   ├── .llm-cache/              # gitignored — LLM resolver resolution cache
│   ├── references/              # LLM-consumable docs (prompts, architecture, doctor checklist)
│   │   ├── architecture.md
│   │   ├── resolver-prompt.md
│   │   ├── doctor-checklist.md
│   │   └── patch-vocabulary.md  # PATCH_CHANGED, SRC_CHANGED, etc.
│   ├── tools/
│   │   ├── check-upstream.sh
│   │   ├── sync.sh              # manual wrapper
│   │   ├── export-patches.sh    # regenerate .fork/patches/
│   │   ├── upstream-patch.sh    # one-command upstream contribution
│   │   └── llm_resolve.py       # provider-agnostic resolver
│   └── skills/                  # repo-local skills the fork ships
│       ├── add-feature/
│       ├── refresh-patches/
│       ├── sync-upstream/
│       ├── resolve-conflict/    # references .fork/references/resolver-prompt.md
│       └── doctor/              # references .fork/references/doctor-checklist.md
├── .github/workflows/
│   ├── fork-upstream-sync.yml
│   ├── fork-build-release.yml
│   └── fork-conflict-resolve.yml
└── .mergify.yml                 # auto-merge rules (Fork-Patch: mergify-config)
```

**Root AGENTS.md/CLAUDE.md** is a tiny pointer (under 20 lines) that any agent hits first. It says: "this is a downstream fork of `<upstream>`. Your full contract is at `.fork/AGENTS.md` — read it before making changes. Source edits go at the repo root; patches are tracked via `Fork-Patch:` commit trailers; see `.fork/skills/` for playbooks."

**Handling upstream's own AGENTS.md**: if upstream ships one at root, the initial setup captures it as a commit with `Fork-Patch: agents-md` trailer — moving the original to `.fork/upstream-AGENTS.md` and replacing root `AGENTS.md` with our pointer. The patch is treated the same way as any other: `Reason: AGENTS.md at root must route agents to the fork contract`. Upstream's guidance stays readable inside `.fork/` for reference.

**`.fork/references/`**: holds the shared LLM-consumable docs the repo-local skills link to. Lets `resolve-conflict/SKILL.md` stay small and reference `references/resolver-prompt.md` for the long-form instructions. Same pattern the `setup-downstream-fork` skill itself uses.

**Agent discovery of `.fork/skills/`**: Claude Code looks at `.claude/skills/`, Codex at `.agents/skills/`. The generated fork ships two symlinks (`.claude/skills → ../.fork/skills` and `.agents/skills → ../.fork/skills`) so both discover our repo-local skills without us duplicating them. Source of truth stays in `.fork/skills/`; agents see them where they expect.

**`.fork/README.md`**: human-facing overview of the fork — what upstream it tracks, why forked, how to build locally. The README a human would skim before touching anything.

Fork repo default name: **same as upstream** (e.g., upstream `charmbracelet/glow` → fork `<your-user>/glow`). The owner path does the disambiguation, the same way VoiceInk's `metrovoc/VoiceInk` fork works. If you already own a repo by that name, setup offers `<repo>-fork` as a fallback; you can also type any name you want.

## Branch and tag lifecycle

```
time →
                                                                 (sync 1)         (sync 2)
upstream (upstream-only)       A ─────────── B ──────────────── C ────────────── D ────────────

tag upstream-sync/*                          upstream-sync/     upstream-sync/
                                             2026-04-17-01e92e3 2026-04-18-adc616e

main (default, append-only)    A─p0──────────squash(sync1)────────────squash(sync2)────────

sync branches (ephemeral)                    sync/2026-04-17-…         sync/2026-04-18-…
                                             └─ rebased + resolved     └─ rebased + resolved

tag sync/*-merged                            sync/2026-04-17-…-merged  sync/2026-04-18-…-merged

tag release/*                                                         release/v1.2.4
```

- **`upstream`** branch is a mirror. Force-updated each sync. No fork content ever.
- **`main`** never has its history rewritten. Each sync adds one squash commit from the sync branch (per Mergify's `fork-sync` queue rule using `method: squash`).
- **`sync/<date>-<sha>`** branches are ephemeral — created, rebased, resolved, merged, deleted. A tag `sync/<date>-<sha>-merged` preserves the patch-level SHAs for archaeology.
- **`upstream-sync/<date>-<sha>`** tags preserve every imported upstream SHA, independent of what upstream does later.
- **`release/<upstream-tag>`** tags snapshot `main` at each upstream version boundary.

Everything is append-only except the `upstream` mirror branch, which by design only ever tracks upstream's HEAD.

## CI workflows and coordination

Three actors, coordinated via `workflow_call` and PR labels:

1. **`fork-upstream-sync.yml`** — cron actor. Detects upstream drift, tags `upstream-sync/<date>-<sha>`, resets `upstream` branch, creates `sync/<date>-<sha>` from `main`, rebases onto `upstream`, delegates to the LLM actor on conflict, regenerates `.fork/patches/`, writes `.fork/snapshots/<date>-<sha>.json`, opens a PR against `main`. If any `DESIGN_CONFLICT:` markers remain, also files a tracking issue and copies the markers into the PR body so Mergify's `body~=DESIGN_CONFLICT:` rule can match.
2. **`fork-build-release.yml`** — build actor. Runs on PRs and on main push. Builds, smoke-tests. Also runs the `drift-recheck` status check on sync PRs: re-fetches upstream and fails the check if upstream's HEAD has advanced beyond the SHA captured in the snapshot. On merge to `main`, tags `sync/<date>-<sha>-merged`. Tags `release/<upstream-tag>` when upstream cut a release.
3. **`fork-conflict-resolve.yml`** — LLM actor. Invoked via `workflow_call`. Shells out to `.fork/tools/llm_resolve.py`, which loads `.fork/references/resolver-prompt.md`, the fork contract from `.fork/AGENTS.md`, and the conflicted commit's `Fork-Patch:` + `Reason:` trailers. Resolves conflicts in source files on the sync branch, commits, returns. The repo-local `.fork/skills/resolve-conflict/` is human-facing documentation for running the same loop manually — not what CI reads.

Mergify gates auto-merge on four conditions: `check-success=build` + `check-success=smoke-test` + `check-success=drift-recheck` + no `DESIGN_CONFLICT:` markers in the PR body (the sync workflow copies any inline markers into the PR body so this match works). The `drift-recheck` status check is produced by `fork-build-release.yml` and implements the jito-solana HEAD-drift pattern.

### `.mergify.yml` contents

Written to the repo root at setup. Sketch:

```yaml
queue_rules:
  - name: fork-sync
    conditions:
      - check-success=build
      - check-success=smoke-test
      - check-success=drift-recheck

pull_request_rules:
  - name: auto-label sync PRs
    conditions:
      - author=github-actions[bot]
      - head~=^sync/
    actions:
      label:
        add: [automerge]

  - name: auto-merge sync PRs on green (no design conflicts)
    conditions:
      - label=automerge
      - check-success=build
      - check-success=smoke-test
      - check-success=drift-recheck
      - "-body~=DESIGN_CONFLICT:"
    actions:
      queue:
        name: fork-sync
        method: squash

  - name: flag design-conflict PRs for human review
    conditions:
      - head~=^sync/
      - "body~=DESIGN_CONFLICT:"
    actions:
      label:
        add: [needs-human]
        remove: [automerge]
      comment:
        message: "⚠️ One or more patches surfaced `DESIGN_CONFLICT:` markers. Human review required before merge."
```

Note on the `body~=` match: Mergify's `files` attribute matches file paths, not file contents. To detect `DESIGN_CONFLICT:` markers left inside source files, the sync workflow extracts any such lines from the diff and appends them to the PR body under a `### DESIGN_CONFLICT:` heading. That lets `body~=DESIGN_CONFLICT:` fire correctly.

Setup installs the Mergify GitHub App on the fork repo as part of the GitHub-side configuration step. Auth is via the app install; no API token needed in workflows.

## Local development flow

1. User/agent opens the repo. Hits root `AGENTS.md` first — a short pointer that routes them to `.fork/AGENTS.md`. The full fork contract lives there: "this is a downstream fork of X, upstream lives on the `upstream` branch, your patches go as commits on `main` with `Fork-Patch: <slug>` + `Reason: <why>` trailers, see `.fork/skills/` for playbooks and `.fork/references/` for prompts."
2. Edit files at the repo root (same paths upstream uses). Write tests. Commit with trailers.
3. `.fork/tools/export-patches.sh` refreshes `.fork/patches/` from the current delta.
4. Open PR. CI runs build + smoke test. Mergify merges on green.

To upstream a feature: `.fork/tools/upstream-patch.sh <slug>` cherry-picks the commit onto a fresh branch off the upstream remote, pushes to your upstream-facing fork (separate from the downstream-maintenance fork this skill generates), and opens the PR against upstream. The `.fork/patches/NNNN-<slug>.patch` file is also directly usable for patch-based contribution paths.

## Workflow recipes

### Add a new fork feature
```bash
# 1. edit upstream files at repo root
vim cmd/main.go

# 2. commit with trailers (the Fork-Patch trailer is what makes it a "patch")
git commit -m "feat(cli): add --quiet flag

Fork-Patch: quiet-flag
Reason: scripted contexts want no stdout"

# 3. refresh derived patches dir
.fork/tools/export-patches.sh

# 4. amend commit to include the patches/ update, or commit as a follow-up
git add .fork/patches/ && git commit --amend --no-edit

# 5. push + open PR
git push -u origin feat/quiet-flag && gh pr create
```

### Upstream a patch back
```bash
# one-command path
.fork/tools/upstream-patch.sh quiet-flag
# → cherry-picks the Fork-Patch: quiet-flag commit onto a branch from upstream,
#   pushes to your upstream-facing fork, opens PR against upstream.

# manual path if you prefer
git format-patch -1 $(git log --grep='Fork-Patch: quiet-flag' --format=%H -1 main)
# → 0001-feat-cli-add-quiet-flag.patch ready to send
```

### Rollback to a previous sync
```bash
# every past sync is durably tagged
git tag -l 'upstream-sync/*'
# → upstream-sync/2026-04-17-01e92e3
#   upstream-sync/2026-04-18-adc616e
#   …

git tag -l 'sync/*-merged'
# → sync/2026-04-17-01e92e3-merged
#   sync/2026-04-18-adc616e-merged

# restore main's state from two syncs ago
git checkout sync/2026-04-17-01e92e3-merged
# now you have main-as-of-that-sync, with upstream pinned + patches applied
```

### Disable a patch
```bash
# find and revert the commit
git revert $(git log --grep='Fork-Patch: custom-theme' --format=%H -1 main)

# patches/ will regenerate without it on next sync, or force it now:
.fork/tools/export-patches.sh
git add .fork/patches/ && git commit -m "fork: disable custom-theme patch"
```

### Reorder or edit a patch
```bash
# standard git — interactive rebase of your fork patches
git rebase -i upstream
# edit, reorder, squash, reword as you wish
git push --force-with-lease <feature-branch>
# (this only force-pushes the feature branch, not main)
```

### See what the last sync actually did
```bash
cat .fork/snapshots/2026-04-18-adc616e.json
# → { "upstream_sha": "adc616e",
#     "pre_sync_main_sha": "…",
#     "merged_commit_sha": "…",
#     "ci_result": "pass",
#     "llm_resolutions": [{"file": "src/foo.c", "patch": "quiet-flag", "outcome": "resolved"}, …] }
```

## LLM resolver

Lives at `.fork/tools/llm_resolve.py`. Provider-agnostic (Claude or OpenAI via env). Single model per run, bounded turns. Local cache of past resolutions keyed on `(file_path, pre_context_hash, post_context_hash)` — replay if we've seen the same shape before (rizzler-style). Returns either the resolved file contents or `DESIGN_CONFLICT: <reason>` inline. A smoke test runs on each resolved file/module; rollback on regression.

Prompt template lives at `.fork/references/resolver-prompt.md` in the generated repo; `llm_resolve.py` loads it, augments with the fork contract from `.fork/AGENTS.md` and the conflicted commit's `Fork-Patch:` + `Reason:` trailers.

## Prior art — what we borrowed, from whom

- **VoiceInk** — the rebase-onto-upstream pattern + LLM-driven conflict resolution via `claude-code-action`, with a short root-level agent pointer (VoiceInk uses `CLAUDE.md`; we use `AGENTS.md` + `CLAUDE.md` symlink) acting as the "fork contract" entry point.
- **jito-solana** — Mergify auto-merge on green CI; HEAD-drift recheck against upstream before merge so we don't land stale resolutions.
- **valgrind-macos** — two-branch layout (`upstream` pristine + working branch).
- **Cromite** — the structured `Reason:` trailer and per-patch escalation semantics when an LLM bails (`DESIGN_CONFLICT:` marker).
- **ungoogled-chromium / VSCodium** — named, ordered, first-class patch files as the human-facing inventory artifact.
- **Debian's `debian/patches/` + quilt** — the `series` file convention for ordering patches.
- **Brave's `gitPatcher.js`** — the patch-staleness enum vocabulary (`PATCH_CHANGED`, `SRC_CHANGED`, etc.) as structured input to the LLM resolver.
- **Mergify** — declarative auto-merge queue rules.
- **git `rerere`** — always on in CI to cache past resolutions.

What we did NOT borrow:
- **`git-subrepo` or `git subtree`** — we smoke-tested subrepo and rejected because it squashes upstream commits.
- **Chromium-style patch stacks without vendoring (Option D)** — deferred for >2GB upstreams; dev UX is too awkward for small forks.
- **Wiggle-based fuzzy patch application** — unnecessary with native git three-way merge markers.

## Addressing the adversarial + subagent review findings

1. **Rollback durability** — every imported upstream SHA tagged `upstream-sync/<date>-<sha>` before the `upstream` branch is reset. SHAs cannot be force-pushed away. `.fork/snapshots/<date>.json` records `(upstream_sha, pre_sync_main_sha, merged_commit_sha, ci_result, llm_resolutions)` per sync as a machine-readable audit trail.
2. **Force-push of `main`** — eliminated. All syncs go through a `sync/*` branch + PR; `main` is append-only. Clones stay consistent across machines.
3. **Skill mismatch with ADR** — SKILL.md is still on the old subrepo design and must be rewritten to match Option C. Phase 1 of the implementation plan.
4. **`fork-*.yml` naming discipline collision risk** — pre-flight check scans upstream's `.github/workflows/` for `fork-*.yml` names; refuses to proceed if there's a collision, so the failure mode is a loud error at setup time, not a silent overwrite months later.
5. **Snapshot filename format** — standardized on `<date>-<sha>.json` (matches the `upstream-sync/<date>-<sha>` and `sync/<date>-<sha>-merged` tag conventions).
6. **Tracking-issue filing** — owned by `fork-upstream-sync.yml` on the `DESIGN_CONFLICT:` path. Not silent.
7. **`DESIGN_CONFLICT:` detection in Mergify** — markers inside source files are surfaced into the PR body by the sync workflow so `body~=DESIGN_CONFLICT:` matches. Mergify's `files~=` matches paths, not contents, so we don't use it.

## Implementation plan

### Phase 1 — reconcile SKILL.md with ADR 0001
- [ ] Rewrite `SKILL.md` for Option C (clone-as-base + `.fork/` + sync-branch merges).
- [ ] Drop references to `git-subrepo`, `src/` subdir, `wiggle`.
- [ ] Add pre-flight: `gh auth status`, upstream reachable, fork name free, `.github/workflows/fork-*.yml` name collision check.
- [ ] Document architecture-layout assertions for the eval harness to verify post-setup.

### Phase 2 — references for the skill author (the skill-creator's own docs)
- [ ] `references/architecture.md` — long-form of ADR 0001, for a future skill maintainer.
- [ ] `references/examples.md` — pointers to VoiceInk, jito-solana, etc. for when the skill needs to extend itself.

### Phase 3 — templates (generated files)
- [ ] `templates/fork/AGENTS-root.md.tmpl` — the tiny root pointer
- [ ] `templates/fork/AGENTS.md.tmpl` — the `.fork/AGENTS.md` full contract
- [ ] `templates/fork/README.md.tmpl`
- [ ] `templates/fork/revision.txt.tmpl`
- [ ] `templates/fork/references/architecture.md.tmpl`
- [ ] `templates/fork/references/resolver-prompt.md.tmpl`
- [ ] `templates/fork/references/doctor-checklist.md.tmpl`
- [ ] `templates/fork/references/patch-vocabulary.md.tmpl` — Brave's `PATCH_CHANGED`/`SRC_CHANGED` enum, for the resolver
- [ ] `templates/workflows/fork-upstream-sync.yml.tmpl`
- [ ] `templates/workflows/fork-build-release.yml.tmpl`
- [ ] `templates/workflows/fork-conflict-resolve.yml.tmpl`
- [ ] `templates/.mergify.yml.tmpl`
- [ ] `templates/tools/check-upstream.sh.tmpl`
- [ ] `templates/tools/sync.sh.tmpl`
- [ ] `templates/tools/export-patches.sh.tmpl`
- [ ] `templates/tools/upstream-patch.sh.tmpl`

### Phase 4 — LLM resolver
- [ ] `templates/tools/llm_resolve.py.tmpl` (provider-agnostic)
- [ ] Resolution cache (per-repo, `.fork/.llm-cache/`)
- [ ] Smoke-test hook per resolved file/module

### Phase 5 — repo-local skills (shipped inside the generated repo)
- [ ] `templates/repo-skills/add-feature/SKILL.md`
- [ ] `templates/repo-skills/refresh-patches/SKILL.md`
- [ ] `templates/repo-skills/sync-upstream/SKILL.md`
- [ ] `templates/repo-skills/resolve-conflict/SKILL.md`
- [ ] `templates/repo-skills/doctor/SKILL.md`

### Phase 6 — executors
- [ ] `scripts/setup_fork.py` — executes the full scaffold against a target upstream, including GitHub repo creation + secrets + branch protection + Mergify app install + Mergify config commit.
- [ ] `scripts/doctor.py` — audits an existing fork, proposes fixes.
- [ ] Language/build-system detection; emit build helpers.

### Phase 7 — evals
- [ ] `evals/evals.json` with 3 test cases:
  - New fork of a small CLI (e.g., `charmbracelet/glow`) — asserts `.fork/` layout, workflows, `revision.txt`, `upstream` branch tag exist.
  - Doctor audit on an intentionally-broken fork — reports correct drift.
  - Synthetic conflict: simulate an upstream bump that drifts a local patch; assert LLM resolver produces a valid diff + smoke test passes.
- [ ] Run paired subagents (with-skill vs baseline).
- [ ] Iterate based on feedback.

### Phase 8 — description optimization
- [ ] 20 realistic trigger queries.
- [ ] Run `run_loop.py`; apply `best_description`.

## Open questions

- Resolution cache scope: per-repo (`.fork/.llm-cache/`, safer) or user-global (`$HOME/.cache/fork-maintainer/`, more efficient). Leaning per-repo.
- Smoke test for cross-compile/platform-specific builds: fallback to topology-only verification when the runner OS can't build the target?
- `fork-conflict-resolve.yml`: one file supporting both `claude-code-action` and an OpenAI equivalent, or two variants?
- Doctor mode: offer to convert older-layout forks (non-`.fork/`) to this layout, or always stop and suggest manual migration? Leaning manual for now.
- Pre-flight size threshold for recommending Option D: 2GB is the current guess; revisit once we fork something large.

## Success criteria

- A fresh fork of a small CLI is fully configured and passes its first cron sync within 30 minutes, start-to-finish, with no manual Git/GH steps.
- On a synthetic upstream bump that drifts 3 of 5 patches, the LLM resolver handles the 3 drifts unattended and the PR auto-merges.
- When the LLM can't resolve, the PR is opened, labeled `needs-human`, a tracking issue is filed — no silent failures.
- Rollback drill: given a fork two syncs behind, we can check out `upstream-sync/<date>-<sha>` and rebuild without network access to upstream.
- Eval viewer shows per-test user feedback with no explicit corrections on the happy-path tests.

## FAQ

**Is this repo self-contained? Can I rebuild if upstream disappears?**
Yes. The repo is a full `git clone` of upstream, so every upstream SHA ever synced is in the object store. `upstream-sync/<date>-<sha>` tags ensure those SHAs stay reachable even if upstream force-pushes. You can `git checkout upstream-sync/<date>-<sha>` offline at any time.

**Can I see upstream's commits as individual commits?**
Yes. `git log upstream` shows upstream's full linear history, unsquashed. This was the deal-breaker that rejected the `git-subrepo` approach.

**Where does "upstream + patches applied" live?**
On `main`. It's the default branch. Users clone and build from `main` directly. No separate `published` branch.

**How do I know what patches my fork carries?**
Two views: `ls .fork/patches/` (flat files with `Reason:` headers) or `git log --grep='Fork-Patch:'` (commit-level). Both always agree.

**How do I contribute a patch back upstream?**
`.fork/tools/upstream-patch.sh <slug>` does it in one command. Or grab `.fork/patches/NNNN-<slug>.patch` and send it manually.

**Is `main` ever force-pushed?**
No. Syncs run on short-lived `sync/*` branches and merge into `main` via PR. Multi-machine clones stay consistent.

**What if the LLM can't resolve a conflict?**
It writes `DESIGN_CONFLICT: <reason>` inline in the file. The sync PR opens labeled `needs-human` (not `automerge`), and a tracking issue is filed. Silent failures are a bug.

**What happens if upstream force-pushes their history?**
The pre-sync `upstream-sync/<date>-<sha>` tag means every SHA we imported stays reachable in our object store. The next sync picks up whatever upstream's new HEAD is and rebases patches accordingly. Worst case: you `git checkout <tag>` and work from there.

**How does the LLM know what a patch is supposed to do?**
The commit carries a `Fork-Patch: <slug>` trailer and a `Reason: <why>` line. Both are read by the resolver when deciding how to merge changes.

**Does this scale to Chromium?**
No. For anything above ~2GB we switch to Option D (patches-only, no vendoring). That's a separate future ADR.

**Why not `git-subrepo`?**
It squashes upstream commits on every sync, losing the per-commit granularity. See ADR 0001 → "Options considered" → "Option B′" for the rejection rationale.

**Why `.fork/` not `vendor/` or `src/`?**
Because upstream's code stays at root (we're a clone of upstream). The `.fork/` namespace is where our scaffolding lives, to avoid colliding with upstream's own root-level files.

## References

- ADR: [../adr/0001-downstream-fork-architecture.md](../adr/0001-downstream-fork-architecture.md)
- Prior-iteration ADR (merged into 0001): [../adr/0003-downstream-fork-subrepo.md](../adr/0003-downstream-fork-subrepo.md)
- Smoke test artifacts: `/tmp/fork-smoketest/` (may be cleaned up)
- `claude-code-action`: https://github.com/anthropics/claude-code-action
- Mergify: https://docs.mergify.com/
- Real-world implementations studied: VoiceInk, Cromite, ungoogled-chromium, jito-solana, Brave, VSCodium, valgrind-macos.
