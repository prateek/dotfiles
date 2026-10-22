//go:build darwin && !cgo

package macos

// orcactl on macOS needs cgo for AppKit; without it every hotkey would
// silently report "Not in Orca". Install the Xcode command-line tools.
var _ = cgoIsRequiredOnDarwin
