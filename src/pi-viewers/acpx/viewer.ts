// pi extension: watches acpx delegations. A roster of runs beside the selected run's transcript as
// dense, expandable rows; the shared kit (lib/kit.ts) draws the frame, the keys and the mouse. It
// attaches to sessions that acpx-pane started (`acpx sessions watch`) and never prompts them;
// cancelling a run (`x`, then `y`) is its only write to a session. Each run's first prompt goes to
// ACPX_SUMMARY_CMD (by default a Haiku call) for the roster label. `pi-viewer acpx` launches it
// with PI_VIEWER=acpx; any other pi ignores it.
//   ACPX_CWD=<dir>    only sessions whose cwd is <dir> or below it (the worktree)
//   ACPX_PREFIX=<p>   only sessions whose name starts with <p>
//   ACPX_SUMMARY_CMD  shell command that reads a prompt on stdin and prints labels for the
//                     roster; empty disables (the agent's session title is used).
//                     Default: claude -p with haiku.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn, execFile, type ChildProcess } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Delegation, type Rec, diffStats, done, failed, label, outputText, rel, statusWord, summary, thoughtHeader } from "./feed.ts";
import {
  clip, clock, dur, fitFields, kTok, leftClip, matches, money, pad, runViewer, shortenPaths, stateColor, stateRoot, visibleWidth, wrapTextWithAnsi,
  type Hint, type ListRow, type Row, type Spec, type State,
} from "../lib/kit.ts";

const SESSIONS = join(homedir(), ".acpx/sessions");
const PREFIX = process.env.ACPX_PREFIX ?? "";
const real = (p: string) => { try { return realpathSync(p); } catch { return p; } };
const CWD = process.env.ACPX_CWD ? real(process.env.ACPX_CWD) : undefined;
const SUMMARY_CMD = process.env.ACPX_SUMMARY_CMD ?? `claude -p --model haiku --no-session-persistence --tools "" --disable-slash-commands --system-prompt 'You label delegated coding tasks. Never perform the task. Reply with only the labels.'`;
const KIND_LABEL: Record<string, string> = { read: "read", search: "search", execute: "run", edit: "edit", delete: "delete", move: "move", fetch: "fetch", think: "think", other: "tool" };
const SUMMARIES = join(stateRoot(), "acpx", "summaries");

// Session records re-read only when their mtime changes; null marks one outside this viewer.
const recordCache = new Map<string, { mtime: number; rec: Rec | null }>();
function records(): Rec[] {
  const out: Rec[] = [];
  let files: string[] = [];
  try { files = readdirSync(SESSIONS); } catch { return out; }
  for (const f of files) {
    if (!f.endsWith(".json")) continue;
    try {
      const path = join(SESSIONS, f);
      const mtime = statSync(path).mtimeMs;
      const hit = recordCache.get(f);
      if (hit && hit.mtime === mtime) { if (hit.rec) out.push(hit.rec); continue; }
      recordCache.set(f, { mtime, rec: null });
      const r = JSON.parse(readFileSync(path, "utf8"));
      if (!r.name || !r.name.startsWith(PREFIX)) continue;
      if (CWD && real(r.cwd) !== CWD && !real(r.cwd).startsWith(CWD + "/")) continue;
      const rec: Rec = { id: f.slice(0, -5), name: r.name, cwd: r.cwd, agent: r.agent_command, closed: !!r.closed, title: r.title || undefined,
        createdAt: Date.parse(r.created_at) || undefined, lastPromptAt: Date.parse(r.last_prompt_at) || undefined, lastUsedAt: Date.parse(r.last_used_at) || undefined,
        shortcut: r.agent_command?.match(/acpx-routing run (\S+)/)?.[1] ?? r.agent_command?.split(/[\s/]/).filter(Boolean).pop() ?? "?",
        model: String(r.acpx?.current_model_id ?? "").split("[")[0] };
      recordCache.set(f, { mtime, rec });
      out.push(rec);
    } catch {} // a half-written record is retried when its mtime changes
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

// Attach to a session: replayed history arrives in one burst, then live events follow.
const watchers = new Map<Delegation, ChildProcess>();
function watch(d: Delegation, onChange: () => void) {
  const { cwd, agent, name } = d.rec;
  const proc = spawn("acpx", ["--format", "json", "--cwd", cwd, "--agent", agent, "sessions", "watch", "-s", name], { cwd: "/tmp", stdio: ["ignore", "pipe", "ignore"] });
  watchers.set(d, proc);
  let buf = "";
  let settle: ReturnType<typeof setTimeout> | undefined;
  proc.stdout!.setEncoding("utf8"); // keeps multi-byte characters intact across chunks
  proc.stdout!.on("data", (chunk: string) => {
    buf += chunk;
    const rows = buf.split("\n");
    buf = rows.pop() ?? "";
    for (const row of rows) {
      try { d.feed(JSON.parse(row)); } catch {} // a malformed event must not stop the view
    }
    clearTimeout(settle);
    if (!d.settled) settle = setTimeout(() => { d.settled = true; }, 700);
    onChange();
  });
  proc.on("exit", () => {
    if (watchers.get(d) === proc) watchers.delete(d);
    if (d.status === "running") d.status = "detached";
    onChange();
  });
  return d;
}
function unwatch(d: Delegation) { watchers.get(d)?.kill(); watchers.delete(d); }
function cancelRun(d: Delegation) {
  execFile("acpx", ["--cwd", d.rec.cwd, "--agent", d.rec.agent, "cancel", "-s", d.rec.name], { cwd: "/tmp" }, () => {});
}

// Summaries sized to their slot. One call per run returns every size at once, each a condensed
// form of the longest, so a run keeps the same wording on every screen. Until it returns, every
// view shows the same fallback (the agent's session title).
const SUMMARY_SIZES = [30, 45, 60, 80, 100];
const summaries = new Map<string, Record<number, string> | null>(); // null while pending
const summaryQueue: { id: string; prompt: string }[] = [];
let summarizing = 0;
const SUMMARY_JOBS = 3;
const summaryFile = (id: string) => join(SUMMARIES, `${id}.json`);
function summaryFor(id: string, prompt: string, budget: number, onDone: () => void): string | undefined {
  if (!summaries.has(id)) {
    try { summaries.set(id, JSON.parse(readFileSync(summaryFile(id), "utf8"))); } catch {}
  }
  if (!summaries.has(id) && prompt) {
    summaries.set(id, null);
    if (SUMMARY_CMD.trim()) { summaryQueue.push({ id, prompt }); pumpSummaries(onDone); }
  }
  const set = summaries.get(id);
  if (!set) return undefined;
  const size = [...SUMMARY_SIZES].reverse().find((n) => n <= budget && set[n]) ?? SUMMARY_SIZES.find((n) => set[n]);
  return size ? set[size] : undefined;
}
function pumpSummaries(onDone: () => void) {
  if (summarizing >= SUMMARY_JOBS) return;
  const job = summaryQueue.shift();
  if (!job) return;
  summarizing++;
  const child = execFile("/bin/sh", ["-c", SUMMARY_CMD], { cwd: "/tmp", timeout: 90_000 }, (err, stdout) => {
    summarizing--;
    const lines = String(stdout ?? "").trim().split("\n").map((l) => l.trim().replace(/^\d+[:.)]\s*/, "").replace(/^["'-]\s*|["'.]$/g, "")).filter(Boolean);
    // A model that answers the task instead of labelling it is discarded; an overlong label is cut.
    if (!err && lines.length >= SUMMARY_SIZES.length && !lines.some((l) => /^(I|I'll|I'm|Let me|Sure)\b/.test(l))) {
      const set: Record<number, string> = {};
      SUMMARY_SIZES.forEach((n, k) => { const t = lines[k]; set[n] = t.length <= n ? t : t.slice(0, n - 1).replace(/\s+\S*$/, "") + "…"; });
      summaries.set(job.id, set);
      try { mkdirSync(SUMMARIES, { recursive: true }); writeFileSync(summaryFile(job.id), JSON.stringify(set) + "\n"); } catch {}
      onDone();
    }
    pumpSummaries(onDone);
  });
  pumpSummaries(onDone); // fill the remaining slots
  child.stdin?.end(`<task>\n${job.prompt.slice(0, 4000)}\n</task>\nLabel the task above. Reply with exactly ${SUMMARY_SIZES.length} lines, one label per line, at most ${SUMMARY_SIZES.join(", ")} characters respectively (counting spaces). Write the longest first in your head, then condense it for each shorter line, keeping the same leading words. Output the lines shortest first. Do not perform the task.`);
}

// Billing access per routing shortcut ("included" for cursor routes), looked up once.
const access = new Map<string, string>();
function accessFor(shortcut: string, onDone: () => void) {
  if (access.has(shortcut)) return access.get(shortcut) || undefined;
  access.set(shortcut, "");
  execFile(join(homedir(), ".agents/bin/acpx-routing"), ["show", shortcut], { cwd: "/tmp", timeout: 15_000 }, (err, stdout) => {
    try { access.set(shortcut, JSON.parse(String(stdout)).access ?? ""); onDone(); } catch {}
  });
  return undefined;
}

const stateOf = (d: Delegation): State =>
  d.status === "running" ? (d.settled ? "running" : "starting") : d.status === "completed" ? "done" : d.status === "failed" ? "failed"
  : d.status === "cancelled" ? "cancelled" : d.status === "detached" ? "detached" : "waiting";
const hasProblem = (d: Delegation) => d.status === "failed" || d.failedTools > 0 || d.denied > 0 || d.errors > 0;
const OUTCOME_W = 18;

export default function (pi: ExtensionAPI) {
  runViewer(pi, "acpx", (shell) => {
    const { theme } = shell;
    const roster = new Map<string, Delegation>();
    const render = () => shell.render();
    const dot = theme.fg("dim", " · ");

    const scan = () => {
      for (const rec of records()) {
        const d = roster.get(rec.id);
        // A closed session leaves the roster; the viewer lists this worktree's open sessions.
        if (d && rec.closed) { unwatch(d); roster.delete(rec.id); continue; }
        if (d && !watchers.has(d)) {
          // The watch ended (queue owner exit, transient error): attach again. The replay
          // rebuilds history, so start from a fresh model and keep only the view state.
          const fresh = new Delegation(rec);
          fresh.view = d.view;
          roster.set(rec.id, watch(fresh, render));
          continue;
        }
        if (d) { d.rec.lastPromptAt = rec.lastPromptAt; d.rec.lastUsedAt = rec.lastUsedAt; d.rec.title = rec.title; continue; }
        if (rec.closed) continue;
        roster.set(rec.id, watch(new Delegation(rec), render));
      }
      render();
    };
    scan();
    const scanTimer = setInterval(scan, 3000);

    // `budget` is the characters the caller's slot can show (all its lines together).
    const summaryOf = (d: Delegation, budget: number) =>
      summaryFor(d.rec.id, d.firstPrompt, budget, render) ?? d.rec.title ?? (d.firstPrompt.split("\n").find((l) => l.trim()) || d.rec.name);
    const matchesFilter = (d: Delegation) => !shell.filter || matches(shell.filter, `${summaryOf(d, 100)} ${d.rec.name} ${d.rec.shortcut}`);
    let frameList: Delegation[] | undefined, frameT = -1;
    const list = () => {
      if (!frameList || frameT !== shell.t) {
        frameT = shell.t;
        frameList = [...roster.values()].filter(matchesFilter).sort((a, b) => Number(b.status === "running") - Number(a.status === "running") || (b.started ?? 0) - (a.started ?? 0));
      }
      return frameList;
    };
    const byId = (id: string) => roster.get(id);
    const sel = () => byId(shell.selectedId ?? "");
    const mark = (d: Delegation) => shell.glyph(stateOf(d));
    const color = (s: string) => stateColor(s === "completed" ? "done" : s);

    const timing = (d: Delegation) => {
      const busy = d.busyMs();
      return d.status === "running" ? dur(Date.now() - d.startOf(d.turn)) : busy > 1500 ? dur(busy) : "";
    };
    // Detail header fields in priority order; narrow screens keep the leading ones.
    const metaFields = (d: Delegation): string[] => {
      const acc = accessFor(d.rec.shortcut, render);
      const time = timing(d);
      return [
        theme.fg(color(d.status), statusWord(d.status, d.turn?.stopReason) + (time ? ` ${time}` : "")),
        theme.fg("text", d.rec.name),
        theme.fg("muted", d.rec.shortcut),
        theme.fg("muted", `started ${clock(d.started)}`),
        theme.fg("muted", `${d.toolCount} tool${d.toolCount === 1 ? "" : "s"}`),
        theme.fg("muted", money(d.cost) ? `cost ${money(d.cost)}` : acc === "included" ? "cost: in plan" : acc ? "cost: n/a" : ""),
        d.tokens != null ? theme.fg("muted", `${kTok(d.tokens)} tok`) : "",
        d.turns.length > 1 ? theme.fg("muted", `${d.turns.length} turns`) : "",
        theme.fg("muted", d.rec.model),
      ].filter((f) => visibleWidth(f) > 0);
    };
    // A finished run's outcome: "ok", or counts of what went wrong.
    // Glyph + count only: ✗ failed tool calls, ⊘ denied permissions, ! protocol errors. With
    // `aligned`, each count sits in a fixed 4-cell slot so the glyphs line up down a column.
    const outcome = (d: Delegation, aligned = false) => {
      if (d.status === "running") return theme.fg("text", d.activity());
      if (d.status !== "completed") return theme.fg("error", d.activity());
      const slot = (n: number, glyph: string, c: "error" | "warning") =>
        n ? theme.fg(c, `${glyph}${n}`) + (aligned ? " ".repeat(Math.max(1, 4 - `${glyph}${n}`.length)) : "") : aligned ? "    " : "";
      const bits = [slot(d.failedTools, "✗", "error"), slot(d.denied, "⊘", "warning"), slot(d.errors, "!", "error")];
      return aligned ? bits.join("") : bits.filter(Boolean).join(" ");
    };
    // Runs launched in the same minute form a batch: only the first shows its start time.
    const startLabel = (ds: Delegation[], i: number) => {
      const t = clock(ds[i]?.started);
      return i > 0 && clock(ds[i - 1]?.started) === t ? " ".repeat(t.length) : t;
    };

    // One line per run, for a strip above or below the transcript.
    // Fixed columns: glyph · summary · start · duration · counts (or what a running run is doing).
    const stripRow = (ds: Delegation[], i: number, w: number): ListRow => {
      const d = ds[i];
      const tail = `${theme.fg("muted", startLabel(ds, i))}  ${theme.fg("muted", (timing(d) || "–").padStart(6))}  ${pad(clip(outcome(d, true), OUTCOME_W), OUTCOME_W)}`;
      const room = w - visibleWidth(tail) - 6;
      const body = ` ${theme.bold(theme.fg("text", clip(summaryOf(d, room), room)))}`;
      return { id: d.rec.id, lead: ` ${mark(d)}`, problem: hasProblem(d), text: pad(body, w - 3 - visibleWidth(tail)) + tail };
    };
    // Summary (wraps to two lines) with elapsed time, then start time · route · outcome.
    const card = (ds: Delegation[], i: number, w: number): ListRow[] => {
      const d = ds[i], id = d.rec.id;
      const quiet = d.status === "running" && Date.now() - d.lastEvent > 15000 ? theme.fg("warning", ` · quiet ${dur(Date.now() - d.lastEvent)}`) : "";
      const time = timing(d);
      const room = w - 4 - (time ? visibleWidth(time) + 1 : 0);
      const wrapped = wrapTextWithAnsi(summaryOf(d, room * 2), room);
      const titles = wrapped.length > 2 ? [wrapped[0], clip(wrapped.slice(1).join(" "), room)] : wrapped;
      const rows: ListRow[] = titles.map((t, k) => {
        const l = ` ${theme.bold(theme.fg("text", t))}`;
        if (k) return { id, text: "  " + l };
        return { id, lead: ` ${mark(d)}`, problem: hasProblem(d), text: l + " ".repeat(Math.max(1, w - 2 - visibleWidth(l) - visibleWidth(time))) + theme.fg("muted", time) };
      });
      // Missing fields are omitted, not padded, so the line always starts at the title's indent.
      const parts = [startLabel(ds, i).trim() ? theme.fg("muted", startLabel(ds, i)) : "", shell.narrow ? "" : theme.fg("muted", d.rec.shortcut), outcome(d)].filter(Boolean);
      rows.push({ id, text: `   ${parts.join(dot)}${quiet}` });
      return rows;
    };

    let cancelArmed = 0;
    const armed = () => Date.now() - cancelArmed < 5000;
    const askCancel = (d: Delegation) => {
      if (armed()) { cancelRun(d); cancelArmed = 0; shell.say(`cancelling ${d.rec.name}`); } else cancelArmed = Date.now();
    };

    const spec: Spec = {
      listName: "runs",
      title: () => (CWD ? CWD.replace(homedir(), "~") : "acpx"),
      ids: () => list().map((d) => d.rec.id),
      has: (id) => roster.has(id),
      state: (id) => { const d = byId(id); return d ? stateOf(d) : "waiting"; },
      problem: (id) => { const d = byId(id); return !!d && hasProblem(d); },
      lastAct: (id) => byId(id)?.lastEvent ?? 0,
      view: (id) => byId(id)!.view,
      label: (id) => { const d = byId(id); return d ? summaryOf(d, 60) : id; },
      empty: "waiting for acpx delegations",
      help: [
        ["x", "cancel the selected run (asks y/n)"],
        ["✗3 ⊘2", "3 failed tool calls · 2 denied permissions"],
      ],
      dispose() { clearInterval(scanTimer); for (const d of roster.values()) unwatch(d); },

      top(w) {
        const ds = list(), running = ds.filter((d) => d.status === "running").length;
        const where = CWD ? CWD.replace(homedir(), "~") : "all sessions";
        const filter = shell.filter ? theme.fg("warning", `  / ${shell.filter}`) : "";
        const left = ` ${theme.bold(theme.fg("accent", "acpx"))} ${theme.fg("muted", where)}  ${theme.fg("muted", `${running} running · ${ds.length} shown`)}${filter}`;
        const legend = theme.fg("muted", "✗ failed calls  ⊘ denied  ");
        return [clip(left, w - visibleWidth(legend) - 1) + " ".repeat(Math.max(1, w - visibleWidth(left) - visibleWidth(legend))) + legend];
      },

      list(w) {
        const ds = list();
        const running = ds.filter((d) => d.status === "running").length;
        const rows: ListRow[] = [];
        if (!shell.side && !shell.narrow) ds.forEach((_, i) => rows.push(stripRow(ds, i, w)));
        else {
          if (running) rows.push({ text: ` ${theme.bold(theme.fg("muted", "running"))} ${theme.fg("muted", String(running))}` });
          ds.forEach((_, i) => {
            if (i === running) rows.push({ text: ` ${theme.bold(theme.fg("muted", "finished"))} ${theme.fg("muted", String(ds.length - running))}` });
            rows.push(...card(ds, i, w));
            if (shell.narrow && i < ds.length - 1) rows.push({ text: "" });
          });
        }
        if (!roster.size) rows.push({ text: theme.fg("muted", ` no open acpx sessions${PREFIX ? ` named ${PREFIX}*` : ""}`) });
        else if (!ds.length) rows.push({ text: theme.fg("muted", `  nothing matches /${shell.filter}`) });
        return { rows };
      },

      // The phone shows the run's title here; desktop already shows it in the run list.
      detailHead(id, w) {
        const d = byId(id)!;
        if (shell.narrow) {
          const title = wrapTextWithAnsi(theme.bold(theme.fg("text", summaryOf(d, (w - 3) * 2))), w - 3).slice(0, 2).map((l, k) => pad(` ${k ? " " : mark(d)} ${l}`, w));
          return [...title, ...fitFields(metaFields(d), w - 3, 2, dot).map((l) => pad(`   ${l}`, w))];
        }
        return fitFields(metaFields(d), w - 3, 1, dot).map((l) => pad(` ${mark(d)} ${l}`, w));
      },

      rows(id, width) {
        const d = byId(id);
        if (!d) return [];
        const v = d.view, dens = shell.dens, narrow = shell.narrow, cwd = d.rec.cwd;
        const rows: Row[] = [];
        const gut = narrow ? " " : "  ";
        const md = (owner: object, text: string) => shell.md(owner, narrow ? shortenPaths(text, width - 1) : text, width - gut.length).map((l) => gut + l);
        // Show the last `max` wrapped rows; live output and thinking stay short.
        const indent = (lines: string[], c = "toolOutput", max = 14) => shell.indent(rows, lines.map((l) => rel(l, cwd)), width, c, max);
        const open = (key: string, auto: boolean) => v.overrides.get(key) ?? (dens === "full" ? true : auto);
        d.turns.forEach((turn, ti) => {
          const latest = ti === d.turns.length - 1;
          const live = turn.status === "running";
          const tkey = `t${ti}`;
          const o = open(tkey, latest);
          const status = live ? theme.fg("warning", `running ${dur(Date.now() - d.startOf(turn))}`)
            : theme.fg(color(turn.status), statusWord(turn.status, turn.stopReason))
              + (d.endOf(turn) && d.endOf(turn)! - d.startOf(turn) > 1500 ? theme.fg("muted", ` · ${dur(d.endOf(turn)! - d.startOf(turn))}`) : "")
              + (turn.cost != null ? theme.fg("muted", ` · ${money(turn.cost)}`) : "") + (turn.tokens != null ? theme.fg("muted", ` · ${kTok(turn.tokens)} tok`) : "");
          const promptFirst = turn.prompt.split("\n").find((l) => l.trim()) ?? "(prompt not retained)";
          rows.push({ key: tkey, head: true, open: o, hay: turn.prompt, text: `${theme.fg("accent", o ? "▾" : "▸")} ${theme.bold(`turn ${ti + 1}`)}  ${status}  ${o ? "" : theme.fg("muted", promptFirst)}` });
          if (!o) return;
          if (turn.prompt) for (const l of md(turn, turn.prompt)) rows.push({ text: l });
          rows.push({ text: "" });
          turn.items.forEach((item, ii) => {
            const key = `${tkey}.${ii}`;
            const lastItem = ii === turn.items.length - 1;
            if (item.type === "text") {
              if (ii > 0 && turn.items[ii - 1].type !== "text") rows.push({ text: "" });
              for (const l of md(item, item.text)) rows.push({ text: l });
              if (!lastItem) rows.push({ text: "" });
            } else if (item.type === "thought") {
              const thinking = live && lastItem;
              if (dens === "compact" && !thinking) return;
              const oo = open(key, thinking);
              rows.push({ key, parent: tkey, open: oo, live: thinking, hay: item.text, text: `${theme.fg("muted", oo ? "▾" : "▸")} ${theme.fg("muted", theme.italic(thinking ? "thinking…" : "thought"))}  ${theme.fg("text", thoughtHeader(item.text))}` });
              if (oo) indent(item.text.trim().split("\n").filter((l) => l.trim()).map((l) => l.replace(/\*\*/g, "")), "thinkingText", thinking ? 8 : 400);
            } else if (item.type === "tools") {
              const running = item.tools.some((t) => !done(t));
              const oo = open(key, live && running);
              const bad = item.tools.some(failed);
              const glyph = running && live ? theme.fg("accent", "◌") : running ? theme.fg("warning", "?") : bad ? theme.fg("error", "✗") : theme.fg("success", "✓");
              const kl = (KIND_LABEL[item.kind] ?? item.kind).padEnd(6);
              if (item.tools.length === 1) {
                const t = item.tools[0];
                const sum = running && !live ? "unfinished" : summary(t, item.kind);
                const denied = t.verdict === "denied" || t.verdict === "cancelled";
                const g = denied ? theme.fg("error", "✗") : glyph;
                const verdict = t.verdict ? theme.fg(t.verdict === "allowed" ? "warning" : "error", `${t.verdict} `) : "";
                const lbl = label(t, cwd);
                const room = width - 9 - visibleWidth(verdict);
                const shown = item.kind === "read" || item.kind === "edit" ? leftClip(lbl, room) : lbl;
                const head = `${g} ${theme.fg("toolTitle", theme.bold(kl))} ${verdict}${theme.fg("text", shown)}`;
                const hay = `${lbl}\n${sum}\n${outputText(t)}`;
                if (bad || denied) {
                  // The error is the point of a failed row: give it its own wrapped lines.
                  rows.push({ key, parent: tkey, open: oo, problem: true, live: running && live, hay, text: clip(head, width) });
                  if (sum && !oo) {
                    const lines = wrapTextWithAnsi(rel(sum, cwd), width - 9);
                    lines.slice(0, 3).forEach((wl, k) => rows.push({ text: "         " + theme.fg("error", k === 2 && lines.length > 3 ? clip(wl + " …", width - 9) : wl) }));
                  }
                } else rows.push({ key, parent: tkey, open: oo, live: running && live, hay, text: head + (sum ? "  " + theme.fg("muted", sum) : "") });
                if (oo) {
                  if (item.kind === "execute" && t.rawInput?.command && String(t.rawInput.command).includes("\n")) indent(String(t.rawInput.command).split("\n"), "text", 20);
                  const s = diffStats(t);
                  if (s) for (const c of t.content ?? []) if (c?.type === "diff") {
                    const old = new Set(String(c.oldText ?? "").split("\n")), neu = String(c.newText ?? "").split("\n");
                    rows.push({ text: theme.fg("dim", "   │ ") + theme.fg("muted", rel(c.path ?? "", cwd)) });
                    for (const l of String(c.oldText ?? "").split("\n").filter((l) => c.oldText != null && !neu.includes(l)).slice(0, 30)) rows.push({ text: theme.fg("dim", "   │ ") + theme.fg("toolDiffRemoved", clip("- " + l, width - 5)) });
                    for (const l of neu.filter((l) => !old.has(l)).slice(0, 30)) rows.push({ text: theme.fg("dim", "   │ ") + theme.fg("toolDiffAdded", clip("+ " + l, width - 5)) });
                  }
                  else {
                    const out = outputText(t).replace(/\n$/, "");
                    if (out) indent(out.split("\n"), bad ? "error" : "toolOutput", running ? 8 : 40);
                    else if (running) rows.push({ text: theme.fg("dim", "   │ ") + theme.fg("muted", "waiting for output…") });
                  }
                }
              } else {
                const counts = new Map<string, number>();
                for (const t of item.tools) counts.set(label(t, cwd), (counts.get(label(t, cwd)) ?? 0) + 1);
                const one = counts.size === 1;
                const names = one ? [...counts.keys()][0] : [...counts].map(([n, c]) => (c > 1 ? `${n} ×${c}` : n)).join(", ");
                const nFailed = item.tools.filter(failed).length, nRunning = item.tools.filter((t) => !done(t)).length;
                const tally = [nFailed ? theme.fg("error", `${nFailed} failed`) : "", nRunning ? theme.fg("muted", `${nRunning} running`) : ""].filter(Boolean).join(theme.fg("muted", " · "));
                const body = one ? `${theme.fg("text", names)} ${theme.fg("muted", `×${item.tools.length}`)}` : `${theme.fg("muted", `×${item.tools.length}`)} ${theme.fg("text", names)}`;
                rows.push({ key, parent: tkey, open: oo, problem: bad, live: running && live, hay: names, text: clip(`${glyph} ${theme.fg("toolTitle", theme.bold(kl))} ${body}`, width - visibleWidth(tally) - 2) + (tally ? "  " + tally : "") });
                if (oo) for (const t of item.tools) {
                  const g = !done(t) ? theme.fg(live ? "accent" : "warning", live ? "◌" : "?") : failed(t) ? theme.fg("error", "✗") : theme.fg("success", "✓");
                  rows.push({ text: `${theme.fg("dim", "   │ ")}${g} ${theme.fg("text", label(t, cwd))}  ${theme.fg("muted", done(t) || live ? summary(t, item.kind) : "unfinished")}` });
                }
              }
            } else {
              const n = item.count && item.count > 1 ? ` ×${item.count}` : "";
              const [verdict, ...rest] = item.text.split(": ");
              rows.push({ key, parent: tkey, open: false, problem: true, hay: item.text, text: clip(theme.fg(item.tone, `! ${rest.length ? `${verdict}${n}: ${rest.join(": ")}` : item.text + n}`), width) });
            }
          });
          if (!live) rows.push({ text: "" });
        });
        if (!d.turns.length) rows.push({ text: theme.fg("muted", "attaching…") });
        return rows;
      },

      key(data) {
        const d = sel();
        if (armed()) { if (d && data === "y") askCancel(d); else cancelArmed = 0; return true; }
        if (data === "x" && d?.status === "running") { askCancel(d); return true; }
        return false;
      },
      hints() {
        const d = sel(), out: Hint[] = [];
        if (d?.status === "running") out.push({ key: armed() ? "y" : "x", label: armed() ? "cancel? y confirms" : "cancel", run: () => askCancel(d), danger: armed(), narrow: true });
        return out;
      },
    };
    return spec;
  }, { placement: "top" });
}
