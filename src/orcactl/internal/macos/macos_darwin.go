//go:build darwin && cgo

// Package macos calls AppKit for what orcactl needs from the desktop.
package macos

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework AppKit
#import <AppKit/AppKit.h>
#include <stdlib.h>

static char *frontmostBundleID(void) {
	@autoreleasepool {
		const char *id = NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier.UTF8String;
		return id ? strdup(id) : NULL;
	}
}

static int copyText(const char *text) {
	@autoreleasepool {
		NSPasteboard *board = NSPasteboard.generalPasteboard;
		[board clearContents];
		return [board setString:[NSString stringWithUTF8String:text] forType:NSPasteboardTypeString] ? 1 : 0;
	}
}

static int openURL(const char *text) {
	@autoreleasepool {
		NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:text]];
		if (url == nil || [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:url] == nil) return 0;
		return [NSWorkspace.sharedWorkspace openURL:url] ? 1 : 0;
	}
}
*/
import "C"

import "unsafe"

// FrontmostBundleID is the bundle identifier of the frontmost application.
func FrontmostBundleID() string {
	id := C.frontmostBundleID()
	if id == nil {
		return ""
	}
	defer C.free(unsafe.Pointer(id))
	return C.GoString(id)
}

// CopyText replaces the general pasteboard's contents with text.
func CopyText(text string) bool {
	value := C.CString(text)
	defer C.free(unsafe.Pointer(value))
	return C.copyText(value) == 1
}

// OpenURL opens url with its registered handler; false when none is registered.
func OpenURL(url string) bool {
	value := C.CString(url)
	defer C.free(unsafe.Pointer(value))
	return C.openURL(value) == 1
}
