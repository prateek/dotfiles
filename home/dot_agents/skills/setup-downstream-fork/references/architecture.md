# Architecture reference

Written for an LLM extending or debugging this skill. Not for the end user of a generated fork — that audience is served by `templates/fork/references/architecture.md.tmpl`, which ships into the generated repo.

Full rationale lives in `docs/adr/0001-downstream-fork-architecture.md` in the dotfiles repo. The plan doc at `docs/plans/setup-downstream-fork-plan.md` is historical context only. This file is the operational summary.

## Core mental model

Four primitives, held together by convention:

1. **Clone-as-base.** The generated repo is a plain `git clone` of upstream. Upstream files stay at root with paths matching upstream exactly. Upstream's full per-commit history is present in the object store from day one.
2. **`.fork/` namespace.** Everything the fork owns lives under `.fork/` (AGENTS.md, tools, snapshots, patches, skills, references, the LLM cache). One directory the fork controls completely; no collisions with upstream's file tree. The only forced exception is `.github/workflows/`, which GitHub requires at root — we prefix every file `fork-*.yml` and pre-flight refuses to proceed if upstream ships a file with that prefix.
3. **Patches-as-commits.** Fork customizations are ordinary git commits on `main` carrying a `Fork-Patch: <slug>` + `Reason: <why>` trailer. The `.fork/patches/*.patch` directory is derived via `git format-patch upstream..main --grep='Fork-Patch:'` on every sync — same content, flat-file view for `ls`-style browsing and direct upstreaming.
4. **Sync-branch merges.** Syncs never run on `main` directly. Each sync runs on an ephemeral `sync/<date>-<sha>` branch, rebases onto a refreshed `upstream`, gets conflict-resolved by the LLM, then Mergify squash-merges into `main` when CI is green. `main` is append-only.

The ADR calls this "Model A, patch stack, expressed via git commits." Conflicts surface as native `<<<<<<<` markers in source files, which is what the resolver reads.

## Branches and tags

| Ref | Kind | Lifecycle | Purpose |
|---|---|---|---|
| `main` | branch | append-only via sync-branch merges; **never force-pushed** | default branch; upstream + fork patches applied; what users clone and build from |
| `upstream` | branch | force-updated to upstream's HEAD on every sync | pristine mirror; no fork content ever lands here |
| `sync/<date>-<sha>` | branch | ephemeral — created, rebased, resolved, merged, deleted | scratch surface for each sync; force-push allowed during resolution because nobody else has it checked out |
| `upstream-sync/<date>-<sha>` | tag | permanent | durable anchor to every imported upstream SHA; tagged *before* the `upstream` branch is reset, so force-pushes upstream cannot erase it |
| `sync/<date>-<sha>-merged` | tag | permanent | preserves the patch-level SHAs of each merged sync branch for archaeology; `main`'s log only shows one squash commit per sync |
| `release/<upstream-tag>` | tag | permanent | snapshots `main` at each upstream version boundary |

Two invariants hold the design together:

- Every SHA we ever imported is reachable via an `upstream-sync/*` tag. You can `git checkout upstream-sync/<date>-<sha>` offline, even if upstream deletes its repo or force-pushes history.
- `main` moves only by merge commit from a `sync/*` branch. Multi-machine clones stay consistent.

Two derived files on `main` answer "where are we" at a glance: `.fork/revision.txt` (current upstream SHA + tag + ISO date) and `.fork/patches/` (flat patch inventory with `Reason:` headers).

## Rejected alternatives (one paragraph each)

See ADR 0001 §Options considered for full detail.

**Option A — scaffolding at root, no namespace.** Upstream files and fork scaffolding both live at `/`. Direct collisions with upstream's own `.github/`, `tools/`, `MAINTAINERS`. Rejected because collisions require hand-merging every sync.

**Option B — `git subtree` vendor/.** Upstream vendored into `vendor/` via `git subtree add --squash`. Zero root collisions, but build systems expect the project at root so every build invocation gets rewritten, `--squash` loses upstream's per-commit history, and `git subtree` ergonomics are poor. Rejected on ergonomics + build-path cost.

**Option B′ — `git-subrepo` vendor/.** We smoke-tested this end-to-end (artifacts may still exist at `/tmp/fork-smoketest/`). `git-subrepo` is a better-ergonomics wrapper around subtree with a `.gitrepo` metadata file and first-class pull/push commands. It works, but squashes upstream commits on every sync — the fork's main-branch history does not contain upstream's individual commits. The user explicitly values seeing upstream's commits one at a time, so B′ was rejected despite the cleaner UX.

**Option D — patches-only, no vendoring.** Repo contains only `patches/*.patch`, a `series` file, `revision.txt`, scaffolding. Upstream materialized fresh at build time. Tiny repo, best reproducibility, only option that scales to Chromium. Rejected as default because dev UX is worse (edits happen in a separate gitignored working dir and extract back). Retained as a future opt-in for upstreams >2GB; pre-flight warns at that threshold.

## CI workflows and coordination

Three workflows coordinate via `workflow_call`, PR labels, and a shared snapshot file.

1. **`fork-upstream-sync.yml`** — cron actor (default daily 06:00 UTC).
   - Fetch upstream. If HEAD matches `.fork/revision.txt`, exit clean.
   - Tag `upstream-sync/<date>-<sha>` at upstream's current HEAD *before* touching the `upstream` branch. This is the durability guarantee; nothing else works if this step is out of order.
   - Fast-forward (or reset) the `upstream` branch to upstream HEAD.
   - Create `sync/<date>-<sha>` from `main`.
   - `git rebase upstream`. On conflict, invoke `fork-conflict-resolve.yml` via `workflow_call` per conflicted commit.
   - Regenerate `.fork/patches/` via `git format-patch upstream..HEAD --grep='Fork-Patch:'`.
   - Write `.fork/snapshots/<date>-<sha>.json` with `upstream_sha`, `pre_sync_main_sha`, `merged_commit_sha` (filled by the build workflow on merge), `ci_result`, `llm_resolutions[]`.
   - Open a PR against `main` via `peter-evans/create-pull-request`. If any `DESIGN_CONFLICT:` markers survived resolution, extract them from the diff, copy them into the PR body under `### DESIGN_CONFLICT:`, label the PR `needs-human`, and file a tracking issue.

2. **`fork-build-release.yml`** — build actor. Runs on PRs against `main` and on `main` push.
   - Build + smoke test. These must be fast and deterministic or the cron loop becomes noisy.
   - Produces a `drift-recheck` status check on sync PRs: re-fetch upstream, fail the check if upstream's HEAD has advanced past the `upstream_sha` captured in the snapshot. This is the jito-solana HEAD-drift pattern — it prevents us from merging a stale resolution.
   - On merge to `main`, tag `sync/<date>-<sha>-merged` so the per-patch SHAs stay reachable (the squash commit on `main` loses them).
   - If upstream cut a release since the last sync, tag `release/<upstream-tag>` on `main`.

3. **`fork-conflict-resolve.yml`** — LLM actor. Invoked via `workflow_call` from the sync workflow.
   - Shells out to `.fork/tools/llm_resolve.py`.
   - Loads `.fork/references/resolver-prompt.md`, the fork contract from `.fork/AGENTS.md`, and the conflicted commit's `Fork-Patch:` + `Reason:` trailers.
   - Resolves conflicts in source files, commits on the sync branch, returns.
   - Provider-agnostic: `LLM_PROVIDER=claude|openai` in env selects the secret the workflow passes through. Single model per run; no tiering in v1.

Mergify reads the state all three workflows emit. Auto-merge fires only on:

- `check-success=build`
- `check-success=smoke-test`
- `check-success=drift-recheck`
- `-body~=DESIGN_CONFLICT:` (Mergify's `files` attribute matches paths, not file contents; the sync workflow copies any in-file markers into the PR body under `### DESIGN_CONFLICT:` so this match works)

See `templates/.mergify.yml.tmpl` for the exact queue rule and PR rules. The `fork-sync` queue uses `method: squash` so `main`'s history stays linear.

## LLM resolver

Lives at `.fork/tools/llm_resolve.py` in the generated repo. Shape:

- Reads conflict files with native git markers on stdin or by path.
- Loads the long resolver prompt from `.fork/references/resolver-prompt.md`, the fork contract from `.fork/AGENTS.md`, and the failing commit's trailers.
- One LLM call per conflicted file with bounded turns (default 3). No multi-file reasoning in v1 — each file is independent.
- Output is either resolved file contents (written back to disk) or `DESIGN_CONFLICT: <reason>` inline. The latter bubbles up through the sync workflow to the PR body and triggers Mergify's `needs-human` gate.
- Local resolution cache at `.fork/.llm-cache/` keyed on `(file_path, pre_context_hash, post_context_hash)`. On a cache hit the resolver replays the prior outcome — rizzler-style. Cache is gitignored.
- A smoke test runs on each resolved file after the resolver finishes (the repo's build command scoped to the file's module, if detectable). Regression rolls the file back to a `DESIGN_CONFLICT:` outcome.

Provider selection and token strategy live in `references/prompts.md`.

## Mergify gating

Four constraints, all must hold, or the PR waits for human review.

1. `build` green — the generated repo's build command succeeded.
2. `smoke-test` green — the generated repo's smoke-test command succeeded.
3. `drift-recheck` green — upstream's HEAD has not advanced past what we rebased against. Without this check we would merge resolutions that are already stale on arrival.
4. No `DESIGN_CONFLICT:` in the PR body. This is what lets humans catch the cases the resolver deliberately punted on.

Mergify is installed via its GitHub App at setup time (see `scripts/setup_fork.py`). No API token is needed in workflows; the app install provides auth. If the app is uninstalled later, auto-merge silently stops — the doctor checklist catches this.

## Edge cases to handle when extending

The design has known failure modes. Any change to the skill must preserve or explicitly address these.

**Upstream force-pushes its history.** The `upstream-sync/<date>-<sha>` tag is created before the `upstream` branch is updated, so every SHA we imported stays reachable. The next sync picks up whatever upstream's new HEAD is and rebases patches onto it. Worst case, the user rolls back via `git checkout upstream-sync/<date>-<sha>`. Do not reorder the tag-before-reset step.

**Upstream repo deletion.** Full clone = full object store. The repo remains self-contained; only future syncs break. The sync workflow should fail loudly with a clear "upstream unreachable" message rather than silently stalling. Doctor mode flags this via the `recent_sync` check.

**Branch protection conflicts.** If the user manually tightens branch protection on `main` to require reviews, Mergify's auto-merge stops working. This is the user's call, not a bug — but the doctor check should surface the required-checks list and flag drift from the setup-time configuration.

**Mergify App uninstalled.** Silent failure mode: PRs pile up, never auto-merge. Doctor check `mergify_yml` verifies the file exists and is valid YAML; add a companion GitHub-API check (`gh api /repos/<owner>/<repo>/installation` or equivalent) before calling doctor complete.

**LLM rate limits / quota exhausted.** The resolver should fail loudly with the provider's error propagated into a `DESIGN_CONFLICT: LLM unavailable: <reason>` marker. The sync PR then opens `needs-human`. Do not retry indefinitely — that burns money and hides the outage. The resolution cache absorbs repeated shapes across syncs and softens rate-limit exposure for common drifts.

**Workflow-name collision with upstream.** Upstream ships a `fork-something.yml` of their own. Pre-flight in `scripts/setup_fork.py` scans upstream's `.github/workflows/` for `fork-*.yml` names and refuses to proceed. If a future upstream commit introduces such a file, the next sync surfaces it as a conflict (both files try to exist at the same path). Doctor check `workflows_present` verifies our three files are still there unmodified.

**Binary file conflicts.** The resolver refuses and emits `DESIGN_CONFLICT: binary file`. See `references/prompts.md` §binary files.

**Simultaneous runs of the sync workflow.** GitHub's `concurrency:` block on the workflow prevents overlap; one cron tick yields if the previous one is still running. If a manual `workflow_dispatch` collides with the cron, the second run is cancelled. Do not remove the concurrency block when editing the template.

## Cross-references

- `SKILL.md` — entry point for the skill, both setup and doctor modes.
- `references/examples.md` — prior-art repos we studied and what we borrowed from each.
- `references/doctor-checklist.md` — full audit list for doctor mode.
- `references/prompts.md` — LLM resolver prompt design, provider-specific tuning, eval ideas.
- `templates/fork/references/architecture.md.tmpl` — the user-facing architecture doc that ships into generated repos. Keep that one shorter and framed around "what you can do with the repo"; keep this one framed around "how to change the skill itself."
