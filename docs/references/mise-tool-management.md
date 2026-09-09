---
status: current
doc_type: reference
related:
  - ../adr/0005-mise-tool-management.md
  - ../adr/0027-codex-standalone-installer.md
  - ../adr/0029-claude-code-native-installer.md
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
- Support official releases, source builds from `main`, and PR builds for Codex.
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

The Codex CLI is not mise-managed. `run_after_07-codex-standalone.sh` installs
it with OpenAI's standalone installer, because `/agents` and the app-server
daemon exec a fixed path that only that installer creates
([ADR 0027](../adr/0027-codex-standalone-installer.md)). It links
`~/.local/bin/codex`, and zprofile puts `~/.local/bin` ahead of the mise shims,
so the standalone install is what `codex` resolves to.

The task still owns Codex source experiments, and adds a channel for the
standalone default:

```sh
mise run codex:use standalone
mise run codex:use standalone 0.153.4
mise run codex:use latest
mise run codex:use release 0.125.0
mise run codex:use --local main
mise run codex:use --local pr 19776
```

For per-repo experiments, avoid changing the tracked global mise config:

```sh
mise run codex:use --local pr 19776
```

The task does this:

- `standalone [version]` re-runs the official installer, which repoints
  `~/.codex/packages/standalone/current` and `~/.local/bin/codex`. This is the
  chezmoi-owned default and the only channel that changes the `codex` on `PATH`.
- `latest` selects `codex@latest`
- `release <version>` selects a pinned release
- `main` builds `codex-cli` from `openai/codex` `main` with Cargo, links it as `codex@main`, and selects it
- `pr <number>` resolves the PR head with `gh`, builds that exact SHA with Cargo, links it as `codex@pr-<number>`, and selects it

The four mise channels record a selection that `~/.local/bin/codex` shadows. Run
those builds explicitly:

```sh
mise exec codex@main -- codex --version
```

## Claude Code workflow

The Claude Code CLI is not mise-managed either.
`run_after_06-claude-native.sh` installs it with Anthropic's installer
([ADR 0029](../adr/0029-claude-code-native-installer.md)), gated on `claude`
appearing in the machine's `agent_clis`. Each release lands at its own path
under `~/.local/share/claude/versions/`, with `~/.local/bin/claude` pointing at
the current one — so an update never unlinks the image a running session is
executing, which the npm package did.

The same hook retires the npm copies once the native install answers for
`claude`, and skips retirement while a session is still executing one of them.
There is no `claude:use` task and no mise channel; the CLI updates itself on the
channel set by `autoUpdatesChannel` in
`home/.chezmoitemplates/claude-settings-managed.json.tmpl`. `claude doctor`
reports the installed version and that channel. To move it by hand:

```sh
claude install latest
```

`npm:@agentclientprotocol/claude-agent-acp` is a different package and stays in
`clis.toml`.

## Implemented State

- ADR 0005 records the decision.
- Codex source experiments live in the repo-owned mise task under `home/dot_config/mise/tasks/`; the CLI itself installs standalone ([ADR 0027](../adr/0027-codex-standalone-installer.md)).
- Claude Code installs through Anthropic's installer ([ADR 0029](../adr/0029-claude-code-native-installer.md)); `tests/bats/packages/claude-native.bats` covers the hook.
- Homebrew installs crit through the `developer-tools` package group; crit is not mise-managed, and `just test-python -p test_brewfile.py` fails if a crit entry returns to `clis.toml`.
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
