---
status: accepted
doc_type: adr
created: 2026-04-27
owner: Prateek
related:
  - ../references/mise-tool-management.md
status_detail: "Accepted decision record; current tool-management guidance lives in ../references/mise-tool-management.md."
---

# ADR 0005 - Mise-managed tool selection

## Context

This repo had a local `devtool` wrapper for switching command-line tools between stable installs and locally built PR versions. It owned custom shims, config files, PR checkout logic, and Rust or Node install recipes.

That duplicated work already covered by `mise`, language package managers, Homebrew, and release installers. The custom wrapper also created a second selection system next to the mise shims already on `PATH`.

Mise now has enough native surface for this job:

- registry entries for common tools
- package-manager backends such as `npm`, `cargo`, `pipx`, and `go`
- release backends such as `aqua`, `github`, and `http`
- `path:` versions for external prefixes
- `mise link` for externally built prefixes
- tasks for repeatable workflows

## Decision

Use mise as the tool selection layer for repo-owned CLI workflows.

Remove the local `devtool` shim system. Do not build a custom mise backend plugin now.

The replacement contract is:

- use mise registry names when they exist
- prefer `aqua` or `github` for release binaries
- use language backends when a tool is distributed through that package manager
- use `path:` when another package manager owns a stable prefix
- use `mise link <tool>@<label> <prefix>` for source builds and one-off installs
- keep any custom source-build logic in mise tasks, scoped to the specific tool that needs it

For Codex, this repo provides a file task at `~/.config/mise/tasks/codex/use`. It can select official releases, build `main`, build a PR head, or link the Homebrew-managed binary.

### Config layout

mise loads `~/.config/mise/conf.d/*.toml` alphabetically after `~/.config/mise/config.toml`. We use that to group each concern in its own file:

- `conf.d/runtimes.toml` — language runtimes (node, go, ruby) and ecosystem package managers (yarn) plus per-language `[settings]`.
- `conf.d/clis.toml` — standalone CLIs without associated env / settings / hooks.
- `conf.d/<name>.toml` — any tool whose configuration spans `[tools]` + `[env]` (or `[settings]` / `[hooks]`), kept together so the whole concern lives in one file and removes cleanly.
- `config.toml` — intentionally empty. Reserve for settings that must load before every `conf.d/` file. New tools go in a `conf.d/` file, not the root.

Rule of thumb when adding a new tool: if the entry is one line and needs nothing alongside it, add it to `clis.toml` or `runtimes.toml`. If it brings its own env var, settings block, or hook, give it its own `conf.d/<name>.toml`.

## Options considered

### Option A - Keep `devtool`

Keep the custom scripts and continue extending them as new tools need npm, Homebrew, GitHub release, install-script, or source-build support.

- Pros: direct control over every edge case
- Cons: duplicates mise shims and backend selection, grows a package manager inside dotfiles, and requires custom behavior for each ecosystem
- Rejected: too much local machinery for a problem mise already models

### Option B - Write a custom mise backend plugin

Create a backend namespace such as `devbuild:codex@pr-123` and implement build logic inside the plugin.

- Pros: gives a native mise version syntax for custom builds
- Cons: still requires custom install recipes, Lua plugin maintenance, trust handling, and backend compatibility work
- Deferred: revisit only if many tools repeatedly need the same source-build lifecycle

### Option C - Use mise native backends plus `mise link` (chosen)

Let mise select versions and build shims. Let upstream package managers and release formats install tools. Use `mise link` only when a tool must be built outside a native backend.

- Pros: smallest local surface, matches mise architecture, and keeps ecosystem-specific install logic with the ecosystem
- Cons: PR builds still need a small task when the upstream repo layout or package manager does not fit a mise backend directly
- Chosen: best fit for the current Codex workflow

## Consequences

### Positive

- One shim system remains: mise.
- Official tool releases use mise registry and backend behavior.
- Source builds install into normal prefixes with `bin/` and become regular mise versions.
- Tool-specific complexity lives in named tasks instead of a global wrapper.

### Negative

- There is no repo-agnostic magic for every install style. A tool still needs a native backend, an external prefix, or a task that creates a prefix.
- Transient PR builds can be expensive because they compile from source.
- `mise use -g` writes to the global mise config, which this repo symlinks from `.config/mise/config.toml`. Use the task's `--local` mode for per-repo experiments.

### Neutral

- Homebrew remains responsible for Homebrew-managed binaries.
- npm remains responsible for npm packages.
- Cargo remains responsible for Rust source builds.
- `mise link` records the resulting prefix under a mise version label.

## Revisit criteria

Re-open this ADR if any of these happen:

- three or more tools need nearly identical PR/source-build tasks
- source builds need shared caching, cleanup, or metadata beyond a prefix with `bin/`
- a mise backend plugin would remove more code than it adds
- mise gains a native feature that replaces the remaining task logic
- the tracked global mise config becomes too noisy for transient tool switching
