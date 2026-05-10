# ADR 0001 — Downstream fork repo architecture

- Status: **In development** (not yet shipped; subject to change while SKILL.md is being written)
- Date: 2026-04-17
- Deciders: Prateek
- Related: [../dev/setup-downstream-fork-plan.md](../dev/setup-downstream-fork-plan.md)
- Related skill: `~/dotfiles/.agents/skills/setup-downstream-fork/`
- History: merged with the short-lived ADR 0003 (git-subrepo experiment — rejected, see "Options considered" below).

## Context

The `setup-downstream-fork` skill generates a repo that holds a downstream fork of an upstream open-source project plus local customizations, and keeps it synced to upstream via CI with an LLM resolving the boring conflicts. The architecture has to answer five questions at once:

1. How do upstream code and fork-authored scaffolding coexist in one repo without colliding?
2. How does the sync mechanism produce conflict artifacts the LLM can act on?
3. How does a local developer (human or LLM) iterate on a fork patch?
4. How is the fork's state ("upstream SHA + patch inventory") legible at a glance?
5. How does the design scale from small CLIs to mid-size projects?

Priorities in order: cruise control, auditable patch inventory, easy upstream contribution, durable rollback, upstream commits visible individually, LLM-native repo.

Out of scope: Chromium-scale forks (40GB+). Those need a patch-stack-without-vendoring approach and will get a separate ADR when they become relevant.

## Options considered

Four repo-layout options and one tool alternative were weighed.

### Option A — Clone-as-base, scaffolding at root

Repo is `git clone <upstream>`. Fork scaffolding (AGENTS.md, `.github/`, `tools/`, `patches/`) lives directly at the root, alongside upstream files.

- **Con**: direct collisions with upstream's `.github/`, `tools/`, `MAINTAINERS`, etc. Requires hand-merging scaffolding into upstream's files.
- **Rejected**: collision risk is too high for anything bigger than a toy fork.

### Option B — Vendored subdir via `git subtree`

Upstream vendored into `vendor/` or similar via `git subtree add --squash`. Scaffolding at root.

- **Pro**: zero root collisions.
- **Con**: build systems usually expect the project at root, so you rewrite every build invocation; `--squash` loses upstream git history; `git subtree`'s commands are verbose and error-prone.
- **Rejected**: subtree ergonomics and the build-path rewrite together outweigh the namespace benefit.

### Option B′ — Vendored subdir via `git-subrepo`

Same shape as B but using [`git-subrepo`](https://github.com/ingydotnet/git-subrepo), which is a better-ergonomics wrapper with a `.gitrepo` metadata file and first-class `subrepo pull` / `subrepo push`.

We smoke-tested this end-to-end (see `/tmp/fork-smoketest/` if still present). It works and addresses B's ergonomics issues, but it squashes upstream commits on every sync — the fork's main-branch history does NOT contain upstream's individual commits. The user explicitly values seeing upstream's commits individually.

**Subrepo vs subtree** (the comparison from the rejected ADR 0003):

| | `git subtree` (built-in) | `git-subrepo` (third-party) |
|---|---|---|
| Install | part of git | `brew install git-subrepo` (single bash script) |
| Metadata on disk | none | `<subdir>/.gitrepo` records remote, branch, SHA |
| History storage | merge commits OR `--squash` loses upstream history | always squashes; SHA preserved in `.gitrepo` |
| Pull | `git subtree pull --prefix=src upstream main --squash` | `git subrepo pull src` |
| Push back upstream | awkward | `git subrepo push src --branch <feat>` |
| Conflict surface | native merge markers in subdir | native merge markers in recovery worktree |

`git-subrepo` beats `git subtree` on every dimension that matters, so if we went B-shaped we'd pick subrepo. But both squash upstream commits, which the user rejected.

- **Rejected**: squashing upstream commits is a deal-breaker.

### Option C — Clone-as-base, inverted `.fork/` subdir (chosen)

Repo is `git clone <upstream>`. Upstream files stay at root (paths match upstream, contents may carry fork patches). Fork scaffolding lives under `.fork/` — a single namespace the user owns entirely — containing: `AGENTS.md` (fork contract), `README.md` (fork-specific human docs), `upstream-AGENTS.md` (preserved copy of upstream's AGENTS.md if any), `revision.txt` (current pinned upstream SHA), `patches/` (derived flat-file inventory), `snapshots/` (per-sync audit JSONs), `references/` (LLM-consumable docs — resolver prompt, doctor checklist, patch vocabulary), `tools/` (sync + resolver scripts), `skills/` (repo-local agent skills), `.llm-cache/` (gitignored, resolver resolution cache).

The only forced exception to the `.fork/` namespace is `.github/workflows/`, which GitHub requires at root; we prefix our files `fork-*.yml` to avoid collisions with upstream's workflow names, and pre-flight setup fails loudly if there is any collision.

Two root-level additions for agent discovery, not in `.fork/`:
- **`AGENTS.md` (root)** — a ~20-line pointer that routes agents to `.fork/AGENTS.md` for the full fork contract.
- **`CLAUDE.md` (root)** — symlink to `AGENTS.md`.
- **`.claude/skills → ../.fork/skills`** — symlink so Claude Code auto-discovers the repo-local skills.
- **`.agents/skills → ../.fork/skills`** — symlink so Codex auto-discovers the same.

If upstream ships its own root `AGENTS.md`, setup captures it as a fork-patch commit (`Fork-Patch: agents-md` + `Reason: AGENTS.md at root must route agents to the fork contract`) that moves upstream's original to `.fork/upstream-AGENTS.md` and replaces the root file with our pointer. The patch re-applies like any other on each sync.

`.mergify.yml` also lives at repo root (Mergify's required location) and is tracked as a regular fork-authored file.

Branches:
- `upstream` — pristine mirror, force-updated to upstream's HEAD on every sync.
- `main` — upstream + fork patches applied as regular commits on top, each carrying a `Fork-Patch: <slug>` + `Reason: <why>` trailer.

Sync happens on a short-lived `sync/<date>-<sha>` branch (detail below), not directly on `main`.

Fork repo naming: default to upstream's repo name unchanged (so `charmbracelet/glow` → `<you>/glow`). The owner path is the disambiguator, matching the VoiceInk pattern (`metrovoc/VoiceInk`). Setup falls back to `<repo>-fork` only when there's a name collision in your own namespace, and accepts any user-provided override.

Patches are git commits, not files. A derived `.fork/patches/` directory is regenerated on every sync by `git format-patch` for flat-file inventory — same content, different presentation.

- **Pro**: best dev UX (edit files at root like any normal repo); upstream commits visible individually on both `upstream` and as ancestors on `main`; native merge markers on conflict; patches upstreamable as-is; file paths match upstream exactly.
- **Pro**: scaled well in real-world precedent (VoiceInk, jito-solana, valgrind-macos).
- **Con**: `.github/workflows/` naming discipline is a real surface — document explicitly.
- **Con**: rebasing patches on sync means SHAs change per sync; we mitigate via `upstream-sync/*` tags and a non-force-pushed `main` (see "Mitigations").

### Option D — Patches-only, no vendoring

Repo contains only `patches/*.patch` files, a `series` file, `revision.txt`, and scaffolding. Upstream is not in the repo. CI and local dev materialize upstream fresh at build time.

- **Pro**: tiny repo regardless of upstream size; best build reproducibility (sealed patch set + pinned SHA); only architecture that scales to Chromium.
- **Con**: not fully self-contained (needs upstream remote alive); worse local dev UX — developer edits in a separate gitignored working directory and extracts changes back.
- **Real-world**: Cromite, Ungoogled Chromium, VSCodium, Debian packaging.
- **Rejected as default**: the target user isn't forking Chromium; dev UX hit isn't worth it. Retained as future opt-in for >2GB upstreams.

## Logical model

Two ways to organize a long-lived fork:

### Model A — Patch stack (rebase-like)

Fork state is conceptually `upstream_at_SHA + [patch_0, patch_1, ...]`. Patches are first-class objects with names and reasons. When upstream advances, patches are replayed onto the new upstream. A conflict is in a specific named patch. Rollback is "pin SHA + patch set."

### Model B — Merge timeline

Fork is a branch that diverged from upstream at some point. Sync = merge upstream into the branch. No patches per se — just commits in a DAG. Conflicts are three-way merges. Rollback is "check out any past merge commit."

**Chosen model: A (patch stack), expressed via git commits + the `Fork-Patch:` trailer convention + a derived `.fork/patches/` directory.** Gives the LLM a bounded unit of work ("this patch failed to apply, fix it"), makes `ls .fork/patches/` the inventory, and makes any one patch upstreamable as a file.

## The sync mechanism (sub-decision)

Syncing on `main` directly forces a choice between force-pushing `main` (surprises anyone who cloned in between) and accumulating merge commits (bushier history, abandons Model A's linear feel).

**We do neither on `main` directly.** Each sync runs on a short-lived `sync/<date>-<sha>` branch:

1. Cron fetches upstream.
2. Tag `upstream-sync/<date>-<sha>` at upstream's current HEAD (before we touch anything — guarantees the SHA is durable even if upstream force-pushes).
3. Fast-forward or reset `upstream` branch to upstream HEAD.
4. Create `sync/<date>-<sha>` from `main`.
5. On the sync branch: `git rebase upstream`. Conflicts surface as native merge markers in source files. LLM resolver resolves; rebase continues.
6. On the sync branch: regenerate `.fork/patches/` via `git format-patch`, commit.
7. Push the sync branch; open PR against `main` via `peter-evans/create-pull-request`.
8. CI runs build + smoke test on the sync branch.
9. Mergify squash-merges the sync branch into `main` on green (HEAD-drift recheck against upstream first). `main` moves forward, no force-push.
10. Delete the sync branch.

`main` is only ever moved by merge from a sync branch, so it is effectively **never force-pushed**. Clones stay consistent. The sync branch is allowed to be force-pushed during resolution (the LLM may amend) because nobody else has it checked out.

One cost: `main`'s history shows one squash commit per sync rather than the individual rebased patch commits. Patch-level granularity is preserved on the `sync/*` branches (kept around via tags `sync/<date>-<sha>-merged`) and in `.fork/patches/` as flat files. Acceptable trade for never force-pushing the default branch.

## Where "upstream + patches applied" lives

**`main`.** There is no separate `published` branch. `main` IS the built tree that users clone and build from; it's upstream code with patches already applied as commits. Release tags (`release/<upstream-tag>`) snapshot `main` at each upstream version boundary.

Summary of persistent references:

| Ref | What | Lifecycle |
|---|---|---|
| `main` | upstream + patches applied (default branch) | append-only via sync-branch merges |
| `upstream` | pristine upstream HEAD mirror | force-updated on every sync |
| `upstream-sync/<date>-<sha>` | tag at each imported upstream SHA | permanent; durable rollback anchor |
| `sync/<date>-<sha>-merged` | tag marking each merged sync branch | permanent; patch-level history per sync |
| `release/<upstream-tag>` | tag at upstream version boundaries | permanent; stable release pointers |
| `.fork/revision.txt` | human-readable current upstream SHA + tag | rewritten on every sync |
| `.fork/patches/` | derived patch files (one per `Fork-Patch:`) | rewritten on every sync |

With this set, "what upstream + patches are we on?" answers in one shell command: `cat .fork/revision.txt && ls .fork/patches/`.

## Mitigations adopted (from the adversarial + subagent reviews)

1. **Sync tags for durable rollback.** `upstream-sync/<date>-<sha>` tagged before the `upstream` branch resets. Upstream force-pushes no longer threaten recoverability.
2. **Non-force-pushed `main`.** Sync workflow operates on a `sync/*` branch, merges to `main` only on green CI. Multi-machine and multi-user clones stay consistent.
3. **HEAD-drift recheck before merge** (jito-solana pattern). Re-fetch upstream right before Mergify merges; abort if upstream advanced during the PR lifetime.
4. **`.fork/snapshots/<date>.json`** per-sync audit log: records `(upstream_sha, pre_sync_main_sha, merged_commit_sha, ci_result, llm_resolutions)`. Machine-readable history of every sync's decisions.
5. **`revision.txt` at repo root** committed on `main`, auto-updated per sync. Always visible in GitHub's root file listing.
6. **Derived `.fork/patches/` directory.** Regenerated from `git format-patch upstream..main --grep='Fork-Patch:'`. Flat-file inventory for `ls`-style browsing and upstreamable patch files.

## Consequences

### Positive

- Dev UX matches plain git — edit at root, commit with `Fork-Patch:` trailer, push.
- Upstream commits visible via `git log upstream` (full, unsquashed history of upstream).
- Patch inventory legible by two mechanisms: commits with trailer, and derived flat files.
- Upstream contribution is one command: `tools/upstream-patch.sh <slug>`.
- Rollback is bit-exact via the sync-tag pair `(upstream-sync/<date>-<sha>, sync/<date>-<sha>-merged)`.
- No force-push of `main`. Safe for multi-machine use.
- Native LLM conflict surface (standard `<<<<<<<` markers in source files).
- No third-party git extension required; everything uses built-in git.
- LLM resolver is provider-agnostic — `LLM_PROVIDER=claude|openai` in env; the generated workflow passes through whichever secret matches. Single-model-per-run; no tiering in v1.

### Negative

- `main`'s log shows one squash commit per sync, not individual rebased patch SHAs. (Per-patch SHAs are still retrievable via `sync/*-merged` tags.) Acceptable tradeoff for the non-force-push property.
- `.github/workflows/` naming discipline: we commit to prefixing every generated workflow `fork-*.yml`. If upstream happens to ship a `fork-release.yml` themselves, the setup skill detects and fails loudly at pre-flight. Unlikely but documented.
- Root-level files sometimes owned by both upstream and fork (README.md, CODEOWNERS, .gitignore). Solution: fork-authored modifications of these are regular commits with `Fork-Patch:` trailers — treated the same as any patch. Does not break the model; does mean sync conflicts on these are possible.
- Clone size equals upstream size. Fine up to a few GB; for Chromium-scale we switch to Option D.

### Neutral

- `upstream` branch is force-updated every sync. This is by design; it's a mirror, not a branch anyone commits to.
- Doctor mode won't convert a non-`.fork/` existing fork automatically. Conversion is destructive enough to require explicit human decision.

## Open questions (still in flight while SKILL.md is rewritten)

- Exact smoke-test flow for Mergify's auto-merge gate (what check names, what order).
- Whether `.fork/snapshots/<date>.json` should also track LLM token cost per sync.
- How doctor mode should report drift when it detects an older-layout fork (`.fork/` missing, patches stored differently).
- Pre-flight threshold for suggesting Option D (the patch-stack-only variant) over Option C. Current guess is upstream repo >2GB.

## Revisit criteria

- Prateek starts forking upstreams >2GB routinely → formalize Option D as a documented alternative.
- Real-world issue with `fork-*.yml` naming discipline surfaces (upstream ships a file we collide with) → rethink workflow namespacing.
- LLM resolution cost becomes significant → revisit the resolution-cache design and whether commit-level or patch-file-level caching helps more.
- A new git tool (or git feature) meaningfully changes the tradeoff between subtree/subrepo/clone-based approaches → re-open the Options Considered section.
- Long-lived fork (say, 30+ patches) causes rebase churn to dominate sync time → consider moving from `main` commits to `.fork/patches/*.patch` as the source of truth (Option D-like).
