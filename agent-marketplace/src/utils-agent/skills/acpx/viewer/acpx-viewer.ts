// pi extension: a full-screen viewer for acpx delegations. One roster of runs and the
// focused run's transcript as dense, expandable rows. It attaches to sessions that
// acpx-pane started (`acpx sessions watch`) and never prompts them; cancelling a run
// (`x`, then `y`) is its only write to a session. Each run's first prompt goes to
// ACPX_SUMMARY_CMD (by default a Haiku call) for the roster label. acpx-pane launches it as
// `pi -ne -e acpx-viewer.ts` with ACPX_VIEWER=1; any other pi ignores it.
//   ACPX_CWD=<dir>    only sessions whose cwd is <dir> or below it (the worktree)
//   ACPX_PREFIX=<p>   only sessions whose name starts with <p>
//   ACPX_ROSTER       roster placement: top (default), bottom, left, right; `L` cycles it
//                     and the choice is remembered in $XDG_STATE_HOME/acpx-viewer/placement
//   ACPX_ROSTER_ROWS  most rows a top/bottom roster may take (a number, or a percentage
//                     like 30%); `+`/`-` adjust it live and the value is remembered
//   ACPX_SUMMARY_CMD  shell command that reads a prompt on stdin and prints labels for the
//                     roster; empty disables (the agent's session title is used).
//                     Default: claude -p with haiku.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { compositeTuiLine, Markdown, matchesKey, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { spawn, execFile, type ChildProcess } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Delegation, type Rec, detail, diffStats, done, failed, label, outputText, rel, statusWord, summary, thoughtHeader } from "./acpx-feed.ts";

const SESSIONS = join(homedir(), ".acpx/sessions");
const PREFIX = process.env.ACPX_PREFIX ?? "";
const real = (p: string) => { try { return realpathSync(p); } catch { return p; } };
const CWD = process.env.ACPX_CWD ? real(process.env.ACPX_CWD) : undefined;
const NARROW = 100; // below this many columns (phones, split panes) the roster and the run stack
const STATE = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "acpx-viewer");
const PLACEMENTS = ["left", "right", "top", "bottom"] as const;
type Placement = (typeof PLACEMENTS)[number];
function initialRosterRows(): string {
  let saved: string | undefined;
  try { saved = readFileSync(join(STATE, "roster-rows"), "utf8").trim(); } catch {}
  return process.env.ACPX_ROSTER_ROWS ?? saved ?? "35%";
}
function initialPlacement(): Placement {
  const pick = (v?: string) => ((PLACEMENTS as readonly string[]).includes(v ?? "") ? (v as Placement) : undefined);
  let saved: string | undefined;
  try { saved = readFileSync(join(STATE, "placement"), "utf8").trim(); } catch {}
  return pick(process.env.ACPX_ROSTER) ?? pick(saved) ?? "top";
}
const SUMMARY_CMD = process.env.ACPX_SUMMARY_CMD ?? `claude -p --model haiku --no-session-persistence --tools "" --disable-slash-commands --system-prompt 'You label delegated coding tasks. Never perform the task. Reply with only the labels.'`;
const KIND_LABEL: Record<string, string> = { read: "read", search: "search", execute: "run", edit: "edit", delete: "delete", move: "move", fetch: "fetch", think: "think", other: "tool" };


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

// Cut from the left so the file name at the end survives.
function leftClip(text: string, w: number) {
  if (visibleWidth(text) <= w) return text;
  return "…" + text.slice(text.length - Math.max(1, w - 1));
}

// On a phone, abbreviate directories in long paths so `file:line` never wraps mid-token.
function shortenPaths(text: string, w: number) {
  return text.replace(/(?:[\w.~-]+\/)+[\w.-]+(?::\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)?/g, (m) => (m.length <= w - 6 ? m : "…/" + m.split("/").pop()));
}

function ago(ms: number) {
  const s = Math.max(0, Math.round(ms / 1000));
  return s >= 3600 ? `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m` : s >= 60 ? `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s` : `${s}s`;
}

const pad = (s: string, w: number) => truncateToWidth(s, w, "…", true);
const clip = (s: string, w: number) => truncateToWidth(s, w, "…");
// A full reset inside a highlighted row would end its background early.
const keepBg = (s: string) => s.split("\x1b[0m").join("\x1b[22;23;39m");

interface Row { text: string; key?: string; problem?: boolean }

// Summaries sized to their slot. One call per run returns every size at once, each a condensed
// form of the longest, so a run keeps the same wording on every screen. Until it returns, every
// view shows the same fallback (the agent's session title).
const SUMMARY_SIZES = [30, 45, 60, 80, 100];
const summaries = new Map<string, Record<number, string> | null>(); // null while pending
const summaryQueue: { id: string; prompt: string }[] = [];
let summarizing = 0;
const SUMMARY_JOBS = 3;
const summaryFile = (id: string) => join(STATE, "summaries", `${id}.json`);
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
      try { mkdirSync(join(STATE, "summaries"), { recursive: true }); writeFileSync(summaryFile(job.id), JSON.stringify(set) + "\n"); } catch {}
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

const clock = (ms?: number) => (ms ? new Date(ms).toTimeString().slice(0, 5) : "--:--");
const money = (n?: number) => (n == null ? undefined : n < 0.01 ? "<$0.01" : `$${n.toFixed(2)}`);
const kTokens = (n?: number) => (n == null ? undefined : n >= 1000 ? `${Math.round(n / 1000)}k tok` : `${n} tok`);

export default function (pi: ExtensionAPI) {
  if (process.env.ACPX_VIEWER !== "1") return;
  const roster = new Map<string, Delegation>();
  let selectedId: string | undefined;
  let scanTimer: ReturnType<typeof setInterval> | undefined;

  pi.registerProvider("acpx-viewer", {
    name: "acpx",
    baseUrl: "acpx://viewer",
    apiKey: "acpx",
    api: "acpx-viewer",
    models: [{ id: "viewer", name: "acpx viewer", input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 1000000, maxTokens: 64000 }],
    streamSimple(model) {
      // Registered only so a minimal pi starts fast; the overlay never runs the agent loop.
      const stream = createAssistantMessageEventStream();
      const message: any = { role: "assistant", content: [{ type: "text", text: "This pi only views acpx delegations." }], api: model.api, provider: model.provider, model: model.id,
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } }, stopReason: "stop", timestamp: Date.now() };
      queueMicrotask(() => { stream.push({ type: "start", partial: message }); stream.push({ type: "done", reason: "stop", message }); });
      return stream;
    },
  });

  pi.on("session_shutdown", () => {
    if (scanTimer) clearInterval(scanTimer);
    for (const d of roster.values()) unwatch(d);
  });

  pi.on("session_start", async (_e, ctx) => {
    if (ctx.mode !== "tui") return;
    const model = ctx.modelRegistry.find("acpx-viewer", "viewer");
    if (model) await pi.setModel(model);

    void ctx.ui.custom<void>((tui, theme, _kb, finish) => {
      // Inline code (paths, commands) gets its own colour so it doesn't read like emphasis.
      const md = { ...getMarkdownTheme(), code: (t: string) => theme.fg("syntaxVariable", t) };
      const mdCache = new WeakMap<object, { key: string; lines: string[] }>();
      let render = () => tui.requestRender();
      let bodyTop = 0, bodyHeight = 0, rosterW = 0;
      let lastRows: Row[] = [];

      const scan = () => {
        for (const rec of records()) {
          const d = roster.get(rec.id);
          // A closed session leaves the roster; the viewer lists this worktree's open sessions.
          if (d && rec.closed) { unwatch(d); roster.delete(rec.id); continue; }
          if (d && !watchers.has(d)) {
            // The watch ended (queue owner exit, transient error): attach again. The replay
            // rebuilds history, so start from a fresh model and keep only the view state.
            const fresh = new Delegation(rec);
            Object.assign(fresh, { overrides: d.overrides, scroll: d.scroll, follow: d.follow, cursor: d.cursor });
            roster.set(rec.id, watch(fresh, () => render()));
            continue;
          }
          if (d) { d.rec.lastPromptAt = rec.lastPromptAt; d.rec.lastUsedAt = rec.lastUsedAt; d.rec.title = rec.title; continue; }
          if (rec.closed) continue;
          roster.set(rec.id, watch(new Delegation(rec), () => render()));
        }
        render();
      };
      scan();
      scanTimer = setInterval(scan, 3000);
      const tick = setInterval(() => render(), 1000);

      // Running delegations first, then newest first.
      let filter = "", filtering = false; // `/` narrows the run list by summary, name, or route
      const matches = (d: Delegation) => !filter || `${summaryOf(d, 100)} ${d.rec.name} ${d.rec.shortcut}`.toLowerCase().includes(filter.toLowerCase());
      const computeList = () => [...roster.values()].filter(matches).sort((a, b) =>
        Number(b.status === "running") - Number(a.status === "running") || (b.started ?? 0) - (a.started ?? 0));
      // A render computes the list once; input handlers between renders compute it fresh.
      let frameList: Delegation[] | undefined;
      const list = () => frameList ?? computeList();
      const selectedIndex = () => Math.max(0, list().findIndex((d) => d.rec.id === selectedId));
      const focus = () => list()[selectedIndex()];
      let listScroll = 0;
      let listRows: Row[] = []; // the phone list as last rendered, for taps
      let sideScroll = 0;
      let placement: Placement = initialPlacement();
      let rosterRect = { x: 0, y: 0, w: 0, h: 0 };
      let rosterView: Row[] = [];
      let bodyX = 0;
      let rosterSize = initialRosterRows(); // "12" or "35%"
      const rowsFor = (avail: number) => {
        const n = rosterSize.endsWith("%") ? Math.floor((avail * parseFloat(rosterSize)) / 100) : parseInt(rosterSize, 10);
        return Math.max(2, Math.min(avail - 6, Number.isFinite(n) ? n : Math.floor(avail * 0.35)));
      };
      let lastAvail = 40;
      const resizeRoster = (delta: number) => {
        rosterSize = String(Math.max(2, rowsFor(lastAvail) + delta)); // switch to an absolute row count
        try { mkdirSync(STATE, { recursive: true }); writeFileSync(join(STATE, "roster-rows"), rosterSize + "\n"); } catch {}
      };
      const cyclePlacement = () => {
        placement = PLACEMENTS[(PLACEMENTS.indexOf(placement) + 1) % PLACEMENTS.length];
        sideScroll = 0;
        try { mkdirSync(STATE, { recursive: true }); writeFileSync(join(STATE, "placement"), placement + "\n"); } catch {}
      };

      // One glyph per run outcome; tool-level trouble lives in the meta line, not here.
      const mark = (s: string) =>
        s === "running" ? theme.fg("warning", "●") : s === "completed" ? theme.fg("success", "✓")
        : s === "failed" ? theme.fg("error", "✗") : s === "cancelled" ? theme.fg("muted", "■") : theme.fg("muted", "○");
      const statusColor = (s: string) => (s === "running" ? "warning" : s === "completed" ? "success" : s === "cancelled" || s === "failed" ? "error" : "muted");

      const markdown = (owner: object, text: string, width: number) => {
        const key = `${width}:${text.length}`;
        const hit = mdCache.get(owner);
        if (hit?.key === key) return hit.lines;
        const lines = new Markdown(text.trim(), 0, 0, md).render(width);
        mdCache.set(owner, { key, lines });
        return lines;
      };

      const expanded = (d: Delegation, key: string, auto: boolean) => d.overrides.get(key) ?? auto;

      const bodyRows = (d: Delegation, width: number): Row[] => {
        const rows: Row[] = [];
        const cwd = d.rec.cwd;
        const gut = narrow ? " " : "  ";
        const md = (owner: object, text: string) => markdown(owner, narrow ? shortenPaths(text, width - 1) : text, width - gut.length).map((l) => gut + l);
        // Show the last `max` wrapped rows; live output and thinking stay short.
        const indent = (lines: string[], color = "toolOutput", max = 14) => {
          const wrapped = lines.flatMap((l) => wrapTextWithAnsi(rel(l, cwd), width - 5));
          const shown = wrapped.length > max ? wrapped.slice(-max) : wrapped;
          if (wrapped.length > max) rows.push({ text: theme.fg("dim", `   │ … ${wrapped.length - max} earlier lines`) });
          for (const w of shown) rows.push({ text: theme.fg("dim", "   │ ") + theme.fg(color as any, w) });
        };
        d.turns.forEach((turn, ti) => {
          const latest = ti === d.turns.length - 1;
          const live = turn.status === "running";
          const tkey = `t${ti}`;
          const open = expanded(d, tkey, latest);
          const status = live ? theme.fg("warning", `running ${ago(Date.now() - d.startOf(turn))}`)
            : theme.fg(statusColor(turn.status) as any, statusWord(turn.status, turn.stopReason))
              + (d.endOf(turn) && d.endOf(turn)! - d.startOf(turn) > 1500 ? theme.fg("muted", ` · ${ago(d.endOf(turn)! - d.startOf(turn))}`) : "")
              + (turn.cost != null ? theme.fg("muted", ` · ${money(turn.cost)}`) : "") + (turn.tokens != null ? theme.fg("muted", ` · ${kTokens(turn.tokens)}`) : "");
          const promptFirst = turn.prompt.split("\n").find((l) => l.trim()) ?? "(prompt not retained)";
          const head = `${theme.fg("accent", open ? "▾" : "▸")} ${theme.bold(`turn ${ti + 1}`)}  ${status}  ${open ? "" : theme.fg("muted", promptFirst)}`;
          rows.push({ key: tkey, text: head });
          if (!open) return;
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
              const o = expanded(d, key, thinking);
              rows.push({ key, text: `${theme.fg("muted", o ? "▾" : "▸")} ${theme.fg("muted", theme.italic(thinking ? "thinking…" : "thought"))}  ${theme.fg("text", thoughtHeader(item.text))}` });
              if (o) indent(item.text.trim().split("\n").filter((l) => l.trim()).map((l) => l.replace(/\*\*/g, "")), "thinkingText", thinking ? 8 : 400);
            } else if (item.type === "tools") {
              const running = item.tools.some((t) => !done(t));
              const o = expanded(d, key, live && running);
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
                if (bad || denied) {
                  // The error is the point of a failed row: give it its own wrapped lines.
                  rows.push({ key, text: clip(head, width), problem: true });
                  if (sum && !o) {
                    const lines = wrapTextWithAnsi(rel(sum, cwd), width - 9);
                    lines.slice(0, 3).forEach((w, k) => rows.push({ text: "         " + theme.fg("error", k === 2 && lines.length > 3 ? clip(w + " …", width - 9) : w) }));
                  }
                } else rows.push({ key, text: head + (sum ? "  " + theme.fg("muted", sum) : "") });
                if (o) {
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
                rows.push({ key, text: clip(`${glyph} ${theme.fg("toolTitle", theme.bold(kl))} ${body}`, width - visibleWidth(tally) - 2) + (tally ? "  " + tally : "") });
                if (o) for (const t of item.tools) {
                  const g = !done(t) ? theme.fg(live ? "accent" : "warning", live ? "◌" : "?") : failed(t) ? theme.fg("error", "✗") : theme.fg("success", "✓");
                  rows.push({ text: `${theme.fg("dim", "   │ ")}${g} ${theme.fg("text", label(t, cwd))}  ${theme.fg("muted", done(t) || live ? summary(t, item.kind) : "unfinished")}` });
                }
              }
            } else {
              const n = item.count && item.count > 1 ? ` ×${item.count}` : "";
              const [verdict, ...rest] = item.text.split(": ");
              rows.push({ key, text: clip(theme.fg(item.tone, `! ${rest.length ? `${verdict}${n}: ${rest.join(": ")}` : item.text + n}`), width), problem: true });
            }
          });
          if (!live) rows.push({ text: "" });
        });
        if (!d.turns.length) rows.push({ text: theme.fg("muted", "attaching…") });
        return rows;
      };

      // `budget` is the characters the caller's slot can show (all its lines together).
      const summaryOf = (d: Delegation, budget: number) =>
        summaryFor(d.rec.id, d.firstPrompt, budget, render) ?? d.rec.title ?? (d.firstPrompt.split("\n").find((l) => l.trim()) || d.rec.name);

      const timing = (d: Delegation) => {
        const busy = d.busyMs();
        return d.status === "running" ? `${ago(Date.now() - d.startOf(d.turn))}` : busy > 1500 ? ago(busy) : "";
      };

      // Detail header fields in priority order; narrow screens keep the leading ones.
      const metaFields = (d: Delegation): string[] => {
        const acc = accessFor(d.rec.shortcut, render);
        const time = timing(d);
        return [
          theme.fg(statusColor(d.status) as any, statusWord(d.status, d.turn?.stopReason) + (time ? ` ${time}` : "")),
          theme.fg("text", d.rec.name),
          theme.fg("muted", d.rec.shortcut),
          theme.fg("muted", `started ${clock(d.started)}`),
          theme.fg("muted", `${d.toolCount} tool${d.toolCount === 1 ? "" : "s"}`),
          theme.fg("muted", money(d.cost) ? `cost ${money(d.cost)}` : acc === "included" ? "cost: in plan" : acc ? "cost: n/a" : ""),
          d.tokens != null ? theme.fg("muted", kTokens(d.tokens)!) : "",
          d.turns.length > 1 ? theme.fg("muted", `${d.turns.length} turns`) : "",
          theme.fg("muted", d.rec.model),
        ].filter((f) => visibleWidth(f) > 0);
      };

      // Fit fields into at most `lines` rows, dropping the lowest-priority ones first.
      const fitFields = (fields: string[], width: number, lines: number) => {
        const dot = theme.fg("dim", " · ");
        const out: string[] = [];
        let row = "";
        for (const f of fields) {
          const next = row ? row + dot + f : f;
          if (visibleWidth(next) <= width) { row = next; continue; }
          if (out.length + 1 >= lines) break;
          out.push(row);
          row = f;
        }
        if (row) out.push(row);
        return out;
      };

      // A finished run's outcome: "ok", or counts of what went wrong.
      // Glyph + count only: ✗ failed tool calls, ⊘ denied permissions, ! protocol errors. With
      // `aligned`, each count sits in a fixed 4-cell slot so the glyphs line up down a column.
      const outcome = (d: Delegation, aligned = false) => {
        if (d.status === "running") return theme.fg("text", d.activity());
        if (d.status !== "completed") return theme.fg("error", d.activity());
        const slot = (n: number, glyph: string, color: "error" | "warning") =>
          n ? theme.fg(color, `${glyph}${n}`) + (aligned ? " ".repeat(Math.max(1, 4 - `${glyph}${n}`.length)) : "") : aligned ? "    " : "";
        const bits = [slot(d.failedTools, "✗", "error"), slot(d.denied, "⊘", "warning"), slot(d.errors, "!", "error")];
        return aligned ? bits.join("") : bits.filter(Boolean).join(" ");
      };

      // Summary (wraps to two lines) with elapsed time, then start time · route · outcome.
      const card = (d: Delegation, i: number, width: number): Row[] => {
        const on = d === focus();
        const quiet = d.status === "running" && Date.now() - d.lastEvent > 15000 ? theme.fg("warning", ` · quiet ${ago(Date.now() - d.lastEvent)}`) : "";
        const time = timing(d);
        const room = width - 4 - (time ? visibleWidth(time) + 1 : 0);
        const wrapped = wrapTextWithAnsi(summaryOf(d, room * 2), room);
        const titles = wrapped.length > 2 ? [wrapped[0], clip(wrapped.slice(1).join(" "), room)] : wrapped;
        const lines = titles.map((t, k) => {
          const l = ` ${k ? " " : mark(d.status)} ${theme.bold(theme.fg("text", t))}`;
          return k ? l : l + " ".repeat(Math.max(1, width - visibleWidth(l) - visibleWidth(time))) + theme.fg("muted", time);
        });
        const dot = theme.fg("dim", " · ");
        // Missing fields are omitted, not padded, so the line always starts at the title's indent.
        const parts = [startLabel(i).trim() ? theme.fg("muted", startLabel(i)) : "", narrow ? "" : theme.fg("muted", d.rec.shortcut), outcome(d)].filter(Boolean);
        lines.push(`   ${parts.join(dot)}${quiet}`);
        return lines.map((l, k) => ({ key: `r${i}`, text: selectedLook(on, l, width, k === 0) }));
      };

      // The selected run is a filled bar while the run list has focus, and a left marker otherwise.
      const selectedLook = (on: boolean, line: string, width: number, first: boolean) => {
        if (!on) return pad(line, width);
        if (pane === "runs" || narrow) return theme.bg("selectedBg", keepBg(pad(line, width)));
        return pad(theme.fg("accent", "▌") + line.slice(1), width);
      };

      // Runs launched in the same minute form a batch: only the first shows its start time.
      const startLabel = (i: number) => {
        const ds = list(), t = clock(ds[i]?.started);
        return i > 0 && clock(ds[i - 1]?.started) === t ? " ".repeat(t.length) : t;
      };

      // One line per run, for the top and bottom strips.
      // Fixed columns: glyph · summary · start · duration · counts (or what a running run is doing).
      const OUTCOME_W = 18;
      const stripRow = (d: Delegation, i: number, width: number): Row => {
        const on = d === focus();
        const out = outcome(d, true);
        const tail = `${theme.fg("muted", startLabel(i))}  ${theme.fg("muted", (timing(d) || "–").padStart(6))}  ${pad(clip(out, OUTCOME_W), OUTCOME_W)}`;
        const room = width - visibleWidth(tail) - 6;
        const head = ` ${mark(d.status)} ${theme.bold(theme.fg("text", clip(summaryOf(d, room), room)))}`;
        return { key: `r${i}`, text: selectedLook(on, pad(head, width - visibleWidth(tail) - 1) + tail, width, true) };
      };

      // Running delegations first under their own heading, then finished ones, newest first.
      const rosterRows = (width: number, spaced = false): Row[] => {
        const ds = list();
        const running = ds.filter((d) => d.status === "running").length;
        const rows: Row[] = running ? [{ text: ` ${theme.bold(theme.fg("muted", "running"))} ${theme.fg("muted", String(running))}` }] : [];
        ds.forEach((d, i) => {
          if (i === running && i < ds.length) rows.push({ text: ` ${theme.bold(theme.fg("muted", "finished"))} ${theme.fg("muted", String(ds.length - running))}` });
          rows.push(...card(d, i, width));
          if (spaced && i < ds.length - 1) rows.push({ text: "" });
        });
        if (!roster.size) rows.push({ text: theme.fg("muted", ` no open acpx sessions${PREFIX ? ` named ${PREFIX}*` : ""}`) });
        return rows;
      };

      const scrollBy = (d: Delegation, n: number) => {
        const max = Math.max(0, lastRows.length - bodyHeight);
        d.scroll = Math.max(0, Math.min(max, d.scroll + n));
        d.follow = d.scroll >= max;
      };

      const moveCursor = (d: Delegation, dir: number) => {
        const keys = lastRows.map((r, i) => [r.key, i] as const).filter(([k]) => k && !k.startsWith("r"));
        if (!keys.length) return;
        let idx = keys.findIndex(([k]) => k === d.cursor);
        if (idx < 0) {
          // start from the first expandable row on screen
          idx = keys.findIndex(([, i]) => i >= d.scroll);
          if (dir < 0 && idx > 0) idx--;
          if (idx < 0) idx = keys.length - 1;
        } else idx = Math.max(0, Math.min(keys.length - 1, idx + dir));
        const [key, line] = keys[idx];
        d.cursor = key;
        if (line < d.scroll) d.scroll = line;
        else if (line >= d.scroll + bodyHeight) d.scroll = line - bodyHeight + 1;
        d.follow = false;
      };

      // Keyboard model (lazygit panes + magit sections): Tab moves focus between the run list and
      // the transcript; j/k move inside the focused pane; Enter drills in; Esc steps back out.
      let pane: "runs" | "transcript" = "runs";
      let help = false;

      // Jump the cursor to the next/previous row matching `want` (turn heads, problem rows).
      const jump = (d: Delegation, dir: number, want: (r: Row) => boolean) => {
        const at = Math.max(0, lastRows.findIndex((r) => r.key === d.cursor));
        const start = d.cursor ? at : dir > 0 ? -1 : lastRows.length; // no cursor: search the whole transcript
        for (let i = start + dir; i >= 0 && i < lastRows.length; i += dir) {
          const r = lastRows[i];
          if (r.key && want(r)) {
            d.cursor = r.key;
            d.follow = false;
            if (i < d.scroll || i >= d.scroll + bodyHeight) d.scroll = Math.max(0, i - Math.floor(bodyHeight / 3));
            return;
          }
        }
      };

      // magit-style visibility levels: 1 turns only, 2 default, 3 everything expanded.
      const level = (d: Delegation, n: 1 | 2 | 3) => {
        d.overrides.clear();
        if (n === 2) return;
        d.turns.forEach((t, ti) => {
          d.overrides.set(`t${ti}`, n === 3);
          if (n === 3) t.items.forEach((_, ii) => d.overrides.set(`t${ti}.${ii}`, true));
        });
      };

      const HELP: [string, string][] = [
        ["Tab", "switch focus: runs ⇄ transcript"],
        ["j / k  ↓ / ↑", "move in the focused pane"],
        ["[ / ]", "previous / next run, from anywhere"],
        ["Enter", "runs: open transcript · transcript: expand/collapse row"],
        ["n / p", "next / previous turn"],
        ["e / E", "next / previous problem (failed, denied, error)"],
        ["1 / 2 / 3", "show turns only / default / expand everything"],
        ["g / G", "top / follow live output"],
        ["Ctrl-d / Ctrl-u", "half page down / up"],
        ["/", "filter runs (Enter keeps, Esc clears)"],
        ["x", "cancel the selected run (asks y/n)"],
        ["L", "move the run list: top → bottom → left → right"],
        ["+ / -", "resize the run list (top/bottom)"],
        ["Esc", "step back: help → filter → transcript → runs"],
        ["q", "quit"],
        ["", ""],
        ["✗3 ⊘2", "3 failed tool calls · 2 denied permissions"],
      ];
      const helpBox = (width: number, height: number): { y: number; x: number; lines: string[] } => {
        const w = Math.min(width - 4, 84);
        const lines = [theme.bold(" keys"), "", ...HELP.map(([k, v]) => (k ? ` ${theme.fg("accent", k.padEnd(17))} ${theme.fg("text", v)}` : "")), "", theme.fg("muted", " Esc, q or ? closes")];
        const boxed = [theme.fg("borderMuted", "╭" + "─".repeat(w - 2) + "╮"), ...lines.map((l) => theme.fg("borderMuted", "│") + pad(l, w - 2) + theme.fg("borderMuted", "│")), theme.fg("borderMuted", "╰" + "─".repeat(w - 2) + "╯")];
        return { y: Math.max(0, Math.floor((height - boxed.length) / 2)), x: Math.max(0, Math.floor((width - w) / 2)), lines: boxed };
      };

      // Rows default to auto (active tool, live thought, latest turn); a toggle flips what is shown.
      const toggle = (d: Delegation, key: string) => d.overrides.set(key, !(d.overrides.get(key) ?? guessOpen(d, key)));

      const guessOpen = (d: Delegation, key: string) => {
        const [t, i] = key.slice(1).split(".").map(Number);
        const turn = d.turns[t];
        if (!turn) return false;
        const live = turn.status === "running";
        if (i === undefined) return t === d.turns.length - 1;
        const item = turn.items[i];
        if (item?.type === "thought") return live && i === turn.items.length - 1;
        if (item?.type === "tools") return live && item.tools.some((x) => !done(x));
        return false;
      };

      // Until the user picks a delegation, keep the view on a running one.
      let picked = false;
      const select = (i: number) => {
        picked = true;
        const ds = list();
        if (!ds.length) return;
        selectedId = ds[(i + ds.length) % ds.length].rec.id;
      };

      // Narrow layout is two screens: the roster list, then one delegation.
      let screen: "list" | "detail" = "list";
      let narrow = false;
      let cancelArmed = 0; // first cancel tap or `x`; confirmed by a second tap or `y` within 5s
      let buttons: { y: number; x0: number; x1: number; run: () => void }[] = [];
      const armed = () => Date.now() - cancelArmed < 5000;
      const askCancel = (d: Delegation) => { if (armed()) { cancelRun(d); cancelArmed = 0; } else cancelArmed = Date.now(); };

      const chip = (label: string, run: () => void, y: number, x: number, danger = false) => {
        const text = ` ${label} `;
        buttons.push({ y, x0: x, x1: x + visibleWidth(text), run });
        return theme.style(text, danger ? { fg: "text", bg: "toolErrorBg", bold: true } : { fg: "text", bg: "toolPendingBg" });
      };

      // Navigation on the left; cancel and quit on the right, apart from each other and from navigation.
      const toolbar = (y: number, d: Delegation | undefined, width: number) => {
        let x = 1, text = " ";
        const add = (label: string, run: () => void) => { text += chip(label, run, y, x) + " "; x = visibleWidth(text); };
        if (narrow && screen === "detail") add("‹ runs", () => { screen = "list"; });
        if (d && narrow && screen === "detail") {
          // The phone gets the same jumps the keyboard has, as buttons.
          add("✗ next", () => jump(d, 1, (r) => !!r.problem));
          add("turn ▸", () => jump(d, 1, (r) => !r.key!.includes(".")));
        }
        if (d && (screen !== "list" || !narrow) && !d.follow) add(narrow ? "↓ latest" : "↓ latest (G)", () => { d.follow = true; d.cursor = undefined; });
        const hint = narrow && screen === "list" ? theme.fg("muted", "tap a run to open")
          : narrow ? "" : armed() ? theme.fg("warning", " y cancels the run, any other key keeps it")
          : filtering ? theme.fg("muted", " type to filter · Enter keep · Esc clear")
          : theme.fg("muted", pane === "runs" ? " j/k run · Enter open · Tab transcript · / filter · ? keys" : " j/k row · Enter expand · n/p turn · e/E problem · [ ] run · Esc runs · ? keys");
        const right: [string, () => void, boolean][] = [];
        if (d?.status === "running" && (!narrow || screen === "detail")) right.push([armed() ? "cancel? tap again" : narrow ? "cancel" : "x cancel", () => askCancel(d), armed()]);
        if (!(narrow && screen === "detail")) right.push([narrow ? "quit" : "q quit", () => finish(), false]); // phones quit from the list
        const chips = right.map(([l]) => ` ${l} `);
        const rightW = chips.reduce((a, c) => a + visibleWidth(c), 0) + (chips.length - 1) * 3 + 1;
        const left = clip(text + hint, width - rightW - 1);
        let rx = width - rightW;
        let out = left + " ".repeat(Math.max(1, rx - visibleWidth(left)));
        right.forEach(([, run, danger], k) => {
          buttons.push({ y, x0: rx, x1: rx + visibleWidth(chips[k]), run });
          const isCancel = right[k][0].startsWith("cancel");
          out += theme.style(chips[k], danger ? { fg: "text", bg: "toolErrorBg", bold: true } : isCancel ? { fg: "error", bg: "toolPendingBg" } : { fg: "muted", bg: "toolPendingBg" });
          rx += visibleWidth(chips[k]) + 3;
          if (k < right.length - 1) out += "   ";
        });
        return out + " ";
      };

      // Scroll position, drawn into the rule under the header.
      const rule = (d: Delegation, width: number) => {
        const max = Math.max(0, lastRows.length - bodyHeight);
        const above = d.scroll > 0 ? `↑ ${d.scroll} above · ` : "";
        const where = max === 0 ? "fits" : above + (d.follow ? (d.status === "running" ? "live ●" : "end") : d.scroll === 0 ? "top · ↓ latest (G)" : `paused ${Math.round((d.scroll / max) * 100)}% · ↓ latest (G)`);
        const tag = ` ${where} `;
        // The focused pane names itself on its divider.
        const name = !narrow && pane === "transcript" ? theme.fg("accent", theme.bold(" transcript ")) : "";
        const line = pane === "transcript" && !narrow ? "border" : "borderMuted";
        return theme.fg(line as any, "──") + name + theme.fg(line as any, "─".repeat(Math.max(0, width - visibleWidth(tag) - visibleWidth(name) - 4))) + theme.fg(d.follow || max === 0 ? "muted" : "warning", tag) + theme.fg(line as any, "──");
      };

      const withHelp = (out: string[], width: number) => {
        frameList = undefined;
        if (!help) return out;
        const box = helpBox(width, out.length);
        box.lines.forEach((l, k) => {
          const y = box.y + k;
          if (y < out.length) out[y] = compositeTuiLine(out[y], l, box.x, visibleWidth(l), width);
        });
        return out;
      };

      return {
        render(width: number) {
          frameList = undefined;
          frameList = computeList();
          const height = Math.max(8, tui.terminal.rows);
          narrow = width < NARROW;
          buttons = [];
          if (!picked && focus()?.status !== "running") {
            const running = list().find((x) => x.settled && x.status === "running");
            if (running) selectedId = running.rec.id;
          }
          const d = focus();
          const out: string[] = [];

          if (narrow && screen === "list") {
            const rows = rosterRows(width, true);
            listRows = rows;
            lastRows = [];
            bodyTop = 0;
            bodyHeight = height - 2; // the last row before the buttons stays blank
            const first = rows.findIndex((r) => r.key === `r${selectedIndex()}`);
            if (first >= 0 && first < listScroll + 1) listScroll = Math.max(0, first - 1);
            if (first >= 0 && first + 3 > listScroll + bodyHeight) listScroll = first + 3 - bodyHeight;
            listScroll = Math.max(0, Math.min(listScroll, rows.length - bodyHeight));
            for (let y = 0; y < bodyHeight; y++) out.push(pad(rows[listScroll + y]?.text ?? "", width));
            // Cards that start at or below the last visible row are hidden; that row becomes the hint.
            const hidden = list().filter((_, i) => rows.findIndex((r) => r.key === `r${i}`) >= listScroll + bodyHeight - 1).length;
            if (hidden > 0) out[bodyHeight - 1] = pad(theme.fg("muted", `   ↓ ${hidden} more below`), width);
            out.push("");
            out.push(toolbar(height - 1, d, width));
            return withHelp(out, width);
          }

          // Wide layouts: the roster sits on one side (cards) or in a strip above/below (one line per run).
          // Phones always use the list/detail screens above.
          const side = !narrow && (placement === "left" || placement === "right");
          const toolbarY = height - 1;
          let detailX = 0, detailY = 0, detailW = width, detailH = toolbarY;
          if (narrow) {
            rosterW = 0;
            rosterRect = { x: 0, y: 0, w: 0, h: 0 }; // phone detail screen: no roster
          } else if (side) {
            rosterW = Math.min(80, Math.max(30, Math.floor(width * 0.42)));
            rosterRect = { x: placement === "left" ? 0 : width - rosterW, y: 0, w: rosterW, h: toolbarY };
            detailX = placement === "left" ? rosterW + 1 : 0;
            detailW = width - rosterW - 1;
          } else {
            lastAvail = toolbarY;
            const cap = rowsFor(toolbarY);
            const stripH = Math.max(2, Math.min(list().length + (cap >= 6 ? 1 : 0), cap)); // shrink to fit few runs
            rosterW = width;
            rosterRect = { x: 0, y: placement === "top" ? 0 : toolbarY - stripH, w: width, h: stripH };
            detailY = placement === "top" ? stripH + 1 : 0;
            detailH = toolbarY - stripH - 1;
          }

          // Roster rows, scrolled to keep the selected run visible, with ↑/↓ overflow hints.
          // A strip of six rows or more spends one on a heading; smaller strips are all runs.
          const all: Row[] = narrow ? [] : side ? rosterRows(rosterW) : [
            ...(rosterRect.h >= 6 || filter || filtering ? [{ text: ` ${theme.bold(theme.fg(pane === "runs" ? "accent" : "muted", "runs"))} ${theme.fg("muted", `${list().filter((x) => x.status === "running").length} running · ${list().length} shown`)}${filtering || filter ? theme.fg("warning", `  / ${filter}${filtering ? "▏" : ""}`) : ""}${theme.fg("muted", "   ✗ failed calls  ⊘ denied")}` }] : []),
            ...list().map((x, i) => stripRow(x, i, width)),
          ];
          const h = Math.max(1, rosterRect.h);
          const sel = all.map((r, k) => (r.key === `r${selectedIndex()}` ? k : -1)).filter((k) => k >= 0);
          if (sel.length && sel[0] < sideScroll + 1) sideScroll = Math.max(0, sel[0] - 1);
          if (sel.length && sel[sel.length - 1] >= sideScroll + h - 1) sideScroll = sel[sel.length - 1] - h + 2;
          sideScroll = Math.max(0, Math.min(sideScroll, Math.max(0, all.length - h)));
          rosterView = narrow ? [] : all.slice(sideScroll, sideScroll + h);
          const keyRow = (k: number) => Number(all[k]?.key?.slice(1) ?? -1);
          if (!narrow && sideScroll > 1) rosterView[0] = { text: theme.fg("muted", `   ↑ ${new Set(all.slice(0, sideScroll + 1).map((_, k) => keyRow(k)).filter((n) => n >= 0)).size} more`) };
          const hiddenBelow = new Set(all.slice(sideScroll + h - 1).map((_, k) => keyRow(sideScroll + h - 1 + k)).filter((n) => n >= 0)).size;
          if (!narrow && sideScroll + h < all.length && hiddenBelow) rosterView[h - 1] = { text: theme.fg("muted", `   ↓ ${hiddenBelow} more`) };

          // Detail block: header, metadata, scroll rule, transcript.
          // The phone shows the run's title here; desktop already shows it in the run list.
          const top = d
            ? narrow
              ? [...wrapTextWithAnsi(theme.bold(theme.fg("text", summaryOf(d, (detailW - 3) * 2))), detailW - 3).slice(0, 2).map((l, k) => pad(` ${k ? " " : mark(d.status)} ${l}`, detailW)), ...fitFields(metaFields(d), detailW - 3, 2).map((l) => pad(`   ${l}`, detailW)), ""]
              : [...fitFields(metaFields(d), detailW - 3, 1).map((l) => pad(` ${mark(d.status)} ${l}`, detailW)), ""]
            : [pad(theme.fg("muted", " waiting for acpx delegations"), detailW)];
          bodyTop = detailY + top.length;
          bodyHeight = detailH - top.length;
          bodyX = detailX;
          lastRows = d ? bodyRows(d, detailW - 1) : [];
          if (d) {
            const max = Math.max(0, lastRows.length - bodyHeight);
            if (d.follow) {
              d.scroll = max;
              // Start the view at a block boundary rather than mid-paragraph, if that costs ≤ 3 rows.
              for (let k = 0; k <= 3 && d.scroll + k < lastRows.length; k++) {
                const at = d.scroll + k;
                if (at === 0 || lastRows[at].key || !lastRows[at - 1].text.trim()) { d.scroll = at; break; }
              }
            }
            d.scroll = Math.min(d.scroll, Math.max(max, d.follow ? d.scroll : 0));
            top[top.length - 1] = rule(d, detailW);
          }
          const detail: string[] = [...top];
          for (let y = 0; y < bodyHeight; y++) {
            const row = d ? lastRows[d.scroll + y] : undefined;
            let text = row?.text ?? "";
            if (row?.key && row.key === d?.cursor && (pane === "transcript" || narrow)) text = theme.bg("selectedBg", keepBg(pad(text, detailW - 1)));
            detail.push(" " + pad(text, detailW - 1));
          }

          const sepV = theme.fg("borderMuted", "│");
          for (let y = 0; y < toolbarY; y++) {
            if (narrow) out.push(y === toolbarY - 1 ? "" : pad(detail[y] ?? "", width));
            else if (side) {
              const r = pad(rosterView[y]?.text ?? "", rosterW);
              const dl = pad(detail[y] ?? "", detailW);
              out.push(placement === "left" ? r + sepV + dl : dl + sepV + r);
            } else if (y >= rosterRect.y && y < rosterRect.y + rosterRect.h) out.push(pad(rosterView[y - rosterRect.y]?.text ?? "", width));
            else if (y >= detailY && y < detailY + detailH) out.push(pad(detail[y - detailY] ?? "", width));
            else {
              // Strip/transcript separator: names the run list when it has focus.
              const label = pane === "runs" ? theme.fg("accent", theme.bold(` runs ${placement === "top" ? "▲" : "▼"} `)) : "";
              out.push(theme.fg(pane === "runs" ? "border" : "borderMuted", "──") + label + theme.fg(pane === "runs" ? "border" : "borderMuted", "─".repeat(Math.max(0, width - 2 - visibleWidth(label)))));
            }
          }
          out.push(toolbar(toolbarY, d, width));
          return withHelp(out, width);
        },
        handleInput(data: string) {
          const d = focus();
          const done = () => tui.requestRender();
          if (help) { if (matchesKey(data, "escape") || matchesKey(data, "q") || matchesKey(data, "?")) help = false; return done(); }
          if (armed()) { if (d && matchesKey(data, "y")) askCancel(d); else cancelArmed = 0; return done(); }
          if (filtering) {
            if (matchesKey(data, "enter")) filtering = false;
            else if (matchesKey(data, "escape")) { filtering = false; filter = ""; }
            else if (matchesKey(data, "backspace")) filter = filter.slice(0, -1);
            else if (data.length === 1 && data >= " ") filter += data;
            return done();
          }
          const key = (...ks: string[]) => ks.some((k) => matchesKey(data, k as any));
          if (key("q")) return finish();
          if (key("?")) { help = true; return done(); }
          if (key("/")) { filtering = true; pane = "runs"; return done(); }
          if (key("[")) { select(selectedIndex() - 1); return done(); }
          if (key("]")) { select(selectedIndex() + 1); return done(); }
          if (key("x") && d?.status === "running") { askCancel(d); return done(); }
          if (!narrow && key("shift+l", "L")) { cyclePlacement(); return done(); }
          if (!narrow && (placement === "top" || placement === "bottom") && key("+", "=", "-")) { resizeRoster(key("-") ? -1 : 1); return done(); }

          // Phones: the list screen is the run pane, the detail screen is the transcript pane.
          const inRuns = narrow ? screen === "list" : pane === "runs";
          if (key("tab", "shift+tab")) {
            if (narrow) screen = screen === "list" ? "detail" : "list";
            else pane = pane === "runs" ? "transcript" : "runs";
            return done();
          }
          if (key("escape")) {
            if (filter) filter = "";
            else if (!inRuns) { if (d?.cursor) d.cursor = undefined; else if (narrow) screen = "list"; else pane = "runs"; }
            return done();
          }
          if (inRuns) {
            if (key("j", "down")) select(selectedIndex() + 1);
            else if (key("k", "up")) select(selectedIndex() - 1);
            else if (key("g", "home")) select(0);
            else if (key("shift+g", "G", "end")) select(list().length - 1);
            else if (key("enter", "l", "right")) { if (narrow) screen = "detail"; else pane = "transcript"; }
            return done();
          }
          if (!d) return done();
          if (key("j", "down")) moveCursor(d, 1);
          else if (key("k", "up")) moveCursor(d, -1);
          else if (key("enter", "space", "l", "right")) { if (d.cursor) { d.follow = false; toggle(d, d.cursor); } else moveCursor(d, 1); }
          else if (key("h", "left")) {
            // magit `^`: collapse the row, or climb to its turn
            if (d.cursor?.includes(".") && (d.overrides.get(d.cursor) ?? guessOpen(d, d.cursor))) toggle(d, d.cursor);
            else if (d.cursor?.includes(".")) d.cursor = d.cursor.split(".")[0];
            else if (narrow) screen = "list"; else pane = "runs";
          }
          else if (key("n")) jump(d, 1, (r) => !r.key!.includes("."));
          else if (key("p")) jump(d, -1, (r) => !r.key!.includes("."));
          else if (key("e")) jump(d, 1, (r) => !!r.problem);
          else if (key("shift+e", "E")) jump(d, -1, (r) => !!r.problem);
          else if (key("1")) level(d, 1);
          else if (key("2")) level(d, 2);
          else if (key("3")) level(d, 3);
          else if (key("pageDown", "ctrl+d")) scrollBy(d, Math.floor(bodyHeight / 2));
          else if (key("pageUp", "ctrl+u")) scrollBy(d, -Math.floor(bodyHeight / 2));
          else if (key("g", "home")) { d.scroll = 0; d.follow = false; d.cursor = undefined; }
          else if (key("shift+g", "G", "end")) { d.follow = true; d.cursor = undefined; }
          return done();
        },
        handleMouse(ev: any) {
          const inRoster = (e: any) => e.x >= rosterRect.x && e.x < rosterRect.x + rosterRect.w && e.y >= rosterRect.y && e.y < rosterRect.y + rosterRect.h;
          const d = focus();
          if (ev.type === "wheel") {
            if (narrow && screen === "list") listScroll = Math.max(0, listScroll + (ev.wheelDelta ?? 0) * 2);
            else if (!narrow && inRoster(ev)) sideScroll = Math.max(0, sideScroll + (ev.wheelDelta ?? 0) * 2);
            else if (d) scrollBy(d, (ev.wheelDelta ?? 0) * 3);
            return { handled: true };
          }
          if (ev.type !== "click" || ev.button !== "left") return { handled: true, render: false };
          const button = buttons.find((b) => b.y === ev.y && ev.x >= b.x0 && ev.x < b.x1);
          if (button) { button.run(); return { handled: true }; }
          if (narrow && screen === "list") {
            const row = listRows[listScroll + ev.y];
            if (row?.key) { select(Number(row.key.slice(1))); screen = "detail"; }
          } else if (!narrow && inRoster(ev)) {
            pane = "runs";
            const row = rosterView[ev.y - rosterRect.y];
            if (row?.key) select(Number(row.key.slice(1)));
          } else if (d && ev.y >= bodyTop && ev.y < bodyTop + bodyHeight && ev.x >= bodyX) {
            const row = lastRows[d.scroll + ev.y - bodyTop];
            pane = "transcript";
            if (row?.key) { d.cursor = row.key; d.follow = false; toggle(d, row.key); }
          }
          return { handled: true };
        },
        invalidate() {},
        dispose() { clearInterval(tick); },
      } as any;
    }, { overlay: true, overlayOptions: { width: "100%", maxHeight: "100%", anchor: "top-left" } }).then(() => ctx.shutdown());
  });
}
