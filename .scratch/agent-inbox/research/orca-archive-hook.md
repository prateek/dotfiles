# Orca archive hook contract

Research for [issue 02](../issues/02-orca-archive-hook-contract.md). Written 2026-09-29.

Sources:

- Orca `main` source from the `ask` cache at `~/.cache/ask/github/github.com/stablyai/orca/main` (refreshed 2026-09-29). Paths below are relative to that root.
- The local CLI, Orca 1.4.215: `orca worktree rm --help` and `orca repo list --json`. Both are read-only.
- The dotfiles chezmoi source under `home/`.

No bundled app code was read.

## Bottom line

- The archive hook is a real, blocking pre-removal gate for the desktop UI's Delete action on local worktrees. A non-zero exit refuses the removal before anything is stopped or deleted, and the desktop shows the script's output with a "Delete Anyway" waiver.
- The hook is not a complete done check. It is skipped when:
  - the CLI runs without `--run-hooks`;
  - the trust prompt is declined or errors;
  - you use forget-local;
  - the registration is stale or unregistered;
  - the workspace is a folder workspace;
  - the removal happens outside Orca.
- The CLI/runtime path cannot run it at all for SSH worktrees.
- It gets paths only (`ORCA_WORKTREE_PATH`, `ORCA_ROOT_PATH`, `ORCA_WORKSPACE_NAME`). It gets no worktree id, repo id, or host.
- Installing it through chezmoi's `modify_orca-data.json.tmpl` is **not viable**. The template targets a dead legacy file. Even the live profile's JSON is only a compatibility export of SQLite, and a hand-edited copy trips a startup divergence refusal. No public CLI or RPC writes `hookSettings`.

## 1. Inputs

The local path (desktop IPC and runtime/CLI) uses `runHook` (`src/main/hooks.ts:203-352`):

- **Script source**: `getEffectiveHooks(repo, hooksPath)`. Removal callers pass no `hooksPath`, so the committed `orca.yaml` is read from `repo.path`, the **primary checkout**, not from the worktree being removed (`src/main/hooks.ts:167-170`, `src/main/ipc/worktrees/removal/execute-worktree-removal.ts:193`, `src/main/runtime/runtime-registered-local-worktree-removal.ts:60`).
- **cwd**: the canonical worktree path (`execute-worktree-removal.ts:209-215`, `runtime-registered-local-worktree-removal.ts:66-72`).
- **Shell**: `spawn(script, { shell: '/bin/bash' })`, which runs as `/bin/bash -c <script>`. This is non-login and non-interactive (`hooks.ts:106-112`, `hooks.ts:288-301`).
- **Arguments**: none. The whole effective script string is the `-c` body.
- **stdin**: ignored (`stdio: ['ignore', 'pipe', 'pipe']`, `hooks.ts:293`). The hook cannot prompt.
- **Environment**:
  - Orca's main-process `process.env`, plus `getSetupEnvVars` (`hooks.ts:263`), wrapped in `promptGuardShellEnv` to suppress git credential prompts (`hooks.ts:291-292`).
  - `getSetupEnvVars` adds `ORCA_ROOT_PATH` (the repo's primary path), `ORCA_WORKTREE_PATH`, `ORCA_WORKSPACE_NAME` (the worktree dir basename), and the compatibility aliases `CONDUCTOR_ROOT_PATH` and `GHOSTX_ROOT_PATH` (`src/main/setup-hook-env-vars.ts:14-23`).
- **WSL**: the same variables, path-translated, run through `runWslProcess` with bash (`hooks.ts:224-261`).
- **SSH (desktop IPC)**: `runRemoteArchiveHook` runs `/bin/bash -lc <script>` (a login shell) **on the SSH host** through the relay's `execNonInteractive`. cwd is the remote worktree path. The env is `getSetupRunnerEnvVars` (the same keys plus the forced credential-guard policy variable) (`src/main/ipc/worktrees/removal/worktree-archive-hook.ts:67-87`, `setup-hook-env-vars.ts:25-31`).

**Identifying the worktree.**

- **Path**: yes.
- **Orca worktree id**: no. `ORCA_WORKTREE_ID` is set only for agent terminals and agent hook services (for example `src/main/devin/hook-service.ts:78`), not for setup or archive hooks.
- **Repo id**: no.
- **Host**: no.

The worktree id is `<repoId>::<path>` (`src/shared/worktree/id.ts:25-27`, `58`). A hook can recover it from the path, for example through the CLI's `path:<path>` selector (`orca worktree rm --help` lists it), or by matching `ORCA_ROOT_PATH` against `orca repo list --json`. Host identity has to come from the machine itself (`hostname`).

## 2. Blocking UX

**Exit semantics.**

- `classifyHookProcessResult` treats a zero exit as success.
- A non-zero exit becomes `success: false` with an `exitCode`.
- A signal, a spawn failure, or a timeout withholds the exit code, so the result is `unverifiable` (`hooks.ts:36-62`, `80-104`; `src/shared/worktree/archive-hook-removal-gate.ts:24-38`, `107-117`).
- Both outcomes block. Loss of contact is never read as a pass (`archive-hook-removal-gate.ts:24-30`).

**Ordering.** The gate is a precondition. It throws `WorktreeArchiveHookFailedError` (code `worktree_archive_hook_failed`) before any PTY stop, deregistration, or delete (`src/main/worktree-archive-hook-gate.ts:13-38`, `execute-worktree-removal.ts:197-223`, `runtime-registered-local-worktree-removal.ts:62-77`).

**Output shown?** Yes.

- The error message is `Archive hook failed for worktree: <path> — exited N.` followed by a fixed hint: "Nothing was stopped, deleted or deregistered. Fix the hook and retry, or delete anyway … 'Delete Anyway' in the app, or --allow-failed-archive-hook on the CLI."
- Then comes the hook's trimmed stdout and stderr (`archive-hook-removal-gate.ts:16-22`, `60-67`).
- Output is capped at 10 MiB per stream, with a truncation note (`hooks.ts:66-78`).

**Desktop UI.**

- `removeWorktree` catches the error and sets `canWaiveArchiveHook` when the message carries that prefix (`src/renderer/src/store/slices/worktrees/teardown/remove-worktree.ts:300-329`).
- The failure toast has no `forceDeleteReason` for this case, so it falls through to the generic copy: title "Failed to delete workspace X", description = **the full error string, including the hook output** (`src/renderer/src/components/sidebar/delete-worktree-toast.ts:133-141`).
- It is rendered as a destructive toast with a **"Delete Anyway"** button (`src/renderer/src/components/sidebar/delete-worktree-failure-toast.tsx:77-84`).
- "Delete Anyway" **re-runs the hook** and waives a failure on that run (`allowFailedArchiveHook: true`). It does not skip the hook (`src/renderer/src/components/sidebar/run-worktree-delete-with-toast.ts:55-58`).
- `force` / Force Delete never waives it (`cli/specs/core.ts:180`).

**CLI.**

- `--run-hooks` is required to run the hook.
- On failure the CLI exits non-zero with `worktree_archive_hook_failed`.
- `--allow-failed-archive-hook` deletes anyway and reports `result.archiveHookOverride`. It requires `--run-hooks` (`src/cli/specs/core.ts:176-181`; the same text appears in the local 1.4.215 `--help`).

**Timeout.**

- 120 s: `HOOK_TIMEOUT` (`hooks.ts:24`) and `ARCHIVE_HOOK_TIMEOUT_MS` (`archive-hook-removal-gate.ts:11`).
- On timeout the process group gets SIGTERM, then a forced kill after 2 s (`hooks.ts:332-349`).
- Timeout is `unverifiable`, so it blocks.
- A paired-client RPC waits 180 s (120 + 60) so it outlasts the hook (`src/renderer/src/store/slices/worktrees/teardown/dispatch-worktree-removal.ts:60-66`).

**Trust prompt (UI only).**

- Before removal, `ensureHooksConfirmed(…, 'archive')` runs (`remove-worktree.ts:93-103`).
- With policy `local-only`, it runs without a prompt (`src/renderer/src/lib/ensure-hooks-confirmed.ts:274-283`).
- Otherwise it hashes the **committed** `orca.yaml` archive script and prompts on first sight or on change (`ensure-hooks-confirmed.ts:284-297`, `103-151`). If no committed archive script exists, it runs without a prompt (`ensure-hooks-confirmed.ts:114-116`).
- Declining, dismissing, or a failed inspection returns `skip`. That sets `skipArchive = true`, which skips **the whole effective archive script, including a local one** (`ensure-hooks-confirmed.ts:289-291`, `300-303`; `execute-worktree-removal.ts:200`).

## 3. Coverage

| Removal path | Runs the hook? | Where it executes | Citation |
|---|---|---|---|
| Desktop UI Delete, local worktree (sidebar, context menu, workspace-cleanup batch) | Yes, unless the trust prompt returns `skip` | Local Orca main process, cwd = worktree | All entry points share `store.removeWorktree` (`remove-worktree.ts:49-56`; `workspace-cleanup-removal.ts:126`; `ssh-host-remove-workspaces.ts:39`) → IPC `worktrees:remove` → `executeWorktreeRemoval` (`register-worktree-removal-handlers.ts:41`, `execute-worktree-removal.ts:193-223`) |
| Desktop UI Delete, SSH worktree (`repo.connectionId`) | Yes | **On the SSH host**, `bash -lc`, via relay | `execute-worktree-removal.ts:207-208`, `worktree-archive-hook.ts:67-87` |
| Desktop UI Delete, worktree owned by a paired server / runtime environment | Yes (`runHooks: !skipArchive`) | **On the paired server's host**, which uses its own repo `hookSettings` and `orca.yaml` | `dispatch-worktree-removal.ts:45-59` → RPC `worktree.rm` → `runtime.removeManagedWorktree` (`src/main/runtime/rpc/methods/worktree.ts:248-253`) |
| UI "Forget" (forget-local, SSH host gone) | **No** | n/a | `remove-worktree.ts:94-96`, `dispatch-worktree-removal.ts:30-32`, `ForgetSshWorkspaceDialog.tsx:107` |
| `orca worktree rm` without `--run-hooks` | **No**. It logs `orca.yaml archive hook skipped …; pass --run-hooks` as `warning` and deletes | n/a | `runtime-registered-local-worktree-removal.ts:65-81`, `orca-runtime-remove-managed-worktree.ts:42` (default `runHooks = false`) |
| `orca worktree rm --run-hooks`, local worktree | Yes, with **no trust prompt** | The Orca instance the CLI talks to (local app, or `--environment` paired server) | `runtime-registered-local-worktree-removal.ts:65-77` |
| `orca worktree rm --run-hooks`, SSH worktree | **Cannot run**. It refuses as `unverifiable` unless `--allow-failed-archive-hook`, which deletes with nothing archived (upstream #18563 will add it) | n/a | `worktree-archive-hook-gate.ts:40-86`, `runtime-registered-remote-worktree-removal.ts:40-48` |
| `orca worktree rm` without `--run-hooks`, SSH worktree | **No** (warning only) | n/a | `worktree-archive-hook-gate.ts:70-74` |
| Stale registration: path is a `.git` file, or the tree is already gone (Windows force) | **No**, by design | n/a | `execute-worktree-removal.ts:142-186`, `orca-runtime-remove-managed-worktree.ts:160-202` |
| Worktree git no longer lists (unregistered/orphan) | **No** (no hook code on that path) | n/a | `execute-worktree-removal.ts:117-131` → `remove-unregistered-worktree.ts`; `orca-runtime-remove-managed-worktree.ts:119-152` |
| Folder workspaces | **No** | n/a | `execute-worktree-removal.ts:95-97` → `remove-folder-workspace.ts`; `removeOrphanOrFolderWorktree` (`orca-runtime-remove-managed-worktree.ts:85-95`) |
| `git worktree remove`, `rm -rf`, or anything outside Orca | No | n/a | n/a |

There is no separate UI "Archive" action. `isArchived` is a metadata flag that only feeds the workspace-cleanup inactivity scan (`src/shared/workspace-cleanup.ts:242-250`) and is never removal. "Archive hook" means "archive before delete" (`src/shared/orca-yaml-hook-types.ts:6-9`).

**SSH quirks.**

- For SSH repos, `orca.yaml` is read from the remote primary checkout.
- A read failure is treated as "no committed hook" (fail-open), but the local `hookSettings` archive script still applies (`worktree-archive-hook.ts:29-65`).
- A local-settings script string is executed on the SSH host, so it must reference a binary that exists **there**.

## 4. Installation

**Combination rule.** One per-repo `hookSettings.commandSourcePolicy` governs both setup and archive, but it resolves per script (`src/main/effective-hook-config.ts:31-58`, `src/shared/hook-command-source-policy.ts:13-26`):

- Explicit `shared-only`: only the committed `orca.yaml` script runs. The local archive script is ignored.
- Explicit `local-only`: only the local script runs. The committed archive script is suppressed.
- Explicit `run-both`: `yaml + "\n" + local`, run as **one bash script**:
  - The exit status is the **last** command's, so our local check, placed last, decides the verdict.
  - A committed script that fails without `set -e` is masked.
  - A committed script that calls `exit` prevents ours from running (`effective-hook-config.ts:24-26`).
- **Unset policy with a local archive script**: resolves to **`local-only`**, which **silently drops the committed archive hook** (`hook-command-source-policy.ts:21-23`). Unset with no local script resolves to `shared-only`.
- An installer must therefore write `commandSourcePolicy: 'run-both'` explicitly.
  - That also sets setup to `run-both`. With no local setup script this is harmless.
  - It keeps shared default-tab commands enabled, because only `local-only` disables them (`effective-hook-config.ts:104-113`).
  - Under `run-both` the UI trust prompt still covers the committed script, and declining it skips ours too (see section 2).

**Where `hookSettings` actually lives in current main.**

- SQLite is the only writable profile backend. `orca-data.json` is kept only as an import and compatibility-export boundary (`src/main/persistence/profile-state/legacy-json/README.md:3-4`, `19-23`).
- The per-profile paths are `<userData>/profiles/<profileId>/orca-data.json` and `…/profile-state.db` (`src/shared/profile-state-storage-paths.ts:10-16`).
- On this machine `profiles/local-default/profile-state.db` exists and is live.
- The top-level `~/Library/Application Support/orca/orca-data.json` was last written 2026-07-31. It is a pre-profile leftover.
- When both the JSON and the DB exist, startup accepts the JSON only if its **byte hash** matches the DB's acceptance marker. Otherwise it throws `diverged-json` and makes the user pick a copy at startup (`src/main/persistence/profile-state/profile-state-authority-bootstrap.ts:80-89`, `profile-state-documents.ts:170-185`, `profile-state-recovery-required.ts:15-18`).
- Repos hydrate `hookSettings` as defaults (empty `setup`/`archive`, no policy) merged with the persisted value (`src/main/persistence/tracking-repos/repo-hydration.ts:80-86`, `src/shared/constants.ts:196-206`).

**Chezmoi verdict: not viable.**

1. `home/Library/Application Support/private_orca/modify_orca-data.json.tmpl` targets the top-level `orca/orca-data.json`. That file is dead: current Orca reads neither it nor the per-profile JSON as live state. The template also only merges a `settings` subtree (lines 41-46). It never touches `repos[].hookSettings`.
2. Retargeting it at `profiles/local-default/orca-data.json` would be worse. Any byte change breaks the acceptance hash, and the next launch stops at a divergence recovery prompt. Orca also rewrites that file on clean shutdown, so any edit would be overwritten anyway.
3. Writing `profile-state.db` directly is an Orca-internal schema. That breaks the map's "no internals" rule, and it races the live writer.
4. No public surface writes `hookSettings`:
   - `orca repo` offers only `list/add/show/set-base-ref/search-refs`.
   - The only writer is the desktop IPC `repos:update` used by Settings → Repository → Hooks (`src/main/ipc/repos/repo-update-handler.ts:21-35`, `src/renderer/src/components/settings/RepositoryPane.tsx:158`).
5. **Repos registered later** get empty default hook settings, and no global or all-repo default exists (`repo-hydration.ts:80-86`). Every new repo would need its own install.

**What is viable.**

- `orca repo list --json` **does** expose `hookSettings` per repo. This was verified locally: all 6 registered repos have an empty `archive` and no `commandSourcePolicy`. `dotfiles` has a committed `orca.yaml` with only `setup`.
- A chezmoi `run_after` or doctor check can therefore **detect** repos missing the inbox hook and print a one-time Settings step. It cannot install the hook.
- The alternative is a committed `orca.yaml` `scripts.archive` per repo. That is fine for personal repos, but it pushes our inbox check onto collaborators in shared work repos (monorepo, envconfig, spacejunk…), so those need the local setting instead.

## 5. Other lifecycle points

- **`orca.yaml` hooks**: only `scripts.setup` and `scripts.archive` exist (`src/shared/orca-yaml-hook-types.ts:5-17`). The top-level keys Orca recognizes are `scripts`, `setupAgentStartupPolicy`, `issueCommand`, `defaultTabs`, `environmentRecipes`, and `worktree` (`src/main/hooks.ts:141-148`). `environmentRecipes` `suspend/resume/destroy` apply to ephemeral VM environments only (`orca-yaml-hook-types.ts:34-44`). There are no hooks for sleep, terminal close, or card status.
- **Plugin events (v0)**: a closed set, `worktree.created`, `worktree.removed`, and `agent.status.changed` (`src/shared/plugins/plugin-manifest.ts:60-67`, payloads in `src/shared/plugins/plugin-events.ts:11-53`).
  - `worktree.removed` (`{worktreeId, path}`) fires **after** removal (`src/main/startup/main-process-pty-startup.ts:34-41`). It is a notification, not a gate. It could drive the "archive record" step (move resolved items aside), but it cannot block.
  - `agent.status.changed` carries per-pane `state` and `mainAgent.outcome`. It could drive a nudge but cannot block.
- **Card status (`workspaceStatus`, for example `completed`)**: plain worktree metadata, persisted with the other metadata (`src/main/runtime/runtime-worktree-ps-summaries.ts:55`). No hook or plugin event fires on it. Blocking a move to `completed` is not possible through public surfaces.
- **Agent hooks** (Claude/Codex status hooks): one-way, as the map already notes. They cannot block Stop.

## Implications for the inbox spec

- The v1 done check holds for the path Prateek normally uses (desktop Delete of a local worktree). The spec should name the bypasses in the coverage table. In particular, agents calling `orca worktree rm` must pass `--run-hooks`, which could become a convention in the `orca-cli` skill or AGENTS.
- The hook must derive identity from `ORCA_WORKTREE_PATH` plus `hostname`. The inbox key should therefore be host + worktree path, or the hook must map the path to an id itself.
- The hook's output is what the user reads in the toast, so print the open items concisely. It has 120 s and no stdin.
- Installation is a manual per-repo Settings step (policy `run-both`) plus a chezmoi-side detector, or a committed `orca.yaml` in personal repos. That replaces the `modify_orca-data.json.tmpl` route listed under "Installation" in the map.
- Separate drift, found in passing and not fixed: the existing Orca settings modify template writes a dead file, so Orca settings in `orca-settings.base.json.tmpl` do not reach the live app. This matches the earlier memory note.
