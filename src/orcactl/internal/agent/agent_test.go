package agent

import (
	"errors"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/focus"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

func probes(running bool, foreground string) map[string]runtimetest.Handler {
	return map[string]runtimetest.Handler{
		"terminal.agentStatus":    runtimetest.Fixed(map[string]any{"agentStatus": map[string]any{"isRunningAgent": running}}),
		"terminal.inspectProcess": runtimetest.Fixed(map[string]any{"process": map[string]any{"foregroundProcess": foreground}}),
	}
}

func TestProcessAgent(t *testing.T) {
	for foreground, want := range map[string]string{
		"claude": "claude",
		"/Users/me/.local/share/claude/versions/2.1.308": "claude",
		"cursor-agent":   "cursor",
		"/usr/bin/zsh":   "",
		"node":           "",
		"codex.exe":      "codex",
		"Pi":             "pi",
		"":               "",
		"2.1.308-beta.1": "2.1.308-beta.1",
	} {
		if got := ProcessAgent(foreground); got != want {
			t.Errorf("%q: got %q, want %q", foreground, got, want)
		}
	}
}

func TestIdentify(t *testing.T) {
	bound := func(agentType, id string) *focus.AgentStatus {
		return &focus.AgentStatus{AgentType: agentType, ProviderSession: focus.ProviderSession{ID: id}}
	}
	for _, tc := range []struct {
		name        string
		running     bool
		foreground  string
		pane        focus.Pane
		wantAgent   string
		wantSession string
		wantErr     error
	}{
		{"process names the agent and keeps its binding", true, "pi", focus.Pane{AgentStatus: bound("pi", "source")}, "pi", "source", nil},
		{"node falls back to the launch agent", true, "node", focus.Pane{LaunchAgent: "pi"}, "pi", "", nil},
		{"native Claude keeps its own binding", true, "/x/claude/versions/2.1.308", focus.Pane{AgentStatus: bound("claude", "source")}, "claude", "source", nil},
		{"native Claude drops a previous agent's binding", true, "/x/claude/versions/2.1.308", focus.Pane{AgentStatus: bound("codex", "old-codex")}, "claude", "", nil},
		{"a shell with no record is unidentified", true, "zsh", focus.Pane{}, "", "", ErrUnidentified},
		{"no running agent", false, "claude", focus.Pane{}, "", "", ErrNotRunning},
	} {
		tc.pane.Terminal = "term-a"
		server := runtimetest.New(t, probes(tc.running, tc.foreground))
		got, err := Identify(server.Socket, tc.pane)
		if !errors.Is(err, tc.wantErr) || got.Agent != tc.wantAgent || got.ProviderSession.ID != tc.wantSession {
			t.Errorf("%s: got %+v, %v", tc.name, got, err)
		}
	}
}

func TestIdentifyToleratesAHalfDeadPane(t *testing.T) {
	server := runtimetest.New(t, map[string]runtimetest.Handler{
		"terminal.agentStatus": runtimetest.Fixed(map[string]any{"agentStatus": map[string]any{"isRunningAgent": true}}),
		"terminal.inspectProcess": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Code: "terminal_gone", Message: "gone"}
		},
	})
	got, err := Identify(server.Socket, focus.Pane{Terminal: "term-a", LaunchAgent: "claude"})
	if err != nil || got.Agent != "claude" {
		t.Fatalf("got %+v, %v", got, err)
	}
}
