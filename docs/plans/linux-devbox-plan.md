---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-24
updated: 2026-09-30
related:
  - ../adr/0040-devbox-machine-type.md
  - ../adr/0043-devbox-os-gating.md
  - ../adr/0012-config-gating-convention.md
  - ../adr/0039-work-overlay-in-work-repo.md
status_detail: "Increments 1-4 verified on the devbox; ADR 0043 replaced the allowlist with OS gates, and an apply from that branch installed the agent surface. The Ubuntu CI job waits on a token with workflow scope; the rollback rehearsal and the onstart run on a fresh box remain."
---

# Linux devbox

Run the dotfiles on Prateek's Linux devbox, a Cloud Workstation that work
tooling provisions, and run headless Orca there for desktop Orca on the Mac.
[ADR 0040](../adr/0040-devbox-machine-type.md) records the `devbox` machine type;
[ADR 0043](../adr/0043-devbox-os-gating.md) replaced its allowlist with OS gates.

## Ownership

Work tooling runs a **bootstrap** on first creation, on resume, and on config
pushes. It runs a **boot hook** on every start. Both hand control last to
Prateek's **onstart hook**, and that hook is the only place the devbox lifecycle
calls into the dotfiles. The onstart hook runs only when
`DEVBOX_RUN_USER_ONSTART=true` in the laptop's `~/.devbox.local`, which resume
seeds onto the box.

| Owner | Paths |
|---|---|
| Bootstrap | `~/.gitconfig`, `~/.bashrc`, `~/.tmux.conf`, `~/.claude.json`, Claude credentials, its own keys in `~/.claude/settings.json` |
| Agent sync (continuous) | `~/.claude/{skills,commands,rules,agents}` |
| Image | `chezmoi`, `uv`, `mise` (activated from `/etc/profile.d`), `zsh`, `tmux`, `perl` |
| Dotfiles | The full source state, less the macOS targets and synced agent asset directories `home/.chezmoiignore` gates off Linux |

Git reads `~/.config/git/config` before `~/.gitconfig`, so on the devbox the
dotfiles render their git config to the XDG path and the bootstrap's identity
and credential settings win.

## Decisions

- The onstart hook in the work repo is a thin trampoline. It sets PATH, clones
  the dotfiles over https if they are missing, and runs
  `~/dotfiles/scripts/devbox/onstart`. The dotfiles own everything after that.
- The first apply runs only when no completion marker exists. The script writes
  the marker after a successful apply. Later boots run only the Orca reconciler.
  Updates are manual, with `chezmoi update`. The boot hook kills the onstart
  process group after 10 minutes, so the first apply and the Orca reconcile
  both detach with `setsid` and log under `~/.local/state/dotfiles/`. The first
  apply holds a `flock`, so a boot during it changes nothing.
- Tools come from Homebrew and mise, as on the Macs. The devbox selects only
  the `devbox` group: the formulae agent sessions ran in a 60-day measurement,
  nothing more. mise config is identical on every machine type. Casks, Mac App
  Store apps, and the `mac-developer-tools` group stay on macOS. Setapp and macOS defaults scripts
  stay ignored. `claude` and `cursor-agent` are provided by work tooling.
  Homebrew's git, tmux, and nvim shadow the image's copies.
- `agent_clis = ["claude", "cursor-agent", "omp", "pi"]` with no acpx routes.
  Script 36 builds the agent marketplace into `~/.agents/plugins` and installs
  the enabled Claude plugins, as on the Macs.
- Orca: `~/.local/bin/orca-devpod-reconcile` (Linux only) takes `start`,
  `stop`, `status`, and `pair`. `start` caches the pinned `.deb`,
  checks its SHA-256, reinstalls it with `sudo -n apt-get` whenever the
  installed version differs, because a stop/start discards everything outside
  `/home`, and serves in a tmux session. The pin tracks desktop Orca on the
  Mac. The onstart hook's `DEVBOX_ORCA_HEADLESS_ENABLED` decides whether it
  starts. Orca's server binds `0.0.0.0` behind the Cloud Workstation IAM
  gateway, per-device tokens, and end-to-end encryption. `start` always serves
  with `--no-pairing`, so no serve log can enroll a device. Pairing runs from
  the Mac with the `devbox-orca-pair` skill, which lives in the work overlay's
  `work` plugin ([ADR 0039](../adr/0039-work-overlay-in-work-repo.md)): `pair` restarts the
  server with an offer on the loopback pairing address, the Mac captures the
  code straight into `orca environment add`, and `start` closes the offer.
  A repeat `start` changes nothing while the server runs the installed
  package with the same runner.
  The runner sets `SHELL` to the login shell, since Orca terminals open
  `$SHELL` and a shared tmux server hands down whatever shell started it.
  `stop` also ends Orca's detached PTY daemon, so a restart or upgrade never
  keeps the old version or environment, and it waits for every Orca process to
  exit, because a server still tearing down holds Orca's single-instance lock.
- Each proven increment is one landable commit. Nothing lands until Prateek
  says so.

## Increments

1. `devbox` type, ADR, and an empty allowlist. The apply manages nothing and the
   hooks survive Linux. (Done; ADR 0043 later retired the allowlist.)
2. Shell: zsh, git (XDG), tmux, Homebrew and the bundle, mise config, nvim,
   inputrc, lesskey, vimrc. The login shell switch to zsh is a work-tooling setting
   (`DEVBOX_LOGIN_SHELL=zsh` in the laptop's `~/.devbox.local`).
3. Agent surface: `~/.agents` docs, built plugins, Claude settings merge.
   Done by retiring the allowlist (ADR 0043); verified with an apply on the
   devbox: 12 plugins built, the five enabled ones installed.
4. Orca by hand, then the reconciler and its rendered config.
5. Onstart script, the rollback rehearsal, and an Ubuntu CI lane. The
   `devbox-linux` job for `install-smoke.yml` (the devbox apply dry-run and
   render cases on Ubuntu) is written but not landed: pushing a workflow change
   needs a token with `workflow` scope. The rehearsal needs a box stop/start.
6. Land, then the trampoline PR in the work repo.

## Known collisions and deferred work

- `~/.vimrc`: the dotfiles manage it, and every bootstrap run appends a marker
  block that sources a work-repo vim fragment if one exists. The block does
  nothing today, but it shows up as drift until the next apply strips it.
  Accept the churn and fix it later.
