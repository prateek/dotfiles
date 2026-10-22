package main

import (
	"os"
	"path/filepath"
	goruntime "runtime"

	"github.com/spf13/cobra"

	"github.com/prateek/dotfiles/src/orcactl/internal/macos"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
	"github.com/prateek/dotfiles/src/orcactl/internal/zen"
)

type accessibility struct{}

func (accessibility) Sidebars(expectedPID int) (zen.State, error) {
	s, err := macos.InspectSidebars(expectedPID)
	return zen.State{PID: s.PID, Frontmost: s.Frontmost, Left: s.Left, Right: s.Right}, err
}

func (accessibility) SetSidebars(pid int, left, right bool) (zen.State, error) {
	s, err := macos.SetSidebars(pid, left, right)
	return zen.State{PID: s.PID, Frontmost: s.Frontmost, Left: s.Left, Right: s.Right}, err
}

// zenStateDir is shared with the earlier orca-zen-mode script, so a view saved
// by either restores through the other.
func zenStateDir() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(base, "orca-zen-mode")
}

func zenCommand() *cobra.Command {
	status := false
	cmd := &cobra.Command{
		Use:   "zen",
		Short: "Toggle Orca between the current project alone and the previous view",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			if goruntime.GOOS != "darwin" {
				return &exitError{message: "Orca Zen mode requires macOS"}
			}
			toggler := zen.Toggler{UserData: runtime.UserData(), StateDir: zenStateDir(), Desktop: accessibility{}}
			var result map[string]any
			var err error
			if status {
				result, err = toggler.Status()
			} else {
				result, err = toggler.Toggle()
			}
			if err != nil || result == nil {
				return err
			}
			return printJSON(result)
		},
	}
	cmd.Flags().BoolVar(&status, "status", false, "inspect without changing the view")
	return cmd
}
