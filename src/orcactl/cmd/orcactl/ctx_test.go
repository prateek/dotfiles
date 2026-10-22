package main

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

// orcaUserData lays out the files orcactl reads from Orca's user-data
// directory: the active profile, its state database, and the runtime socket.
func orcaUserData(t *testing.T, server *runtimetest.Server, settings ...map[string]any) {
	t.Helper()
	root := t.TempDir()
	write := func(name, content string) {
		if err := os.WriteFile(filepath.Join(root, name), []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("orca-profile-index.json", `{"activeProfileId":"test"}`)
	meta, _ := json.Marshal(map[string]any{"authToken": server.Socket.Token,
		"transports": []map[string]any{{"kind": "unix", "endpoint": server.Socket.Endpoint}}})
	write("orca-runtime.json", string(meta))
	folder := filepath.Join(root, "profiles", "test")
	if err := os.MkdirAll(folder, 0o700); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", filepath.Join(folder, "profile-state.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	document := map[string]any{}
	if len(settings) > 0 {
		document = settings[0]
	}
	payload, _ := json.Marshal(document)
	if _, err := db.Exec(`CREATE TABLE profile_state_documents (domain TEXT, payload TEXT)`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO profile_state_documents VALUES ('settings', ?)`, string(payload)); err != nil {
		t.Fatal(err)
	}
	t.Setenv("ORCA_USER_DATA_PATH", root)
}

func fakeOrca(t *testing.T, foreground string, running bool, status map[string]any) *runtimetest.Server {
	pane := map[string]any{"id": "tab::leaf", "type": "terminal", "terminal": "term-a", "title": "agent"}
	if status != nil {
		pane["agentStatus"] = status
	}
	server := runtimetest.New(t, map[string]runtimetest.Handler{
		"worktree.ps": runtimetest.Fixed(map[string]any{"worktrees": []map[string]any{
			{"worktreeId": "repo::/project", "path": "/project", "displayName": "project", "isActive": true, "hostId": "local"}}}),
		"session.tabs.list":       runtimetest.Fixed(map[string]any{"activeTabId": "tab::leaf", "tabs": []any{pane}}),
		"terminal.show":           runtimetest.Fixed(map[string]any{"terminal": map[string]any{"connected": true, "executionHostId": "local"}}),
		"terminal.agentStatus":    runtimetest.Fixed(map[string]any{"agentStatus": map[string]any{"isRunningAgent": running}}),
		"terminal.inspectProcess": runtimetest.Fixed(map[string]any{"process": map[string]any{"foregroundProcess": foreground}}),
	})
	orcaUserData(t, server)
	return server
}

func TestContextReportsTheFocusedAgentAndBinding(t *testing.T) {
	server := fakeOrca(t, "claude", true, map[string]any{"agentType": "claude", "providerSession": map[string]any{"id": "source"}})
	got, err := buildContext()
	if err != nil {
		t.Fatal(err)
	}
	terminal := got.Active.Terminal
	if got.Active.Worktree.Path != "/project" || terminal.Handle != "term-a" || terminal.Host != "local" ||
		terminal.Agent == nil || *terminal.Agent != "claude" || terminal.SessionID == nil || *terminal.SessionID != "source" {
		t.Fatalf("got %+v", got)
	}
	for _, method := range server.Methods() {
		if strings.HasPrefix(method, "aiVault.") {
			t.Fatalf("ctx scanned the vault: %v", server.Methods())
		}
	}
}

func TestContextForAPlainShellHasNoAgent(t *testing.T) {
	fakeOrca(t, "zsh", false, nil)
	got, err := buildContext()
	if err != nil || got.Active.Terminal.Agent != nil || got.Active.Terminal.SessionID != nil {
		t.Fatalf("got %+v, %v", got, err)
	}
}
