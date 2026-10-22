//go:build darwin && cgo

package macos

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework AppKit -framework ApplicationServices
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <stdlib.h>

// Orca's shell exposes its DOM classes through AXDOMClassList; the sidebars
// are found by class and toggled through their labelled buttons.

static id copyAttribute(AXUIElementRef element, NSString *name) {
	CFTypeRef value = NULL;
	if (AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)name, &value) != kAXErrorSuccess) return nil;
	return CFBridgingRelease(value);
}

typedef struct {
	int pid;
	int frontmost;
	int left;   // -1 unknown, 0 hidden, 1 shown
	int right;
	AXUIElementRef leftButton;
	AXUIElementRef rightButton;
	int visited;
	int webAreaSeen;
	NSString *error;
} Snapshot;

static void walk(AXUIElementRef element, int depth, Snapshot *s) {
	if (s->error) return;
	if (++s->visited > 1500 || depth > 40) { s->error = @"Orca accessibility tree exceeded its limit"; return; }
	NSString *role = copyAttribute(element, @"AXRole");
	NSArray *classes = copyAttribute(element, @"AXDOMClassList") ?: @[];
	if ([role isEqualToString:@"AXWebArea"]) {
		if (s->webAreaSeen) return;
		s->webAreaSeen = 1;
	}
	if ([classes containsObject:@"bg-worktree-sidebar"]) {
		NSArray *children = copyAttribute(element, @"AXChildren");
		s->left = children != nil && children.count > 0;
		return;
	}
	if ([classes containsObject:@"right-sidebar-header-drag"]) {
		id parent = copyAttribute(element, @"AXParent");
		NSArray *parentClasses = parent ? (copyAttribute((__bridge AXUIElementRef)parent, @"AXDOMClassList") ?: @[]) : @[];
		if (![parentClasses containsObject:@"flex-shrink-0"] || ![parentClasses containsObject:@"flex-row"]) {
			s->error = @"Unrecognized right sidebar container";
			return;
		}
		if ([parentClasses containsObject:@"overflow-visible"]) s->right = 1;
		else if ([parentClasses containsObject:@"overflow-hidden"]) s->right = 0;
	}
	if ([role isEqualToString:@"AXButton"]) {
		NSString *label = copyAttribute(element, @"AXDescription");
		AXUIElementRef *slot = NULL;
		if ([label isEqualToString:@"Toggle sidebar"]) slot = &s->leftButton;
		else if ([label isEqualToString:@"Toggle right sidebar"]) slot = &s->rightButton;
		if (slot) {
			if (*slot) { s->error = @"Ambiguous sidebar toggle"; return; }
			*slot = (AXUIElementRef)CFRetain(element);
		}
		return;
	}
	if (![@[@"AXWindow", @"AXGroup", @"AXWebArea"] containsObject:role ?: @""]) return;
	if ([classes containsObject:@"xterm"] || [classes containsObject:@"monaco-editor"]) return;
	NSArray *children = copyAttribute(element, @"AXChildren");
	for (id child in children) walk((__bridge AXUIElementRef)child, depth + 1, s);
}

static void release(Snapshot *s) {
	if (s->leftButton) CFRelease(s->leftButton);
	if (s->rightButton) CFRelease(s->rightButton);
	s->leftButton = s->rightButton = NULL;
}

static Snapshot snapshot(int expectedPID) {
	Snapshot s = {0};
	s.left = s.right = -1;
	s.frontmost = [NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier isEqualToString:@"com.stablyai.orca"];
	if (expectedPID && !s.frontmost) { s.error = @"Orca must be frontmost; focus was left unchanged"; return s; }
	NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.stablyai.orca"];
	if (apps.count != 1) { s.error = @"Expected one running Orca application"; return s; }
	s.pid = [apps[0] processIdentifier];
	if (expectedPID && s.pid != expectedPID) { s.error = @"Orca restarted during the toggle"; return s; }
	AXUIElementRef app = AXUIElementCreateApplication(s.pid);
	NSArray *windows = copyAttribute(app, @"AXWindows");
	CFRelease(app);
	if (windows.count != 1) { s.error = @"Expected one Orca window"; return s; }
	AXUIElementRef window = (__bridge AXUIElementRef)windows[0];
	if (![copyAttribute(window, @"AXTitle") isEqual:@"Orca"] || ![copyAttribute(window, @"AXMain") boolValue]) {
		s.error = @"Expected the main Orca window";
		return s;
	}
	walk(window, 0, &s);
	if (!s.error && (s.left < 0 || s.right < 0 || !s.leftButton || !s.rightButton)) {
		s.error = @"Sidebar controls unavailable; open an Orca workspace in the English interface";
	}
	return s;
}

// Returns a malloc'd JSON object: {pid, frontmost, left, right} or {error}.
static char *encode(Snapshot *s) {
	NSDictionary *out = s->error ? @{@"error": s->error}
		: @{@"pid": @(s->pid), @"frontmost": (s->frontmost ? @YES : @NO), @"left": (s->left == 1 ? @YES : @NO), @"right": (s->right == 1 ? @YES : @NO)};
	NSData *data = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
	char *json = malloc(data.length + 1);
	memcpy(json, data.bytes, data.length);
	json[data.length] = 0;
	return json;
}

static char *inspectSidebars(int expectedPID) {
	@autoreleasepool {
		if (!AXIsProcessTrusted()) {
			Snapshot s = {0};
			s.error = @"Accessibility permission is required for this launcher";
			return encode(&s);
		}
		Snapshot s = snapshot(expectedPID);
		release(&s);
		return encode(&s);
	}
}

static char *setSidebars(int pid, int left, int right) {
	@autoreleasepool {
		if (!AXIsProcessTrusted()) {
			Snapshot s = {0};
			s.error = @"Accessibility permission is required for this launcher";
			return encode(&s);
		}
		Snapshot state = snapshot(pid);
		int desired[2] = {left, right};
		for (int side = 0; side < 2 && !state.error; side++) {
			release(&state);
			state = snapshot(pid);
			if (state.error) break;
			int current = side == 0 ? state.left : state.right;
			if (current == desired[side]) continue;
			AXUIElementRef button = side == 0 ? state.leftButton : state.rightButton;
			if (AXUIElementPerformAction(button, kAXPressAction) != kAXErrorSuccess) {
				state.error = side == 0 ? @"Could not press the left sidebar toggle" : @"Could not press the right sidebar toggle";
				break;
			}
			NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.5];
			do {
				release(&state);
				state = snapshot(pid);
				current = side == 0 ? state.left : state.right;
				if (state.error || current == desired[side]) break;
				[NSThread sleepForTimeInterval:0.02];
			} while ([deadline timeIntervalSinceNow] > 0);
			if (!state.error && current != desired[side]) {
				state.error = side == 0 ? @"The left sidebar did not change" : @"The right sidebar did not change";
			}
		}
		release(&state);
		return encode(&state);
	}
}
*/
import "C"

import (
	"encoding/json"
	"errors"
	"unsafe"
)

// SidebarState is Orca's window and sidebar visibility.
type SidebarState struct {
	PID       int    `json:"pid"`
	Frontmost bool   `json:"frontmost"`
	Left      bool   `json:"left"`
	Right     bool   `json:"right"`
	Error     string `json:"error"`
}

func decodeSidebars(raw *C.char) (SidebarState, error) {
	defer C.free(unsafe.Pointer(raw))
	var state SidebarState
	if err := json.Unmarshal([]byte(C.GoString(raw)), &state); err != nil {
		return SidebarState{}, errors.New("Unexpected Orca sidebar state")
	}
	if state.Error != "" {
		return SidebarState{}, errors.New(state.Error)
	}
	return state, nil
}

// InspectSidebars reads Orca's sidebars; expectedPID 0 skips the frontmost
// and same-process checks.
func InspectSidebars(expectedPID int) (SidebarState, error) {
	return decodeSidebars(C.inspectSidebars(C.int(expectedPID)))
}

// SetSidebars presses each sidebar toggle that differs and waits up to 1.5 s
// for it to take effect.
func SetSidebars(pid int, left, right bool) (SidebarState, error) {
	return decodeSidebars(C.setSidebars(C.int(pid), boolInt(left), boolInt(right)))
}

func boolInt(v bool) C.int {
	if v {
		return 1
	}
	return 0
}
