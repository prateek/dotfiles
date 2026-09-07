---
name: ios-sim-lease
description: Review or implement the planned cross-project iOS simulator lease design. Use when the user asks to build the lease helper or pool, or diagnose simulator collisions across concurrent agents. The helper and pool are not built; current scaffolded projects isolate simulator state through their repository-owned worktree helpers.
---

# iOS Simulator Lease

> **Status: design only.** The `ios-sim-lease` bash helper described below is
> not implemented. See [TODO.md](./TODO.md) for the implementation plan.
> Scaffolded projects currently isolate simulator state through their
> repository-owned worktree helpers.

## Problem

Multiple coding agents (Claude Code, Codex, potentially others) run against the same machine at the same time, often in different repos or git worktrees. Every one of them wants to boot a simulator, install an app, launch it, and run tests. Without coordination, the first agent's "booted" device becomes the second agent's "oh that's already running, I'll just use it", and the second agent installs a different app binary over the first's running session. State corruption follows. The `xcrun simctl` CLI has no built-in mutual exclusion for this.

## Design

Pre-create a pool of named simulator clones. Agents lease one clone at the start of an iOS session and release it at the end. A shared JSON file tracks which clone is leased to whom; `flock` keeps writes atomic across agents.

### Pool

Create two clones per device kind so at most two phones and two tablets run concurrently. Scale up by adding more clones if contention appears.

```bash
xcrun simctl create "Agents-iPhone-17-Pro-A" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
xcrun simctl create "Agents-iPhone-17-Pro-B" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
xcrun simctl create "Agents-iPad-Pro-13-A" \
  "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
xcrun simctl create "Agents-iPad-Pro-13-B" \
  "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB" \
  "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
```

Everything named `Agents-*` belongs to the pool. Devices with other names belong to humans and must be left alone.

### Lease file

```
~/.agents/state/ios-sim-leases.json
~/.agents/state/ios-sim-leases.lock    (flock mutex; not checked in)
```

```json
{
  "leases": [
    {
      "udid": "ABCD-1234-...",
      "name": "Agents-iPhone-17-Pro-A",
      "kind": "phone",
      "owner": {
        "agent": "codex",
        "pid": 12345,
        "cwd": "/Users/prateek/code/experiments/ios-silly-tavern",
        "worktree": "ios-silly-tavern-app",
        "started_at": "2026-04-10T14:05:00Z"
      },
      "last_heartbeat": "2026-04-10T14:12:30Z",
      "ttl_minutes": 60
    }
  ]
}
```

### Helper: `ios-sim-lease`

A single bash script at `~/.agents/bin/ios-sim-lease` exposes five subcommands. Agents call it; nobody edits the JSON by hand.

```
ios-sim-lease acquire --kind <phone|tablet> [--agent NAME] [--ttl MINUTES]
  # Picks a free Agents-* device of the requested kind, boots it, prints the UDID.
  # Writes a lease entry with owner pid/cwd/worktree.
  # Exit 0 on success, 75 (EX_TEMPFAIL) if pool is exhausted.

ios-sim-lease release <udid>
  # Erases the device (xcrun simctl erase), shuts it down, removes the lease.

ios-sim-lease heartbeat <udid>
  # Updates last_heartbeat on the existing lease. Safe to call once per minute
  # from a background process or shell trap.

ios-sim-lease list
  # Prints all current leases with owner, age, and whether they look stale.

ios-sim-lease reap
  # Walks every lease; removes any whose owner.pid is gone (kill -0) or whose
  # last_heartbeat is older than ttl_minutes. Erases each reaped device.
  # Safe to run from a cron or at shell startup.
```

### Agent workflow

Every agent iOS session wraps its work with three calls:

```bash
UDID=$(ios-sim-lease acquire --kind phone --agent codex --ttl 60)
export IOS_SIM_UDID="$UDID"

# ... make build / make run / make test / make audit ...

ios-sim-lease release "$UDID"
```

A shell trap (`trap 'ios-sim-lease release "$IOS_SIM_UDID"' EXIT`) handles abnormal exits.

Makefile targets `boot-lease` and `release-lease` wrap the helper so agents only call `make boot-lease && make run && make release-lease`.

## Design decisions (locked in)

- **TTL default: 60 min.** Reaped leases shrink false-busy claims without killing active long-running work.
- **Erase on release** (`xcrun simctl erase`). Clean slate between sessions; trades ~2–5s startup cost for reliable reset.
- **Name prefix: `Agents-`.** Hyphens, not slashes; slashes in simulator names confuse some tools.
- **State dir: `~/.agents/state/`.** Lives under `.agents/` so it travels with dotfiles state.
- **Pool size: 2 phones + 2 tablets.** Enough for current real concurrency; grow when contention appears.
- **Lock: `flock` against `ios-sim-leases.lock`.** Portable and atomic.

## Current behavior

The repository-owned helper generated by `ios-project-scaffold` owns simulator
identities, locks, and mutable state under `build/`. It isolates worktrees
inside one project but does not coordinate simulators across unrelated
projects. Until the lease helper ships, report cross-project contention and
assign separate devices through each repository's helper. Do not introduce
`.ios-sim-udid`; the scaffold audit rejects that retired path.

## See also

- `~/.agents/docs/ios.md` — iOS conventions playbook; points at this skill for §Simulator leasing.
- `ios-project-scaffold` — generates the repository-owned worktree helper that
  a future global lease service must integrate with.
- [TODO.md](./TODO.md) — what's built, what isn't, and the implementation plan.
