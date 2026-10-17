---
status: active
doc_type: plan
summary: "Option-Z project Zen mode beta, restore behavior, known selection races, and the proposed native atomic operation."
created: 2026-10-17
updated: 2026-10-17
related:
  - ../adr/0044-karabiner-sole-remapper.md
status_detail: "Approved for beta use with known selection and profile races; reliable atomic toggling needs an Orca-owned operation."
---

# Orca Zen mode

Option-Z hides both sidebars and applies Orca's project filter to the project selected on entry. Reopening the left sidebar keeps that filter. The next Option-Z restores the previous project filter and sidebar visibility, even if the user reopened a sidebar or selected another project while in Zen mode. Existing host, activity, and workspace-category filters remain in effect.

The original request was for one worktree. The user accepted project scope because installed Orca cannot filter by worktree identity. Development must preserve the foreground app and selected workspace.

## Installed Orca boundary

The installed application is Orca 1.4.224, commit `8ba3cf46ab093eb5ef95bb476b3c3c92e32b8b40`.

- [`ui.get` and `ui.set`](https://github.com/stablyai/orca/blob/v1.4.224/src/main/runtime/rpc/methods/client-ui.ts) expose persisted UI preferences. A live read and unchanged-value write confirmed `filterRepoIds` on the installed runtime.
- [`filterRepoIds`](https://github.com/stablyai/orca/blob/v1.4.224/src/shared/rpc-contract/client-ui-workspace-filter-fields-params.ts) selects projects. The schema has no worktree-ID filter.
- [`computeVisibleWorktrees`](https://github.com/stablyai/orca/blob/v1.4.224/src/renderer/src/components/sidebar/visible-worktrees.ts) applies native project, host, origin, and activity filters. Orca can still include structural ancestors or temporarily revealed workspaces. `showActiveOnly` is retired and ignored during hydration.
- [`sidebarOpen`](https://github.com/stablyai/orca/blob/v1.4.224/src/shared/pairing-local-ui-fields.ts) is stripped from UI RPC responses and writes, even though the parameter schema accepts it. The left sidebar requires accessibility control.

## Implementation

The user approved landing and activating this prototype for beta testing on 2026-10-17. The review found two correctness gaps: the saved session can lag the selected project, and the startup profile index can point to the next profile while the old runtime is still serving requests. The existing tests do not cover those transitions. Beta approval accepts these limits; passing tests do not prove these races are resolved.

The [helper](../../home/dot_local/bin/executable_orca-zen-mode) reads the active project from the local desktop's profile session and updates only `filterRepoIds` through its authenticated local runtime socket. The desktop owns this filter even when the focused worktree is on a paired server. Inherited CLI server-selection variables do not redirect the operation. Runtime credentials stay in memory and are never printed or saved in the restore snapshot.

The [accessibility adapter](../../home/dot_local/libexec/orca-zen-mode.js) reads sidebar state and presses the existing sidebar buttons. It never activates Orca or sends keyboard events. It requires frontmost Orca for mutations and refuses multiple windows or an unrecognized shell. The control labels currently require the English interface. `orca-zen-mode --status` inspects the layout, current project, and filter without requiring Orca to be frontmost.

The [Karabiner binding](../../home/dot_config/karabiner.edn.tmpl) follows [ADR 0044](../adr/0044-karabiner-sole-remapper.md), is scoped to frontmost Orca, and disables key repeat. Option-Z takes precedence over Orca's existing editor word-wrap shortcut.

Restoration state lives at `${XDG_STATE_HOME:-~/.local/state}/orca-zen-mode/restore-<profile>.json`. The helper saves the previous filter and both sidebar states before mutation, serializes invocations, verifies the filter write, and retains the snapshot after an error. Each profile has its own snapshot. A snapshot survives an Orca restart because the project filter also persists. The next successful toggle restores it and removes the snapshot.

## Validation

- `just test-python -p test_orca_zen_mode.py`: eleven tests pass. They exercise the controller with a real temporary profile database and Unix-socket RPC fixture, substituting only the external accessibility process. Coverage includes all sidebar combinations, empty and nonempty original filters, reopening a sidebar, selecting another project, preserving unrelated preferences, RPC/sidebar failures, ignored writes, restarts, profile changes, concurrent invocations, malformed state, and foreground preservation. The adapter also runs against a native-accessibility fixture in Node.
- A mutation check disabled the project-filter write in a temporary copy; the behavior test detected it.
- `BATS_TAGS=host just test-shell tests/bats/config/karabiner.bats`: real Goku compilation passes, including the app scope and repeat behavior.
- Live `--status` reads the installed app's sidebar state and selected project. An unchanged-value `ui.set` followed by `ui.get` verified the installed RPC contract without altering the filter.
- Earlier live sidebar inspection exposed a mounted-but-empty collapsed container. The corrected fixture reproduces that distinction, and a semantic accessibility press restored the original layout.

## Live selection and compare-and-swap

The user proposed using CLI selection and compare-and-swap to make the operation atomic. Source inspection of the installed version establishes these limits:

- [`--worktree active` and `current`](https://github.com/stablyai/orca/blob/v1.4.224/src/cli/selectors.ts) resolve the worktree containing the CLI caller's current directory. A read-only invocation from this checkout returned `zen-mode`; it is not an accessor for the desktop selection.
- [`worktree ps` activity flags](https://github.com/stablyai/orca/blob/v1.4.224/src/main/runtime/runtime-worktree-ps-activity.ts) come from workspace-session snapshots and can mark a selected workspace in each host's session. They do not provide one authoritative current desktop selection.
- Session updates are [debounced in the renderer](https://github.com/stablyai/orca/blob/v1.4.224/src/renderer/src/lib/session-write-subscriber.ts), then [scheduled for disk persistence](https://github.com/stablyai/orca/blob/v1.4.224/src/main/persistence/loading-store/write-scheduling.ts). Reading SQLite twice can return the same stale project both times.
- [`ui.set`](https://github.com/stablyai/orca/blob/v1.4.224/src/main/runtime/rpc/methods/client-ui.ts) unconditionally merges its patch. Its [strict parameter schema](https://github.com/stablyai/orca/blob/v1.4.224/src/shared/rpc-contract/client-ui-params.ts) has no expected state or revision argument. A separate read, compare, and write would still race with Orca's own UI writers.
- The [profile-switch handler](https://github.com/stablyai/orca/blob/v1.4.224/src/main/ipc/orca-profiles.ts) changes the startup index before relaunching. Profile identity must come from the running process, not that index.

The proposed replacement is an Orca-owned Zen operation. It should capture the live renderer's selected project, the running profile identity, and the original filter/sidebar state, then apply the project filter and both visibility changes in one state transition. If the external caller supplies an expected state, compare a token that includes the runtime/profile incarnation and live view revision within that same operation. A mismatch must reject the whole mutation. This API does not exist in the installed build.

Store the restore snapshot with the changed view state and use an idempotency key so retrying an uncertain response cannot toggle the view twice. Exiting must allow sidebar reopening while Zen mode is active: compare against a fresh current revision, then restore the entry snapshot. A file lock in this helper only serializes helper invocations; it cannot fence UI actions, other RPC clients, or profile transitions. Direct SQL compare-and-swap would also leave the live renderer and runtime state outside the transaction.

## Beta use

After selecting a project, let Orca settle for a few seconds before pressing Option-Z. This reduces the chance of reading the previous selection; it is not an atomicity guarantee. Avoid the shortcut during a profile switch, and exit Zen mode before switching profiles.

Press Option-Z to enter, Cmd-B to reopen the filtered left sidebar, and Option-Z again to restore the entry view. If entry only partly succeeds, another Option-Z attempts restoration from the saved snapshot. The snapshot remains after a failed restore. Inspect `~/.local/bin/orca-zen-mode --status` and `${XDG_STATE_HOME:-~/.local/state}/orca-zen-mode/restore-<profile>.json` when diagnosing an unexpected view. Do not delete a snapshot before recovering the original filter and layout. Option-Z replaces the editor word-wrap shortcut while Orca is frontmost.

Activation applies the helper, accessibility adapter, and Karabiner input from the canonical chezmoi source, then runs the existing Goku compilation hook. It does not modify installed Orca files. Keep the canonical source and live files converged.

## Remaining work

Replace the prototype's multi-step mutation with an Orca-owned atomic operation. Add regression coverage for delayed session persistence, profile handoff, concurrent view edits, idempotent retries, and reopening the sidebar before exit.

An attended check must verify Option-Z entering and leaving Zen mode, reopening the left sidebar with Cmd-B, and restoring a nonempty prior project filter. This has not been run against the user's working window. Exact-worktree filtering remains a future native Orca enhancement.
