// Package runtime calls Orca's runtime RPC: the desktop's local Unix socket, or
// a paired server through the client Orca ships for pairing.
package runtime

import (
	"bufio"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"
)

// Caller makes one RPC round trip and decodes its result into out.
type Caller interface {
	Call(method string, params any, out any) error
	// WithTimeout returns a caller whose calls may take up to d.
	WithTimeout(d time.Duration) Caller
}

// MethodError is a method-level failure reported by Orca, such as a terminal
// that has gone away. Transport failures are ordinary errors.
type MethodError struct {
	Method  string
	Code    string
	Message string
}

func (e *MethodError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("Orca RPC %s failed: %s (%s)", e.Method, e.Message, e.Code)
	}
	return fmt.Sprintf("Orca RPC %s failed: %s", e.Method, e.Message)
}

// IsMethodError reports whether err is Orca rejecting the method rather than
// the connection failing.
func IsMethodError(err error) bool {
	var methodErr *MethodError
	return errors.As(err, &methodErr)
}

// Socket talks to the runtime advertised in <userData>/orca-runtime.json.
type Socket struct {
	Endpoint string
	Token    string
	Timeout  time.Duration
}

type runtimeMetadata struct {
	AuthToken  string `json:"authToken"`
	Transports []struct {
		Kind     string `json:"kind"`
		Endpoint string `json:"endpoint"`
	} `json:"transports"`
}

// LocalSocket reads the desktop runtime's socket and token from userData.
func LocalSocket(userData string) (*Socket, error) {
	raw, err := os.ReadFile(filepath.Join(userData, "orca-runtime.json"))
	if err != nil {
		return nil, errors.New("Orca runtime metadata not found; is Orca running?")
	}
	var meta runtimeMetadata
	if err := json.Unmarshal(raw, &meta); err != nil {
		return nil, errors.New("Orca runtime metadata not found; is Orca running?")
	}
	for _, transport := range meta.Transports {
		if transport.Kind == "unix" {
			return &Socket{Endpoint: transport.Endpoint, Token: meta.AuthToken, Timeout: 15 * time.Second}, nil
		}
	}
	return nil, errors.New("Orca runtime metadata not found; is Orca running?")
}

type frame struct {
	ID        string          `json:"id"`
	OK        bool            `json:"ok"`
	Keepalive bool            `json:"_keepalive"`
	Result    json.RawMessage `json:"result"`
	Error     *struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func (s *Socket) WithTimeout(d time.Duration) Caller {
	copied := *s
	copied.Timeout = d
	return &copied
}

// Call sends one newline-delimited request and waits for the frame with its id.
func (s *Socket) Call(method string, params any, out any) error {
	timeout := s.Timeout
	if timeout == 0 {
		timeout = 15 * time.Second
	}
	conn, err := net.DialTimeout("unix", s.Endpoint, timeout)
	if err != nil {
		return errors.New("could not reach the Orca runtime socket; is Orca running?")
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))
	if params == nil {
		params = map[string]any{}
	}
	id := requestID()
	request, err := json.Marshal(map[string]any{"id": id, "authToken": s.Token, "method": method, "params": params})
	if err != nil {
		return err
	}
	if _, err := conn.Write(append(request, '\n')); err != nil {
		return errors.New("could not reach the Orca runtime socket; is Orca running?")
	}
	reader := bufio.NewReaderSize(conn, 1<<16)
	for {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			return fmt.Errorf("Orca runtime closed the connection (%s)", method)
		}
		var reply frame
		if json.Unmarshal(line, &reply) != nil {
			if len(line) > 1 {
				return fmt.Errorf("Orca RPC %s returned an invalid frame", method)
			}
			continue
		}
		if reply.Keepalive || reply.ID != id {
			continue
		}
		return decode(method, reply, out)
	}
}

func decode(method string, reply frame, out any) error {
	if !reply.OK {
		methodErr := &MethodError{Method: method}
		if reply.Error != nil {
			methodErr.Code, methodErr.Message = reply.Error.Code, reply.Error.Message
		}
		return methodErr
	}
	if reply.Result == nil {
		return fmt.Errorf("Orca RPC %s returned no result", method)
	}
	if out == nil {
		return nil
	}
	if err := json.Unmarshal(reply.Result, out); err != nil {
		return fmt.Errorf("Orca RPC %s returned an unexpected result: %w", method, err)
	}
	return nil
}

func requestID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
