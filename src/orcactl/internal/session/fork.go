package session

import (
	"fmt"
	"os"
	"path/filepath"
)

// ForkCommand is the agent's native fork of s. Resuming the source instead
// would create a second writer on one conversation, so agents without a
// native fork get an error.
func ForkCommand(s Session) ([]string, error) {
	id := s.SessionID
	switch s.Agent {
	case "claude":
		return []string{"claude", "--dangerously-skip-permissions", "--resume", id, "--fork-session"}, nil
	case "codex":
		home := s.CodexHome
		if home == "" && s.ExecutionHostID != "" && s.ExecutionHostID != "local" {
			return nil, fmt.Errorf("The remote Codex account home is unknown; Orca must report its transcript path")
		}
		if home == "" {
			userHome, _ := os.UserHomeDir()
			home = filepath.Join(userHome, ".codex")
		}
		return []string{"env", "CODEX_HOME=" + home, "codex", "--dangerously-bypass-approvals-and-sandbox", "fork", id}, nil
	case "pi", "omp":
		if s.FilePath == "" {
			return nil, fmt.Errorf("The focused %s transcript path is unknown; refusing an ambiguous fork", s.Agent)
		}
		return []string{s.Agent, "--fork", s.FilePath}, nil
	case "droid":
		return []string{"droid", "--fork", id}, nil
	}
	return nil, nil
}
