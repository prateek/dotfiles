# ios-sim-lease — implementation TODO

## Current state (2026-04-10)

- [x] Design documented in `SKILL.md`.
- [x] `~/.agents/state/` directory exists (empty).
- [x] `~/.agents/bin/` directory exists (empty).
- [x] Lease entry shape finalized (see `SKILL.md` → Lease file).
- [x] Subcommand surface finalized: `acquire`, `release`, `heartbeat`, `list`, `reap`.
- [x] `ios-project-scaffold` generates a repository-owned worktree helper that
  owns simulator identities, locks, and mutable state under `build/`.
- [ ] Bash helper script (`~/.agents/bin/ios-sim-lease`) — **NOT BUILT**.
- [ ] Pool creation (4 `xcrun simctl create` calls for phone A/B + tablet A/B) — **NOT RUN** on this machine.
- [ ] Lease file (`~/.agents/state/ios-sim-leases.json`) — does not exist yet.
- [ ] Cron / shell-startup `reap` hook — not wired.
- [ ] First end-to-end smoke test against a real project.

## Why deferred

Current iOS work is low-concurrency across projects, so the helper remains
forward-looking infrastructure. Inside a project, the generated worktree
helper already isolates simulator state. Build the global lease layer when
contention appears between unrelated projects.

## Current flow

Use each project's `make` targets, which delegate simulator ownership to its
repository worktree helper. For concurrent work across projects, configure
separate devices through those helpers and report contention. Do not recreate
the retired `.ios-sim-udid` sentinel.

## When to build the helper

Pull this TODO forward when any of:

- Two agents interfere with each other's iOS work in a session (real contention).
- The user explicitly asks for the simulator pool or `ios-sim-lease`.
- A new project enters parallel UI-testing rollout and needs guaranteed isolation per lane.

## Implementation plan (for future me)

Scope: ~150 lines of bash + `jq` + `flock`. Half a day of work.

### Files to create

1. `~/.agents/bin/ios-sim-lease` — the helper. Single bash file, no dependencies beyond `jq`, `flock`, and `xcrun simctl`.
2. `~/.agents/state/ios-sim-leases.json` — initial empty `{"leases": []}`.
3. `~/.agents/state/ios-sim-leases.lock` — empty sentinel for `flock`.

### Pool bootstrap (one-shot script)

Add a subcommand `ios-sim-lease bootstrap-pool` that reads `~/.agents/state/ios-triple.json` and runs the four `xcrun simctl create` calls from `SKILL.md` → Pool, skipping any that already exist. Idempotent.

### Subcommand semantics

- `acquire --kind <phone|tablet> [--agent NAME] [--ttl MINUTES]`
  1. `flock` the lock file.
  2. Read leases JSON.
  3. List `Agents-*` devices of the requested kind via `xcrun simctl list devices -j`.
  4. Pick the first not in the leases array.
  5. Write a new lease entry with pid, cwd (`$PWD`), worktree (basename), started_at, last_heartbeat, ttl.
  6. `xcrun simctl boot <udid>`, `xcrun simctl bootstatus <udid> -b`.
  7. `echo <udid>` to stdout.
  8. Release `flock`.
  9. Exit 0. If pool exhausted, exit 75 (`EX_TEMPFAIL`).

- `release <udid>`
  1. `flock` lock.
  2. Remove the lease entry.
  3. `xcrun simctl shutdown <udid>` → `xcrun simctl erase <udid>`.
  4. Release lock.

- `heartbeat <udid>`
  1. `flock` lock.
  2. Update `last_heartbeat` to now (`date -u +%FT%TZ`).
  3. Release lock.

- `list`
  1. `flock` lock (shared).
  2. Pretty-print leases with age and pid-liveness per entry.

- `reap`
  1. `flock` lock (exclusive).
  2. For each lease: if `kill -0 $pid` fails or `last_heartbeat + ttl < now`, treat as stale; shut down + erase the device and drop the entry.
  3. Release lock.

### Shell trap pattern to document in README

```bash
UDID=$(ios-sim-lease acquire --kind phone --agent codex --ttl 60)
export IOS_SIM_UDID="$UDID"
trap 'ios-sim-lease release "$IOS_SIM_UDID"' EXIT
# ... do work ...
```

### Tests to run before declaring done

1. `acquire` twice in parallel from two shells → both get different UDIDs.
2. `acquire` when pool is full → exit 75.
3. `release` after `acquire` → lease gone, device shut down, erased.
4. `reap` after killing the acquiring shell with `kill -9` → lease cleaned up, device erased.
5. Makefile `boot-lease` target swapped to call `ios-sim-lease acquire` → `make build` works unchanged.
6. Two real projects running `make test` in parallel worktrees → no state collision.

### Integration with repository worktree helpers

Once the global helper ships, update the `ios-project-scaffold` worktree-helper
template to acquire a global lease before creating or booting a simulator,
persist lease metadata under `build/state/`, and release it through the
helper's existing cleanup path. Re-run the scaffold audit against existing
projects before migration.

## Related

- `~/.agents/docs/ios.md` — points at this skill for the simulator-leasing section.
- `ios-project-scaffold` — owns the worktree-helper template this service must
  integrate with.
