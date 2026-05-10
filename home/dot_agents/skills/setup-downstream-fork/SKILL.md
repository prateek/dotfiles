---
name: setup-downstream-fork
description: "Set up or maintain an LLM-driven downstream fork of an upstream git project. Use when the user wants to fork a CLI/app/library, layer custom patches on top, and have the fork auto-track upstream via CI with an LLM resolving conflicts. Two modes: setup (clone upstream, scaffold .fork/, wire up GitHub Actions + Mergify, kick off first sync) and doctor (audit + fix an existing fork). Generates a clone-as-base repo where upstream files live at root, your scaffolding lives under .fork/, patches are git commits with Fork-Patch: trailers, and cruise-control is driven by three GitHub workflows + Mergify gating. Provider-agnostic LLM resolver (Claude or OpenAI). Trigger on phrases like 'fork upstream X', 'set up a downstream of Y', 'maintain a custom build of Z', 'auto-sync my fork', 'patch stack repo', 'cruise control fork', 'set up sync workflow for my fork'."
---

# setup-downstream-fork

A skill for spinning up — and keeping healthy — a downstream fork of an upstream open-source project. The generated repo runs on cruise control: it tracks upstream daily, applies your patches, falls back to an LLM when patches drift, and only escalates to a human when a real design decision is needed.

Full architectural rationale is in `docs/adr/0001-downstream-fork-architecture.md` in the dotfiles repo. Plan doc with concrete workflow recipes is at `docs/dev/setup-downstream-fork-plan.md`. Read `references/architecture.md` in this skill for an LLM-oriented summary if you need to extend the skill itself.

## When to use

- The user wants to use an upstream tool (CLI, app, library) with their own customizations and have it stay current with upstream.
- The user already has a fork and it's drifting, breaking, or hard to maintain.
- The user references patterns like VoiceInk / Cromite / VSCodium / jito-solana.

Two invocation modes. Ask which one if unclear.

## Mode 1 — `setup` (greenfield)

Use when starting from scratch. The skill executes the whole scaffold: clones upstream, generates `.fork/`, creates the GitHub repo, configures secrets and branch protection, installs Mergify, kicks off the first sync.

### Step 1 — Gather inputs

Required:
- Upstream repo URL or `owner/repo`.
- Fork name (defaults to upstream's repo name; fall back to `<repo>-fork` if there's a name collision in the user's namespace).

Optional (sensible defaults):
- Upstream branch to track (default: upstream's default branch).
- Local path to create the fork (default: `$GHPATH/<your-gh-user>/<fork-name>`).
- GitHub org/user to create the repo under (default: authenticated `gh` user).
- LLM provider for the resolver — `claude` or `openai` (default: `claude`).
- Visibility — public or private (default: private).
- Sync cron expression (default: `0 6 * * *` — daily 06:00 UTC).

Auto-detected at pre-flight:
- Build system and smoke-test command. Read `Cargo.toml`, `package.json`, `pyproject.toml`, `go.mod`, `*.xcodeproj`, `Makefile`, `meson.build`, etc. Propose a one-liner; show the user before baking it into `.fork/tools/build.sh`. If detection fails, leave a `# TODO` and proceed.
- Language(s). Used to parameterize the resolver prompt.

If the user says "just go" or "use defaults," apply the defaults and don't block on confirmation.

### Step 2 — Pre-flight checks

Run in parallel. Fail loudly if any is broken.

- `gh auth status` — must have `repo`, `admin:repo_hook`, `workflow` scopes.
- `git --version` — needs ≥ 2.39.
- Upstream URL reachable: `git ls-remote <url> HEAD`.
- Target fork path doesn't already exist locally.
- `gh repo view <org>/<fork-name>` returns 404 (name is free); if not, offer `<repo>-fork`.
- Scan upstream's `.github/workflows/` for any `fork-*.yml` filenames. If any exist, fail loudly — we use that prefix and cannot silently collide.
- Upstream repo size < 2GB (via GitHub API). If larger, warn and recommend the patch-stack-only variant (not yet scoped; for now, just warn and proceed).
- Mergify GitHub App install status on the target org (offer to install if missing).

### Step 3 — Execute the scaffold

Call `scripts/setup_fork.py` to do the heavy lifting. Narrate as phases run.

1. **Clone upstream** into the target path; rename remote `origin` → `upstream`. Tag `upstream-sync/<date>-<sha>` at current HEAD.
2. **Create `upstream` branch** from current HEAD as a pristine mirror.
3. **Create `main` branch** from `upstream`.
4. **Write `.fork/` scaffolding** by rendering every file in `templates/fork/` with the gathered inputs. Includes `AGENTS.md`, `README.md`, `revision.txt`, `references/*`, `skills/*`, `tools/*`.
5. **Write root pointer files**: `AGENTS.md` (routes to `.fork/AGENTS.md`) + `CLAUDE.md` (symlink). If upstream already had a root `AGENTS.md`, move it to `.fork/upstream-AGENTS.md` first.
6. **Write `.github/workflows/fork-*.yml`** and `.mergify.yml` from `templates/`.
7. **Write `.gitignore`** entries for `.fork/.llm-cache/` and typical language build artifacts.
8. **Create the skill-discovery symlinks**: `.claude/skills → ../.fork/skills` and `.agents/skills → ../.fork/skills`.
9. **Commit everything** as a single `Fork-Patch: initial-scaffold` commit on `main`. Reason: `initial fork-maintainer scaffold targeting <upstream>@<sha>`.
10. **Create GH repo**: `gh repo create <org>/<fork-name> --source=. --remote=origin --push`. Push both `main` and `upstream` branches and all tags.
11. **Configure GitHub side**:
    - Enable auto-merge on the repo.
    - Enable Actions.
    - Add secrets: `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (whichever provider the user picked). Store via `gh secret set`.
    - Set branch protection on `main`: require the `build`, `smoke-test`, and `drift-recheck` status checks; require PRs (no direct pushes); allow auto-merge.
    - Install/enable Mergify App on the repo (link to the install flow if not already installed org-wide).
12. **Trigger first sync**: `gh workflow run fork-upstream-sync.yml`. Verifies the pipeline is wired.

### Step 4 — Hand-off

Print:
- Local path + GH URL.
- Time of next cron tick.
- Two commands the user will use day-to-day:
  - `cd <fork> && .fork/tools/sync.sh` — manual sync trigger.
  - `cd <fork> && claude` — opens any agent with the repo skills already in place.

Then stop. Don't add features the user didn't ask for.

## Mode 2 — `doctor` (audit + fix)

Use when the user has an existing fork and wants to check it or upgrade it to this skill's conventions.

### Audit checks

Run `scripts/doctor.py`. For each item report **✓ ok / ⚠ fixable / ✗ broken**. See `references/doctor-checklist.md` for the full list; here's the spine:

- Branch layout: `upstream` exists and matches a reachable upstream SHA; `main` exists and descends from an import of that SHA.
- `.fork/` directory exists with `AGENTS.md`, `revision.txt`, `tools/`, `skills/`, `references/`, `patches/`, `snapshots/`.
- Root `AGENTS.md` is the pointer (short, routes to `.fork/AGENTS.md`), not upstream's.
- `CLAUDE.md` symlinks to `AGENTS.md`.
- `.claude/skills` and `.agents/skills` symlink to `../.fork/skills`.
- `.github/workflows/fork-*.yml` — all three present and syntactically valid YAML.
- `.mergify.yml` present and includes the `fork-sync` queue rule.
- Patches in `.fork/patches/` match `git format-patch upstream..HEAD --grep='Fork-Patch:'` output.
- Last `upstream-sync/*` tag is within the last 14 days (warn if older).
- Every `.fork/snapshots/<date>-<sha>.json` has the required fields.
- Tags `upstream-sync/*`, `sync/*-merged`, and `release/*` exist as expected.
- `.fork/.llm-cache/` is gitignored (not accidentally committed).

### Fix mode

After the audit, ask which findings to fix. For each, make the smallest possible change.

If the fork uses a genuinely different architecture (single-branch rebase like VoiceInk without the `.fork/` namespace, pure patch-stack like Cromite, etc.), **don't try to convert it automatically**. Tell the user what they have, what this skill would have built differently, and stop. Conversion is destructive enough to deserve an explicit human decision.

## How the generated repo runs on cruise control

The generated repo holds three GitHub Actions workflows plus `.mergify.yml`. Between them:

1. **Cron tick** (default daily): `fork-upstream-sync.yml` runs. Fetches upstream; if its HEAD matches `.fork/revision.txt`, exits clean.
2. **Tag + reset**: tags `upstream-sync/<date>-<sha>` at upstream's current HEAD (durable rollback anchor), then fast-forwards the `upstream` branch.
3. **Sync branch + rebase**: creates `sync/<date>-<sha>` from `main`, rebases onto the new `upstream`. On conflict, each conflict file is handed to `.fork/tools/llm_resolve.py`.
4. **Resolve**: resolver reads `.fork/references/resolver-prompt.md`, the fork contract from `.fork/AGENTS.md`, and the conflicted commit's `Fork-Patch:` + `Reason:` trailers. Writes either the resolved file or inline `DESIGN_CONFLICT: <reason>` markers.
5. **Export + snapshot**: regenerate `.fork/patches/` via `git format-patch upstream..HEAD --grep='Fork-Patch:'`; write `.fork/snapshots/<date>-<sha>.json` with upstream SHA, pre-sync main SHA, and per-file resolution outcomes.
6. **PR**: open against `main` via `peter-evans/create-pull-request`. If any `DESIGN_CONFLICT:` markers exist, copy them into the PR body under `### DESIGN_CONFLICT:` and add `needs-human` label + file a tracking issue. Otherwise add `automerge` label.
7. **CI**: `fork-build-release.yml` runs build + smoke test; also runs `drift-recheck` (re-fetches upstream, fails if HEAD advanced past the snapshot SHA).
8. **Mergify**: squash-merges on `check-success=build` + `check-success=smoke-test` + `check-success=drift-recheck` + `-body~=DESIGN_CONFLICT:`. Tag `sync/<date>-<sha>-merged`.
9. **Release**: if upstream cut a tag, tag `release/<upstream-tag>` on `main`.

Main never force-pushed. Every sync point is durably tagged. Rollback is `git checkout upstream-sync/<date>-<sha>` or `sync/<date>-<sha>-merged`.

## LLM resolver

`templates/tools/llm_resolve.py.tmpl` is the reference implementation. Provider-agnostic (Claude or OpenAI via `LLM_PROVIDER` env). Single model per run, bounded turns. Local cache at `.fork/.llm-cache/` keyed on `(file_path, pre_context_hash, post_context_hash)` — replay on match. Returns resolved file content or `DESIGN_CONFLICT: <reason>` inline.

## Files in this skill

- `SKILL.md` — this file.
- `scripts/setup_fork.py` — executor for Mode 1.
- `scripts/doctor.py` — executor for Mode 2.
- `templates/fork/` — prose templates (AGENTS.md, README.md, revision.txt, references/*, skills/*).
- `templates/workflows/` — the three `fork-*.yml.tmpl`.
- `templates/.mergify.yml.tmpl`.
- `templates/tools/` — shell scripts + `llm_resolve.py.tmpl`.
- `references/architecture.md` — long-form of ADR 0001 for an LLM extending the skill.
- `references/examples.md` — pointers to VoiceInk, jito-solana, Cromite, VSCodium, Brave, Mergify docs.
- `references/doctor-checklist.md` — full doctor-mode audit list.
- `references/prompts.md` — resolver prompt templates (separate from the `.fork/references/resolver-prompt.md` shipped to generated repos).
- `evals/evals.json` — test cases.

## Tone

Narrate concretely as you go. Tell the user what you're about to do, then do it. Don't ask permission for every setup step — they signed up for the whole flow. Do ask before destructive doctor-mode fixes.
