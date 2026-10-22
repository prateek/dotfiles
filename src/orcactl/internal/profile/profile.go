// Package profile reads Orca's active profile state, read-only, to decide which
// runtime owns the focused workspace.
package profile

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	_ "modernc.org/sqlite"
)

var (
	profileID   = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)
	runtimeHost = regexp.MustCompile(`^runtime:[^|\s]+$`)
	sshHost     = regexp.MustCompile(`^ssh:[^|\s]+$`)
	errUnread   = errors.New("could not read Orca's active profile and server selection; update or restart Orca")
)

// openActive opens the active profile's state database read-only; mode=ro
// never creates the file or its directory.
func openActive(userData string) (string, *sql.DB, error) {
	raw, err := os.ReadFile(filepath.Join(userData, "orca-profile-index.json"))
	if err != nil {
		return "", nil, errUnread
	}
	var index struct {
		ActiveProfileID any `json:"activeProfileId"`
	}
	if json.Unmarshal(raw, &index) != nil {
		return "", nil, errUnread
	}
	id, ok := index.ActiveProfileID.(string)
	if !ok || !profileID.MatchString(id) {
		return "", nil, errors.New("Orca returned an invalid active profile")
	}
	database := filepath.Join(userData, "profiles", id, "profile-state.db")
	if _, err := os.Stat(database); err != nil {
		return "", nil, errUnread
	}
	db, err := sql.Open("sqlite", "file:"+(&url.URL{Path: database}).EscapedPath()+"?mode=ro")
	if err != nil {
		return "", nil, errUnread
	}
	return id, db, nil
}

// SelectedEnvironment returns the paired-server environment id that owns the
// focused workspace, or "" when the desktop's own runtime owns it. The saved
// focused host wins over the default-server preference, because selecting a
// workspace in the sidebar changes the former without the latter.
func SelectedEnvironment(userData string) (string, error) {
	_, db, err := openActive(userData)
	if err != nil {
		return "", err
	}
	defer db.Close()
	rows, err := db.Query(`SELECT domain, payload FROM profile_state_documents WHERE domain IN ('settings', 'workspaceSession')`)
	if err != nil {
		return "", errUnread
	}
	defer rows.Close()
	documents := map[string]map[string]any{}
	for rows.Next() {
		var domain, payload string
		if rows.Scan(&domain, &payload) != nil {
			return "", errUnread
		}
		var document map[string]any
		if json.Unmarshal([]byte(payload), &document) != nil {
			return "", errUnread
		}
		documents[domain] = document
	}
	if rows.Err() != nil {
		return "", errUnread
	}
	session := documents["workspaceSession"]
	host, hasHost := session["activeWorkspaceExecutionHostId"].(string)
	if worktree, _ := session["activeWorktreeId"].(string); worktree != "" && hasHost {
		switch {
		case runtimeHost.MatchString(host):
			return strings.TrimPrefix(host, "runtime:"), nil
		case host == "local" || sshHost.MatchString(host):
			return "", nil
		default:
			return "", errors.New("Orca returned an invalid focused workspace host")
		}
	}
	settings, ok := documents["settings"]
	if !ok {
		return "", errUnread
	}
	selected, _ := settings["activeRuntimeEnvironmentId"].(string)
	return selected, nil
}

// ActiveRepo returns the active profile id and its selected project's repo id
// ("" when none is selected).
func ActiveRepo(userData string) (profileName, repo string, err error) {
	id, db, err := openActive(userData)
	if err != nil {
		return "", "", err
	}
	defer db.Close()
	var payload string
	switch err := db.QueryRow(`SELECT payload FROM profile_state_documents WHERE domain = 'workspaceSession'`).Scan(&payload); {
	case errors.Is(err, sql.ErrNoRows):
		return id, "", nil
	case err != nil:
		return "", "", errUnread
	}
	var session struct {
		ActiveRepoID string `json:"activeRepoId"`
	}
	if json.Unmarshal([]byte(payload), &session) != nil {
		return "", "", errUnread
	}
	return id, session.ActiveRepoID, nil
}
