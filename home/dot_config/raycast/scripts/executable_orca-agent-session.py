#!/usr/bin/env -S PATH=${PATH}:/opt/homebrew/bin:/usr/local/bin uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Reveal Orca Agent Session
# @raycast.mode silent
# @raycast.packageName Orca
#
# Optional parameters:
# @raycast.icon 🔍
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description When Orca is frontmost, open agentsview at the session of the agent running in the focused terminal (and copy the session ID). Bind to ⌥A in Raycast.
# @raycast.author Prateek Rungta
#
# orca-agent-session — resolve the agent session in Orca's focused terminal.
#
# Doubles as a Raycast command (frontmatter above; the shebang appends
# Homebrew paths because Raycast spawns scripts with a minimal PATH) and a
# plain CLI via the ~/bin symlink:
#
#   orca-agent-session                # gate on Orca frontmost, copy + open agentsview
#   orca-agent-session --fork         # gate, copy, and fork the session into a new split
#   orca-agent-session --json         # machine output, no gate / copy / open
#   orca-agent-session --json --copy  # machine output, and copy the session ID
#   orca-agent-session --fork --dry-run --json   # print the fork plan only
#   orca-agent-session --worktree ~/code/worktrees/dotfiles/foo --json
#
# Session identity uses Orca's private session.tabs.list providerSession
# metadata and aiVault.listSessions. Without a pane binding, only a unique
# local session is accepted; timestamps cannot identify a focused conversation.

import argparse
import json
import os
import re
import shlex
import socket
import subprocess
import sys
import urllib.parse
import uuid

ORCA_USER_DATA = os.path.expanduser("~/Library/Application Support/orca")
ORCA_BUNDLE_ID = "com.stablyai.orca"

# Orca reports the pane's foreground process; the AI vault keys sessions by
# agent name. These differ for a handful of agents (from Orca's
# tui-agent-config detectCmd -> agent key). Unlisted names pass through, and
# shells and shared interpreters cannot identify an agent on their own.
VAULT_AGENT_BY_PROCESS = {
    "agent": "cursor",
    "agy": "antigravity",
    "auggie": "aug",
    "cn": "continue",
    "cursor-agent": "cursor",
    "kiro-cli": "kiro",
    "mimo": "mimo-code",
    "qwen": "qwen-code",
    "traecli": "trae",
    "vibe": "mistral-vibe",
}
GENERIC_PROCESSES = {"zsh", "bash", "fish", "sh", "login", "nu", "tcsh", "node", "bun"}

JSON_MODE = False


def fail(message, benign=False):
    if JSON_MODE:
        print(json.dumps({"error": message}))
    else:
        print(message)
    sys.exit(0 if benign else 1)


def orca_cli(*args):
    try:
        proc = subprocess.run(["orca", *args, "--json"], capture_output=True, text=True)
    except FileNotFoundError:
        fail("orca CLI not found on PATH")
    try:
        envelope = json.loads(proc.stdout)
    except json.JSONDecodeError:
        fail(f"orca {args[0]} failed: {proc.stderr.strip() or proc.stdout.strip()}")
    if not envelope.get("ok"):
        fail(f"orca {args[0]} failed: {envelope.get('error')}")
    return envelope["result"]


def rpc(method, params, timeout=15, fatal=True):
    """One runtime RPC round-trip. fatal=False returns None on a method-level
    error (e.g. terminal_gone for a half-dead pane) so per-pane probes can
    skip instead of aborting; transport-level failures always abort."""
    try:
        with open(os.path.join(ORCA_USER_DATA, "orca-runtime.json")) as f:
            meta = json.load(f)
        endpoint = next(
            t["endpoint"] for t in meta["transports"] if t["kind"] == "unix"
        )
    except (OSError, KeyError, StopIteration, json.JSONDecodeError):
        fail("Orca runtime metadata not found; is Orca running?")
    request = {
        "id": str(uuid.uuid4()),
        "authToken": meta["authToken"],
        "method": method,
        "params": params,
    }
    try:
        with socket.socket(socket.AF_UNIX) as s:
            s.settimeout(timeout)
            s.connect(endpoint)
            s.sendall((json.dumps(request) + "\n").encode())
            buf = b""
            while True:
                chunk = s.recv(65536)
                if not chunk:
                    fail(f"Orca runtime closed the connection ({method})")
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if not line.strip():
                        continue
                    try:
                        frame = json.loads(line)
                    except json.JSONDecodeError:
                        fail(f"Orca RPC {method} returned an invalid frame")
                    if frame.get("_keepalive") or frame.get("id") != request["id"]:
                        continue
                    if not frame.get("ok"):
                        if not fatal:
                            return None
                        error = frame.get("error", {})
                        fail(f"Orca RPC {method} failed: {error.get('message', error)}")
                    if "result" not in frame:
                        fail(f"Orca RPC {method} returned no result")
                    return frame["result"]
    except (OSError, TimeoutError):
        fail("Could not reach the Orca runtime socket; is Orca running?")


def frontmost_is_orca():
    front = subprocess.run(["lsappinfo", "front"], capture_output=True, text=True)
    info = subprocess.run(
        ["lsappinfo", "info", "-only", "bundleid", front.stdout.strip()],
        capture_output=True,
        text=True,
    )
    return ORCA_BUNDLE_ID in info.stdout


def focused_worktree():
    worktrees = orca_cli("worktree", "ps")["worktrees"]
    active = next((w for w in worktrees if w.get("isActive")), None)
    if active is None:
        fail("Orca has no active workspace")
    return active


def focused_pane(worktree_id):
    result = rpc("session.tabs.list", {"worktree": worktree_id})
    pane = next((tab for tab in result.get("tabs", [])
                 if tab.get("id") == result.get("activeTabId")), None)
    if not pane or pane.get("type") != "terminal" or not pane.get("terminal"):
        fail("Focus an Orca agent terminal first")
    return pane


def pane_agent(handle):
    """(is_running, vault agent name | None), all through Orca's own detection."""
    status_result = rpc("terminal.agentStatus", {"terminal": handle}, fatal=False)
    status = (status_result or {}).get("agentStatus") or {}
    if not status.get("isRunningAgent"):
        return False, None
    process_result = rpc("terminal.inspectProcess", {"terminal": handle}, fatal=False)
    process = (process_result or {}).get("process") or {}
    name = os.path.basename(process.get("foregroundProcess") or "").lower()
    name = name.removesuffix(".exe")
    if not name or name in GENERIC_PROCESSES:
        return True, None
    return True, VAULT_AGENT_BY_PROCESS.get(name, name)


def vault_session(agent, worktree_path, provider_session):
    sessions = rpc(
        "aiVault.listSessions",
        {"scopePaths": [worktree_path], "force": True, "unlimited": True},
        timeout=60,
    )["sessions"]
    root = worktree_path.rstrip("/")

    def in_worktree(s):
        cwd = (s.get("cwd") or "").rstrip("/")
        return cwd == root or cwd.startswith(root + "/")

    matches = [
        s
        for s in sessions
        if not s.get("subagent")
        and s.get("executionHostId", "local") == "local"
        and s.get("agent") == agent
        and in_worktree(s)
    ]
    sid = provider_session.get("id")
    transcript = provider_session.get("transcriptPath")
    if sid or transcript:
        matches = [s for s in matches
                   if (not sid or s.get("sessionId") == sid)
                   and (not transcript or s.get("filePath") == transcript)]
        if len(matches) != 1:
            fail(f"The focused {agent} session could not be identified in the local vault")
        return matches[0]
    exact = [s for s in matches if (s.get("cwd") or "").rstrip("/") == root]
    scoped = exact or matches
    if not scoped:
        return None
    if len(scoped) != 1:
        fail(f"Orca has not identified the focused {agent} session; {len(scoped)} sessions match")
    return scoped[0]


def agentsview_base_url():
    """Base URL of the agentsview server, or None when the daemon is down.

    Deliberately does not start the daemon — its lifecycle belongs to the
    AgentsView app's sidecar (or an explicit `agentsview serve --background`),
    not a hotkey. Re-read on every run: `serve status` exits 0 whether or not
    a server runs, the URL in its output is the liveness signal, and the port
    changes across daemon restarts.

    Raycast does not read shell startup files, so a host that links
    ~/.agentsview to another volume passes the resolved directory explicitly:
    through the symlink, status finds no daemon.
    """
    env = dict(os.environ)
    data_dir = os.path.expanduser("~/.agentsview")
    if os.path.islink(data_dir):
        env.setdefault("AGENTSVIEW_DATA_DIR", os.path.realpath(data_dir))
    try:
        proc = subprocess.run(
            ["agentsview", "serve", "status"], capture_output=True, text=True, env=env
        )
    except FileNotFoundError:
        return None
    match = re.search(r"https?://\S+", proc.stdout)
    if proc.returncode != 0 or not match:
        return None
    return match.group(0).rstrip("/")


def fork_argv(agent, session):
    """Native forks only: resuming the source would create a second writer."""
    sid = session["sessionId"]
    if agent == "claude":
        return ["claude", "--dangerously-skip-permissions", "--resume", sid, "--fork-session"]
    if agent == "codex":
        home = session.get("codexHome") or os.path.expanduser("~/.codex")
        return ["env", f"CODEX_HOME={home}", "codex", "--dangerously-bypass-approvals-and-sandbox", "fork", sid]
    if agent in {"pi", "omp"}:
        return [agent, "--fork", session.get("filePath") or sid]
    if agent == "droid":
        return ["droid", "--fork", sid]
    return None


def reveal_in_agentsview(session_id):
    """Open the session, preferring the AgentsView app over a browser.

    AgentsView v0.41.1 registers no URL scheme and its Tauri shell always
    loads the webview at the server root, so the desktop app cannot be
    deep-linked yet (verified against the installed bundle and the v0.41.1 /
    main source). Probe the agentsview:// scheme anyway — `open` fails
    quietly when no handler exists — so the app takes over automatically
    once deep-link support lands, and fall back to the web UI until then.
    """
    quoted = urllib.parse.quote(session_id, safe="")
    scheme_open = subprocess.run(
        ["open", f"agentsview://sessions/{quoted}"], capture_output=True
    )
    if scheme_open.returncode == 0:
        return "AgentsView app"
    base_url = agentsview_base_url()
    if base_url is None:
        return None
    browser_open = subprocess.run(["open", f"{base_url}/sessions/{quoted}"])
    return "agentsview (browser)" if browser_open.returncode == 0 else None


def main():
    global JSON_MODE
    parser = argparse.ArgumentParser(
        description="Resolve the agent session in Orca's focused terminal."
    )
    parser.add_argument("--json", action="store_true", help="print JSON; skip gate, copy, and open")
    parser.add_argument("--copy", action="store_true", help="copy the session ID via pbcopy")
    parser.add_argument("--agent-only", action="store_true", help="identify the focused agent without looking up its session")
    parser.add_argument("--list-agents", action="store_true", help="list agents detected by the local Orca runtime")
    parser.add_argument("--fork", action="store_true", help="fork the session into a new split instead of revealing it")
    parser.add_argument("--dry-run", action="store_true", help="with --fork: print the plan without splitting")
    parser.add_argument("--worktree", help="workspace path (default: Orca's focused workspace)")
    args = parser.parse_args()
    JSON_MODE = args.json

    if args.list_agents:
        agents = rpc("preflight.detectAgents", {})
        if not isinstance(agents, list) or any(not isinstance(agent, str) for agent in agents):
            fail("Orca returned an invalid agent list")
        print(json.dumps({"agents": agents}) if args.json else "\n".join(agents))
        return

    hud_mode = not args.json
    if hud_mode and not args.worktree and not frontmost_is_orca():
        fail("Not in Orca", benign=True)

    if args.worktree:
        path = os.path.abspath(os.path.expanduser(args.worktree))
        worktrees = orca_cli("worktree", "ps")["worktrees"]
        active = next((w for w in worktrees if w.get("path") == path), None)
        if active is None:
            fail(f"No Orca workspace found for {path}")
    else:
        active = focused_worktree()

    pane = focused_pane(active["worktreeId"])
    running, agent = pane_agent(pane["terminal"])
    if not running:
        fail("No agent running in the focused terminal")
    status = pane.get("agentStatus") or {}
    reported_agent = status.get("agentType") or pane.get("launchAgent")
    if agent is None:
        agent = reported_agent
    if not agent:
        fail("Could not identify the agent in the focused terminal")
    if args.agent_only:
        print(json.dumps({"agent": agent}) if args.json else agent)
        return
    provider_session = status.get("providerSession") or {}
    if status.get("agentType") != agent:
        provider_session = {}

    session = vault_session(agent, active["path"], provider_session)
    if session is None:
        fail(f"Agent {agent or '(unknown)'} is running but no session found on disk yet")

    session_id = session["sessionId"]

    copied = False
    if args.copy or hud_mode:
        copied = subprocess.run(["pbcopy"], input=session_id, text=True).returncode == 0

    if args.fork:
        agent_name = session.get("agent")
        argv = fork_argv(agent_name, session)
        if argv is None:
            fail(
                f"{agent_name} can't fork a live session safely — "
                f"ID {'copied' if copied else session_id[:8]} for manual resume"
            )
        command = f"cd {shlex.quote(session.get('cwd') or active['path'])} && {shlex.join(argv)}"
        if args.dry_run:
            print(json.dumps({"agent": agent_name, "sessionId": session_id, "forkCommand": command})
                  if args.json else f"would fork {agent_name} {session_id[:8]}: {command}")
            return
        split = orca_cli(
            "terminal", "split", "--terminal", pane["terminal"], "--command", command
        )
        new_handle = (split.get("terminal") or split.get("split") or {}).get("handle") if isinstance(split, dict) else None
        if args.json:
            print(json.dumps({
                "agent": agent_name,
                "sessionId": session_id,
                "forkCommand": command,
                "newTerminal": new_handle,
            }))
        else:
            print(f"forked {agent_name} {session_id[:8]} → new split")
        return

    if hud_mode:
        target = reveal_in_agentsview(session_id)
        copy_note = "ID copied" if copied else "copy failed"
        if target:
            print(f"{session.get('agent')} {session_id[:8]} → {target} ({copy_note})")
        else:
            print(
                f"{session.get('agent')} {session_id[:8]} — agentsview not running; "
                f"launch AgentsView ({copy_note})"
            )
        return

    base_url = agentsview_base_url()
    print(
        json.dumps(
            {
                "agent": session.get("agent"),
                "sessionId": session_id,
                "title": session.get("title"),
                "cwd": session.get("cwd"),
                "worktree": active["path"],
                "terminalTitle": pane.get("title"),
                "terminalIsFocusedPane": True,
                "filePath": session.get("filePath"),
                "resumeCommand": session.get("resumeCommand"),
                "agentsviewUrl": (
                    f"{base_url}/sessions/{urllib.parse.quote(session_id, safe='')}"
                    if base_url
                    else None
                ),
            }
        )
    )


if __name__ == "__main__":
    main()
