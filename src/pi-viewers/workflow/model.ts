// Claude Code Workflow runs as data: the journal, agent transcripts and completion record folded into
// agents with honest states. No pi imports, so Node tests and the --once snapshot use it directly.
// Read-only inputs, per run under ~/.claude/projects/<project>/<session>/:
//   subagents/workflows/wf_<id>/journal.jsonl     started/result/failed, appended live (agentId, label, phase)
//   subagents/workflows/wf_<id>/agent-<id>.jsonl  each agent's transcript, appended live (+ .meta.json)
//   workflows/scripts/<name>-wf_<id>.js           saved at launch: meta.name and meta.phases
//   workflows/wf_<id>.json                        written at completion: state, queuedAt, tokens, errors
import { closeSync, existsSync, openSync, readdirSync, readFileSync, readSync, statSync, type Dirent } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { newView, type View } from "../lib/core.ts";

export const STALL_MS = 180_000;
const HOME = homedir();
export const projectsDir = () => process.env.CCWF_PROJECTS ?? join(homedir(), ".claude/projects");

// Replays judge agents at a past instant: items after it are invisible and nothing is "stalled".
let replay = false;
export function setReplay(on: boolean) { replay = on; }

export const str = (s: unknown) => (s == null ? "" : typeof s === "string" ? s : JSON.stringify(s));
export const firstLine = (s?: unknown) => str(s).split("\n").find((l) => l.trim())?.trim() ?? "";
// Skip wrapper tags (`<persisted-output>`) so a one-line hint shows real output.
export const lastLine = (s?: unknown) => str(s).split("\n").filter((l) => l.trim() && !/^<\/?[\w-]+>$/.test(l.trim())).pop()?.trim() ?? "";
// Workflow agents get two framed user turns: the triggering user request and the computed task.
// Strip the harness frame so rows show the content; the label says which turn it was.
export function unframe(text = "") {
  const m = text.match(/^\[Workflow harness — ([^\]]+)\][^\n]*\n([\s\S]*)$/);
  if (!m) return { label: "", body: text };
  const body = m[2].split("\n").map((l) => l.replace(/^  /, "")).join("\n");
  return { label: m[1].includes("computed") ? "task" : m[1].includes("user request") ? "request" : m[1], body };
}
// The most telling string in an object: a well-known field, else the longest string. Leading fields
// are often identifiers (a batch label), which say nothing about the outcome.
const TELLING = ["summary", "result", "verdict", "answer", "findings", "message", "text", "output", "description", "query", "command", "pattern", "prompt", "path", "url"];
export function tellingString(o: any): string {
  if (!o || typeof o !== "object") return "";
  for (const k of TELLING) if (typeof o[k] === "string" && o[k].trim()) return o[k];
  const strs = Object.values(o).filter((x): x is string => typeof x === "string" && !!x.trim());
  return strs.sort((a, b) => b.length - a.length)[0] ?? "";
}
export function resultLine(r?: unknown) {
  if (r && typeof r === "object") return firstLine(tellingString(r)) || firstLine(str(r));
  const s = str(r).trim();
  if (s.startsWith("{")) { try { const v = tellingString(JSON.parse(s)); if (v) return firstLine(v); } catch {} }
  return firstLine(s).replace(/^#+\s*/, "");
}
// Appended-line reader: each call returns the complete lines written since the last call.
export class Tail {
  path: string;
  off = 0;
  buf = "";
  dec = new StringDecoder("utf8");
  constructor(path: string) { this.path = path; }
  read(): string[] {
    let size = 0;
    try { size = statSync(this.path).size; } catch { return []; }
    if (size <= this.off) return [];
    const fd = openSync(this.path, "r");
    try {
      const b = Buffer.alloc(size - this.off);
      readSync(fd, b, 0, b.length, this.off);
      this.off = size;
      this.buf += this.dec.write(b);
    } finally { closeSync(fd); }
    const lines = this.buf.split("\n");
    this.buf = lines.pop() ?? "";
    return lines.filter(Boolean);
  }
}

// `key` is stable for the life of the transcript (tool id, else position in the append-only list),
// so fold state survives refreshes and out-of-order timestamps.
export interface Item { t: "prompt" | "text" | "think" | "tool" | "note"; ts: number; key: string; text?: string; name?: string; input?: any; id?: string; result?: string; err?: boolean; endTs?: number }
export type AgentState = "hidden" | "starting" | "running" | "stalled" | "done" | "failed" | "cached" | "abandoned";
export interface Snap { vis: Item[]; state: AgentState; lastAct: number; ctx: number; tools: number; errors: number; lastTool?: Item; running?: Item; longTool: boolean }

const resultText = (c: any): string =>
  typeof c === "string" ? c : Array.isArray(c) ? c.map((x) => (x?.type === "text" ? x.text : x?.type === "image" ? "[image]" : "")).join("\n") : "";
// How long an unanswered tool call still counts as activity. Bash runs up to its own timeout
// (10 min cap); a nested agent can run for as long as it likes.
const toolGrace = (it: Item) => (it.name === "Agent" || it.name === "Task" ? Infinity : Math.max(Number(it.input?.timeout) || 0, 600_000) + 60_000);

export class Agent {
  id: string;
  label: string;
  phase: string;
  items: Item[] = [];
  byTool = new Map<string, Item>();
  usage = new Map<string, { ts: number; ctx: number }>(); // keyed by message id: content blocks repeat usage
  model = "";
  cwd = "";
  journal: "started" | "done" | "failed" = "started";
  result?: unknown;
  final?: any;
  superseded = false; // the run finished without this agent in its final record
  lastText = "";
  last = 0;
  tail: Tail;
  rev = 0;
  private memo?: { t: number; rev: number; s: Snap };
  // view state, owned by the viewer
  view: View = newView();
  constructor(id: string, label: string, phase: string, dir: string) {
    this.id = id; this.label = label; this.phase = phase;
    this.tail = new Tail(join(dir, `agent-${id}.jsonl`));
  }
  private push(it: Omit<Item, "key">) { const item = { ...it, key: it.t === "tool" ? `t:${it.id}` : `k${this.items.length}` } as Item; this.items.push(item); this.last = Math.max(this.last, it.ts); return item; }
  feed(line: string) {
    let d: any;
    try { d = JSON.parse(line); } catch { return; }
    const ts = Date.parse(d.timestamp) || 0;
    const m = d.message;
    if (!ts || !m) return;
    this.rev++;
    if (d.cwd) this.cwd = d.cwd;
    if (d.type === "user") {
      if (typeof m.content === "string") { this.push({ t: this.items.length ? "note" : "prompt", ts, text: m.content }); return; }
      for (const c of m.content ?? []) {
        if (c.type === "tool_result") {
          const it = this.byTool.get(c.tool_use_id);
          if (it) { it.result = resultText(c.content); it.err = !!c.is_error; it.endTs = ts; this.last = Math.max(this.last, ts); }
        } else if (c.type === "text" && c.text?.trim()) this.push({ t: this.items.length ? "note" : "prompt", ts, text: c.text });
      }
    } else if (d.type === "assistant") {
      const synthetic = m.model === "<synthetic>";
      if (m.model && !synthetic) this.model = m.model;
      const u = m.usage;
      const ctx = u ? (u.input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) : 0;
      // A synthetic "API Error" turn reports zero usage; it must not wipe the real context size.
      if (u && !synthetic && ctx > 0) this.usage.set(m.id ?? d.uuid, { ts, ctx });
      for (const c of m.content ?? []) {
        if (c.type === "text" && c.text?.trim()) { this.push({ t: "text", ts, text: c.text }); this.lastText = c.text; }
        else if (c.type === "thinking" && c.thinking?.trim()) this.push({ t: "think", ts, text: c.thinking });
        else if (c.type === "tool_use") this.byTool.set(c.id, this.push({ t: "tool", ts, name: c.name, input: c.input, id: c.id }));
      }
    }
  }
  setFinal(e: any) { this.final = e; this.rev++; }
  get firstTs() { return this.items[0]?.ts ?? 0; }
  get lastTs() { return this.last; }
  get task() { const n = this.items.find((i) => (i.t === "note" || i.t === "prompt") && unframe(i.text).label === "task"); return n ? firstLine(unframe(n.text).body) : ""; }
  // Old runs record neither a label nor a phase for some agents; prompts usually name their batch
  // or target (`GAP__C-standard__unowned__10`), else the opening words will do.
  get name() {
    if (this.label !== this.id) return this.label;
    const body = this.task || unframe(this.items.find((i) => i.t === "prompt")?.text).body;
    const ident = body.match(/\b[A-Za-z][\w-]*__[\w-]+\b/)?.[0];
    return ident ?? (firstLine(body).split(/\s+/).slice(0, 6).join(" ") || this.id);
  }
  get error() { return firstLine(this.final?.error) || (/error|failed|denied/i.test(this.lastText) ? firstLine(this.lastText) : ""); }
  toolDone(i: Item, t: number) { return i.endTs != null && i.endTs <= t; }
  // Everything a frame needs about this agent at time t, computed once per (t, revision).
  snap(t: number): Snap {
    if (this.memo && this.memo.t === t && this.memo.rev === this.rev) return this.memo.s;
    const vis = replay ? this.items.filter((i) => i.ts <= t) : this.items;
    let lastAct = 0, tools = 0, errors = 0, lastTool: Item | undefined, running: Item | undefined;
    for (const i of vis) {
      lastAct = Math.max(lastAct, i.ts, i.endTs && i.endTs <= t ? i.endTs : 0);
      if (i.t === "tool") { tools++; lastTool = i; if (this.toolDone(i, t)) { if (i.err) errors++; } else running = i; }
    }
    let ctx = 0, last = 0;
    for (const u of this.usage.values()) if (u.ts <= t && u.ts >= last) { last = u.ts; ctx = u.ctx; }
    // An open tool call is activity until its timeout: a 6-minute test run is not a stall.
    const inTool = !!running && t - running.ts < toolGrace(running);
    const finished = !replay || this.lastTs <= t;
    let state: AgentState;
    if (replay && (this.items.length ? this.firstTs > t : (this.final?.startedAt ?? Infinity) > t)) state = "hidden";
    else if (this.journal === "failed" && finished) state = "failed";
    else if (this.final?.cached && finished) state = "cached";
    else if (this.journal === "done" && finished) state = this.final?.state === "error" ? "failed" : "done";
    else if (this.journal === "started" && this.final && finished) state = this.final.state === "error" ? "failed" : this.final.state === "done" ? "done" : "abandoned";
    else if (this.superseded && finished) state = "abandoned";
    else if (!this.items.length) state = "starting";
    else state = !replay && !inTool && t - lastAct > STALL_MS ? "stalled" : "running";
    const s = { vis, state, lastAct, ctx, tools, errors, lastTool, running, longTool: inTool && t - running!.ts > STALL_MS };
    this.memo = { t, rev: this.rev, s };
    return s;
  }
  state(t: number) { return this.snap(t).state; }
  // Durations never run past the agent's own last event once it is no longer live.
  end(t: number) { const s = this.snap(t); return s.state === "running" || s.state === "starting" ? t : s.state === "stalled" ? s.lastAct : this.lastTs || t; }
}

export function readdirSafe(d: string) { try { return readdirSync(d); } catch { return []; } }
// A session's workflows/ can sit under a different project directory than its subagents/
// (seen when the session's cwd changed), so look for the same session id across projects.
function workflowsDirs(sessionDir: string) {
  const sid = basename(sessionDir), own = join(sessionDir, "workflows"), root = projectsDir();
  return [own, ...readdirSafe(root).map((p) => join(root, p, sid, "workflows")).filter((w) => w !== own && existsSync(w))];
}
const findScript = (sessionDir: string, runId: string) => {
  for (const w of workflowsDirs(sessionDir)) { const f = readdirSafe(join(w, "scripts")).find((n) => n.endsWith(`-${runId}.js`)); if (f) return join(w, "scripts", f); }
};
const findFinal = (sessionDir: string, runId: string) => workflowsDirs(sessionDir).map((w) => join(w, `${runId}.json`)).find((f) => existsSync(f));

// A JS string literal's contents, honouring its own quote character and escapes.
export const quoted = (src: string, key: string) => src.match(new RegExp(`${key}\\s*:\\s*(['"\`])((?:\\\\.|(?!\\1)[\\s\\S])*)\\1`))?.[2]?.replace(/\\(['"`\\])/g, "$1") ?? "";
// The `[...]` after `key:`, matched bracket-for-bracket and ignoring brackets inside strings.
export function bracketed(src: string, key: string) {
  const at = src.search(new RegExp(`${key}\\s*:\\s*\\[`));
  if (at < 0) return "";
  const i = src.indexOf("[", at);
  let depth = 0, q = "";
  for (let j = i; j < src.length; j++) {
    const c = src[j];
    if (q) { if (c === "\\") j++; else if (c === q) q = ""; continue; }
    if (c === "'" || c === '"' || c === "`") q = c;
    else if (c === "[") depth++;
    else if (c === "]" && --depth === 0) return src.slice(i + 1, j);
  }
  return "";
}
export function parseMeta(src: string, fallbackName = "") {
  const meta = src.match(/export\s+const\s+meta\s*=\s*\{[\s\S]*?\n\}/)?.[0] ?? src.slice(0, 4000);
  return {
    name: quoted(meta, "name") || fallbackName,
    description: quoted(meta, "description"),
    phases: [...bracketed(meta, "phases").matchAll(/title\s*:\s*(['"`])((?:\\.|(?!\1)[\s\S])*)\1/g)].map((m) => m[2]),
  };
}
const metaCache = new Map<string, { name: string; phases: string[]; description: string }>();
export function scriptMeta(sessionDir: string, runId: string) {
  const hit = metaCache.get(runId);
  if (hit) return hit;
  let r = { name: "", phases: [] as string[], description: "" };
  try {
    const path = findScript(sessionDir, runId);
    if (path) r = parseMeta(readFileSync(path, "utf8"), basename(path).replace(`-${runId}.js`, ""));
    else {
      // No suffixed script (older runs): fall back to the completion record, if there is one.
      const f = findFinal(sessionDir, runId);
      if (f) { const d = JSON.parse(readFileSync(f, "utf8")); r = { name: d.workflowName ?? "", description: d.summary ?? "", phases: (d.phases ?? []).map((p: any) => p.title).filter(Boolean) }; }
    }
  } catch {}
  metaCache.set(runId, r); // scripts are written at launch, so a miss stays a miss
  return r;
}
export const projectOf = (sessionDir: string) => basename(dirname(sessionDir)).replace(/^-Users-[^-]+-/, "").replace(/^code-(worktrees-)?/, "");

export class Run {
  dir: string;
  agents = new Map<string, Agent>();
  phases: string[] = [];
  name: string;
  description: string;
  runId: string;
  sessionDir: string;
  project: string;
  journal: Tail;
  final?: any;
  finalMtime = 0;
  finalPath?: string;
  lastFinalLook = 0;
  needMeta = new Set<string>(); // agents still missing a label or phase
  start = Infinity;
  last = 0;
  rev = 0;
  private visMemo?: { t: number; rev: number; list: Agent[] };
  constructor(dir: string) {
    this.dir = dir;
    this.runId = basename(dir);
    this.sessionDir = dirname(dirname(dirname(dir)));
    this.project = projectOf(this.sessionDir);
    this.journal = new Tail(join(dir, "journal.jsonl"));
    const meta = scriptMeta(this.sessionDir, this.runId);
    this.name = meta.name || this.runId;
    this.description = meta.description;
    this.phases = [...meta.phases];
  }
  agent(id: string, label?: string, phase?: string) {
    let a = this.agents.get(id);
    if (!a) { a = new Agent(id, label ?? id, phase ?? "", this.dir); this.agents.set(id, a); this.rev++; }
    if (label) a.label = label;
    if (phase) a.phase = phase;
    if (a.label === id || !a.phase) this.needMeta.add(id); else this.needMeta.delete(id);
    if (a.phase && !this.phases.includes(a.phase)) this.phases.push(a.phase);
    return a;
  }
  refresh() {
    for (const line of this.journal.read()) {
      try {
        const j = JSON.parse(line);
        if (j.type === "started") this.agent(j.agentId, j.label, j.phase);
        else if (j.type === "result") { const a = this.agent(j.agentId); a.journal = "done"; a.result = j.result; a.rev++; }
        else if (j.type === "failed") { const a = this.agent(j.agentId); a.journal = "failed"; a.rev++; }
      } catch {}
    }
    for (const f of readdirSafe(this.dir)) {
      const id = f.match(/^agent-(\w+)\.jsonl$/)?.[1];
      if (id && !this.agents.has(id)) this.agent(id);
    }
    // Old journals carry no label/phase; meta.json does. A torn read is retried next refresh.
    for (const id of [...this.needMeta]) {
      try { const meta = JSON.parse(readFileSync(join(this.dir, `agent-${id}.meta.json`), "utf8")); this.agent(id, meta.description, meta.workflowPhase); } catch {}
    }
    for (const a of this.agents.values()) {
      for (const l of a.tail.read()) a.feed(l);
      if (a.firstTs) this.start = Math.min(this.start, a.firstTs);
      this.last = Math.max(this.last, a.lastTs);
    }
    if (!this.finalPath && Date.now() - this.lastFinalLook > 5000) { this.lastFinalLook = Date.now(); this.finalPath = findFinal(this.sessionDir, this.runId); }
    if (this.finalPath) try {
      const mt = statSync(this.finalPath).mtimeMs;
      if (mt !== this.finalMtime) {
        const final = JSON.parse(readFileSync(this.finalPath, "utf8")); // parse first: a torn read retries
        this.finalMtime = mt;
        this.final = final;
        if (this.name === this.runId && final.workflowName) this.name = final.workflowName;
        if (!this.phases.length) this.phases = (final.phases ?? []).map((ph: any) => ph.title).filter(Boolean);
        const listed = new Set<string>();
        for (const e of final.workflowProgress ?? []) {
          if (e.type !== "workflow_agent" || !e.agentId) continue;
          listed.add(e.agentId);
          this.agent(e.agentId, e.label, e.phaseTitle).setFinal(e);
        }
        // Resumed, killed and retried runs leave started agents that the record never mentions.
        for (const a of this.agents.values()) if (!listed.has(a.id) && a.journal === "started") { a.superseded = true; a.rev++; }
        this.rev++;
      }
    } catch {}
    return this;
  }
  get startTs() { return this.start === Infinity ? Date.now() : this.start; }
  get lastTs() { return this.last; }
  visibleAgents(t: number) {
    let rev = this.rev;
    for (const a of this.agents.values()) rev += a.rev;
    if (this.visMemo && this.visMemo.t === t && this.visMemo.rev === rev) return this.visMemo.list;
    const list = [...this.agents.values()].filter((a) => a.state(t) !== "hidden");
    this.visMemo = { t, rev, list };
    return list;
  }
  status(t: number) {
    const ag = this.visibleAgents(t);
    if (ag.some((a) => a.state(t) === "running" || a.state(t) === "starting")) return "running";
    if (this.final && (!replay || t >= this.lastTs)) return this.final.status as string;
    if (ag.some((a) => a.state(t) === "stalled")) return "stalled";
    return replay ? "running" : "no final record";
  }
  live(t: number) { const s = this.status(t); return s === "running" || s === "stalled"; }
  span(t: number) { const t0 = this.startTs; return { t0, t1: Math.max(t0 + 1000, this.live(t) ? t : this.lastTs) }; }
}

// Freshness is the newest file in the run directory: the journal only changes on start/result,
// while transcripts change every few seconds.
export function discoverRuns(): { dir: string; mtime: number }[] {
  const out: { dir: string; mtime: number }[] = [], root = projectsDir();
  for (const p of readdirSafe(root)) {
    let ents: Dirent[] = [];
    try { ents = readdirSync(join(root, p), { withFileTypes: true }); } catch { continue; }
    for (const e of ents) {
      if (!e.isDirectory()) continue;
      const w = join(root, p, e.name, "subagents/workflows");
      if (!existsSync(w)) continue;
      for (const r of readdirSafe(w)) {
        if (!r.startsWith("wf_")) continue;
        let mtime = 0;
        for (const f of readdirSafe(join(w, r))) { try { mtime = Math.max(mtime, statSync(join(w, r, f)).mtimeMs); } catch {} }
        out.push({ dir: join(w, r), mtime });
      }
    }
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}
export function findRun(want?: string) {
  const runs = discoverRuns();
  if (!want) return runs[0];
  return runs.find((r) => r.dir.includes(want)) ?? runs.find((r) => new Run(r.dir).name.includes(want));
}

const SHORT: Record<string, string> = { Bash: "run", Read: "read", Edit: "edit", Write: "write", MultiEdit: "edit", NotebookEdit: "edit", Grep: "grep", Glob: "glob", LS: "ls",
  WebSearch: "search", WebFetch: "fetch", Agent: "agent", Task: "agent", Skill: "skill", ToolSearch: "tools", TodoWrite: "todo", StructuredOutput: "result" };
export const GROUPABLE = new Set(["Read", "Grep", "Glob", "LS"]);
export const kindOf = (n = "") => SHORT[n] ?? (n.startsWith("mcp__") ? n.split("__").pop()!.split("_")[0].slice(0, 6) : n.toLowerCase().slice(0, 6));
export function rel(p: string | undefined, cwd: string) {
  if (!p) return "";
  if (cwd && p.startsWith(cwd + "/")) return p.slice(cwd.length + 1);
  return p.startsWith(HOME) ? "~" + p.slice(HOME.length) : p;
}
// Long shell commands usually open with `cd <worktree> &&`; that prefix is noise in a one-line row.
const stripCd = (cmd: string, cwd: string) => cmd.replace(/^cd\s+("[^"]+"|'[^']+'|\S+)\s*(&&|;)\s*/, (m, d) => (rel(d.replace(/['"]/g, ""), cwd) === "" || d.includes(cwd) || d.startsWith("/") || d.startsWith("~") ? "" : m));
export function toolSummary(it: Item, cwd: string) {
  const i = it.input ?? {};
  switch (it.name) {
    case "Bash": return stripCd(firstLine(i.command), cwd);
    case "Read": return rel(i.file_path, cwd) + (i.offset ? `:${i.offset}` : "");
    case "Edit": case "Write": case "MultiEdit": return rel(i.file_path, cwd);
    case "NotebookEdit": return rel(i.notebook_path, cwd);
    case "Grep": return `${i.pattern}${i.path ? "  " + rel(i.path, cwd) : ""}`;
    case "Glob": return i.pattern ?? "";
    case "WebSearch": return i.query ?? "";
    case "WebFetch": return i.url ?? "";
    case "Agent": case "Task": return i.description ?? "";
    case "Skill": return i.skill ?? "";
    case "StructuredOutput": return resultLine(i);
    default: return firstLine(tellingString(i)) || JSON.stringify(i).slice(0, 200);
  }
}
export function toolHint(it: Item) {
  const r = it.result ?? "";
  const n = r.split("\n").filter((l) => l.trim()).length;
  switch (it.name) {
    case "Read": return `${n} lines`;
    case "Grep": case "Glob": return `${n} hits`;
    case "Edit": { const o = (it.input?.old_string ?? "").split("\n").length, w = (it.input?.new_string ?? "").split("\n").length; return `+${w} -${o}`; }
    case "Write": return `+${(it.input?.content ?? "").split("\n").length}`;
    case "StructuredOutput": return "";
    default: return lastLine(r);
  }
}
export function toolDetail(it: Item): string[] {
  const i = it.input ?? {};
  if (it.name === "Bash") return [`$ ${i.command ?? ""}`];
  if (it.name === "Edit") return [...(i.old_string ?? "").split("\n").slice(0, 6).map((l: string) => `- ${l}`), ...(i.new_string ?? "").split("\n").slice(0, 6).map((l: string) => `+ ${l}`)];
  if (it.name === "Write") return (i.content ?? "").split("\n").slice(0, 8);
  if (it.name === "Agent" || it.name === "Task") return (i.prompt ?? "").split("\n").slice(0, 8);
  return [JSON.stringify(i).slice(0, 400)];
}

// A plain snapshot of a run at time t: what --once --json prints and what tests assert on.
export function snapshot(run: Run, t = Date.now()) {
  const ag = run.visibleAgents(t);
  const phases = [...run.phases, ...(ag.some((a) => !a.phase) ? [""] : [])];
  return {
    runId: run.runId, name: run.name, project: run.project, status: run.status(t),
    durationMs: run.span(t).t1 - run.span(t).t0, totalTokens: run.final?.totalTokens ?? null,
    phases: phases.map((ph) => ({
      name: ph || "other",
      agents: ag.filter((a) => a.phase === ph).map((a) => {
        const s = a.snap(t);
        return {
          id: a.id, name: a.name, state: s.state, durationMs: a.end(t) - (a.firstTs || t), tools: s.tools, failedTools: s.errors, ctx: s.ctx,
          now: s.running ? `${kindOf(s.running.name)} ${toolSummary(s.running, a.cwd)}` : null,
          result: s.state === "done" || s.state === "cached" ? resultLine(a.result) : s.state === "failed" ? a.error : null,
        };
      }),
    })),
  };
}
