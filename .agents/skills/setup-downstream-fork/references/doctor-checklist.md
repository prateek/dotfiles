# Doctor mode checklist

Full list of checks `scripts/doctor.py` runs against an existing fork. Each entry has an ID (matches the script), description, how to check, and how to fix. Report format per item is `✓ ok / ⚠ fixable / ✗ broken`.

Check IDs are stable contracts between this doc and `scripts/doctor.py`. Do not rename one without updating the other.

## `branches_upstream`

**What it checks.** The `upstream` branch exists locally (and on the remote), points at a SHA reachable in upstream's public repo, and contains no fork-authored commits.

**Check.** `git rev-parse --verify upstream`; `git log upstream --grep='Fork-Patch:'` returns empty; `git ls-remote <upstream-url> HEAD` matches `git rev-parse upstream` (or a recent ancestor).

**Fix.** If the branch is missing, recreate from the upstream remote: `git fetch upstream && git branch upstream upstream/<default-branch>`. If it contains fork commits, it was misused; reset it to upstream HEAD and move the stray commits to a new branch for investigation. Destructive — ask the user before resetting.

## `branches_main`

**What it checks.** `main` exists, is the default branch, and descends from some ancestor present on `upstream`. All commits between `upstream..main` either carry a `Fork-Patch:` trailer or are sync squash-merge commits.

**Check.** `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main`; `git merge-base main upstream` returns a valid SHA; `git log upstream..main --format='%H %s %(trailers:key=Fork-Patch)'` — every commit has the trailer or is a merge.

**Fix.** Missing or untrailered commits mean someone landed work outside the patch-stack convention. Do not auto-rewrite history. Report the specific commits to the user and ask whether to add trailers retroactively or accept the drift.

## `fork_dir`

**What it checks.** `.fork/` exists and contains the expected subtree: `AGENTS.md`, `revision.txt`, `tools/`, `skills/`, `references/`, `patches/`, `snapshots/`. `.fork/.llm-cache/` may exist.

**Check.** `test -d .fork` and each required child.

**Fix.** For missing subdirectories, render the template from `templates/fork/` into place. If `.fork/` itself is absent the fork predates this skill; doctor reports the situation and stops rather than auto-converting (conversion is destructive).

## `root_agents_md`

**What it checks.** Root `AGENTS.md` exists and is the short pointer to `.fork/AGENTS.md`, not upstream's own AGENTS.md.

**Check.** File exists, is under ~30 lines, contains the string `.fork/AGENTS.md`. If longer or missing the pointer, it is likely upstream's original.

**Fix.** Capture any existing content as `.fork/upstream-AGENTS.md` if not already saved, then render the root pointer template. Commit with `Fork-Patch: agents-md`.

## `root_claude_md`

**What it checks.** Root `CLAUDE.md` is a symlink to `AGENTS.md`.

**Check.** `test -L CLAUDE.md` and `readlink CLAUDE.md` equals `AGENTS.md`.

**Fix.** Remove any regular file at `CLAUDE.md`, create the symlink: `ln -sf AGENTS.md CLAUDE.md`.

## `skill_discovery_symlinks`

**What it checks.** `.claude/skills` and `.agents/skills` both exist and symlink to `../.fork/skills`.

**Check.** `test -L .claude/skills && readlink .claude/skills == "../.fork/skills"`; same for `.agents/skills`.

**Fix.** `mkdir -p .claude .agents && ln -sf ../.fork/skills .claude/skills && ln -sf ../.fork/skills .agents/skills`.

## `workflows_present`

**What it checks.** All three workflows exist under `.github/workflows/` with the `fork-*.yml` prefix: `fork-upstream-sync.yml`, `fork-build-release.yml`, `fork-conflict-resolve.yml`. Each is syntactically valid YAML.

**Check.** File existence + `python -c "import yaml; yaml.safe_load(open(p))"` per file.

**Fix.** Re-render the missing file from `templates/workflows/`. If present but invalid YAML, report the parse error and ask the user whether to restore from template (destructive — local edits will be lost).

## `mergify_yml`

**What it checks.** `.mergify.yml` exists at repo root, parses as YAML, declares the `fork-sync` queue rule, and includes the `body~=DESIGN_CONFLICT:` exclusion.

**Check.** YAML parse; search for `queue_rules` entry named `fork-sync`; search for `"-body~=DESIGN_CONFLICT:"` in the auto-merge rule's conditions.

**Fix.** Re-render from `templates/.mergify.yml.tmpl`. Bonus check: verify the Mergify GitHub App is installed on the repo (`gh api /repos/<owner>/<repo>/installation` or equivalent) and offer the install link if not.

## `patches_synced`

**What it checks.** The flat-file inventory at `.fork/patches/` matches what `git format-patch upstream..main --grep='Fork-Patch:'` would produce right now.

**Check.** Run `git format-patch upstream..main --grep='Fork-Patch:' --stdout | sha256sum` against a deterministic concatenation of `.fork/patches/*.patch`. Compare. Also verify `.fork/patches/series` lists files in the same order.

**Fix.** `./.fork/tools/export-patches.sh` regenerates the directory. Commit as a housekeeping change.

## `recent_sync`

**What it checks.** The most recent `upstream-sync/*` tag is within the cron cadence plus a grace window (default: within 14 days).

**Check.** `git for-each-ref --sort=-creatordate --count=1 'refs/tags/upstream-sync/*'` and parse the embedded date; diff against today.

**Fix.** Not automatic. Warn the user that syncs have stalled. Common causes: workflow disabled, cron secret rotated, Mergify uninstalled, upstream unreachable. Doctor prints the last three sync workflow run statuses via `gh run list --workflow=fork-upstream-sync.yml --limit 3` to speed diagnosis.

## `snapshots_valid`

**What it checks.** Every `.fork/snapshots/<date>-<sha>.json` parses as JSON and has the required fields: `upstream_sha`, `pre_sync_main_sha`, `merged_commit_sha`, `ci_result`, `llm_resolutions`.

**Check.** Walk the directory, `json.load()` each file, assert required keys present.

**Fix.** Malformed snapshots are usually an aborted sync. Report path + first parse error. Ask the user whether to delete (safe — snapshots are audit log only, not load-bearing for future syncs).

## `release_tags`

**What it checks.** For each upstream release tag since the fork started tracking upstream, a matching `release/<upstream-tag>` exists on `main`.

**Check.** `git tag -l` on upstream release pattern (heuristic: `v*`) vs `git tag -l 'release/*'`. Diff.

**Fix.** Missing release tags mean `fork-build-release.yml` did not run or failed during the window that tag appeared. Not auto-fixable — requires re-running the build workflow against the target SHA. Report the gap list for manual catch-up.

## `llm_cache_gitignored`

**What it checks.** `.fork/.llm-cache/` is in `.gitignore` and not tracked by git.

**Check.** `git check-ignore .fork/.llm-cache/` returns match; `git ls-files .fork/.llm-cache/` returns empty.

**Fix.** Append `.fork/.llm-cache/` to `.gitignore`. If cache files were already committed, remove with `git rm -r --cached .fork/.llm-cache/` and commit the cleanup.

## `architecture_mismatch`

**What it checks.** The fork uses this skill's Option C layout (clone-as-base + `.fork/` namespace + patches-as-commits).

**Check.** Heuristic: `.fork/` exists AND `upstream` branch exists AND at least one `Fork-Patch:` trailer is present in recent history. If `.fork/` is missing but upstream+main both exist, it is probably a VoiceInk-style earlier fork. If neither `.fork/` nor trailers exist but `patches/*.patch` is present at root, it is probably a Cromite/ungoogled-chromium patch-stack fork.

**Fix.** **Never auto-convert.** Report to the user: "this looks like a <pattern> fork, not an Option C fork. This skill would have built differently. Conversion is destructive; recommend manual migration." Stop. The user decides.

## Execution order and stop conditions

Run in the order listed. If `architecture_mismatch` reports a non-Option-C layout, skip every subsequent check and bail — the other checks assume Option C semantics and would misreport. Everything else runs to completion regardless of individual failures; the final report lists all findings at once so the user can fix in a single pass.
