// Package zen toggles Orca between the current project alone with both
// sidebars hidden, and the view it had before.
package zen

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"syscall"
	"time"

	"github.com/prateek/dotfiles/src/orcactl/internal/profile"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

// State is Orca's window as accessibility reports it.
type State struct {
	PID       int  `json:"pid"`
	Frontmost bool `json:"frontmost"`
	Left      bool `json:"left"`
	Right     bool `json:"right"`
}

// Desktop inspects and sets Orca's sidebars. expectedPID 0 skips the
// frontmost and same-process checks.
type Desktop interface {
	Sidebars(expectedPID int) (State, error)
	SetSidebars(pid int, left, right bool) (State, error)
}

// Toggler owns one toggle's inputs.
type Toggler struct {
	UserData string
	StateDir string
	Desktop  Desktop
}

type saved struct {
	State
	Profile       string   `json:"profile"`
	FilterRepoIDs []string `json:"filterRepoIds"`
}

// Status reports the view without changing it.
func (t Toggler) Status() (map[string]any, error) {
	current, err := t.Desktop.Sidebars(0)
	if err != nil {
		return nil, err
	}
	name, repo, err := profile.ActiveRepo(t.UserData)
	if err != nil {
		return nil, err
	}
	filters, err := t.filters(current.PID)
	if err != nil {
		return nil, err
	}
	return map[string]any{"pid": current.PID, "frontmost": current.Frontmost, "left": current.Left, "right": current.Right,
		"profile": name, "project": nullable(repo), "filterRepoIds": filters}, nil
}

// Toggle enters Zen, or restores the saved view when one exists. A second
// press while a toggle runs is ignored (nil, nil).
func (t Toggler) Toggle() (map[string]any, error) {
	if err := os.MkdirAll(t.StateDir, 0o700); err != nil {
		return nil, err
	}
	lock, err := os.OpenFile(filepath.Join(t.StateDir, "lock"), os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, err
	}
	defer lock.Close()
	if syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		return nil, nil
	}
	current, err := t.Desktop.Sidebars(0)
	if err != nil {
		return nil, err
	}
	if !current.Frontmost {
		return nil, errors.New("Orca must be frontmost; focus was left unchanged")
	}
	name, repo, err := profile.ActiveRepo(t.UserData)
	if err != nil {
		return nil, err
	}
	stateFile := filepath.Join(t.StateDir, "restore-"+name+".json")
	var target saved
	restoring := false
	if raw, err := os.ReadFile(stateFile); err == nil {
		restoring = true
		var fields map[string]any
		if json.Unmarshal(raw, &fields) != nil || json.Unmarshal(raw, &target) != nil ||
			fields["profile"] != name || !isBool(fields["left"]) || !isBool(fields["right"]) || !validFilter(fields["filterRepoIds"]) {
			return nil, errors.New("Invalid saved layout; inspect " + stateFile)
		}
	} else {
		if repo == "" {
			return nil, errors.New("Select an Orca project before entering Zen mode")
		}
		filters, err := t.filters(current.PID)
		if err != nil {
			return nil, err
		}
		raw, _ := json.Marshal(saved{State: current, Profile: name, FilterRepoIDs: filters})
		temporary := stateFile + ".tmp"
		if err := os.WriteFile(temporary, raw, 0o600); err != nil {
			return nil, err
		}
		if err := os.Rename(temporary, stateFile); err != nil {
			return nil, err
		}
		target = saved{State: State{Left: false, Right: false}, FilterRepoIDs: []string{repo}}
	}

	before, err := t.Desktop.Sidebars(0)
	if err != nil {
		return nil, err
	}
	activeProfile, activeRepo, err := profile.ActiveRepo(t.UserData)
	if err != nil {
		return nil, err
	}
	if !before.Frontmost || before.PID != current.PID || activeProfile != name || (!restoring && activeRepo != repo) {
		return nil, errors.New("Orca focus or project changed; toggle again to restore")
	}
	if _, err := t.ui(current.PID, "ui.set", map[string]any{"filterRepoIds": target.FilterRepoIDs}); err != nil {
		return nil, err
	}
	applied, err := t.filters(current.PID)
	if err != nil {
		return nil, err
	}
	if !slices.Equal(applied, target.FilterRepoIDs) {
		return nil, errors.New("Project filter change was not verified; toggle again to restore")
	}
	if again, _, err := profile.ActiveRepo(t.UserData); err != nil || again != name {
		return nil, errors.New("Orca profile changed; return to the original profile to restore")
	}
	actual, err := t.Desktop.SetSidebars(current.PID, target.Left, target.Right)
	if err != nil {
		return nil, err
	}
	if actual.PID != current.PID || actual.Left != target.Left || actual.Right != target.Right {
		return nil, errors.New("Sidebar change was not verified; press Option-Z again to restore")
	}
	if restoring {
		if err := os.Remove(stateFile); err != nil {
			return nil, err
		}
	}
	return map[string]any{"pid": actual.PID, "frontmost": actual.Frontmost, "left": actual.Left, "right": actual.Right,
		"zen": !restoring, "filterRepoIds": target.FilterRepoIDs}, nil
}

func (t Toggler) filters(pid int) ([]string, error) {
	ui, err := t.ui(pid, "ui.get", nil)
	if err != nil {
		return nil, err
	}
	if !validFilter(ui["filterRepoIds"]) {
		return nil, errors.New("Invalid Orca project filter")
	}
	filters := []string{}
	for _, id := range ui["filterRepoIds"].([]any) {
		filters = append(filters, id.(string))
	}
	return filters, nil
}

// ui always addresses this desktop's own UI, even when its selected workspace
// is on a paired server, and refuses if Orca restarted mid-toggle.
func (t Toggler) ui(pid int, method string, params map[string]any) (map[string]any, error) {
	raw, err := os.ReadFile(filepath.Join(t.UserData, "orca-runtime.json"))
	if err != nil {
		return nil, errors.New("Orca's local runtime socket is unavailable")
	}
	var meta struct {
		PID int `json:"pid"`
	}
	if json.Unmarshal(raw, &meta) != nil || meta.PID != pid {
		return nil, errors.New("Orca restarted during the toggle")
	}
	socket, err := runtime.LocalSocket(t.UserData)
	if err != nil {
		return nil, errors.New("Orca's local runtime socket is unavailable")
	}
	socket.Timeout = 5 * time.Second
	var result struct {
		UI map[string]any `json:"ui"`
	}
	if err := socket.Call(method, params, &result); err != nil {
		return nil, err
	}
	return result.UI, nil
}

func isBool(v any) bool { _, ok := v.(bool); return ok }

func validFilter(v any) bool {
	items, ok := v.([]any)
	if !ok {
		return false
	}
	for _, item := range items {
		if _, ok := item.(string); !ok {
			return false
		}
	}
	return true
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}
