#!/usr/bin/env python3
"""Install the qualified Camofox runtime and supervise one ephemeral REST server."""

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid


INPUTS = Path(__file__).resolve().parent / "camofox"
PIN = json.loads((INPUTS / "runtime.json").read_text())
PACKAGE = json.loads((INPUTS / "package.json").read_text())
SERVER = Path("node_modules/@askjo/camofox-browser/server.js")


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def runtime_path():
    identity = hashlib.sha256(b"".join(
        (INPUTS / name).read_bytes()
        for name in ("package.json", "package-lock.json", "runtime.json")
    )).hexdigest()[:20]
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return cache.expanduser().resolve() / "browser-skill" / "camofox" / identity


def child_environment(state, node):
    env = {
        "PATH": f"{node.parent}:/usr/bin:/bin:/usr/sbin:/sbin",
        "HOME": str(state / "home"),
        "TMPDIR": str(state / "tmp"),
        "LANG": "en_US.UTF-8",
        "CAMOFOX_CRASH_REPORT_ENABLED": "false",
        "SENTRY_DSN": "",
        "PROMETHEUS_ENABLED": "false",
        "MOZ_CRASHREPORTER_DISABLE": "1",
        "DO_NOT_TRACK": "1",
        "npm_config_audit": "false",
        "npm_config_fund": "false",
        "npm_config_update_notifier": "false",
        "CAMOFOX_SKIP_DOWNLOAD": "1",
        "CAMOFOX_DISABLE_DEFAULT_ADDONS": "true",
        "CAMOFOX_INTERACTIVE": "off",
        "CAMOFOX_BIND_HOST": "127.0.0.1",
    }
    for name in ("home", "tmp", "profiles", "cookies", "uploads", "traces"):
        (state / name).mkdir(mode=0o700, exist_ok=True)
    for name in ("profiles", "cookies", "uploads", "traces"):
        key = "PROFILE" if name == "profiles" else name.upper()
        env[f"CAMOFOX_{key}_DIR"] = str(state / name)
    return env


def node_executable(install_missing=False):
    env = {name: os.environ[name] for name in (
        "PATH", "HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME",
        "MISE_CONFIG_DIR", "MISE_DATA_DIR",
    ) if name in os.environ}
    env["DO_NOT_TRACK"] = "1"
    lookup = ["mise", "which", "node", "--tool", f"node@{PIN['node']}"]
    result = subprocess.run(lookup, cwd=Path.home(), env=env, capture_output=True, text=True, timeout=30)
    if result.returncode:
        if not install_missing:
            raise RuntimeError(f"Node {PIN['node']} is unavailable; run the explicit Camofox install task")
        subprocess.run(["mise", "install", f"node@{PIN['node']}"], env=env,
                       cwd=Path.home(), check=True, timeout=300, stdout=sys.stderr)
        result = subprocess.run(lookup, cwd=Path.home(), env=env, check=True, capture_output=True, text=True, timeout=30)
    node = Path(result.stdout.strip())
    actual = subprocess.check_output([str(node), "--version"], env=env, text=True, timeout=10).strip()
    if actual != "v" + PIN["node"]:
        raise RuntimeError(f"Expected Node {PIN['node']}, got {actual}")
    return node


def validate(runtime):
    try:
        validate_files(runtime)
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        raise RuntimeError(f"Runtime {runtime}: {error}. Repair with camofox-runtime.py install --repair") from error


def validate_files(runtime):
    if not runtime.is_dir():
        raise RuntimeError("Runtime is not installed; run camofox-runtime.py install first")
    for name in ("package.json", "package-lock.json", "runtime.json"):
        if (runtime / name).read_bytes() != (INPUTS / name).read_bytes():
            raise RuntimeError(f"Runtime input differs: {name}; install a clean runtime")
    for name, expected in (PACKAGE["dependencies"] | PACKAGE["overrides"]).items():
        actual = json.loads((runtime / "node_modules" / name / "package.json").read_text())["version"]
        if actual != expected:
            raise RuntimeError(f"Runtime dependency {name}: expected {expected}, got {actual}")
    if digest(runtime / PIN["executable"]) != PIN["executable_sha256"]:
        raise RuntimeError("Camoufox executable does not match the qualified artifact")
    version, _, release = PIN["browser_version"].partition("-")
    for parent in (runtime / "browser", runtime / PIN["resources"]):
        if json.loads((parent / "version.json").read_text()) != {"version": version, "release": release}:
            raise RuntimeError(f"Camoufox version metadata differs at {parent}")
    policies = json.loads((runtime / PIN["resources"] / "distribution/policies.json").read_text())["policies"]
    if policies.get("DisableTelemetry") is not True or policies.get("DisableFirefoxStudies") is not True:
        raise RuntimeError("Camoufox telemetry/study policies are not disabled")
    if not (runtime / SERVER).is_file():
        raise RuntimeError("Camofox server is missing")


@contextmanager
def runtime_lock(runtime, exclusive=False, wait=False):
    runtime.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = runtime.with_suffix(".lock")
    with path.open("a") as lock:
        mode = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
        try:
            fcntl.flock(lock, mode | (0 if wait else fcntl.LOCK_NB))
        except BlockingIOError:
            raise RuntimeError(f"Runtime {runtime} is in use or installation is running; retry when it is idle") from None
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def install(runtime, node, archive, repair=False):
    if runtime.exists() and not repair:
        with runtime_lock(runtime):
            validate(runtime)
        return
    with runtime_lock(runtime, exclusive=True, wait=not repair):
        install_locked(runtime, node, archive, repair)


def install_locked(runtime, node, archive, repair):
    if runtime.exists() and not repair:
        validate(runtime)
        return
    leases = runtime.with_suffix(".leases")
    if leases.exists():
        for lease in leases.iterdir():
            try:
                state = Path(json.loads(lease.read_text())["stateDir"])
                if not state.is_absolute():
                    raise ValueError("stateDir must be absolute")
            except (OSError, ValueError, KeyError, TypeError) as error:
                raise RuntimeError(f"Invalid recovery lease {lease}: {error}; reconcile it before repair") from error
            if state.exists():
                raise RuntimeError(f"Recover owned processes and task state at {state} before repairing {runtime}")
            lease.unlink()
    runtime.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.TemporaryDirectory(prefix=".install-", dir=runtime.parent) as staging:
        stage = Path(staging)
        app = stage / "app"
        app.mkdir()
        env = child_environment(stage, node)
        for name in ("package.json", "package-lock.json", "runtime.json"):
            shutil.copyfile(INPUTS / name, app / name)
        subprocess.run(
            [str(node.parent / "npm"), "ci", "--no-audit", "--no-fund"],
            cwd=app, env=env, check=True, timeout=600, stdout=sys.stderr,
        )
        bundle = Path(archive).expanduser().resolve() if archive else stage / "browser.zip"
        if not archive:
            subprocess.run(
                ["/usr/bin/curl", "--fail", "--location", "--proto", "=https", "--proto-redir", "=https",
                 "--connect-timeout", "10", "--max-time", "300", "--output", str(bundle), PIN["archive_url"]],
                env=env, check=True, timeout=310, stdout=sys.stderr,
            )
        if digest(bundle) != PIN["archive_sha256"]:
            raise RuntimeError("Camoufox archive checksum mismatch; nothing installed")
        subprocess.run(["/usr/bin/ditto", "-xk", str(bundle), str(app / "browser")],
                       check=True, timeout=120, env=env)
        # The wrapper requires metadata beside the app; camoufox-js reads INSTALL_DIR.
        version, _, release = PIN["browser_version"].partition("-")
        for parent in (app / "browser", app / PIN["resources"]):
            (parent / "version.json").write_text(json.dumps({"version": version, "release": release}) + "\n")
        validate(app)
        previous = stage / "previous"
        if runtime.exists():
            runtime.rename(previous)
        try:
            app.rename(runtime)
        except OSError:
            if previous.exists():
                previous.rename(runtime)
            raise


def process_table():
    result = subprocess.check_output(["/bin/ps", "-axo", "pid=,ppid=,pgid=,lstart="],
                                     env={"PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"}, text=True, timeout=10)
    table = {}
    for line in result.splitlines():
        fields = line.split(None, 3)
        if len(fields) == 4:
            table[int(fields[0])] = (int(fields[1]), fields[3].strip(), int(fields[2]))
    return table


def remember_children(pid, owned, table):
    parents = {pid}
    while parents:
        children = {child for child, info in table.items() if info[0] in parents}
        for child in children:
            owned[child] = table[child][1]
        parents = children


def alive(owned, table):
    return [pid for pid, started in owned.items() if pid in table and table[pid][1] == started]


class OwnedProcesses:
    def __init__(self, server_pid, journal):
        self.server_pid = server_pid
        self.server_started = None
        self.journal = journal
        self.owned = {}
        self.groups = {}
        self.retired = set()
        self.errors = set()

    def add_group(self, group, started):
        if (group, started) not in self.retired:
            current = self.groups.get(group)
            if current is not None and current != started:
                self.errors.add(f"Process group identity changed: {group}")
            else:
                self.groups[group] = started

    def read_journal(self, complete):
        spawns = {}
        identities = {}
        try:
            text = self.journal.read_text()
            if text and not text.endswith("\n"):
                if complete:
                    self.errors.add("Incomplete process ownership journal")
                text = text.rpartition("\n")[0]
            for line in text.splitlines():
                record = json.loads(line)
                pid = record["pid"]
                if not isinstance(pid, int) or pid <= 0:
                    raise ValueError("Invalid process ID")
                if record["event"] == "spawn":
                    if record["group"] not in (None, pid):
                        raise ValueError("Invalid browser process group")
                    spawns[pid] = record["group"]
                    identities.pop(pid, None)
                elif record["event"] == "identity" and isinstance(record["started"], str) and record["started"]:
                    identities[pid] = record["started"]
                else:
                    raise ValueError("Invalid ownership record")
            for pid, group in spawns.items():
                if pid in identities:
                    self.owned.setdefault(pid, identities[pid])
                    if group is not None:
                        self.add_group(group, identities[pid])
                elif complete:
                    self.errors.add(f"Browser process identity missing: {pid}")
        except (OSError, ValueError, KeyError, TypeError) as error:
            self.errors.add(f"Invalid process ownership journal: {error}")

    def sample(self, complete=False):
        self.read_journal(complete)
        try:
            table = process_table()
        except (OSError, subprocess.SubprocessError) as error:
            self.errors.add(f"Process ownership observation failed: {error}")
            return []
        if self.server_pid in table and table[self.server_pid][0] == os.getpid():
            started = table[self.server_pid][1]
            if self.server_started is None:
                self.server_started = started
            if started == self.server_started:
                remember_children(self.server_pid, self.owned, table)
                self.add_group(self.server_pid, started)
            else:
                self.errors.add("Server process identity changed")
        for pid in alive(self.owned, table):
            group = table[pid][2]
            if group in table and group != os.getpgrp():
                self.add_group(group, table[group][1])
        for group, started in list(self.groups.items()):
            if group in table and table[group][1] != started:
                self.errors.add(f"Process group leader changed: {group}")
                self.retired.add((group, started))
                del self.groups[group]
                continue
            members = {pid: info[1] for pid, info in table.items() if info[2] == group}
            if not members:
                self.retired.add((group, started))
                del self.groups[group]
            else:
                self.owned.update(members)
        return alive(self.owned, table)


def listening(pid, port):
    result = subprocess.run(
        ["/usr/sbin/lsof", "-nP", "-a", "-p", str(pid), f"-iTCP:{port}", "-sTCP:LISTEN", "-Fn"],
        capture_output=True, text=True, timeout=5,
    )
    return result.returncode == 0 and f"n127.0.0.1:{port}" in result.stdout


def run(runtime, node, port, parent_pid=None):
    parent_pid = os.getppid() if parent_pid is None else parent_pid
    with runtime_lock(runtime):
        supervise(runtime, node, port, parent_pid)


def supervise(runtime, node, port, parent_pid):
    validate(runtime)
    if port == 0:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
    state = Path(tempfile.mkdtemp(prefix="camofox-task-"))
    env = child_environment(state, node)
    journal = state / "processes.jsonl"
    env.update(CAMOFOX_PORT=str(port), CAMOUFOX_EXECUTABLE=str(runtime / PIN["executable"]),
               CAMOUFOX_INSTALL_DIR=str(runtime / PIN["resources"]),
               CAMOFOX_PROCESS_JOURNAL=str(journal))
    stopping = False

    def request_stop(_signal, _frame):
        nonlocal stopping
        stopping = True

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, request_stop)
    proc = None
    ownership = None
    lease = None
    ready = False
    failure = None
    base = f"http://127.0.0.1:{port}"
    try:
        leases = runtime.with_suffix(".leases")
        leases.mkdir(mode=0o700, exist_ok=True)
        lease = leases / (state.name + ".json")
        lease.write_text(json.dumps({"stateDir": str(state), "supervisorPid": os.getpid()}) + "\n")
        os.chmod(lease, 0o600)
        journal.touch(mode=0o600, exist_ok=False)
        if os.getppid() != parent_pid:
            raise RuntimeError("Launching parent exited during preflight; server was not started")
        with (state / "server.log").open("w") as log:
            proc = subprocess.Popen([str(node), "--import", str(Path(__file__).with_name("camofox-processes.mjs")),
                                     str(runtime / SERVER)], cwd=state, env=env,
                                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            ownership = OwnedProcesses(proc.pid, journal)
            deadline = time.monotonic() + 60
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            while not stopping and proc.poll() is None:
                if os.getppid() != parent_pid:
                    stopping = True
                    break
                ownership.sample()
                if not ready:
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Camofox did not become ready in 60 seconds")
                    if listening(proc.pid, port):
                        try:
                            with opener.open(base + "/health", timeout=2) as response:
                                health = json.loads(response.read(65536))
                            ready = health.get("ok") is True and health.get("engine") == "camoufox"
                        except (OSError, ValueError):
                            pass
                    if ready:
                        print(json.dumps({"ready": True, "pid": os.getpid(), "serverPid": proc.pid,
                                          "baseUrl": base, "userId": str(uuid.uuid4()),
                                          "sessionKey": str(uuid.uuid4()), "stateDir": str(state),
                                          "telemetry": "disabled", "retention": "ephemeral"}), flush=True)
                time.sleep(1 if ready else 0.25)
            if not stopping:
                raise RuntimeError(f"Camofox exited unexpectedly ({proc.returncode})")
    except BaseException as error:
        failure = error
    finally:
        cleanup_errors = set()
        if proc is not None:
            ownership.sample()
            try:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        cleanup_errors.add("Server required forced termination")
                        proc.kill()
                        proc.wait(timeout=10)
            except (OSError, subprocess.SubprocessError) as error:
                cleanup_errors.add(f"Server termination failed: {error}")
            if proc.returncode != 0:
                cleanup_errors.add(f"Server shutdown exit status: {proc.returncode}")
            survivors = ownership.sample(complete=proc.poll() is not None)
            signalled = set()
            deadline = time.monotonic() + 10
            while survivors and time.monotonic() < deadline:
                for pid in survivors:
                    identity = (pid, ownership.owned[pid])
                    if identity not in signalled:
                        try:
                            os.kill(pid, signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                        except OSError as error:
                            cleanup_errors.add(f"Owned process {pid} termination failed: {error}")
                        signalled.add(identity)
                time.sleep(0.1)
                survivors = ownership.sample(complete=proc.poll() is not None)
            if survivors:
                cleanup_errors.add(f"Owned children still alive: {survivors}")
            cleanup_errors.update(ownership.errors)
        if cleanup_errors:
            details = "; ".join(sorted(cleanup_errors))
            failure = RuntimeError(f"{failure}; {details}" if failure is not None else details)
        if failure is not None and (state / "server.log").exists():
            directory = Path(tempfile.mkdtemp(prefix="camofox-diagnostic-"))
            diagnostic = directory / "server.log"
            with (state / "server.log").open("rb") as log:
                log.seek(0, os.SEEK_END)
                log.seek(max(0, log.tell() - 65536))
                with diagnostic.open("xb") as output:
                    os.chmod(diagnostic, 0o600)
                    output.write(log.read(65536))
            print(json.dumps({"diagnostic": str(diagnostic), "error": str(failure)}), flush=True)
        if failure is not None and proc is not None:
            print(json.dumps({"cleaned": False, "cleanupUncertain": True,
                              "stateDir": str(state), "serverPid": proc.pid,
                              "runtime": str(runtime), "lease": str(lease),
                              "serverStopped": proc.poll() is not None}), flush=True)
        else:
            shutil.rmtree(state)
            if lease is not None:
                lease.unlink()
            print(json.dumps({"cleaned": True, "stateDir": str(state), "serverStopped": True}), flush=True)
    if failure is not None:
        raise failure


def main():
    parent_pid = os.getppid()
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    installer = commands.add_parser("install", help="Install exact dependencies and verified browser into a private cache")
    installer.add_argument("--archive", help="Use an existing official archive after checksum verification")
    installer.add_argument("--repair", action="store_true", help="Replace an invalid cache while no task uses it")
    runner = commands.add_parser("run", help="Run one ephemeral server; SIGINT/SIGTERM stops it and removes task state")
    runner.add_argument("--port", type=int, default=0, help="Loopback port (default: choose a free port)")
    commands.add_parser("check", help="Verify the installed pins, browser hash and privacy policies")
    args = parser.parse_args()
    if sys.platform != PIN["platform"] or platform.machine() != PIN["architecture"]:
        parser.error("This recipe is qualified only on macOS arm64")
    runtime = runtime_path()
    node = node_executable(install_missing=args.command == "install")
    if args.command == "install":
        install(runtime, node, args.archive, repair=args.repair)
    elif args.command == "run":
        if not 0 <= args.port <= 65535:
            parser.error("port must be between 0 and 65535")
        run(runtime, node, args.port, parent_pid)
        return
    else:
        with runtime_lock(runtime):
            validate(runtime)
    print(json.dumps({"runtime": str(runtime), "node": PIN["node"],
                      "camofox": PACKAGE["dependencies"]["@askjo/camofox-browser"],
                      "camoufox": PIN["browser_version"], "verified": True,
                      "verificationScope": ["shipped_inputs", "declared_dependency_versions",
                                            "browser_executable_sha256", "version_metadata", "telemetry_policies"]}))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"camofox-runtime: {error}", file=sys.stderr)
        sys.exit(1)
