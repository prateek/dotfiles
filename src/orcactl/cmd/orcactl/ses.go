package main

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/spf13/cobra"

	"github.com/prateek/dotfiles/src/orcactl/internal/agent"
	"github.com/prateek/dotfiles/src/orcactl/internal/macos"
	"github.com/prateek/dotfiles/src/orcactl/internal/profile"
	"github.com/prateek/dotfiles/src/orcactl/internal/runtime"
	"github.com/prateek/dotfiles/src/orcactl/internal/session"
)

const orcaBundleID = "com.stablyai.orca"

type sesOptions struct {
	json     *bool
	copy     bool
	dryRun   bool
	worktree string
}

func sesCommand(jsonOutput *bool) *cobra.Command {
	ses := &cobra.Command{Use: "ses", Aliases: []string{"session", "s"}, Short: "Act on the agent session in Orca's focused pane"}
	ses.AddCommand(sessionAction(jsonOutput, false), sessionAction(jsonOutput, true))
	return ses
}

func sessionAction(jsonOutput *bool, fork bool) *cobra.Command {
	opts := &sesOptions{json: jsonOutput}
	cmd := &cobra.Command{
		Use:   "reveal",
		Short: "Copy the focused session's ID and open it in AgentsView",
		Args:  cobra.NoArgs,
		RunE:  func(*cobra.Command, []string) error { return runSession(fork, *opts) },
	}
	if fork {
		cmd.Use, cmd.Short = "fork", "Fork the focused session into a split beside its pane"
		cmd.Flags().BoolVar(&opts.dryRun, "dry-run", false, "print the fork plan without splitting")
	}
	cmd.Flags().BoolVar(&opts.copy, "copy", false, "copy the session ID even with --json")
	cmd.Flags().StringVar(&opts.worktree, "worktree", "", "workspace path (default: Orca's focused workspace)")
	return cmd
}

func runSession(fork bool, opts sesOptions) error {
	hud := !*opts.json
	if hud && opts.worktree == "" && macos.FrontmostBundleID() != orcaBundleID {
		return benign("Not in Orca")
	}
	path := ""
	if opts.worktree != "" {
		abs, err := filepath.Abs(expandHome(opts.worktree))
		if err != nil {
			return err
		}
		path = abs
	}
	rt, captured, err := capture(path)
	if err != nil {
		return err
	}
	identity, err := agent.Identify(rt, captured.Pane)
	if err != nil {
		return err
	}
	found, err := session.Find(rt, captured, identity)
	if err != nil {
		return err
	}
	id := found.SessionID
	copied := false
	if opts.copy || hud {
		copied = macos.CopyText(id)
	}
	if fork {
		return forkSession(rt, captured.Pane.Terminal, captured.Worktree.Path, captured.Host, found, copied, opts)
	}
	if hud {
		note := "copy failed"
		if copied {
			note = "ID copied"
		}
		if target := revealInAgentsView(id); target != "" {
			fmt.Fprintf(stdout, "%s %s → %s (%s)\n", found.Agent, short(id), target, note)
		} else {
			fmt.Fprintf(stdout, "%s %s — agentsview not running; launch AgentsView (%s)\n", found.Agent, short(id), note)
		}
		return nil
	}
	var agentsviewURL any
	if base := agentsViewBaseURL(); base != "" {
		agentsviewURL = base + "/sessions/" + url.PathEscape(id)
	}
	return printJSON(map[string]any{
		"agent": found.Agent, "executionHostId": captured.Host, "sessionId": id,
		"title": nullable(found.Title), "cwd": nullable(found.Cwd), "worktree": captured.Worktree.Path,
		"terminalTitle": nullable(captured.Pane.Title), "terminalIsFocusedPane": true,
		"filePath": nullable(found.FilePath), "resumeCommand": nullable(found.ResumeCommand),
		"agentsviewUrl": agentsviewURL,
	})
}

func forkSession(rt runtime.Caller, handle, worktreePath, host string, found session.Session, copied bool, opts sesOptions) error {
	argv, err := session.ForkCommand(found)
	if err != nil {
		return err
	}
	if argv == nil {
		manual := short(found.SessionID)
		if copied {
			manual = "copied"
		}
		return fmt.Errorf("%s can't fork a live session safely — ID %s for manual resume", found.Agent, manual)
	}
	cwd := found.Cwd
	if cwd == "" {
		cwd = worktreePath
	}
	command := "cd " + shellQuote(cwd) + " && " + shellJoin(argv)
	if opts.dryRun {
		if *opts.json {
			return printJSON(map[string]any{"agent": found.Agent, "sessionId": found.SessionID, "forkCommand": command, "executionHostId": host})
		}
		fmt.Fprintf(stdout, "would fork %s %s: %s\n", found.Agent, short(found.SessionID), command)
		return nil
	}
	var split struct {
		Split    *struct{ Handle string } `json:"split"`
		Terminal *struct{ Handle string } `json:"terminal"`
	}
	if err := rt.Call("terminal.split", map[string]any{"terminal": handle, "command": command}, &split); err != nil {
		return err
	}
	var newTerminal any
	if split.Terminal != nil {
		newTerminal = split.Terminal.Handle
	} else if split.Split != nil {
		newTerminal = split.Split.Handle
	}
	if *opts.json {
		return printJSON(map[string]any{"agent": found.Agent, "sessionId": found.SessionID, "forkCommand": command,
			"newTerminal": newTerminal, "executionHostId": host})
	}
	fmt.Fprintf(stdout, "forked %s %s → new split\n", found.Agent, short(found.SessionID))
	return nil
}

func agentsCommand(jsonOutput *bool) *cobra.Command {
	return &cobra.Command{
		Use:   "agents",
		Short: "List agents installed for the active Orca runtime",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			userData := runtime.UserData()
			environment, err := profile.SelectedEnvironment(userData)
			if err != nil {
				return err
			}
			rt, err := connect(userData, environment)
			if err != nil {
				return err
			}
			var agents []any
			if err := rt.Call("preflight.detectAgents", map[string]any{}, &agents); err != nil {
				return err
			}
			names := []string{}
			for _, entry := range agents {
				name, ok := entry.(string)
				if !ok {
					return errors.New("Orca returned an invalid agent list")
				}
				names = append(names, name)
			}
			if *jsonOutput {
				return printJSON(map[string]any{"agents": names})
			}
			fmt.Fprintln(stdout, strings.Join(names, "\n"))
			return nil
		},
	}
}

// revealInAgentsView prefers the app's URL scheme, which opens nothing until
// AgentsView registers one, then the running server's web UI.
func revealInAgentsView(id string) string {
	quoted := url.PathEscape(id)
	if macos.OpenURL("agentsview://sessions/" + quoted) {
		return "AgentsView app"
	}
	base := agentsViewBaseURL()
	if base == "" {
		return ""
	}
	if macos.OpenURL(base + "/sessions/" + quoted) {
		return "agentsview (browser)"
	}
	return ""
}

var serverURL = regexp.MustCompile(`https?://\S+`)

// agentsViewBaseURL never starts the daemon; its lifecycle belongs to the
// AgentsView app. `serve status` exits 0 either way, so the URL in its output
// is the liveness signal. Launchers skip shell startup files, so a linked
// ~/.agentsview is passed resolved: through the link, status finds no daemon.
func agentsViewBaseURL() string {
	cmd := exec.Command("agentsview", "serve", "status")
	cmd.Env = os.Environ()
	home, _ := os.UserHomeDir()
	dataDir := filepath.Join(home, ".agentsview")
	if info, err := os.Lstat(dataDir); err == nil && info.Mode()&os.ModeSymlink != 0 && os.Getenv("AGENTSVIEW_DATA_DIR") == "" {
		if resolved, err := filepath.EvalSymlinks(dataDir); err == nil {
			cmd.Env = append(cmd.Env, "AGENTSVIEW_DATA_DIR="+resolved)
		}
	}
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(serverURL.FindString(string(out)), "/")
}

var shellSafe = regexp.MustCompile(`^[A-Za-z0-9@%+=:,./_-]+$`)

// shellQuote matches Python's shlex.quote.
func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	if shellSafe.MatchString(s) {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'"'"'`) + "'"
}

func shellJoin(argv []string) string {
	quoted := make([]string, len(argv))
	for i, arg := range argv {
		quoted[i] = shellQuote(arg)
	}
	return strings.Join(quoted, " ")
}

func short(id string) string {
	if len(id) > 8 {
		return id[:8]
	}
	return id
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func expandHome(path string) string {
	if rest, ok := strings.CutPrefix(path, "~"); ok && (rest == "" || strings.HasPrefix(rest, "/")) {
		home, _ := os.UserHomeDir()
		return home + rest
	}
	return path
}
