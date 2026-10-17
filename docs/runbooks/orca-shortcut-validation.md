---
status: active
doc_type: runbook
summary: "Local, SSH, and paired-server fork comparisons, sidebar focus regression, and release-specific integration limits."
created: 2026-10-07
updated: 2026-10-17
related:
  - ../plans/orca-shortcuts-plan.md
---

# Orca shortcut validation

The [session helper](../../home/dot_config/raycast/scripts/executable_orca-agent-session.py)
and its [paired-server adapter](../../home/dot_config/raycast/scripts/orca-agent-rpc.cjs)
back Reveal and Fork Orca Agent Session. Activate both files together through
chezmoi after source validation. The [plan](../plans/orca-shortcuts-plan.md) tracks activation and
attended hotkey checks.

## Fast regression lane

```sh
just test-python -p test_orca_shortcuts.py
```

This checks local vault ambiguity, agent aliases, bound remote conversations,
account homes, unavailable hosts, and refusal to fork unsupported agents. Orca
is substituted at the external command/RPC boundary. Active-profile selection
also uses an isolated SQLite fixture. This lane does not prove the runtime wire
contract.

## Container integration lane

Start your ARM64 Docker engine, then run:

```sh
just test-orca-shortcuts-docker
```

The [runner](../../scripts/tests/orca-shortcuts-docker) downloads the pinned Orca
1.4.222 ARM64 AppImage by default and verifies SHA256, builds the
[fixture image](../../tests/fixtures/orca-shortcuts/Dockerfile), and starts two
disposable containers. One runs the packaged desktop under Xvfb; the other runs
sshd and, for paired-server scenarios, packaged `orca serve`. No host ports,
personal home, credentials, or production Orca state are mounted. The checkout
is mounted read-only.

The [scenarios](../../tests/fixtures/orca-shortcuts/scenarios.py) call the real
shortcut entrypoint through a symlink and the Orca CLI, connect through the real SSH relay, publish
agent hooks over HTTP, and wait for the resulting session bindings. The
generated Claude, Codex, Pi, OMP, and Droid agents verify the fork locator and Codex
account home before publishing a new conversation. Local, SSH, and paired-server
scenarios cover all five agents. Each fork also writes a process receipt inside its container;
the scenario checks hostname, source locator, working directory, and that the
other container received no fork. Both containers contain matching source IDs,
so a local transcript cannot silently stand in for a remote one.
These scenarios cover routing and hook
transport; they do not validate the native agents' fork implementations.

The paired-server scenario pairs a real headless server with the desktop,
checks explicit default-server selection for each agent, then stops the server
and checks refusal to fork. On 1.4.224 it also clicks the workspace in the
desktop sidebar while the default server remains local, flushes the saved
focus, and checks all five agents on that server. Paired
RPCs use the installed Orca client's authentication and encryption through the
adjacent adapter; there is no substitute transport implementation. SSH scenarios
also check refusal after explicit disconnect.

The native Claude lane runs Claude Code 2.1.292 in the SSH host against a
[deterministic Anthropic Messages server](../../tests/fixtures/orca-shortcuts/llm-server.py).
It checks the returned answer, generated session ID, native transcript path,
hook delivery, and the shortcut's resolved host and conversation. The API key is
a fixture string; no real model calls are required. The CLI uses print mode with
stream input kept open, so this checks native session creation and hooks rather
than keyboard behavior in its TUI.

All waits use scenario deadlines and observable readiness. Failure is nonzero.
Containers and the network are removed on exit; image and AppImage caches remain.
Build output belongs under ignored `build/orca-shortcut/`. On scenario failure,
the runner also copies the disposable desktop log there for diagnosis.

To supply an already-downloaded artifact with the same pinned digest:

```sh
just test-orca-shortcuts-docker --appimage /path/to/orca-linux-arm64.AppImage
```

Select a checksum-pinned release and scenario for diagnosis:

```sh
just test-orca-shortcuts-docker --orca-version 1.4.224 --scenario paired
```

`--scenario` accepts `all` (default), `local`, `ssh`, or `paired`. The paired lane
also runs local forks so both containers contain source conversations.

## Coverage limits

The container lane is ARM64 Linux. macOS Raycast hotkeys, native application
navigation, real Codex/Pi/OMP/Droid provider calls, and a user's remote network
are separate checks. Remote Reveal still opens the configured local AgentsView
instance; that instance must already contain the remote session. The shortcut
does not import transcripts into AgentsView.

On 2026-10-17, the 1.4.224 paired sidebar scenario reproduced a routing bug:
the focused workspace was remote while `settings.activeRuntimeEnvironmentId`
remained null. The helper queried the local runtime and returned
`Orca has no active workspace`. The earlier scenario changed the default server
before testing and missed this case. The helper now prefers the active profile's
saved `workspaceSession.activeWorkspaceExecutionHostId`; the fixed local and paired
scenarios and 24 focused regression tests pass. This tests settled, persisted
focus, not the interval before Orca saves a just-clicked workspace.

The 1.4.224 full lane currently fails before the SSH shortcut scenarios:
`repos.addRemote` reports `SSH connection "<id>" not found or not connected`
after `ssh.connect` reports connected. The default release remains 1.4.222.
This is source validation; live hotkey activation remains tracked in the plan.

The helper depends on private Orca RPCs, the profile-state settings schema, and
packaged runtime-client module layout. Review these version-matched sources
when updating its pinned integration artifact:

- [AI Vault RPC](https://github.com/stablyai/orca/blob/v1.4.222/src/main/runtime/rpc/methods/ai-vault.ts): runtime-local scan.
- [Terminal contract](https://github.com/stablyai/orca/blob/v1.4.222/src/shared/runtime-terminal-contracts.ts): execution host identity.
- [Provider binding](https://github.com/stablyai/orca/blob/v1.4.222/src/shared/agent-session-resume.ts): ID and transcript locators.
- [SSH RPC](https://github.com/stablyai/orca/blob/v1.4.222/src/main/runtime/rpc/methods/ssh.ts): connection state.
- [Packaged runtime client](https://github.com/stablyai/orca/blob/v1.4.222/src/cli/runtime/client.ts): paired-server authentication and RPC routing.
