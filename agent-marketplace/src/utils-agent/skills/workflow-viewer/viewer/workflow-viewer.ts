// pi extension: a full-screen viewer for Claude Code Workflow runs. A list of the run's agents on
// the left (Tree, Table or Timeline), the selected agent's transcript on the right (pinned agents
// split it), an optional Stream tail of every agent's events, and zoom. Every action works by mouse
// alone, by keys alone, or both; `?` lists them. It only reads files (workflow-model.ts).
// The workflow-viewer launcher starts it as `pi -ne -e workflow-viewer.ts` with CCWF_VIEWER=1.
//   CCWF_RUN=<runId or name substring>  pick a run (default: the most recently active)
//   CCWF_REPLAY=<speed>                 replay a finished run as if live, at <speed>x
//   CCWF_MODE=tree|table|timeline       starting list mode (default: the last one used)
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { Markdown, matchesKey, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import {
  Agent, type AgentState, discoverRuns, dur, findRun, firstLine, GROUPABLE, type Item, kindOf, matches, projectOf, resultLine, Run, scriptMeta,
  setReplay, STALL_MS, toolDetail, toolHint, toolSummary, unframe,
} from "./workflow-model.ts";

const STATE = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "workflow-viewer");
const MODES = ["tree", "table", "timeline"] as const;
const DENSITIES = ["compact", "normal", "full"] as const;
const FOLLOW_IDLE_MS = 30_000; // auto-follow leaves an agent only after it finishes or idles this long
const JUMP_KEYS = "asdfghjklqwertyuiopzxcvbnm";
const B = 2; // first body row: the header and tab rows sit above it

const pad = (s: string, w: number) => truncateToWidth(s, Math.max(0, w), "…", true);
const clip = (s: string, w: number) => truncateToWidth(s, Math.max(0, w), "…");
// Labels like `A-control__metrics-ingestion__02` differ at the end, so cut from the middle.
const mid = (s: string, w: number) => (visibleWidth(s) <= w || w < 8 ? s : s.slice(0, Math.ceil((w - 1) * 0.55)) + "…" + s.slice(s.length - Math.floor((w - 1) * 0.45)));
const keepBg = (s: string) => s.split("\x1b[0m").join("\x1b[22;23;39m");
const plain = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "");
const kTok = (n: number) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`);
const clock = (ms: number) => new Date(ms).toTimeString().slice(0, 8);

// Clock: live, or a finished run replayed from its first event at `speed`x. Pausing freezes it (and
// stops reading files). A frame samples the clock once, so every agent in it is judged at one instant.
let speed = Number(process.env.CCWF_REPLAY ?? 0);
const REPLAY = speed > 0;
setReplay(REPLAY);
let replayBase = 0, replayWall = 0;
let pausedAt: number | undefined;
let frameT: number | undefined;
const rawNow = () => (REPLAY ? replayBase + (Date.now() - replayWall) * speed : Date.now());
const now = () => frameT ?? pausedAt ?? rawNow();
const setSpeed = (s: number) => { if (pausedAt == null) { replayBase = rawNow(); replayWall = Date.now(); } speed = Math.max(1, Math.min(512, s)); };
const togglePause = () => {
  if (pausedAt == null) pausedAt = rawNow();
  else { if (REPLAY) { replayBase = pausedAt; replayWall = Date.now(); } pausedAt = undefined; }
};

interface Row { text: string; key?: string; open?: boolean; problem?: boolean; live?: boolean; hay?: string }
interface Hit { x0: number; x1: number; y0: number; y1: number; click?: (ev: any) => void; wheel?: (d: number) => void; press?: (ev: any) => boolean; drag?: (ev: any) => void; right?: (ev: any) => void }
type Entry = { ph: string; a?: Agent };

export default function (pi: ExtensionAPI) {
  if (process.env.CCWF_VIEWER !== "1") return;

  pi.registerProvider("ccwf-viewer", {
    name: "ccwf",
    baseUrl: "ccwf://viewer",
    apiKey: "ccwf",
    api: "ccwf-viewer",
    models: [{ id: "viewer", name: "workflow viewer", input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 1000000, maxTokens: 64000 }],
    streamSimple(model) {
      // Registered only so a minimal pi starts fast; the overlay never runs the agent loop.
      const stream = createAssistantMessageEventStream();
      const message: any = { role: "assistant", content: [{ type: "text", text: "viewer only" }], api: model.api, provider: model.provider, model: model.id,
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } }, stopReason: "stop", timestamp: Date.now() };
      queueMicrotask(() => { stream.push({ type: "start", partial: message }); stream.push({ type: "done", reason: "stop", message }); });
      return stream;
    },
  });

  pi.on("session_start", async (_e, ctx) => {
    if (ctx.mode !== "tui") return;
    const model = ctx.modelRegistry.find("ccwf-viewer", "viewer");
    if (model) await pi.setModel(model);

    void ctx.ui.custom<void>((tui, theme, _kb, finish) => {
      const md = { ...getMarkdownTheme(), code: (t: string) => theme.fg("syntaxVariable", t) };
      const mdCache = new WeakMap<object, { key: string; lines: string[] }>();
      const markdown = (owner: object, text: string, width: number) => {
        const key = `${width}:${text.length}`;
        const hit = mdCache.get(owner);
        if (hit?.key === key) return hit.lines;
        const lines = new Markdown(text.trim(), 0, 0, md).render(width);
        mdCache.set(owner, { key, lines });
        return lines;
      };
      const saved = (k: string, d: string) => { try { return readFileSync(join(STATE, k), "utf8").trim() || d; } catch { return d; } };
      const save = (k: string, v: string) => { try { mkdirSync(STATE, { recursive: true }); writeFileSync(join(STATE, k), v + "\n"); } catch {} };

      // ---------- state ----------
      let mode = Math.max(0, MODES.indexOf((process.env.CCWF_MODE ?? saved("mode", "tree")) as any));
      let density = Math.max(0, DENSITIES.indexOf(saved("density", "normal") as any));
      const leftW = MODES.map((m) => Number(saved(`left-width-${m}`, "0")) || 0); // 0 = automatic
      let tailOpen = saved("tail", "off") === "on";
      let runs = discoverRuns();
      let run: Run | undefined;
      let selectedId: string | undefined;
      let cursorPhase: string | undefined; // list cursor on a phase row instead of an agent
      let auto = true; // follow the active agent until the user picks one
      let reveal = true; // scroll lists to the selection on the next frame (only after it changes)
      let focusPane: "list" | "detail" = "list";
      let zoom = false;
      let picker = false, pickerIdx = 0, pickerScroll = 0;
      let help = false, helpScroll = 0;
      let filter = "", filtering = false;
      let search = "", searching = false; // transcript search: n/N step through matches
      let jumping = false, jumpMap = new Map<string, string>(); // jump mode: a letter per visible agent
      let sortKey: "status" | "label" | "phase" | "time" | "tools" | "ctx" = "status", sortDesc = false;
      const SORTS = ["status", "label", "phase", "time", "tools", "ctx"] as const;
      const pins: string[] = [];
      const collapsed = new Set<string>();
      const listScroll = [0, 0, 0]; // one per mode
      let tailScroll = 0, tailFollow = true;
      let hits: Hit[] = [];
      let hover = { x: -1, y: -1 };
      let captured: Hit | undefined;
      let H = 40, W = 120, lastLeftW = 50;
      let flash = "", flashUntil = 0;
      const say = (m: string) => { flash = m; flashUntil = Date.now() + 2500; };

      const openRun = (dir: string) => {
        run = new Run(dir);
        run.refresh();
        selectedId = undefined; cursorPhase = undefined; auto = true; reveal = true; zoom = false; pins.length = 0; listScroll.fill(0); tailScroll = 0; tailFollow = true;
        if (REPLAY) { replayBase = run.startTs - 1000; replayWall = Date.now(); pausedAt = undefined; }
      };
      const initial = findRun(process.env.CCWF_RUN);
      if (initial) openRun(initial.dir);

      const tick = setInterval(() => { if (pausedAt == null) run?.refresh(); tui.requestRender(); }, REPLAY ? 250 : 1000);
      const rescan = setInterval(() => { runs = discoverRuns(); }, 10_000);

      // ---------- palette ----------
      const glyph = (s: AgentState) =>
        s === "running" || s === "starting" ? theme.fg("warning", "●") : s === "done" ? theme.fg("success", "✓") : s === "failed" ? theme.fg("error", "✗")
        : s === "stalled" ? theme.fg("error", "◐") : s === "cached" ? theme.fg("muted", "◇") : s === "abandoned" ? theme.fg("dim", "⊘") : theme.fg("muted", "○");
      const stateColor = (s: string) => (s === "running" || s === "starting" ? "warning" : s === "done" || s === "completed" || s === "cached" ? "success" : s === "failed" || s === "stalled" || s === "killed" ? "error" : s === "abandoned" ? "dim" : "muted");
      const PALETTE = ["accent", "success", "warning", "syntaxVariable", "syntaxString", "syntaxNumber", "syntaxType", "syntaxFunction", "mdLink", "thinkingHigh"];
      const colorOf = (id: string) => PALETTE[[...id].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7) % PALETTE.length];
      const hovered = (y: number, x0 = 0, x1 = 1e9) => hover.y === y && hover.x >= x0 && hover.x < x1;
      const hl = (text: string, w: number, selected: boolean, isHover: boolean) =>
        selected ? theme.bg("selectedBg", keepBg(pad(text, w))) : isHover ? theme.bg("userMessageBg", keepBg(pad(text, w))) : pad(text, w);
      const pill = (s: string) => {
        const bg = s === "running" || s === "starting" ? "toolPendingBg" : s === "completed" || s === "done" || s === "cached" ? "toolSuccessBg" : s === "failed" || s === "killed" || s === "stalled" ? "toolErrorBg" : "customMessageBg";
        return theme.bg(bg as any, theme.fg(stateColor(s) as any, theme.bold(` ${s} `)));
      };
      const phaseName = (ph: string) => ph || "other";
      // Jump mode replaces a row's first two columns with its letter.
      const jumpTag = (id: string) => { const k = jumping ? jumpMap.get(id) : undefined; return k ? theme.bg("selectedBg", theme.fg("accent", theme.bold(k))) + " " : undefined; };
      const jumpLetters: string[] = []; // agents in on-screen order, filled while the list renders
      const tagRow = (id: string) => { if (jumping && !jumpMap.has(id) && jumpLetters.length < JUMP_KEYS.length) { jumpMap.set(id, JUMP_KEYS[jumpLetters.length]); jumpLetters.push(id); } return jumpTag(id); };

      // ---------- agent lists ----------
      const RANK: Record<string, number> = { failed: 0, stalled: 1, running: 2, starting: 2, done: 4, cached: 5, abandoned: 6, hidden: 7 };
      const allAgents = () => (run ? run.visibleAgents(now()) : []);
      const agents = () => allAgents().filter((a) => !filter || matches(filter, `${a.name} ${a.phase}`));
      // Within a phase: problems first, then live work, then finished (Turborepo's order).
      const byStatus = (t: number) => (a: Agent, b: Agent) => (RANK[a.state(t)] ?? 3) - (RANK[b.state(t)] ?? 3) || a.firstTs - b.firstTs;
      const phaseList = () => (run ? [...run.phases, ...(agents().some((a) => !a.phase) ? [""] : [])] : []);
      // Tree/Timeline cursor targets: every phase row, then its agents when the phase is open.
      const entries = (): Entry[] => {
        const t = now(), ag = agents();
        return phaseList().flatMap((ph) => [{ ph }, ...(collapsed.has(ph) ? [] : ag.filter((a) => a.phase === ph).sort(mode === 2 ? (x, y) => (x.firstTs || t) - (y.firstTs || t) : byStatus(t)).map((a) => ({ ph, a })))]);
      };
      const tableOrder = () => {
        const t = now(), ag = [...agents()];
        const val = (a: Agent): number | string => {
          const s = a.snap(t);
          return sortKey === "label" ? a.name : sortKey === "phase" ? `${a.phase}` : sortKey === "time" ? a.end(t) - (a.firstTs || t) : sortKey === "tools" ? s.tools : sortKey === "ctx" ? s.ctx : RANK[s.state] ?? 3;
        };
        ag.sort((a, b) => { const x = val(a), y = val(b); const c = typeof x === "string" ? x.localeCompare(y as string) : (x as number) - (y as number); return (sortDesc ? -c : c) || a.firstTs - b.firstTs; });
        return ag;
      };
      const sel = () => run?.agents.get(selectedId ?? "");
      const pick = (id?: string) => { if (!id) return; if (id !== selectedId) reveal = true; selectedId = id; cursorPhase = undefined; auto = false; };
      const autoSelect = () => {
        if (!auto && sel()) return;
        const t = now(), ag = agents(), cur = sel();
        // Hysteresis: stay on the followed agent while it is live and recently active.
        if (auto && cur && cur.state(t) === "running" && t - cur.snap(t).lastAct < FOLLOW_IDLE_MS && ag.includes(cur)) return;
        const running = ag.filter((a) => a.state(t) === "running").sort((a, b) => b.snap(t).lastAct - a.snap(t).lastAct);
        const next = running[0] ?? ag.slice().sort((a, b) => b.lastTs - a.lastTs)[0];
        if (next && next.id !== selectedId) { selectedId = next.id; reveal = true; }
      };
      // j/k: phases and agents in Tree and Timeline, agents in Table.
      const step = (d: number) => {
        if (mode === 1) {
          const list = tableOrder();
          if (!list.length) return;
          const i = list.findIndex((a) => a.id === selectedId);
          return pick(list[Math.max(0, Math.min(list.length - 1, (i < 0 ? 0 : i) + d))].id);
        }
        const es = entries();
        if (!es.length) return;
        let i = cursorPhase != null ? es.findIndex((e) => !e.a && e.ph === cursorPhase) : es.findIndex((e) => e.a?.id === selectedId);
        i = Math.max(0, Math.min(es.length - 1, (i < 0 ? 0 : i) + d));
        const e = es[i];
        if (e.a) pick(e.a.id); else { cursorPhase = e.ph; auto = false; reveal = true; }
      };
      const togglePhase = (ph: string) => { collapsed.has(ph) ? collapsed.delete(ph) : collapsed.add(ph); };

      // ---------- transcript ----------
      // Dense rows: one line per tool call, consecutive reads/searches grouped, the running tool and
      // live thinking expanded until they finish. Density changes what is open by default. Each row
      // records whether it is open (so a toggle flips what is shown) and its searchable text.
      const transcriptRows = (a: Agent, width: number): Row[] => {
        const t = now(), snap = a.snap(t), rows: Row[] = [], live = snap.state === "running", dens = DENSITIES[density];
        const vis = snap.vis;
        const open = (key: string, auto: boolean) => a.overrides.get(key) ?? (dens === "full" ? true : auto);
        const indent = (lines: string[], color = "toolOutput", max = 12) => {
          const wrapped = lines.flatMap((l) => wrapTextWithAnsi(l, Math.max(10, width - 5)));
          const shown = wrapped.length > max ? wrapped.slice(-max) : wrapped;
          if (wrapped.length > max) rows.push({ text: theme.fg("dim", `   ┊ … ${wrapped.length - max} earlier lines`) });
          for (const l of shown) rows.push({ text: theme.fg("borderMuted", "   │ ") + theme.fg(color as any, l) });
        };
        const toolRow = (it: Item, nested = false) => {
          const doneNow = a.toolDone(it, t), key = it.key;
          const g = !doneNow ? (live ? theme.fg("accent", "◌") : theme.fg("dim", "◌")) : it.err ? theme.fg("error", "✗") : theme.fg("success", "✓");
          const took = doneNow && it.endTs! - it.ts >= 2000 ? theme.fg("dim", ` ${dur(it.endTs! - it.ts)}`) : "";
          const hint = doneNow ? toolHint(it) : theme.fg("warning", dur(t - it.ts));
          const o = open(key, !doneNow && live);
          const summary = clip(toolSummary(it, a.cwd), Math.max(10, Math.floor(width * 0.62) - 10));
          rows.push({ key, open: o, problem: it.err, live: !doneNow, hay: `${toolSummary(it, a.cwd)}\n${JSON.stringify(it.input ?? {})}\n${it.result ?? ""}`,
            text: `${nested ? theme.fg("borderMuted", "  ├ ") : ""}${g} ${theme.fg("muted", kindOf(it.name).padEnd(6))} ${summary}  ${theme.fg(it.err ? "error" : "dim", clip(String(hint), Math.max(8, width - visibleWidth(summary) - 16)))}${took}` });
          if (o) {
            indent(toolDetail(it), "text", 8);
            if (doneNow && it.result) indent(it.result.split("\n"), it.err ? "error" : "toolOutput", dens === "full" ? 40 : 12);
          }
        };
        let i = 0;
        while (i < vis.length) {
          const it = vis[i], key = it.key;
          if (it.t === "prompt" || (it.t === "note" && unframe(it.text).label === "task")) {
            const o = open(key, false), u = unframe(it.text), lab = u.label || "prompt";
            if (dens !== "compact" || lab === "task") {
              rows.push({ key, open: o, hay: u.body, text: `${theme.fg("accent", o ? "▾" : "▸")} ${theme.bold(lab.padEnd(7))} ${o ? "" : theme.fg(lab === "task" ? "text" : "muted", clip(firstLine(u.body), width - 12))}` });
              if (o) for (const l of markdown(it, u.body, width - 2)) rows.push({ text: "  " + l });
            }
            i++;
          } else if (it.t === "text") {
            const lastText = !vis.slice(i + 1).some((x) => x.t === "text");
            if (dens === "compact" && !(lastText && !live)) {
              const o = open(key, false);
              rows.push({ key, open: o, hay: it.text, text: `${theme.fg("muted", o ? "▾" : "▸")} ${theme.fg("text", "»")} ${theme.fg("text", clip(firstLine(it.text), width - 6))}` });
              if (o) for (const l of markdown(it, it.text ?? "", width - 4)) rows.push({ text: "    " + l });
            } else {
              rows.push({ text: "" });
              for (const l of markdown(it, it.text ?? "", width - 2)) rows.push({ text: "  " + l });
              rows.push({ text: "" });
            }
            i++;
          } else if (it.t === "note") {
            if (dens !== "compact" && !/^\[Image[: ]/.test(it.text ?? "")) {
              const o = open(key, false);
              rows.push({ key, open: o, hay: it.text, text: `${theme.fg("muted", o ? "▾" : "▸")} ${theme.fg("muted", "user")}  ${theme.fg("dim", clip(firstLine(it.text), width - 12))}` });
              if (o) indent((it.text ?? "").split("\n"), "muted", 40);
            }
            i++;
          } else if (it.t === "think") {
            const thinking = live && i === vis.length - 1;
            if (dens !== "compact" || thinking) {
              const o = open(key, thinking);
              rows.push({ key, open: o, live: thinking, hay: it.text, text: `${theme.fg("muted", o ? "▾" : "▸")} ${theme.fg("thinkingText", theme.italic(thinking ? "thinking…" : "thought"))}  ${theme.fg("muted", clip(firstLine(it.text).replace(/\*\*/g, ""), width - 16))}` });
              if (o) indent((it.text ?? "").split("\n").filter((l) => l.trim()), "thinkingText", thinking ? 6 : 400);
            }
            i++;
          } else {
            let j = i;
            while (j < vis.length && vis[j].t === "tool" && GROUPABLE.has(vis[j].name ?? "") && a.toolDone(vis[j], t)) j++;
            if (j - i >= 2) {
              const group = vis.slice(i, j), gkey = `g:${it.key}`, o = open(gkey, false), bad = group.some((g) => g.err);
              const kinds = [...new Set(group.map((g) => kindOf(g.name)))].join("/");
              rows.push({ key: gkey, open: o, problem: bad, hay: group.map((g) => `${toolSummary(g, a.cwd)}\n${g.result ?? ""}`).join("\n"),
                text: `${theme.fg("accent", o ? "▾" : "▸")}${bad ? theme.fg("error", "✗") : theme.fg("success", "✓")} ${theme.fg("muted", kinds.padEnd(6))}${theme.fg("accent", `×${group.length}`)} ${clip(group.map((g) => basename(toolSummary(g, a.cwd).split("  ")[0])).join(", "), width - 20)}` });
              if (o) group.forEach((g) => toolRow(g, true));
              i = j;
            } else { toolRow(it); i++; }
          }
        }
        if (snap.state === "failed") rows.push({ text: theme.fg("error", `  ✗ agent failed${a.error ? `: ${a.error}` : ""}`), problem: true });
        else if (snap.state === "stalled") rows.push({ text: theme.fg("error", `  ◐ no activity for ${dur(t - snap.lastAct)} and no result in the journal`), problem: true });
        else if (snap.state === "abandoned") rows.push({ text: theme.fg("dim", "  ⊘ the run finished without this agent's result (resumed, retried or killed)") });
        else if (snap.state === "done" && a.result && dens === "compact") rows.push({ text: theme.fg("success", "  ✓ ") + theme.fg("text", clip(resultLine(a.result), width - 6)) });
        if (!vis.length) rows.push({ text: theme.fg("muted", snap.state === "cached" ? "  cached result reused; no transcript" : "  waiting for the first event…") });
        return rows;
      };
      let lastBlock: { a: Agent; rows: Row[]; h: number } | undefined;
      const rowsFor = (a: Agent) => (lastBlock?.a === a ? lastBlock.rows : transcriptRows(a, 80));
      const isMatch = (r: Row) => !!search && matches(search, r.hay ?? plain(r.text));

      // Card header: identity + live numbers on one line; what it is doing now (or how it ended) next.
      let cardX = 0;
      const card = (a: Agent, w: number, y: number): string[] => {
        const t = now(), s = a.snap(t);
        const left = ` ${glyph(s.state)} ${theme.bold(mid(a.name, Math.max(12, w - 40)))} ${pill(s.state)}${auto && a.id === selectedId ? theme.fg("accent", " ⟳") : ""}`;
        // Right: numbers, dropped lowest-priority first until both sides fit.
        const fields: [number, string][] = [
          [0, theme.fg(s.state === "running" ? "warning" : "muted", dur(a.end(t) - (a.firstTs || t)))],
          [1, theme.fg("muted", `${s.tools} tools`)],
          ...(s.errors ? [[0.5, theme.fg("error", `${s.errors} failed`)] as [number, string]] : []),
          ...(a.final?.attempt > 1 ? [[2, theme.fg("warning", `attempt ${a.final.attempt}`)] as [number, string]] : []),
          [3, theme.fg("muted", `ctx ${kTok(s.ctx)}`)],
          [5, theme.fg("dim", (a.model || a.final?.model || "").replace("claude-", ""))],
          [6, theme.fg("dim", phaseName(a.phase))],
        ];
        const isPinned = pins.includes(a.id);
        const pinB = theme.fg(isPinned ? "accent" : "dim", isPinned ? "◆ pinned" : "◇ pin");
        let keep = fields.slice();
        const rightOf = (f: [number, string][]) => [...f.map((x) => x[1]), pinB].join(theme.fg("borderMuted", " · ")) + " ";
        while (keep.length > 1 && visibleWidth(left) + visibleWidth(rightOf(keep)) + 2 > w) keep = keep.filter((x) => x[0] !== Math.max(...keep.map((k) => k[0])));
        const right = rightOf(keep);
        const pinX = w - visibleWidth(pinB) - 1;
        const line1 = clip(left, Math.max(10, w - visibleWidth(right) - 1));
        hits.push({ x0: cardX + pinX, x1: cardX + w, y0: y, y1: y + 1, click: () => { pick(a.id); act("pin"); } });
        hits.push({ x0: cardX, x1: cardX + pinX, y0: y, y1: y + 2, click: () => pick(a.id) });
        const status = s.state === "running"
          ? (s.running ? `${theme.fg("accent", "◌")} ${s.longTool ? theme.fg("warning", "in ") : ""}${theme.fg("muted", kindOf(s.running.name))} ${toolSummary(s.running, a.cwd)} ${theme.fg("warning", (s.longTool ? "for " : "") + dur(t - s.running.ts))}` : theme.fg("thinkingText", "thinking…"))
          : s.state === "done" || s.state === "cached" ? theme.fg("success", "✓ ") + theme.fg("text", resultLine(a.result) || s.state)
          : s.state === "failed" ? theme.fg("error", `✗ ${a.error || "failed"}`)
          : s.state === "stalled" ? theme.fg("error", `◐ no activity for ${dur(t - s.lastAct)}`)
          : s.state === "abandoned" ? theme.fg("dim", "⊘ superseded: the run finished without this agent's result") : theme.fg("muted", a.task);
        return [pad(line1 + " ".repeat(Math.max(1, w - visibleWidth(line1) - visibleWidth(right))) + right, w), pad(`   ${clip(status, w - 4)}`, w)];
      };

      // A transcript block at (x, y), w×h, with a minimap scrollbar in its last column. The minimap
      // marks failed calls (red), the running call (accent) and search matches (warning); click or
      // drag it to jump.
      const scrollBy = (a: Agent, d: number, max: number) => { a.scroll = Math.max(0, Math.min(max, a.scroll + d)); a.follow = a.scroll >= max; if (d < 0) auto = false; };
      const transcriptBlock = (a: Agent | undefined, x: number, y: number, w: number, h: number, focused: boolean): string[] => {
        if (h <= 0) return [];
        if (!a) return Array.from({ length: h }, (_, k) => pad(k === 1 ? theme.fg("muted", "   select an agent") : "", w));
        const tw = w - 1;
        const rows = transcriptRows(a, tw - 1);
        const max = Math.max(0, rows.length - h);
        if (a.follow) a.scroll = max;
        a.scroll = Math.max(0, Math.min(a.scroll, max));
        const thumb0 = rows.length ? Math.floor((a.scroll / rows.length) * h) : 0;
        const thumb1 = rows.length ? Math.max(thumb0 + 1, Math.ceil(((a.scroll + h) / rows.length) * h)) : h;
        const marks = Array<string>(h).fill("");
        rows.forEach((r, k) => {
          const c = Math.min(h - 1, Math.floor((k / Math.max(1, rows.length)) * h));
          if (r.problem) marks[c] = "error"; else if (focused && isMatch(r) && marks[c] !== "error") marks[c] = "warning"; else if (r.live && !marks[c]) marks[c] = "accent";
        });
        const out: string[] = [];
        for (let k = 0; k < h; k++) {
          const r = rows[a.scroll + k];
          const isCursor = !!r?.key && r.key === a.cursor && focused;
          const gutter = r && focused && isMatch(r) ? theme.fg("warning", "▌") : " ";
          const text = hl(gutter + (r?.text ?? ""), tw, isCursor, !!r?.key && hovered(y + k, x, x + tw));
          const inThumb = k >= thumb0 && k < thumb1;
          const m = marks[k] ? theme.fg(marks[k] as any, inThumb ? "┃" : "▪") : inThumb ? theme.fg("scrollbarThumb" as any, "┃") : theme.fg("borderMuted", "│");
          out.push(text + (rows.length > h ? m : " "));
        }
        if (!a.follow && max - a.scroll > 0 && h > 2) {
          out[h - 1] = pad(theme.bg("customMessageBg", theme.fg("accent", ` ↓ ${max - a.scroll} more below · f follows `)), tw) + out[h - 1].slice(-1);
          hits.push({ x0: x, x1: x + 30, y0: y + h - 1, y1: y + h, click: () => { a.follow = true; } });
        }
        const jump = (yy: number) => { a.follow = false; auto = false; a.scroll = Math.max(0, Math.min(max, Math.round(((yy - y) / h) * rows.length - h / 2))); if (a.scroll >= max) a.follow = true; };
        hits.push({ x0: x + tw, x1: x + w, y0: y, y1: y + h, press: (ev) => { jump(ev.y); return true; }, drag: (ev) => jump(ev.y), wheel: (d) => scrollBy(a, d * 3, max) });
        hits.push({ x0: x, x1: x + tw, y0: y, y1: y + h,
          click: (ev) => {
            if (ev.clickCount >= 2) return; // the first click already toggled
            const r = rows[a.scroll + ev.y - y]; pick(a.id); focusPane = "detail";
            if (r?.key) { a.cursor = r.key; a.follow = false; a.overrides.set(r.key, !r.open); }
          },
          wheel: (d) => scrollBy(a, d * 3, max) });
        if (focused) lastBlock = { a, rows, h };
        return out;
      };
      const toggleRow = (a: Agent, key: string) => { const r = rowsFor(a).find((x) => x.key === key); a.overrides.set(key, !(r?.open ?? false)); };
      const moveCursor = (a: Agent, dir: number) => {
        const rows = rowsFor(a);
        const keyed = rows.map((r, i) => ({ r, i })).filter((x) => x.r.key);
        if (!keyed.length) return;
        let at = keyed.findIndex((x) => x.r.key === a.cursor);
        at = at < 0 ? (dir > 0 ? Math.max(0, keyed.findIndex((x) => x.i >= a.scroll)) : keyed.length - 1) : Math.max(0, Math.min(keyed.length - 1, at + dir));
        const target = keyed[at];
        a.cursor = target.r.key; a.follow = false;
        const h = lastBlock?.h ?? 20;
        if (target.i < a.scroll) a.scroll = target.i;
        if (target.i >= a.scroll + h) a.scroll = target.i - h + 1;
      };
      // Jump between rows whose text, input or output matches; a match hidden in a folded row opens it.
      const stepMatch = (a: Agent, dir: number, pred: (r: Row) => boolean, none: string) => {
        const rows = rowsFor(a);
        const hitsAt = rows.map((r, i) => ({ r, i })).filter((x) => x.r.key && pred(x.r));
        if (!hitsAt.length) return say(none);
        const cur = rows.findIndex((r) => r.key === a.cursor);
        const next = dir > 0 ? hitsAt.find((x) => x.i > cur) ?? hitsAt[0] : [...hitsAt].reverse().find((x) => x.i < cur) ?? hitsAt[hitsAt.length - 1];
        a.cursor = next.r.key; a.follow = false; auto = false; a.scroll = Math.max(0, next.i - 3);
        if (pred === isMatch && !matches(search, plain(next.r.text))) a.overrides.set(next.r.key!, true);
        if (pred === isMatch) say(`match ${hitsAt.indexOf(next) + 1}/${hitsAt.length}`);
      };
      // The sections of the detail pane: the selection, then pinned agents (up to three panes).
      const detailAgents = () => { const s = sel(); return [...new Set([s, ...pins.map((id) => run?.agents.get(id))].filter(Boolean))].slice(0, 3) as Agent[]; };

      // ---------- actions (keys, clicks and hints share these) ----------
      const act = (name: string) => {
        const a = sel();
        switch (name) {
          case "zoom": if (a) { zoom = !zoom; focusPane = "detail"; auto = false; } break;
          case "back":
            if (search) search = "";
            else if (zoom) zoom = false;
            else if (filter) filter = "";
            else if (focusPane === "detail") { if (a?.cursor) a.cursor = undefined; else focusPane = "list"; }
            else if (cursorPhase != null) cursorPhase = undefined;
            break;
          case "pin": { if (!a) break; const i = pins.indexOf(a.id); if (i >= 0) pins.splice(i, 1); else { pins.push(a.id); if (pins.length > 2) pins.shift(); } say(i >= 0 ? `unpinned ${a.name}` : `pinned ${a.name}`); break; }
          case "follow": if (a) { a.follow = true; a.cursor = undefined; } tailFollow = true; break;
          case "top": if (a) { a.follow = false; a.scroll = 0; auto = false; } break;
          case "auto": auto = true; say("following the active agent"); break;
          case "nextErr": case "prevErr": {
            const d = name === "nextErr" ? 1 : -1;
            if (focusPane === "detail" || zoom) { if (a) stepMatch(a, d, (r) => !!r.problem, "no failed tool calls in this agent"); break; }
            const t = now(), list = mode === 1 ? tableOrder() : entries().filter((e) => e.a).map((e) => e.a!);
            const bad = list.filter((x) => x.state(t) === "failed" || x.state(t) === "stalled" || x.snap(t).errors);
            if (!bad.length) { say("no failed agents or tool calls"); break; }
            const i = bad.findIndex((x) => x.id === selectedId);
            pick(bad[(i + d + bad.length) % bad.length].id);
            break;
          }
          case "nextMatch": case "prevMatch": if (a && search) stepMatch(a, name === "nextMatch" ? 1 : -1, isMatch, `no match for "${search}"`); break;
          case "search": if (a) { searching = true; search = ""; focusPane = "detail"; auto = false; } break;
          case "density": density = (density + 1) % DENSITIES.length; save("density", DENSITIES[density]); break;
          case "filter": filtering = true; break;
          case "help": help = !help; helpScroll = 0; break;
          case "runs": runs = discoverRuns(); picker = true; pickerIdx = Math.max(0, runs.findIndex((r) => r.dir === run?.dir)); break;
          case "closeRuns": picker = false; break;
          case "tail": tailOpen = !tailOpen; tailFollow = true; save("tail", tailOpen ? "on" : "off"); break;
          case "jump": jumping = true; jumpMap = new Map(); jumpLetters.length = 0; break;
          case "pause": togglePause(); break;
          case "faster": if (REPLAY) setSpeed(speed * 2); else say("speed applies to replays (CCWF_REPLAY)"); break;
          case "slower": if (REPLAY) setSpeed(speed / 2); else say("speed applies to replays (CCWF_REPLAY)"); break;
          case "expandAll": case "collapseAll": if (a) for (const r of transcriptRows(a, 80)) if (r.key) a.overrides.set(r.key, name === "expandAll"); break;
          case "fold": {
            if ((focusPane === "detail" || zoom) && a?.cursor) { toggleRow(a, a.cursor); break; }
            if (mode === 1) { act("zoom"); break; }
            if (cursorPhase != null) { togglePhase(cursorPhase); break; }
            // Folding from an agent folds its phase and leaves the cursor on that phase row,
            // so the next press unfolds it again.
            if (a) { cursorPhase = a.phase; collapsed.add(a.phase); reveal = true; }
            break;
          }
          case "sort": { sortKey = SORTS[(SORTS.indexOf(sortKey) + 1) % SORTS.length]; sortDesc = sortKey === "time" || sortKey === "tools" || sortKey === "ctx"; say(`sorted by ${sortKey}`); break; }
          case "reverse": sortDesc = !sortDesc; break;
          case "wider": case "narrower": leftW[mode] = Math.max(28, Math.min(W - 40, (leftW[mode] || lastLeftW) + (name === "wider" ? 4 : -4))); save(`left-width-${MODES[mode]}`, String(leftW[mode])); break;
          case "quit": finish(); break;
        }
        if (name.startsWith("mode")) { mode = Number(name.slice(4)); zoom = false; picker = false; focusPane = "list"; cursorPhase = undefined; reveal = true; save("mode", MODES[mode]); }
      };

      // ---------- chrome ----------
      // Header: run identity and counts, the phase strip (scaled to the room left), then the clock
      // controls. Controls register their hits first, and phase hits only where the phase is drawn.
      const header = (w: number) => {
        if (!run) return pad(theme.fg("muted", " no workflow runs under ~/.claude/projects"), w);
        const t = now(), st = run.status(t), ag = run.visibleAgents(t);
        const n = (s: AgentState) => ag.filter((a) => a.state(t) === s).length;
        const { t0, t1 } = run.span(t);
        const tot = run.final && (!REPLAY || t >= run.lastTs) ? run.final.totalTokens : undefined;
        const chips: [string, () => void][] = pausedAt != null
          ? [[theme.bg("toolErrorBg", theme.fg("warning", theme.bold(" ❚❚ paused "))), () => act("pause")]]
          : REPLAY ? [] : [[run.live(t) ? theme.fg("success", " ● live ") : theme.fg("muted", " ○ finished "), () => act("pause")]];
        if (REPLAY) chips.push([theme.fg("accent", " ◂ "), () => act("slower")], [theme.fg("accent", `${speed}x`) + (pausedAt == null ? theme.fg("dim", " ⏵") : ""), () => act("pause")], [theme.fg("accent", " ▸ "), () => act("faster")], [theme.fg("dim", clock(t) + " "), () => act("pause")]);
        const rw = chips.reduce((s, [c]) => s + visibleWidth(c), 0);
        let cx = w - rw;
        for (const [c, f] of chips) { const cw = visibleWidth(c); hits.push({ x0: cx, x1: cx + cw, y0: 0, y1: 1, click: f }); cx += cw; }
        let x = 0;
        const parts: string[] = [];
        const push = (s: string) => { parts.push(s); x += visibleWidth(s); };
        push(` ${theme.fg("accent", "◆")} ${theme.bold(run.name)} `);
        push(pill(st));
        push(theme.fg("muted", ` ${dur(t1 - t0)} `));
        const live = n("running") + n("starting");
        push(`${theme.fg("success", `✓${n("done") + n("cached")}`)}${live ? theme.fg("warning", ` ●${live}`) : ""}${n("failed") ? theme.fg("error", ` ✗${n("failed")}`) : ""}${n("stalled") ? theme.fg("error", ` ◐${n("stalled")}`) : ""}${n("abandoned") ? theme.fg("dim", ` ⊘${n("abandoned")}`) : ""}${theme.fg("muted", ` /${ag.length}`)}${tot ? theme.fg("muted", ` · ${kTok(tot)} tok`) : ""}  `);
        const avail = w - rw - 1 - x;
        const names = run.phases.map((ph) => clip(phaseName(ph), 12));
        const fixed = names.reduce((s, nm) => s + visibleWidth(nm) + 3, 0);
        const cap = Math.min(14, Math.floor((avail - fixed) / Math.max(1, run.phases.length)) - 1);
        run.phases.forEach((ph, k) => {
          const inPh = ag.filter((a) => a.phase === ph);
          const done = inPh.filter((a) => ["done", "cached"].includes(a.state(t))).length;
          let body: string;
          if (cap >= 3) {
            const sorted = inPh.slice().sort(byStatus(t)).reverse();
            body = sorted.slice(0, cap).map((a) => theme.fg(stateColor(a.state(t)) as any, a.state(t) === "running" ? "▰" : "■")).join("") + (inPh.length > cap ? theme.fg("muted", `+${inPh.length - cap}`) : "") || theme.fg("dim", "·");
          } else body = inPh.length ? theme.fg(done === inPh.length ? "success" : "muted", `${done}/${inPh.length}`) : theme.fg("dim", "·");
          const seg = `${theme.fg(hovered(0, x, x + visibleWidth(names[k]) + 1) ? "accent" : "text", names[k])} ${body}  `;
          const sw = visibleWidth(seg);
          if (x + sw <= w - rw - 1) hits.push({ x0: x, x1: x + sw, y0: 0, y1: 1, click: () => { collapsed.delete(ph); picker = false; zoom = false; cursorPhase = ph; auto = false; reveal = true; if (mode === 1) act("mode0"); } });
          push(seg);
        });
        const left = clip(parts.join(""), w - rw - 1);
        return pad(left + " ".repeat(Math.max(1, w - visibleWidth(left) - rw)) + chips.map(([c]) => c).join(""), w);
      };
      const tabsRow = (w: number) => {
        let x = 0, out = "";
        const narrow = w < 120;
        const button = (label: string, onClick: () => void, active = false) => {
          const lw = visibleWidth(label);
          if (x + lw > w) return;
          const s = active ? theme.bg("selectedBg", theme.bold(label)) : hovered(1, x, x + lw) ? theme.bg("userMessageBg", label) : label;
          hits.push({ x0: x, x1: x + lw, y0: 1, y1: 2, click: onClick });
          out += s; x += lw;
        };
        const sep = (s = " ") => { out += s; x += visibleWidth(s); };
        sep();
        if (zoom) {
          // Breadcrumb: run › phase › agent; each part is a way back out.
          const a = sel();
          button(theme.fg("accent", " ← "), () => act("back"));
          button(theme.fg("muted", ` ${clip(run?.name ?? "", 24)} `), () => act("back"));
          sep(theme.fg("borderMuted", "›"));
          button(theme.fg("muted", ` ${phaseName(a?.phase ?? "")} `), () => { if (a) { zoom = false; cursorPhase = a.phase; collapsed.delete(a.phase); reveal = true; } });
          sep(theme.fg("borderMuted", "›"));
          button(theme.bold(` ${mid(a?.name ?? "", 32)} `), () => {}, true);
        } else MODES.forEach((m, i) => button(` ${theme.fg("accent", String(i + 1))} ${narrow ? m.slice(0, 4) : m[0].toUpperCase() + m.slice(1)} `, () => act(`mode${i}`), i === mode && !picker));
        sep(theme.fg("borderMuted", " │"));
        button(` ${theme.fg("accent", "t")} ${tailOpen ? "stream ✓" : "stream"} `, () => act("tail"), tailOpen);
        const runsB = picker ? theme.fg("accent", " ⇄ runs ✕ ") : theme.fg("muted", ` ⇄ ${runs.length} runs `);
        if (narrow) button(runsB, () => act(picker ? "closeRuns" : "runs"), picker);
        sep(theme.fg("borderMuted", "│"));
        if (narrow) button(` ${theme.fg("accent", "d")} ${DENSITIES[density]} `, () => act("density"));
        else DENSITIES.forEach((d, i) => { button(i === density ? theme.fg("text", ` ${d} `) : theme.fg("muted", ` ${d} `), () => { density = i; save("density", d); }, i === density); });
        sep(theme.fg("borderMuted", "│"));
        if (searching || search) {
          button(` ${theme.fg("warning", `🔍 ${search}${searching ? "▏" : ""}`)}${search ? theme.fg("muted", " n/N ✕") : ""} `, () => { if (search && !searching) search = ""; else searching = true; });
        } else {
          const shown = filter ? theme.fg("muted", ` ${agents().length}/${allAgents().length}`) : "";
          const f = filtering ? theme.fg("warning", `/ ${filter}▏`) + shown : filter ? theme.fg("warning", `/ ${filter}`) + shown + theme.fg("muted", " ✕") : theme.fg("muted", "/ filter");
          button(` ${f} `, () => { if (filter && !filtering) filter = ""; else filtering = true; });
        }
        if (!narrow) { sep(" ".repeat(Math.max(1, w - x - visibleWidth(runsB)))); button(runsB, () => act(picker ? "closeRuns" : "runs"), picker); }
        return pad(out, w);
      };
      const hintBar = (y: number, w: number, items: [string, string, string][]) => {
        let x = 0, out = "";
        if (flash && Date.now() < flashUntil) { const f = theme.fg("accent", ` ${flash} `); out += f; x += visibleWidth(f); }
        for (const [key, label, action] of items) {
          const s = ` ${theme.fg("accent", key)} ${theme.fg("muted", label)} `;
          const lw = visibleWidth(s);
          if (x + lw > w) break;
          out += hovered(y, x, x + lw) ? theme.bg("userMessageBg", s) : s;
          hits.push({ x0: x, x1: x + lw, y0: y, y1: y + 1, click: () => act(action) });
          x += lw;
        }
        return pad(out, w);
      };
      // Keep the selection on screen only right after it changes, so the wheel can browse freely.
      const keepVisible = (first: number, last: number, h: number, total: number) => {
        if (reveal && first >= 0) {
          if (first < listScroll[mode]) listScroll[mode] = Math.max(0, first - 1);
          if (last >= listScroll[mode] + h) listScroll[mode] = last - h + 1;
        }
        listScroll[mode] = Math.max(0, Math.min(listScroll[mode], Math.max(0, total - h)));
      };
      // Shared list wiring: click selects (double-click zooms), right-click pins, wheel scrolls.
      const listHits = (x1: number, y0: number, h: number, at: (y: number) => { id?: string; ph?: string } | undefined) =>
        hits.push({ x0: 0, x1, y0, y1: y0 + h,
          click: (ev) => { const r = at(ev.y); focusPane = "list"; zoom = false; if (!r) return;
            if (r.id) { pick(r.id); if (ev.clickCount >= 2) act("zoom"); }
            else if (r.ph != null) { cursorPhase = r.ph; auto = false; if (ev.clickCount < 2) togglePhase(r.ph); } },
          right: (ev) => { const r = at(ev.y); if (r?.id) { pick(r.id); act("pin"); } },
          wheel: (d) => { listScroll[mode] = Math.max(0, listScroll[mode] + d * 2); } });

      // ---------- list modes ----------
      const miniBar = (a: Agent, t0: number, t1: number, w: number, t: number) => {
        const s = a.state(t), col = (x: number) => Math.max(0, Math.min(w - 1, Math.floor(((x - t0) / (t1 - t0)) * w)));
        const c0 = col(a.final?.queuedAt && a.final.queuedAt < a.firstTs ? a.final.queuedAt : a.firstTs || t), c1 = col(a.firstTs || t), c2 = col(a.end(t));
        let out = "";
        for (let c = 0; c < w; c++) out += c >= c1 && c <= c2 ? theme.fg(stateColor(s) as any, "━") : c >= c0 && c < c1 ? theme.fg("dim", "╌") : " ";
        return out;
      };
      const phaseCounts = (ph: string, t: number, ended: boolean) => {
        const inPh = agents().filter((a) => a.phase === ph);
        const c = (s: AgentState) => inPh.filter((a) => a.state(t) === s).length, live = c("running") + c("starting");
        if (!inPh.length) return { inPh, text: theme.fg("dim", ended ? "skipped" : "planned") };
        return { inPh, text: `${theme.fg("success", `✓${c("done") + c("cached")}`)}${live ? theme.fg("warning", ` ●${live}`) : ""}${c("failed") ? theme.fg("error", ` ✗${c("failed")}`) : ""}${c("stalled") ? theme.fg("error", ` ◐${c("stalled")}`) : ""}${c("abandoned") ? theme.fg("dim", ` ⊘${c("abandoned")}`) : ""}${theme.fg("muted", `/${inPh.length}`)}` };
      };

      // Tree: lanes like git log --graph; running agents get a second line with the live tool call,
      // and a small bar shows when each agent ran within the whole run.
      type LRow = { text: string; id?: string; ph?: string; problem?: boolean; lead?: string }; // lead: two columns a jump letter can replace
      const treeRows = (w: number): LRow[] => {
        if (!run) return [];
        const t = now(), rows: LRow[] = [], { t0, t1 } = run.span(t), ended = !run.live(t);
        const bw = w >= 52 ? Math.min(16, Math.floor(w * 0.22)) : 0;
        const es = entries();
        es.forEach((e, k) => {
          if (!e.a) {
            const { inPh, text } = phaseCounts(e.ph, t, ended);
            const span = inPh.length ? theme.fg("muted", dur(Math.max(...inPh.map((a) => a.end(t))) - Math.min(...inPh.map((a) => a.firstTs || t)))) : "";
            const head = `${theme.fg("accent", collapsed.has(e.ph) ? "▸" : "▾")} ${theme.bold(phaseName(e.ph))} ${text}`;
            rows.push({ ph: e.ph, text: head + " ".repeat(Math.max(1, w - visibleWidth(head) - visibleWidth(span) - 1)) + span });
            return;
          }
          const a = e.a, s = a.snap(t), last = !es[k + 1]?.a;
          const right = (bw ? miniBar(a, t0, t1, bw, t) + " " : "") + theme.fg(s.state === "running" ? "warning" : "muted", dur(a.end(t) - (a.firstTs || t)).padStart(6));
          const lw = w - 4 - visibleWidth(right) - 1;
          const lab = mid(a.name, lw);
          const name = s.state === "failed" ? theme.fg("error", lab) : s.state === "done" || s.state === "cached" ? theme.fg("text", lab) : s.state === "abandoned" ? theme.fg("dim", lab) : theme.bold(lab);
          rows.push({ id: a.id, problem: s.state === "failed", lead: theme.fg("borderMuted", last ? "└ " : "├ "), text: `${glyph(s.state)} ${pad(name, lw)} ${right}` });
          if (s.state === "running" || s.state === "stalled") {
            const what = s.state === "stalled" ? theme.fg("error", `idle ${dur(t - s.lastAct)} · no result yet`)
              : s.running ? `${theme.fg("accent", "◌")} ${theme.fg("muted", kindOf(s.running.name))} ${toolSummary(s.running, a.cwd)} ${theme.fg("warning", dur(t - s.running.ts))}`
              : s.lastTool ? theme.fg("dim", `last: ${kindOf(s.lastTool.name)} ${toolSummary(s.lastTool, a.cwd)}`) : theme.fg("dim", s.vis.length ? "thinking…" : "starting…");
            rows.push({ id: a.id, text: `${theme.fg("borderMuted", last ? " " : "│")}   ${clip(what, w - 6)}` });
          }
        });
        if (!es.some((e) => e.a)) rows.push({ text: theme.fg("muted", filter ? `  nothing matches /${filter}` : "  waiting for agents…") });
        return rows;
      };
      const renderTree = (lw: number, h: number): string[] => {
        const rows = treeRows(lw);
        const isSel = (r?: LRow) => !!r && (cursorPhase != null ? r.ph === cursorPhase && !r.id : !!r.id && r.id === selectedId);
        const idx = rows.map((r, k) => (isSel(r) ? k : -1)).filter((k) => k >= 0);
        keepVisible(idx[0] ?? -1, idx[idx.length - 1] ?? -1, h, rows.length);
        const top = listScroll[mode];
        listHits(lw, B, h, (y) => rows[top + y - B]);
        const out: string[] = [];
        for (let y = 0; y < h; y++) {
          const r = rows[top + y];
          const text = r?.lead != null ? (r.id ? tagRow(r.id) : undefined) ?? r.lead : "";
          let line = hl(text + (r?.text ?? ""), lw, isSel(r) && focusPane === "list", isSel(r) || (!!r && (r.id != null || r.ph != null) && hovered(B + y, 0, lw)));
          if (y === 0 && top > 0) line = pad(theme.fg("muted", `  ↑ ${top} more`), lw);
          if (y === h - 1 && top + h < rows.length) line = pad(theme.fg("muted", `  ↓ ${rows.length - top - h} more`), lw);
          out.push(line);
        }
        return out;
      };
      // Table: sortable columns (click a header or press s/S); columns drop as the pane narrows.
      const renderTable = (lw: number, h: number): string[] => {
        const t = now(), list = tableOrder(), { t0, t1 } = run ? run.span(t) : { t0: 0, t1: 1 };
        const show = { ctx: lw >= 64, phase: lw >= 78, bar: lw >= 96, now: lw >= 70 };
        const nw = Math.min(28, Math.max(14, Math.floor(lw * 0.26))), pw = 12, bw = 14;
        const cols: [typeof sortKey, string, number][] = [["status", "", 4], ["label", "agent", nw + 1], ...(show.phase ? [["phase", "phase", pw + 1] as [typeof sortKey, string, number]] : []), ["time", "  time", 7], ["tools", "tools", 6], ...(show.ctx ? [["ctx", "  ctx", 6] as [typeof sortKey, string, number]] : [])];
        let x = 1, head = " ";
        for (const [k, label, cw] of cols) {
          const s = pad((label || "st") + (sortKey === k ? (sortDesc ? "▾" : "▴") : " "), cw);
          head += hovered(B, x, x + cw) ? theme.bg("userMessageBg", theme.fg("text", s)) : theme.fg(sortKey === k ? "accent" : "muted", s);
          hits.push({ x0: x, x1: x + cw, y0: B, y1: B + 1, click: () => { if (sortKey === k) sortDesc = !sortDesc; else { sortKey = k; sortDesc = k === "time" || k === "tools" || k === "ctx"; } } });
          x += cw;
        }
        head += theme.fg("muted", (show.bar ? " " + pad("timeline", bw) : "") + (show.now ? "  now / result" : ""));
        const out = [pad(head, lw)];
        const idx = list.findIndex((a) => a.id === selectedId);
        keepVisible(idx, idx, h - 1, list.length);
        const top = listScroll[mode];
        listHits(lw, B + 1, h - 1, (y) => { const a = list[top + y - B - 1]; return a ? { id: a.id } : undefined; });
        for (let k = 0; k < h - 1; k++) {
          const a = list[top + k];
          if (!a) { out.push(""); continue; }
          const s = a.snap(t);
          const nowCol = s.state === "running" ? (s.running ? `${theme.fg("accent", "◌")} ${theme.fg("muted", kindOf(s.running.name))} ${toolSummary(s.running, a.cwd)}` : theme.fg("thinkingText", "thinking…"))
            : s.state === "failed" ? theme.fg("error", a.error || "failed") : s.state === "stalled" ? theme.fg("error", `no activity for ${dur(t - s.lastAct)}`)
            : s.state === "abandoned" ? theme.fg("dim", "superseded") : theme.fg("dim", resultLine(a.result));
          const lead = tagRow(a.id) ?? (pins.includes(a.id) ? theme.fg("accent", "◆ ") : "  ");
          const text = `${lead}${glyph(s.state)} ${theme.fg(colorOf(a.id) as any, pad(mid(a.name, nw), nw))} ${show.phase ? theme.fg("muted", pad(phaseName(a.phase), pw)) + " " : ""}${dur(a.end(t) - (a.firstTs || t)).padStart(6)} ${String(s.tools).padStart(5)}${s.errors ? theme.fg("error", "!") : " "}${show.ctx ? kTok(s.ctx).padStart(5) : ""}${show.bar ? "  " + miniBar(a, t0, t1, bw, t) : ""}${show.now ? "  " + nowCol : ""}`;
          out.push(hl(text, lw, a.id === selectedId && focusPane === "list", a.id === selectedId || hovered(B + 1 + k, 0, lw)));
        }
        return out;
      };
      // Timeline: phase and agent bars over the run (queued time dim, failures red, a now line), with
      // eighth-block bar ends and a time readout under the pointer.
      const renderTimeline = (lw: number, h: number): string[] => {
        if (!run) return [];
        const t = now(), ag = agents();
        const nameW = Math.min(30, Math.max(14, Math.floor(lw * 0.36)));
        const bw = Math.max(8, lw - nameW - 2);
        const q0 = Math.min(...ag.map((a) => a.final?.queuedAt ?? Infinity));
        const { t1 } = run.span(t), t0 = Math.min(run.startTs, q0);
        const col = (x: number) => Math.max(0, Math.min(bw - 1, Math.floor(((x - t0) / (t1 - t0)) * (bw - 1))));
        const axis = Array(bw).fill(" ");
        for (let m = 0; m <= 2; m++) {
          const c = Math.floor((m / 2) * (bw - 1)), lab = `+${dur(((t1 - t0) * m) / 2)}`;
          const start = Math.min(bw - lab.length, Math.max(0, c - (m === 2 ? lab.length - 1 : m === 1 ? Math.floor(lab.length / 2) : 0)));
          for (let k = 0; k < lab.length; k++) axis[start + k] = lab[k];
        }
        const hc = hover.y >= B && hover.y < B + h && hover.x >= nameW + 2 && hover.x < lw ? hover.x - nameW - 2 : -1;
        if (hc >= 0) { const s = `▼ +${dur(((hc / (bw - 1)) * (t1 - t0)))}`; const st = Math.min(bw - s.length, Math.max(0, hc)); for (let k = 0; k < s.length; k++) axis[st + k] = s[k]; }
        const out = [pad(theme.fg("muted", " ".repeat(nameW + 1) + "│" + axis.join("")), lw)];
        const rows: LRow[] = [];
        const nowC = run.live(t) ? col(t) : -1, ended = !run.live(t);
        for (const e of entries()) {
          if (!e.a) {
            const inPh = ag.filter((a) => a.phase === e.ph), closed = collapsed.has(e.ph);
            const bar = Array(bw).fill(" ");
            if (inPh.length) {
              const s0 = col(Math.min(...inPh.map((a) => a.firstTs || t))), s1 = col(Math.max(...inPh.map((a) => a.end(t))));
              for (let c = s0; c <= s1; c++) bar[c] = theme.fg("accent", closed ? "▬" : "═");
              if (closed) for (const a of inPh) bar[col(a.end(t))] = theme.fg(stateColor(a.state(t)) as any, "┃");
            }
            if (nowC >= 0) bar[nowC] = theme.fg("warning", "┆");
            rows.push({ ph: e.ph, text: pad(`${theme.fg("accent", closed ? "▸" : "▾")} ${theme.bold(phaseName(e.ph))} ${theme.fg("muted", inPh.length ? `${inPh.length}` : ended ? "skipped" : "planned")}`, nameW) + " │" + bar.join("") });
            continue;
          }
          const a = e.a, s = a.snap(t);
          const cells: string[] = Array(bw).fill(theme.fg("borderMuted", "·"));
          const q = a.final?.queuedAt, start = a.firstTs || t, end = a.end(t);
          if (q && q < start) for (let c = col(q); c < col(start); c++) cells[c] = theme.fg("dim", "░");
          const fx = (x: number) => Math.max(0, Math.min(bw - 1e-6, ((x - t0) / (t1 - t0)) * (bw - 1)));
          const e0 = fx(start), e1 = fx(end) + 1 / 8;
          for (let c = Math.floor(e0); c <= Math.floor(e1) && c < bw; c++) {
            const cover = Math.min(c + 1, e1) - Math.max(c, e0);
            const eighths = Math.max(1, Math.min(8, Math.round(cover * 8)));
            cells[c] = theme.fg(stateColor(s.state) as any, c === Math.floor(e1) && eighths < 8 ? "▏▎▍▌▋▊▉█"[eighths - 1] : c === Math.floor(e0) && e0 % 1 > 0.5 && c !== Math.floor(e1) ? "▐" : "█");
          }
          // Failed calls tint their cell red rather than punching a hole in the bar.
          for (const it of s.vis) if (it.t === "tool" && it.err && a.toolDone(it, t)) cells[col(it.ts)] = theme.fg("error", "█");
          if (s.state === "running") cells[col(end)] = theme.fg("warning", "▶");
          if (nowC >= 0 && cells[nowC].includes("·")) cells[nowC] = theme.fg("warning", "┆");
          rows.push({ id: a.id, lead: "  ", text: pad(`${glyph(s.state)} ${mid(a.name, nameW - 5)}`, nameW - 2) + " │" + cells.join("") });
        }
        const isSel = (r?: LRow) => !!r && (cursorPhase != null ? r.ph === cursorPhase && !r.id : !!r.id && r.id === selectedId);
        const idx = rows.findIndex((r) => isSel(r));
        keepVisible(idx, idx, h - 1, rows.length);
        const top = listScroll[mode];
        listHits(lw, B + 1, h - 1, (y) => rows[top + y - B - 1]);
        for (let k = 0; k < h - 1; k++) {
          const r = rows[top + k];
          const lead = r?.lead != null ? (r.id ? tagRow(r.id) : undefined) ?? r.lead : "";
          out.push(hl(lead + (r?.text ?? ""), lw, isSel(r) && focusPane === "list", isSel(r) || (!!r && hovered(B + 1 + k, 0, nameW))));
        }
        return out;
      };

      // ---------- detail pane ----------
      // The selection and any pinned agents, stacked; each gets a card and a transcript.
      const renderDetail = (x: number, w: number, h: number): string[] => {
        const list = detailAgents();
        if (!list.length) return transcriptBlock(undefined, x, B, w, h, false);
        const out: string[] = [];
        const each = Math.floor(h / list.length);
        list.forEach((a, i) => {
          const sh = i === list.length - 1 ? h - each * i : each;
          const y = B + out.length;
          cardX = x;
          const head = [...card(a, w, y), theme.fg(a.id === selectedId && focusPane === "detail" ? "border" : "borderMuted", "─".repeat(w))];
          out.push(...head.slice(0, sh));
          out.push(...transcriptBlock(a, x, y + 3, w, sh - 3, focusPane === "detail" && a.id === selectedId));
        });
        return out;
      };

      // ---------- stream tail ----------
      const renderStream = (w: number, y0: number, h: number): string[] => {
        const t = now(), ev: { ts: number; a: Agent; text: string; key?: string }[] = [];
        for (const a of agents()) {
          const s = a.snap(t);
          if (a.firstTs) ev.push({ ts: a.firstTs, a, text: theme.fg("accent", "▶ started") + theme.fg("muted", `  ${phaseName(a.phase)} · ${clip(a.task, w - 60)}`) });
          let structured = false;
          for (const it of s.vis) {
            if (it.t === "tool") { if (it.name === "StructuredOutput") structured = true; ev.push({ ts: it.ts, a, key: it.key, text: `${!a.toolDone(it, t) ? theme.fg("accent", "◌") : it.err ? theme.fg("error", "✗") : theme.fg("success", "✓")} ${theme.fg("muted", kindOf(it.name).padEnd(6))} ${toolSummary(it, a.cwd)}` }); }
            else if (it.t === "text") ev.push({ ts: it.ts, a, key: it.key, text: theme.fg("text", `» ${firstLine(it.text)}`) });
          }
          // When a result tool already printed the outcome, the done marker stays short.
          if (s.state === "done" || s.state === "failed" || s.state === "abandoned")
            ev.push({ ts: a.lastTs, a, text: s.state === "done" ? theme.fg("success", "■ done") + (structured ? "" : theme.fg("dim", "  " + resultLine(a.result))) : s.state === "failed" ? theme.fg("error", `■ failed  ${a.error}`) : theme.fg("dim", "■ superseded") });
        }
        ev.sort((x, y) => x.ts - y.ts);
        const max = Math.max(0, ev.length - h);
        if (tailFollow) tailScroll = max;
        tailScroll = Math.max(0, Math.min(tailScroll, max));
        const lab = Math.min(26, Math.floor(w * 0.2));
        const out: string[] = [];
        for (let k = 0; k < h; k++) {
          const e = ev[tailScroll + k];
          if (!e) { out.push(""); continue; }
          out.push(hl(` ${theme.fg("dim", clock(e.ts))} ${theme.fg(colorOf(e.a.id) as any, pad(mid(e.a.name, lab), lab))} ${theme.fg("borderMuted", "│")} ${e.text}`, w, false, e.a.id === selectedId || hovered(y0 + k)));
        }
        hits.push({ x0: 0, x1: w, y0, y1: y0 + h,
          click: (evt) => { const e = ev[tailScroll + evt.y - y0]; if (!e) return; pick(e.a.id);
            if (e.key) { e.a.cursor = e.key; e.a.follow = false; e.a.overrides.set(e.key, true); const rows = transcriptRows(e.a, 80); e.a.scroll = Math.max(0, rows.findIndex((r) => r.key === e.key) - 3); }
            if (evt.clickCount >= 2) act("zoom"); },
          right: (evt) => { const e = ev[tailScroll + evt.y - y0]; if (e) { pick(e.a.id); act("pin"); } },
          wheel: (d) => { tailScroll = Math.max(0, tailScroll + d * 3); tailFollow = tailScroll >= max; } });
        if (!tailFollow) {
          out[h - 1] = pad(theme.bg("customMessageBg", theme.fg("warning", ` ⏸ scrolled back · ${max - tailScroll} newer · click to follow `)), w);
          hits.unshift({ x0: 0, x1: w, y0: y0 + h - 1, y1: y0 + h, click: () => { tailFollow = true; } });
        }
        return out;
      };

      // ---------- body ----------
      const renderBody = (w: number, h: number): string[] => {
        jumpLetters.length = 0; if (jumping) jumpMap = new Map();
        const tailH = tailOpen && !zoom ? Math.max(5, Math.floor(h * 0.3)) : 0;
        const mainH = h - tailH;
        const out: string[] = [];
        if (zoom) {
          const a = sel();
          cardX = 0;
          if (a) out.push(...card(a, w, B), theme.fg("borderMuted", "─".repeat(w)));
          out.push(...transcriptBlock(a, 0, B + out.length, w, mainH - out.length, true));
        } else {
          const auto_ = mode === 0 ? Math.min(64, Math.max(36, Math.floor(w * 0.36))) : Math.floor(w * (mode === 1 ? 0.58 : 0.55));
          const lw = Math.max(28, Math.min(w - 40, leftW[mode] || auto_));
          lastLeftW = lw;
          const left = mode === 0 ? renderTree(lw, mainH) : mode === 1 ? renderTable(lw, mainH) : renderTimeline(lw, mainH);
          // Draggable splitter (H/L from the keyboard).
          hits.push({ x0: lw, x1: lw + 1, y0: B, y1: B + mainH, press: () => true, drag: (ev) => { leftW[mode] = Math.max(28, Math.min(w - 40, ev.x)); save(`left-width-${MODES[mode]}`, String(leftW[mode])); } });
          // The Timeline card previews whatever is under the pointer; the transcript keeps the selection.
          const detail = renderDetail(lw + 1, w - lw - 1, mainH);
          const sepHot = hovered(hover.y, lw, lw + 1) || captured?.x0 === lw;
          const sep = theme.fg(sepHot ? "accent" : focusPane === "list" ? "border" : "borderMuted", sepHot ? "┃" : "│");
          for (let y = 0; y < mainH; y++) out.push(pad(left[y] ?? "", lw) + sep + pad(detail[y] ?? "", w - lw - 1));
        }
        if (tailH) {
          const label = theme.fg("accent", " stream ") + theme.fg("muted", "· every agent, newest last · t closes ");
          out.push(theme.fg("borderMuted", "──") + label + theme.fg("borderMuted", "─".repeat(Math.max(0, w - 2 - visibleWidth(label)))));
          hits.push({ x0: 0, x1: w, y0: B + mainH, y1: B + mainH + 1, click: () => act("tail") });
          out.push(...renderStream(w, B + mainH + 1, tailH - 1));
        }
        return out;
      };

      // ---------- picker, help ----------
      const pickerMeta = new Map<string, { name: string; description: string }>();
      const renderPicker = (w: number, h: number, out: string[]) => {
        const close = theme.fg("accent", " ✕ close ");
        out.push(pad(theme.bold(" workflow runs ") + theme.fg("muted", "newest activity first · enter or click opens "), w - visibleWidth(close)) + close);
        hits.unshift({ x0: w - visibleWidth(close), x1: w, y0: B, y1: B + 1, click: () => act("closeRuns") });
        const bodyH = h - 1;
        if (pickerIdx < pickerScroll) pickerScroll = pickerIdx;
        if (pickerIdx >= pickerScroll + bodyH) pickerScroll = pickerIdx - bodyH + 1;
        hits.push({ x0: 0, x1: w, y0: B + 1, y1: B + 1 + bodyH, click: (ev) => { const r = runs[pickerScroll + ev.y - B - 1]; if (r) { if (r.dir !== run?.dir) openRun(r.dir); picker = false; } }, wheel: (d) => { pickerScroll = Math.max(0, Math.min(runs.length - 1, pickerScroll + d * 2)); } });
        for (let k = 0; k < bodyH; k++) {
          const r = runs[pickerScroll + k];
          if (!r) { out.push(""); continue; }
          const sd = dirname(dirname(dirname(r.dir))), id = basename(r.dir);
          let meta = pickerMeta.get(id);
          if (!meta) { meta = scriptMeta(sd, id); pickerMeta.set(id, meta); }
          const fresh = Date.now() - r.mtime < STALL_MS;
          const text = ` ${fresh ? theme.fg("success", "●") : theme.fg("muted", "○")} ${pad(theme.bold(meta.name || id), 34)} ${theme.fg("muted", pad(dur(Date.now() - r.mtime) + " ago", 10))} ${theme.fg("dim", pad(projectOf(sd), 36))} ${theme.fg("dim", clip(meta.description, Math.max(0, w - 90)))}`;
          out.push(hl(text, w, pickerScroll + k === pickerIdx, hovered(B + 1 + k)));
        }
      };
      const HELP: [string, string][] = [
        ["1 2 3  < >", "list mode: Tree, Table, Timeline (or click a tab)"],
        ["t", "toggle the stream: every agent's events interleaved, newest last"],
        ["j k  ↑ ↓", "move through phases and agents, or rows when the transcript has focus"],
        ["[ ]", "previous / next agent from anywhere"],
        ["'", "jump: letters appear beside agents; press one to select it"],
        ["tab  l  →", "focus the transcript; h or ← returns to the list"],
        ["enter", "list: zoom the agent, or fold the phase under the cursor · transcript: toggle the row"],
        ["space  h", "fold the phase under the cursor (from an agent: its phase) · transcript: toggle / collapse the row"],
        ["z  esc", "zoom / back (the zoom breadcrumb is clickable)"],
        ["/", "list: filter agents by name or phase · transcript: search its rows, outputs included"],
        ["n  N", "next / previous search match (opens folded rows that match)"],
        ["e  E", "next / previous failure (agents in the list, tool calls in a transcript)"],
        ["f  G  end", "follow the tail"],
        ["g  home", "jump to the top"],
        ["d", "density: compact → normal → full"],
        ["+ (=)  -", "expand / collapse every row of the agent"],
        ["p", "pin the agent: pinned agents stack under the selection (two at most)"],
        ["s  S", "Table: cycle the sort column / reverse it"],
        ["H  L", "narrow / widen the list"],
        ["{  }", "replay slower / faster"],
        ["a", "auto: follow whichever agent is active"],
        ["P", "pause or resume the live feed"],
        ["r", "pick another run"],
        ["q", "quit"],
        ["mouse", "click selects or toggles · double-click zooms · right-click pins · the wheel scrolls the pane under the pointer · drag the divider · click or drag a transcript's scrollbar · click column headers to sort · click a phase in the header to jump to it · the header's ◂ 60x ▸ chips change replay speed and ● live pauses · every hint in the bottom bar is a button"],
      ];
      const helpLines = (bw: number) => HELP.flatMap(([k, d]) => wrapTextWithAnsi(d, bw - 25).map((line, i) => `  ${theme.fg("accent", pad(i ? "" : k, 18))} ${theme.fg("text", line)}`));

      const hintsFor = (): [string, string, string][] => {
        const common: [string, string, string][] = [["t", tailOpen ? "hide stream" : "stream", "tail"], ["d", DENSITIES[density], "density"], ["P", pausedAt != null ? "resume" : "pause", "pause"], ...(REPLAY ? [["{}", `${speed}x`, "faster"] as [string, string, string]] : []), ["?", "help", "help"], ["q", "quit", "quit"]];
        if (help) return [["j k", "scroll", "help"], ["esc", "close", "help"]];
        if (picker) return [["esc", "close", "closeRuns"], ["q", "quit", "quit"]];
        if (jumping) return [["a–z", "pick an agent", "jump"], ["esc", "cancel", "back"]];
        if (zoom || focusPane === "detail") {
          const s: [string, string, string][] = search ? [["n", "next match", "nextMatch"], ["N", "prev", "prevMatch"]] : [["/", "search", "search"]];
          return [["esc", "back", "back"], ["⏎", "toggle", "fold"], ...s, ["e", "next failure", "nextErr"], ["f", "follow", "follow"], ["g", "top", "top"], ["+", "expand all", "expandAll"], ["-", "collapse all", "collapseAll"], ["p", "pin", "pin"], ...common];
        }
        const base: [string, string, string][] = [["⏎", cursorPhase != null ? "fold" : "zoom", cursorPhase != null ? "fold" : "zoom"], ["'", "jump", "jump"], ["e", "next failure", "nextErr"], ["p", "pin", "pin"], ["/", "filter", "filter"]];
        if (mode !== 1) base.splice(1, 0, ["space", "fold", "fold"]);
        if (mode === 1) base.push(["s", `sort: ${sortKey}`, "sort"], ["S", "reverse", "reverse"]);
        base.push(["H L", "resize", "wider"]);
        if (!auto) base.push(["a", "auto-follow", "auto"]);
        return [...base, ...common];
      };

      const draw = (width: number): string[] => {
        hits = [];
        frameT = pausedAt ?? rawNow();
        H = Math.max(10, tui.terminal.rows); W = width;
        const out: string[] = [header(width), tabsRow(width)];
        const h = H - 3;
        if (help) {
          const bw = Math.min(width - 2, 104), x0 = Math.max(0, Math.floor((width - bw) / 2));
          const lines = helpLines(bw), room = h - 2;
          helpScroll = Math.max(0, Math.min(helpScroll, Math.max(0, lines.length - room)));
          const more = lines.length > room ? theme.fg("muted", ` ${helpScroll + 1}-${Math.min(lines.length, helpScroll + room)} of ${lines.length} · j/k or wheel `) : "";
          out.push(" ".repeat(x0) + theme.fg("border", "╭" + "─".repeat(bw - 2) + "╮"));
          for (const l of lines.slice(helpScroll, helpScroll + room)) out.push(" ".repeat(x0) + theme.fg("border", "│") + pad(l, bw - 2) + theme.fg("border", "│"));
          out.push(" ".repeat(x0) + theme.fg("border", "╰") + more + theme.fg("border", "─".repeat(Math.max(0, bw - 2 - visibleWidth(more))) + "╯"));
          hits.unshift({ x0: 0, x1: width, y0: B, y1: H - 1, click: () => { help = false; }, wheel: (d) => { helpScroll = Math.max(0, helpScroll + d * 2); } });
        } else if (picker) renderPicker(width, h, out);
        else {
          autoSelect();
          out.push(...renderBody(width, h).slice(0, h));
          reveal = false;
        }
        while (out.length < H - 1) out.push("");
        out.length = H - 1;
        out.push(hintBar(H - 1, width, hintsFor()));
        frameT = undefined;
        return out.map((l) => pad(l, width));
      };

      return {
        render(width: number) {
          try { return draw(width); } catch (e: any) {
            frameT = undefined;
            return [pad(theme.fg("error", ` render error: ${e?.message}`), width), ...String(e?.stack ?? "").split("\n").slice(1, 8).map((l) => pad(theme.fg("dim", l), width))];
          }
        },
        handleInput(data: string) {
          const done = () => tui.requestRender();
          // Printable keys match exactly: pi's matchesKey treats "p" as matching "P". Named keys
          // (enter, tab, ctrl+d) go through matchesKey.
          const key = (...ks: string[]) => ks.some((k) => (k.length === 1 ? data === k : matchesKey(data, k as any)));
          if (help) {
            if (key("j", "down")) helpScroll++;
            else if (key("k", "up")) helpScroll = Math.max(0, helpScroll - 1);
            else if (key("pageDown", "ctrl+d", " ")) helpScroll += 10;
            else if (key("pageUp", "ctrl+u")) helpScroll = Math.max(0, helpScroll - 10);
            else help = false;
            return done();
          }
          if (jumping) {
            jumping = false;
            const id = [...jumpMap.entries()].find(([, k]) => k === data)?.[0];
            if (id) pick(id);
            return done();
          }
          if (filtering || searching) {
            const set = (v: string) => { if (filtering) filter = v; else search = v; };
            const cur = filtering ? filter : search;
            if (key("enter")) { if (searching && search) { searching = false; act("nextMatch"); } filtering = searching = false; }
            else if (key("escape")) { set(""); filtering = searching = false; }
            else if (key("backspace")) set(cur.slice(0, -1));
            else if (data.length === 1 && data >= " ") set(cur + data);
            reveal = true;
            return done();
          }
          if (picker) {
            if (key("escape", "q", "r")) picker = false;
            else if (key("j", "down")) pickerIdx = Math.min(runs.length - 1, pickerIdx + 1);
            else if (key("k", "up")) pickerIdx = Math.max(0, pickerIdx - 1);
            else if (key("enter") && runs[pickerIdx]) { if (runs[pickerIdx].dir !== run?.dir) openRun(runs[pickerIdx].dir); picker = false; }
            else if (key("1", "2", "3")) act(`mode${Number(data) - 1}`);
            return done();
          }
          const a = sel();
          const inDetail = zoom || focusPane === "detail";
          if (key("q")) return finish();
          if (key("?")) act("help");
          else if (key("1", "2", "3")) act(`mode${Number(data) - 1}`);
          else if (key("<", ",")) act(`mode${(mode + 2) % 3}`);
          else if (key(">", ".")) act(`mode${(mode + 1) % 3}`);
          else if (key("t")) act("tail");
          else if (key("r")) act("runs");
          else if (key("P")) act("pause");
          else if (key("{")) act("slower");
          else if (key("}")) act("faster");
          else if (key("/")) act(inDetail ? "search" : "filter");
          else if (key("n") && inDetail) act("nextMatch");
          else if (key("N") && inDetail) act("prevMatch");
          else if (key("'")) act("jump");
          else if (key("d")) act("density");
          else if (key("a")) act("auto");
          else if (key("p")) act("pin");
          else if (key("e")) act("nextErr");
          else if (key("E")) act("prevErr");
          else if (key("S")) act("reverse");
          else if (key("s") && mode === 1) act("sort");
          else if (key("H") && !zoom) act("narrower");
          else if (key("L") && !zoom) act("wider");
          else if (key("[")) step(-1);
          else if (key("]")) step(1);
          else if (key("+", "=")) act("expandAll");
          else if (key("-")) act("collapseAll");
          else if (key("escape")) act("back");
          else if (key("z")) act("zoom");
          else if (key("tab", "shift+tab") && !zoom) { focusPane = focusPane === "list" ? "detail" : "list"; if (focusPane === "detail") auto = false; }
          else if (inDetail && a) {
            if (key("j", "down")) moveCursor(a, 1);
            else if (key("k", "up")) moveCursor(a, -1);
            else if (key("enter", " ")) { if (a.cursor) toggleRow(a, a.cursor); else moveCursor(a, 1); }
            else if (key("l", "right")) { if (a.cursor) a.overrides.set(a.cursor, true); else moveCursor(a, 1); }
            else if (key("h", "left")) {
              // magit-style: collapse the row, else climb out to the list
              const r = a.cursor ? rowsFor(a).find((x) => x.key === a.cursor) : undefined;
              if (r?.open) a.overrides.set(a.cursor!, false);
              else if (!zoom) focusPane = "list"; else zoom = false;
            }
            else if (key("G", "end", "f")) act("follow");
            else if (key("g", "home")) act("top");
            else if (key("pageDown", "ctrl+d")) { a.follow = false; a.scroll += 10; auto = false; }
            else if (key("pageUp", "ctrl+u")) { a.follow = false; a.scroll = Math.max(0, a.scroll - 10); auto = false; }
          } else {
            if (key("j", "down")) step(1);
            else if (key("k", "up")) step(-1);
            else if (key("g", "home")) { cursorPhase = undefined; step(-1e6); }
            else if (key("G", "end")) step(1e6);
            else if (key("enter")) { if (cursorPhase != null) act("fold"); else act("zoom"); }
            else if (key("l", "right")) { if (cursorPhase != null) collapsed.delete(cursorPhase); else { focusPane = "detail"; auto = false; } }
            else if (key("h", "left", " ")) act("fold");
            else if (key("f")) act("follow");
          }
          return done();
        },
        handleMouse(ev: any) {
          const at = (e: any) => hits.find((hh) => e.x >= hh.x0 && e.x < hh.x1 && e.y >= hh.y0 && e.y < hh.y1);
          if (ev.type === "move") { const moved = hover.x !== ev.x || hover.y !== ev.y; hover = { x: ev.x, y: ev.y }; return { handled: true, render: moved }; }
          if (ev.type === "drag" && captured) { captured.drag?.(ev); return { handled: true, render: true }; }
          if (ev.type === "release") { const was = !!captured; captured = undefined; return { handled: true, render: was }; }
          const hit = at(ev);
          if (ev.type === "wheel") { hit?.wheel?.(ev.wheelDelta ?? 0); return { handled: true }; }
          if (ev.type === "press" && ev.button === "left" && hit?.press?.(ev)) { captured = hit; return { handled: true, capture: true }; }
          if (ev.type === "press" && ev.button === "right") { hit?.right?.(ev); return { handled: true }; }
          if (ev.type !== "click" || ev.button !== "left") return { handled: true, render: false };
          if (jumping) jumping = false;
          hit?.click?.(ev);
          return { handled: true };
        },
        invalidate() {},
        dispose() { clearInterval(tick); clearInterval(rescan); },
      } as any;
    }, { overlay: true, overlayOptions: { width: "100%", maxHeight: "100%", anchor: "top-left" } }).then(() => ctx.shutdown());
  });
}
