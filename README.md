# Dotfiles

Personal macOS dotfiles for Prateek, managed with chezmoi. Homebrew handles packages, mise handles runtimes and tasks, and selected shell, app, and macOS config is declared under `home/`.

## Install

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

The first run prompts for install profile (`core` or `full`), macOS defaults, install scripts, secret-backed files, and administrator access when Homebrew/packages/defaults need it. The generated chezmoi config disables chezmoi's pager so sudo can read from the terminal during apply. If an older local config still pages output, rerun with `chezmoi --no-pager apply`.

`full` installs `xcodes`, but the Xcode download itself is opt-in because Apple may require Apple ID login:

```sh
DOTFILES_INSTALL_XCODE=true chezmoi apply
```

Answers live in `~/.config/chezmoi/chezmoi.toml`.

Use a faster profile with:

```sh
DOTFILES_INSTALL_PROFILE=core \
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

After 1Password CLI is signed in, render private config with:

```sh
DOTFILES_SECRETS_ENABLED=true chezmoi apply
```

## Notes

- Source state in `home/` materializes into `$HOME`.
- Agent guidance lives in `AGENTS.md`; `CLAUDE.md` points there too.
- Plans live in `docs/dev/`; decisions live in `docs/adr/`.
