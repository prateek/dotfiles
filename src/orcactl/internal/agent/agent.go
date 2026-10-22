// Package agent identifies the agent in a pane and its native fork command.
package agent

import (
	"errors"
	"path"
	"regexp"
	"strings"

	"github.com/prateek/dotfiles/src/orcactl/internal/focus"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

// Orca reports the pane's foreground process; the AI vault keys sessions by
// agent name. These differ for a handful of agents (Orca's tui-agent-config
// detectCmd → agent key). Unlisted names pass through.
var vaultAgentByProcess = map[string]string{
	"agent":        "cursor",
	"agy":          "antigravity",
	"auggie":       "aug",
	"cn":           "continue",
	"cursor-agent": "cursor",
	"kiro-cli":     "kiro",
	"mimo":         "mimo-code",
	"qwen":         "qwen-code",
	"traecli":      "trae",
	"vibe":         "mistral-vibe",
}

// Shells and shared interpreters cannot identify an agent on their own.
var genericProcesses = map[string]bool{
	"zsh": true, "bash": true, "fish": true, "sh": true, "login": true,
	"nu": true, "tcsh": true, "node": true, "bun": true,
}

// Native Claude runs ~/.local/share/claude/versions/<version>.
var versionName = regexp.MustCompile(`^\d+(?:\.\d+)+$`)

// Refusals that mean the pane has no identifiable agent, as opposed to Orca
// being unreachable.
var (
	ErrNotRunning   = errors.New("No agent running in the focused terminal")
	ErrUnidentified = errors.New("Could not identify the agent in the focused terminal")
)

// Identity is the pane's agent and the conversation Orca bound to it, if the
// binding belongs to that agent.
type Identity struct {
	Agent           string
	ProviderSession focus.ProviderSession
}

// ProcessAgent maps a foreground process path to a vault agent name; "" means
// the process cannot identify the agent.
func ProcessAgent(foreground string) string {
	name := strings.TrimSuffix(strings.ToLower(path.Base(foreground)), ".exe")
	switch {
	case foreground == "" || name == "" || genericProcesses[name]:
		return ""
	case versionName.MatchString(name):
		return "claude"
	case vaultAgentByProcess[name] != "":
		return vaultAgentByProcess[name]
	default:
		return name
	}
}

// Identify uses Orca's own detection. Method errors on the probes, such as a
// half-dead pane, count as "no answer"; transport errors abort.
func Identify(rt runtime.Caller, pane focus.Pane) (Identity, error) {
	var status struct {
		AgentStatus struct {
			IsRunningAgent bool `json:"isRunningAgent"`
		} `json:"agentStatus"`
	}
	if err := rt.Call("terminal.agentStatus", map[string]any{"terminal": pane.Terminal}, &status); err != nil && !runtime.IsMethodError(err) {
		return Identity{}, err
	}
	if !status.AgentStatus.IsRunningAgent {
		return Identity{}, ErrNotRunning
	}
	var process struct {
		Process struct {
			ForegroundProcess string `json:"foregroundProcess"`
		} `json:"process"`
	}
	if err := rt.Call("terminal.inspectProcess", map[string]any{"terminal": pane.Terminal}, &process); err != nil && !runtime.IsMethodError(err) {
		return Identity{}, err
	}
	reported := pane.LaunchAgent
	var binding focus.ProviderSession
	var boundAgent string
	if pane.AgentStatus != nil {
		boundAgent, binding = pane.AgentStatus.AgentType, pane.AgentStatus.ProviderSession
		if boundAgent != "" {
			reported = boundAgent
		}
	}
	name := ProcessAgent(process.Process.ForegroundProcess)
	if name == "" {
		name = reported
	}
	if name == "" {
		return Identity{}, ErrUnidentified
	}
	if boundAgent != name {
		binding = focus.ProviderSession{}
	}
	return Identity{Agent: name, ProviderSession: binding}, nil
}
