# Prior art reference

Concrete repo pointers for the future skill maintainer. Each entry: URL, one-line description, what we borrowed (or why we did not). Organized by the part of the design it inspired, not alphabetically.

## Rebase-onto-upstream + LLM-driven resolution

### VoiceInk — the core pattern

- Upstream: https://github.com/Beingpax/VoiceInk
- Downstream: https://github.com/metrovoc/VoiceInk

The load-bearing precedent for this whole skill. A macOS dictation app with a downstream fork that rebases onto upstream on a schedule and uses `claude-code-action` to resolve conflicts automatically.

What we borrowed:
- Clone-as-base layout — `metrovoc/VoiceInk` is a direct fork of the upstream repo, not a subrepo or patch stack.
- Rebase-onto-upstream as the sync primitive.
- A short root-level agent pointer (`CLAUDE.md` in VoiceInk; we use `AGENTS.md` with a `CLAUDE.md` symlink) that routes any coding agent to the fork contract.
- LLM-driven conflict resolution as the default path, human review as the fallback.
- The name-disambiguation approach: fork keeps upstream's repo name (`VoiceInk`), the owner path (`metrovoc/`) does the disambiguation.

What we changed:
- VoiceInk's scaffolding sits at root alongside upstream. We push it under `.fork/` to eliminate collision risk for larger upstreams.
- VoiceInk uses `claude-code-action` directly inside the workflow. We abstract the resolver into `.fork/tools/llm_resolve.py` so provider swaps (Claude ↔ OpenAI) do not require workflow edits.

## Auto-merge gating + HEAD-drift recheck

### jito-solana — Mergify tuning and the drift pattern

- https://github.com/jito-foundation/jito-solana

A downstream fork of Solana used by the jito validator fleet. Their Mergify config is the source of both the auto-merge pattern and the pre-merge HEAD-drift recheck we adopted.

What we borrowed:
- Mergify `queue_rules` with `check-success=build` + `check-success=smoke-test` as the auto-merge condition.
- The `drift-recheck` status check: re-fetch upstream right before merging; abort if upstream's HEAD has advanced past what we rebased against. Without this, a slow resolution chain can land stale code.
- Squash-merge as the queue method so `main`'s history stays one commit per sync.

## Two-branch layout precedent

### valgrind-macos

- https://github.com/LouisBrunner/valgrind-macos

Long-lived macOS fork of valgrind. Uses the `upstream` + working-branch layout we adopted nearly as-is.

What we borrowed:
- `upstream` branch as a pristine, force-updated mirror of upstream's HEAD.
- Working branch (`main` in our design) with fork patches applied as ordinary commits on top.
- The operational rule: nothing ever commits to the `upstream` branch directly.

## Patch application and escalation semantics

### Cromite — `git apply --reject` + sentinel markers

- https://github.com/uazo/cromite

A de-Google'd Chromium fork. Applies patches via `git apply --reject`, falls back to `wiggle` for fuzzy application, and uses inline sentinel markers when a patch cannot be salvaged.

What we borrowed:
- The escalation shape: try exact apply, fall back to a best-effort resolver, emit a sentinel marker (`DESIGN_CONFLICT:` in our design; Cromite uses its own) when the resolver bails.
- Structured `Reason:` trailers so the resolver (human or LLM) knows why a patch exists.

What we did *not* borrow:
- `wiggle`-based fuzzy application. Native git three-way merge markers plus an LLM are enough for the small-to-mid fork sizes this skill targets. Wiggle is worth revisiting if we ever add Option D (patches-only) support.

## Patch inventory as first-class artifact

### ungoogled-chromium — patch series + devutils

- https://github.com/ungoogled-software/ungoogled-chromium

Pure patch-stack fork: no vendoring, just `patches/*.patch` + a `series` file + devutils. This is the canonical implementation of Option D from ADR 0001.

What we borrowed:
- Named, ordered, first-class patch files as the human-facing inventory. We expose the same thing via a derived `.fork/patches/` directory, regenerated on every sync from the `Fork-Patch:` commits on `main`.
- The `series` file convention for ordering (shared with Debian quilt — see below).

Kept in the back pocket: if Prateek starts forking upstreams >2GB routinely, we reach for ungoogled-chromium's full shape rather than inventing something new.

### Debian quilt — the `series` file

- https://manpages.debian.org/quilt
- Real-world consumer: https://sources.debian.org/ (any Debian package's `debian/patches/`)

What we borrowed:
- The `series` file format — one patch filename per line, applied in order. We regenerate this file alongside the patch files on every sync so third-party `quilt`/`patch` tools can consume our patch inventory directly.

## Release tagging cadence

### VSCodium — per-upstream-tag releases

- https://github.com/VSCodium/vscodium

A telemetry-free build of VSCode. Releases track upstream's release tags one-to-one.

What we borrowed:
- The `release/<upstream-tag>` tag convention on our `main` branch, applied by `fork-build-release.yml` when upstream cut a release since the last sync.
- The `check_tags.sh` cadence idea — detect-release-and-snapshot as a separate concern from sync-on-HEAD. We fold this into the build workflow rather than a standalone script.

## Patch-staleness vocabulary

### Brave Browser — `gitPatcher.js`

- https://github.com/brave/brave-core/blob/master/build/commands/lib/gitPatcher.js

Brave maintains a large downstream patch set against Chromium. Their patcher classifies each patch into a small enum when applying, which is exactly the vocabulary an LLM resolver wants as structured input.

What we borrowed:
- The patch-staleness enum itself: `PATCH_CHANGED`, `SRC_CHANGED`, both-changed, clean-apply. Lives in `templates/fork/references/patch-vocabulary.md.tmpl` so generated repos ship it, and the resolver prompt references it by name.
- The idea that the resolver should receive classified conflict shape, not raw merge markers — structured context makes the model's reasoning tighter.

## Alternative resolver integrations

### claude-code-action

- https://github.com/anthropics/claude-code-action

Official GitHub Action for invoking Claude on a PR or issue.

How it fits:
- Used as an alternative resolver path in `templates/workflows/fork-conflict-resolve.yml.tmpl`, commented out by default.
- Uncomment if a user prefers the action-native flow over shelling out to `llm_resolve.py`. Tradeoff: less control over prompt structure and caching, but zero Python dependency in CI.
- VoiceInk uses it directly — see VoiceInk entry above for the reference implementation.

## Rejected with reference intact

### git-subrepo — better subrepo ergonomics, still squashes history

- https://github.com/ingydotnet/git-subrepo

A single-bash-script wrapper around `git subtree` with a `.gitrepo` metadata file, first-class `subrepo pull` / `subrepo push`, and saner commands overall.

Why it shows up here despite being rejected:
- ADR 0001 subsumed the short-lived ADR 0003 which proposed this tool. If a future maintainer wonders why we did not pick the obviously-better-ergonomics option, the answer is: it squashes upstream commits on every sync. Prateek values seeing upstream's commits one at a time. Smoke-test artifacts at `/tmp/fork-smoketest/` (may be cleaned up).
- If the "see upstream commits individually" requirement ever relaxes, `git-subrepo` becomes the right tool. Keep this pointer so that re-evaluation is cheap.

## Always-on standard tooling

### git `rerere`

- https://git-scm.com/docs/git-rerere

Enabled in every generated repo's CI environment. Caches past conflict resolutions so identical three-way merges resolve without LLM involvement. Free conflict-resolution speedup on top of our own `.fork/.llm-cache/`.

### peter-evans/create-pull-request

- https://github.com/peter-evans/create-pull-request

The GitHub Action the sync workflow uses to open PRs. Not borrowed conceptually — just the specific action we invoke. Pinned to a major version in the template.
