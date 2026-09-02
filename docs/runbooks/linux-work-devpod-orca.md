---
status: current
doc_type: runbook
owner: Prateek
created: 2026-09-02
updated: 2026-09-02
related:
  - ../plans/linux-work-devpod-orca-pilot-plan.md
  - ../references/chezmoi-architecture.md
  - ../references/chezmoi-hook-lifecycle.md
  - ../adr/0012-config-gating-convention.md
status_detail: "Bootstrap, pairing, recovery, and ownership procedure for the default-off work × Linux Orca pilot."
---

# Linux work DevPod and Orca

This runbook operates Prateek's default-off Orca headless pilot on a
Chronosphere Cloud Workstation. Spacejunk owns workstation bootstrap and the
image; this repo supplies the minimal `work × linux` chezmoi profile and Orca
reconciler.

## Ownership boundary

The Linux composite profile resolves from
`home/.chezmoidata/machines-composite.toml`. It keeps `machine_type=work` for
identity while replacing the Mac-oriented behavior:

- Spacejunk keeps ownership of image packages, runtimes, Git identity, root
  `~/.zshrc`, mise, tmux, Neovim, direct Claude skill/command/rule/agent trees,
  and its own keys in Claude settings.
- Chezmoi manages portable zsh files under `$ZDOTDIR`, Orca keybindings,
  `orca-cli`, `orca-devpod-reconcile`, the `prateek-local` Claude settings
  keys, package sources, the headless uv bootstrap, and the generated
  `~/.agents/plugins` marketplace.
- General chezmoi package/runtime scripts, skill-root maintenance, the private
  overlay, macOS defaults, and unrelated pi/crit settings do not run. The
  plugin renderer is the only enabled apply script; uv comes from the earlier
  `read-source-state.pre` config hook.

The root `~/.zshrc` is ignored so chezmoi cannot delete an image-owned file.
Once the managed `~/.zshenv` selects `ZDOTDIR`, zsh reads the managed startup
files instead. Spacejunk's `/etc/zsh/zprofile` shim provides the shared
workstation environment without modifying either root file.

## Enable the pilot

Set these values in the laptop's `~/.devbox.local`, then run the normal
Spacejunk `gcp.sh up` or `gcp.sh resume` path:

```sh
DEVBOX_RUN_USER_ONSTART=true
DEVBOX_ORCA_HEADLESS_ENABLED=true
DEVBOX_LOGIN_SHELL=zsh
```

The per-user Spacejunk hook fast-forwards `~/dotfiles` only when it is already
on `master`, initializes chezmoi as `machine_type=work`, validates that identity
with `chezmoi data`, applies the Linux composite profile, and reconciles Orca
to the requested state. The generated chezmoi config installs checksum-pinned
uv from `read-source-state.pre`; in this sequence, the `data` command triggers
it before apply. Apply can then use uv for the Claude settings modifier and
plugin renderer. Spacejunk does not know about these steps. Setting
`DEVBOX_ORCA_HEADLESS_ENABLED=false` stops the tmux service on the next hook run.

## Agent skills

Spacejunk continues to publish its direct `agentsview`, `devbox`, `devserver`,
`doc-lifecycle`, and `pr-lifecycle-v4` skills under `~/.claude/skills`.
Dotfiles renders a separate local plugin marketplace under
`~/.agents/plugins`. Its settings merge preserves Spacejunk keys and enables
the default-loaded `core`, `mattpocock`, `review`, and `utils-agent` plugins.
The `design`, `experimental`, `ios`, `obsidian-wiki`, and `utils-human`
packages render but remain disabled. Codex is not activated by this profile.

## Tunnel and pair

Orca desktop already uses local port 6768. From the Spacejunk checkout on the
laptop, map the workstation's serving port to local port 16768:

```sh
devbox/setup/gcp.sh tunnel prungta-devbox-1 6768 16768
```

On the DevPod:

```sh
orca-devpod-reconcile start
orca-devpod-reconcile status
```

On first start, retrieve the `orca://` pairing offer from the private
`~/.local/state/orca-headless/serve.log` and complete it in desktop Orca. Do
not paste that offer into chat, tickets, or shared logs. After pairing:

```sh
orca-devpod-reconcile disable-pairing
```

That command creates `~/.config/orca/pairing-complete` with mode 0600 and
restarts the server with `--no-pairing`.

## Network and credential boundary

Orca 1.4.193 reports its serving endpoint as `ws://0.0.0.0:6768`; the
reconciler requires that exact endpoint so a release behavior change fails
visibly. The pairing address remains `127.0.0.1:16768`, which matches the
laptop-side tunnel.

The tunnel adds an authenticated route; it does not make port 6768
tunnel-exclusive. The pilot relies on Cloud Workstations IAM, Orca client
authentication, and keeping the pairing offer private. Principals already
authorized to reach the workstation may have a route to high ports, but still
need Orca credentials. Do not expose the service through a public ingress.

Treat `~/.config/orca` and `serve.log` as sensitive. The pilot relies on the
workstation's encrypted persistent disk plus 0700 directories and 0600 files;
it does not add a keyring or KMS envelope around Orca's upstream credential
store.

## Recovery

Inspect state without killing unrelated processes:

```sh
orca-devpod-reconcile status
tmux has-session -t orca-headless
ss -ltn 'sport = :6768'
```

The reconciler stops only its named tmux session. If another process still
owns port 6768, it fails closed; identify that owner instead of using a broad
`pkill` or `fuser -k`.

To generate a fresh pairing offer:

```sh
rm -f ~/.config/orca/pairing-complete
orca-devpod-reconcile start
```

Pair again, then rerun `orca-devpod-reconcile disable-pairing`.

The pinned Debian package is downloaded into
`~/.cache/orca/<version>/`, checked against its committed SHA-256 before
installation, and reinstalled or downgraded when the installed package does
not match the pinned executable.

## Validation

Before landing a profile or reconciler change:

```sh
make test-machines-features
make test-headless-uv-bootstrap
make test-linux-work-profile
make test-orca-devpod-reconcile
make test-agent-skill-packages
make test-claude-settings
git diff --check
```

For a live cold-start check, stop and restart the workstation, confirm the
Spacejunk hook completes, verify `orca-devpod-reconcile status`, reconnect the
tunnel, and open an existing Orca environment without generating a new pairing
offer.
