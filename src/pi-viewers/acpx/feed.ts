// ACP event model for the acpx delegation viewer. Folds the JSON lines of
// `acpx --format json sessions watch` into turns, items, and tool calls. It has no
// pi or terminal dependencies, so Node can test it directly.
import { homedir } from "node:os";
import { newView, type View } from "../lib/core.ts";

export const GROUPABLE = new Set(["read", "search", "fetch"]);
export const GENERIC = /^(read file|read|grep|find|search|terminal|edit|write|web fetch|fetch|glob|list)$/i;

export interface Rec { id: string; name: string; cwd: string; agent: string; shortcut: string; model: string; closed: boolean; title?: string; createdAt?: number; lastPromptAt?: number; lastUsedAt?: number }

export const rel = (s: string, cwd: string) =>
  s.split("/private" + cwd + "/").join("").split(cwd + "/").join("").split(homedir() + "/").join("~/");

export interface Tool { id: string; title?: string; kind?: string; status?: string; locations?: { path: string }[]; rawInput?: any; rawOutput?: any; content?: any[]; verdict?: "allowed" | "denied" | "cancelled" }
export type Item =
  | { type: "text"; text: string }
  | { type: "thought"; text: string }
  | { type: "tools"; kind: string; tools: Tool[] }
  | { type: "note"; text: string; tone: "warning" | "error"; count?: number };
export interface Turn { prompt: string; items: Item[]; status: string; stopReason?: string; started: number; ended?: number; cost?: number; tokens?: number }

const noteKey = (text: string) => text.replace(/(https?:\/\/[^/\s]+)\S*/g, "$1").slice(0, 40);

export class Delegation {
  rec: Rec;
  turns: Turn[] = [];
  tools = new Map<string, Tool>();
  replaying = false;
  loadIds = new Set<unknown>();
  permissions = new Map<unknown, any>();
  denied = 0;
  errors = 0;
  status = "idle";
  lastEvent = 0;
  // Attach replays retained history in one burst; turns that end inside it have no real timing.
  settled = false;
  // View state, owned by the viewer.
  view: View = newView();

  constructor(rec: Rec) {
    this.rec = rec;
  }

  get turn() { return this.turns[this.turns.length - 1]; }

  // The latest turn may predate the attach; its prompt time comes from the session record.
  startOf(t: Turn) { const p = this.rec.lastPromptAt; return t === this.turn && p && p < t.started ? p : t.started; }
  // A replayed latest turn ends at the record's last_used_at; older replayed turns have no timing.
  endOf(t: Turn) { return t.ended ?? (t === this.turn && t.status !== "running" ? this.rec.lastUsedAt : undefined); }

  add(item: Item) {
    const t = this.turn;
    if (!t) return;
    const last = t.items[t.items.length - 1];
    if (last && (item.type === "text" || item.type === "thought") && last.type === item.type) last.text += item.text;
    else if (last?.type === "tools" && item.type === "tools" && GROUPABLE.has(item.kind) && last.kind === item.kind) last.tools.push(...item.tools);
    // Back-to-back notes collapse into one counted row when they match up to their first 40
    // characters, with URLs reduced to their host (repeated fetch denials differ only in path).
    else if (last?.type === "note" && item.type === "note" && last.tone === item.tone && noteKey(last.text) === noteKey(item.text)) last.count = (last.count ?? 1) + 1;
    else t.items.push(item);
  }

  feed(e: any) {
    this.lastEvent = Date.now();
    if (e.type === "turn_started") {
      this.status = "running";
      this.turns.push({ prompt: "", items: [], status: "running", started: Date.now() });
      return;
    }
    if (e.type === "turn_result") {
      this.status = e.result?.status ?? "completed";
      if (this.turn) Object.assign(this.turn, { status: this.status, stopReason: e.result?.stopReason, ended: this.settled ? Date.now() : undefined });
      return;
    }
    const m = e.message ?? {};
    const p = m.params ?? {};
    if (!this.turn) this.turns.push({ prompt: "", items: [], status: "running", started: Date.now() });
    if (m.method === "session/load") { this.replaying = true; this.loadIds.add(m.id); }
    else if (m.method === "session/prompt") {
      this.replaying = false; // updates between load and prompt replay earlier turns
      this.turn.prompt = (p.prompt ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("\n");
    } else if (m.method === "session/update" && !this.replaying) {
      const u = p.update ?? {};
      if (u.sessionUpdate === "agent_message_chunk" && u.content?.type === "text") this.add({ type: "text", text: u.content.text });
      else if (u.sessionUpdate === "agent_thought_chunk") this.add({ type: "thought", text: u.content?.text ?? "" });
      else if (u.sessionUpdate === "usage_update" && typeof u.cost?.amount === "number") this.turn.cost = u.cost.amount; // claude-agent-acp; cursor sends none
      else if (u.sessionUpdate === "tool_call" || u.sessionUpdate === "tool_call_update") {
        let tool = this.tools.get(u.toolCallId);
        const fresh = !tool;
        if (!tool) { tool = { id: u.toolCallId }; this.tools.set(u.toolCallId, tool); }
        for (const [k, v] of Object.entries(u)) if (v != null && k !== "sessionUpdate") (tool as any)[k] = v; // titles arrive late
        if (fresh) this.add({ type: "tools", kind: tool.kind ?? "other", tools: [tool] });
      }
    } else if (!m.method && m.result?.stopReason && m.result.usage) {
      const x = m.result.usage;
      this.turn.tokens = x.totalTokens ?? (x.inputTokens ?? 0) + (x.outputTokens ?? 0);
    } else if (m.method === "session/request_permission") {
      this.permissions.set(m.id, p);
    } else if (!m.method && m.id != null && m.result?.outcome && this.permissions.has(m.id)) {
      // ids are per direction: only an `outcome` result answers a permission request
      const req = this.permissions.get(m.id);
      const kind = String((req.options ?? []).find((o: any) => o.optionId === m.result.outcome.optionId)?.kind ?? m.result.outcome.outcome);
      const verdict = kind.startsWith("allow") ? "allowed" : kind.startsWith("reject") ? "denied" : "cancelled";
      const tool = this.tools.get(req.toolCall?.toolCallId);
      if (verdict === "denied") this.denied++;
      // Fold the verdict into the tool row it belongs to; a request for an unknown call gets its own row.
      if (tool) tool.verdict = verdict;
      else this.add({ type: "note", tone: verdict === "allowed" ? "warning" : "error", text: `${verdict}: ${rel(String(req.toolCall?.title ?? "tool").replace(/`/g, ""), this.rec.cwd)}` });
    } else if (m.error && m.error.code !== -32601 && !this.loadIds.has(m.id)) {
      this.errors++;
      this.add({ type: "note", tone: "error", text: `error: ${m.error.data?.message ?? m.error.message}` });
    }
  }

  activity(): string {
    const t = this.turn;
    if (!t) return "waiting";
    if (t.status !== "running") return statusWord(t.status, t.stopReason);
    // Running: what it is doing right now.
    const last = t.items[t.items.length - 1];
    if (!last) return "now: starting";
    if (last.type === "thought") return "now: thinking";
    if (last.type === "text") return "now: writing answer";
    if (last.type === "tools") return `now: ${label(last.tools[last.tools.length - 1], this.rec.cwd)}`;
    return `now: ${last.text}`;
  }

  get firstPrompt() { return this.turns.find((t) => t.prompt)?.prompt ?? ""; }
  get started() { return this.rec.createdAt ?? this.turns[0]?.started; }
  get cost() { const c = this.turns.filter((t) => t.cost != null); return c.length ? c.reduce((a, t) => a + t.cost!, 0) : undefined; }
  get tokens() { const c = this.turns.filter((t) => t.tokens != null); return c.length ? c.reduce((a, t) => a + t.tokens!, 0) : undefined; }
  get toolCount() { return this.tools.size; }
  get failedTools() { let n = 0; for (const t of this.tools.values()) if (failed(t)) n++; return n; }
  // Wall time the delegation spent working: finished turns plus the running one.
  busyMs() {
    return this.turns.reduce((a, t) => a + (t.status === "running" ? Date.now() - this.startOf(t) : this.endOf(t) ? this.endOf(t)! - this.startOf(t) : 0), 0);
  }
}

// One vocabulary on every screen; the ACP stop reason shows only when it is abnormal.
export function statusWord(status: string, stopReason?: string) {
  const word = { running: "running", completed: "done", cancelled: "cancelled", failed: "failed", detached: "detached", idle: "waiting" }[status] ?? status;
  return stopReason && stopReason !== "end_turn" && stopReason !== "cancelled" ? `${word} (${stopReason.replace(/_/g, " ")})` : word;
}

export function detail(t: Tool) {
  const i = t.rawInput ?? {};
  return t.locations?.[0]?.path ?? i.path ?? i.file_path ?? i.command ?? i.pattern ?? i.query ?? i.url;
}

export function label(t: Tool, cwd: string) {
  const title = String(t.title ?? "").replace(/^`|`$/g, "").replace(/\s+/g, " ").trim();
  const d = detail(t);
  const text = d && (!title || GENERIC.test(title)) ? String(d).replace(/\s+/g, " ") : title.replace(/^(Read|Edit|Write)\s+/, "");
  return rel(text || t.kind || "tool", cwd);
}

export function done(t: Tool) { return t.status === "completed" || t.status === "failed"; }

export function outputText(t: Tool): string {
  const parts: string[] = [];
  for (const c of t.content ?? []) {
    if (c?.type === "content" && c.content?.type === "text") parts.push(c.content.text);
    else if (c?.type === "terminal") continue;
  }
  const r = t.rawOutput;
  if (!parts.length && r != null) {
    if (typeof r === "string") parts.push(r);
    else {
      for (const k of ["stdout", "content", "output", "stderr", "error"]) if (typeof r[k] === "string" && r[k]) parts.push(r[k]);
    }
  }
  return parts.join("\n");
}

export function diffStats(t: Tool) {
  let add = 0, del = 0, seen = false;
  for (const c of t.content ?? []) {
    if (c?.type !== "diff") continue;
    seen = true;
    const old = (c.oldText ?? "").split("\n"), neu = (c.newText ?? "").split("\n");
    const o = new Set(old), n = new Set(neu);
    add += neu.filter((l: string) => !o.has(l)).length;
    del += c.oldText == null ? 0 : old.filter((l: string) => !n.has(l)).length;
  }
  return seen ? { add, del } : undefined;
}

export function failed(t: Tool) {
  const r = t.rawOutput;
  return t.status === "failed" || (r && typeof r === "object" && (typeof r.error === "string" || (typeof r.exitCode === "number" && r.exitCode !== 0)));
}

export function summary(t: Tool, kind: string): string {
  if (!done(t)) return "running";
  const out = outputText(t);
  const lines = out ? out.replace(/\n$/, "").split("\n") : [];
  const r = t.rawOutput ?? {};
  if (typeof r.error === "string" && !r.content && !r.stdout) return lines[lines.length - 1] ?? "error";
  if (kind === "edit") { const s = diffStats(t); return s ? `+${s.add} -${s.del}` : t.status ?? ""; }
  if (kind === "execute") {
    const last = lines.filter((l) => l.trim()).pop() ?? "";
    const exit = typeof r.exitCode === "number" ? `exit ${r.exitCode}` : typeof r.durationMs === "number" ? `${(r.durationMs / 1000).toFixed(1)}s` : "";
    return [exit, last.trim()].filter(Boolean).join(" · ");
  }
  if (kind === "search") return typeof r.totalFiles === "number" ? `${r.totalFiles} files` : `${lines.length} ${lines.length === 1 ? "match" : "matches"}`;
  if (kind === "fetch") return `${lines.length} lines`;
  return lines.length ? `${lines.length} lines` : "";
}

export function thoughtHeader(text: string) {
  const first = text.split("\n").map((l) => l.trim()).find(Boolean) ?? "";
  return first.replace(/^\*\*(.*)\*\*$/, "$1").replace(/^#+\s*/, "");
}
