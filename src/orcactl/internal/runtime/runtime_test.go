package runtime_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime/runtimetest"
)

func TestCallSkipsKeepalivesAndDecodesResult(t *testing.T) {
	server := runtimetest.New(t, map[string]runtimetest.Handler{"worktree.ps": runtimetest.Fixed(map[string]any{"n": 3})})
	var out struct{ N int }
	if err := server.Socket.Call("worktree.ps", nil, &out); err != nil || out.N != 3 {
		t.Fatalf("got %+v, %v", out, err)
	}
}

func TestMethodErrorsAreDistinctFromTransportErrors(t *testing.T) {
	server := runtimetest.New(t, map[string]runtimetest.Handler{
		"terminal.show": func(map[string]any) runtimetest.Reply {
			return runtimetest.Reply{Code: "terminal_gone", Message: "gone"}
		},
	})
	err := server.Socket.Call("terminal.show", nil, nil)
	if !runtime.IsMethodError(err) || !strings.Contains(err.Error(), "terminal_gone") {
		t.Fatalf("got %v", err)
	}
	unreachable := &runtime.Socket{Endpoint: filepath.Join(t.TempDir(), "missing.sock")}
	if err := unreachable.Call("worktree.ps", nil, nil); err == nil || runtime.IsMethodError(err) {
		t.Fatalf("got %v", err)
	}
}

func TestLocalSocketReadsTheUnixTransport(t *testing.T) {
	dir := t.TempDir()
	meta := `{"authToken":"tok","transports":[{"kind":"websocket","endpoint":"ws://x"},{"kind":"unix","endpoint":"/tmp/rt.sock"}]}`
	if err := os.WriteFile(filepath.Join(dir, "orca-runtime.json"), []byte(meta), 0o600); err != nil {
		t.Fatal(err)
	}
	socket, err := runtime.LocalSocket(dir)
	if err != nil || socket.Endpoint != "/tmp/rt.sock" || socket.Token != "tok" {
		t.Fatalf("got %+v, %v", socket, err)
	}
	if _, err := runtime.LocalSocket(t.TempDir()); err == nil {
		t.Fatal("missing metadata should refuse")
	}
}
