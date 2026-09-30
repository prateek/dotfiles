---
status: superseded
doc_type: adr
owner: Prateek
created: 2026-09-24
updated: 2026-09-30
closed: 2026-09-30
superseded_by: 0043-devbox-os-gating.md
related:
  - ../plans/linux-devbox-plan.md
  - 0012-config-gating-convention.md
  - 0043-devbox-os-gating.md
status_detail: "The devbox type, the per-type os declaration, and the Homebrew group remain; ADR 0043 replaces the managed_allowlist with OS gates."
---

# ADR 0040 — Devbox machine type

## Decision

Add a dedicated `devbox` machine type for Prateek's Linux Cloud Workstation.
The first adoption selects it with `chezmoi init --promptChoice machine_type=devbox`,
like any other type. Its `[machines.type.devbox]` layer turns on a new
`managed_allowlist` feature. When that feature is on, `.chezmoiignore` ignores
every target and script, then un-ignores only the paths the devbox takes.

The devbox installs its CLIs with Homebrew from one minimal `devbox` group,
limited to formulae that agent sessions actually ran. Adding a tool means
adding it to that group. Homebrew on Linux lives under
`/home/linuxbrew`, which is on the persistent disk. Casks and Mac App Store
apps are macOS-only, so the Brewfile renders them only on macOS, and the cask
gate reports every cask as absent off macOS. Formulae that only build or run on
macOS move to a `mac-developer-tools` group that every Mac type selects. The
move alone leaves the Mac Brewfiles unchanged.

Each machine type declares the OS it runs as `os` in `machines.toml`:
`darwin` for the Macs, `linux` for the devbox. There is no default, and no
other layer may set it. `features.tmpl` picks the `os.<os>` layer from it,
refuses a host whose OS differs, and the per-type renderers
(`render-brewfile`, the apply dry-run, the test helpers) render a type as its
declared OS on any host.

## Rationale

The devbox is not a work Mac on Linux. The `work` type turns on the private
overlay, the session archive, TLS inspection, Jamf elevation, Touch ID sudo, and
macOS package groups. None of these apply. Layer precedence is
`defaults < os < type < host`, so an OS layer cannot switch off anything a type
turns on. The pilot needed an extra composite layer for this reason. A separate
type needs no new mechanism.

Work tooling provisions the devbox and re-runs its own bootstrap on resume and
on config pushes. That bootstrap writes `~/.gitconfig`, `~/.bashrc`, the tmux
and vim marker blocks, and the Claude credentials. It also syncs the Claude
skill and command directories. Most of the source state either targets macOS
or collides with one of these owners. An allowlist makes every managed path an
explicit choice. A denylist would silently pick up each new macOS target.

## Consequences

- Each increment that adds devbox behavior adds its paths to the allowlist
  block in `.chezmoiignore`. The work-type render must not change.
- An ignored parent hides its children, and `*` stops at `/`. So the allowlist
  un-ignores each parent directory and gives each allowlisted directory its own
  `dir/*` line. Scripts match by target name (`.chezmoiscripts/<NN-name>`).
- chezmoi applies `.chezmoiremove` and `remove_` entries even to ignored
  targets. The allowlist profile renders `.chezmoiremove` empty and never
  un-ignores a `remove_` target, so it deletes nothing another owner wrote.
- A formula that fails on Linux belongs in `mac-developer-tools`, not behind a
  per-item OS flag.
- `.chezmoiignore` does not govern externals. The zinit external reaches the
  devbox, and the shell needs it.
- The plan tracks the rollout: [Linux devbox](../plans/linux-devbox-plan.md).
