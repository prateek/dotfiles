"""Bounded transports and private atomic checkpoints."""

import contextlib
import fcntl
from http.client import HTTPException
import json
import os
import signal
from pathlib import Path
import subprocess
import tempfile
import urllib.error
import urllib.request

from .contracts import Invalid

MAX_BYTES = 8 * 1024 * 1024


class Failure(Exception):
    def __init__(self, status, detail=""):
        self.status, self.detail = status, detail
        super().__init__(detail or status)


def classify(text, code=1):
    t = text.lower()
    if code == 127:
        return "unavailable"
    if code == 429 or "rate limit" in t or "too many requests" in t:
        return "rate_limited"
    if any(
        x in t
        for x in (
            "captcha",
            "verify you are human",
            "automated queries",
            "unusual traffic",
            "verifying your request",
        )
    ):
        return "challenge"
    if code == 401 or any(
        x in t
        for x in (
            "bad credentials",
            "requires authentication",
            "authentication failed",
            "sign in to search",
        )
    ):
        return "auth_failed"
    if code == 403:
        return "auth_failed"
    if code >= 500:
        return "transient"
    return "failed"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise Failure(
            "schema_error", "Unexpected redirect; credentials were not forwarded"
        )


def http(url, timeout, headers=None, body=None):
    from .diagnostics import transport

    with transport("http", {"url": url, "body": body}):
        return _http(url, timeout, headers, body)


def _http(url, timeout, headers=None, body=None):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "agent-search/1", **(headers or {})},
        data=None if body is None else json.dumps(body).encode(),
    )
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.build_opener(NoRedirect()).open(
            req, timeout=timeout
        ) as res:
            raw = res.read(MAX_BYTES + 1)
    except urllib.error.HTTPError as exc:
        with exc:
            status = classify(exc.read(8192).decode(errors="replace"), exc.code)
        raise Failure(status, f"HTTP {exc.code}") from None
    except (TimeoutError, subprocess.TimeoutExpired):
        raise Failure("timeout", "Transport deadline exceeded") from None
    except urllib.error.URLError as exc:
        status = "timeout" if isinstance(exc.reason, TimeoutError) else "transient"
        raise Failure(status, "Connection failed") from None
    except (OSError, HTTPException):
        raise Failure("transient", "Incomplete or interrupted HTTP response") from None
    if len(raw) > MAX_BYTES:
        raise Failure("schema_error", "Response exceeds byte limit")
    try:
        return json.loads(raw)
    except (ValueError, UnicodeError):
        status = classify(raw[:8192].decode(errors="replace"))
        raise Failure(
            status if status != "failed" else "schema_error", "Expected JSON response"
        ) from None


def command(argv, timeout):
    from .diagnostics import transport

    with transport("command", {"argv": argv}):
        return _command(argv, timeout)


def _command(argv, timeout):
    # Files bound memory, including noisy third-party CLIs. Child output never becomes a command.
    env = {**os.environ, "DO_NOT_TRACK": "1", "DISABLE_TELEMETRY": "1"}
    try:
        with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
            p = subprocess.Popen(
                argv, stdout=out, stderr=err, env=env, start_new_session=True
            )
            try:
                p.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait()
                raise Failure("timeout", "Command deadline exceeded") from None
            out.seek(0)
            err.seek(0)
            stdout, stderr = out.read(MAX_BYTES + 1), err.read(MAX_BYTES + 1)
        if max(len(stdout), len(stderr)) > MAX_BYTES:
            raise Failure("schema_error", "Command output exceeds byte limit")
        return {
            "rc": p.returncode,
            "stdout": stdout.decode(errors="replace"),
            "stderr": stderr.decode(errors="replace"),
        }
    except FileNotFoundError:
        raise Failure("unavailable", f"{argv[0]} is not installed") from None
    except OSError:
        raise Failure("failed", "Command could not complete") from None


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Invalid(f"Duplicate JSON field: {key}")
        result[key] = value
    return result


def read(path):
    try:
        if Path(path).stat().st_size > MAX_BYTES:
            raise Invalid("Document exceeds byte limit")
        return json.loads(Path(path).read_text(), object_pairs_hook=unique_pairs)
    except (OSError, ValueError) as exc:
        raise Invalid(f"Cannot read JSON document: {path}") from exc


def private_parent(path):
    parent = Path(path).absolute().parent
    missing = []
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    for directory in reversed(missing):
        directory.mkdir(mode=0o700, exist_ok=True)


def atomic(path, value):
    path = Path(path)
    private_parent(path)
    encoded = json.dumps(value, indent=2, allow_nan=False) + "\n"
    if len(encoded.encode()) > MAX_BYTES:
        raise Invalid(
            "Checkpoint exceeds byte limit; prior checkpoint remains recoverable"
        )
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(encoded)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


@contextlib.contextmanager
def lock(path):
    path = Path(path)
    private_parent(path)
    fd = os.open(str(path) + ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    except BlockingIOError:
        raise Invalid("State is locked by another writer") from None
    finally:
        os.close(fd)
