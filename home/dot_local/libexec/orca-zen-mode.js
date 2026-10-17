// Orca 1.4.224 exposes its shell classes through AXDOMClassList.
ObjC.import('AppKit');
ObjC.import('ApplicationServices');

function attribute(element, name) {
    const result = Ref();
    if ($.AXUIElementCopyAttributeValue(element, $(name), result) !== 0) return null;
    return ObjC.castRefToObject(result[0]);
}

function value(element, name) {
    return ObjC.deepUnwrap(attribute(element, name));
}

function snapshot(expectedPid) {
    const frontmost = ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier) === 'com.stablyai.orca';
    if (expectedPid && !frontmost) {
        throw Error('Orca must be frontmost; focus was left unchanged');
    }
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier('com.stablyai.orca');
    if (Number(apps.count) !== 1) throw Error('Expected one running Orca application');
    const app = apps.objectAtIndex(0);
    const pid = app.processIdentifier;
    if (expectedPid && pid !== expectedPid) throw Error('Orca restarted during the toggle');
    const windows = attribute($.AXUIElementCreateApplication(pid), 'AXWindows');
    if (!windows || Number(windows.count) !== 1) throw Error('Expected one Orca window');
    const window = windows.objectAtIndex(0);
    if (value(window, 'AXTitle') !== 'Orca' || !value(window, 'AXMain')) {
        throw Error('Expected the main Orca window');
    }
    const result = {pid, frontmost, left: null, right: null, buttons: {}};
    let visited = 0;
    let webAreaSeen = false;
    function walk(element, depth) {
        if (++visited > 1500 || depth > 40) throw Error('Orca accessibility tree exceeded its limit');
        const role = value(element, 'AXRole');
        const classes = value(element, 'AXDOMClassList') || [];
        if (role === 'AXWebArea') {
            if (webAreaSeen) return;
            webAreaSeen = true;
        }
        if (classes.includes('bg-worktree-sidebar')) {
            const children = attribute(element, 'AXChildren');
            result.left = children !== null && Number(children.count) > 0;
            return;
        }
        if (classes.includes('right-sidebar-header-drag')) {
            const parent = value(attribute(element, 'AXParent'), 'AXDOMClassList') || [];
            if (!parent.includes('flex-shrink-0') || !parent.includes('flex-row')) {
                throw Error('Unrecognized right sidebar container');
            }
            if (parent.includes('overflow-visible')) result.right = true;
            else if (parent.includes('overflow-hidden')) result.right = false;
        }
        if (role === 'AXButton') {
            const label = value(element, 'AXDescription');
            const side = {'Toggle sidebar': 'left', 'Toggle right sidebar': 'right'}[label];
            if (side) {
                if (result.buttons[side]) throw Error('Ambiguous sidebar toggle');
                result.buttons[side] = element;
            }
            return;
        }
        if (!['AXWindow', 'AXGroup', 'AXWebArea'].includes(role)) return;
        if (classes.includes('xterm') || classes.includes('monaco-editor')) return;
        const children = attribute(element, 'AXChildren');
        if (children) for (let i = 0; i < children.count; i++) walk(children.objectAtIndex(i), depth + 1);
    }
    walk(window, 0);
    if (result.left === null || result.right === null || !result.buttons.left || !result.buttons.right) {
        throw Error('Sidebar controls unavailable; open an Orca workspace in the English interface');
    }
    return result;
}

function run(args) {
    if (!$.AXIsProcessTrusted()) throw Error('Accessibility permission is required for this launcher');
    if (args.length !== 0 && (args.length !== 3 || !/^\d+$/.test(args[0])
        || !args.slice(1).every(v => v === 'true' || v === 'false'))) {
        throw Error('Expected PID LEFT RIGHT, with boolean sidebar states');
    }
    let state = snapshot(args.length ? Number(args[0]) : null);
    if (args.length) {
        const pid = state.pid;
        for (const [index, side] of ['left', 'right'].entries()) {
            const desired = args[index + 1] === 'true';
            state = snapshot(pid);
            if (state[side] === desired) continue;
            if ($.AXUIElementPerformAction(state.buttons[side], $('AXPress')) !== 0) {
                throw Error('Could not press the ' + side + ' sidebar toggle');
            }
            const deadline = Date.now() + 1500;
            do {
                state = snapshot(pid);
                if (state[side] === desired) break;
                $.NSThread.sleepForTimeInterval(0.02);
            } while (Date.now() < deadline);
            if (state[side] !== desired) throw Error('The ' + side + ' sidebar did not change');
        }
    }
    return JSON.stringify({pid: state.pid, frontmost: state.frontmost, left: state.left, right: state.right});
}
