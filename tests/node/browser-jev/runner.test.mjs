import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const launcher = fileURLToPath(new URL('../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/run-jev', import.meta.url));
const runnerUrl = new URL('../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/runner.mjs', import.meta.url);

function job() {
  return {
    version: 1, goal: 'Find orchard entries',
    browser: { driver: 'orca', worktree: 'path:/task', pageId: 'p1' },
    provider: { kind: 'cloudflare', model: 'typesafe/jev' },
    limits: { actions: 4, decisions: 6, elapsedMs: 2000 },
    scope: { origins: ['https://fixture.test'], foregroundInput: true,
      controls: [{ selector: '#query', operations: ['FILL'], inputId: 'query' }] },
    inputs: { query: 'orchard' },
    checks: [{ selector: '#query', property: 'value', equals: 'orchard' }],
  };
}

function page() {
  let value = '';
  const effects = [];
  return {
    effects,
    async observe(j) {
      return {
        url: 'https://fixture.test/search', documentId: 'd1', text: 'Search entries', focused: true,
        controls: [{ scopeIndex: 0, selector: '#query', token: 'node1', fingerprint: 'input:text:query',
          visible: true, disabled: false, tag: 'input', type: 'text', label: 'Query', value }],
        checks: j.checks.map((c, index) => ({ index, matched: c.equals === value })),
      };
    },
    async execute(action) { effects.push(action); value = action.value; },
  };
}

const choose = (choice, confidence = 1) => async (request) => {
  const operation = choice.startsWith('c') ? choice.slice(choice.indexOf('_') + 1) : choice;
  const answers = Object.fromEntries(Object.entries(request.questions).map(([name, question]) => [name, {
    type: 'choice', confidence: 1, choice: Object.keys(question.criteria)[0],
  }]));
  answers.operation = { type: 'choice', choice: operation, confidence };
  if (choice.startsWith('c')) answers[`${operation}_target`] = { type: 'choice', choice, confidence: 1 };
  return { model: 'fixture-jev', answers, usage: { input_tokens: 10, output_tokens: 2 } };
};

test('one authorized fill verifies from fresh browser state and preserves an effect receipt', async () => {
  const { runJob } = await import(runnerUrl);
  const browser = page();
  const result = await runJob(job(), { browser, decide: choose('c0_FILL') });
  assert.equal(result.status, 'verified', JSON.stringify(result));
  assert.equal(browser.effects.length, 1);
  assert.equal(browser.effects[0].value, 'orchard');
  assert.equal(result.receipts[0].effect, 'confirmed');
  assert.equal(result.counters.actions, 1);
  assert.equal(result.counters.decisions, 1);
  assert.equal(result.receipts[0].generation, result.decisions[0].generation);
});

test('supplied values deterministically complete a changing page without Jev decisions or selectors', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Show only published entries matching orchard',
    browser: { driver: 'orca', worktree: 'path:/task', pageId: 'p1' },
    scope: { origins: ['https://fixture.test'], foregroundInput: true, discover: true },
    inputs: { query: 'orchard', published: true },
    checks: [
      { selector: '#query', property: 'value', equals: 'orchard' },
      { selector: '#published', property: 'checked', equals: true },
    ],
    confidenceFloor: 0.6,
  };
  let open = false;
  let query = '';
  let published = false;
  const effects = [];
  const control = (index, selector, kind, extra = {}) => ({
    scopeIndex: index, selector, discoveryKind: kind, token: `node${index}`,
    fingerprint: `${kind}:${index}`, visible: true, disabled: false,
    tag: 'button', type: '', label: selector, value: '', checked: null, ...extra,
  });
  const browser = {
    async observe(j) {
      return {
        url: 'https://fixture.test/search', documentId: 'd1',
        text: `Search entries ${open ? 'Published only' : ''} ${query}`,
        focused: true,
        controls: [
          control(1001, '#filters', 'disclosure', { label: 'Filters' }),
          control(1002, '#query', 'fill', { tag: 'input', type: 'text', label: 'Query', id: 'query', value: query }),
          ...(open ? [control(1003, '#published', 'checkbox', { tag: 'input', type: 'checkbox', label: 'Published only', id: 'published', checked: published })] : []),
        ],
        checks: j.checks.map((check, index) => ({ index, matched: check.property === 'value' ? query === check.equals : published === check.equals })),
      };
    },
    async execute(action) {
      effects.push(action.operation);
      if (action.operation === 'CLICK') open = true;
      if (action.operation === 'FILL') query = action.value;
      if (action.operation === 'CHECK') published = true;
    },
  };
  const result = await runJob(intent, { browser, decide() { assert.fail('unexpected Jev decision'); } });
  assert.equal(result.status, 'verified', JSON.stringify(result));
  assert.deepEqual(effects, ['FILL', 'CLICK', 'CHECK']);
  assert.deepEqual(result.receipts.map(receipt => receipt.effect), ['confirmed', 'observed_change', 'confirmed']);
  assert.equal(result.counters.decisions, 0);
  assert.equal(result.decisions.every(decision => decision.source === 'deterministic'), true);
});

for (const [scenario, documentForPage] of [
  ['replaces the document', page => `document-${page}`],
  ['updates the current document', () => 'document-1'],
]) {
  test(`discovered Next page remains usable until the target page is reached when pagination ${scenario}`, async () => {
    const { runJob } = await import(runnerUrl);
    let pageNumber = 1;
    const effects = [];
    const intent = {
      version: 1, goal: 'Reach page 3',
      browser: { driver: 'agent-browser', session: 'owned', pageId: 'tab', config: '/tmp/empty.json' },
      limits: { actions: 3, decisions: 4, elapsedMs: 2000 },
      scope: { origins: ['https://fixture.test'], foregroundInput: false, discover: true },
      checks: [{ selector: '#page', property: 'text', equals: 'Page 3' }],
    };
    const browser = {
      async observe(j) {
        const documentId = documentForPage(pageNumber);
        return {
          url: 'https://fixture.test/entries', documentId, text: `Page ${pageNumber}`,
          controls: [{ scopeIndex: 1001, selector: '#next', discoveryKind: 'pagination',
            token: `${documentId}:1`, fingerprint: 'button:next', visible: true, disabled: false,
            tag: 'button', type: '', label: 'Next page', value: '', checked: null }],
          checks: j.checks.map((_, index) => ({ index, matched: pageNumber === 3 })),
        };
      },
      async execute(action) { effects.push(action.operation); pageNumber++; },
    };
    const result = await runJob(intent, { browser, decide: choose('c1001_CLICK') });
    assert.equal(result.status, 'verified', JSON.stringify(result));
    assert.deepEqual(effects, ['CLICK', 'CLICK']);
  });
}

test('discovery without a deterministic success check returns for verification', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Inspect the current page',
    browser: { driver: 'orca', worktree: 'path:/task', pageId: 'p1' },
    scope: { origins: ['https://fixture.test'], foregroundInput: true, discover: true },
  };
  const browser = { async observe(j) {
    return { url: 'https://fixture.test/', documentId: 'd1', text: 'Current page', focused: true,
      controls: [], checks: j.checks.map((_, index) => ({ index, matched: false })) };
  }, async execute() { assert.fail('unexpected browser mutation'); } };
  const result = await runJob(intent, { browser, decide: choose('DONE') });
  assert.equal(result.status, 'handoff');
  assert.equal(result.reason, 'verification_required');
  assert.equal(result.counters.actions, 0);
});

test('discovery rejects ambiguous value binding before consulting Jev', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Search for orchard',
    browser: { driver: 'agent-browser', session: 'owned', pageId: 'tab', config: '/tmp/empty.json' },
    scope: { origins: ['https://fixture.test'], foregroundInput: false, discover: true },
    inputs: { query: 'orchard' },
  };
  const control = index => ({ scopeIndex: index, selector: `#field${index}`, discoveryKind: 'fill',
    token: `node${index}`, fingerprint: `input:${index}`, visible: true, disabled: false,
    tag: 'input', type: 'text', label: 'Search', id: '', name: 'query', value: '', checked: null });
  const browser = {
    async observe() { return { url: 'https://fixture.test/', documentId: 'd1', text: 'Search',
      controls: [control(1001), control(1002)], checks: [] }; },
    async execute() { assert.fail('unexpected browser mutation'); },
  };
  const result = await runJob(intent, { browser, decide() { assert.fail('unexpected Jev decision'); } });
  assert.equal(result.status, 'handoff');
  assert.equal(result.reason, 'ambiguous_input');
});

test('discovery never offers an external-origin link as an action', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Open the record',
    browser: { driver: 'agent-browser', session: 'owned', pageId: 'tab', config: '/tmp/empty.json' },
    scope: { origins: ['https://fixture.test'], foregroundInput: false, discover: true },
  };
  const browser = {
    async observe() { return { url: 'https://fixture.test/', documentId: 'd1', text: 'Open the record',
      controls: [{ scopeIndex: 1001, selector: '#external', discoveryKind: 'link',
        token: 'node1', fingerprint: 'link:external', visible: true, disabled: false,
        tag: 'a', type: '', label: 'Record', href: 'https://outside.test/record', value: '', checked: null }],
      checks: [] }; },
    async execute() { assert.fail('unexpected browser mutation'); },
  };
  const result = await runJob(intent, { browser, decide: request => {
    assert.equal(request.questions.CLICK_target, undefined);
    return choose('DONE')(request);
  } });
  assert.equal(result.reason, 'verification_required');
  assert.equal(result.counters.actions, 0);
});

test('discovery rejects unsupported false checkbox intent before browser access', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Exclude published entries',
    browser: { driver: 'agent-browser', session: 'owned', pageId: 'tab', config: '/tmp/empty.json' },
    scope: { origins: ['https://fixture.test'], foregroundInput: false, discover: true },
    inputs: { published: false },
  };
  const result = await runJob(intent, {
    browser: { observe() { assert.fail('unexpected browser access'); } },
    decide() { assert.fail('unexpected Jev decision'); },
  });
  assert.equal(result.status, 'failed');
  assert.equal(result.reason, 'invalid_job');
});

test('two Filters disclosures are left for Jev when a requested checkbox is hidden', async () => {
  const { runJob } = await import(runnerUrl);
  const intent = {
    version: 1, goal: 'Show published entries',
    browser: { driver: 'agent-browser', session: 'owned', pageId: 'tab', config: '/tmp/empty.json' },
    scope: { origins: ['https://fixture.test'], foregroundInput: false, discover: true },
    inputs: { published: true },
  };
  const browser = {
    async observe() { return { url: 'https://fixture.test/', documentId: 'd1', text: 'Filters', checks: [],
      controls: [1001, 1002].map(index => ({ scopeIndex: index, selector: `#filters${index}`,
        discoveryKind: 'disclosure', token: `node${index}`, fingerprint: `button:${index}`,
        visible: true, disabled: false, tag: 'button', type: '', label: 'Filters',
        value: '', checked: null })) }; },
    async execute() { assert.fail('unexpected browser mutation'); },
  };
  const result = await runJob(intent, { browser, decide: request => {
    assert.equal(Object.keys(request.questions.CLICK_target.criteria).length, 2);
    return choose('HANDOFF')(request);
  } });
  assert.equal(result.reason, 'model_handoff');
  assert.equal(result.counters.actions, 0);
  assert.equal(result.counters.decisions, 1);
});

test('DONE with a wrong query is a handoff, never a model-certified success', async () => {
  const { runJob } = await import(runnerUrl);
  const browser = page();
  const result = await runJob(job(), { browser, decide: choose('DONE') });
  assert.equal(result.status, 'handoff');
  assert.equal(result.reason, 'verification_failed');
  assert.equal(browser.effects.length, 0);
});

test('missing checks and malformed scope fail before browser or provider I/O', async () => {
  const { runJob } = await import(runnerUrl);
  for (const change of [j => j.checks = [], j => j.scope.origins = ['https://fixture.test/path'],
    j => j.browser.worktree = 'current', j => j.scope.controls[0].operations = ['EVAL']]) {
    const j = job(); change(j);
    const result = await runJob(j, { browser: { observe() { assert.fail('browser I/O'); } }, decide() { assert.fail('provider I/O'); } });
    assert.equal(result.status, 'failed');
    assert.equal(result.reason, 'invalid_job');
  }
});

test('missing parent input and an unknown model action cannot dispatch', async () => {
  const { runJob } = await import(runnerUrl);
  for (const [change, decision, reason] of [
    [j => j.inputs = {}, 'c0_FILL', 'missing_input'],
    [() => {}, 'c99_DELETE', 'provider_response_invalid'],
  ]) {
    const j = job(); change(j); const browser = page();
    const result = await runJob(j, { browser, decide: choose(decision) });
    assert.equal(result.reason, reason);
    assert.equal(browser.effects.length, 0);
  }
});

test('a timeout after dispatch preserves unknown effect and never retries mutation', async () => {
  const { runJob } = await import(runnerUrl);
  const browser = page();
  let dispatched = 0;
  browser.execute = async () => { dispatched++; throw Object.assign(new Error('raw secret'), { code: 'command_aborted' }); };
  const result = await runJob(job(), { browser, decide: choose('c0_FILL') });
  assert.equal(dispatched, 1);
  assert.equal(result.status, 'handoff');
  assert.equal(result.reason, 'mutation_reply_lost');
  assert.equal(result.receipts[0].effect, 'unknown');
  assert.equal(result.receipts[0].dispatch, 'started');
  assert.ok(!JSON.stringify(result).includes('raw secret'));
});

test('completed dispatch receipt survives failure of the very next observation', async () => {
  const { runJob } = await import(runnerUrl);
  const browser = page();
  const observe = browser.observe;
  browser.observe = (...args) => {
    if (browser.effects.length) throw Object.assign(new Error('private page'), { code: 'browser_gone' });
    return observe(...args);
  };
  const result = await runJob(job(), { browser, decide: choose('c0_FILL') });
  assert.equal(result.reason, 'browser_gone');
  assert.equal(result.receipts.length, 1);
  assert.equal(result.receipts[0].dispatch, 'completed');
  assert.equal(result.receipts[0].effect, 'unknown');
  assert.equal(browser.effects.length, 1);
});

test('unexpected origin before or after a decision never reaches the provider or effects again', async () => {
  const { runJob } = await import(runnerUrl);
  for (const redirectAt of [1, 2]) {
    const browser = page(); const observe = browser.observe; let observations = 0; let decisions = 0;
    browser.observe = async (...args) => ({ ...await observe(...args), url: ++observations >= redirectAt ? 'https://other.test/private' : 'https://fixture.test/search' });
    const result = await runJob(job(), { browser, decide: async (...args) => { decisions++; return choose('c0_FILL')(...args); } });
    assert.equal(result.reason, 'origin_out_of_scope');
    assert.equal(decisions, redirectAt - 1);
    assert.equal(browser.effects.length, 0);
  }
});

test('an identical-looking replacement node invalidates the decision despite same selector and descriptor', async () => {
  const { runJob } = await import(runnerUrl);
  const browser = page(); const observe = browser.observe; let token = 0;
  browser.observe = async (...args) => {
    const o = await observe(...args); o.controls[0].token = `replacement${++token}`; return o;
  };
  const result = await runJob(job(), { browser, decide: choose('c0_FILL') });
  assert.equal(result.reason, 'stale_target');
  assert.equal(result.counters.recoveries, 3);
  assert.equal(browser.effects.length, 0);
});

test('foreground permission and confidence independently gate Orca input', async () => {
  const { runJob } = await import(runnerUrl);
  for (const [foregroundInput, confidence, reason] of [[false, 1, 'foreground_required'], [true, 0.8, 'low_confidence']]) {
    const j = job(); j.scope.foregroundInput = foregroundInput; const browser = page();
    const result = await runJob(j, { browser, decide: choose('c0_FILL', confidence) });
    assert.equal(result.reason, reason);
    assert.equal(browser.effects.length, 0);
  }
});

test('verified headless Orca permits unfocused input without desktop focus permission', async () => {
  const { runJob } = await import(runnerUrl);
  const j = job(); j.scope.foregroundInput = false;
  const browser = page(); const observe = browser.observe;
  browser.observe = async current => ({ ...await observe(current), requiresForeground: false, focused: false });
  const result = await runJob(j, { browser, decide: choose('c0_FILL') });
  assert.equal(result.status, 'verified');
  assert.equal(browser.effects.length, 1);
});

test('Orca rechecks foreground permission and focus before dispatch', async () => {
  const { runJob } = await import(runnerUrl);
  for (const [foregroundInput, requiresForeground, reason] of [
    [false, true, 'foreground_required'],
    [false, undefined, 'foreground_required'],
    [true, true, 'window_not_focused'],
    [false, 'false', 'foreground_required'],
  ]) {
    const j = job(); j.scope.foregroundInput = foregroundInput;
    const browser = page(); const observe = browser.observe; let reads = 0;
    browser.observe = async current => ({ ...await observe(current), focused: false,
      requiresForeground: ++reads === 1 ? false : requiresForeground });
    const result = await runJob(j, { browser, decide: choose('c0_FILL') });
    assert.equal(result.reason, reason);
    assert.equal(browser.effects.length, 0);
  }
});

test('target confidence and membership are checked for the selected operation', async () => {
  const { runJob } = await import(runnerUrl);
  for (const [target, reason] of [
    [{ type: 'choice', choice: 'c0_FILL', confidence: 0.2 }, 'low_confidence'],
    [{ type: 'choice', choice: 'c9_CLICK', confidence: 1 }, 'provider_response_invalid'],
    [null, 'provider_response_invalid'],
  ]) {
    const browser = page();
    const result = await runJob(job(), { browser, decide: async request => {
      const answer = await choose('c0_FILL')(request); answer.answers.FILL_target = target; return answer;
    } });
    assert.equal(result.reason, reason);
    assert.equal(browser.effects.length, 0);
  }
});

test('one transient provider retry consumes a decision and never retries a second time', async () => {
  const { runJob } = await import(runnerUrl);
  let calls = 0;
  const result = await runJob(job(), { browser: page(), decide: async () => {
    calls++; throw Object.assign(new Error(), { code: 'provider_http_503' });
  } });
  assert.equal(calls, 2);
  assert.equal(result.counters.decisions, 2);
  assert.equal(result.counters.providerRetries, 1);
  assert.equal(result.reason, 'provider_http_503');
});

test('deadline aborts an in-flight decision before any effect', async () => {
  const { runJob } = await import(runnerUrl);
  const j = job(); j.limits.elapsedMs = 60; const browser = page();
  const began = Date.now();
  const result = await runJob(j, { browser, decide: async (_, { signal }) => {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(resolve, 5000);
      signal.addEventListener('abort', () => { clearTimeout(timer); reject(new Error('aborted')); }, { once: true });
    });
  } });
  assert.equal(result.reason, 'deadline_exceeded');
  assert.equal(browser.effects.length, 0);
  assert.ok(Date.now() - began < 1000);
});

test('caller cancellation during dispatch returns an uncertain receipt', async () => {
  const { runJob } = await import(runnerUrl);
  const cancellation = new AbortController(); const browser = page();
  browser.execute = async () => { cancellation.abort(); throw new Error('cancelled'); };
  const result = await runJob(job(), { browser, decide: choose('c0_FILL'), signal: cancellation.signal });
  assert.equal(result.reason, 'cancelled');
  assert.equal(result.receipts[0].effect, 'unknown');
});

test('a completed click cannot be selected again when final checks remain false', async () => {
  const { runJob } = await import(runnerUrl);
  const j = job(); j.limits.elapsedMs = 150;
  j.scope.controls = [{ selector: '#submit', operations: ['CLICK'], expect: { selector: '#status', property: 'text', equals: 'saved' } }];
  let writes = 0;
  const browser = {
    async observe(current) { return { url: 'https://fixture.test/search', documentId: 'd1', text: 'Submit', focused: true,
      controls: [{ scopeIndex: 0, selector: '#submit', token: 'n1', fingerprint: 'button', tag: 'button', visible: true, disabled: false }],
      checks: current.checks.map((c, index) => ({ index, matched: c.selector === '#status' && writes > 0 })) }; },
    async execute() { writes++; },
  };
  const result = await runJob(j, { browser, decide: choose('c0_CLICK') });
  assert.equal(writes, 1);
  assert.equal(result.status, 'handoff');
  assert.equal(result.receipts[0].effect, 'confirmed');
});

test('unsupported page handoff reason survives an empty content observation', async () => {
  const { runJob } = await import(runnerUrl);
  const result = await runJob(job(), { browser: { async observe() {
    return { url: 'https://fixture.test/login', documentId: '', blocked: 'login_required' };
  } }, decide() { assert.fail('provider I/O'); } });
  assert.equal(result.reason, 'login_required');
});

test('viewport scrolling requires observed movement and reports a boundary without claiming success', async () => {
  const { runJob } = await import(runnerUrl);
  for (const moves of [true, false]) {
    const j = job();
    j.scope.controls = [{ selector: 'body', operations: ['SCROLL'], direction: 'down', amount: 400 }];
    j.checks = [{ selector: '#status', property: 'text', equals: 'Scrolled' }];
    let y = 0;
    const browser = {
      async observe() { return { url: 'https://fixture.test/search', documentId: 'd1', focused: true, text: 'Scroll to continue',
        controls: [{ scopeIndex: 0, selector: 'body', token: 'body1', fingerprint: 'body', visible: true, disabled: false, tag: 'body' }],
        checks: [{ index: 0, matched: y > 0 }], scroll: { x: 0, y, maxY: 800, maxX: 0 } }; },
      async execute() { if (moves) y = 400; },
    };
    const result = await runJob(j, { browser, decide: choose('c0_SCROLL') });
    assert.equal(result.status, moves ? 'verified' : 'handoff');
    assert.equal(result.receipts[0].effect, moves ? 'confirmed' : 'boundary');
    if (!moves) assert.equal(result.reason, 'scroll_boundary');
  }
});

test('WAIT completes only when its declared condition becomes true', async () => {
  const { runJob } = await import(runnerUrl);
  const j = job(); j.scope.controls = [];
  j.scope.pending = { selector: '#status', property: 'text', equals: 'Ready' };
  j.checks = [j.scope.pending];
  let ready = false;
  const browser = { async observe() { return { url: 'https://fixture.test/search', documentId: 'd1', text: 'Loading',
    controls: [], checks: [{ index: 0, matched: ready }] }; }, async execute() { assert.fail('WAIT must not dispatch browser input'); } };
  const result = await runJob(j, { browser, decide: async request => {
    setTimeout(() => { ready = true; }, 30);
    return choose('WAIT')(request);
  } });
  assert.equal(result.status, 'verified');
  assert.equal(result.counters.actions, 0);
  assert.equal(result.counters.decisions, 1);
});

test('CLI rejects malformed stdin with one machine-readable result before external I/O', () => {
  const result = spawnSync(process.execPath, [launcher], {
    input: '{', encoding: 'utf8', env: { PATH: '/nonexistent' }, timeout: 5000,
  });
  assert.equal(result.status, 1);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.status, 'failed');
  assert.equal(parsed.reason, 'invalid_job');
  assert.deepEqual(parsed.receipts, []);
  assert.equal(result.stderr, '');
});
