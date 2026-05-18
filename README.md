# Dotfiles

Personal macOS dotfiles for Prateek, managed with [Nix Flakes](https://nixos.wiki/wiki/Flakes), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager). Homebrew (via `nix-darwin.homebrew`) handles packages and casks, mise handles runtimes and tasks, and selected shell, app, and macOS config is declared under `home/`.

## Install

```sh
xcode-select --install

# 1. Install nix (Determinate Systems installer recommended).
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Clone the repo.
git clone https://github.com/prateek/dotfiles ~/dotfiles
cd ~/dotfiles

# 3. Build the system (no apply yet) and inspect.
nix run nix-darwin -- build --flake .#prateek-mac

# 4. Apply.
nix run nix-darwin -- switch --flake .#prateek-mac
```

After the first switch, `darwin-rebuild` is on your PATH and you can run it directly:

```sh
darwin-rebuild switch --flake ~/dotfiles#prateek-mac
darwin-rebuild --rollback        # undo to the previous generation
darwin-rebuild --list-generations
```

### Profiles and toggles

The host config at `nix/hosts/prateek-mac.nix` exposes a `profile.*` option block (defaults shown):

```nix
profile.install            = "full";     # "core" | "full"
profile.installMas         = false;      # Mac App Store apps
profile.installXcode       = false;      # Xcode + Xcode-only brews
profile.runInstallScripts  = true;       # mise install, gh extensions, skill renders
profile.applyMacosDefaults = true;       # nix-darwin defaults + activation script
profile.secrets.enabled    = false;      # 1Password op:// hooks
```

Override per host or per worktree by editing the host file or by overlaying a `nix/hosts/<machine>.nix` and pointing `darwin-rebuild` at it.

### Secrets (1Password)

Secret-backed files (BetterTouchTool / Moom / Alfred licenses, private app configs) are written at activation time by `op read` against the refs you set under `profile.secrets.refs`. To enable:

```sh
op signin
# then on next rebuild
profile.secrets.enabled = true;  # in nix/hosts/prateek-mac.nix
darwin-rebuild switch --flake .#prateek-mac
```

## Migration from chezmoi

This repo was migrated from chezmoi to Nix in 2026. See [ADR 0009](docs/adr/0009-migrate-to-nix.md) and [the plan](docs/dev/chezmoi-to-nix-plan.md). The migration is **Phase 0**: scaffolded but not yet validated end-to-end on a real Mac. Expect iteration. If something blows up, `git revert <pre-migration-sha>` brings chezmoi back; the chezmoi infrastructure is recoverable from git history.

## Notes

- Source content in `home/` is referenced by nix modules under `nix/`; together they materialise into `$HOME` via home-manager.
- Repo-local agent guidance lives in `AGENTS.md`; `CLAUDE.md` symlinks there. Repo-local skills live in `.agents/skills/`, with `.claude/skills` as the Claude Code adapter. Machine-wide agent guidance and skills are managed under `home/dot_agents/` and materialise to `~/.agents` via home-manager.
- Plans live in `docs/dev/`; decisions live in `docs/adr/`.
