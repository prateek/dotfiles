---
status: current
doc_type: reference
related:
  - ../adr/0005-mise-tool-management.md
---

# Mise Tool Management Reference

This reference describes the implemented replacement for the repo-local
`devtool` shim system: mise-native tool selection.

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

## Crit workflow

Crit is managed by mise as a Go CLI, not Homebrew:

```sh
mise run crit:use latest
mise run crit:use release v0.12.0
mise run crit:use --local pr 1
mise run crit:use --local local /Users/prateek/code/github.com/tomasz-tomczyk/crit pr-1
```

Use `latest` or `release` for normal use. Use `pr` when GitHub is reachable, or `local` when a PR branch is already checked out locally and you want mise to build and link that exact source tree.

## Implemented State

- ADR 0005 records the decision.
- Codex selection lives in the repo-owned mise task under `home/dot_config/mise/tasks/`.
- Crit is selected through `home/dot_config/mise/conf.d/clis.toml` and the `crit:use` task; it is intentionally absent from Brewfile profiles.
- `bin/devtool`, `bin/devtool-shim`, `.config/devtools/config.toml`, and `docs/devtools.md` are removed.
- `devtool` is no longer linked into `~/bin`.
- Mise config and tasks are chezmoi-managed source state under `home/dot_config/mise/`.
- Bootstrap is the chezmoi one-liner, not `bootstrap.sh` or `install.sh`.

## Validation

Use these checks after changes. In an untrusted checkout, either run `mise trust` first or use `MISE_TRUSTED_CONFIG_PATHS="$PWD"`.

```sh
MISE_TRUSTED_CONFIG_PATHS="$PWD" mise tasks ls | rg 'codex:use'
MISE_TRUSTED_CONFIG_PATHS="$PWD" mise run codex:use --help
chezmoi apply --dry-run --verbose --exclude=scripts
rg -n 'devtool|devtools|\.devtools\.toml' . --hidden -g '!*.git/*'
```

The only remaining `devtools` matches should be unrelated third-party names, such as browser DevTools docs or skills.
