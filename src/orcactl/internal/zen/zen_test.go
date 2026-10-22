package zen

import (
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"syscall"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

// fixture is Orca's desktop UI: sidebars behind accessibility, preferences
// behind ui.get/ui.set, and the active profile's selected project.
type fixture struct {
	t           *testing.T
	root        string
	state       string
	ui          State
	preferences map[string]any
	failSidebar bool
	failSet     bool
	ignoreSet   bool
	afterGet    func()
	sidebarSets [][2]bool
	uiSets      []map[string]any
	server      *runtimetest.Server
}

func newFixture(t *testing.T) *fixture {
	f := &fixture{t: t, root: t.TempDir(), state: filepath.Join(t.TempDir(), "orca-zen-mode"),
		ui:          State{PID: 123, Frontmost: true, Left: true, Right: false},
		preferences: map[string]any{"filterRepoIds": []any{"previous-project", "another-project"}, "hideSleepingWorkspaces": true, "sidebarWidth": 321.0},
		afterGet:    func() {}}
	f.server = runtimetest.New(t, map[string]runtimetest.Handler{
		"ui.get": func(map[string]any) runtimetest.Reply {
			f.afterGet()
			return runtimetest.Reply{Result: map[string]any{"ui": f.preferences}}
		},
		"ui.set": func(params map[string]any) runtimetest.Reply {
			if !f.restoreSaved() {
				t.Error("restoration must be saved before the filter changes")
			}
			if len(params) != 1 || params["filterRepoIds"] == nil {
				t.Errorf("ui.set must change only the filter: %v", params)
			}
			f.uiSets = append(f.uiSets, params)
			if f.failSet {
				return runtimetest.Reply{Message: "fixture failure"}
			}
			if !f.ignoreSet {
				f.preferences["filterRepoIds"] = params["filterRepoIds"]
			}
			return runtimetest.Reply{Result: map[string]any{"ui": f.preferences}}
		},
	})
	f.writeRuntime()
	f.selectProfile("test", "active-project")
	return f
}

func (f *fixture) writeRuntime() {
	meta, _ := json.Marshal(map[string]any{"pid": f.ui.PID, "authToken": f.server.Socket.Token,
		"transports": []map[string]any{{"kind": "unix", "endpoint": f.server.Socket.Endpoint}}})
	if err := os.WriteFile(filepath.Join(f.root, "orca-runtime.json"), meta, 0o600); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) selectProfile(name, repo string) {
	index, _ := json.Marshal(map[string]any{"activeProfileId": name})
	if err := os.WriteFile(filepath.Join(f.root, "orca-profile-index.json"), index, 0o600); err != nil {
		f.t.Fatal(err)
	}
	folder := filepath.Join(f.root, "profiles", name)
	if err := os.MkdirAll(folder, 0o700); err != nil {
		f.t.Fatal(err)
	}
	db, err := sql.Open("sqlite", filepath.Join(folder, "profile-state.db"))
	if err != nil {
		f.t.Fatal(err)
	}
	defer db.Close()
	session := map[string]any{"activeWorkspaceExecutionHostId": "runtime:remote-server"}
	if repo != "" {
		session["activeRepoId"] = repo
	}
	payload, _ := json.Marshal(session)
	for _, stmt := range []string{
		`CREATE TABLE IF NOT EXISTS profile_state_documents (domain TEXT PRIMARY KEY, payload TEXT)`,
		`INSERT OR REPLACE INTO profile_state_documents VALUES ('workspaceSession', ?)`,
	} {
		args := []any{}
		if strings.Contains(stmt, "?") {
			args = append(args, string(payload))
		}
		if _, err := db.Exec(stmt, args...); err != nil {
			f.t.Fatal(err)
		}
	}
}

func (f *fixture) restoreSaved() bool {
	matches, _ := filepath.Glob(filepath.Join(f.state, "restore-*.json"))
	return len(matches) > 0
}

func (f *fixture) stateFile() string { return filepath.Join(f.state, "restore-test.json") }

func (f *fixture) Sidebars(expectedPID int) (State, error) {
	if expectedPID != 0 && !f.ui.Frontmost {
		return State{}, errors.New("Orca must be frontmost; focus was left unchanged")
	}
	return f.ui, nil
}

func (f *fixture) SetSidebars(pid int, left, right bool) (State, error) {
	if !f.restoreSaved() {
		f.t.Error("restoration must be saved before the sidebars change")
	}
	f.sidebarSets = append(f.sidebarSets, [2]bool{left, right})
	if f.failSidebar {
		return State{}, errors.New("Sidebar change failed")
	}
	f.ui.Left, f.ui.Right = left, right
	return f.ui, nil
}

func (f *fixture) toggler() Toggler { return Toggler{UserData: f.root, StateDir: f.state, Desktop: f} }

func (f *fixture) toggle() error {
	_, err := f.toggler().Toggle()
	return err
}

func (f *fixture) filter() []any { return f.preferences["filterRepoIds"].([]any) }

func (f *fixture) mustToggle() {
	f.t.Helper()
	if err := f.toggle(); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) noMutations() bool { return len(f.sidebarSets) == 0 && len(f.uiSets) == 0 }

func TestEachLayoutAndFilterRestoresAfterTheSidebarIsReopened(t *testing.T) {
	for _, left := range []bool{false, true} {
		for _, right := range []bool{false, true} {
			for _, filters := range [][]any{{}, {"previous-project", "another-project"}} {
				f := newFixture(t)
				f.ui.Left, f.ui.Right = left, right
				f.preferences["filterRepoIds"] = filters
				f.mustToggle()
				if f.ui.Left || f.ui.Right || !reflect.DeepEqual(f.filter(), []any{"active-project"}) {
					t.Fatalf("enter %v/%v/%v: %+v %v", left, right, filters, f.ui, f.filter())
				}
				f.ui.Left = true
				f.selectProfile("test", "newly-selected-project")
				f.mustToggle()
				want := map[string]any{"filterRepoIds": filters, "hideSleepingWorkspaces": true, "sidebarWidth": 321.0}
				if f.ui.Left != left || f.ui.Right != right || !reflect.DeepEqual(normalize(f.preferences), normalize(want)) {
					t.Fatalf("restore %v/%v/%v: %+v %v", left, right, filters, f.ui, f.preferences)
				}
				if f.restoreSaved() {
					t.Fatal("restore file left behind")
				}
			}
		}
	}
}

func normalize(v map[string]any) string { raw, _ := json.Marshal(v); return string(raw) }

func TestAFailedChangeKeepsTheRestoreForTheNextPress(t *testing.T) {
	for _, boundary := range []string{"sidebar", "rpc"} {
		f := newFixture(t)
		f.failSidebar, f.failSet = boundary == "sidebar", boundary == "rpc"
		if err := f.toggle(); err == nil || !strings.Contains(err.Error(), map[string]string{"sidebar": "Sidebar change failed", "rpc": "fixture failure"}[boundary]) {
			t.Fatalf("%s: %v", boundary, err)
		}
		var saved map[string]any
		raw, _ := os.ReadFile(f.stateFile())
		if json.Unmarshal(raw, &saved) != nil || saved["left"] != true {
			t.Fatalf("%s: restore file %s", boundary, raw)
		}
		f.ui.Left = false // A partial mutation must not become the new baseline.
		f.failSidebar, f.failSet = false, false
		f.mustToggle()
		if !f.ui.Left || f.ui.Right || !reflect.DeepEqual(f.filter(), []any{"previous-project", "another-project"}) || f.restoreSaved() {
			t.Fatalf("%s: %+v %v", boundary, f.ui, f.filter())
		}
	}
}

func TestARestartKeepsTheOriginalFilterAndLayout(t *testing.T) {
	f := newFixture(t)
	f.mustToggle()
	f.ui.PID++
	f.writeRuntime()
	f.mustToggle()
	if !f.ui.Left || f.ui.Right || !reflect.DeepEqual(f.filter(), []any{"previous-project", "another-project"}) || f.restoreSaved() {
		t.Fatalf("%+v %v", f.ui, f.filter())
	}
}

func TestProfilesRestoreIndependentSnapshots(t *testing.T) {
	f := newFixture(t)
	f.mustToggle()
	f.selectProfile("other", "other-project")
	f.ui.Left, f.ui.Right = false, true
	f.preferences["filterRepoIds"] = []any{"other-original"}
	f.mustToggle()
	if !reflect.DeepEqual(f.filter(), []any{"other-project"}) {
		t.Fatalf("enter other: %v", f.filter())
	}
	f.mustToggle()
	if f.ui.Left || !f.ui.Right || !reflect.DeepEqual(f.filter(), []any{"other-original"}) {
		t.Fatalf("restore other: %+v %v", f.ui, f.filter())
	}
	if _, err := os.Stat(f.stateFile()); err != nil {
		t.Fatal("the first profile's restore was lost")
	}
	f.selectProfile("test", "active-project")
	f.mustToggle()
	if !f.ui.Left || f.ui.Right || !reflect.DeepEqual(f.filter(), []any{"previous-project", "another-project"}) {
		t.Fatalf("restore test: %+v %v", f.ui, f.filter())
	}
}

func TestStatusAndBackgroundRefusalChangeNothing(t *testing.T) {
	f := newFixture(t)
	f.ui.Frontmost = false
	status, err := f.toggler().Status()
	if err != nil || status["project"] != "active-project" || status["profile"] != "test" {
		t.Fatalf("status: %v %v", status, err)
	}
	if err := f.toggle(); err == nil || !strings.Contains(err.Error(), "frontmost") {
		t.Fatalf("got %v", err)
	}
	if f.restoreSaved() || !f.noMutations() {
		t.Fatal("background refusal changed state")
	}
}

func TestAMissingProjectRefusesBeforeAnyMutation(t *testing.T) {
	f := newFixture(t)
	f.selectProfile("test", "")
	if err := f.toggle(); err == nil || !strings.Contains(err.Error(), "Select an Orca project") {
		t.Fatalf("got %v", err)
	}
	if f.restoreSaved() || !f.noMutations() {
		t.Fatal("refusal changed state")
	}
}

func TestAnIgnoredFilterIsNotReportedAsSuccess(t *testing.T) {
	f := newFixture(t)
	f.ignoreSet = true
	if err := f.toggle(); err == nil || !strings.Contains(err.Error(), "Project filter change was not verified") {
		t.Fatalf("got %v", err)
	}
	if !f.restoreSaved() || len(f.sidebarSets) != 0 {
		t.Fatal("expected the restore kept and the sidebars untouched")
	}
}

func TestAFocusChangeDuringPreflightRefusesBeforeMutating(t *testing.T) {
	f := newFixture(t)
	f.afterGet = func() { f.ui.Frontmost = false }
	if err := f.toggle(); err == nil || !strings.Contains(err.Error(), "focus or project changed") {
		t.Fatalf("got %v", err)
	}
	if !f.noMutations() {
		t.Fatal("refusal changed state")
	}
}

func TestAnOverlappingPressIsIgnored(t *testing.T) {
	f := newFixture(t)
	if err := os.MkdirAll(f.state, 0o700); err != nil {
		t.Fatal(err)
	}
	lock, err := os.OpenFile(filepath.Join(f.state, "lock"), os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	result, err := f.toggler().Toggle()
	if err != nil || result != nil || !f.noMutations() || f.restoreSaved() {
		t.Fatalf("got %v %v", result, err)
	}
}

func TestACorruptRestoreRefusesWithoutChangingTheView(t *testing.T) {
	f := newFixture(t)
	f.mustToggle()
	for _, corrupt := range []string{
		`null`,
		`{"profile":"test","left":"yes","right":false}`,
		`{"profile":"test","left":true,"right":false,"filterRepoIds":"invalid"}`,
	} {
		if err := os.WriteFile(f.stateFile(), []byte(corrupt), 0o600); err != nil {
			t.Fatal(err)
		}
		f.sidebarSets, f.uiSets = nil, nil
		if err := f.toggle(); err == nil || !strings.Contains(err.Error(), "Invalid") {
			t.Fatalf("%s: got %v", corrupt, err)
		}
		if !f.noMutations() {
			t.Fatalf("%s: view changed", corrupt)
		}
	}
}
