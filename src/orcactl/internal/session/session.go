// Package session finds the conversation behind the focused pane.
package session

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/prateek/dotfiles/src/orcactl/internal/agent"
	"github.com/prateek/dotfiles/src/orcactl/internal/focus"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

// Session is one conversation, in the AI vault's field names.
type Session struct {
	Agent           string `json:"agent"`
	SessionID       string `json:"sessionId"`
	Title           string `json:"title"`
	Cwd             string `json:"cwd"`
	FilePath        string `json:"filePath"`
	ResumeCommand   string `json:"resumeCommand"`
	ExecutionHostID string `json:"executionHostId"`
	Subagent        bool   `json:"subagent"`
	CodexHome       string `json:"codexHome"`
}

// ErrNotFound means the agent runs but its conversation is not on disk yet.
var ErrNotFound = errors.New("no session found on disk yet")

// Find resolves the focused conversation. Local panes go through the vault;
// SSH and paired panes trust only Orca's binding, so a local transcript can
// never stand in for a remote one.
func Find(rt runtime.Caller, captured focus.Focus, identity agent.Identity) (Session, error) {
	if captured.Host == "local" {
		return vault(rt, identity, captured.Worktree.Path)
	}
	return bound(identity, captured.Worktree.Path, captured.Host)
}

func vault(rt runtime.Caller, identity agent.Identity, worktreePath string) (Session, error) {
	// A forced, unlimited vault scan is the slowest call orcactl makes.
	slow := rt.WithTimeout(60 * time.Second)
	var result struct {
		Sessions []Session `json:"sessions"`
	}
	params := map[string]any{"scopePaths": []string{worktreePath}, "force": true, "unlimited": true}
	if err := slow.Call("aiVault.listSessions", params, &result); err != nil {
		return Session{}, err
	}
	root := strings.TrimRight(worktreePath, "/")
	inWorktree := func(s Session) bool {
		cwd := strings.TrimRight(s.Cwd, "/")
		return cwd == root || strings.HasPrefix(cwd, root+"/")
	}
	var matches []Session
	for _, s := range result.Sessions {
		host := s.ExecutionHostID
		if host == "" {
			host = "local"
		}
		if !s.Subagent && host == "local" && s.Agent == identity.Agent && inWorktree(s) {
			matches = append(matches, s)
		}
	}
	id, transcript := identity.ProviderSession.ID, identity.ProviderSession.TranscriptPath
	if id != "" || transcript != "" {
		var bound []Session
		for _, s := range matches {
			if (id == "" || s.SessionID == id) && (transcript == "" || s.FilePath == transcript) {
				bound = append(bound, s)
			}
		}
		if len(bound) != 1 {
			return Session{}, fmt.Errorf("The focused %s session could not be identified in the local vault", identity.Agent)
		}
		return bound[0], nil
	}
	var exact []Session
	for _, s := range matches {
		if strings.TrimRight(s.Cwd, "/") == root {
			exact = append(exact, s)
		}
	}
	scoped := matches
	if len(exact) > 0 {
		scoped = exact
	}
	switch len(scoped) {
	case 0:
		return Session{}, fmt.Errorf("Agent %s is running but %w", identity.Agent, ErrNotFound)
	case 1:
		return scoped[0], nil
	default:
		return Session{}, fmt.Errorf("Orca has not identified the focused %s session; %d sessions match", identity.Agent, len(scoped))
	}
}

func bound(identity agent.Identity, worktreePath, host string) (Session, error) {
	id := identity.ProviderSession.ID
	if id == "" {
		return Session{}, fmt.Errorf("Orca has not bound the focused %s conversation on %s; no local fallback", identity.Agent, host)
	}
	transcript := identity.ProviderSession.TranscriptPath
	s := Session{Agent: identity.Agent, SessionID: id, Cwd: worktreePath, FilePath: transcript, ExecutionHostID: host}
	if identity.Agent == "codex" && transcript != "" {
		// Rollouts live at <CODEX_HOME>/sessions/<date>/<filename>.
		if i := strings.LastIndex(transcript, "/sessions/"); i > 0 && strings.HasPrefix(transcript, "/") {
			s.CodexHome = transcript[:i]
		}
	}
	return s, nil
}
