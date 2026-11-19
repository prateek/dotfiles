# Orca archive hook contract

Type: research
Status: resolved
Blocked by: none

## Question

Exactly what does Orca's `scripts.archive` hook give us as a done check?

Use Orca `main` source and docs (`ask src github:stablyai/orca@main`; start at `src/main/hooks.ts`, `src/main/effective-hook-config.ts`, `src/main/worktree-archive-hook-gate.ts`, `src/main/runtime/runtime-registered-local-worktree-removal.ts`, `src/main/ipc/worktrees/removal/execute-worktree-removal.ts`) and answer:

1. **Inputs.** What environment variables, cwd, and arguments does the script receive? Can it identify the worktree (path, Orca worktree id, repo id, host)?
2. **Blocking UX.**
   - What does the user see in the UI when it exits non-zero?
   - Is the script's output shown, how is the override offered, and is there a timeout?
3. **Coverage.** Which removal paths run it:
   - UI archive vs delete
   - `orca worktree rm` with and without `--run-hooks`
   - SSH-host and paired-server (remote) worktrees: where does the script execute?
4. **Installation.**
   - How do per-repo local hook settings (`hookSettings.scripts.archive`, `commandSourcePolicy`) combine with a committed `orca.yaml` archive script?
   - Can chezmoi's `modify_orca-data.json.tmpl` safely install a local archive hook for every registered repo, and what happens for repos registered later?
5. **Other points.** Is there any other lifecycle point (card status → `completed`, workspace sleep, terminal close) with a hook or plugin event we could use?

Cite file:line for each answer. Capture findings in `research/orca-archive-hook.md`.

## Answer

Findings: [research/orca-archive-hook.md](../research/orca-archive-hook.md).

**The archive hook is a usable but leaky v1 done check.**

- **Inputs.** It runs as `/bin/bash -c` with cwd set to the worktree and gets `ORCA_WORKTREE_PATH`, `ORCA_ROOT_PATH` and `ORCA_WORKSPACE_NAME`. It gets no worktree id, repo id or host. It must derive the id (`<repoId>::<path>`) from `orca repo list --json`, and the host from `hostname`.
- **Blocking.** A non-zero exit, a timeout (120 s) or a signal refuses removal before anything is touched. The UI toast shows the script's stdout and stderr and offers **Delete Anyway**, which re-runs the hook and accepts its failure. Force Delete never overrides the hook.
- **Gaps.** The hook is skipped when:
  - `orca worktree rm` runs without `--run-hooks`.
  - The UI trust prompt for a committed `orca.yaml` is declined. That also skips any local script.
  - The user picks UI Forget.
  - The worktree's git record is stale, it's a folder workspace, or it's removed outside Orca.
- **Remote worktrees.**
  - For SSH worktrees, the UI runs the script on the SSH host (`bash -lc`), so the binary must exist there. The CLI `--run-hooks` refuses SSH worktrees unless you pass `--allow-failed-archive-hook`.
  - For worktrees on a paired server, the hook runs on the server with the server's settings.
- **Installation.**
  - Chezmoi can't install the hook. `orca-data.json` is dead, and live state is `profile-state.db` (SQLite). Editing the JSON triggers a recovery prompt, and no public CLI writes `hookSettings`.
  - A local script with an unset `commandSourcePolicy` silently drops the committed `orca.yaml` archive hook, so installs must set `run-both` and put our check last.
  - What's viable: detect repos that lack the hook via `orca repo list --json` and print a one-time Settings step, or commit an `orca.yaml` in personal repos.
- **Other lifecycle points.** None can block. The plugin `worktree.removed` event fires after removal and could drive archiving resolved items. Card status has no hook or event.
