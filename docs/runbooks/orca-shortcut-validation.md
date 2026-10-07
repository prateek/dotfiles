---
status: active
doc_type: runbook
created: 2026-10-07
updated: 2026-10-07
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
1.4.222 ARM64 AppImage and verifies SHA256, builds the
[fixture image](../../tests/fixtures/orca-shortcuts/Dockerfile), and starts two
disposable containers. One runs the packaged desktop under Xvfb; the other runs
sshd and, for paired-server scenarios, packaged `orca serve`. No host ports,
personal home, credentials, or production Orca state are mounted. The checkout
is mounted read-only.

The [scenarios](../../tests/fixtures/orca-shortcuts/scenarios.py) call the real
shortcut entrypoint through a symlink and the Orca CLI, connect through the real SSH relay, publish
agent hooks over HTTP, and wait for the resulting session bindings. The
generated Claude, Codex, Pi, and OMP agents verify the fork locator and Codex
account home before publishing a new conversation. They cover routing and hook
transport; they do not validate the native agents' fork implementations.

The paired-server scenario pairs a real headless server with the desktop,
selects it in the active profile, and checks conversation resolution and fork
on that server. It then stops the server and checks refusal to fork. Paired
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

## Coverage limits

The container lane is ARM64 Linux. macOS Raycast hotkeys, native application
navigation, real Codex/Pi/OMP/Cursor provider calls, and a user's remote network
are separate checks. Remote Reveal still opens the configured local AgentsView
instance; that instance must already contain the remote session. The shortcut
does not import transcripts into AgentsView.

Validated on 2026-10-07 with all container scenarios passing and 23 focused
regression tests passing. This is source validation; live hotkey activation
remains tracked in the plan.

The helper depends on private Orca RPCs, the profile-state settings schema, and
packaged runtime-client module layout. Review these version-matched sources
when updating its pinned integration artifact:

- [AI Vault RPC](https://github.com/stablyai/orca/blob/v1.4.222/src/main/runtime/rpc/methods/ai-vault.ts): runtime-local scan.
- [Terminal contract](https://github.com/stablyai/orca/blob/v1.4.222/src/shared/runtime-terminal-contracts.ts): execution host identity.
- [Provider binding](https://github.com/stablyai/orca/blob/v1.4.222/src/shared/agent-session-resume.ts): ID and transcript locators.
- [SSH RPC](https://github.com/stablyai/orca/blob/v1.4.222/src/main/runtime/rpc/methods/ssh.ts): connection state.
- [Packaged runtime client](https://github.com/stablyai/orca/blob/v1.4.222/src/cli/runtime/client.ts): paired-server authentication and RPC routing.
