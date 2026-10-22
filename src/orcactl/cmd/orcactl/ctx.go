package main

import (
	"errors"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/prateek/dotfiles/src/orcactl/internal/agent"
	"github.com/prateek/dotfiles/src/orcactl/internal/focus"
	"github.com/prateek/dotfiles/src/orcactl/internal/profile"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
)

type contextTerminal struct {
	Handle    string  `json:"handle"`
	Title     string  `json:"title"`
	Agent     *string `json:"agent"`
	SessionID *string `json:"session_id"`
	Host      string  `json:"host"`
}

type contextWorktree struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Path string `json:"path"`
}

type orcaContext struct {
	Active struct {
		Worktree contextWorktree `json:"worktree"`
		Terminal contextTerminal `json:"terminal"`
	} `json:"active"`
}

// connect picks the runtime for an environment; tests substitute it.
var connect = runtime.For

// capture reads route and focus; every command acts on what it returns.
func capture(worktreePath string) (runtime.Caller, focus.Focus, error) {
	userData := runtime.UserData()
	environment, err := profile.SelectedEnvironment(userData)
	if err != nil {
		return nil, focus.Focus{}, err
	}
	rt, err := connect(userData, environment)
	if err != nil {
		return nil, focus.Focus{}, err
	}
	captured, err := focus.Capture(rt, worktreePath, environment)
	return rt, captured, err
}

func buildContext() (orcaContext, error) {
	var out orcaContext
	rt, captured, err := capture("")
	if err != nil {
		return out, err
	}
	out.Active.Worktree = contextWorktree{ID: captured.Worktree.WorktreeID, Name: captured.Worktree.DisplayName, Path: captured.Worktree.Path}
	out.Active.Terminal = contextTerminal{Handle: captured.Pane.Terminal, Title: captured.Pane.Title, Host: captured.Host}
	identity, err := agent.Identify(rt, captured.Pane)
	if errors.Is(err, agent.ErrNotRunning) || errors.Is(err, agent.ErrUnidentified) {
		// A focused shell is a valid context: it simply has no agent.
		return out, nil
	}
	if err != nil {
		return out, err
	}
	out.Active.Terminal.Agent = &identity.Agent
	if id := identity.ProviderSession.ID; id != "" {
		out.Active.Terminal.SessionID = &id
	}
	return out, nil
}

func ctxCommand(jsonOutput *bool) *cobra.Command {
	return &cobra.Command{
		Use:   "ctx",
		Short: "Show the Orca workspace and pane in focus, and its agent",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			context, err := buildContext()
			if err != nil {
				return err
			}
			if *jsonOutput {
				return printJSON(context)
			}
			terminal := context.Active.Terminal
			agentName := "none"
			if terminal.Agent != nil {
				agentName = *terminal.Agent
			}
			fmt.Fprintf(stdout, "%s  %s  %s  agent=%s\n", context.Active.Worktree.Path, terminal.Handle, terminal.Host, agentName)
			return nil
		},
	}
}
