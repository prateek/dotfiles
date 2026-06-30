# Dotfiles

Personal macOS dotfiles for Prateek, managed with chezmoi. Homebrew handles packages, mise handles runtimes and tasks, and selected shell, app, and macOS config is declared under `home/`.

## Install

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

The first run prompts for machine type (`personal`, `homelab`, `work`, or `ci`) and, on `work`, the Jamf policy ID; it also asks for administrator access when Homebrew/packages/defaults need it. Machine type drives package selection and behavior (install scripts, macOS defaults, secret-backed files, elevation) via `home/.chezmoidata/machines.toml` — `work` skips the personal apps (Tailscale, Arq, VoiceInk) and the Apple/iOS toolchain. The generated chezmoi config disables chezmoi's pager so sudo can read from the terminal during apply. If an older local config still pages output, rerun with `chezmoi --no-pager apply`.

Personal and homelab machines install `xcodes`, but the Xcode download itself is opt-in because Apple may require Apple ID login:

```sh
DOTFILES_INSTALL_XCODE=true chezmoi apply
```

Answers live in `~/.config/chezmoi/chezmoi.toml`.

Use the minimal `ci` machine type for a faster, base-only install (`--promptChoice` keys on the prompt name):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --promptChoice 'machine_type=ci' --source ~/dotfiles prateek
```

Secret-backed files (1Password) are off by default. After `op` is signed in, enable them for this machine and apply:

```sh
chezmoi edit-config   # add a [data.machines_local] block with secrets_enabled = true
chezmoi apply
```

## Notes

- Source state in `home/` materializes into `$HOME`.
- Repo-local agent guidance lives in `AGENTS.md`; `CLAUDE.md` points there too. Repo-local skills live in `.agents/skills/`, with `.claude/skills` as the Claude Code adapter. Machine-wide agent guidance and skills are managed under `home/dot_agents/` and materialize to `~/.agents`.
- Plans live in `docs/plans/`; references in `docs/references/`; runbooks in `docs/runbooks/`; decisions in `docs/adr/`.
