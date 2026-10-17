const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');

function fixture(left, right, {frontmost = true, malformed = false, loseFocus = false} = {}) {
  const state = {left, right, frontmost, pressed: []};
  const array = values => ({count: String(values.length), objectAtIndex: index => values[index]});
  const element = (role, classes = [], children = [], attributes = {}) => {
    const result = {AXRole: role, AXDOMClassList: classes, AXChildren: array(children), ...attributes};
    for (const child of children) child.AXParent = result;
    return result;
  };
  function window() {
    const button = (label, side) => element('AXButton', [], [], {AXDescription: label, side});
    const leftToggle = button('Toggle sidebar', 'left');
    const rightToggle = button('Toggle right sidebar', 'right');
    const header = element('AXGroup', ['right-sidebar-header-drag'], state.right ? [rightToggle] : []);
    const panel = element('AXGroup', malformed ? [] : [
      'relative', 'flex-shrink-0', 'flex', 'flex-row', state.right ? 'overflow-visible' : 'overflow-hidden'
    ], [header]);
    const body = [leftToggle, panel];
    body.push(element('AXGroup', ['bg-worktree-sidebar'], state.left ? [element('AXGroup')] : []));
    if (!state.right) body.push(rightToggle);
    // A web page may contain lookalike sidebar controls. Only Orca's root web area counts.
    body.push(element('AXWebArea', [], [button('Toggle sidebar', 'decoy')]));
    return element('AXWindow', [], [element('AXWebArea', [], body)], {AXTitle: 'Orca', AXMain: true});
  }
  const $ = value => value;
  Object.assign($, {
    NSWorkspace: {sharedWorkspace: {get frontmostApplication() {
      return {bundleIdentifier: state.frontmost ? 'com.stablyai.orca' : 'another.app'};
    }}},
    NSRunningApplication: {runningApplicationsWithBundleIdentifier: () => array([{processIdentifier: 123}])},
    AXUIElementCreateApplication: () => ({AXWindows: array([window()])}),
    AXUIElementCopyAttributeValue: (node, key, output) => {
      if (!(key in node)) return -1;
      output[0] = node[key];
      return 0;
    },
    AXUIElementPerformAction: (node, action) => {
      assert.equal(action, 'AXPress');
      assert.ok(state.frontmost);
      assert.ok(['left', 'right'].includes(node.side));
      state[node.side] = !state[node.side];
      state.pressed.push(node.side);
      if (loseFocus) state.frontmost = false;
      return 0;
    },
    AXIsProcessTrusted: () => true,
    NSThread: {sleepForTimeInterval: () => { throw Error('unexpected wait'); }}
  });
  const context = vm.createContext({$, Ref: () => [], ObjC: {
    import() {}, castRefToObject: value => value, unwrap: value => value, deepUnwrap: value => value
  }});
  vm.runInContext(source, context);
  return {state, run: args => JSON.parse(context.run(args))};
}

for (const left of [false, true]) for (const right of [false, true]) {
  const {run, state} = fixture(left, right);
  assert.deepEqual(run([]), {pid: 123, frontmost: true, left, right});
  assert.deepEqual(run(['123', 'false', 'false']), {pid: 123, frontmost: true, left: false, right: false});
  assert.deepEqual(state.pressed, [...(left ? ['left'] : []), ...(right ? ['right'] : [])]);
  assert.deepEqual(run(['123', String(left), String(right)]), {pid: 123, frontmost: true, left, right});
}
const background = fixture(true, true, {frontmost: false});
assert.equal(background.run([]).frontmost, false);
assert.throws(() => background.run(['123', 'false', 'false']), /frontmost/);
assert.deepEqual(background.state.pressed, []);
const changed = fixture(true, true, {loseFocus: true});
assert.throws(() => changed.run(['123', 'false', 'false']), /frontmost/);
assert.deepEqual(changed.state.pressed, ['left']);
const unknown = fixture(true, true, {malformed: true});
assert.throws(() => unknown.run(['123', 'false', 'false']), /Unrecognized right sidebar/);
assert.deepEqual(unknown.state.pressed, []);
const restarted = fixture(true, true);
assert.throws(() => restarted.run(['456', 'false', 'false']), /restarted/);
assert.deepEqual(restarted.state.pressed, []);
