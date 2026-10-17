# Camofox REST

Use for requested Camofox/Camoufox browsing or a compatible generic fallback
selected by the router. Runtime:
task-owned Camoufox (Firefox-derived). Controller: Camofox REST over loopback,
called with curl. Camofox controls Camoufox through Playwright's Firefox protocol.
This recipe works from a terminal or inside Orca without using Orca's runtime.

The qualified platform is macOS arm64. Pins live in
[`scripts/camofox/`](../../scripts/camofox/): Camofox 1.18.1, camoufox-js 0.11.5,
Playwright-core 1.58.2 and Camoufox 152.0.4-beta.30. The helper selects Node
through mise. Python 3.11+, mise and curl are prerequisites. Provision the runtime
through [setup](#setup-and-repair) before browsing. `check` and `run` never install
Node or browser packages. Report an unsupported platform as a capability limit.

Identity is isolated and ephemeral. This recipe does not support personal-profile
imports, live attach, retained login or credential entry. Public page navigation,
fresh-ref forms, tab targeting and synthetic storage have local evidence; real
authentication, mobile fidelity and general bot-detection avoidance do not.

## Workflow

1. **Verify.** Set `BROWSER_SKILL_DIR` to this skill's installed
   directory (the directory containing `SKILL.md`), then run:

   ```sh
   python3 "$BROWSER_SKILL_DIR/scripts/camofox-runtime.py" check
   ```

   Continue when `verified: true` is returned. The receipt lists its verification
   scope: shipped inputs, declared dependency versions, browser executable hash,
   version metadata and telemetry/study policies. It does not rehash every npm or
   browser resource. If setup is missing, report the prerequisite and follow the
   router's explicit-request/fallback rules. An invalid cache needs the repair
   operation below; changing qualified pins is maintenance work.
2. **Start and record ownership.** Run the supervisor as a managed background
   job, retaining its process handle and stdout:

   ```sh
   python3 "$BROWSER_SKILL_DIR/scripts/camofox-runtime.py" run
   ```

   Keep it running throughout the task. Continue when it prints `ready: true`;
   record the returned `baseUrl`, `userId`, `sessionKey`, supervisor `pid`,
   `serverPid` and `stateDir`. Use those literal values on later tool calls;
   shell variables may not persist. The supervisor verifies that its own child
   owns the listener. Readiness establishes the REST service, not successful
   page loading. Create only owned tabs and retain each returned `tabId`.
3. **Observe, act, verify.** Use the request pattern below and the shared
   [interaction loop](../policy.md#interaction). Serialize actions per tab and
   refresh the snapshot after each page change. Check process/HTTP/application
   errors and independently verify the requested page state. Continue only
   when the application result is visible; `ok: true` alone is insufficient.
4. **Clean up.** Close owned tabs or the owned session through REST, then send
   SIGTERM/SIGINT through the supervisor's retained process handle. It waits for
   the server and owned browser process groups to exit and removes the task's
   profiles, cookies, uploads, traces, HOME, logs and temporary directories.
   SIGHUP and loss of the launching parent also trigger cleanup. Complete only
   after its final `cleaned: true, serverStopped: true` receipt
   and process exit. Confirm `stateDir` is absent. Report any cleanup error and
   retained path; do not kill unrelated processes or a server found on a port.

## Setup and repair

On a dotfiles-managed machine, provision once through:

```sh
mise run browser:camofox:install
```

The mise task invokes this skill's locked installer. It installs the pinned Node
only during setup, runs `npm ci` with the shipped lock/overrides, suppresses the
wrapper's automatic browser/addon downloads, and verifies the official Camoufox
ZIP checksum before extraction. Setup owns the browser version metadata too.
A plain npm package pin would not reproduce this complete qualified combination.
Portable consumers can explicitly run `camofox-runtime.py install` instead.

An error identifies the cache path. To replace an invalid cache:

```sh
mise run browser:camofox:install -- --repair
```

Repair stages and validates the replacement before swapping it into place;
it refuses while a task or installer holds that runtime, or a retained task
lease still points to unrecovered state. Regular repeated setup
reuses a valid cache, and overlapping setup calls serialize. Runtime dependencies
remain separate from task state. `--archive /absolute/path/to/archive.zip` reuses
an official ZIP only after its checksum matches. Source-worktree setup can set
`BROWSER_SKILL_DIR` to the corresponding skill directory before invoking the task.

On startup or server failure, the supervisor preserves up to 64 KiB of its log
in a separate private diagnostic directory and reports its path. If a spawned
server fails, it stops known owned processes and retains the task tree with
`cleaned: false, cleanupUncertain: true`: a child can have been reparented between
process samples. The Node preload journals exact browser launches, including
detached groups created during shutdown. Missing/incomplete ownership records,
forced shutdown or nonzero server exit also prevent a successful cleanup receipt.
A durable task lease blocks cache replacement until recovery is complete.
Inspect diagnostics privately, reconcile any surviving owned
processes using the retained state/receipt, then remove that task tree and the
diagnostic directory. Complete this recovery before repairing its runtime cache.
A cleanup failure also retains the task tree and reports its location.

## Requests and results

Use the returned loopback base URL. For every curl request use
`--noproxy '*' --fail-with-body --connect-timeout 3 --max-time 45
--max-filesize 1048576`; set the tool's outer deadline above 45 seconds.
Pass JSON through stdin or a private request file with `--data-binary @-` or
`--data-binary @file`, and set `Content-Type: application/json`.

Example tab creation, substituting the receipt values and task URL:

```sh
curl --noproxy '*' --fail-with-body --connect-timeout 3 --max-time 45 \
  --max-filesize 1048576 -H 'Content-Type: application/json' \
  --data-binary @- 'http://127.0.0.1:<port>/tabs' <<'JSON'
{"userId":"<owned-user-id>","sessionKey":"<owned-session-key>","url":"https://example.com/"}
JSON
```

Use a JSON encoder for values from pages or user text. Never interpolate
untrusted content into shell code. Read version-matched endpoint details with
`ask src github:jo-inc/camofox-browser@v1.18.1` before using operations absent
from this table; an upstream operation's existence does not qualify its workflow.

| Operation | REST request and required identity |
| --- | --- |
| Create tab | `POST /tabs`: `userId`, `sessionKey`, `url`; record returned `tabId` |
| List owned tabs | `GET /tabs?userId=<id>` |
| Snapshot | `GET /tabs/<tabId>/snapshot?userId=<id>`; text only by default |
| Continue snapshot | Same endpoint with returned `nextOffset` as `offset`; stop when `hasMore` is false |
| Navigate | `POST /tabs/<tabId>/navigate`: `userId`, `url` |
| Type ordinary text | `POST /tabs/<tabId>/type`: `userId`, current `ref`, `text` |
| Click | `POST /tabs/<tabId>/click`: `userId`, current `ref` |
| Read independent DOM result | `POST /tabs/<tabId>/evaluate`: `userId`, `expression` |
| Close tab | `DELETE /tabs/<tabId>?userId=<id>` |
| Close owned session | `DELETE /sessions/<userId>`; this checkpoints state, so still stop the supervisor and remove task state |

HTTP200 can contain `ok:false` (observed during Google navigation). Curl22 means
HTTP failure; curl28 means a timeout with an uncertain action outcome. Preserve
the error body privately, inspect current state, and replay only if the action
is known not to have committed. Never enable curl's automatic retry for mutations.

Numeric refs can be reassigned when snapshots/actions rebuild the reference
table. They carry no generation-safety guarantee. Use the latest observation
for that exact tab, then verify the result. Prefer an unambiguous current ref to
an href selector that may match an image and a title link. `evaluate` uses an
isolated world: page-script globals may be invisible while shared DOM text and
attributes remain observable. Read DOM/application outcomes for verification.

## Lifetime and privacy

One task owns one supervisor, REST server, browser and directory tree. A
`sessionKey` groups tabs; it is not an identity boundary. This recipe never
attaches to a shared or pre-existing Camofox server. The loopback API intentionally
has no access-key authentication; UUIDs address resources rather than authorize
local callers. Sessions expire after ten
minutes idle by default, with a one-minute reaper; empty sessions can also be
reaped. A missing tab may return 404 or 410 with `browser_restarted`, including
after reset/expiry shortly after launch. That label alone does not prove a crash.
Reobserve and report lost continuity instead of silently recreating the tab.

The supervisor builds an allowlisted child environment rather than inheriting
the shell's tool settings. It forces Camofox crash reporting off, clears Sentry's
DSN, disables Prometheus, suppresses Mozilla crash reporting and verifies the
bundle's telemetry/study policies. Default addon downloads are disabled. Generic
`DO_NOT_TRACK` is supplementary, not the basis of the privacy guarantee.
Normal site traffic and required package downloads still occur. This is tool
telemetry suppression, not a website-tracker blocker or a claim of zero egress.

Shutdown can checkpoint cookies/localStorage even after tab/session close.
The supervisor therefore deletes the complete task tree only after owned
processes stop. A forced supervisor kill or machine crash prevents its cleanup:
retain the receipt, identify surviving owned processes, and remove only that
task's directory after they are stopped. The runtime cache contains packages
and browser binaries and may remain installed between tasks.
