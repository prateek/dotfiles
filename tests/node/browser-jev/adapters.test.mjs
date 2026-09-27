import { test } from "node:test";
import assert from "node:assert/strict";
import { createContext, runInContext } from "node:vm";
import { createOrcaAdapter } from "../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/orca.mjs";
import { createAgentBrowserAdapter } from "../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/agent-browser.mjs";

const worktree = "repo::/task";
const orcaBrowser = { driver: "orca", pageId: "page-1", worktree: `id:${worktree}` };
const agentBrowser = { driver: "agent-browser", session: "owned", pageId: "TARGET-1", config: "/task/empty-config.json" };
const job = {
  scope: { origins: ["https://fixture.test"], controls: [{ selector: "#query", operations: ["FILL"] }] },
  checks: [{ selector: "#query", property: "value", equals: "orchard" }],
};

class Element {
  constructor(properties = {}) {
    Object.assign(this, {
      tagName: "INPUT", id: "query", type: "text", value: "", textContent: "", isConnected: true,
      labels: [], options: [], attrs: {}, visible: true,
    }, properties);
  }
  getAttribute(name) { return this.attrs[name] ?? null; }
  hasAttribute(name) { return Object.hasOwn(this.attrs, name); }
  closest() { return null; }
  matches(selectors) { return selectors.split(",").includes(this.tagName.toLowerCase()); }
  getClientRects() { return this.visible ? [{}] : []; }
}

function page() {
  const controls = [new Element({ attrs: { placeholder: "Search entries" } })];
  const paragraph = new Element({ tagName: "P", id: "", type: "", textContent: "Search the orchard entries" });
  const text = { parentElement: paragraph, textContent: paragraph.textContent };
  const document = {
    body: {}, documentElement: {}, scrollingElement: { scrollWidth: 1000, scrollHeight: 1200 },
    hasFocus: () => true,
    querySelectorAll(selector) {
      if (selector === "#query") return controls;
      if (selector.startsWith('input[type="password"]')) return controls.filter((node) => node.type === "password");
      return [];
    },
    getElementById() { return null; },
    createTreeWalker() {
      let visited = false;
      return { currentNode: text, nextNode() { if (visited) return false; visited = true; return true; } };
    },
  };
  const location = { href: "https://fixture.test/search", origin: "https://fixture.test" };
  const context = createContext({
    Element, document, location, NodeFilter: { SHOW_TEXT: 4 },
    getComputedStyle: () => ({ display: "block", visibility: "visible" }),
    scrollX: 0, scrollY: 0, innerWidth: 1000, innerHeight: 600,
  });
  return { controls, text, location, document, eval(expression) { return runInContext(expression, context); } };
}

function orcaHarness(currentPage = page()) {
  const calls = [];
  const tab = { browserPageId: "page-1", worktreeId: worktree, profileId: "isolated" };
  const status = {
    app: { desktopWindowStatus: "available" },
    runtime: { reachable: true, state: "ready", runtimeId: "runtime-1", capabilities: [] },
    graph: { state: "ready" },
  };
  const state = { page: currentPage, calls, tab, status, override: undefined };
  state.command = async (executable, args, options) => {
    calls.push({ executable, args, options });
    if (args[0] === "status") {
      assert.deepEqual(args, ["status", "--json"]);
      return { ok: true, result: structuredClone(state.status) };
    }
    assert.deepEqual(args.slice(-5), ["--page", "page-1", "--worktree", `id:${worktree}`, "--json"]);
    if (state.override) return state.override(args);
    if (args[0] === "tab") return { ok: true, result: { tab: { ...tab } } };
    if (args[0] === "eval") return {
      ok: true, result: { result: JSON.stringify(state.page.eval(args[2])), origin: state.page.location.href },
    };
    if (args[0] === "fill") state.page.controls[0].value = args[4];
    return { ok: true, result: { [args[0]]: true } };
  };
  return state;
}

test("Orca observation decodes nested eval text and verifies field state after a typed fill", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  const before = await adapter.observe(job);
  assert.equal(before.controls[0].label, "Search entries");
  assert.equal(before.checks[0].matched, false);
  await adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" });
  const after = await adapter.observe(job);
  assert.equal(after.checks[0].matched, true);
  assert.equal(after.controls[0].value, "orchard");
  assert.equal(after.documentId, before.documentId);
  assert.equal(after.controls[0].token, before.controls[0].token);
});

test("Orca discovers current low-impact controls and newly revealed controls without a selector manifest", async () => {
  const current = page();
  const filters = new Element({ tagName: "BUTTON", id: "filters", type: "button", textContent: "Filters" });
  const published = new Element({ id: "published", type: "checkbox", attrs: { "aria-label": "Published only" }, visible: false, checked: false });
  const danger = new Element({ tagName: "BUTTON", id: "delete", type: "button", textContent: "Delete all records" });
  danger.attrs['aria-controls'] = 'confirmation';
  const submit = new Element({ tagName: "BUTTON", id: "submit", type: "submit", textContent: "Save request", form: {} });
  const newTab = new Element({ tagName: "A", id: "new-tab", type: "", textContent: "Other page", href: "https://fixture.test/other", target: "_blank" });
  current.controls.push(filters, published, danger, submit, newTab);
  current.document.querySelectorAll = selector => {
    if (selector === 'a[href],button,input,textarea,select') return current.controls;
    if (selector.startsWith('input[type="password"]')) return [];
    if (selector.startsWith('#')) return current.controls.filter(node => node.id === selector.slice(1));
    return [];
  };
  current.document.querySelector = selector => current.document.querySelectorAll(selector)[0] ?? null;
  const discoveryJob = { scope: { origins: ["https://fixture.test"], controls: [], discover: true }, checks: [] };
  const adapter = createOrcaAdapter(orcaBrowser, { command: orcaHarness(current).command });
  const before = await adapter.observe(discoveryJob);
  assert.deepEqual(before.controls.map(control => [control.selector, control.discoveryKind]), [
    ['#query', 'fill'], ['#filters', 'disclosure'],
  ]);
  published.visible = true;
  const after = await adapter.observe(discoveryJob);
  assert.deepEqual(after.controls.map(control => control.discoveryKind), ['fill', 'disclosure', 'checkbox']);
  assert.equal(after.controls[0].token, before.controls[0].token);
  assert.equal(after.controls[1].token, before.controls[1].token);
  assert.ok(!after.controls.some(control => ['#delete', '#submit', '#new-tab'].includes(control.selector)));
});

test("discovery hands back on a page with too many candidate controls", async () => {
  const current = page();
  current.controls.push(...Array.from({ length: 240 }, (_, index) =>
    new Element({ tagName: "BUTTON", id: `hidden-${index}`, type: "button", visible: false })));
  current.document.querySelectorAll = selector => {
    if (selector === 'a[href],button,input,textarea,select') return current.controls;
    if (selector.startsWith('input[type="password"]')) return [];
    if (selector.startsWith('#')) return current.controls.filter(node => node.id === selector.slice(1));
    return [];
  };
  current.document.querySelector = selector => current.document.querySelectorAll(selector)[0] ?? null;
  const discoveryJob = { scope: { origins: ["https://fixture.test"], controls: [], discover: true }, checks: [] };
  const adapter = createOrcaAdapter(orcaBrowser, { command: orcaHarness(current).command });
  assert.equal((await adapter.observe(discoveryJob)).blocked, "discovery_limit");
  current.controls.pop();
  const withinLimit = await adapter.observe(discoveryJob);
  assert.equal(withinLimit.blocked, undefined);
  assert.deepEqual(withinLimit.controls.map(control => control.selector), ["#query"]);
});

test("only a verified headless Orca runtime can waive foreground requirements", async () => {
  for (const scenario of [
    { window: "available", capabilities: [], requiresForeground: true },
    { window: "openable", capabilities: ["browser.headless.v1"], requiresForeground: false },
    { window: "openable", capabilities: [], requiresForeground: true },
    { window: undefined, capabilities: ["browser.headless.v1"], requiresForeground: true },
    { window: "available", capabilities: ["browser.headless.v1"], requiresForeground: true },
    { window: "openable", capabilities: ["browser.headless.v1"], graph: "loading", requiresForeground: true },
  ]) {
    const harness = orcaHarness();
    harness.status.app.desktopWindowStatus = scenario.window;
    harness.status.runtime.capabilities = scenario.capabilities;
    harness.status.graph.state = scenario.graph ?? "ready";
    harness.page.document.hasFocus = () => false;
    const observed = await createOrcaAdapter(orcaBrowser, { command: harness.command }).observe(job);
    assert.equal(observed.requiresForeground, scenario.requiresForeground);
    assert.equal(observed.focused, false);
    assert.equal(new Set(harness.calls.map(({ executable }) => executable)).size, 1);
  }
});

test("unreachable or unidentified Orca runtimes stop before inspecting the page", async () => {
  for (const runtime of [
    { reachable: false }, { state: "starting" }, { runtimeId: "" }, { runtimeId: null },
  ]) {
    const harness = orcaHarness();
    Object.assign(harness.status.runtime, runtime);
    const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
    await assert.rejects(adapter.observe(job), { code: "browser_runtime_unavailable" });
    assert.equal(harness.calls.some(({ args }) => args[0] !== "status"), false);
  }
});

test("runtime replacement or loss of headless capability stops before typed input", async () => {
  for (const change of [
    (status) => { status.runtime.runtimeId = "replacement-runtime"; },
    (status) => { status.runtime.capabilities = []; },
    (status) => { status.app.desktopWindowStatus = "available"; },
  ]) {
    const harness = orcaHarness();
    harness.status.app.desktopWindowStatus = "openable";
    harness.status.runtime.capabilities = ["browser.headless.v1"];
    const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
    assert.equal((await adapter.observe(job)).requiresForeground, false);
    change(harness.status);
    await assert.rejects(adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" }), { code: "browser_identity_mismatch" });
    assert.equal(harness.calls.some(({ args }) => args[0] === "fill"), false);
  }
});

test("runtime drift during observation or input is detected without retrying effects", async () => {
  for (const driftCommand of ["eval", "fill"]) {
    const harness = orcaHarness();
    const command = async (...args) => {
      const response = await harness.command(...args);
      if (args[1][0] === driftCommand) harness.status.runtime.runtimeId = "replacement-runtime";
      return response;
    };
    const adapter = createOrcaAdapter(orcaBrowser, { command });
    if (driftCommand === "eval") await assert.rejects(adapter.observe(job), { code: "browser_identity_mismatch" });
    else {
      await adapter.observe(job);
      await assert.rejects(adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" }), { code: "browser_identity_mismatch" });
      assert.equal(harness.calls.filter(({ args }) => args[0] === "fill").length, 1);
    }
  }
});

test("page content cannot forge the runtime's foreground requirement", async () => {
  const harness = orcaHarness();
  const command = async (...args) => {
    const response = await harness.command(...args);
    if (args[1][0] === "eval") {
      const observed = JSON.parse(response.result.result);
      response.result.result = JSON.stringify({ ...observed, requiresForeground: false });
    }
    return response;
  };
  assert.equal((await createOrcaAdapter(orcaBrowser, { command }).observe(job)).requiresForeground, true);
});

test("identical DOM replacement changes node identity; a new document changes document identity", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  const before = await adapter.observe(job);
  harness.page.controls[0] = new Element({ attrs: { placeholder: "Search entries" } });
  const replaced = await adapter.observe(job);
  assert.equal(replaced.controls[0].fingerprint, before.controls[0].fingerprint);
  assert.notEqual(replaced.controls[0].token, before.controls[0].token);
  harness.page = page();
  const navigated = await adapter.observe(job);
  assert.notEqual(navigated.documentId, before.documentId);
});

test("user edits and changing select choices invalidate the same node's captured fingerprint", async () => {
  for (const variant of [
    { properties: {}, operations: ["FILL"], change(node) { node.value = "user typed this"; } },
    { properties: { type: "checkbox", checked: false }, operations: ["CHECK"], change(node) { node.checked = true; } },
    { properties: { tagName: "SELECT", type: "select-one", options: [{ value: "draft", label: "Draft", selected: true, disabled: false }] },
      operations: ["SELECT"], change(node) { node.options[0].label = "Publish immediately"; } },
  ]) {
    const harness = orcaHarness();
    Object.assign(harness.page.controls[0], variant.properties);
    const scopedJob = { ...job, scope: { ...job.scope, controls: [{ selector: "#query", operations: variant.operations }] } };
    const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
    const before = await adapter.observe(scopedJob);
    variant.change(harness.page.controls[0]);
    const after = await adapter.observe(scopedJob);
    assert.equal(after.controls[0].token, before.controls[0].token);
    assert.notEqual(after.controls[0].fingerprint, before.controls[0].fingerprint);
  }
});

test("missing controls can appear later, while duplicate selectors block ambiguous input", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  harness.page.controls.length = 0;
  const absent = await adapter.observe(job);
  assert.equal(absent.blocked, undefined);
  assert.equal(absent.controls.length, 0);
  harness.page.controls.push(new Element(), new Element());
  const duplicate = await adapter.observe(job);
  assert.equal(duplicate.blocked, "ambiguous_target");
  assert.equal(duplicate.controls.length, 0);
});

test("observations report loss of document focus without requesting activation", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  assert.equal((await adapter.observe(job)).focused, true);
  harness.page.document.hasFocus = () => false;
  assert.equal((await adapter.observe(job)).focused, false);
  assert.equal(harness.calls.some(({ args }) => !["status", "tab", "eval"].includes(args[0])), false);
});

test("password values never appear in observations and unsupported editable widgets hand back", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  harness.page.controls[0].type = "password";
  harness.page.controls[0].value = "never-expose-this";
  let observed = await adapter.observe(job);
  assert.equal(observed.blocked, "login_required");
  assert.equal(JSON.stringify(observed).includes("never-expose-this"), false);
  harness.page.controls[0].visible = false;
  observed = await adapter.observe(job);
  assert.equal(observed.blocked, "sensitive_field");
  harness.page.controls[0] = new Element({ isContentEditable: true });
  assert.equal((await adapter.observe(job)).blocked, "unsupported_control");
});

test("origin mismatch prevents page content extraction and oversized visible text is flagged", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  harness.page.location.href = "https://other.test/private";
  harness.page.location.origin = "https://other.test";
  const wrongOrigin = await adapter.observe(job);
  assert.equal(wrongOrigin.blocked, "origin_mismatch");
  assert.equal(wrongOrigin.text, "");
  assert.equal(wrongOrigin.controls.length, 0);
  harness.page.location.href = "https://fixture.test/search";
  harness.page.location.origin = "https://fixture.test";
  harness.page.text.textContent = "x".repeat(20000);
  const longText = await adapter.observe(job);
  assert.equal(longText.truncated, true);
  assert.equal(longText.text.length, 12000);
});

test("ordinary values preserve whitespace and shell metacharacters as one argv value", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  const value = "  line one\n$(not-a-shell) `nor-this`  ";
  await adapter.execute({ operation: "FILL", selector: "#query", value });
  const command = harness.calls.find(({ args }) => args[0] === "fill");
  assert.equal(command.args[4], value);
  const observed = await adapter.observe({ ...job, checks: [{ selector: "#query", property: "value", equals: value }] });
  assert.equal(observed.controls[0].value, value);
  assert.equal(observed.checks[0].matched, true);
});

test("hidden text and input state cannot satisfy goal checks", async () => {
  const harness = orcaHarness();
  const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
  Object.assign(harness.page.controls[0], { value: "orchard", textContent: "Success", checked: true, visible: false });
  const checks = [
    { selector: "#query", property: "text", equals: "Success" },
    { selector: "#query", property: "value", equals: "orchard" },
    { selector: "#query", property: "checked", equals: true },
    { selector: "#query", property: "visible", equals: false },
  ];
  const observed = await adapter.observe({ ...job, checks });
  assert.deepEqual(observed.checks.map(({ matched }) => matched), [false, false, false, true]);
});

test("page/worktree or profile drift stops before any typed browser input", async () => {
  for (const change of [
    (tab) => { tab.browserPageId = "other-page"; },
    (tab) => { tab.worktreeId = "other::/task"; },
    (tab) => { tab.profileId = "personal"; },
  ]) {
    const harness = orcaHarness();
    const adapter = createOrcaAdapter(orcaBrowser, { command: harness.command });
    await adapter.observe(job);
    change(harness.tab);
    await assert.rejects(adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" }), { code: "browser_identity_mismatch" });
    assert.equal(harness.calls.some(({ args }) => args[0] === "fill"), false);
  }
});

test("Orca rejects outer failures, command-level failures, and malformed eval without leaking details", async () => {
  for (const response of [
    { ok: false, error: { message: "private error" } },
    { ok: true, result: { success: false, error: "private error" } },
    { ok: true, result: { ok: false } },
  ]) {
    const adapter = createOrcaAdapter(orcaBrowser, { command: async () => response });
    await assert.rejects(adapter.observe(job), (error) => error.code === "browser_command_failed" && !error.message.includes("private"));
  }
  const harness = orcaHarness();
  const normal = harness.command;
  const adapter = createOrcaAdapter(orcaBrowser, { command: (executable, args, options) => args[0] === "eval"
    ? { ok: true, result: { result: "not json", origin: "https://fixture.test/search" } }
    : normal(executable, args, options) });
  await assert.rejects(adapter.observe(job), { code: "browser_payload_invalid" });
});

function agentHarness() {
  const state = { page: page(), calls: [], sessions: ["owned"], targetId: "TARGET-1", driftAfterInput: false };
  state.command = async (executable, args, options) => {
    state.calls.push({ executable, args, options });
    assert.equal(executable, "agent-browser");
    assert.deepEqual(args.slice(0, 2), ["--config", "/task/empty-config.json"]);
    let data;
    if (args[2] === "session") data = { sessions: state.sessions };
    else {
      assert.deepEqual(args.slice(2, 6), ["--session", "owned", "--pin-tab", "--json"]);
      const command = args.slice(6);
      if (command[0] === "tab") data = { tabs: [{ targetId: state.targetId, active: true }] };
      else if (command[0] === "eval") data = { result: state.page.eval(command[1]) };
      else {
        if (command[0] === "fill") state.page.controls[0].value = command[2];
        if (state.driftAfterInput) state.targetId = "OTHER";
        data = { success: true };
      }
    }
    return { success: true, data };
  };
  return state;
}

test("agent-browser uses the named existing session and target and normalizes object eval results", async () => {
  const harness = agentHarness();
  const adapter = createAgentBrowserAdapter(agentBrowser, { command: harness.command });
  assert.equal((await adapter.observe(job)).checks[0].matched, false);
  await adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" });
  assert.equal((await adapter.observe(job)).checks[0].matched, true);
});

test("a missing agent-browser session fails without a command that can create a browser", async () => {
  const harness = agentHarness();
  harness.sessions = [];
  const adapter = createAgentBrowserAdapter(agentBrowser, { command: harness.command });
  await assert.rejects(adapter.observe(job), { code: "browser_session_missing" });
  assert.equal(harness.calls.length, 1);
});

test("active-tab drift is detected before dispatch and an uncertain post-dispatch drift is never retried", async () => {
  const harness = agentHarness();
  const adapter = createAgentBrowserAdapter(agentBrowser, { command: harness.command });
  harness.targetId = "OTHER";
  await assert.rejects(adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" }), { code: "browser_identity_mismatch" });
  assert.equal(harness.calls.some(({ args }) => args[6] === "fill"), false);
  harness.targetId = "TARGET-1";
  harness.driftAfterInput = true;
  await assert.rejects(adapter.execute({ operation: "FILL", selector: "#query", value: "orchard" }), { code: "browser_identity_mismatch" });
  assert.equal(harness.calls.filter(({ args }) => args[6] === "fill").length, 1);
});
