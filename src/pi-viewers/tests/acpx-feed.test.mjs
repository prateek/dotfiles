import assert from "node:assert/strict";
import { test } from "node:test";

import { Delegation, label } from "../acpx/feed.ts";

const cwd = "/work/repo";
const rec = { id: "r1", name: "review", cwd, agent: "agent", shortcut: "agpt", model: "m", closed: false };

const message = (m) => ({ type: "message", message: { jsonrpc: "2.0", ...m } });
const update = (u) => message({ method: "session/update", params: { update: u } });
const prompt = (id, text) => message({ id, method: "session/prompt", params: { prompt: [{ type: "text", text }] } });

function run(events) {
  const d = new Delegation(rec);
  for (const e of events) d.feed(e);
  return d;
}

test("a permission answer and the prompt response that share an id are told apart by shape", () => {
  const d = run([
    { type: "turn_started" },
    prompt(7, "check"),
    update({ sessionUpdate: "tool_call", toolCallId: "t1", kind: "execute", title: "git status", status: "pending", rawInput: { command: "git status" } }),
    message({ id: 7, method: "session/request_permission", params: { toolCall: { toolCallId: "t1", title: "git status" }, options: [{ optionId: "no", kind: "reject_once" }] } }),
    message({ id: 7, result: { outcome: { outcome: "selected", optionId: "no" } } }),
    message({ id: 7, result: { stopReason: "end_turn" } }),
  ]);
  assert.equal(d.status, "running");
  assert.equal(d.tools.get("t1").verdict, "denied");
  assert.equal(d.denied, 1);
  assert.equal(d.turn.items.length, 1);
});

test("updates replayed between session/load and the next prompt are not added again", () => {
  const d = run([
    { type: "turn_started" },
    message({ id: 1, method: "session/load", params: {} }),
    update({ sessionUpdate: "agent_message_chunk", content: { type: "text", text: "old answer" } }),
    prompt(2, "follow-up"),
    update({ sessionUpdate: "agent_message_chunk", content: { type: "text", text: "new answer" } }),
  ]);
  assert.deepEqual(d.turn.items, [{ type: "text", text: "new answer" }]);
  assert.equal(d.turn.prompt, "follow-up");
});

test("a tool call that never completes stays listed after the turn ends", () => {
  const d = run([
    { type: "turn_started" },
    prompt(1, "go"),
    update({ sessionUpdate: "tool_call", toolCallId: "t1", kind: "read", title: "Read", status: "pending", rawInput: {} }),
    { type: "turn_result", result: { status: "cancelled", stopReason: "cancelled" } },
  ]);
  assert.equal(d.turn.status, "cancelled");
  assert.equal(d.turn.items.length, 1);
  assert.equal(d.turn.items[0].tools[0].status, "pending");
});

test("unexpected event shapes are ignored without throwing", () => {
  const d = new Delegation(rec);
  for (const e of [{}, { type: "message" }, message({ method: "session/update", params: {} }), message({ result: null })]) d.feed(e);
  assert.equal(d.turns.length, 1);
  assert.deepEqual(d.turn.items, []);
});

test("a generic tool title takes its detail from later updates, relative to the session cwd", () => {
  const d = run([
    { type: "turn_started" },
    prompt(1, "go"),
    update({ sessionUpdate: "tool_call", toolCallId: "t1", kind: "read", title: "Read File", status: "pending", rawInput: {} }),
    update({ sessionUpdate: "tool_call_update", toolCallId: "t1", locations: [{ path: "/private/work/repo/src/app.ts" }], title: null }),
  ]);
  const tool = d.tools.get("t1");
  assert.equal(tool.title, "Read File");
  assert.equal(label(tool, cwd), "src/app.ts");
});

test("method-not-found and failed session/load errors are hidden; other errors are shown", () => {
  const d = run([
    { type: "turn_started" },
    message({ id: 3, method: "session/load", params: {} }),
    message({ id: 3, error: { code: -32602, message: "Invalid params", data: { message: "Session not found" } } }),
    prompt(4, "go"),
    message({ id: 9, error: { code: -32601, message: "Method not found" } }),
    message({ id: 10, error: { code: -32000, message: "boom" } }),
  ]);
  assert.deepEqual(d.turn.items, [{ type: "note", tone: "error", text: "error: boom" }]);
  assert.equal(d.errors, 1);
});

test("back-to-back reads group into one row and repeated notes collapse into a count", () => {
  const d = run([
    { type: "turn_started" },
    prompt(1, "go"),
    update({ sessionUpdate: "tool_call", toolCallId: "a", kind: "read", title: "Read a", status: "completed" }),
    update({ sessionUpdate: "tool_call", toolCallId: "b", kind: "read", title: "Read b", status: "completed" }),
    message({ id: 20, method: "session/request_permission", params: { toolCall: { title: "Fetch https://example.com/1" }, options: [] } }),
    message({ id: 20, result: { outcome: { outcome: "selected", optionId: "x" } } }),
    message({ id: 21, method: "session/request_permission", params: { toolCall: { title: "Fetch https://example.com/2" }, options: [] } }),
    message({ id: 21, result: { outcome: { outcome: "selected", optionId: "x" } } }),
  ]);
  const [reads, note] = d.turn.items;
  assert.equal(reads.tools.length, 2);
  assert.equal(note.type, "note");
  assert.equal(note.count, 2);
});
