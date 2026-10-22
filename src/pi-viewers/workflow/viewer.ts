// pi extension: watches a Claude Code Workflow run. Its agents grouped by phase in a list (a tree,
// a sortable table or a timeline of bars) beside the selected agent's transcript, an optional
// stream of every agent's events, a run picker, and replay; the shared kit (lib/kit.ts) draws the
// frame, the keys and the mouse. It only reads files (model.ts). `pi-viewer workflow` launches it
// with PI_VIEWER=workflow.
//   CCWF_RUN=<runId or name substring>  pick a run (default: the most recently active)
//   CCWF_REPLAY=<speed>                 replay a finished run as if live, at <speed>x
//   CCWF_MODE=tree|table|timeline       starting list mode (default: the last one used)
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { basename, dirname } from "node:path";
import {
  Agent, type AgentState, discoverRuns, findRun, firstLine, GROUPABLE, type Item, kindOf, projectOf, resultLine, Run, scriptMeta, setReplay, STALL_MS,
  toolDetail, toolHint, toolSummary, unframe,
} from "./model.ts";
import {
  clip, clock, dur, kTok, matches, mid, pad, RANK, runViewer, stateColor, visibleWidth,
  type Hint, type ListHeader, type ListOut, type ListRow, type Rect, type Row, type Spec, type State,
} from "../lib/kit.ts";

const MODES = ["tree", "table", "timeline"] as const;
const SORTS = ["status", "label", "phase", "time", "tools", "ctx"] as const;
type SortKey = (typeof SORTS)[number];
type Entry = { ph: string; a?: Agent };

// Clock: live, or a finished run replayed from its first event at `speed`x. Pausing freezes it (and
// stops reading files).
let speed = Number(process.env.CCWF_REPLAY ?? 0);
const REPLAY = speed > 0;
setReplay(REPLAY);
let replayBase = 0, replayWall = 0;
let pausedAt: number | undefined;
const rawNow = () => (REPLAY ? replayBase + (Date.now() - replayWall) * speed : Date.now());
const setSpeed = (s: number) => { if (pausedAt == null) { replayBase = rawNow(); replayWall = Date.now(); } speed = Math.max(1, Math.min(512, s)); };
const togglePause = () => {
  if (pausedAt == null) pausedAt = rawNow();
  else { if (REPLAY) { replayBase = pausedAt; replayWall = Date.now(); } pausedAt = undefined; }
};

export default function (pi: ExtensionAPI) {
  runViewer(pi, "workflow", (shell) => {
    const { theme } = shell;
    const now = () => shell.t;

    // ---------- state ----------
    let mode = Math.max(0, MODES.indexOf((process.env.CCWF_MODE ?? shell.prefs.get("mode", "tree")) as any));
    let tailOpen = shell.prefs.get("tail", "off") === "on";
    let sortKey = (SORTS as readonly string[]).includes(shell.prefs.get("sort", "status")) ? (shell.prefs.get("sort", "status") as SortKey) : "status";
    let sortDesc = shell.prefs.get("sort-desc", "0") === "1";
    let runs = discoverRuns();
    let run: Run | undefined;
    let picker = false, pickerIdx = 0, pickerScroll = 0;
    const collapsed = new Set<string>();
    let tailScroll = 0, tailFollow = true;

    const openRun = (dir: string) => {
      run = new Run(dir);
      run.refresh();
      shell.selectedId = undefined; shell.cursorGroup = undefined; shell.auto = true; shell.reveal = true; shell.zoom = false; shell.pins.length = 0; shell.listScroll = 0;
      tailScroll = 0; tailFollow = true;
      if (REPLAY) { replayBase = run.startTs - 1000; replayWall = Date.now(); pausedAt = undefined; }
    };
    const initial = findRun(process.env.CCWF_RUN);
    if (initial) openRun(initial.dir);
    const rescan = setInterval(() => { runs = discoverRuns(); }, 10_000);
    const setMode = (i: number) => { mode = i; shell.zoom = false; picker = false; shell.focus = "list"; shell.cursorGroup = undefined; shell.reveal = true; shell.listScroll = 0; shell.prefs.set("mode", MODES[mode]); };
    const setSort = (k: SortKey, desc: boolean) => { sortKey = k; sortDesc = desc; shell.prefs.set("sort", k); shell.prefs.set("sort-desc", desc ? "1" : "0"); };

    // ---------- palette ----------
    const PALETTE = ["accent", "success", "warning", "syntaxVariable", "syntaxString", "syntaxNumber", "syntaxType", "syntaxFunction", "mdLink", "thinkingHigh"];
    const colorOf = (id: string) => PALETTE[[...id].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7) % PALETTE.length];
    const phaseName = (ph: string) => ph || "other";
    const glyph = (s: AgentState) => shell.glyph(s as State);

    // ---------- agent lists ----------
    const allAgents = () => (run ? run.visibleAgents(now()) : []);
    const agents = () => allAgents().filter((a) => !shell.filter || matches(shell.filter, `${a.name} ${a.phase}`));
    // Within a phase: problems first, then live work, then finished (Turborepo's order).
    const byStatus = (t: number) => (a: Agent, b: Agent) => (RANK[a.state(t) as State] ?? 3) - (RANK[b.state(t) as State] ?? 3) || a.firstTs - b.firstTs;
    const phaseList = () => (run ? [...run.phases, ...(agents().some((a) => !a.phase) ? [""] : [])] : []);
    const inPhase = (ph: string) => { const t = now(); return agents().filter((a) => a.phase === ph).sort(mode === 2 ? (x, y) => (x.firstTs || t) - (y.firstTs || t) : byStatus(t)); };
    // Tree/Timeline rows: every phase, then its agents when the phase is open.
    const entries = (): Entry[] => phaseList().flatMap((ph) => [{ ph }, ...(collapsed.has(ph) ? [] : inPhase(ph).map((a) => ({ ph, a })))]);
    const tableOrder = () => {
      const t = now(), ag = [...agents()];
      const val = (a: Agent): number | string => {
        const s = a.snap(t);
        return sortKey === "label" ? a.name : sortKey === "phase" ? `${a.phase}` : sortKey === "time" ? a.end(t) - (a.firstTs || t) : sortKey === "tools" ? s.tools : sortKey === "ctx" ? s.ctx : RANK[s.state as State] ?? 3;
      };
      ag.sort((a, b) => { const x = val(a), y = val(b); const c = typeof x === "string" ? x.localeCompare(y as string) : (x as number) - (y as number); return (sortDesc ? -c : c) || a.firstTs - b.firstTs; });
      return ag;
    };
    const byId = (id: string) => run?.agents.get(id);
    const sel = () => byId(shell.selectedId ?? "");

    // ---------- transcript ----------
    // Dense rows: one line per tool call, consecutive reads/searches grouped, the running tool and
    // live thinking expanded until they finish. Density changes what is open by default. Each row
    // records whether it is open (so a toggle flips what is shown) and its searchable text.
    const transcriptRows = (a: Agent, width: number): Row[] => {
      const t = now(), snap = a.snap(t), rows: Row[] = [], live = snap.state === "running", dens = shell.dens, v = a.view;
      const vis = snap.vis;
      const open = (key: string, auto: boolean) => v.overrides.get(key) ?? (dens === "full" ? true : auto);
      const indent = (lines: string[], color = "toolOutput", max = 12) => shell.indent(rows, lines, width, color, max);
      const toolRow = (it: Item, parent?: string) => {
        const doneNow = a.toolDone(it, t), key = it.key;
        const g = !doneNow ? (live ? theme.fg("accent", "◌") : theme.fg("dim", "◌")) : it.err ? theme.fg("error", "✗") : theme.fg("success", "✓");
        const took = doneNow && it.endTs! - it.ts >= 2000 ? theme.fg("dim", ` ${dur(it.endTs! - it.ts)}`) : "";
        const hint = doneNow ? toolHint(it) : theme.fg("warning", dur(t - it.ts));
        const o = open(key, !doneNow && live);
        const summary = clip(toolSummary(it, a.cwd), Math.max(10, Math.floor(width * 0.62) - 10));
        rows.push({ key, parent, open: o, problem: it.err, live: !doneNow, hay: `${toolSummary(it, a.cwd)}\n${JSON.stringify(it.input ?? {})}\n${it.result ?? ""}`,
          text: `${parent ? theme.fg("borderMuted", "  ├ ") : ""}${g} ${theme.fg("muted", kindOf(it.name).padEnd(6))} ${summary}  ${theme.fg(it.err ? "error" : "dim", clip(String(hint), Math.max(8, width - visibleWidth(summary) - 16)))}${took}` });
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
            rows.push({ key, head: true, open: o, hay: u.body, text: `${theme.fg("accent", o ? "▾" : "▸")} ${theme.bold(lab.padEnd(7))} ${o ? "" : theme.fg(lab === "task" ? "text" : "muted", clip(firstLine(u.body), width - 12))}` });
            if (o) for (const l of shell.md(it, u.body, width - 2)) rows.push({ text: "  " + l });
          }
          i++;
        } else if (it.t === "text") {
          const lastText = !vis.slice(i + 1).some((x) => x.t === "text");
          if (dens === "compact" && !(lastText && !live)) {
            const o = open(key, false);
            rows.push({ key, open: o, hay: it.text, text: `${theme.fg("muted", o ? "▾" : "▸")} ${theme.fg("text", "»")} ${theme.fg("text", clip(firstLine(it.text), width - 6))}` });
            if (o) for (const l of shell.md(it, it.text ?? "", width - 4)) rows.push({ text: "    " + l });
          } else {
            rows.push({ text: "" });
            for (const l of shell.md(it, it.text ?? "", width - 2)) rows.push({ text: "  " + l });
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
            if (o) group.forEach((g) => toolRow(g, gkey));
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

    const card = (a: Agent, w: number, x: number, y: number): string[] => {
      const t = now(), s = a.snap(t);
      const left = ` ${glyph(s.state)} ${theme.bold(mid(a.name, Math.max(12, w - 40)))} ${shell.pill(s.state)}${shell.auto && a.id === shell.selectedId ? theme.fg("accent", " ⟳") : ""}`;
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
      const isPinned = shell.pins.includes(a.id);
      const pinB = theme.fg(isPinned ? "accent" : "dim", isPinned ? "◆ pinned" : "◇ pin");
      let keep = fields.slice();
      const rightOf = (f: [number, string][]) => [...f.map((x) => x[1]), pinB].join(theme.fg("borderMuted", " · ")) + " ";
      while (keep.length > 1 && visibleWidth(left) + visibleWidth(rightOf(keep)) + 2 > w) keep = keep.filter((x) => x[0] !== Math.max(...keep.map((k) => k[0])));
      const right = rightOf(keep);
      const pinX = w - visibleWidth(pinB) - 1;
      const line1 = clip(left, Math.max(10, w - visibleWidth(right) - 1));
      shell.hits.add({ x0: x + pinX, x1: x + w, y0: y, y1: y + 1, click: () => { shell.pick(a.id); shell.act("pin"); } });
      shell.hits.add({ x0: x, x1: x + pinX, y0: y, y1: y + 2, click: () => shell.pick(a.id) });
      const status = s.state === "running"
        ? (s.running ? `${theme.fg("accent", "◌")} ${s.longTool ? theme.fg("warning", "in ") : ""}${theme.fg("muted", kindOf(s.running.name))} ${toolSummary(s.running, a.cwd)} ${theme.fg("warning", (s.longTool ? "for " : "") + dur(t - s.running.ts))}` : theme.fg("thinkingText", "thinking…"))
        : s.state === "done" || s.state === "cached" ? theme.fg("success", "✓ ") + theme.fg("text", resultLine(a.result) || s.state)
        : s.state === "failed" ? theme.fg("error", `✗ ${a.error || "failed"}`)
        : s.state === "stalled" ? theme.fg("error", `◐ no activity for ${dur(t - s.lastAct)}`)
        : s.state === "abandoned" ? theme.fg("dim", "⊘ superseded: the run finished without this agent's result") : theme.fg("muted", a.task);
      return [pad(line1 + " ".repeat(Math.max(1, w - visibleWidth(line1) - visibleWidth(right))) + right, w), pad(`   ${clip(status, w - 4)}`, w)];
    };

    // ---------- chrome above the panes ----------
    // Header: run identity and counts, the phase strip (scaled to the room left), then the clock
    // controls. Controls register their hits first, and phase hits only where the phase is drawn.
    const header = (w: number) => {
      if (!run) return pad(theme.fg("muted", " no workflow runs under ~/.claude/projects"), w);
      const t = now(), st = run.status(t), ag = run.visibleAgents(t);
      const n = (s: AgentState) => ag.filter((a) => a.state(t) === s).length;
      const { t0, t1 } = run.span(t);
      const tot = run.final && (!REPLAY || t >= run.lastTs) ? run.final.totalTokens : undefined;
      const chips: [string, () => void][] = pausedAt != null
        ? [[theme.bg("toolErrorBg", theme.fg("warning", theme.bold(" ❚❚ paused "))), togglePause]]
        : REPLAY ? [] : [[run.live(t) ? theme.fg("success", " ● live ") : theme.fg("muted", " ○ finished "), togglePause]];
      if (REPLAY) chips.push([theme.fg("accent", " ◂ "), () => setSpeed(speed / 2)], [theme.fg("accent", `${speed}x`) + (pausedAt == null ? theme.fg("dim", " ⏵") : ""), togglePause], [theme.fg("accent", " ▸ "), () => setSpeed(speed * 2)], [theme.fg("dim", clock(t, true) + " "), togglePause]);
      const rw = chips.reduce((s, [c]) => s + visibleWidth(c), 0);
      let cx = w - rw;
      for (const [c, f] of chips) { const cw = visibleWidth(c); shell.hits.row(cx, cx + cw, 0, { click: f }); cx += cw; }
      let x = 0;
      const parts: string[] = [];
      const push = (s: string) => { parts.push(s); x += visibleWidth(s); };
      push(` ${theme.fg("accent", "◆")} ${theme.bold(run.name)} `);
      push(shell.pill(st));
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
          body = sorted.slice(0, cap).map((a) => theme.fg(stateColor(a.state(t)), a.state(t) === "running" ? "▰" : "■")).join("") + (inPh.length > cap ? theme.fg("muted", `+${inPh.length - cap}`) : "") || theme.fg("dim", "·");
        } else body = inPh.length ? theme.fg(done === inPh.length ? "success" : "muted", `${done}/${inPh.length}`) : theme.fg("dim", "·");
        const seg = `${theme.fg(shell.pointer.over(0, x, x + visibleWidth(names[k]) + 1) ? "accent" : "text", names[k])} ${body}  `;
        const sw = visibleWidth(seg);
        if (x + sw <= w - rw - 1) shell.hits.row(x, x + sw, 0, { click: () => { collapsed.delete(ph); picker = false; shell.zoom = false; shell.cursorGroup = ph; shell.auto = false; shell.reveal = true; if (mode === 1) setMode(0); } });
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
        out += active ? theme.bg("selectedBg", theme.bold(label)) : shell.pointer.over(1, x, x + lw) ? theme.bg("userMessageBg", label) : label;
        shell.hits.row(x, x + lw, 1, { click: onClick });
        x += lw;
      };
      const sep = (s = " ") => { out += s; x += visibleWidth(s); };
      sep();
      MODES.forEach((m, i) => button(` ${theme.fg("accent", String(i + 1))} ${narrow ? m.slice(0, 4) : m[0].toUpperCase() + m.slice(1)} `, () => setMode(i), i === mode && !picker));
      sep(theme.fg("borderMuted", " │"));
      button(` ${theme.fg("accent", "t")} ${tailOpen ? "stream ✓" : "stream"} `, toggleTail, tailOpen);
      const runsB = picker ? theme.fg("accent", " ⇄ runs ✕ ") : theme.fg("muted", ` ⇄ ${runs.length} runs `);
      if (narrow) button(runsB, togglePicker, picker);
      else { sep(" ".repeat(Math.max(1, w - x - visibleWidth(runsB)))); button(runsB, togglePicker, picker); }
      return pad(out, w);
    };
    const toggleTail = () => { tailOpen = !tailOpen; tailFollow = true; shell.prefs.set("tail", tailOpen ? "on" : "off"); };
    const togglePicker = () => { if (picker) { picker = false; return; } runs = discoverRuns(); picker = true; pickerIdx = Math.max(0, runs.findIndex((r) => r.dir === run?.dir)); };

    // ---------- list modes ----------
    const miniBar = (a: Agent, t0: number, t1: number, w: number, t: number) => {
      const s = a.state(t), col = (x: number) => Math.max(0, Math.min(w - 1, Math.floor(((x - t0) / (t1 - t0)) * w)));
      const c0 = col(a.final?.queuedAt && a.final.queuedAt < a.firstTs ? a.final.queuedAt : a.firstTs || t), c1 = col(a.firstTs || t), c2 = col(a.end(t));
      let out = "";
      for (let c = 0; c < w; c++) out += c >= c1 && c <= c2 ? theme.fg(stateColor(s), "━") : c >= c0 && c < c1 ? theme.fg("dim", "╌") : " ";
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
    const treeRows = (w: number): ListRow[] => {
      if (!run) return [];
      const t = now(), rows: ListRow[] = [], { t0, t1 } = run.span(t), ended = !run.live(t);
      const bw = w >= 52 ? Math.min(16, Math.floor(w * 0.22)) : 0;
      const es = entries();
      es.forEach((e, k) => {
        if (!e.a) {
          const { inPh, text } = phaseCounts(e.ph, t, ended);
          const span = inPh.length ? theme.fg("muted", dur(Math.max(...inPh.map((a) => a.end(t))) - Math.min(...inPh.map((a) => a.firstTs || t)))) : "";
          const head = `${theme.fg("accent", collapsed.has(e.ph) ? "▸" : "▾")} ${theme.bold(phaseName(e.ph))} ${text}`;
          rows.push({ group: e.ph, text: head + " ".repeat(Math.max(1, w - visibleWidth(head) - visibleWidth(span) - 1)) + span });
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
      if (!es.some((e) => e.a)) rows.push({ text: theme.fg("muted", shell.filter ? `  nothing matches /${shell.filter}` : "  waiting for agents…") });
      return rows;
    };
    // Table: sortable columns (click a header or press s/S); columns drop as the pane narrows.
    const tableList = (lw: number): ListOut => {
      const t = now(), list = tableOrder(), { t0, t1 } = run ? run.span(t) : { t0: 0, t1: 1 };
      const show = { ctx: lw >= 64, phase: lw >= 78, bar: lw >= 96, now: lw >= 70 };
      const nw = Math.min(28, Math.max(14, Math.floor(lw * 0.26))), pw = 12, bw = 14;
      const cols: [SortKey, string, number][] = [["status", "", 4], ["label", "agent", nw + 1], ...(show.phase ? [["phase", "phase", pw + 1] as [SortKey, string, number]] : []), ["time", "  time", 7], ["tools", "tools", 6], ...(show.ctx ? [["ctx", "  ctx", 6] as [SortKey, string, number]] : [])];
      let x = 1, head = " ";
      const hits: ListHeader["hits"] = [];
      for (const [k, label, cw] of cols) {
        const s = pad((label || "st") + (sortKey === k ? (sortDesc ? "▾" : "▴") : " "), cw);
        head += theme.fg(sortKey === k ? "accent" : "muted", s);
        hits.push({ x0: x, x1: x + cw, run: () => { if (sortKey === k) setSort(k, !sortDesc); else setSort(k, k === "time" || k === "tools" || k === "ctx"); } });
        x += cw;
      }
      head += theme.fg("muted", (show.bar ? " " + pad("timeline", bw) : "") + (show.now ? "  now / result" : ""));
      const rows: ListRow[] = list.map((a) => {
        const s = a.snap(t);
        const nowCol = s.state === "running" ? (s.running ? `${theme.fg("accent", "◌")} ${theme.fg("muted", kindOf(s.running.name))} ${toolSummary(s.running, a.cwd)}` : theme.fg("thinkingText", "thinking…"))
          : s.state === "failed" ? theme.fg("error", a.error || "failed") : s.state === "stalled" ? theme.fg("error", `no activity for ${dur(t - s.lastAct)}`)
          : s.state === "abandoned" ? theme.fg("dim", "superseded") : theme.fg("dim", resultLine(a.result));
        return { id: a.id, problem: s.state === "failed", lead: shell.pins.includes(a.id) ? theme.fg("accent", "◆ ") : "  ",
          text: `${glyph(s.state)} ${theme.fg(colorOf(a.id), pad(mid(a.name, nw), nw))} ${show.phase ? theme.fg("muted", pad(phaseName(a.phase), pw)) + " " : ""}${dur(a.end(t) - (a.firstTs || t)).padStart(6)} ${String(s.tools).padStart(5)}${s.errors ? theme.fg("error", "!") : " "}${show.ctx ? kTok(s.ctx)!.padStart(5) : ""}${show.bar ? "  " + miniBar(a, t0, t1, bw, t) : ""}${show.now ? "  " + nowCol : ""}` };
      });
      if (!rows.length) rows.push({ text: theme.fg("muted", shell.filter ? `  nothing matches /${shell.filter}` : "  waiting for agents…") });
      return { header: [{ text: head, hits }], rows };
    };
    // Timeline: phase and agent bars over the run (queued time dim, failures red, a now line), with
    // eighth-block bar ends and a time readout under the pointer.
    const timelineList = (lw: number): ListOut => {
      if (!run) return { rows: [] };
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
      const lr = shell.frame?.list;
      const hc = lr && shell.pointer.in(lr) && shell.pointer.x - lr.x >= nameW + 2 ? shell.pointer.x - lr.x - nameW - 2 : -1;
      if (hc >= 0) { const s = `▼ +${dur(((hc / (bw - 1)) * (t1 - t0)))}`; const st = Math.min(bw - s.length, Math.max(0, hc)); for (let k = 0; k < s.length; k++) axis[st + k] = s[k]; }
      const rows: ListRow[] = [];
      const nowC = run.live(t) ? col(t) : -1, ended = !run.live(t);
      for (const e of entries()) {
        if (!e.a) {
          const inPh = ag.filter((a) => a.phase === e.ph), closed = collapsed.has(e.ph);
          const bar = Array(bw).fill(" ");
          if (inPh.length) {
            const s0 = col(Math.min(...inPh.map((a) => a.firstTs || t))), s1 = col(Math.max(...inPh.map((a) => a.end(t))));
            for (let c = s0; c <= s1; c++) bar[c] = theme.fg("accent", closed ? "▬" : "═");
            if (closed) for (const a of inPh) bar[col(a.end(t))] = theme.fg(stateColor(a.state(t)), "┃");
          }
          if (nowC >= 0) bar[nowC] = theme.fg("warning", "┆");
          rows.push({ group: e.ph, text: pad(`${theme.fg("accent", closed ? "▸" : "▾")} ${theme.bold(phaseName(e.ph))} ${theme.fg("muted", inPh.length ? `${inPh.length}` : ended ? "skipped" : "planned")}`, nameW) + " │" + bar.join("") });
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
          cells[c] = theme.fg(stateColor(s.state), c === Math.floor(e1) && eighths < 8 ? "▏▎▍▌▋▊▉█"[eighths - 1] : c === Math.floor(e0) && e0 % 1 > 0.5 && c !== Math.floor(e1) ? "▐" : "█");
        }
        // Failed calls tint their cell red rather than punching a hole in the bar.
        for (const it of s.vis) if (it.t === "tool" && it.err && a.toolDone(it, t)) cells[col(it.ts)] = theme.fg("error", "█");
        if (s.state === "running") cells[col(end)] = theme.fg("warning", "▶");
        if (nowC >= 0 && cells[nowC].includes("·")) cells[nowC] = theme.fg("warning", "┆");
        rows.push({ id: a.id, lead: "  ", problem: s.state === "failed", text: pad(`${glyph(s.state)} ${mid(a.name, nameW - 5)}`, nameW - 2) + " │" + cells.join("") });
      }
      return { header: [pad(theme.fg("muted", " ".repeat(nameW + 1) + "│" + axis.join("")), lw)], rows };
    };

    // ---------- stream tail ----------
    const stream = (r: Rect): string[] => {
      const t = now(), ev: { ts: number; a: Agent; text: string; key?: string }[] = [];
      for (const a of agents()) {
        const s = a.snap(t);
        if (a.firstTs) ev.push({ ts: a.firstTs, a, text: theme.fg("accent", "▶ started") + theme.fg("muted", `  ${phaseName(a.phase)} · ${clip(a.task, r.w - 60)}`) });
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
      const h = r.h - 1, y0 = r.y + 1;
      const max = Math.max(0, ev.length - h);
      if (tailFollow) tailScroll = max;
      tailScroll = Math.max(0, Math.min(tailScroll, max));
      const lab = Math.min(26, Math.floor(r.w * 0.2));
      const label = theme.fg("accent", " stream ") + theme.fg("muted", "· every agent, newest last · t closes ");
      const out = [theme.fg("borderMuted", "──") + label + theme.fg("borderMuted", "─".repeat(Math.max(0, r.w - 2 - visibleWidth(label))))];
      shell.hits.row(r.x, r.x + r.w, r.y, { click: toggleTail });
      for (let k = 0; k < h; k++) {
        const e = ev[tailScroll + k];
        if (!e) { out.push(""); continue; }
        out.push(shell.hl(` ${theme.fg("dim", clock(e.ts, true))} ${theme.fg(colorOf(e.a.id), pad(mid(e.a.name, lab), lab))} ${theme.fg("borderMuted", "│")} ${e.text}`, r.w, false, e.a.id === shell.selectedId || shell.pointer.over(y0 + k)));
      }
      shell.hits.add({ x0: r.x, x1: r.x + r.w, y0, y1: y0 + h,
        click: (evt) => {
          const e = ev[tailScroll + evt.y - y0]; if (!e) return;
          shell.pick(e.a.id);
          if (e.key) { const v = e.a.view; v.cursor = e.key; v.follow = false; v.overrides.set(e.key, true); const rows = transcriptRows(e.a, 80); v.scroll = Math.max(0, rows.findIndex((x) => x.key === e.key) - 3); }
          if (evt.clickCount && evt.clickCount >= 2) shell.act("zoom");
        },
        right: (evt) => { const e = ev[tailScroll + evt.y - y0]; if (e) { shell.pick(e.a.id); shell.act("pin"); } },
        wheel: (d) => { tailScroll = Math.max(0, tailScroll + d * 3); tailFollow = tailScroll >= max; } });
      if (!tailFollow) {
        out[out.length - 1] = pad(theme.bg("customMessageBg", theme.fg("warning", ` ⏸ scrolled back · ${max - tailScroll} newer · click to follow `)), r.w);
        shell.hits.front({ x0: r.x, x1: r.x + r.w, y0: r.y + r.h - 1, y1: r.y + r.h, click: () => { tailFollow = true; } });
      }
      return out;
    };

    // ---------- run picker ----------
    const pickerMeta = new Map<string, { name: string; description: string }>();
    const renderPicker = (w: number, h: number, y: number): string[] => {
      const close = theme.fg("accent", " ✕ close ");
      const out = [pad(theme.bold(" workflow runs ") + theme.fg("muted", "newest activity first · enter or click opens "), w - visibleWidth(close)) + close];
      shell.hits.front({ x0: w - visibleWidth(close), x1: w, y0: y, y1: y + 1, click: () => { picker = false; } });
      const bodyH = h - 1;
      if (pickerIdx < pickerScroll) pickerScroll = pickerIdx;
      if (pickerIdx >= pickerScroll + bodyH) pickerScroll = pickerIdx - bodyH + 1;
      shell.hits.add({ x0: 0, x1: w, y0: y + 1, y1: y + 1 + bodyH, click: (ev) => { const r = runs[pickerScroll + ev.y - y - 1]; if (r) { if (r.dir !== run?.dir) openRun(r.dir); picker = false; } }, wheel: (d) => { pickerScroll = Math.max(0, Math.min(runs.length - 1, pickerScroll + d * 2)); } });
      for (let k = 0; k < bodyH; k++) {
        const r = runs[pickerScroll + k];
        if (!r) { out.push(""); continue; }
        const sd = dirname(dirname(dirname(r.dir))), id = basename(r.dir);
        let meta = pickerMeta.get(id);
        if (!meta) { meta = scriptMeta(sd, id); pickerMeta.set(id, meta); }
        const fresh = Date.now() - r.mtime < STALL_MS;
        const text = ` ${fresh ? theme.fg("success", "●") : theme.fg("muted", "○")} ${pad(theme.bold(meta.name || id), 34)} ${theme.fg("muted", pad(dur(Date.now() - r.mtime) + " ago", 10))} ${theme.fg("dim", pad(projectOf(sd), 36))} ${theme.fg("dim", clip(meta.description, Math.max(0, w - 90)))}`;
        out.push(shell.hl(text, w, pickerScroll + k === pickerIdx, shell.pointer.over(y + 1 + k)));
      }
      return out;
    };

    const spec: Spec = {
      listName: "agents",
      title: () => run?.name ?? "workflow",
      ids: () => (mode === 1 ? tableOrder() : phaseList().flatMap(inPhase)).map((a) => a.id),
      has: (id) => !!byId(id),
      state: (id) => (byId(id)?.state(now()) ?? "waiting") as State,
      problem: (id) => (byId(id)?.snap(now()).errors ?? 0) > 0,
      lastAct: (id) => byId(id)?.snap(now()).lastAct ?? 0,
      view: (id) => byId(id)!.view,
      label: (id) => byId(id)?.name ?? id,
      groupOf: (id) => byId(id)?.phase ?? "",
      group: (ph, op) => { if (op === "toggle" ? collapsed.has(ph) : op === "open") collapsed.delete(ph); else collapsed.add(ph); },
      onSelect: (id) => { const a = byId(id); if (a) collapsed.delete(a.phase); },
      autoSize: (side, W) => (side ? (mode === 0 ? Math.min(64, Math.max(36, Math.floor(W * 0.36))) : Math.floor(W * (mode === 1 ? 0.58 : 0.55))) : 0),
      get empty() { return run ? "select an agent" : "no workflow runs under ~/.claude/projects"; },
      help: [
        ["1 2 3", "list mode: Tree, Table, Timeline (or click a tab)"],
        ["t", "toggle the stream: every agent's events interleaved, newest last"],
        ["r", "pick another run"],
        ["s  S", "Table: cycle the sort column / reverse it"],
        ["P", "pause or resume the live feed"],
        [", .", "replay slower / faster"],
      ],
      tickMs: REPLAY ? 250 : 1000,
      tick: () => { if (pausedAt == null) run?.refresh(); },
      now: () => pausedAt ?? rawNow(),
      dispose: () => clearInterval(rescan),

      top: (w) => [header(w), tabsRow(w)],
      list: (w) => (mode === 0 ? { rows: treeRows(w) } : mode === 1 ? tableList(w) : timelineList(w)),
      detailHead: (id, w, x, y) => card(byId(id)!, w, x, y),
      rows: (id, w) => { const a = byId(id); return a ? transcriptRows(a, w) : []; },
      tailRows: (bodyH) => (tailOpen ? Math.max(5, Math.floor(bodyH * 0.3)) : 0),
      tail: stream,
      modal: (w, h, y) => (picker ? renderPicker(w, h, y) : undefined),

      key(data, key) {
        if (picker) {
          if (key("escape") || data === "q" || data === "r") picker = false;
          else if (key("j") || key("down")) pickerIdx = Math.min(runs.length - 1, pickerIdx + 1);
          else if (key("k") || key("up")) pickerIdx = Math.max(0, pickerIdx - 1);
          else if (key("enter") && runs[pickerIdx]) { if (runs[pickerIdx].dir !== run?.dir) openRun(runs[pickerIdx].dir); picker = false; }
          else if (data === "1" || data === "2" || data === "3") setMode(Number(data) - 1);
          return true;
        }
        if (data === "1" || data === "2" || data === "3") setMode(Number(data) - 1);
        else if (data === "t") toggleTail();
        else if (data === "r") togglePicker();
        else if (data === "P") togglePause();
        else if (data === ",") { if (REPLAY) setSpeed(speed / 2); else shell.say("speed applies to replays (CCWF_REPLAY)"); }
        else if (data === ".") { if (REPLAY) setSpeed(speed * 2); else shell.say("speed applies to replays (CCWF_REPLAY)"); }
        else if (data === "s" && mode === 1) { const k = SORTS[(SORTS.indexOf(sortKey) + 1) % SORTS.length]; setSort(k, k === "time" || k === "tools" || k === "ctx"); shell.say(`sorted by ${k}`); }
        else if (data === "S" && mode === 1) setSort(sortKey, !sortDesc);
        else return false;
        return true;
      },
      hints() {
        if (picker) return [{ key: "esc", label: "close", run: togglePicker }];
        const out: Hint[] = [{ key: "t", label: tailOpen ? "hide stream" : "stream", run: toggleTail }, { key: "P", label: pausedAt != null ? "resume" : "pause", run: togglePause }];
        if (REPLAY) out.push({ key: ", .", label: `${speed}x`, run: () => setSpeed(speed * 2) });
        if (mode === 1 && !shell.inDetail) out.push({ key: "s", label: `sort: ${sortKey}`, run: () => spec.key!("s", () => false) }, { key: "S", label: "reverse", run: () => setSort(sortKey, !sortDesc) });
        return out;
      },
    };
    return spec;
  }, { placement: "left" });
}
