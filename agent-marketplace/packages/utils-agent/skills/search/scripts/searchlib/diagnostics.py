"""Private run storage and redacted transport events; no response bodies in events."""

from contextlib import contextmanager
from contextvars import ContextVar
import datetime as dt
import json
import fcntl
import os
from pathlib import Path
import re
import time
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

from . import io, registry

TRANSPORT = ContextVar("search_transport", default=None)
SECRET_KEY = re.compile(
    r"(?i)(authorization|cookie|password|secret|token|api[_-]?key|credential)"
)


def redact(value):
    secrets = [
        os.environ.get(p.get("credential") or "", "")
        for p in registry.REGISTRY.values()
    ]
    secrets += [
        v for k, v in os.environ.items() if SECRET_KEY.search(k) and len(v) >= 8
    ]

    def clean(item, parent=None):
        if isinstance(item, dict):
            return {
                k: "[redacted]"
                if parent != "constraints" and SECRET_KEY.search(k)
                else clean(v, k)
                for k, v in item.items()
            }
        if isinstance(item, list):
            return [clean(v) for v in item]
        if isinstance(item, str):
            for secret in secrets:
                if secret:
                    item = item.replace(secret, "[redacted]")
            if item.startswith(("http://", "https://")):
                parts = urlsplit(item)
                pairs = parse_qsl(parts.query, keep_blank_values=True)
                if parts.username or any(SECRET_KEY.search(k) for k, _ in pairs):
                    query = urlencode(
                        [
                            (k, "[redacted]" if SECRET_KEY.search(k) else v)
                            for k, v in pairs
                        ]
                    )
                    item = urlunsplit(
                        (
                            parts.scheme,
                            parts.netloc.rsplit("@", 1)[-1],
                            parts.path,
                            query,
                            parts.fragment,
                        )
                    )
            return item
        return item

    return clean(value)


def default_path(run_id):
    base = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    if not base.is_absolute():
        raise io.Invalid("XDG_STATE_HOME must be absolute")
    date = dt.datetime.now(dt.timezone.utc).date().isoformat()
    return base / "agent-search/runs" / date / run_id / "state.json"


def trace_info(path):
    path = Path(path).absolute()
    return {
        "schema_version": 1,
        "state": str(path),
        "events": str(path) + ".events.jsonl",
    }


def append(path, event):
    io.private_parent(path)
    payload = (json.dumps(redact(event), allow_nan=False) + "\n").encode()
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        os.fchmod(fd, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        with os.fdopen(fd, "ab", closefd=False) as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(fd)
    finally:
        os.close(fd)


@contextmanager
def attempt(trace, work):
    token = TRANSPORT.set((trace, work))
    try:
        yield
    finally:
        TRANSPORT.reset(token)


@contextmanager
def transport(kind, request):
    context = TRANSPORT.get()
    if not context or not context[0]:
        yield
        return
    trace, work = context
    base = {
        "schema_version": 1,
        "run_id": work["run_id"],
        "attempt_id": work["attempt_id"],
        "facet_id": work["facet_id"],
        "provider": work["provider"],
        "transport": kind,
        "request": request,
        "started_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    }
    try:
        append(trace["events"], {**base, "phase": "started"})
    except OSError as exc:
        raise OSError(
            f"Trace journal failed; reconcile pending work in {trace['state']}: {exc}"
        ) from exc
    start = time.monotonic()
    status = "returned"
    try:
        yield
    except io.Failure as exc:
        status = exc.status
        raise
    except BaseException:
        status = "interrupted_or_failed"
        raise
    finally:
        append(
            trace["events"],
            {
                **base,
                "phase": "finished",
                "status": status,
                "elapsed_seconds": time.monotonic() - start,
            },
        )
