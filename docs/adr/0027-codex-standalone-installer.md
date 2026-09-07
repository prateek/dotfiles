---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - 0005-mise-tool-management.md
  - 0010-machine-type-package-selection.md
  - ../references/mise-tool-management.md
---

# ADR 0027: Install the Codex CLI with OpenAI's standalone installer

Install the Codex CLI through `https://chatgpt.com/codex/install.sh`, driven by a
chezmoi apply hook, and retire the Homebrew cask. `codex-acp` stays a formula.

## Context

The `codex` package group installed the CLI as a Homebrew cask and `codex-acp`,
a separate ACP adapter, as a formula.

Two Codex features do not run under that install. `/agents` and the background
app-server daemon both exec the release at a fixed path,
`$CODEX_HOME/packages/standalone/current/codex`. Only the standalone installer
creates that layout: it unpacks each release under
`$CODEX_HOME/packages/standalone/releases/<version>-<platform>/`, points
`current` at the active one, and links `~/.local/bin/codex` (plus
`codex-code-mode-host` on macOS) at it. A cask-installed binary leaves the path
absent, so `codex app-server daemon start` fails with the managed standalone
package missing — reproduced on this Mac against cask 0.153.4.

Homebrew cannot supply the layout. Neither can a hand-built copy of it: the path
is Codex's own update seam, and a fabricated `current` would be overwritten or
invalidated the first time Codex managed its own release.

## Decision

`run_after_07-codex-standalone.sh` owns the CLI. It is gated on the same
`codex` package group that machines.toml already selects for personal and
homelab, so the machine roles are unchanged. It exits early when the standalone
package and the visible command are both present, so the steady state costs two
stat calls and no network.

The hook constrains the installer in three ways:

- `CODEX_HOME` is pinned to `$HOME/.codex`. Orca terminals can export a
  per-account Codex home, and an apply launched from one must still target the
  machine's own home.
- The installer runs with `PATH` set to `~/.local/bin` plus the system
  directories. The installer writes a PATH block into a shell startup file when
  its install directory is off `PATH`, and offers to uninstall any other Codex
  it finds on `PATH`; that PATH gives it neither condition, so chezmoi keeps
  ownership of shell configuration and of the cask's retirement.
- `CODEX_NON_INTERACTIVE=1` declines the remaining prompts.

The cask retires through the existing mechanism: `{ name = "codex" }` under
`[packages.retired].casks`, uninstalled by `run_onchange_after_08-retired-packages`.
The hook is numbered ahead of it deliberately. It verifies the standalone
binary, and if the install failed while the cask is still installed it fails the
apply, so the working executable is never removed behind a broken replacement.

## Consequences

`~/.local/bin` precedes the mise shims in the managed `path` array, so the
standalone install is what `codex` resolves to — the same precedence
`~/.local/bin/claude` already has over its mise pin. A mise-selected Codex is
therefore an explicit build to run through `mise exec`, not the command on
`PATH`. `mise run codex:use brew` is gone, since it reinstalled the retired
cask; `mise run codex:use standalone [version]` replaces it and re-runs the
official installer.

Codex versions are no longer visible to `brew list`. The installed release is
the directory name under `packages/standalone/releases/`, and the hook installs
`latest` only when the package is absent, matching `brew bundle install
--no-upgrade`.

## Alternatives considered

- **Keep the cask and construct the standalone layout beside it.** Rejected:
  the layout is Codex's own release seam, and a fabricated `current` is not a
  supported state.
- **Install from npm.** Same missing layout as the cask, plus a Node dependency.
- **Keep Codex on mise.** The registry entries install a bare binary, so
  `/agents` and the daemon stay broken, and the shim loses to `~/.local/bin`
  anyway.
