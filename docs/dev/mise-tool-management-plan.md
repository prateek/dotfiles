---
status: current
doc_type: plan
related:
  - ../adr/0005-mise-tool-management.md
---

# Mise tool management plan

This plan replaces the repo-local `devtool` shim system with mise-native tool selection.

## Problem

Tool installs come from several places:

- package managers such as npm, Cargo, pipx, Go, RubyGems, and Homebrew
- release systems such as GitHub releases, direct URLs, and aqua packages
- source builds from branches, tags, commits, and PR heads
- install scripts that create their own prefix

The old `devtool` script tried to hide those differences behind one local command. That made dotfiles own shims, config parsing, PR fetches, build commands, and fallback behavior.

Mise already owns shims and per-directory version selection. The repo should use that instead of maintaining another selector.

## Goals

- Use mise for active tool selection and shims.
- Use upstream packaging systems when they can install the tool.
- Keep local code limited to small mise tasks for workflows that need glue.
- Support official releases, Homebrew installs, source builds from `main`, and PR builds for Codex.
- Remove the custom `devtool` scripts, config, and docs.

## Non-goals

- Build a generic package manager in dotfiles.
- Write a mise backend plugin now.
- Replace Homebrew, npm, Cargo, or upstream install scripts.
- Make every install method look identical.

## Architecture

The selection layer is mise.

The install layer stays with the tool's native packaging format:

| Source | Preferred mise shape |
| --- | --- |
| mise registry entry | `tool = "version"` |
| aqua package | `aqua:owner/repo` |
| GitHub release asset | `github:owner/repo` |
| direct binary or archive URL | `http:` or a tool stub |
| npm package | `npm:package` |
| Rust crate or Git source | `cargo:crate` or `cargo:https://...` |
| Python CLI | `pipx:package` |
| Go CLI | `go:module` |
| Homebrew or another external prefix | `path:/prefix` or `mise link tool@label /prefix` |
| install script or custom source build | install into a prefix with `bin/`, then `mise link` |

The only prefix contract is: after install, executable commands live under `<prefix>/bin`.

## Codex workflow

Codex currently ships through npm, Homebrew cask, and GitHub releases. The mise registry maps `codex` to `aqua:openai/codex` and `npm:@openai/codex`.

Use:

```sh
mise run codex:use latest
mise run codex:use release 0.125.0
mise run codex:use --local main
mise run codex:use --local pr 19776
mise run codex:use brew
```

For per-repo experiments, avoid changing the tracked global mise config:

```sh
mise run codex:use --local pr 19776
```

The task does this:

- `latest` selects `codex@latest`
- `release <version>` selects a pinned release
- `main` builds `codex-cli` from `openai/codex` `main` with Cargo, links it as `codex@main`, and selects it
- `pr <number>` resolves the PR head with `gh`, builds that exact SHA with Cargo, links it as `codex@pr-<number>`, and selects it
- `brew` links the Homebrew-managed binary through a small prefix and selects `codex@brew`

## Migration steps

- Add ADR 0005.
- Add this plan.
- Add the Codex mise task.
- Remove `bin/devtool` and `bin/devtool-shim`.
- Remove `.config/devtools/config.toml`.
- Remove `docs/devtools.md`.
- Remove the devtools symlink block from `bootstrap.sh`.
- Stop linking `devtool` into `~/bin`.
- Update README references to point at mise.
- Link `.config/mise/tasks` into `~/.config/mise/tasks` from `bootstrap.sh`.

## Validation

Use these checks after changes. In an untrusted checkout, either run `mise trust` first or use `MISE_TRUSTED_CONFIG_PATHS="$PWD"`.

```sh
MISE_TRUSTED_CONFIG_PATHS="$PWD" mise tasks ls | rg 'codex:use'
MISE_TRUSTED_CONFIG_PATHS="$PWD" mise run codex:use --help
./install.sh --core --dry-run
rg -n 'devtool|devtools|\.devtools\.toml' . --hidden -g '!*.git/*'
```

The only remaining `devtools` matches should be unrelated third-party names, such as browser DevTools docs or skills.
