package runtime

import (
	"bytes"
	"context"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"time"
)

// The adapter loads Orca's packaged runtime client, which owns the pairing
// authentication and encryption orcactl does not re-implement.
//
//go:embed paired-adapter.cjs
var pairedAdapter []byte

// Paired calls a saved paired server through Orca's packaged runtime client.
type Paired struct {
	CLI         string // Orca's CLI launcher, resolved on PATH
	UserData    string
	Environment string
	Timeout     time.Duration
}

func (p *Paired) WithTimeout(d time.Duration) Caller {
	copied := *p
	copied.Timeout = d
	return &copied
}

func (p *Paired) Call(method string, params any, out any) error {
	timeout := p.Timeout
	if timeout == 0 {
		timeout = 15 * time.Second
	}
	launcher, err := exec.LookPath(p.CLI)
	if err != nil {
		return fmt.Errorf("%s CLI not found on PATH", p.CLI)
	}
	real, err := filepath.EvalSymlinks(launcher)
	if err != nil {
		return fmt.Errorf("%s CLI not found on PATH", p.CLI)
	}
	resources := filepath.Dir(filepath.Dir(real))
	executable := filepath.Join(filepath.Dir(resources), "orca-ide")
	if goruntime.GOOS == "darwin" {
		executable = filepath.Join(filepath.Dir(resources), "MacOS", "Orca")
	}
	adapter, err := adapterPath()
	if err != nil {
		return err
	}
	if params == nil {
		params = map[string]any{}
	}
	request, err := json.Marshal(map[string]any{
		"resources": resources, "userData": p.UserData, "environment": p.Environment,
		"method": method, "params": params, "timeoutMs": timeout.Milliseconds(),
	})
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout+5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, executable, adapter)
	cmd.Stdin = bytes.NewReader(request)
	cmd.Env = append(os.Environ(), "ELECTRON_RUN_AS_NODE=1")
	stdout, _ := cmd.Output()
	unavailable := errors.New("could not reach the selected paired Orca server through its packaged runtime client")
	var reply struct {
		frame
		TransportError bool `json:"transportError"`
	}
	if json.Unmarshal(stdout, &reply) != nil {
		return unavailable
	}
	if !reply.OK && reply.TransportError {
		message := "paired server unavailable"
		var code string
		if reply.Error != nil {
			message, code = reply.Error.Message, reply.Error.Code
		}
		if code != "" {
			return fmt.Errorf("Orca RPC %s failed: %s (%s)", method, message, code)
		}
		return fmt.Errorf("Orca RPC %s failed: %s", method, message)
	}
	return decode(method, reply.frame, out)
}

// adapterPath writes the embedded adapter once per content hash, because
// Electron's Node mode runs scripts from files.
func adapterPath() (string, error) {
	sum := sha256.Sum256(pairedAdapter)
	dir, err := os.UserCacheDir()
	if xdg := os.Getenv("XDG_CACHE_HOME"); xdg != "" {
		dir, err = xdg, nil
	}
	if err != nil {
		return "", err
	}
	dir = filepath.Join(dir, "orcactl")
	path := filepath.Join(dir, "paired-adapter-"+hex.EncodeToString(sum[:8])+".cjs")
	if _, err := os.Stat(path); err == nil {
		return path, nil
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	tmp, err := os.CreateTemp(dir, "paired-adapter-*.cjs")
	if err != nil {
		return "", err
	}
	if _, err := tmp.Write(pairedAdapter); err != nil {
		tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	return path, os.Rename(tmp.Name(), path)
}
