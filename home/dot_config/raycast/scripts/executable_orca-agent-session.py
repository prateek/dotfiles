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
# Resolution pipeline, most of it through Orca itself so agent CLIs never
# need to be hardcoded here:
#   1. focused workspace   `orca worktree ps --json` (public CLI, isActive)
#   2. focused pane        `orca terminal list --include-visual-layouts` (public CLI)
#   3. agent detection     terminal.agentStatus + terminal.inspectProcess
#                          (runtime RPC), with session.tabs.list launchAgent
#                          as fallback when the foreground is transiently a
#                          shell
#   4. session lookup      aiVault.listSessions (runtime RPC), Orca's own
#                          cross-agent session scanner, filtered to the pane's
#                          agent + the workspace path, newest first
#
# Steps 3-4 use undocumented runtime RPCs over the same unix-socket envelope
# the `orca` CLI uses (orca-runtime.json). Public alternatives exist for
# detection but are worse fits: `terminal wait --for tui-idle` blocks and
# can't distinguish a busy agent from no agent, and `diagnostics memory`'s
# pane->pid bridge requires walking the process tree against a hand-kept
# agent-binary list. Provider session IDs have no public surface at all in
# 1.4.187 (deliberate: the orchestration guide forbids even guessing them).
# So these four methods are the accepted private dependency; they fail
# loudly if a future Orca drifts.

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
# shells mean "no agent process in the foreground".
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
SHELL_PROCESSES = {"zsh", "bash", "fish", "sh", "login", "nu", "tcsh"}

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


def candidate_panes(worktree_id):
    """Terminal panes of the workspace, UI-focused pane first."""
    result = orca_cli(
        "terminal", "list", "--worktree", f"id:{worktree_id}", "--include-visual-layouts"
    )
    layouts = [
        l for l in result.get("visualLayouts", []) if l.get("worktreeId") == worktree_id
    ]
    ranked = []

    def collect_panes(node, bucket):
        if not isinstance(node, dict):
            return
        if node.get("type") == "terminal" and node.get("handle"):
            bucket.append(node)
            return
        # pane-split nodes hold their two halves under first/second;
        # children/panes covers group-style containers.
        for child in [node.get("first"), node.get("second")]:
            collect_panes(child, bucket)
        for child in node.get("children") or node.get("panes") or []:
            collect_panes(child, bucket)

    def walk_group(node):
        if not isinstance(node, dict) or node.get("type") != "group":
            return
        for tab in node.get("tabs", []):
            panes = []
            collect_panes(tab.get("panes"), panes)
            is_active_tab = tab.get("tabId") == node.get("activeTabId")
            for pane in panes:
                active_leaf = tab.get("activeLeafId")
                is_active_pane = bool(pane.get("active")) or (
                    active_leaf is not None and pane.get("leafId") == active_leaf
                )
                # Every pane in the visible tab outranks hidden tabs' panes.
                rank = (0 if is_active_pane else 1) if is_active_tab else (2 if is_active_pane else 3)
                ranked.append((rank, pane, is_active_tab and is_active_pane))
        for child in node.get("children", []):
            walk_group(child)

    for layout in layouts:
        walk_group(layout.get("root"))
    if not ranked:
        fail("The focused Orca workspace has no terminals")
    ranked.sort(key=lambda entry: entry[0])
    return [(pane, focused) for _, pane, focused in ranked]


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
    if not name or name in SHELL_PROCESSES:
        return True, None
    return True, VAULT_AGENT_BY_PROCESS.get(name, name)


def launch_agent(worktree_id, pane):
    """Agent identity from the tab's launcher, for when the pane's foreground
    process is transiently a shell (e.g. the agent is mid-tool-execution).
    Without this the vault lookup would silently cross agents in workspaces
    running more than one."""
    tabs = (rpc("session.tabs.list", {"worktree": worktree_id}, fatal=False) or {}).get("tabs", [])
    for tab in tabs:
        if (
            tab.get("type") == "terminal"
            and tab.get("parentTabId") == pane.get("tabId")
            and tab.get("leafId") == pane.get("leafId")
        ):
            return tab.get("launchAgent")
    return None


def vault_session(agent, worktree_path):
    """Newest AI-vault session for the workspace, filtered to agent when known."""
    sessions = rpc(
        "aiVault.listSessions",
        {"scopePaths": [worktree_path], "force": True, "limit": 100},
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
        and (agent is None or s.get("agent") == agent)
        and in_worktree(s)
    ]
    exact = [s for s in matches if (s.get("cwd") or "").rstrip("/") == root]
    scoped = exact or matches
    if not scoped:
        return None
    return max(scoped, key=lambda s: s.get("updatedAt") or "")


def agentsview_base_url():
    """Base URL of the agentsview server, or None when the daemon is down.

    Deliberately does not start the daemon — its lifecycle belongs to the
    AgentsView app's sidecar (or an explicit `agentsview serve --background`),
    not a hotkey. Re-read on every run: `serve status` exits 0 whether or not
    a server runs, the URL in its output is the liveness signal, and the port
    changes across daemon restarts.
    """
    try:
        proc = subprocess.run(
            ["agentsview", "serve", "status"], capture_output=True, text=True
        )
    except FileNotFoundError:
        return None
    match = re.search(r"https?://\S+", proc.stdout)
    if proc.returncode != 0 or not match:
        return None
    return match.group(0).rstrip("/")


def fork_argv(agent, session):
    """Command to continue a fork of the session in a fresh pane, or None
    when the agent has no fork semantics. Verified against installed CLI
    help: claude --fork-session, `codex fork`, pi --fork, droid --fork.
    cursor-agent and gemini can only resume the same session — spawning a
    second writer — so they are deliberately unsupported. The permissive
    flags mirror the yolo/yoloc aliases; spelled out because zsh functions
    don't resolve in a spawned pane.
    """
    sid = session["sessionId"]
    if agent == "claude":
        return ["claude", "--dangerously-skip-permissions", "--resume", sid, "--fork-session"]
    if agent == "codex":
        return ["codex", "--dangerously-bypass-approvals-and-sandbox", "fork", sid]
    if agent == "pi":
        return ["pi", "--fork", session.get("filePath") or sid]
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
    parser.add_argument("--fork", action="store_true", help="fork the session into a new split instead of revealing it")
    parser.add_argument("--dry-run", action="store_true", help="with --fork: print the plan without splitting")
    parser.add_argument("--worktree", help="workspace path (default: Orca's focused workspace)")
    args = parser.parse_args()
    JSON_MODE = args.json

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

    agent = None
    chosen = None
    for pane, focused in candidate_panes(active["worktreeId"]):
        running, pane_agent_name = pane_agent(pane["handle"])
        if running:
            if pane_agent_name is None:
                pane_agent_name = launch_agent(active["worktreeId"], pane)
            agent, chosen = pane_agent_name, (pane, focused)
            break
    if chosen is None:
        fail("No agent running in the focused workspace's terminals")

    session = vault_session(agent, active["path"])
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
            "terminal", "split", "--terminal", chosen[0]["handle"], "--command", command
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
                "terminalTitle": chosen[0].get("title"),
                "terminalIsFocusedPane": chosen[1],
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
