# Dotfiles

Personal macOS dotfiles for Prateek, managed with chezmoi. Homebrew handles packages, mise handles runtimes and tasks, and selected shell, app, and macOS config is declared under `home/`.

## Install

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

The first run prompts for machine type (`personal`, `homelab`, `work`, or `ci`) and, on `work`, the Jamf policy ID; it also asks for administrator access when Homebrew/packages/defaults need it. Machine type drives package selection and behavior (install scripts, macOS defaults, secret-backed files, elevation) via `home/.chezmoidata/machines.toml`. `work` gets the Mac desktop and developer stack without personal apps or Apple-development packages; `personal` gets Mac desktop, developer, and personal apps without Apple-development packages; `homelab` gets developer, Apple-development, and remote/admin apps without the full Mac desktop surface. The generated chezmoi config disables chezmoi's pager so sudo can read from the terminal during apply. If an older local config still pages output, rerun with `chezmoi --no-pager apply`.

Homelab machines install `xcodes`, but the Xcode download itself is opt-in because Apple may require Apple ID login:

```sh
DOTFILES_INSTALL_XCODE=true chezmoi apply
```

Answers live in `~/.config/chezmoi/chezmoi.toml`.

Use the minimal `ci` machine type for a faster, core-only install (`--promptChoice` keys on the prompt name):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --promptChoice 'machine_type=ci' --source ~/dotfiles prateek
```

Secret-backed files (1Password) are on for personal machines and off elsewhere. chezmoi reads them as a 1Password service account whose token lives in the login keychain, so an apply needs no `op signin`. When the token is missing, the bootstrap `chezmoi init --apply` reads it from your own 1Password account (approve the unlock prompt) and stores it in the keychain. A plain `chezmoi apply` only checks and stops; rerun `chezmoi init --apply`, or store the token by hand:

```sh
security add-generic-password -U -s op-devland-sa -a "$USER" -w   # prompts for the token
chezmoi init          # machines set up before this: re-render the config with its [onepassword] block
chezmoi apply
```

Another machine opts in with `chezmoi edit-config` and a `[data.machines_local]` block setting `secrets_enabled = true`; a personal machine can opt out the same way with `false`.

The service account needs read access to the vault that holds each ref in `home/.chezmoidata/secrets.toml` (or this machine's `[data.secrets.refs]`); service accounts cannot read the Private vault.

## Notes

- Source state in `home/` materializes into `$HOME`.
- Repo-local agent guidance lives in `AGENTS.md`; `CLAUDE.md` points there too. Repo-local skills live in `.agents/skills/`, with `.claude/skills` as the Claude Code adapter. Machine-wide agent guidance and skills are managed under `home/dot_agents/` and materialize to `~/.agents`.
- Plans live in `docs/plans/`; references in `docs/references/`; runbooks in `docs/runbooks/`; decisions in `docs/adr/`.
