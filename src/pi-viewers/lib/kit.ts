// The chrome both pi viewers share: the pi bootstrap, a list beside (or above, below, or instead
// of) the selected item's transcript, a phone layout, zoom and pins, the transcript block with its
// scrollbar and search, help, the hint bar, filter and jump modes, and one keymap. A viewer hands
// the Shell a Spec: its items, how to draw its list and detail heads, and its own keys. What needs
// no pi-tui lives in core.ts so Node can test it.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { Markdown, matchesKey, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { join } from "node:path";
import {
  autoPick, BAD, DENSITIES, Flash, HELP_BASE, Hits, inRect, Jump, keepBg, layout, LIVE, matches, moveCursor, NARROW, newView, plain, Pointer, PLACEMENTS, Prefs,
  scrollBy, setOpen, settle, stateRoot, stepRows, TextEntry, toggleRow,
  type Density, type Frame, type KeyTest, type Mouse, type Placement, type Rect, type Row, type State, type View,
} from "./core.ts";

export * from "./core.ts";
export { visibleWidth, wrapTextWithAnsi };

export const FOLLOW_IDLE_MS = 30_000; // auto-follow leaves an item only after it finishes or idles this long

// pi's Theme, structurally: the viewers only call these.
export interface Theme {
  fg(color: any, text: string): string;
  bg(color: any, text: string): string;
  bold(text: string): string;
  italic(text: string): string;
  style(text: string, options: any): string;
}

// ---------- text ----------
export const pad = (s: string, w: number) => truncateToWidth(s, Math.max(0, w), "…", true);
export const clip = (s: string, w: number) => truncateToWidth(s, Math.max(0, w), "…");
// Cut from the left so the file name at the end survives.
export function leftClip(text: string, w: number) {
  if (visibleWidth(text) <= w) return text;
  return "…" + text.slice(text.length - Math.max(1, w - 1));
}
// On a phone, abbreviate directories in long paths so `file:line` never wraps mid-token.
export function shortenPaths(text: string, w: number) {
  return text.replace(/(?:[\w.~-]+\/)+[\w.-]+(?::\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)?/g, (m) => (m.length <= w - 6 ? m : "…/" + m.split("/").pop()));
}
// Fit fields into at most `lines` rows, dropping the lowest-priority (last) ones first.
export function fitFields(fields: string[], width: number, lines: number, dot: string) {
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
}

// ---------- the spec a viewer supplies ----------
export interface ListRow { text: string; id?: string; group?: string; lead?: string; problem?: boolean } // lead: two columns a jump letter may replace
export interface ListHeader { text: string; hits?: { x0: number; x1: number; run: (ev: Mouse) => void }[] } // hits are relative to the list's left edge
export interface ListOut { header?: (string | ListHeader)[]; rows: ListRow[] }
export type GroupOp = "toggle" | "open" | "close";
export interface Hint { key: string; label: string; run: () => void; danger?: boolean; narrow?: boolean } // narrow: shown as a phone chip too

export interface Spec {
  listName: string; // "runs", "agents": names the list pane on its divider and the phone's back chip
  title?(): string; // the zoom breadcrumb's root
  ids(): string[]; // items in list order, after the viewer applied shell.filter
  has(id: string): boolean; // whether the item still exists, filtered or not
  state(id: string): State;
  problem?(id: string): boolean;
  lastAct?(id: string): number;
  view(id: string): View;
  label(id: string): string;
  groupOf?(id: string): string;
  group?(name: string, op: GroupOp): void;
  rows(id: string, w: number): Row[];
  top?(w: number): string[]; // rows above the panes: header, tabs; the viewer registers their hits
  list(w: number): ListOut;
  detailHead(id: string, w: number, x: number, y: number): string[]; // above the transcript; the shell draws the rule under it
  tail?(r: Rect): string[];
  tailRows?(bodyH: number): number; // how tall the tail wants to be; 0 or absent closes it
  modal?(w: number, h: number, y: number): string[] | undefined; // replaces the panes (a picker); the viewer consumes keys while it is open
  key?(data: string, key: KeyTest): boolean; // first chance at a key; true consumes it
  help?: [string, string][];
  hints?(): Hint[];
  autoSize?(side: boolean, W: number, H: number): number; // automatic list size; 0 keeps the kit default
  empty?: string; // detail text while nothing is selected
  tick?(): void; // refresh models before each timed render
  tickMs?: number;
  now?(): number; // the frame clock (replays)
  onSelect?(id: string): void;
  dispose?(): void;
}

const GLYPH: Record<State, [string, string]> = {
  running: ["warning", "●"], starting: ["warning", "●"], done: ["success", "✓"], failed: ["error", "✗"], stalled: ["error", "◐"],
  cancelled: ["muted", "■"], cached: ["muted", "◇"], abandoned: ["dim", "⊘"], detached: ["muted", "○"], waiting: ["muted", "○"],
};
export const stateColor = (s: string) =>
  s === "running" || s === "starting" ? "warning" : s === "done" || s === "cached" ? "success" : BAD.has(s as State) || s === "cancelled" ? "error" : s === "abandoned" ? "dim" : "muted";

export interface ViewerDefaults { placement?: Placement } // what a viewer starts with before the user saves a preference

type Action =
  | "quit" | "help" | "back" | "zoom" | "pin" | "follow" | "top" | "auto" | "nextErr" | "prevErr" | "nextMatch" | "prevMatch" | "search" | "filter"
  | "density" | "jump" | "expandAll" | "collapseAll" | "resetFolds" | "place" | "wider" | "narrower" | "nextSection" | "prevSection" | "openDetail" | "toList" | "fold";

export class Shell {
  spec!: Spec;
  readonly theme: Theme;
  readonly prefs: Prefs;
  readonly hits = new Hits();
  readonly pointer = new Pointer();
  readonly jump = new Jump();
  readonly flash = new Flash();
  readonly filterEntry = new TextEntry();
  readonly searchEntry = new TextEntry();
  W = 120; H = 40;
  t = Date.now(); // the frame clock; every item in a frame is judged at one instant
  frame?: Frame;
  narrow = false;
  screen: "list" | "detail" = "list";
  focus: "list" | "detail" = "list";
  zoom = false;
  help = false;
  helpScroll = 0;
  placement: Placement;
  sizeSide: number;
  sizeStrip: number;
  density: number;
  auto = true; // follow the active item until the user picks one
  selectedId?: string;
  cursorGroup?: string; // the list cursor rests on a group row instead of an item
  pins: string[] = [];
  listScroll = 0;
  reveal = true; // scroll the list to the selection on the next frame (only after it changes)
  private rowsOf = new Map<string, Row[]>(); // transcripts as last rendered, for the keys between frames
  private bodyH = 20;
  private tick?: ReturnType<typeof setInterval>;
  private mdCache = new WeakMap<object, { key: string; lines: string[] }>();
  private mdTheme: any;

  constructor(readonly id: string, private tui: any, theme: Theme, private finish: () => void, defaults: ViewerDefaults = {}) {
    this.theme = theme;
    this.prefs = new Prefs(join(stateRoot(), id));
    const place = this.prefs.get("placement", defaults.placement ?? "left") as Placement;
    this.placement = (PLACEMENTS as readonly string[]).includes(place) ? place : "left";
    this.sizeSide = Number(this.prefs.get("size-side", "0")) || 0;
    this.sizeStrip = Number(this.prefs.get("size-strip", "0")) || 0;
    this.density = Math.max(0, DENSITIES.indexOf(this.prefs.get("density", "normal") as Density));
    // Inline code (paths, commands) gets its own colour so it doesn't read like emphasis.
    this.mdTheme = { ...getMarkdownTheme(), code: (t: string) => theme.fg("syntaxVariable", t) };
  }

  start() {
    this.tick = setInterval(() => { this.spec.tick?.(); this.tui.requestRender(); }, this.spec.tickMs ?? 1000);
  }
  dispose() { if (this.tick) clearInterval(this.tick); this.spec?.dispose?.(); }
  render() { this.tui.requestRender(); }
  say(m: string) { this.flash.say(m); }
  get filter() { return this.filterEntry.value; }
  get search() { return this.searchEntry.value; }
  get dens(): Density { return DENSITIES[this.density]; }
  get side() { return this.placement === "left" || this.placement === "right"; }
  get inDetail() { return this.zoom || (this.narrow ? this.screen === "detail" : this.focus === "detail"); }
  live(id: string) { return LIVE.has(this.spec.state(id)); }
  isMatch = (r: Row) => !!this.search && matches(this.search, r.hay ?? plain(r.text));
  // The selection and its view, or nothing once the item has left the viewer's model.
  get sel() { return this.selectedId && this.spec.has(this.selectedId) ? this.selectedId : undefined; }
  get view() { const a = this.sel; return a ? this.spec.view(a) : undefined; }

  // ---------- palette ----------
  glyph(s: State) { const [c, g] = GLYPH[s] ?? GLYPH.waiting; return this.theme.fg(c, g); }
  pill(s: string) {
    const bg = s === "running" || s === "starting" ? "toolPendingBg" : s === "done" || s === "cached" || s === "completed" ? "toolSuccessBg" : BAD.has(s as State) || s === "cancelled" || s === "killed" ? "toolErrorBg" : "customMessageBg";
    return this.theme.bg(bg, this.theme.fg(stateColor(s), this.theme.bold(` ${s} `)));
  }
  hl(text: string, w: number, selected: boolean, hovered: boolean) {
    return selected ? this.theme.bg("selectedBg", keepBg(pad(text, w))) : hovered ? this.theme.bg("userMessageBg", keepBg(pad(text, w))) : pad(text, w);
  }
  chip(label: string, danger = false, muted = false) {
    return this.theme.style(` ${label} `, danger ? { fg: "text", bg: "toolErrorBg", bold: true } : muted ? { fg: "muted", bg: "toolPendingBg" } : { fg: "text", bg: "toolPendingBg" });
  }
  md(owner: object, text: string, width: number) {
    const key = `${width}:${text.length}`;
    const hit = this.mdCache.get(owner);
    if (hit?.key === key) return hit.lines;
    const lines = new Markdown(text.trim(), 0, 0, this.mdTheme).render(Math.max(10, width));
    this.mdCache.set(owner, { key, lines });
    return lines;
  }
  // Quoted output under a row: the last `max` wrapped lines behind a bar.
  indent(rows: Row[], lines: string[], width: number, color = "toolOutput", max = 12) {
    const wrapped = lines.flatMap((l) => wrapTextWithAnsi(l, Math.max(10, width - 5)));
    const shown = wrapped.length > max ? wrapped.slice(-max) : wrapped;
    if (wrapped.length > max) rows.push({ text: this.theme.fg("dim", `   ┊ … ${wrapped.length - max} earlier lines`) });
    for (const l of shown) rows.push({ text: this.theme.fg("borderMuted", "   │ ") + this.theme.fg(color, l) });
  }

  // ---------- selection ----------
  pick(id?: string) {
    if (!id) return;
    if (id !== this.selectedId) this.reveal = true;
    this.selectedId = id; this.cursorGroup = undefined; this.auto = false;
    this.spec.onSelect?.(id);
  }
  step(dir: number) {
    const ids = this.spec.ids();
    if (!ids.length) return;
    const i = ids.indexOf(this.selectedId ?? "");
    this.pick(ids[((i < 0 ? (dir > 0 ? -1 : 0) : i) + dir + ids.length) % ids.length]);
  }
  private autoFollow() {
    // An item that left the model (a closed session) releases the selection and its pins.
    if (this.selectedId && !this.spec.has(this.selectedId)) { this.selectedId = undefined; this.auto = true; }
    this.pins = this.pins.filter((id) => this.spec.has(id));
    if (!this.auto) return;
    const ids = this.spec.ids();
    const cur = this.selectedId && ids.includes(this.selectedId) ? this.selectedId : undefined;
    const next = autoPick(ids, cur, (id) => this.live(id), (id) => this.spec.lastAct?.(id) ?? 0, FOLLOW_IDLE_MS, this.t);
    if (next && next !== this.selectedId) { this.selectedId = next; this.reveal = true; }
  }
  private detailIds() {
    return [...new Set([this.sel, ...this.pins])].filter((id): id is string => !!id && this.spec.has(id)).slice(0, 3);
  }
  rowsFor(id: string) { return this.rowsOf.get(id) ?? this.spec.rows(id, 80); }

  // ---------- actions (keys, clicks and hints share these) ----------
  act(name: Action) {
    const a = this.sel, spec = this.spec, v = this.view;
    switch (name) {
      case "quit": this.finish(); break;
      case "help": this.help = !this.help; this.helpScroll = 0; break;
      case "back":
        if (this.searchEntry.value) this.searchEntry.clear();
        else if (this.zoom) this.zoom = false;
        else if (this.filterEntry.value) { this.filterEntry.clear(); this.reveal = true; }
        else if (this.inDetail) { if (v?.cursor) v.cursor = undefined; else if (this.narrow) this.screen = "list"; else this.focus = "list"; }
        else if (this.cursorGroup != null) this.cursorGroup = undefined;
        break;
      case "zoom": if (a) { this.zoom = !this.zoom; this.focus = "detail"; this.auto = false; } break;
      case "openDetail": if (a) { if (this.cursorGroup != null) { spec.group?.(this.cursorGroup, "toggle"); break; } if (this.narrow) this.screen = "detail"; else this.focus = "detail"; this.auto = false; } break;
      case "toList": this.zoom = false; if (this.narrow) this.screen = "list"; else this.focus = "list"; break;
      case "fold": {
        if (this.cursorGroup != null) { spec.group?.(this.cursorGroup, "toggle"); break; }
        // Folding from an item folds its group and leaves the cursor on that group row.
        const g = a && spec.groupOf?.(a);
        if (g != null && spec.group) { spec.group(g, "close"); this.cursorGroup = g; this.reveal = true; }
        break;
      }
      case "pin": { if (!a) break; const i = this.pins.indexOf(a); if (i >= 0) this.pins.splice(i, 1); else { this.pins.push(a); if (this.pins.length > 2) this.pins.shift(); } this.say(i >= 0 ? `unpinned ${spec.label(a)}` : `pinned ${spec.label(a)}`); break; }
      case "follow": if (v) { v.follow = true; v.cursor = undefined; } break;
      case "top": if (v) { v.follow = false; v.scroll = 0; v.cursor = undefined; this.auto = false; } break;
      case "auto": this.auto = true; this.say("following the active item"); break;
      case "nextErr": case "prevErr": {
        const d = name === "nextErr" ? 1 : -1;
        if (this.inDetail && a && v) { if (!stepRows(v, this.rowsFor(a), d, (r) => !!r.problem, this.bodyH)) this.say("no problems in this transcript"); break; }
        const bad = spec.ids().filter((id) => BAD.has(spec.state(id)) || spec.problem?.(id));
        if (!bad.length) { this.say("no failed items"); break; }
        const i = bad.indexOf(a ?? "");
        this.pick(bad[((i < 0 ? (d > 0 ? -1 : 0) : i) + d + bad.length) % bad.length]);
        break;
      }
      case "nextMatch": case "prevMatch": {
        if (!a || !v || !this.search) break;
        const hit = stepRows(v, this.rowsFor(a), name === "nextMatch" ? 1 : -1, this.isMatch, this.bodyH);
        if (!hit) { this.say(`no match for "${this.search}"`); break; }
        // A match hidden inside a folded row opens it.
        if (!matches(this.search, plain(hit.row.text))) v.overrides.set(hit.row.key!, true);
        this.auto = false;
        this.say(`match ${hit.n}/${hit.of}`);
        break;
      }
      case "nextSection": case "prevSection": {
        const d = name === "nextSection" ? 1 : -1;
        if (this.inDetail && a && v) { if (!stepRows(v, this.rowsFor(a), d, (r) => !!r.head, this.bodyH)) this.say("no sections in this transcript"); break; }
        this.listStep(d, true);
        break;
      }
      case "search": if (a) { this.searchEntry.start(); if (!this.narrow) this.focus = "detail"; this.auto = false; } break;
      case "filter": this.filterEntry.start(true); break;
      case "density": this.density = (this.density + 1) % DENSITIES.length; this.prefs.set("density", this.dens); break;
      case "jump": this.jump.start(); break;
      case "expandAll": case "collapseAll": case "resetFolds": if (a && v) setOpen(v, this.rowsFor(a), name === "expandAll" ? true : name === "collapseAll" ? false : undefined); break;
      case "place": this.placement = PLACEMENTS[(PLACEMENTS.indexOf(this.placement) + 1) % PLACEMENTS.length]; this.listScroll = 0; this.reveal = true; this.prefs.set("placement", this.placement); break;
      case "wider": case "narrower": {
        const d = name === "wider" ? 1 : -1;
        if (this.side) { this.sizeSide = Math.max(28, Math.min(this.W - 40, (this.frame?.list?.w ?? 40) + 4 * d)); this.prefs.set("size-side", String(this.sizeSide)); }
        else { this.sizeStrip = Math.max(2, (this.frame?.list?.h ?? 8) + d); this.prefs.set("size-strip", String(this.sizeStrip)); }
        break;
      }
    }
  }
  resizeTo(cols: number, rows: number) {
    if (this.side) { this.sizeSide = Math.max(28, Math.min(this.W - 40, cols)); this.prefs.set("size-side", String(this.sizeSide)); }
    else { this.sizeStrip = Math.max(2, rows); this.prefs.set("size-strip", String(this.sizeStrip)); }
  }

  private lastList: ListOut = { rows: [] };
  private listStep(dir: number, groupsOnly = false) {
    const rows = this.lastList.rows;
    const nav = rows.map((r, i) => ({ r, i })).filter((x) => (x.r.group != null && !x.r.id) || (!groupsOnly && x.r.id && rows.findIndex((y) => y.id === x.r.id) === x.i));
    if (!nav.length) return;
    let i = this.cursorGroup != null ? nav.findIndex((x) => x.r.group === this.cursorGroup && !x.r.id) : nav.findIndex((x) => x.r.id === this.selectedId);
    if (i < 0 && this.cursorGroup == null && this.selectedId) {
      // The selection sits under a folded group: continue from that group's row.
      const g = this.spec.groupOf?.(this.selectedId);
      i = nav.findIndex((x) => x.r.group === g && !x.r.id);
    }
    i = Math.max(0, Math.min(nav.length - 1, (i < 0 ? (dir > 0 ? -1 : nav.length) : i) + dir));
    const e = nav[i].r;
    if (e.id) this.pick(e.id); else { this.cursorGroup = e.group; this.auto = false; this.reveal = true; }
  }

  // ---------- drawing ----------
  private draw(width: number): string[] {
    const { theme, spec, hits } = this;
    hits.reset(); this.jump.frame();
    this.W = width; this.H = Math.max(10, this.tui.terminal.rows);
    this.t = spec.now?.() ?? Date.now();
    this.narrow = width < NARROW;
    this.autoFollow();
    const top = spec.top?.(width) ?? [];
    const out: string[] = [...top];
    const bodyY = top.length, bodyH = this.H - top.length - 1;
    if (this.help) {
      out.push(...this.drawHelp(width, bodyY, bodyH));
    } else {
      const modal = spec.modal?.(width, bodyH, bodyY);
      if (modal) out.push(...modal.slice(0, bodyH));
      else {
        // A strip is sized by what it has to show, so the list is built before the layout when it is one.
        const pre = this.narrow || this.side || this.zoom ? undefined : spec.list(width);
        const auto = spec.autoSize?.(this.side, width, this.H) ?? 0;
        const size = this.side ? this.sizeSide || auto : this.sizeStrip || auto;
        const f = this.frame = layout({
          W: width, H: this.H, top: top.length, bottom: 1, placement: this.placement, size, narrow: this.narrow, screen: this.screen, zoom: this.zoom,
          tailRows: spec.tailRows?.(bodyH) ?? 0, listRows: pre ? pre.rows.length + (pre.header?.length ?? 0) : undefined,
        });
        const rows: string[][] = Array.from({ length: bodyH }, () => []);
        const paint = (r: Rect | undefined, lines: string[]) => { if (r) for (let y = 0; y < r.h; y++) rows[r.y - bodyY + y]?.push(pad(lines[y] ?? "", r.w)); };
        const segs: [Rect | undefined, () => string[]][] = [];
        if (f.list) segs.push([f.list, () => this.drawList(f.list!, pre)]);
        if (f.sep) segs.push([f.sep, () => this.drawSep(f.sep!, f.side)]);
        if (f.detail) segs.push([f.detail, () => this.drawDetail(f.detail!)]);
        if (f.tail && spec.tail) segs.push([f.tail, () => spec.tail!(f.tail!)]);
        const drawn = segs.map(([r, fn]) => [r, fn()] as [Rect, string[]]);
        drawn.sort((a, b) => a[0].x - b[0].x || a[0].y - b[0].y);
        for (const [r, lines] of drawn) paint(r, lines);
        for (const r of rows) out.push(r.join(""));
      }
    }
    while (out.length < this.H - 1) out.push("");
    out.length = this.H - 1;
    out.push(this.hintBar(this.H - 1, width));
    this.reveal = false;
    return out.map((l) => pad(l, width));
  }

  private drawList(r: Rect, pre?: ListOut): string[] {
    const { theme, spec, hits } = this;
    const out = this.lastList = pre ?? spec.list(r.w);
    const header = out.header ?? [], rows = out.rows, h = r.h - header.length, y0 = r.y + header.length;
    const isSel = (row?: ListRow) => !!row && (this.cursorGroup != null ? row.group === this.cursorGroup && !row.id : !!row.id && row.id === this.selectedId);
    const idx = rows.map((row, k) => (isSel(row) ? k : -1)).filter((k) => k >= 0);
    if (this.reveal && idx.length) {
      if (idx[0] < this.listScroll + 1) this.listScroll = Math.max(0, idx[0] - 1);
      if (idx[idx.length - 1] >= this.listScroll + h - 1) this.listScroll = idx[idx.length - 1] - h + 2;
    }
    this.listScroll = Math.max(0, Math.min(this.listScroll, Math.max(0, rows.length - h)));
    const top = this.listScroll;
    hits.add({ x0: r.x, x1: r.x + r.w, y0, y1: r.y + r.h,
      click: (ev) => {
        const row = rows[top + ev.y - y0];
        this.zoom = false; if (!this.narrow) this.focus = "list";
        if (!row) return;
        if (row.id) { this.pick(row.id); if (this.narrow) this.screen = "detail"; else if (ev.clickCount && ev.clickCount >= 2) this.act("zoom"); }
        else if (row.group != null) { this.cursorGroup = row.group; this.auto = false; if (!ev.clickCount || ev.clickCount < 2) spec.group?.(row.group, "toggle"); }
      },
      right: (ev) => { const row = rows[top + ev.y - y0]; if (row?.id) { this.pick(row.id); this.act("pin"); } },
      wheel: (d) => { this.listScroll = Math.max(0, this.listScroll + d * 2); } });
    const lines = header.map((l, i) => {
      if (typeof l === "string") return pad(l, r.w);
      for (const hh of l.hits ?? []) hits.row(r.x + hh.x0, r.x + hh.x1, r.y + i, { click: hh.run });
      return pad(l.text, r.w);
    });
    const focused = this.focus === "list" || this.narrow;
    // Jump mode replaces a row's two lead columns with its letter.
    const tag = (id: string) => { const k = this.jump.tag(id); return k ? theme.bg("selectedBg", theme.fg("accent", theme.bold(k))) + " " : undefined; };
    // Overflow counts items when rows carry ids (a card spans several rows), else rows.
    const hidden = (slice: ListRow[]) => { const ids = new Set(slice.map((x) => x.id).filter(Boolean)); return ids.size || slice.filter((x) => x.text.trim()).length; };
    for (let y = 0; y < h; y++) {
      const row = rows[top + y];
      const first = !!row?.id && rows.findIndex((x) => x.id === row.id) === top + y;
      const lead = row?.lead != null ? (first ? tag(row.id!) : undefined) ?? row.lead : "";
      let line = this.hl(lead + (row?.text ?? ""), r.w, isSel(row) && focused, isSel(row) || (!!row && (row.id != null || row.group != null) && this.pointer.over(y0 + y, r.x, r.x + r.w)));
      if (!isSel(row) && !focused && row?.id === this.selectedId && first) line = pad(theme.fg("accent", "▌") + line.slice(1), r.w);
      if (y === 0 && top > 0) line = pad(theme.fg("muted", `  ↑ ${hidden(rows.slice(0, top + 1))} more`), r.w);
      if (y === h - 1 && top + h < rows.length) line = pad(theme.fg("muted", `  ↓ ${hidden(rows.slice(top + h - 1))} more`), r.w);
      lines.push(line);
    }
    return lines;
  }

  private drawSep(r: Rect, vertical: boolean): string[] {
    const { theme } = this;
    const hot = this.pointer.in(r) || this.pointer.captured?.x0 === r.x && this.pointer.captured?.y0 === r.y;
    const listFocus = this.focus === "list";
    const onDrag = (ev: Mouse) => {
      if (vertical) this.resizeTo(this.placement === "left" ? ev.x : this.W - ev.x - 1, 0);
      else { const f = this.frame!, top = this.placement === "top"; const y0 = top ? f.list!.y : f.detail!.y; const h = (f.list!.h + f.detail!.h + 1); this.resizeTo(0, top ? ev.y - y0 : y0 + h - ev.y - 1); }
    };
    this.hits.rect(r, { press: () => true, drag: onDrag });
    if (vertical) return Array.from({ length: r.h }, () => theme.fg(hot ? "accent" : listFocus ? "border" : "borderMuted", hot ? "┃" : "│"));
    const label = listFocus ? theme.fg("accent", theme.bold(` ${this.spec.listName} ${this.placement === "top" ? "▲" : "▼"} `)) : "";
    const color = hot ? "accent" : listFocus ? "border" : "borderMuted";
    return [theme.fg(color, "──") + label + theme.fg(color, "─".repeat(Math.max(0, r.w - 2 - visibleWidth(label))))];
  }

  private drawDetail(r: Rect): string[] {
    const { theme, spec } = this;
    const ids = this.detailIds();
    if (!ids.length) return Array.from({ length: r.h }, (_, k) => (k === 1 ? theme.fg("muted", ` ${spec.empty ?? "nothing selected"}`) : ""));
    const out: string[] = [];
    const each = Math.floor(r.h / ids.length);
    ids.forEach((id, i) => {
      const sh = i === ids.length - 1 ? r.h - each * i : each;
      const y = r.y + out.length;
      const focused = this.inDetail && id === this.selectedId;
      const crumbs = this.zoom && i === 0 ? [this.breadcrumb(id, r.w, r.x, y)] : [];
      const head = spec.detailHead(id, r.w, r.x, y + crumbs.length);
      const bodyH = Math.max(0, sh - crumbs.length - head.length - 1);
      const v = spec.view(id);
      const rows = spec.rows(id, r.w - 2);
      this.rowsOf.set(id, rows);
      if (id === this.selectedId) this.bodyH = bodyH;
      const max = settle(v, rows, bodyH);
      const block = [...crumbs, ...head, this.rule(v, rows.length, bodyH, r.w, r.x, y + crumbs.length + head.length, focused, this.live(id))];
      out.push(...block.slice(0, sh));
      if (bodyH > 0) out.push(...this.transcript(id, rows, v, r.x, y + block.length, r.w, bodyH, focused, max));
    });
    return out;
  }

  private breadcrumb(id: string, w: number, x: number, y: number) {
    const { theme, spec, hits } = this;
    let cx = x, text = "";
    const part = (s: string, run?: () => void) => { const sw = visibleWidth(s); if (run) hits.row(cx, cx + sw, y, { click: run }); text += s; cx += sw; };
    part(theme.fg("accent", " ← "), () => this.act("back"));
    if (spec.title) part(theme.fg("muted", ` ${clip(spec.title(), 28)} `), () => this.act("back"));
    const g = spec.groupOf?.(id);
    if (g) { part(theme.fg("borderMuted", "›")); part(theme.fg("muted", ` ${g} `), () => { this.zoom = false; this.cursorGroup = g; spec.group?.(g, "open"); this.reveal = true; }); }
    part(theme.fg("borderMuted", "›"));
    part(theme.bold(` ${clip(spec.label(id), Math.max(10, w - visibleWidth(text) - 4))} `));
    return pad(text, w);
  }

  private rule(v: View, n: number, h: number, w: number, x: number, y: number, focused: boolean, live: boolean) {
    const { theme } = this;
    const max = Math.max(0, n - h);
    const above = v.scroll > 0 ? `↑ ${v.scroll} above · ` : "";
    const where = max === 0 ? "fits" : above + (v.follow ? (live ? "live ●" : "end") : v.scroll === 0 ? "top · ↓ latest (G)" : `paused ${Math.round((v.scroll / max) * 100)}% · ↓ latest (G)`);
    const tag = ` ${where} `;
    const name = focused && !this.narrow ? theme.fg("accent", theme.bold(" transcript ")) : "";
    const line = focused && !this.narrow ? "border" : "borderMuted";
    if (!v.follow && max > 0) this.hits.row(x + w - visibleWidth(tag) - 2, x + w, y, { click: () => { v.follow = true; v.cursor = undefined; } });
    return theme.fg(line, "──") + name + theme.fg(line, "─".repeat(Math.max(0, w - visibleWidth(tag) - visibleWidth(name) - 4))) + theme.fg(v.follow || max === 0 ? "muted" : "warning", tag) + theme.fg(line, "──");
  }

  private transcript(id: string, rows: Row[], v: View, x: number, y: number, w: number, h: number, focused: boolean, max: number): string[] {
    const { theme, hits } = this;
    const tw = w - 1;
    const thumb0 = rows.length ? Math.floor((v.scroll / rows.length) * h) : 0;
    const thumb1 = rows.length ? Math.max(thumb0 + 1, Math.ceil(((v.scroll + h) / rows.length) * h)) : h;
    const marks = Array<string>(h).fill("");
    rows.forEach((r, k) => {
      const c = Math.min(h - 1, Math.floor((k / Math.max(1, rows.length)) * h));
      if (r.problem) marks[c] = "error"; else if (focused && this.isMatch(r) && marks[c] !== "error") marks[c] = "warning"; else if (r.live && !marks[c]) marks[c] = "accent";
    });
    const out: string[] = [];
    for (let k = 0; k < h; k++) {
      const r = rows[v.scroll + k];
      const isCursor = !!r?.key && r.key === v.cursor && focused;
      const gutter = r && focused && this.isMatch(r) ? theme.fg("warning", "▌") : " ";
      const text = this.hl(gutter + (r?.text ?? ""), tw, isCursor, !!r?.key && this.pointer.over(y + k, x, x + tw));
      const inThumb = k >= thumb0 && k < thumb1;
      const m = marks[k] ? theme.fg(marks[k], inThumb ? "┃" : "▪") : inThumb ? theme.fg("scrollbarThumb", "┃") : theme.fg("borderMuted", "│");
      out.push(text + (rows.length > h ? m : " "));
    }
    const jumpTo = (yy: number) => { v.follow = false; this.auto = false; v.scroll = Math.max(0, Math.min(max, Math.round(((yy - y) / h) * rows.length - h / 2))); if (v.scroll >= max) v.follow = true; };
    hits.add({ x0: x + tw, x1: x + w, y0: y, y1: y + h, press: (ev) => { jumpTo(ev.y); return true; }, drag: (ev) => jumpTo(ev.y), wheel: (d) => { scrollBy(v, d * 3, max); if (d < 0) this.auto = false; } });
    hits.add({ x0: x, x1: x + tw, y0: y, y1: y + h,
      click: (ev) => {
        if (ev.clickCount && ev.clickCount >= 2) return; // the first click already toggled
        const r = rows[v.scroll + ev.y - y];
        this.pick(id); if (!this.narrow) this.focus = "detail";
        if (r?.key) { v.cursor = r.key; v.follow = false; v.overrides.set(r.key, !r.open); }
      },
      wheel: (d) => { scrollBy(v, d * 3, max); if (d < 0) this.auto = false; } });
    return out;
  }

  private drawHelp(w: number, y0: number, h: number): string[] {
    const { theme, spec, hits } = this;
    const bw = Math.min(w - 2, 104), x0 = Math.max(0, Math.floor((w - bw) / 2));
    const entries: [string, string][] = [...HELP_BASE, ...(spec.help?.length ? [["", ""] as [string, string], ...spec.help] : []), ["", ""],
      ["mouse", "click selects or toggles · double-click zooms · right-click pins · the wheel scrolls the pane under the pointer · drag the divider · click or drag a transcript's scrollbar · every hint in the bottom bar is a button"]];
    const lines = entries.flatMap(([k, d]) => (k || d ? wrapTextWithAnsi(d, bw - 25).map((line, i) => `  ${theme.fg("accent", pad(i ? "" : k, 18))} ${theme.fg("text", line)}`) : [""]));
    const room = h - 2;
    this.helpScroll = Math.max(0, Math.min(this.helpScroll, Math.max(0, lines.length - room)));
    const more = lines.length > room ? theme.fg("muted", ` ${this.helpScroll + 1}-${Math.min(lines.length, this.helpScroll + room)} of ${lines.length} · j/k or wheel `) : "";
    const out = [" ".repeat(x0) + theme.fg("border", "╭" + "─".repeat(bw - 2) + "╮")];
    for (const l of lines.slice(this.helpScroll, this.helpScroll + room)) out.push(" ".repeat(x0) + theme.fg("border", "│") + pad(l, bw - 2) + theme.fg("border", "│"));
    out.push(" ".repeat(x0) + theme.fg("border", "╰") + more + theme.fg("border", "─".repeat(Math.max(0, bw - 2 - visibleWidth(more))) + "╯"));
    hits.front({ x0: 0, x1: w, y0, y1: y0 + h, click: () => { this.help = false; }, wheel: (d) => { this.helpScroll = Math.max(0, this.helpScroll + d * 2); } });
    return out;
  }

  // ---------- hints ----------
  private hintsFor(): Hint[] {
    const { spec } = this;
    const v = this.view;
    const H = (key: string, label: string, run: () => void | Action, narrow = false): Hint => ({ key, label, run: () => { const r = run(); if (typeof r === "string") this.act(r); }, narrow });
    const A = (key: string, label: string, action: Action, narrow = false) => H(key, label, () => this.act(action), narrow);
    const tail: Hint[] = [A("d", this.dens, "density"), A("?", "help", "help"), A("q", "quit", "quit", true)];
    if (this.help) return [A("j k", "scroll", "help"), A("esc", "close", "help")];
    if (this.jump.active) return [H("a–z", "pick an item", () => {}), A("esc", "cancel", "back")];
    if (this.filterEntry.active) return [H("", "type to filter · Enter keeps · Esc clears", () => {})];
    if (this.searchEntry.active) return [H("", "type to search · Enter finds · Esc clears", () => {})];
    const extra = spec.hints?.() ?? [];
    if (this.inDetail) {
      const s = this.search ? [A("n", "next match", "nextMatch"), A("N", "prev", "prevMatch")] : [A("/", "search", "search")];
      return [
        ...(this.narrow ? [A("‹ " + spec.listName, "", "toList", true)] : [A("esc", "back", "back")]),
        A("⏎", "toggle", "openDetail"), ...s, A("e", "next problem", "nextErr", true), A("}", "section", "nextSection", true),
        ...(v && !v.follow ? [A("f", "↓ latest", "follow", true)] : []), A("g", "top", "top"), A("+", "expand all", "expandAll"), A("-", "collapse all", "collapseAll"), A("p", "pin", "pin"), ...extra, ...tail,
      ];
    }
    if (this.narrow) { const one = spec.listName.replace(/s$/, ""); return [H("", `tap ${/^[aeiou]/.test(one) ? "an" : "a"} ${one} to open`, () => {}), ...extra, ...tail]; }
    const base: Hint[] = [A("⏎", this.cursorGroup != null ? "fold" : "open", "openDetail"), A("'", "jump", "jump"), A("e", "next problem", "nextErr"), A("p", "pin", "pin"), A("/", "filter", "filter"), A("o", "place", "place"), A("H L", "size", "wider")];
    if (!this.auto) base.push(A("a", "auto-follow", "auto"));
    return [...base, ...extra, ...tail];
  }
  private hintBar(y: number, w: number) {
    const { theme, hits } = this;
    let x = 0, out = "";
    const flash = this.flash.current;
    if (flash) { const f = theme.fg("accent", ` ${flash} `); out += f; x += visibleWidth(f); }
    const items = this.hintsFor();
    if (this.narrow) {
      for (const h of items) {
        if (!h.narrow && h.key && h.label && !h.key.startsWith("‹")) continue;
        const s = h.key && !h.label ? this.chip(h.key, h.danger) : h.label && !h.key ? theme.fg("muted", ` ${h.label} `) : this.chip(h.label, h.danger, h.key === "q");
        const lw = visibleWidth(s) + 1;
        if (x + lw > w) break;
        hits.row(x, x + lw - 1, y, { click: h.run });
        out += s + " "; x += lw;
      }
      return pad(out, w);
    }
    for (const h of items) {
      const s = h.key && h.label ? ` ${theme.fg(h.danger ? "error" : "accent", h.key)} ${theme.fg(h.danger ? "warning" : "muted", h.label)} ` : ` ${theme.fg("muted", h.label || h.key)} `;
      const lw = visibleWidth(s);
      if (x + lw > w) break;
      out += this.pointer.over(y, x, x + lw) ? theme.bg("userMessageBg", s) : s;
      hits.row(x, x + lw, y, { click: h.run });
      x += lw;
    }
    return pad(out, w);
  }

  // ---------- input ----------
  private handleInput(data: string) {
    const { spec } = this;
    const done = () => this.tui.requestRender();
    // Printable keys match exactly: pi's matchesKey treats "p" as matching "P". Named keys go through matchesKey.
    const key: KeyTest = (k) => (k.length === 1 ? data === k : matchesKey(data, k as any));
    const keys = (...ks: string[]) => ks.some(key);
    if (this.help) {
      if (keys("j", "down")) this.helpScroll++;
      else if (keys("k", "up")) this.helpScroll = Math.max(0, this.helpScroll - 1);
      else if (keys("pageDown", "ctrl+d", " ")) this.helpScroll += 10;
      else if (keys("pageUp", "ctrl+u")) this.helpScroll = Math.max(0, this.helpScroll - 10);
      else this.help = false;
      return done();
    }
    if (this.jump.active) { const id = this.jump.pick(data); if (id) { this.pick(id); if (this.narrow) this.screen = "detail"; } return done(); }
    if (this.filterEntry.active) { this.filterEntry.handle(data, key); this.reveal = true; return done(); }
    if (this.searchEntry.active) { if (this.searchEntry.handle(data, key) === "commit" && this.search) this.act("nextMatch"); return done(); }
    if (spec.key?.(data, key)) return done();
    const a = this.sel, v = this.view;
    if (keys("q")) return this.finish();
    if (keys("?")) this.act("help");
    else if (keys("tab", "shift+tab")) { if (this.narrow) this.screen = this.screen === "list" ? "detail" : "list"; else if (!this.zoom) { this.focus = this.focus === "list" ? "detail" : "list"; if (this.focus === "detail") this.auto = false; } }
    else if (keys("[")) this.step(-1);
    else if (keys("]")) this.step(1);
    else if (keys("'")) this.act("jump");
    else if (keys("/")) this.act(this.inDetail ? "search" : "filter");
    else if (keys("n") && this.inDetail) this.act("nextMatch");
    else if (keys("N") && this.inDetail) this.act("prevMatch");
    else if (keys("e")) this.act("nextErr");
    else if (keys("E")) this.act("prevErr");
    else if (keys("d")) this.act("density");
    else if (keys("p")) this.act("pin");
    else if (keys("z")) this.act("zoom");
    else if (keys("a")) this.act("auto");
    else if (keys("o") && !this.narrow) this.act("place");
    else if (keys("H") && !this.zoom && !this.narrow) this.act("narrower");
    else if (keys("L") && !this.zoom && !this.narrow) this.act("wider");
    else if (keys("+")) this.act("expandAll");
    else if (keys("-")) this.act("collapseAll");
    else if (keys("=")) this.act("resetFolds");
    else if (keys("{")) this.act("prevSection");
    else if (keys("}")) this.act("nextSection");
    else if (keys("escape")) this.act("back");
    else if (this.inDetail && a && v) {
      const rows = this.rowsFor(a), h = this.bodyH;
      if (keys("j", "down")) moveCursor(v, rows, 1, h);
      else if (keys("k", "up")) moveCursor(v, rows, -1, h);
      else if (keys("enter", " ")) { if (v.cursor) toggleRow(v, rows, v.cursor); else moveCursor(v, rows, 1, h); }
      else if (keys("l", "right")) { if (v.cursor) v.overrides.set(v.cursor, true); else moveCursor(v, rows, 1, h); }
      else if (keys("h", "left")) {
        // magit `^`: collapse the row, else climb to its section, else leave the transcript.
        const r = v.cursor ? rows.find((x) => x.key === v.cursor) : undefined;
        if (r?.open) v.overrides.set(v.cursor!, false);
        else if (r?.parent) v.cursor = r.parent;
        else this.act("toList");
      }
      else if (keys("G", "end", "f")) this.act("follow");
      else if (keys("g", "home")) this.act("top");
      else if (keys("pageDown", "ctrl+d")) { scrollBy(v, Math.max(1, Math.floor(h / 2)), Math.max(0, rows.length - h)); this.auto = false; }
      else if (keys("pageUp", "ctrl+u")) { scrollBy(v, -Math.max(1, Math.floor(h / 2)), Math.max(0, rows.length - h)); this.auto = false; }
    } else {
      if (keys("j", "down")) this.listStep(1);
      else if (keys("k", "up")) this.listStep(-1);
      else if (keys("g", "home")) { this.cursorGroup = undefined; this.listStep(-1e6); }
      else if (keys("G", "end")) this.listStep(1e6);
      else if (keys("enter")) this.act("openDetail");
      else if (keys("l", "right")) { if (this.cursorGroup != null) spec.group?.(this.cursorGroup, "open"); else this.act("openDetail"); }
      else if (keys("h", "left", " ")) this.act("fold");
      else if (keys("f")) this.act("follow");
    }
    return done();
  }

  component() {
    return {
      render: (width: number) => {
        try { return this.draw(width); } catch (e: any) {
          return [pad(this.theme.fg("error", ` render error: ${e?.message}`), width), ...String(e?.stack ?? "").split("\n").slice(1, 8).map((l) => pad(this.theme.fg("dim", l), width))];
        }
      },
      handleInput: (data: string) => this.handleInput(data),
      handleMouse: (ev: any) => this.pointer.dispatch(ev, this.hits, () => { if (this.jump.active) this.jump.cancel(); }),
      invalidate() {},
      dispose: () => this.dispose(),
    };
  }
}

// The launcher sets PI_VIEWER to the viewer's id; any other pi ignores the extension.
export function runViewer(pi: ExtensionAPI, id: string, make: (shell: Shell) => Spec, defaults: ViewerDefaults = {}) {
  if (process.env.PI_VIEWER !== id) return;
  const provider = `${id}-viewer`;
  pi.registerProvider(provider, {
    name: id,
    baseUrl: `${id}://viewer`,
    apiKey: id,
    api: provider,
    models: [{ id: "viewer", name: `${id} viewer`, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 1000000, maxTokens: 64000 }],
    streamSimple(model) {
      // Registered only so a minimal pi starts fast; the overlay never runs the agent loop.
      const stream = createAssistantMessageEventStream();
      const message: any = { role: "assistant", content: [{ type: "text", text: "viewer only" }], api: model.api, provider: model.provider, model: model.id,
        usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } }, stopReason: "stop", timestamp: Date.now() };
      queueMicrotask(() => { stream.push({ type: "start", partial: message }); stream.push({ type: "done", reason: "stop", message }); });
      return stream;
    },
  } as any);
  let shell: Shell | undefined;
  pi.on("session_shutdown", () => shell?.dispose());
  pi.on("session_start", async (_e, ctx) => {
    if (ctx.mode !== "tui") return;
    const model = ctx.modelRegistry.find(provider, "viewer");
    if (model) await pi.setModel(model);
    void ctx.ui.custom<void>((tui, theme, _kb, finish) => {
      shell = new Shell(id, tui, theme as any, () => finish(), defaults);
      shell.spec = make(shell);
      shell.start();
      return shell.component() as any;
    }, { overlay: true, overlayOptions: { width: "100%", maxHeight: "100%", anchor: "top-left" } }).then(() => ctx.shutdown());
  });
}
