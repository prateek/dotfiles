# Agent Notes

This is the repo-specific contract for coding agents working in Prateek's dotfiles repo. Keep this file lean. Put repeatable maintenance workflow in `$code-gardening`, and keep deep topic guidance in the focused docs it points to.

## Repo Map

- `flake.nix`: top-level flake (inputs: nixpkgs-unstable, nix-darwin, home-manager, nix-homebrew; outputs `darwinConfigurations.<host>`).
- `nix/hosts/`: per-host configs. The personal Mac is `prateek-mac.nix`.
- `nix/modules/common.nix`: cross-cutting `profile.*` options (install profile, MAS opt-in, Xcode opt-in, run-install-scripts, apply-macos-defaults, secrets, agents, …).
- `nix/modules/darwin/`: nix-darwin modules (homebrew, defaults, activation). Activation scripts handle imperative `pmset`/`nvram`/`mdutil`/inline plists and shell out to `scripts/macos/plist-merge` for partial-merge bundles.
- `nix/modules/home/`: home-manager modules (shell, git, tools, mise, tmux, ghostty, neovim, hammerspoon, agents, apps, secrets).
- `home/`: content store. Files referenced by nix modules by path. Leaf-level chezmoi prefixes (`dot_zprofile`, `dot_zshrc` inside subdirs) were renamed during the chezmoi→nix migration; top-level `home/dot_*` paths stay because nix modules target them by explicit name.
- `home/macos/plists/`: desired plist fragments (partial-merge bundles).
- `home/dot_agents/`: machine-wide agent surface. Skill packages live under `packages/`; renderer templates under `templates/`.
- `.agents/`: repo-local agent surface for this checkout. Keep repo-specific `AGENTS.md` and `CLAUDE.md` at the repo root; keep repo-local skills and tool adapters under `.agents/`.
- `scripts/`: focused helpers for packages, macOS/app config, plist + JSON + TOML mergers, Tart, traces, audits.
- `docs/dev/`: plans and runbooks for repo changes.
- `docs/adr/`: architectural decisions. Migration: [ADR 0009](docs/adr/0009-migrate-to-nix.md).
- `docs/*.md`: operator-facing repo references.

Nix is the ongoing command surface: prefer `darwin-rebuild build/switch --flake .#<host>`, `nix flake check`, and `nix flake update` over adding a wrapper.

Keep repo-local and machine-level agent state separate. Files that define how agents work in this dotfiles checkout stay at the repo root or under repo-root `.agents/`. Files that configure Prateek's machine-wide agent environment stay under `home/` so home-manager materializes them into `$HOME`.

Use `$agent-skill-management` for changes to `home/dot_agents/packages/`,
activation-time skill/plugin render scripts, Codex or Claude rendered plugin
activation, and the related docs (`docs/dev/chezmoi-agent-skills-plan.md`,
`docs/dev/agent-skill-management-research.md`, `docs/adr/0007-default-loaded-plugin-policy.md`). The generated live roots are
`~/.agents/skills`, `~/.claude/skills`, and `~/.agents/plugins`; do not commit
source copies under `home/dot_agents/skills`, `home/dot_claude/skills`, or
`home/dot_agents/plugins`.

## Docs And Decisions

- Non-trivial repo initiatives get a plan at `docs/dev/<slug>-plan.md`.
- Architectural decisions get the next numbered ADR at `docs/adr/<NNNN>-<slug>.md`; never renumber existing ADRs.
- Markdown docs under `docs/` must use YAML frontmatter with a canonical `status`; follow [docs/document-lifecycle.md](docs/document-lifecycle.md) for states and transitions.
- Plan docs reference their ADRs, and ADRs reference the plan docs that prompted them. Prefer Markdown-relative links for in-repo docs.
- Small one-off fixes do not need a plan or ADR.
- `README.md` is user-facing and intentionally tiny. Move coding-agent or maintenance details here or into focused docs instead.
- `AGENTS.md` should contain durable conventions only. Do not add one-off session notes.

## Common Commands

- Build (no switch): `darwin-rebuild build --flake .#prateek-mac`.
- Apply: `darwin-rebuild switch --flake .#prateek-mac` (review the diff first).
- Rollback: `darwin-rebuild --rollback` (or `--list-generations` to pick).
- Evaluate-only: `nix flake check`.
- Update inputs: `nix flake update` (or `nix flake lock --update-input <name>`).
- Package/app audits: `scripts/audit/brew-inventory.sh`, `scripts/audit/brewfile-usage.sh`, `scripts/audit/app-inventory.sh`.
- Fresh-shell checks: `scripts/audit/zsh-fresh-shells.zsh verify` and `bench`.
- Test index: `tests/README.md`.
- Tart local install lane: `docs/dev/tart-mini-validation.md` (the helper still references chezmoi; see TODO(nix) in the script).
- Worktree workflow: `home/dot_agents/docs/worktrees.md`.
- Git/commit workflow: `home/dot_agents/docs/git.md`.

## Nix And App Config

- Keep app config readable at the native target path under `home/` when possible; nix modules reference it by relative path.
- Simple file-backed apps go in `nix/modules/home/apps.nix` under a `profile.apps.<name>.enable` option.
- Nested preference plists use a desired-plist fragment at `home/macos/plists/<bundle-id>.plist` consumed by `nix/modules/darwin/activation.nix` via `scripts/macos/plist-merge`.
- Plist fragments are plain `.plist` files (no Go templating). When you need to substitute a runtime value (e.g. VoiceInk's base64-encoded prompts), use a `__PLACEHOLDER__` token and substitute it in the activation script.
- Gate optional app config behind per-app `profile.apps.<name>.enable` options. Default true; flip to false in the host config when the cask is absent.
- Secret-backed configs and licenses are 1Password-driven activation hooks in `nix/modules/home/secrets.nix`; store only obfuscated `op://` refs in the host config under `profile.secrets.refs.<key>`.
- Raw app captures live under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`, not in the repo.
- Mac App Store entries are opt-in with `profile.installMas = true`.
- Setapp-managed apps install after Setapp login. Do not add config for a Setapp-installed app until the repo also has an install path for that app.
- Chrome extension settings are not snapshotted from user profiles. Prefer Chrome Sync or extension-native export.

## Shell Startup

Shell load order:

```text
zshenv -> zprofile -> zshrc -> init.sh -> zinit-init.zsh -> lib/*.zsh -> extra/*.zsh
```

- Keep baseline `PATH` entries in `zprofile`'s `path=(...)` array, not ad hoc `export PATH=...` snippets in `zshrc`.
- Keep host-local shell secrets and env overlays in `$HOME/.zprofile.local` or `$HOME/.zshrc.local`; they are sourced by managed zsh startup and not managed by nix.
- Prefer explicit directories like `$HOME/go/bin` over indirect env vars like `$GOPATH/bin` for shell PATH setup.
- When startup only needs mise shims, add `$HOME/.local/share/mise/shims` to `zprofile` instead of running `mise activate --shims` on every shell.
- Reserve `zshrc` PATH mutations for interactive or late overlays only.
- Prefer autoloaded wrappers for optional or conflicting CLIs instead of source-time aliases.
- For zoxide, prefer lazy wrappers plus `zoxide init zsh --cmd j`; keep `zi` reserved for zinit.
- Avoid source-time command substitutions such as `$(brew --prefix)`. Prefer `HOMEBREW_PREFIX`, `whence -p`, or resolution at call time.
- Guard shell widgets and key-binding scripts behind `[[ -o zle ]]`.
- Use a real PTY login shell for shell widget/keymap debugging; `zsh -ic` can lie about ZLE.
- Synthetic shell harnesses must set `DOTFILES_SKIP_LAUNCHCTL_SYNC=1`.
- If syncing `PATH` into `launchctl`, compare against `launchctl getenv PATH`, not a persistent cache file.

## Validation

- For code behavior changes, add or update the smallest meaningful tests and run the relevant local checks.
- For docs/config-only changes, run the lightest checks that prove links, parsers, or generated output still make sense.
- Mirror CI locally when practical by inspecting `.github/workflows`.
- Current CI includes shellcheck, `nix flake check`, Tart helper contract tests, trace conversion tests, and a Mac job that runs `darwin-rebuild build --flake .#prateek-mac` (no switch).
- CI does not boot a full macOS VM; that is local via Tart.
- Never ignore test output. If expected errors are part of behavior, assert them.

## Dependency And Tooling Gotchas

- Python imports must be declared in `pyproject.toml`; add stubs and build-system dependency mirrors when typecheck/build rules need them.
- When testing, evaluating, or selecting a specific CLI version, prefer mise (`mise use`, `mise link`, or a repo-owned `mise run <tool>:use` task) over swapping Homebrew/npm/cargo/pipx installs. Use ignored `mise.local.toml` for per-worktree experiments; commit durable machine-wide selections under `home/dot_config/mise/`.
- For skill-creator eval review (the human-review HTML over an iteration directory), default to `scripts/eval-review.py`. Use the canonical skill viewer (`generate_review.py`) only if the user explicitly asks for it.
- After editing a skill, validate it. Frontmatter/parser drift has bitten this repo before.
- If CI says to run the build file generator and provides a diff, apply that diff exactly when local generation is blocked by auth/network/private module issues.
- Use `git diff --check` before handoff on non-trivial docs or code changes.
- Do not edit `flake.lock` by hand; use `nix flake lock --update-input <name>` or `nix flake update`.
