"""Container-only scenarios: real Orca desktop, real SSH relay, generated agents."""
import importlib.util
import json
import pathlib
import shlex
import subprocess
import time
import urllib.request

import websocket

ROOT = pathlib.Path("/dotfiles")
SCRIPT = ROOT / "home/dot_config/raycast/scripts/executable_orca-agent-session.py"
ENTRYPOINT = pathlib.Path("/tmp/orca-agent-session")


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

    def evaluate(self, expression):
        self.seq += 1
        self.ws.send(json.dumps({"id": self.seq, "method": "Runtime.evaluate", "params": {
            "expression": expression, "awaitPromise": True, "returnByValue": True}}))
        while True:
            response = json.loads(self.ws.recv())
            if response.get("id") != self.seq:
                continue
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
    result = subprocess.run(["python3", str(ENTRYPOINT), "--json", *args], capture_output=True, text=True, timeout=90)
    assert result.returncode == expected, result.stdout + result.stderr
    return json.loads(result.stdout)


def remote(*args, check=True):
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new",
                           "root@remote", shlex.join(args)], capture_output=True, text=True, check=check, timeout=20)


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


def paired_runtime(desktop, resolver):
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
    desktop.evaluate(f"window.api.settings.setActiveRuntimeEnvironmentPreference({json.dumps({'environmentId': env_id})})")
    desktop.evaluate("location.reload(); true")
    wait(lambda: desktop.evaluate("Boolean(window.api?.runtimeEnvironments)"), "paired desktop reload")
    host = f"runtime:{env_id}"
    worktree = wait(lambda: next(iter(cli("worktree", "list", "--environment", env_id)["worktrees"]), None),
                    "paired worktree on server")
    created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                  "--command", "claude fixture-source", "--focus", "--environment", env_id)
    handle = created["terminal"]["handle"]
    selector = f"id:{worktree['id']}"
    resolver.SELECTED_ENVIRONMENT = env_id
    wait(lambda: any(p.get("terminal") == handle and p.get("agentStatus", {}).get("providerSession", {}).get("id")
                     == "fixture-source" for p in resolver.rpc("session.tabs.list", {"worktree": selector})["tabs"]),
         "paired conversation hook binding")
    result = shortcut("--fork", "--dry-run")
    assert result["sessionId"] == "fixture-source" and result["executionHostId"] == host, result
    forked = shortcut("--fork")
    assert forked["newTerminal"], forked
    wait(lambda: any(p.get("terminal") == forked["newTerminal"]
                     and p.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-fork"
                     for p in resolver.rpc("session.tabs.list", {"worktree": selector})["tabs"]), "paired fork")
    print("PASS paired runtime: focused conversation and fork stay on the server", flush=True)
    remote("python3", "-c", "import os,signal; os.killpg(int(open('/tmp/orca-paired.pid').read()), signal.SIGTERM)")
    wait(lambda: remote("python3", "-c", "import socket; s=socket.socket(); s.settimeout(1); exit(0 if s.connect_ex(('127.0.0.1',6768)) else 1)", check=False).returncode == 0,
         "paired runtime shutdown")
    refused = shortcut("--fork", expected=1)
    assert "remote_runtime_unavailable" in refused["error"], refused
    print("PASS unavailable paired server refuses to fork", flush=True)


def main():
    ENTRYPOINT.symlink_to(SCRIPT)
    log = open("/tmp/orca-desktop.log", "w")
    app = subprocess.Popen(["dbus-run-session", "--", "xvfb-run", "-a", "/opt/squashfs-root/orca-ide",
                            "--no-sandbox", "--remote-debugging-port=9222"], stdout=log, stderr=log)
    desktop = Desktop()
    try:
        wait(desktop.connect, "Orca debugger startup")
        wait(lambda: desktop.evaluate("Boolean(window.api?.ssh && window.api?.repos)"), "Orca preload bridge")
        target = desktop.evaluate("""(async () => {
          const result = await window.api.ssh.addTarget({target: {
            label: 'Shortcut fixture', host: 'remote', port: 22, username: 'root',
            identityFile: '/root/.ssh/id_ed25519', identitiesOnly: true,
            relayGracePeriodSeconds: 1}});
          const state = await window.api.ssh.connect({targetId: result.target.id});
          if (state.status !== 'connected') throw new Error('SSH fixture did not connect');
          const added = await window.api.repos.addRemote({connectionId: result.target.id,
            remotePath: '/workspace', displayName: 'Remote shortcut fixture'});
          if ('error' in added) throw new Error(added.error);
          return {targetId: result.target.id, repoId: added.repo.id};
        })()""")
        print("Connected real Orca SSH relay", flush=True)
        worktree = wait(lambda: next((w for w in cli("worktree", "list")["worktrees"]
                                    if w.get("repoId") == target["repoId"]), None), "remote worktree")
        print(f"Remote worktree: {worktree['id']}", flush=True)
        spec = importlib.util.spec_from_file_location("shortcut", SCRIPT)
        resolver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(resolver)
        for agent in ["claude", "codex", "pi", "omp"]:
            created = cli("terminal", "create", "--worktree", f"id:{worktree['id']}",
                          "--command", f"{agent} fixture-source", "--focus")
            handle = created["terminal"]["handle"]
            wait(lambda: next((p for p in resolver.rpc("session.tabs.list", {
                "worktree": worktree["id"]})["tabs"] if p.get("terminal") == handle
                and p.get("agentStatus", {}).get("providerSession", {}).get("id") == "fixture-source"), None),
                f"{agent} hook binding")
            result = shortcut("--fork", "--dry-run")
            assert result["agent"] == agent, result
            assert result["sessionId"] == "fixture-source", result
            assert result["executionHostId"] == f"ssh:{target['targetId']}", result
            assert "/root/account home" in result["forkCommand"] if agent == "codex" else True, result
            forked = shortcut("--fork")
            assert forked["newTerminal"], forked
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
        paired_runtime(desktop, resolver)
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
