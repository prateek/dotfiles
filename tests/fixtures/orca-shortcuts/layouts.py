"""Mixed-agent layouts: the shortcut acts on the pane focused when it fired, wherever focus goes next."""
import json
import os
import pathlib
import shutil
import socket
import statistics
import struct
import subprocess
import threading
import time

from scenarios import ENTRYPOINT, cli, fork_receipts, wait

USER_DATA = pathlib.Path(os.environ["ORCA_USER_DATA_PATH"])
SHIM = pathlib.Path("/tmp/orca-shortcut-userdata")
PROXY = "/tmp/orca-shortcut-proxy.sock"
# The last read that decides focus; every later call is keyed by the captured handle.
FOCUS_READ = "session.tabs.list"
AFTER_CAPTURE = "terminal.show"

# worktree -> tabs -> panes. A pane is (agent command, source id); None runs a plain shell.
LAYOUTS = {
    "/workspace": [
        [("claude", "w1-splits-claude-source"), ("cursor-agent", "w1-splits-cursor-source"),
         ("pi", "w1-splits-pi-source")],
        [("claude", "w1-tab-claude-source")],
        [("cursor-agent", "w1-tab-cursor-source")],
        [("pi", "w1-tab-pi-source")],
    ],
    "/workspace2": [
        [("claude", "w2-mixed-claude-source"), ("pi", "w2-mixed-pi-source"), None],
        [("cursor-agent", "w2-pair-cursor-source"), ("claude", "w2-pair-claude-source")],
    ],
}
VAULT_AGENT = {"cursor-agent": "cursor"}


class RuntimeProxy:
    """Relays the helper's runtime RPCs through a socket it can observe and pause."""

    def __init__(self):
        self.lock = threading.Lock()
        self.calls = []
        self.hold = None
        self.held = threading.Event()
        self.release = threading.Event()

    def start(self):
        meta = json.loads((USER_DATA / "orca-runtime.json").read_text())
        self.upstream = next(t["endpoint"] for t in meta["transports"] if t["kind"] == "unix")
        for transport in meta["transports"]:
            if transport["kind"] == "unix":
                transport["endpoint"] = PROXY
        shutil.rmtree(SHIM, ignore_errors=True)
        SHIM.mkdir()
        for entry in USER_DATA.iterdir():
            if entry.name != "orca-runtime.json":
                (SHIM / entry.name).symlink_to(entry)
        (SHIM / "orca-runtime.json").write_text(json.dumps(meta))
        pathlib.Path(PROXY).unlink(missing_ok=True)
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(PROXY)
        self.server.listen(16)
        threading.Thread(target=self.accept, daemon=True).start()

    def reset(self, hold=None):
        with self.lock:
            self.calls = []
        self.hold = hold
        self.held.clear()
        self.release.clear()

    def accept(self):
        while True:
            client, _ = self.server.accept()
            threading.Thread(target=self.relay, args=(client,), daemon=True).start()

    def relay(self, client):
        pid = struct.unpack("3i", client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[0]
        upstream = socket.socket(socket.AF_UNIX)
        upstream.connect(self.upstream)

        def pump():
            try:
                while chunk := upstream.recv(65536):
                    client.sendall(chunk)
            except OSError:
                pass
            finally:
                # close() alone sends no FIN while the other thread is blocked in recv().
                shutdown(client)

        threading.Thread(target=pump, daemon=True).start()
        buffer = b""
        try:
            while chunk := client.recv(65536):
                buffer += chunk
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    try:
                        method = json.loads(line).get("method")
                    except json.JSONDecodeError:
                        method = None
                    with self.lock:
                        self.calls.append((time.monotonic(), method, pid))
                    if self.hold is not None and method == self.hold and not self.held.is_set():
                        self.held.set()
                        assert self.release.wait(60), "Held RPC was never released"
                    upstream.sendall(line + b"\n")
        except OSError:
            pass
        finally:
            shutdown(upstream)

    def first(self, method):
        with self.lock:
            return next((at for at, called, _ in self.calls if called == method), None)

    def callers(self, *methods):
        with self.lock:
            return {pid for _, called, pid in self.calls if called in methods}


def shutdown(connection):
    try:
        connection.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass
    connection.close()


def build_layouts(resolver):
    panes = []
    for path, tabs in LAYOUTS.items():
        if path != "/workspace":
            subprocess.run(["sh", "-c", f"mkdir -p {path} && git -C {path} init -q && git -C {path} "
                            "-c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial"],
                           check=True)
        cli("repo", "add", "--path", path)
        worktree = next(w for w in cli("worktree", "list")["worktrees"] if w["path"] == path)
        for tab_index, tab in enumerate(tabs):
            first = None
            for pane in tab:
                command = f"{pane[0]} {pane[1]}" if pane else "bash"
                if first is None:
                    created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                                  "--command", command, "--focus")["terminal"]
                else:
                    split = cli("terminal", "split", "--terminal", first, "--command", command)
                    created = split.get("terminal") or split.get("split")
                first = first or created["handle"]
                panes.append({"worktree": worktree["id"], "path": path, "tab": tab_index,
                              "handle": created["handle"], "agent": pane and pane[0], "source": pane and pane[1]})
    for pane in panes:
        wait(lambda: tab_entry(resolver, pane), f"{pane['handle']} tab entry")
        if pane["agent"]:
            wait(lambda: (tab_entry(resolver, pane) or {}).get("agentStatus", {})
                 .get("providerSession", {}).get("id") == pane["source"], f"{pane['source']} binding")
        pane["parent"] = tab_entry(resolver, pane).get("parentTabId")
    print(f"Built {len(panes)} panes across {len(LAYOUTS)} worktrees", flush=True)
    return panes


def tab_entry(resolver, pane):
    tabs = resolver.rpc("session.tabs.list", {"worktree": pane["worktree"]})["tabs"]
    return next((tab for tab in tabs if tab.get("terminal") == pane["handle"]), None)


def is_focused(resolver, pane):
    worktrees = resolver.rpc("worktree.ps", {})["worktrees"]
    active = next((w for w in worktrees if w.get("isActive")), None)
    if not active or active.get("worktreeId") != pane["worktree"]:
        return False
    result = resolver.rpc("session.tabs.list", {"worktree": pane["worktree"]})
    return any(tab.get("id") == result.get("activeTabId") and tab.get("terminal") == pane["handle"]
               for tab in result["tabs"])


def focus(resolver, pane):
    resolver.rpc("terminal.focus", {"terminal": pane["handle"]})
    wait(lambda: is_focused(resolver, pane), f"focus on {pane['source'] or 'shell'}", seconds=15)


def trigger(proxy, *args, hold=None):
    proxy.reset(hold)
    started = time.monotonic()
    process = subprocess.Popen(["python3", str(ENTRYPOINT), "--json", *args], stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, env=dict(os.environ, ORCA_USER_DATA_PATH=str(SHIM)))
    return started, process


def await_capture(proxy, process, label):
    deadline = time.monotonic() + 30
    while not proxy.held.wait(0.05):
        if process.poll() is not None or time.monotonic() > deadline:
            process.kill()
            stdout, stderr = process.communicate()
            raise AssertionError(f"{label} never finished its focus read: {stdout}{stderr} "
                                 f"RPCs: {[method for _, method, _ in proxy.calls]}")


def finish(process, expected=0):
    stdout, stderr = process.communicate(timeout=90)
    assert process.returncode == expected, stdout + stderr
    return json.loads(stdout)


def expected_locator(pane):
    if pane["agent"] in {"pi", "omp"}:
        slug = pane["path"].replace("/", "-")
        return f"/root/.{pane['agent']}/agent/sessions/-{slug}--/{pane['source']}.jsonl"
    return pane["source"]


def check_result(resolver, pane, action, result, receipts_before):
    label = f"{action} {pane['source']}"
    if action == "reveal":
        assert result["sessionId"] == pane["source"], (label, result)
        assert result["agent"] == VAULT_AGENT.get(pane["agent"], pane["agent"]), (label, result)
        assert result["worktree"] == pane["path"], (label, result)
        return
    if pane["agent"] == "cursor-agent":
        assert "cursor can't fork" in result["error"], (label, result)
        assert fork_receipts(False) == receipts_before, (label, "cursor refusal still forked")
        return
    receipts = wait(lambda: (rows if len(rows := fork_receipts(False)) > len(receipts_before) else None),
                    f"{label} process receipt")
    assert len(receipts) == len(receipts_before) + 1 and receipts[-1]["source"] == expected_locator(pane), (label, receipts[-1])
    assert receipts[-1]["cwd"] == pane["path"], (label, receipts[-1])
    new = {"worktree": pane["worktree"], "handle": result["newTerminal"]}
    entry = wait(lambda: tab_entry(resolver, new), f"{label} split")
    assert entry.get("parentTabId") == pane["parent"], (label, "fork split landed in another tab", entry)
    resolver.rpc("terminal.close", {"terminal": result["newTerminal"]})
    wait(lambda: tab_entry(resolver, new) is None, f"{label} split closed")


def destinations(panes, pane):
    """Where a user might go right after pressing the shortcut."""
    others = [p for p in panes if p is not pane]
    picks = {
        "split": next((p for p in others if p["worktree"] == pane["worktree"] and p["tab"] == pane["tab"]), None),
        "tab": next((p for p in others if p["worktree"] == pane["worktree"] and p["tab"] != pane["tab"]), None),
        "worktree": next((p for p in others if p["worktree"] != pane["worktree"]), None),
    }
    return {kind: p for kind, p in picks.items() if p}


def moved_after_capture(resolver, proxy, panes):
    """Deterministic: hold the helper right after its focus read, move focus, then let it act."""
    count = 0
    for pane in (p for p in panes if p["agent"]):
        for action in ["reveal", "fork"]:
            for kind, destination in destinations(panes, pane).items():
                focus(resolver, pane)
                receipts = fork_receipts(False)
                _, process = trigger(proxy, *(["--fork"] if action == "fork" else []), hold=AFTER_CAPTURE)
                await_capture(proxy, process, f"{action} {pane['source']}")
                focus(resolver, destination)
                proxy.release.set()
                result = finish(process, expected=1 if action == "fork" and pane["agent"] == "cursor-agent" else 0)
                landed = "the destination" if is_focused(resolver, destination) else (
                    "the fork" if result.get("newTerminal") and is_focused(
                        resolver, {"worktree": pane["worktree"], "handle": result["newTerminal"]}) else "elsewhere")
                # A fork into the tab the user is still in takes focus; anywhere else, focus stays put.
                forked_here = action == "fork" and "error" not in result and kind == "split"
                expected = "the fork" if forked_here else "the destination"
                assert landed == expected, f"{action} {pane['source']} after a {kind} move: focus on {landed}"
                check_result(resolver, pane, action, result, receipts)
                count += 1
                print(f"PASS {action} {pane['source']}: focus moved to another {kind} after capture; "
                      f"focus ended on {landed}", flush=True)
    shell = next(p for p in panes if not p["agent"])
    focus(resolver, shell)
    receipts = fork_receipts(False)
    _, process = trigger(proxy, "--fork")
    refused = finish(process, expected=1)
    # Orca may or may not count a shell command as a running agent; either way nothing is identified.
    assert any(reason in refused["error"] for reason in ("No agent running", "Could not identify the agent")), refused
    assert fork_receipts(False) == receipts, "Plain shell forked"
    print(f"PASS {count} moved-focus trials; a focused plain shell is refused", flush=True)


def human_moves(resolver, proxy, panes, budget_ms):
    """Move focus at the budget mark, as a quick user would, and require the original pane."""
    latencies = []
    for pane, destination in ((p, d) for p in panes if p["agent"]
                              for kind, d in destinations(panes, p).items() if kind in {"tab", "worktree"}):
        focus(resolver, pane)
        started, process = trigger(proxy)
        time.sleep(max(0, started + budget_ms / 1000 - time.monotonic()))
        moving = time.monotonic()
        resolver.rpc("terminal.focus", {"terminal": destination["handle"]})
        result = finish(process)
        captured = proxy.first(FOCUS_READ)
        assert captured, f"{pane['source']}: helper never read focus"
        latencies.append((captured - started) * 1000)
        print(f"TIMING {pane['source']}: focus read {latencies[-1]:.0f} ms after trigger, "
              f"focus moved at {(moving - started) * 1000:.0f} ms", flush=True)
        # A child process (the Node CLI) costs ~170 ms on macOS, more than this lane's Linux cost.
        assert proxy.callers("worktree.ps", FOCUS_READ) == {process.pid}, f"{pane['source']}: focus read via a child process"
        # The relay timestamps requests, not Orca's read; the session ID is the outcome that matters.
        assert captured < moving and result["sessionId"] == pane["source"], (pane["source"], result)
        wait(lambda: is_focused(resolver, destination), "human-speed focus move")
    print(f"TIMING focus read: median {statistics.median(latencies):.0f} ms, worst {max(latencies):.0f} ms, "
          f"budget {budget_ms} ms", flush=True)
    print(f"PASS {len(latencies)} human-speed moves at {budget_ms} ms act on the original pane, "
          "with focus read in-process", flush=True)


def run(resolver, budget_ms):
    proxy = RuntimeProxy()
    proxy.start()
    panes = build_layouts(resolver)
    moved_after_capture(resolver, proxy, panes)
    human_moves(resolver, proxy, panes, budget_ms)
