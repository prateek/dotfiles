---
name: ios-sim-lease
description: Coordinate iOS simulator leases across multiple coding agents working concurrently on the same machine. Provides a shared pool of named simulator clones and a lease file so that parallel Claude Code / Codex / other agent sessions in different repos or worktrees never boot, install into, or launch the same simulator. Use when the user asks to "acquire a simulator", "set up a simulator pool", "release a simulator", "handle concurrent simulator use", or asks why parallel iOS build loops are stepping on each other. STATUS design is stable but the bash helper and pool bootstrap are NOT YET BUILT. See TODO.md.
---

# iOS Simulator Lease

> **Status: design only.** The `ios-sim-lease` bash helper described below is not yet implemented. See [TODO.md](./TODO.md) for what exists, what's missing, and the implementation plan. In the meantime, projects following `~/.agents/docs/ios.md` use an interim sentinel-file flow (`.ios-sim-udid` at the project root) that the full helper will replace without breaking Makefile targets.

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

## Interim flow (until the helper ships)

Projects following `~/.agents/docs/ios.md` use a sentinel file at `.ios-sim-udid` in the project root. The Makefile reads from it:

```make
LEASE_FILE  := .ios-sim-udid
IOS_SIM_UDID = $(shell test -f $(LEASE_FILE) && cat $(LEASE_FILE))
```

Workflow: manually boot a named device once, write its UDID to `.ios-sim-udid`, run `make`. When `ios-sim-lease` lands, the Makefile `boot-lease` target switches to calling the helper and the sentinel file becomes an implementation detail.

## See also

- `~/.agents/docs/ios.md` — iOS conventions playbook; points at this skill for §Simulator leasing.
- `~/.agents/skills/ios-project-scaffold/` — the scaffold skill generates the Makefile that consumes leases.
- [TODO.md](./TODO.md) — what's built, what isn't, and the implementation plan.
