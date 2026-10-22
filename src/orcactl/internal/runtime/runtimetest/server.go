// Package runtimetest serves Orca's newline-delimited runtime protocol on a
// real Unix socket for tests.
package runtimetest

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

// Reply is one method's answer: a result, or a method error when Code or
// Message is set.
type Reply struct {
	Result  any
	Code    string
	Message string
}

// Handler answers one request's params.
type Handler func(params map[string]any) Reply

// Server records each call and answers from Handlers; an unknown method fails
// the test.
type Server struct {
	t        *testing.T
	Handlers map[string]Handler
	mu       sync.Mutex
	calls    []Call
	listener net.Listener
	Socket   *runtime.Socket
}

// Call is one request the server received.
type Call struct {
	Method string
	Params map[string]any
}

const token = "test-token"

// New starts a server that the returned Socket reaches.
func New(t *testing.T, handlers map[string]Handler) *Server {
	t.Helper()
	dir, err := os.MkdirTemp("", "orca-rt")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	path := filepath.Join(dir, "rt.sock")
	listener, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	s := &Server{t: t, Handlers: handlers, listener: listener, Socket: &runtime.Socket{Endpoint: path, Token: token}}
	t.Cleanup(func() { listener.Close() })
	go s.serve()
	return s
}

// Calls returns the methods called so far, in order.
func (s *Server) Calls() []Call {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]Call(nil), s.calls...)
}

// Methods returns just the called method names, in order.
func (s *Server) Methods() []string {
	var methods []string
	for _, call := range s.Calls() {
		methods = append(methods, call.Method)
	}
	return methods
}

func (s *Server) serve() {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			return
		}
		go s.handle(conn)
	}
}

func (s *Server) handle(conn net.Conn) {
	defer conn.Close()
	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		return
	}
	var request struct {
		ID        string         `json:"id"`
		AuthToken string         `json:"authToken"`
		Method    string         `json:"method"`
		Params    map[string]any `json:"params"`
	}
	if err := json.Unmarshal(line, &request); err != nil {
		s.t.Errorf("invalid request frame: %v", err)
		return
	}
	s.mu.Lock()
	s.calls = append(s.calls, Call{Method: request.Method, Params: request.Params})
	s.mu.Unlock()
	reply := map[string]any{"id": request.ID}
	handler, ok := s.Handlers[request.Method]
	switch {
	case request.AuthToken != token:
		reply["ok"], reply["error"] = false, map[string]any{"code": "unauthorized", "message": "bad token"}
	case !ok:
		s.t.Errorf("unexpected RPC %s %v", request.Method, request.Params)
		reply["ok"], reply["error"] = false, map[string]any{"code": "method_not_found", "message": request.Method}
	default:
		answer := handler(request.Params)
		if answer.Code != "" || answer.Message != "" {
			reply["ok"], reply["error"] = false, map[string]any{"code": answer.Code, "message": answer.Message}
		} else {
			reply["ok"], reply["result"] = true, answer.Result
		}
	}
	// A keepalive frame first, as Orca sends, so clients must match by id.
	keepalive, _ := json.Marshal(map[string]any{"_keepalive": true})
	payload, _ := json.Marshal(reply)
	conn.Write(append(append(keepalive, '\n'), append(payload, '\n')...))
}

// Fixed returns a handler that always answers result.
func Fixed(result any) Handler {
	return func(map[string]any) Reply { return Reply{Result: result} }
}
