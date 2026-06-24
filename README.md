# Dotfiles

Personal macOS dotfiles for Prateek, managed with chezmoi. Homebrew handles packages, mise handles runtimes and tasks, and selected shell, app, and macOS config is declared under `home/`.

## Install

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

The first run prompts for machine type (`personal`, `homelab`, or `work`), macOS defaults, install scripts, secret-backed files, and administrator access when Homebrew/packages/defaults need it. Machine type drives package selection — `work` skips the personal apps (Tailscale, Arq, VoiceInk). The generated chezmoi config disables chezmoi's pager so sudo can read from the terminal during apply. If an older local config still pages output, rerun with `chezmoi --no-pager apply`.

Personal, homelab, and work machines install `xcodes`, but the Xcode download itself is opt-in because Apple may require Apple ID login:

```sh
DOTFILES_INSTALL_XCODE=true chezmoi apply
```

Answers live in `~/.config/chezmoi/chezmoi.toml`.

Use the minimal `ci` machine type for a faster, base-only install:

```sh
DOTFILES_MACHINE_TYPE=ci \
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

After 1Password CLI is signed in, render private config with:

```sh
DOTFILES_SECRETS_ENABLED=true chezmoi apply
```

## Notes

- Source state in `home/` materializes into `$HOME`.
- Repo-local agent guidance lives in `AGENTS.md`; `CLAUDE.md` points there too. Repo-local skills live in `.agents/skills/`, with `.claude/skills` as the Claude Code adapter. Machine-wide agent guidance and skills are managed under `home/dot_agents/` and materialize to `~/.agents`.
- Plans live in `docs/plans/`; references in `docs/references/`; runbooks in `docs/runbooks/`; decisions in `docs/adr/`.
