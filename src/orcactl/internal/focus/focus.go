// Package focus captures the pane Orca considers focused. Callers act on the
// captured handle afterwards, so focus moving later changes nothing.
package focus

import (
	"errors"
	"net/url"
	"regexp"
	"strings"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

// Worktree is one row of worktree.ps.
type Worktree struct {
	WorktreeID  string `json:"worktreeId"`
	Path        string `json:"path"`
	DisplayName string `json:"displayName"`
	IsActive    bool   `json:"isActive"`
	HostID      string `json:"hostId"`
}

// ProviderSession is Orca's binding from a pane to an agent conversation.
type ProviderSession struct {
	ID             string `json:"id"`
	TranscriptPath string `json:"transcriptPath"`
}

// AgentStatus is the hook-reported agent state of a pane.
type AgentStatus struct {
	AgentType       string          `json:"agentType"`
	ProviderSession ProviderSession `json:"providerSession"`
}

// Pane is one leaf of session.tabs.list; Orca reports focus per split.
type Pane struct {
	ID          string       `json:"id"`
	Type        string       `json:"type"`
	Terminal    string       `json:"terminal"`
	Title       string       `json:"title"`
	ParentTabID string       `json:"parentTabId"`
	LaunchAgent string       `json:"launchAgent"`
	AgentStatus *AgentStatus `json:"agentStatus"`
}

// Focus is the captured workspace, pane, and the host the pane runs on.
type Focus struct {
	Worktree Worktree
	Pane     Pane
	Host     string // "local", "ssh:<id>", or "runtime:<environment>"
}

var validHost = regexp.MustCompile(`^(?:ssh|runtime):[^|\s]+$`)

// Workspace returns the active workspace, or the one at path when given.
func Workspace(rt runtime.Caller, path string) (Worktree, error) {
	var result struct {
		Worktrees []Worktree `json:"worktrees"`
	}
	if err := rt.Call("worktree.ps", map[string]any{}, &result); err != nil {
		return Worktree{}, err
	}
	for _, worktree := range result.Worktrees {
		if (path == "" && worktree.IsActive) || (path != "" && worktree.Path == path) {
			return worktree, nil
		}
	}
	if path != "" {
		return Worktree{}, errors.New("No Orca workspace found for " + path)
	}
	return Worktree{}, errors.New("Orca has no active workspace")
}

// FocusedPane returns the workspace's focused split, which must be a terminal.
func FocusedPane(rt runtime.Caller, worktreeID string) (Pane, error) {
	var result struct {
		ActiveTabID string `json:"activeTabId"`
		Tabs        []Pane `json:"tabs"`
	}
	if err := rt.Call("session.tabs.list", map[string]any{"worktree": worktreeID}, &result); err != nil {
		return Pane{}, err
	}
	for _, pane := range result.Tabs {
		if pane.ID == result.ActiveTabID && result.ActiveTabID != "" {
			if pane.Type != "terminal" || pane.Terminal == "" {
				break
			}
			return pane, nil
		}
	}
	return Pane{}, errors.New("Focus an Orca agent terminal first")
}

// Host resolves where the pane runs and refuses a disconnected pane or SSH host.
// selected is the paired environment owning the workspace, or "".
func Host(rt runtime.Caller, pane Pane, worktree Worktree, selected string) (string, error) {
	var shown struct {
		Terminal struct {
			Connected       bool   `json:"connected"`
			ExecutionHostID string `json:"executionHostId"`
		} `json:"terminal"`
	}
	if err := rt.Call("terminal.show", map[string]any{"terminal": pane.Terminal}, &shown); err != nil {
		return "", err
	}
	if !shown.Terminal.Connected {
		return "", errors.New("The focused terminal is disconnected")
	}
	host := shown.Terminal.ExecutionHostID
	if host == "" {
		host = worktree.HostID
	}
	if host == "" {
		return "", errors.New("Orca could not identify the focused terminal's execution host; update Orca")
	}
	if host == "local" && selected != "" {
		host = "runtime:" + selected
	}
	if host != "local" && !validHost.MatchString(host) {
		return "", errors.New("Orca returned an invalid execution host")
	}
	if target, ok := strings.CutPrefix(host, "ssh:"); ok {
		if unescaped, err := url.PathUnescape(target); err == nil {
			target = unescaped
		}
		var state struct {
			State *struct {
				Status string `json:"status"`
			} `json:"state"`
		}
		if err := rt.Call("ssh.getState", map[string]any{"targetId": target}, &state); err != nil {
			return "", err
		}
		if state.State == nil || state.State.Status != "connected" {
			return "", errors.New("The focused terminal's SSH host is disconnected")
		}
	}
	return host, nil
}

// Capture reads focus in the order that keeps the pre-capture window short:
// workspace, then focused split, then that pane's host.
func Capture(rt runtime.Caller, worktreePath, selected string) (Focus, error) {
	worktree, err := Workspace(rt, worktreePath)
	if err != nil {
		return Focus{}, err
	}
	pane, err := FocusedPane(rt, worktree.WorktreeID)
	if err != nil {
		return Focus{}, err
	}
	host, err := Host(rt, pane, worktree, selected)
	if err != nil {
		return Focus{}, err
	}
	return Focus{Worktree: worktree, Pane: pane, Host: host}, nil
}
