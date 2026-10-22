//go:build !darwin

// Package macos calls AppKit for what orcactl needs from the desktop; other
// platforms get no desktop integration.
package macos

import "errors"

var errUnsupported = errors.New("Orca Zen mode requires macOS")

// FrontmostBundleID is unknown off macOS.
func FrontmostBundleID() string { return "" }

// CopyText is unavailable off macOS.
func CopyText(string) bool { return false }

// OpenURL is unavailable off macOS.
func OpenURL(string) bool { return false }

// SidebarState is Orca's window and sidebar visibility.
type SidebarState struct {
	PID       int
	Frontmost bool
	Left      bool
	Right     bool
}

// InspectSidebars needs macOS accessibility.
func InspectSidebars(int) (SidebarState, error) {
	return SidebarState{}, errUnsupported
}

// SetSidebars needs macOS accessibility.
func SetSidebars(int, bool, bool) (SidebarState, error) {
	return SidebarState{}, errUnsupported
}
