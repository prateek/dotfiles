---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-07-04
updated: 2026-07-04
related:
  - tartelet-runner-plan.md
  - ../runbooks/tartelet-runner-setup.md
  - ../adr/0014-tartelet-self-hosted-runners.md
status_detail: "Design proposal. A prototype was built and validated on 2026-07-04 (all checks passed) but not kept in-tree; this branch carries docs only. Implement from the design here. The m4mini is unprotected until this is built and applied."
---

# Tartelet Runner Memory-Guard Proposal

On 2026-07-03 a self-hosted runner build drove the homelab m4mini out of memory,
macOS started killing host processes, and the machine wedged hard enough to need a
manual power cycle. This proposes a host memory-pressure circuit breaker that sheds
the runner before that happens again. A prototype was built and validated during the
investigation, then dropped so this branch carries only the design — this doc is the
spec to implement from when you pick it back up.

The parent initiative is the [Tartelet runner plan](tartelet-runner-plan.md) and
[ADR 0014](../adr/0014-tartelet-self-hosted-runners.md); the operator guide is the
[runner setup runbook](../runbooks/tartelet-runner-setup.md).

## The incident (2026-07-03)

A `workflow_dispatch` build (`prateek/forks`, run 28693677688) ran on the runner
for ~27 minutes before Prateek canceled it. During that window macOS logged a
`JetsamEvent` at 07:15:38 — the low-memory killer firing. What it killed is the
tell:

| Killed process | RAM |
| --- | --- |
| OrbStack Helper | 1129 MB |
| codex | 835 MB |
| 5× claude.exe (agents) | ~1.9 GB combined |
| JumpConnect | 486 MB |
| Orca + helpers | ~890 MB |
| ArqAgent, WindowServer, Spotlight, … | more |

Everything jetsam killed is a *host* process. The runner VM is absent from the
list: its 8 GB is wired VM backing that jetsam cannot reclaim, so under pressure
macOS ate the workstation instead and the machine locked up.

## Diagnosis

The host cannot hold both loads at once:

- **Host**: M4 mini, **16 GB** RAM, 10 cores.
- **Runner VM**: 4 vCPU / **8 GB**, fixed and host-backed (`tart get tartelet-runner`).
- Under an Xcode/Go build the guest actively touches most of its 8 GB, so the host
  must back ~8 GB. That leaves ~8 GB for macOS plus Orca, several Claude agents,
  Codex, and OrbStack — which is more than 8 GB. The compressor maxes out, jetsam
  fires, and the machine wedges.

Two structural facts make this unavoidable without a guard:

1. macOS has no cgroups; nothing bounds the *sum* of host + guest memory.
2. The two-VM framework cap and `runner_vm_count = 1` do not help — a single 8 GB
   VM was enough to tip a 16 GB host that was also doing real work.

The one lever macOS does give us: it raises `kern.memorystatus_vm_pressure_level`
to warn (2) and then critical (4) **before** jetsam kills anything. A watchdog can
act in that window.

## Proposed protection: a memory-pressure circuit breaker

A small always-on watchdog watches host memory and yields the runner under
pressure, trading the in-flight CI job to keep the host alive. Because runners are
ephemeral, the next job re-clones a fresh VM.

- **Sense**: poll `kern.memorystatus_vm_pressure_level` and `vm.swapusage` every
  10 s (both readable without sudo).
- **Trip**: on sustained warn (default 3 polls, ~30 s) or an immediate critical,
  `launchctl bootout` the `com.prateek.tartelet-runner` agent and `pkill` the
  `tart run` guest so its RAM is released at once.
- **Re-arm**: `launchctl bootstrap` the runner agent again only after the host has
  been healthy for a sustained window (default ~3 min) and a minimum downtime has
  elapsed (default 5 min), so the runner does not flap up and down under load.

The load-bearing design point: the runner LaunchAgent has `KeepAlive=true`, so
quitting Tartelet just relaunches it. The breaker has to bootout/bootstrap the
*agent*, not the app, to actually hold the runner down. Trip state persists across
guard restarts and reconciles against a reboot that re-armed the runner at login.

## Design: files and layout

The prototype implemented exactly this layout; it is the spec to rebuild. Everything
is gated on the `tartelet` cask, so it stays inert on every machine except a homelab
runner host, and inert there until `chezmoi apply` loads the agent.

| File | Role |
| --- | --- |
| `home/dot_local/bin/executable_tartelet-mem-guard` | The watchdog daemon. `next_action` is the pure trip/recover decision; `swap_used_mb` parses `vm.swapusage`. |
| `home/Library/LaunchAgents/com.prateek.tartelet-mem-guard.plist.tmpl` | Always-on agent that runs the guard; logs to `~/Library/Logs/tartelet-mem-guard.log`. |
| `home/.chezmoiscripts/run_onchange_after_19-tartelet-mem-guard.sh.tmpl` | Loads/reloads the guard agent on apply. |
| `home/.chezmoiscripts/run_onchange_after_90-verify.sh.tmpl` (edit) | Verify asserts the guard files exist and the agent is loaded. |
| `home/.chezmoiignore` (edit) | Gates the guard script + plist on the tartelet cask, alongside the runner agent. |
| `tests/tartelet-mem-guard.zsh`, `Makefile`, `.github/workflows/install-smoke.yml` (edits) | Unit test for the decision logic + swap parser; wired into `make` and CI. |

Tunables (all `TARTELET_MEM_GUARD_*` env-overridable; defaults live in the guard
script):

| Constant | Default | Meaning |
| --- | --- | --- |
| `TRIP_STREAK` | 3 | consecutive warn polls (~30 s) before tripping; critical trips at once |
| `RECOVER_STREAK` | 18 | consecutive healthy polls (~3 min) before re-arming |
| `MIN_DOWN_SEC` | 300 | minimum downtime after a trip before re-arming (anti-flap) |
| `SWAP_TRIP_MB` | 3072 | swap used (MB) that counts as danger on its own |
| `SWAP_CLEAR_MB` | 512 | swap used (MB) below which a poll counts as healthy |

## Feasibility (prototype built and verified 2026-07-04, then dropped)

A prototype of the design above was built and passed these checks, then removed so
this branch stays docs-only. A rebuild should reproduce them:

- `make test-tartelet-mem-guard` passed: the trip/recover decision table and the
  swap parser were covered, plus render + cask-gating for the plist and load script.
- Guard script was shellcheck-clean.
- Live read-only sensing on the m4mini read correctly (pressure level, swap, and a
  synthetic 8 GB swap string parsing to 8192 MB).
- `chezmoi apply --dry-run` confirmed the guard files would materialize on the mini
  (script mode 755).
- Adjacent tests (`test-tartelet-settings`, `test-tartelet-softnet-wrapper`,
  `test-package-gated-configs`) and docs-lifecycle passed.

Never done, even on the prototype: a live trip under real memory pressure. The
breaker has never actually fired against a runaway build.

## To land this

1. Build the guard per the design above (`next_action` is the core decision; mind
   the KeepAlive/bootout interaction), gated on the tartelet cask, with the unit
   test and CI wiring.
2. `chezmoi apply` on the mini — writes the files and `run_onchange_after_19`
   bootstraps the guard agent. Confirm with
   `launchctl print gui/$(id -u)/com.prateek.tartelet-mem-guard`.
3. Prove a trip: run (or simulate) a heavy build, watch
   `~/Library/Logs/tartelet-mem-guard.log` for a `TRIP`, and confirm the host stays
   responsive and the runner re-registers on `RECOVER`. Tune thresholds if it trips
   too eagerly or too late.
4. Fold the memory-guard content back into the runner plan (phase) and runbook
   (operator section) as *landed*, and update `docs/index.md`.

## Open decisions

- **Trip aggressiveness.** Default trips on 3 sustained warn polls or instant
  critical. This favors host stability over CI throughput: a false trip kills a job
  and re-arms ~5 min later. If builds should ride closer to the edge, raise
  `TRIP_STREAK` or gate on critical only.
- **Hardware is the real fix.** The guard makes overload graceful, not impossible.
  16 GB co-hosting an 8 GB VM and an active agent stack is fundamentally tight. A
  dedicated mini or a higher-RAM host is the durable answer; the guard is a safety
  net for as long as this mini does double duty.

## Picking it back up (quick reference)

- This doc lives on `prateek/prevent-overload`; the prototype code is not in-tree.
- Core logic to build: the `next_action` trip/recover decision (streak accounting)
  and a `vm.swapusage` parser, both as a pure seam so a unit test can drive them.
- Test to write: the decision table plus the swap parser (`make test-tartelet-mem-guard`).
- Activate once built: `chezmoi apply` on the mini, or the scoped two-path apply plus
  `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.prateek.tartelet-mem-guard.plist`.
