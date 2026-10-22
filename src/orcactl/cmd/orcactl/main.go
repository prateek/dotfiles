// Command orcactl works with Orca from launchers, hotkeys, and agents.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"

	"github.com/spf13/cobra"
)

// exitError carries a message and whether the failure is benign (exit 0), such
// as a hotkey pressed outside Orca.
type exitError struct {
	message string
	benign  bool
}

func (e *exitError) Error() string { return e.message }

func benign(message string) error { return &exitError{message: message, benign: true} }

// stdout and stderr are where commands print; tests capture them.
var (
	stdout io.Writer = os.Stdout
	stderr io.Writer = os.Stderr
)

func main() {
	launcherPath()
	os.Exit(run(os.Args[1:]))
}

// launcherPath appends Homebrew's directories when missing: Raycast, Tuna,
// and Karabiner start commands with a minimal PATH, and orcactl runs the Orca
// CLI's Electron and agentsview from it.
func launcherPath() {
	path := os.Getenv("PATH")
	for _, dir := range []string{"/opt/homebrew/bin", "/usr/local/bin"} {
		if !slices.Contains(filepath.SplitList(path), dir) {
			path += string(os.PathListSeparator) + dir
		}
	}
	os.Setenv("PATH", path)
}

// run executes one invocation and returns its exit status.
func run(args []string) int {
	jsonOutput := false
	root := &cobra.Command{
		Use:           "orcactl",
		Short:         "Work with Orca from launchers, hotkeys, and agents",
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	root.SetArgs(args)
	root.SetOut(stdout)
	root.PersistentFlags().BoolVar(&jsonOutput, "json", false, "print JSON")
	root.AddCommand(ctxCommand(&jsonOutput), sesCommand(&jsonOutput), agentsCommand(&jsonOutput), zenCommand())
	cmd, err := root.ExecuteC()
	if err == nil {
		return 0
	}
	switch {
	case jsonOutput:
		_ = printJSON(map[string]string{"error": err.Error()})
	case cmd != nil && cmd.Name() == "zen":
		// Zen's stdout is its JSON result; launchers that surface errors read stderr.
		fmt.Fprintln(stderr, "orcactl zen: "+err.Error())
	default:
		// Raycast's silent mode shows a script's last stdout line as its HUD.
		fmt.Fprintln(stdout, err.Error())
	}
	var exit *exitError
	if errors.As(err, &exit) && exit.benign {
		return 0
	}
	return 1
}

// printJSON leaves &, <, and > unescaped: output feeds shells and scripts, not HTML.
func printJSON(value any) error {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		return err
	}
	_, err := stdout.Write(buf.Bytes())
	return err
}
