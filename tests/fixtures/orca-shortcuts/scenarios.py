"""Container-only scenarios: real Orca desktop, real SSH relay, generated agents."""
import argparse
import importlib.util
import json
import os
import pathlib
import shlex
import subprocess
import sys
import time
import urllib.request

import websocket

ROOT = pathlib.Path("/dotfiles")
SCRIPT = ROOT / "home/dot_config/raycast/scripts/executable_orca-agent-session.py"
ENTRYPOINT = pathlib.Path("/tmp/orca-agent-session")
ORCACTL = ROOT / "build/orcactl/linux-arm64/orcactl"
SELECTED = {"entrypoint": "python"}


def shortcut_command(*args):
    """The selected entrypoint's argv for helper-style flags (`--fork`, `--dry-run`), with JSON output."""
    if SELECTED["entrypoint"] == "orcactl":
        action = "fork" if "--fork" in args else "reveal"
        return [str(ORCACTL), "ses", action, *(arg for arg in args if arg != "--fork"), "--json"]
    return ["python3", str(ENTRYPOINT), "--json", *args]


def wait(check, description, seconds=45):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(f"Timed out: {description}")


class Desktop:
    def __init__(self):
        self.seq = 0
        self.ws = None

    def connect(self):
        try:
            with urllib.request.urlopen("http://127.0.0.1:9222/json", timeout=1) as response:
                pages = json.load(response)
            page = next(p for p in pages if p["type"] == "page")
            self.ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=90, suppress_origin=True)
            return True
        except (OSError, StopIteration):
            return False

    def evaluate(self, expression, navigating=False):
        self.seq += 1
        self.ws.send(json.dumps({"id": self.seq, "method": "Runtime.evaluate", "params": {
            "expression": expression, "awaitPromise": True, "returnByValue": True}}))
        while True:
            response = json.loads(self.ws.recv())
            if response.get("id") != self.seq:
                continue
            if navigating and response.get("error", {}).get("message") in {
                "Inspected target navigated or closed", "Cannot find context with specified id"
            }:
                return None
            if "error" in response or "exceptionDetails" in response.get("result", {}):
                raise AssertionError(f"Desktop evaluation failed: {response}")
            return response["result"]["result"].get("value")


def cli(*args):
    result = subprocess.run(["orca-ide", *args, "--json"], capture_output=True, text=True, timeout=90)
    payload = json.loads(result.stdout)
    if result.returncode or not payload.get("ok"):
        raise AssertionError(f"orca {args[:2]}: {payload}")
    return payload["result"]


def shortcut(*args, expected=0):
    result = subprocess.run(shortcut_command(*args), capture_output=True, text=True, timeout=90)
    assert result.returncode == expected, result.stdout + result.stderr
    return json.loads(result.stdout)


def remote(*args, check=True):
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new",
                           "root@remote", shlex.join(args)], capture_output=True, text=True, check=check, timeout=20)


def fork_receipts(on_remote):
    if on_remote:
        result = remote("cat", "/tmp/fork-receipts.jsonl", check=False)
        if result.returncode:
            assert result.returncode == 1 and "No such file" in result.stderr, result.stderr
            return []
        content = result.stdout
    else:
        path = pathlib.Path("/tmp/fork-receipts.jsonl")
        content = path.read_text() if path.exists() else ""
    return [json.loads(line) for line in content.splitlines()]


def checked_fork(agent, host):
    on_remote = host != "local"
    before = fork_receipts(on_remote)
    other_before = fork_receipts(not on_remote)
    forked = shortcut("--fork")
    assert forked["newTerminal"] and forked["executionHostId"] == host, forked
    receipts = wait(lambda: (rows if len(rows := fork_receipts(on_remote)) > len(before) else None),
                    f"{agent} process receipt on {host}")
    assert len(receipts) == len(before) + 1, receipts
    assert fork_receipts(not on_remote) == other_before, "Fork ran on both hosts"
    receipt = receipts[-1]
    hostname = remote("hostname").stdout.strip() if on_remote else os.uname().nodename
    assert receipt["hostname"] == hostname and receipt["agent"] == agent, receipt
    assert receipt["cwd"] == "/workspace", receipt
    expected_source = (f"/root/.{agent}/agent/sessions/--workspace--/fixture-source.jsonl"
                       if agent in {"pi", "omp"} else "fixture-source")
    assert receipt["source"] == expected_source, receipt
    if agent == "codex":
        assert receipt["codexHome"] == "/root/account home", receipt
    print(f"PROCESS {host}: {json.dumps(receipt, sort_keys=True)}", flush=True)
    return forked


def wait_focused_source(resolver, worktree_id, handle, agent):
    def focused():
        result = resolver.rpc("session.tabs.list", {"worktree": worktree_id})
        return next((pane for pane in result["tabs"]
                     if pane.get("id") == result.get("activeTabId") and pane.get("terminal") == handle
                     and pane.get("agentStatus", {}).get("agentType") == agent
                     and pane.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-source"), None)
    try:
        return wait(focused, f"focused {agent} source binding")
    except AssertionError:
        result = resolver.rpc("session.tabs.list", {"worktree": worktree_id})
        print(f"TAB STATE (want {handle}):", json.dumps({"active": result.get("activeTabId"), "tabs": [
            {"id": t.get("id"), "terminal": t.get("terminal"), "agent": (t.get("agentStatus") or {}).get("agentType"),
             "session": ((t.get("agentStatus") or {}).get("providerSession") or {}).get("id")} for t in result["tabs"]]}), flush=True)
        raise


def focus_terminal_tab(desktop, resolver, worktree_id, handle):
    pane = wait(lambda: next((p for p in resolver.rpc("session.tabs.list", {"worktree": worktree_id})["tabs"]
                              if p.get("terminal") == handle), None), "created terminal tab")
    tab_id = pane.get("parentTabId") or pane["tabId"]
    wait(lambda: desktop.evaluate(f"""(() => {{
      const tab = [...document.querySelectorAll('[data-tab-id]')]
        .find(tab => [{json.dumps(tab_id)}, {json.dumps("web-terminal-" + tab_id)}].includes(tab.dataset.tabId));
      if (!tab) return false;
      tab.dispatchEvent(new PointerEvent('pointerdown', {{bubbles: true, button: 0}}));
      tab.dispatchEvent(new PointerEvent('pointerup', {{bubbles: true, button: 0}}));
      return true;
    }})()"""), "desktop terminal tab")
    wait(lambda: desktop.evaluate(f"""[...document.querySelectorAll('[data-tab-id]')]
      .some(tab => [{json.dumps(tab_id)}, {json.dumps("web-terminal-" + tab_id)}]
        .includes(tab.dataset.tabId) && tab.dataset.active === 'true')"""), "active desktop terminal tab")
    desktop.evaluate("window.api.session.flush()")


def local_runtime(resolver):
    cli("repo", "add", "--path", "/workspace")
    worktree = next(w for w in cli("worktree", "list")["worktrees"] if w["path"] == "/workspace")
    for agent in ["claude", "codex", "pi", "omp", "droid"]:
        created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                      "--command", f"{agent} fixture-source", "--focus")
        handle = created["terminal"]["handle"]
        wait_focused_source(resolver, worktree["id"], handle, agent)
        result = shortcut("--fork", "--dry-run")
        assert result["agent"] == agent and result["sessionId"] == "fixture-source", result
        assert result["executionHostId"] == "local", result
        forked = checked_fork(agent, "local")
        wait(lambda: any(p.get("terminal") == forked["newTerminal"]
                         and p.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-fork"
                         for p in resolver.rpc("session.tabs.list", {"worktree": worktree["id"]})["tabs"]),
             f"local {agent} fork binding")
        print(f"PASS {agent}: resolve and fork on local host", flush=True)


def real_claude(worktree, resolver):
    server = subprocess.Popen(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "root@remote", "python3",
                               "/dotfiles/tests/fixtures/orca-shortcuts/llm-server.py"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        wait(lambda: remote("python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8033/health', timeout=1)", check=False).returncode == 0,
             "fake API server")
        remote("cp", "/dotfiles/tests/fixtures/orca-shortcuts/real-claude.cjs", "/usr/local/bin/claude")
        remote("chmod", "+x", "/usr/local/bin/claude")
        created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}", "--command", "claude", "--focus")
        handle = created["terminal"]["handle"]

        def read_result():
            result = remote("cat", "/tmp/real-claude-result.json", check=False)
            return json.loads(result.stdout) if result.returncode == 0 else None

        response = wait(read_result, "real Claude result from fake API", seconds=90)
        assert not response.get("is_error"), response
        assert response["result"] == "Fixture answer from the isolated API server.", response
        wait(lambda: any(p.get("terminal") == handle and p.get("agentStatus", {}).get("providerSession", {}).get("id")
                         == response["session_id"] for p in resolver.rpc("session.tabs.list", {"worktree": worktree["id"]})["tabs"]),
             "real Claude hook binding")
        resolved = shortcut()
        assert resolved["agent"] == "claude" and resolved["sessionId"] == response["session_id"], resolved
        assert resolved["executionHostId"].startswith("ssh:"), resolved
        assert resolved["filePath"].startswith("/root/.claude/"), resolved
        assert int(remote("cat", "/tmp/llm-request-count").stdout) > 0
        print("PASS real Claude CLI → fake API → native transcript → SSH hook → shortcut", flush=True)
    finally:
        server.terminate()
        server.wait(timeout=10)


def paired_runtime(desktop, resolver, version):
    remote("cp", "/dotfiles/tests/fixtures/orca-shortcuts/agent.cjs", "/usr/local/bin/claude")
    remote("python3", "-c", """import os,subprocess
env = dict(os.environ, ORCA_USER_DATA_PATH='/root/.config/orca-paired-fixture')
log = open('/tmp/orca-paired.log', 'w')
process = subprocess.Popen(['/opt/squashfs-root/orca-ide', '--no-sandbox', 'serve', '--port', '6768',
                  '--pairing-address', 'ws://remote:6768/runtime', '--json'],
                 env=env, stdout=log, stderr=log, stdin=subprocess.DEVNULL, start_new_session=True)
open('/tmp/orca-paired.pid', 'w').write(str(process.pid))
""")

    def ready():
        for line in remote("cat", "/tmp/orca-paired.log").stdout.splitlines():
            if line.startswith('{"type":"orca_server_ready"'):
                return json.loads(line)
        return None

    offer = wait(ready, "paired runtime ready")
    args = {"name": "Paired shortcut fixture", "pairingCode": offer["pairing"]["url"]}
    environment = desktop.evaluate(f"window.api.runtimeEnvironments.addFromPairingCode({json.dumps(args)})")["environment"]
    env_id = environment["id"]
    desktop.evaluate(f"window.api.runtimeEnvironments.connect({json.dumps({'selector': env_id})})")
    added = desktop.evaluate(f"window.api.runtimeEnvironments.call({json.dumps({'selector': env_id, 'method': 'repo.add', 'params': {'path': '/workspace'}})})")
    assert added.get("ok"), added
    host = f"runtime:{env_id}"
    worktree = next(iter(cli("worktree", "list", "--environment", env_id)["worktrees"]))
    cli("worktree", "set", "--worktree", f"id:{worktree['id']}", "--display-name", "Paired shortcut workspace",
        "--environment", env_id)
    if version == "1.4.224":
        for agent in ["claude", "codex", "pi", "omp", "droid"]:
            created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                          "--command", f"{agent} fixture-source", "--focus", "--environment", env_id)
            desktop.evaluate("location.reload(); true")
            wait(lambda: desktop.evaluate("Boolean(window.api?.runtimeEnvironments)", navigating=True), "paired desktop reload")
            wait(lambda: desktop.evaluate("""(() => {
              const card = [...document.querySelectorAll('[data-worktree-card-surface]')]
                .find(card => card.textContent.includes('Paired shortcut workspace'));
              if (!card) return false;
              card.click();
              return true;
            })()"""), "paired sidebar card")
            focused = wait(lambda: desktop.evaluate(f"""window.api.session.get().then(s =>
              s.activeWorkspaceExecutionHostId === {json.dumps(host)} ? {{host: s.activeWorkspaceExecutionHostId,
                worktree: s.activeWorktreeId}} : null)"""), "paired sidebar focus")
            desktop.evaluate("window.api.session.flush()")
            resolver.SELECTED_ENVIRONMENT = env_id
            wait_focused_source(resolver, worktree["id"], created["terminal"]["handle"], agent)
            default = desktop.evaluate("window.api.settings.get().then(s => s.activeRuntimeEnvironmentId)")
            assert default is None, default
            print(f"SIDEBAR {json.dumps(focused)}; default environment: {default}", flush=True)
            result = shortcut("--fork", "--dry-run")
            assert result["executionHostId"] == host and result["sessionId"] == "fixture-source", result
            checked_fork(agent, host)
            print(f"PASS paired sidebar {agent}: local default forks on the server", flush=True)
    desktop.evaluate(f"window.api.settings.setActiveRuntimeEnvironmentPreference({json.dumps({'environmentId': env_id})})")
    desktop.evaluate("location.reload(); true")
    wait(lambda: desktop.evaluate("Boolean(window.api?.runtimeEnvironments)", navigating=True), "selected-server reload")
    worktree = wait(lambda: next(iter(cli("worktree", "list", "--environment", env_id)["worktrees"]), None),
                    "paired worktree on server")
    for agent in ["claude", "codex", "pi", "omp", "droid"]:
        created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                      "--command", f"{agent} fixture-source", "--focus", "--environment", env_id)
        desktop.evaluate("location.reload(); true")
        wait(lambda: desktop.evaluate("Boolean(window.api?.runtimeEnvironments)", navigating=True), "paired agent reload")
        wait(lambda: desktop.evaluate("""(() => {
          const card = [...document.querySelectorAll('[data-worktree-card-surface]')]
            .find(card => card.textContent.includes('Paired shortcut workspace'));
          if (!card) return false;
          card.click();
          return true;
        })()"""), "selected-server sidebar card")
        handle = created["terminal"]["handle"]
        selector = f"id:{worktree['id']}"
        resolver.SELECTED_ENVIRONMENT = env_id
        focus_terminal_tab(desktop, resolver, selector, handle)
        wait_focused_source(resolver, selector, handle, agent)
        result = shortcut("--fork", "--dry-run")
        assert result["sessionId"] == "fixture-source" and result["executionHostId"] == host, result
        forked = checked_fork(agent, host)
        wait(lambda: any(p.get("terminal") == forked["newTerminal"]
                         and p.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-fork"
                         for p in resolver.rpc("session.tabs.list", {"worktree": selector})["tabs"]), "paired fork")
        print(f"PASS paired {agent}: focused conversation and fork stay on the server", flush=True)
    remote("python3", "-c", "import os,signal; os.killpg(int(open('/tmp/orca-paired.pid').read()), signal.SIGTERM)")
    wait(lambda: remote("python3", "-c", "import socket; s=socket.socket(); s.settimeout(1); exit(0 if s.connect_ex(('127.0.0.1',6768)) else 1)", check=False).returncode == 0,
         "paired runtime shutdown")
    refused = shortcut("--fork", expected=1)
    assert "remote_runtime_unavailable" in refused["error"], refused
    print("PASS unavailable paired server refuses to fork", flush=True)


def ssh_runtime(desktop, resolver):
    target = desktop.evaluate("""(async () => {
      const result = await window.api.ssh.addTarget({target: {
        label: 'Shortcut fixture', host: 'remote', port: 22, username: 'root',
        identityFile: '/root/.ssh/id_ed25519', identitiesOnly: true,
        relayGracePeriodSeconds: 1}});
      const state = await window.api.ssh.connect({targetId: result.target.id});
      if (state.status !== 'connected' || state.plainSsh) {
        throw new Error('SSH fixture has no relay: ' + JSON.stringify(state));
      }
      const added = await window.api.repos.addRemote({connectionId: result.target.id,
        remotePath: '/workspace', displayName: 'Remote shortcut fixture'});
      if ('error' in added) throw new Error(added.error);
      return {targetId: result.target.id, repoId: added.repo.id};
    })()""")
    print("Connected real Orca SSH relay", flush=True)
    worktree = wait(lambda: next((w for w in cli("worktree", "list")["worktrees"]
                                if w.get("repoId") == target["repoId"]), None), "remote worktree")
    print(f"Remote worktree: {worktree['id']}", flush=True)
    for agent in ["claude", "codex", "pi", "omp", "droid"]:
        created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                      "--command", f"{agent} fixture-source", "--focus")
        handle = created["terminal"]["handle"]
        wait_focused_source(resolver, worktree["id"], handle, agent)
        result = shortcut("--fork", "--dry-run")
        assert result["agent"] == agent, result
        assert result["sessionId"] == "fixture-source", result
        assert result["executionHostId"] == f"ssh:{target['targetId']}", result
        assert "/root/account home" in result["forkCommand"] if agent == "codex" else True, result
        forked = checked_fork(agent, f"ssh:{target['targetId']}")
        wait(lambda: next((p for p in resolver.rpc("session.tabs.list", {
            "worktree": worktree["id"]})["tabs"]
            if p.get("terminal") == forked["newTerminal"]
            and p.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-fork"), None),
            f"{agent} fork on SSH host")
        print(f"PASS {agent}: resolve and fork on SSH host", flush=True)
    real_claude(worktree, resolver)
    desktop.evaluate(f"window.api.ssh.disconnect({json.dumps({'targetId': target['targetId']})})")
    wait(lambda: (desktop.evaluate(f"window.api.ssh.getState({json.dumps({'targetId': target['targetId']})})") or {}).get("status")
         != "connected", "SSH disconnect publication")
    refused = shortcut("--fork", expected=1)
    assert "error" in refused, refused
    print("PASS disconnected host refuses to fork", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", choices=["all", "local", "ssh", "paired", "layouts"], default="all")
    parser.add_argument("--orca-version", required=True)
    parser.add_argument("--focus-budget-ms", type=int, default=150,
                        help="layouts: when focus moves after the trigger; the shortcut must have read it by then")
    parser.add_argument("--entrypoint", choices=["python", "orcactl"], default="python")
    args = parser.parse_args()
    SELECTED["entrypoint"] = args.entrypoint
    ENTRYPOINT.symlink_to(SCRIPT)
    log = open("/tmp/orca-desktop.log", "w")
    app = subprocess.Popen(["dbus-run-session", "--", "xvfb-run", "-a", "/opt/squashfs-root/orca-ide",
                            "--no-sandbox", "--remote-debugging-port=9222"], stdout=log, stderr=log,
                           env=dict(os.environ, CODEX_HOME="/root/account home"))
    desktop = Desktop()
    try:
        wait(desktop.connect, "Orca debugger startup")
        wait(lambda: desktop.evaluate("Boolean(window.api?.ssh && window.api?.repos)"), "Orca preload bridge")
        wait(lambda: cli("status").get("graph", {}).get("state") == "ready", "Orca runtime graph")
        spec = importlib.util.spec_from_file_location("shortcut", SCRIPT)
        resolver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(resolver)
        if args.scenario in {"all", "local", "paired"}:
            local_runtime(resolver)
        if args.scenario in {"all", "ssh"}:
            ssh_runtime(desktop, resolver)
        if args.scenario in {"all", "paired"}:
            paired_runtime(desktop, resolver, args.orca_version)
        if args.scenario == "layouts":
            # layouts imports this module's helpers; reuse it rather than executing it twice.
            sys.modules.setdefault("scenarios", sys.modules[__name__])
            import layouts
            layouts.run(resolver, args.focus_budget_ms)
    finally:
        if desktop.ws:
            desktop.ws.close()
        app.terminate()
        try:
            app.wait(timeout=10)
        except subprocess.TimeoutExpired:
            app.kill()
            app.wait()
        log.close()


if __name__ == "__main__":
    main()
