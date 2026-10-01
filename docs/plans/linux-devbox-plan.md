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
status_detail: "Increments 1-4 verified on the devbox; ADR 0043 replaced the allowlist with OS gates. On 2026-09-30 the trampoline, first apply, and headless Orca ran on a fresh prateek-devbox-orca-1, with the onstart hook run by hand after the first boot skipped it, and desktop Orca paired it as work-devbox. The Ubuntu CI job waits on a token with workflow scope; the rollback rehearsal remains."
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

- Naming: the workstation is `prateek-devbox-<purpose>-<N>`, currently
  `prateek-devbox-orca-1` on `devpod-always-on-16`, pinned as `DEVBOX_WS` and
  `DEVBOX_CONFIG` in the laptop's `~/.devbox.local`. A rebuild bumps `N`,
  because a deleted name stays taken until its teardown finishes. Desktop Orca
  names the environment with the fixed alias `work-devbox` on the fixed tunnel
  port 16768, so a rebuild re-pairs under the same name and changes only the
  pin and the tunnel's box argument. Create the box
  with `gcp.sh create`, which labels it `owner=<laptop $USER>`. The toolkit
  watchdog accepts that label for a name outside `${USER}-devbox-*`.
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
- The Mac end of the pairing is the `com.prateek.devbox-orca-tunnel` launch
  agent, on machines with the `devbox_orca_tunnel` feature (work). It runs
  `~/.local/bin/devbox-orca-tunnel run`, which reads `DEVBOX_WS` from
  `~/.devbox.local` on every start and forwards 127.0.0.1:16768 to the box's
  6768 over the `droidcli devpod ssh-config` Host entry. The ssh process is
  its own connection, not a ControlMaster client, so launchd's running state
  is the tunnel's state, and the Raycast Launchd Monitor watches the label in
  the menu bar. Add that label to the extension's preferences by hand; they
  live in Raycast's encrypted store. After a rebuild or an ssh-config change,
  run `devbox-orca-tunnel restart`. It replaces the work overlay's tmux
  tunnel, whose note that endpoint security flagged launchd keepalives had no
  source; two KeepAlive-free launch agents and the toolkit's own watchdog
  agent run cleanly on the work Mac.
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
- First boot skips the onstart hook. The bootstrap looks for the hook in
  `~/spacejunk-sync` or agentd's Spacejunk clone, and neither exists until
  agentd's first sync, so `gcp.sh up` on a new box logs `user onstart enabled,
  but ... is absent`. Once `gcp.sh ready` passes, run the hook by hand:
  `set -a; . ~/.devbox.local; set +a; timeout 600
  ~/spacejunk-sync/devbox/configs/prateek/dotfiles/onstart.sh`. Any later boot
  or resume would also run it.
