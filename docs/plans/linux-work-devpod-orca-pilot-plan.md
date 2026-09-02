---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-01
updated: 2026-09-02
related:
  - ../runbooks/linux-work-devpod-orca.md
  - ../references/chezmoi-architecture.md
  - ../references/chezmoi-hook-lifecycle.md
  - ../adr/0012-config-gating-convention.md
status_detail: "Spacejunk layers have landed; dotfiles hardening and the final cold-start acceptance pass remain."
---

# Linux work DevPod Orca pilot

## Goal

Run Prateek's portable work dotfiles and Orca headless on the existing
Chronosphere Cloud Workstation without changing the macOS work profile or
making the behavior the default for another user.

The steady-state operator procedure is the
[Linux work DevPod and Orca runbook](../runbooks/linux-work-devpod-orca.md).

## Boundaries

- Keep `machine_type=work`; derive the Linux flavor from `.chezmoi.os`.
- Preserve every existing Darwin machine profile.
- Leave image packages, runtimes, Git identity, and direct shared agent assets
  under Spacejunk ownership. Dotfiles owns its user-local rendering
  prerequisites.
- Keep the pilot opt-in through per-user Spacejunk variables.
- Use the released checksum-pinned Debian package and a user tmux session.
- Use the existing Cloud Workstations tunnel and Orca authentication boundary.
- Do not add shared network policy, a private-overlay dependency, systemd
  state, or a new dotfiles wrapper command.

## Design

`features.tmpl` merges a type × OS composite after the one-axis type layer and
before host overrides:

```text
defaults < os < type < composite < host < machines_local
```

The `work × linux` composite selects only the `core` package group, disables
general chezmoi install scripts, macOS defaults, elevation, the private
overlay, and session-wiki integration, and selects `orca_mode=headless`. It
configures a pre-source-state uv prerequisite and allows only the agent-plugin
apply script, which projects package source into `~/.agents/plugins`.

Spacejunk provides two landed layers:

- [PR #972](https://github.com/chronosphereio/spacejunk/pull/972): common
  configurable login-shell support and a bounded per-user startup hook.
- [PR #973](https://github.com/chronosphereio/spacejunk/pull/973): Prateek's
  default-off hook that updates `~/dotfiles`, applies `machine_type=work`, and
  starts or stops Orca.

Dotfiles installs uv from `hooks.read-source-state.pre`, before chezmoi
computes its uv-backed Claude settings target. The later `run_after_` plugin
renderer uses the same installation. Dotfiles deep-merges only its
`prateek-local` marketplace and plugin keys into Claude settings after
Spacejunk has written its own keys. Spacejunk remains the sole writer of the
direct `~/.claude/{skills,commands,rules,agents}` trees and has no uv or
plugin projection logic.

This repo owns the platform-aware `orca-cli` wrapper and
`orca-devpod-reconcile`. The reconciler verifies the package checksum, repairs
the pinned installation, serializes state changes, supervises Orca in tmux,
checks the emitted ready event, and requires an explicit transition from
pairing mode to `--no-pairing`.

## Work graph

```text
released-package and tunnel spike ─┐
                                   ├─> Linux profile + ownership gates ─┐
Spacejunk common hook ─────────────┘                                    │
                                                                        ├─> final cold-start pilot
Spacejunk per-user hook ─────────────> dotfiles apply + Orca reconcile ──┤
                                                                        │
CI + docs + macOS regression checks ────────────────────────────────────┘
```

| Work | State |
| --- | --- |
| Debian package, headless serve, tunnel, and pairing spike | Complete |
| Spacejunk common startup-hook and login-shell support | Landed |
| Spacejunk Prateek-specific desired-state hook | Landed |
| Linux composite profile and image-ownership ignores | In dotfiles PR #14 |
| Plugin projection, reconciler hardening, pairing command, and Ubuntu lane | In dotfiles PR #14 |
| Cold-start with the landed branches and pairing disabled | Pending |

## Acceptance

The pilot is complete when:

1. Darwin `work`, `personal`, `homelab`, and `ci` rendering remain unchanged
   except for intentional platform-neutral wrapper changes.
2. A clean Ubuntu test environment applies `work × linux` without Homebrew,
   Jamf, private externals, or preinstalled uv; chezmoi supplies uv itself.
3. Spacejunk-owned Claude asset trees remain untouched, its settings keys
   survive the dotfiles merge, and the local plugin marketplace is rendered.
4. A corrupt Orca package cannot reach `apt-get`.
5. Pinned-version downgrade and reinstall recovery are tested.
6. Pairing can be disabled explicitly and stays disabled across restarts.
7. A workstation cold start converges automatically, reconnects through
   `gcp.sh tunnel`, and opens an existing paired Orca environment.

## Risks and deferred work

- Port 6768 is not tunnel-exclusive. The pilot accepts the existing Cloud
  Workstations IAM plus Orca authentication boundary; public ingress remains
  out of scope.
- Orca's credential store is protected by the workstation's encrypted
  persistent disk and file permissions, not by a new keyring or KMS layer.
  Upstream-backed secret storage is follow-up work before a broader rollout.
- The exact user hook is intentionally personal. Generalizing Orca lifecycle
  into shared Spacejunk infrastructure requires a separate adoption decision.

After the final cold-start acceptance pass, archive this plan and keep the
runbook and architecture reference as current guidance.
