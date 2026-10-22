package runtime

import (
	"os"
	"path/filepath"
	goruntime "runtime"
)

// UserData is Orca's user-data directory, honoring Orca's own override.
func UserData() string {
	if dir := os.Getenv("ORCA_USER_DATA_PATH"); dir != "" {
		return dir
	}
	home, _ := os.UserHomeDir()
	if goruntime.GOOS == "darwin" {
		return filepath.Join(home, "Library", "Application Support", "orca")
	}
	config := os.Getenv("XDG_CONFIG_HOME")
	if config == "" {
		config = filepath.Join(home, ".config")
	}
	return filepath.Join(config, "orca")
}

// CLI is the Orca launcher name for this session: Orca's export for managed
// sessions, the dev launcher in a dev checkout, `orca-ide` on Linux (bare
// `orca` there is the GNOME screen reader), else `orca`.
func CLI() string {
	if cli := os.Getenv("ORCA_CLI_COMMAND"); cli != "" {
		return cli
	}
	if os.Getenv("ORCA_DEV_REPO_ROOT") != "" {
		return "orca-dev"
	}
	if goruntime.GOOS == "linux" {
		return "orca-ide"
	}
	return "orca"
}

// For returns the caller for the runtime that owns the focused workspace:
// the paired environment when one is selected, else the desktop's socket.
func For(userData, environment string) (Caller, error) {
	if environment != "" {
		return &Paired{CLI: CLI(), UserData: userData, Environment: environment}, nil
	}
	return LocalSocket(userData)
}
