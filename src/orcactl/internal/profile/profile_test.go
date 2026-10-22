package profile

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func writeProfile(t *testing.T, documents map[string]any) string {
	t.Helper()
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "orca-profile-index.json"), []byte(`{"activeProfileId":"test"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	folder := filepath.Join(root, "profiles", "test")
	if err := os.MkdirAll(folder, 0o700); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", filepath.Join(folder, "profile-state.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if _, err := db.Exec(`CREATE TABLE profile_state_documents (domain TEXT, payload TEXT)`); err != nil {
		t.Fatal(err)
	}
	for domain, document := range documents {
		payload, _ := json.Marshal(document)
		if _, err := db.Exec(`INSERT INTO profile_state_documents VALUES (?, ?)`, domain, string(payload)); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestFocusedWorkspaceHostOverridesDefaultServer(t *testing.T) {
	for _, tc := range []struct {
		host     any
		fallback any
		want     string
	}{
		{"runtime:remote", nil, "remote"},
		{"runtime:remote", "different-server", "remote"},
		{"local", "remote", ""},
		{"ssh:fixture", "remote", ""},
		{nil, "remote", "remote"},
	} {
		root := writeProfile(t, map[string]any{
			"settings":         map[string]any{"activeRuntimeEnvironmentId": tc.fallback},
			"workspaceSession": map[string]any{"activeWorktreeId": "repo::/project", "activeWorkspaceExecutionHostId": tc.host},
		})
		got, err := SelectedEnvironment(root)
		if err != nil || got != tc.want {
			t.Errorf("host %v, default %v: got %q, %v; want %q", tc.host, tc.fallback, got, err, tc.want)
		}
	}
}

func TestOlderProfileUsesDefaultServer(t *testing.T) {
	root := writeProfile(t, map[string]any{"settings": map[string]any{"activeRuntimeEnvironmentId": "paired-server"}})
	if got, err := SelectedEnvironment(root); err != nil || got != "paired-server" {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestMissingDatabaseRefusesWithoutCreatingState(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "orca-profile-index.json"), []byte(`{"activeProfileId":"missing"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := SelectedEnvironment(root); err == nil {
		t.Fatal("expected a refusal")
	}
	if _, err := os.Stat(filepath.Join(root, "profiles")); !os.IsNotExist(err) {
		t.Fatalf("profiles directory was created: %v", err)
	}
}

func TestInvalidFocusedHostRefuses(t *testing.T) {
	root := writeProfile(t, map[string]any{
		"settings":         map[string]any{},
		"workspaceSession": map[string]any{"activeWorktreeId": "repo::/project", "activeWorkspaceExecutionHostId": "runtime:bad|id"},
	})
	if _, err := SelectedEnvironment(root); err == nil {
		t.Fatal("expected a refusal")
	}
}
