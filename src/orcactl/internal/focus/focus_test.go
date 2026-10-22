package focus

import (
	"strings"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

func workspaces(active string) runtimetest.Handler {
	return runtimetest.Fixed(map[string]any{"worktrees": []map[string]any{
		{"worktreeId": "repo::/other", "path": "/other", "isActive": active == "/other", "hostId": "local"},
		{"worktreeId": "repo::/project", "path": "/project", "isActive": active == "/project", "hostId": "local"},
	}})
}

// Three splits in one tab plus a second tab; Orca reports focus per leaf.
func tabs(active string) runtimetest.Handler {
	return runtimetest.Fixed(map[string]any{"activeTabId": active, "tabs": []map[string]any{
		{"id": "tab-1::leaf-a", "type": "terminal", "terminal": "term-a", "parentTabId": "tab-1"},
		{"id": "tab-1::leaf-b", "type": "terminal", "terminal": "term-b", "parentTabId": "tab-1"},
		{"id": "tab-1::leaf-c", "type": "terminal", "terminal": "term-c", "parentTabId": "tab-1"},
		{"id": "tab-2::leaf-d", "type": "terminal", "terminal": "term-d", "parentTabId": "tab-2"},
		{"id": "browser", "type": "browser"},
	}})
}

func shown(connected bool, host string) runtimetest.Handler {
	return runtimetest.Fixed(map[string]any{"terminal": map[string]any{"connected": connected, "executionHostId": host}})
}

func TestCaptureSelectsTheFocusedSplitBeforeProbingIt(t *testing.T) {
	for _, leaf := range []string{"tab-1::leaf-a", "tab-1::leaf-b", "tab-1::leaf-c", "tab-2::leaf-d"} {
		server := runtimetest.New(t, map[string]runtimetest.Handler{
			"worktree.ps": workspaces("/project"), "session.tabs.list": tabs(leaf), "terminal.show": shown(true, "local"),
		})
		got, err := Capture(server.Socket, "", "")
		if err != nil {
			t.Fatal(err)
		}
		want := "term-" + leaf[len(leaf)-1:]
		if got.Pane.Terminal != want || got.Worktree.Path != "/project" || got.Host != "local" {
			t.Errorf("leaf %s: got %+v", leaf, got)
		}
		calls := server.Calls()
		if strings.Join(server.Methods(), ",") != "worktree.ps,session.tabs.list,terminal.show" {
			t.Errorf("call order %v", server.Methods())
		}
		if calls[1].Params["worktree"] != "repo::/project" || calls[2].Params["terminal"] != want {
			t.Errorf("focus calls not keyed by the captured workspace and pane: %+v", calls)
		}
	}
}

func TestCaptureRefusals(t *testing.T) {
	for _, tc := range []struct {
		name     string
		handlers map[string]runtimetest.Handler
		path     string
		want     string
	}{
		{"no active workspace", map[string]runtimetest.Handler{"worktree.ps": workspaces("")}, "", "no active workspace"},
		{"unknown path", map[string]runtimetest.Handler{"worktree.ps": workspaces("/project")}, "/missing", "No Orca workspace found for /missing"},
		{"browser focused", map[string]runtimetest.Handler{"worktree.ps": workspaces("/project"), "session.tabs.list": tabs("browser")}, "", "Focus an Orca agent terminal first"},
		{"disconnected terminal", map[string]runtimetest.Handler{"worktree.ps": workspaces("/project"), "session.tabs.list": tabs("tab-1::leaf-a"), "terminal.show": shown(false, "local")}, "", "disconnected"},
		{"invalid host", map[string]runtimetest.Handler{"worktree.ps": workspaces("/project"), "session.tabs.list": tabs("tab-1::leaf-a"), "terminal.show": shown(true, "ssh:bad|host")}, "", "invalid execution host"},
		{"ssh host down", map[string]runtimetest.Handler{"worktree.ps": workspaces("/project"), "session.tabs.list": tabs("tab-1::leaf-a"), "terminal.show": shown(true, "ssh:box"),
			"ssh.getState": runtimetest.Fixed(map[string]any{"state": map[string]any{"status": "disconnected"}})}, "", "SSH host is disconnected"},
	} {
		server := runtimetest.New(t, tc.handlers)
		if _, err := Capture(server.Socket, tc.path, ""); err == nil || !strings.Contains(err.Error(), tc.want) {
			t.Errorf("%s: got %v, want %q", tc.name, err, tc.want)
		}
	}
}

func TestExplicitWorkspacePath(t *testing.T) {
	server := runtimetest.New(t, map[string]runtimetest.Handler{
		"worktree.ps": workspaces("/project"), "session.tabs.list": tabs("tab-2::leaf-d"), "terminal.show": shown(true, "local"),
	})
	got, err := Capture(server.Socket, "/other", "")
	if err != nil || got.Worktree.Path != "/other" {
		t.Fatalf("got %+v, %v", got, err)
	}
}

func TestHostRouting(t *testing.T) {
	for _, tc := range []struct{ host, selected, want string }{
		{"local", "", "local"},
		{"local", "paired-env", "runtime:paired-env"},
		{"", "", "local"}, // falls back to the workspace host
		{"ssh:box%20one", "", "ssh:box%20one"},
	} {
		server := runtimetest.New(t, map[string]runtimetest.Handler{
			"terminal.show": shown(true, tc.host),
			"ssh.getState": func(params map[string]any) runtimetest.Reply {
				if params["targetId"] != "box one" {
					t.Errorf("ssh target not unescaped: %v", params)
				}
				return runtimetest.Reply{Result: map[string]any{"state": map[string]any{"status": "connected"}}}
			},
		})
		got, err := Host(server.Socket, Pane{Terminal: "term-a"}, Worktree{HostID: "local"}, tc.selected)
		if err != nil || got != tc.want {
			t.Errorf("host %q selected %q: got %q, %v; want %q", tc.host, tc.selected, got, err, tc.want)
		}
	}
}

func TestMalformedSSHTargetIsQueriedLiterally(t *testing.T) {
	server := runtimetest.New(t, map[string]runtimetest.Handler{
		"terminal.show": shown(true, "ssh:host%zz"),
		"ssh.getState": func(params map[string]any) runtimetest.Reply {
			if params["targetId"] != "host%zz" {
				t.Errorf("target rewritten: %v", params)
			}
			return runtimetest.Reply{Result: map[string]any{"state": map[string]any{"status": "connected"}}}
		},
	})
	if got, err := Host(server.Socket, Pane{Terminal: "term-a"}, Worktree{}, ""); err != nil || got != "ssh:host%zz" {
		t.Fatalf("got %q, %v", got, err)
	}
}
