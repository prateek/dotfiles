package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

// orca is a configurable fake of the Orca runtime around one focused pane.
type orca struct {
	process      string
	running      bool
	connected    bool
	sshConnected bool
	terminalHost string
	worktreeHost string
	environment  string
	agentStatus  map[string]any
	launchAgent  string
	sessions     []map[string]any
	extraTabs    []map[string]any
	server       *runtimetest.Server
}

func newOrca() *orca {
	return &orca{process: "claude", running: true, connected: true, sshConnected: true,
		sessions: []map[string]any{vaultSession("claude", "source", nil)}}
}

func vaultSession(agent, id string, extra map[string]any) map[string]any {
	s := map[string]any{"agent": agent, "sessionId": id, "cwd": "/project",
		"filePath": "/store/" + id + ".jsonl", "updatedAt": "2026-09-01T00:00:00Z", "executionHostId": "local"}
	for k, v := range extra {
		s[k] = v
	}
	return s
}

func (o *orca) start(t *testing.T) {
	t.Helper()
	pane := map[string]any{"id": "tab::leaf", "type": "terminal", "terminal": "focused", "title": "agent"}
	if o.agentStatus != nil {
		pane["agentStatus"] = o.agentStatus
	}
	if o.launchAgent != "" {
		pane["launchAgent"] = o.launchAgent
	}
	worktree := map[string]any{"worktreeId": "repo::/project", "path": "/project", "isActive": true, "hostId": "local"}
	if o.worktreeHost != "" {
		worktree["hostId"] = o.worktreeHost
	}
	o.server = runtimetest.New(t, map[string]runtimetest.Handler{
		"worktree.ps": runtimetest.Fixed(map[string]any{"worktrees": []any{worktree}}),
		"session.tabs.list": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Result: map[string]any{"activeTabId": "tab::leaf", "tabs": append([]map[string]any{pane}, o.extraTabs...)}}
		},
		"terminal.show": func(map[string]any) runtimetest.Reply {
			terminal := map[string]any{"connected": o.connected}
			if o.terminalHost != "" {
				terminal["executionHostId"] = o.terminalHost
			}
			return runtimetest.Reply{Result: map[string]any{"terminal": terminal}}
		},
		"ssh.getState": func(map[string]any) runtimetest.Reply {
			status := "disconnected"
			if o.sshConnected {
				status = "connected"
			}
			return runtimetest.Reply{Result: map[string]any{"state": map[string]any{"status": status}}}
		},
		"terminal.agentStatus": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Result: map[string]any{"agentStatus": map[string]any{"isRunningAgent": o.running}}}
		},
		"terminal.inspectProcess": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Result: map[string]any{"process": map[string]any{"foregroundProcess": o.process}}}
		},
		"aiVault.listSessions": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Result: map[string]any{"sessions": o.sessions}}
		},
		"terminal.split":         runtimetest.Fixed(map[string]any{"split": map[string]any{"handle": "forked"}}),
		"preflight.detectAgents": runtimetest.Fixed([]string{"claude", "codex", "pi", "omp"}),
	})
	orcaUserData(t, o.server, map[string]any{"activeRuntimeEnvironmentId": o.environment})
	// Paired servers are reached through Orca's packaged client; route every
	// environment to the fake so the selection logic is what's under test.
	previous := connect
	connect = func(string, string) (runtime.Caller, error) { return o.server.Socket, nil }
	t.Cleanup(func() { connect = previous })
}

func (o *orca) run(t *testing.T, args ...string) (int, map[string]any) {
	t.Helper()
	o.start(t)
	var buf bytes.Buffer
	previous := stdout
	stdout = &buf
	defer func() { stdout = previous }()
	code := run(append(args, "--json"))
	var out map[string]any
	if err := json.Unmarshal(buf.Bytes(), &out); err != nil {
		t.Fatalf("invalid JSON %q: %v", buf.String(), err)
	}
	return code, out
}

func (o *orca) called(method string) bool {
	for _, m := range o.server.Methods() {
		if m == method {
			return true
		}
	}
	return false
}

func (o *orca) splitParams(t *testing.T) map[string]any {
	for _, call := range o.server.Calls() {
		if call.Method == "terminal.split" {
			return call.Params
		}
	}
	t.Fatal("no split")
	return nil
}

func TestForkCommandsUseNativeForkAndExplicitSource(t *testing.T) {
	for agent, want := range map[string]string{
		"claude": "claude --dangerously-skip-permissions --resume source --fork-session",
		"codex":  "env 'CODEX_HOME=/account home' codex --dangerously-bypass-approvals-and-sandbox fork source",
		"pi":     "pi --fork /store/source.jsonl",
		"omp":    "omp --fork /store/source.jsonl",
		"droid":  "droid --fork source",
	} {
		o := newOrca()
		o.process = agent
		extra := map[string]any{}
		if agent == "codex" {
			extra["codexHome"] = "/account home"
		}
		o.sessions = []map[string]any{vaultSession(agent, "source", extra)}
		code, out := o.run(t, "ses", "fork")
		command := "cd /project && " + want
		if code != 0 || out["forkCommand"] != command || out["newTerminal"] != "forked" {
			t.Errorf("%s: %d %v", agent, code, out)
			continue
		}
		if params := o.splitParams(t); params["terminal"] != "focused" || params["command"] != command {
			t.Errorf("%s: split %v", agent, params)
		}
	}
}

func TestCodexDefaultHomeIgnoresOrcasAccountHome(t *testing.T) {
	t.Setenv("CODEX_HOME", "/wrong-account")
	home, _ := os.UserHomeDir()
	o := newOrca()
	o.process = "codex"
	o.sessions = []map[string]any{vaultSession("codex", "source", nil)}
	code, out := o.run(t, "ses", "fork", "--dry-run")
	if code != 0 || !strings.Contains(out["forkCommand"].(string), "CODEX_HOME="+filepath.Join(home, ".codex")) || o.called("terminal.split") {
		t.Fatalf("%d %v", code, out)
	}
}

func TestPiSessionIsFoundBeyondAGlobalVaultLimit(t *testing.T) {
	o := newOrca()
	o.process = "pi"
	o.sessions = nil
	for i := 0; i < 100; i++ {
		o.sessions = append(o.sessions, vaultSession("codex", fmt.Sprint(i), map[string]any{"cwd": "/elsewhere"}))
	}
	o.sessions = append(o.sessions, vaultSession("pi", "source", nil))
	code, out := o.run(t, "ses", "fork", "--dry-run")
	if code != 0 || out["agent"] != "pi" {
		t.Fatalf("%d %v", code, out)
	}
	for _, call := range o.server.Calls() {
		if call.Method == "aiVault.listSessions" && (call.Params["unlimited"] != true || call.Params["force"] != true) {
			t.Fatalf("vault scan was limited: %v", call.Params)
		}
	}
}

func TestFocusedBindingWinsOverTheNewestSession(t *testing.T) {
	for _, args := range [][]string{{"ses", "reveal"}, {"ses", "fork", "--dry-run"}} {
		o := newOrca()
		o.process = "pi"
		o.agentStatus = map[string]any{"agentType": "pi", "providerSession": map[string]any{"id": "source", "transcriptPath": "/store/source.jsonl"}}
		o.sessions = []map[string]any{vaultSession("pi", "other", map[string]any{"updatedAt": "2026-09-26T00:00:00Z"}), vaultSession("pi", "source", nil)}
		if code, out := o.run(t, args...); code != 0 || out["sessionId"] != "source" {
			t.Errorf("%v: %d %v", args, code, out)
		}
	}
}

// Every refusal must leave Orca's layout untouched.
func TestRefusalsNeverSplit(t *testing.T) {
	for _, tc := range []struct {
		name  string
		setup func(*orca)
		want  string
	}{
		{"ambiguous sessions need the pane's identity", func(o *orca) { o.sessions = append(o.sessions, vaultSession("claude", "other", nil)) }, "session"},
		{"a missing bound session has no fallback", func(o *orca) {
			o.agentStatus = map[string]any{"agentType": "claude", "providerSession": map[string]any{"id": "missing"}}
		}, "could not be identified"},
		{"a remote copy never serves a local pane", func(o *orca) {
			o.sessions = []map[string]any{vaultSession("claude", "source", map[string]any{"executionHostId": "ssh:other"})}
		}, "no session found"},
		{"an unbound remote pane never uses a local session", func(o *orca) { o.terminalHost = "ssh:devbox" }, "no local fallback"},
		{"remote codex needs account evidence", func(o *orca) {
			o.process, o.terminalHost = "codex", "ssh:devbox"
			o.agentStatus = map[string]any{"agentType": "codex", "providerSession": map[string]any{"id": "remote"}}
		}, "account home"},
		{"a disconnected pane keeps no hook identity", func(o *orca) { o.connected = false }, "disconnected"},
		{"a disconnected SSH host overrides the terminal flag", func(o *orca) {
			o.terminalHost, o.sshConnected = "ssh:devbox", false
			o.agentStatus = map[string]any{"agentType": "claude", "providerSession": map[string]any{"id": "remote"}}
		}, "disconnected"},
		{"an agent without native fork never resumes", func(o *orca) {
			o.process = "gemini"
			o.sessions = []map[string]any{vaultSession("gemini", "source", nil)}
		}, "can't fork"},
		{"a focused shell never selects a hidden agent", func(o *orca) {
			o.running = false
			o.extraTabs = []map[string]any{{"id": "other::leaf", "type": "terminal", "terminal": "hidden"}}
		}, "focused terminal"},
	} {
		o := newOrca()
		tc.setup(o)
		code, out := o.run(t, "ses", "fork")
		message, _ := out["error"].(string)
		if code == 0 || !strings.Contains(message, tc.want) || o.called("terminal.split") {
			t.Errorf("%s: %d %v", tc.name, code, out)
		}
	}
}

func TestRemoteBoundSessionsSkipTheLocalVault(t *testing.T) {
	for _, host := range []string{"ssh:devbox", "runtime:server"} {
		o := newOrca()
		o.worktreeHost = host
		o.agentStatus = map[string]any{"agentType": "claude", "providerSession": map[string]any{"id": "remote-source", "transcriptPath": "/remote/source.jsonl"}}
		code, out := o.run(t, "ses", "fork", "--dry-run")
		if code != 0 || out["sessionId"] != "remote-source" || out["executionHostId"] != host || o.called("aiVault.listSessions") {
			t.Errorf("%s: %d %v", host, code, out)
		}
	}
}

func TestSelectedPairedServerOwnsItsTerminalAndSession(t *testing.T) {
	o := newOrca()
	o.environment, o.terminalHost = "server", "local"
	o.agentStatus = map[string]any{"agentType": "claude", "providerSession": map[string]any{"id": "paired-source"}}
	code, out := o.run(t, "ses", "fork", "--dry-run")
	if code != 0 || out["sessionId"] != "paired-source" || out["executionHostId"] != "runtime:server" || o.called("aiVault.listSessions") {
		t.Fatalf("%d %v", code, out)
	}
}

func TestRemoteCursorResolvesButRefusesToFork(t *testing.T) {
	setup := func() *orca {
		o := newOrca()
		o.process, o.terminalHost = "cursor-agent", "ssh:devbox"
		o.agentStatus = map[string]any{"agentType": "cursor", "providerSession": map[string]any{"id": "cursor-source"}}
		return o
	}
	if code, out := setup().run(t, "ses", "reveal"); code != 0 || out["agent"] != "cursor" || out["sessionId"] != "cursor-source" {
		t.Fatalf("reveal: %d %v", code, out)
	}
	o := setup()
	code, out := o.run(t, "ses", "fork")
	if message, _ := out["error"].(string); code == 0 || !strings.Contains(message, "can't fork") || o.called("terminal.split") {
		t.Fatalf("fork: %d %v", code, out)
	}
}

func TestRemoteCodexForkKeepsItsAccountHome(t *testing.T) {
	t.Setenv("CODEX_HOME", "/wrong-local-account")
	o := newOrca()
	o.process, o.terminalHost = "codex", "runtime:server"
	o.agentStatus = map[string]any{"agentType": "codex", "providerSession": map[string]any{
		"id": "remote", "transcriptPath": "/remote/account home/sessions/2026/10/07/rollout.jsonl"}}
	code, out := o.run(t, "ses", "fork", "--dry-run")
	if code != 0 || !strings.Contains(out["forkCommand"].(string), "'CODEX_HOME=/remote/account home'") {
		t.Fatalf("%d %v", code, out)
	}
}

func TestAgentCatalogNeedsNoWorkspace(t *testing.T) {
	o := newOrca()
	code, out := o.run(t, "agents")
	if code != 0 || fmt.Sprint(out["agents"]) != "[claude codex pi omp]" || strings.Join(o.server.Methods(), ",") != "preflight.detectAgents" {
		t.Fatalf("%d %v %v", code, out, o.server.Methods())
	}
}

func TestShellQuoteMatchesPythonShlex(t *testing.T) {
	for in, want := range map[string]string{
		"":             "''",
		"/project":     "/project",
		"a b":          "'a b'",
		"it's":         `'it'"'"'s'`,
		"CODEX_HOME=x": "CODEX_HOME=x",
		"--fork":       "--fork",
		"$HOME":        "'$HOME'",
	} {
		if got := shellQuote(in); got != want {
			t.Errorf("%q: got %s, want %s", in, got, want)
		}
	}
}
