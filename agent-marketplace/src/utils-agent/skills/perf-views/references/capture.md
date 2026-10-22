# Capturing spans

Each pattern produces spans for `scripts/perf-view`. Use `time.perf_counter()`
(or the language's monotonic clock) and subtract one origin taken at the start.

## Wrapper tracing inside the process

Load the program as a module and wrap the functions that cross a boundary
(RPC, CLI, database, file scan). The wrapper records `(name, start, end)` and
calls through:

```python
def span(label, fn):
    def wrapped(*args, **kwargs):
        name = label(*args, **kwargs) if callable(label) else label
        start = time.perf_counter()
        try:
            return fn(*args, **kwargs)
        finally:
            spans.append({"name": name, "start": (start - T0) * 1000,
                          "end": (time.perf_counter() - T0) * 1000})
    return wrapped

app.rpc = span(lambda method, *_, **__: f"rpc {method}", app.rpc)
```

For an `async def`, make `wrapped` async and `return await fn(...)`; the sync
wrapper times only the creation of the coroutine.

Name spans by what crossed the boundary (`rpc worktree.ps`, `cli orca terminal
split`), so a reader can match them to code. Run the program's entrypoint in a
read-only mode (`--dry-run`, a list or show subcommand), confirmed read-only in
its help or source, and suppress its side effects.

## A relay at a process boundary

When the code under test runs as its own process, put a relay between it and
the service it calls. The relay timestamps each request and can pause one to
create a deterministic window. On Linux, `SO_PEERCRED` gives the caller's PID,
which shows whether work happened in the process itself or in a child it
launched:

```python
pid = struct.unpack("3i", client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[0]
```

The relay's time is when it received the request, not when the service acted.
Use it for ordering and attribution; judge outcomes from the result itself.
Shut sockets down with `shutdown(SHUT_RDWR)`: `close()` from one thread sends
no FIN while another thread is blocked in `recv()`, and the client hangs.

## Repeated runs for launcher cost

Startup is its own span. Time the cheapest invocation that still loads what a
real run loads (configuration, plugins, imports). `--help` often exits before
that work, so check with the tool's verbose output or a trace that it reaches
the same point:

```sh
hyperfine -N --warmup 3 --runs 20 --export-json launch.json './tool status'
```

`-N` skips the intermediate shell. Take the cold figure before any warm run,
from a cold cache (first run after a reboot, or a fresh cache directory such
as `UV_CACHE_DIR=$(mktemp -d)`): `hyperfine -N --runs 1 './tool status'`.
Without hyperfine, launch the process six times from a parent with a monotonic
clock, starting from a cold cache, and report the first and the median of the
rest.

## Comparing builds

Check the baseline out whole (`git worktree add /tmp/base origin/main`), so
every module it imports comes from the baseline, then run the same tracer
against both and render both views on one unit. Read the
outputs as well as the timings: a baseline run can expose a correctness bug the
timings alone would miss.
