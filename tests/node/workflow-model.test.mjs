import assert from "node:assert/strict";
import { appendFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";

import { Tail, Run, findRun, parseMeta, resultLine, snapshot, STALL_MS } from "../../agent-marketplace/src/utils-agent/skills/workflow-viewer/viewer/workflow-model.ts";

const root = mkdtempSync(join(tmpdir(), "workflow-model-"));
process.env.CCWF_PROJECTS = root;
after(() => rmSync(root, { recursive: true, force: true }));

const NOW = Date.now();
const at = (minutesAgo) => new Date(NOW - minutesAgo * 60_000).toISOString();
const jsonl = (rows) => rows.map((r) => JSON.stringify(r) + "\n").join("");
const user = (m, content) => ({ type: "user", timestamp: at(m), message: { role: "user", content } });
const assistant = (m, id, content, extra = {}) => ({ type: "assistant", timestamp: at(m), message: { id, role: "assistant", model: "claude-x", usage: { input_tokens: 10, cache_read_input_tokens: 5000 }, content, ...extra } });

// One run directory: journal lines, agent transcripts, optional meta.json and final record.
function makeRun(name, { journal = [], agents = {}, meta = {}, final, script } = {}) {
  const session = join(root, "-tmp-project", `session-${name}`);
  const dir = join(session, "subagents/workflows", `wf_${name}`);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "journal.jsonl"), jsonl([{ type: "launched" }, ...journal]));
  for (const [id, rows] of Object.entries(agents)) writeFileSync(join(dir, `agent-${id}.jsonl`), jsonl(rows));
  for (const [id, m] of Object.entries(meta)) writeFileSync(join(dir, `agent-${id}.meta.json`), JSON.stringify(m));
  if (final || script) mkdirSync(join(session, "workflows/scripts"), { recursive: true });
  if (final) writeFileSync(join(session, "workflows", `wf_${name}.json`), JSON.stringify(final));
  if (script) writeFileSync(join(session, "workflows/scripts", `${name}-wf_${name}.js`), script);
  return new Run(dir).refresh();
}

test("the tail holds a partial line until its newline arrives", () => {
  const path = join(root, "tail.jsonl");
  writeFileSync(path, '{"a":1}\n{"b":');
  const tail = new Tail(path);
  assert.deepEqual(tail.read(), ['{"a":1}']);
  appendFileSync(path, "2}\n");
  assert.deepEqual(tail.read(), ['{"b":2}']);
});

test("an open tool call is activity until its timeout; silence past the stall window is a stall", () => {
  const run = makeRun("live", {
    journal: [{ type: "started", agentId: "a1", label: "build", phase: "Build" }, { type: "started", agentId: "a2", label: "quiet", phase: "Build" }],
    agents: {
      a1: [user(5, "build it"), assistant(4, "m1", [{ type: "tool_use", id: "t1", name: "Bash", input: { command: "make all", timeout: 600000 } }])],
      a2: [user(6, "think"), assistant(5, "m2", [{ type: "text", text: "ok" }])],
    },
  });
  const build = run.agents.get("a1"), quiet = run.agents.get("a2");
  assert.equal(build.state(NOW), "running");
  assert.equal(build.snap(NOW).longTool, true);
  assert.equal(quiet.state(NOW), "stalled");
  assert.ok(NOW - quiet.snap(NOW).lastAct > STALL_MS);
  // A stalled agent's duration stops at its last event instead of growing with the clock.
  assert.equal(quiet.end(NOW), quiet.snap(NOW).lastAct);
  assert.equal(run.status(NOW), "running");
});

test("agents a finished run never recorded are superseded, not stalled forever", () => {
  const run = makeRun("resumed", {
    journal: [{ type: "started", agentId: "a1", label: "first", phase: "Review" }, { type: "started", agentId: "a2", label: "retry", phase: "Review" }, { type: "result", agentId: "a2", result: "ok" }],
    agents: { a1: [user(900, "review")], a2: [user(10, "review again"), assistant(9, "m", [{ type: "text", text: "ok" }])] },
    final: { status: "completed", phases: [{ title: "Review" }], workflowProgress: [{ type: "workflow_agent", agentId: "a2", label: "retry", phaseTitle: "Review", state: "done" }] },
  });
  assert.equal(run.agents.get("a1").state(NOW), "abandoned");
  assert.equal(run.agents.get("a2").state(NOW), "done");
  assert.equal(run.status(NOW), "completed");
  assert.ok(run.agents.get("a1").end(NOW) < NOW - 800 * 60_000);
});

test("a synthetic API-error turn keeps the real context size and surfaces the error", () => {
  const run = makeRun("apierror", {
    journal: [{ type: "started", agentId: "a1", label: "auditor", phase: "Audit" }, { type: "failed", agentId: "a1" }],
    agents: { a1: [user(5, "audit"), assistant(4, "m1", [{ type: "text", text: "reading" }]), assistant(3, "m2", [{ type: "text", text: "API Error: 403 Please run /login" }], { model: "<synthetic>", usage: { input_tokens: 0 } })] },
  });
  const a = run.agents.get("a1");
  assert.equal(a.state(NOW), "failed");
  assert.equal(a.snap(NOW).ctx, 5010);
  assert.match(a.error, /403/);
});

test("labels come from meta.json, else from an identifier in the prompt", () => {
  const run = makeRun("oldjournal", {
    journal: [{ type: "started", agentId: "a1" }, { type: "started", agentId: "a2" }],
    agents: { a1: [user(5, "x")], a2: [user(5, "You are auditing a batch.\nYour batch file: /tmp/GAP__C-standard__unowned__10.json")] },
    meta: { a1: { description: "read:code", workflowPhase: "Understand" }, a2: { agentType: "workflow-subagent" } },
  });
  assert.equal(run.agents.get("a1").name, "read:code");
  assert.equal(run.agents.get("a1").phase, "Understand");
  assert.equal(run.agents.get("a2").name, "GAP__C-standard__unowned__10");
});

test("script meta survives apostrophes and brackets inside strings", () => {
  const meta = parseMeta(`export const meta = {\n  name: 'audit',\n  description: "It's a run that checks [things]",\n  phases: [{ title: 'Read [all]' }, { title: "Judge" }],\n}\n`);
  assert.equal(meta.description, "It's a run that checks [things]");
  assert.deepEqual(meta.phases, ["Read [all]", "Judge"]);
});

test("a result line prefers the telling field over a leading identifier", () => {
  assert.equal(resultLine({ batch: "B-storage__jobs__00", summary: "3 monitors are dead" }), "3 monitors are dead");
  assert.equal(resultLine('{"id":"x","notes":"a much longer free-text note"}'), "a much longer free-text note");
  assert.equal(resultLine("## Findings\nmore"), "Findings");
});

test("the snapshot groups agents by phase with their state and result", () => {
  const run = makeRun("snap", {
    script: "export const meta = {\n  name: 'snap-run',\n  phases: [{ title: 'One' }, { title: 'Two' }],\n}\n",
    journal: [{ type: "started", agentId: "a1", label: "first", phase: "One" }, { type: "result", agentId: "a1", result: { summary: "all good" } }],
    agents: { a1: [user(3, "go"), assistant(2, "m", [{ type: "text", text: "done" }])] },
  });
  const s = snapshot(run, NOW);
  assert.equal(s.name, "snap-run");
  assert.deepEqual(s.phases.map((p) => p.name), ["One", "Two"]);
  assert.deepEqual(s.phases[0].agents.map((a) => [a.name, a.state, a.result]), [["first", "done", "all good"]]);
  assert.ok(findRun("wf_snap").dir.endsWith("wf_snap"));
});
