// State and geometry shared by the pi viewers: pane layout, fold-row cursors, mouse hit regions,
// text entry, jump letters, preferences, and the one keymap. No pi or terminal imports, so Node
// tests cover it directly; kit.ts adds the parts that need pi-tui.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ---------- layout ----------
export type Placement = "top" | "bottom" | "left" | "right";
export const PLACEMENTS: readonly Placement[] = ["top", "bottom", "left", "right"];
export const NARROW = 100; // below this many columns (phones, thin splits) the list and detail stack as two screens

export interface Rect { x: number; y: number; w: number; h: number }
export interface Frame { narrow: boolean; side: boolean; list?: Rect; detail?: Rect; sep?: Rect; tail?: Rect }
export interface LayoutInput {
  W: number; H: number;
  top: number; // rows the viewer draws above the panes (header, tabs)
  bottom: number; // rows below them (hint bar)
  placement: Placement;
  size: number; // list columns (left/right) or rows (top/bottom); 0 = automatic
  narrow: boolean;
  screen: "list" | "detail"; // narrow layouts show one at a time
  zoom: boolean;
  tailRows?: number; // 0 = no tail pane
  listRows?: number; // a strip shrinks to fit this many rows
}

export const sideWidth = (W: number, size: number) =>
  Math.max(28, Math.min(W - 40, size > 0 ? size : Math.min(80, Math.max(30, Math.floor(W * 0.42)))));
export function stripRows(avail: number, size: number, listRows?: number) {
  const cap = Math.max(2, Math.min(avail - 6, size > 0 ? size : Math.floor(avail * 0.35)));
  return listRows == null ? cap : Math.max(1, Math.min(cap, listRows));
}
export function layout(i: LayoutInput): Frame {
  const y0 = i.top, side = i.placement === "left" || i.placement === "right";
  let h = Math.max(1, i.H - i.top - i.bottom);
  const f: Frame = { narrow: i.narrow, side };
  const tailRows = i.tailRows ?? 0;
  if (tailRows > 0 && !i.zoom && !i.narrow && h - tailRows >= 4) { f.tail = { x: 0, y: y0 + h - tailRows, w: i.W, h: tailRows }; h -= tailRows; }
  if (i.narrow) {
    if (i.screen === "list") f.list = { x: 0, y: y0, w: i.W, h }; else f.detail = { x: 0, y: y0, w: i.W, h };
    return f;
  }
  if (i.zoom) { f.detail = { x: 0, y: y0, w: i.W, h }; return f; }
  if (side) {
    const lw = sideWidth(i.W, i.size), left = i.placement === "left";
    f.list = { x: left ? 0 : i.W - lw, y: y0, w: lw, h };
    f.sep = { x: left ? lw : i.W - lw - 1, y: y0, w: 1, h };
    f.detail = { x: left ? lw + 1 : 0, y: y0, w: i.W - lw - 1, h };
    return f;
  }
  const sh = Math.min(stripRows(h, i.size, i.listRows), Math.max(1, h - 2)), top = i.placement === "top";
  f.list = { x: 0, y: top ? y0 : y0 + h - sh, w: i.W, h: sh };
  f.sep = { x: 0, y: top ? y0 + sh : y0 + h - sh - 1, w: i.W, h: 1 };
  f.detail = { x: 0, y: top ? y0 + sh + 1 : y0, w: i.W, h: Math.max(0, h - sh - 1) };
  return f;
}
export const inRect = (r: Rect | undefined, x: number, y: number) => !!r && x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;

// ---------- fold rows ----------
// A transcript is a list of rows; keyed rows fold (`open` says what the row shows now), `head` rows
// start a section (a turn, a prompt), `parent` names the row a collapsed child climbs to, and `hay`
// is what search matches when the visible text is not enough.
export interface Row { text: string; key?: string; open?: boolean; problem?: boolean; live?: boolean; head?: boolean; parent?: string; hay?: string }
export interface View { scroll: number; follow: boolean; cursor?: string; overrides: Map<string, boolean> }
export const newView = (): View => ({ scroll: 0, follow: true, overrides: new Map() });

// Applies follow and clamps the scroll; a following view starts at a block boundary (a keyed row or
// a blank line) when that costs at most three rows. Returns the largest scroll.
export function settle(v: View, rows: Row[], h: number) {
  const max = Math.max(0, rows.length - h);
  if (v.follow) {
    v.scroll = max;
    for (let k = 0; k <= 3 && v.scroll + k < rows.length; k++) {
      const at = v.scroll + k;
      if (at === 0 || rows[at].key || !rows[at - 1].text.trim()) { v.scroll = at; break; }
    }
  }
  v.scroll = Math.max(0, Math.min(v.scroll, Math.max(max, v.follow ? v.scroll : 0)));
  return max;
}
export function scrollBy(v: View, n: number, max: number) {
  v.scroll = Math.max(0, Math.min(max, v.scroll + n));
  v.follow = v.scroll >= max;
}
export function moveCursor(v: View, rows: Row[], dir: number, h: number) {
  const keyed = rows.map((r, i) => ({ r, i })).filter((x) => x.r.key);
  if (!keyed.length) return;
  let at = keyed.findIndex((x) => x.r.key === v.cursor);
  if (at >= 0) at = Math.max(0, Math.min(keyed.length - 1, at + dir));
  else if (dir > 0) { at = keyed.findIndex((x) => x.i >= v.scroll); if (at < 0) at = keyed.length - 1; }
  else { at = -1; keyed.forEach((x, k) => { if (x.i < v.scroll + h) at = k; }); if (at < 0) at = keyed.length - 1; }
  const t = keyed[at];
  v.cursor = t.r.key; v.follow = false;
  if (t.i < v.scroll) v.scroll = t.i; else if (t.i >= v.scroll + h) v.scroll = t.i - h + 1;
}
// The next or previous keyed row matching `pred`, wrapping around; says which match it is.
export function stepRows(v: View, rows: Row[], dir: number, pred: (r: Row) => boolean, h: number) {
  const hits = rows.map((r, i) => ({ r, i })).filter((x) => x.r.key && pred(x.r));
  if (!hits.length) return undefined;
  const cur = rows.findIndex((r) => r.key === v.cursor);
  const next = dir > 0 ? hits.find((x) => x.i > cur) ?? hits[0] : [...hits].reverse().find((x) => x.i < cur) ?? hits[hits.length - 1];
  v.cursor = next.r.key; v.follow = false;
  if (next.i < v.scroll || next.i >= v.scroll + h) v.scroll = Math.max(0, next.i - Math.floor(h / 3));
  return { row: next.r, index: next.i, n: hits.indexOf(next) + 1, of: hits.length };
}
export function toggleRow(v: View, rows: Row[], key: string) {
  const r = rows.find((x) => x.key === key);
  v.overrides.set(key, !(r?.open ?? false));
}
// `open` undefined restores the automatic folds.
export function setOpen(v: View, rows: Row[], open?: boolean) {
  v.overrides.clear();
  if (open != null) for (const r of rows) if (r.key) v.overrides.set(r.key, open);
}

// ---------- mouse ----------
export interface Mouse { type: string; button: string; x: number; y: number; wheelDelta?: number; clickCount?: number }
export interface Hit { x0: number; x1: number; y0: number; y1: number; click?: (ev: Mouse) => void; wheel?: (d: number) => void; press?: (ev: Mouse) => boolean; drag?: (ev: Mouse) => void; right?: (ev: Mouse) => void }
export type HitHandlers = Omit<Hit, "x0" | "x1" | "y0" | "y1">;
// Regions registered while a frame renders; the first match wins, so `front` adds overlays.
export class Hits {
  items: Hit[] = [];
  reset() { this.items = []; }
  add(h: Hit) { this.items.push(h); return h; }
  front(h: Hit) { this.items.unshift(h); return h; }
  rect(r: Rect, h: HitHandlers) { return this.add({ x0: r.x, x1: r.x + r.w, y0: r.y, y1: r.y + r.h, ...h }); }
  row(x0: number, x1: number, y: number, h: HitHandlers) { return this.add({ x0, x1, y0: y, y1: y + 1, ...h }); }
  at(x: number, y: number) { return this.items.find((h) => x >= h.x0 && x < h.x1 && y >= h.y0 && y < h.y1); }
}
export class Pointer {
  x = -1; y = -1;
  captured?: Hit;
  over(y: number, x0 = 0, x1 = 1e9) { return this.y === y && this.x >= x0 && this.x < x1; }
  in(r: Rect | undefined) { return inRect(r, this.x, this.y); }
  dispatch(ev: Mouse, hits: Hits, beforeClick?: () => void): { handled: boolean; render?: boolean; capture?: boolean } {
    if (ev.type === "move") { const moved = this.x !== ev.x || this.y !== ev.y; this.x = ev.x; this.y = ev.y; return { handled: true, render: moved }; }
    if (ev.type === "drag" && this.captured) { this.captured.drag?.(ev); return { handled: true, render: true }; }
    if (ev.type === "release") { const was = !!this.captured; this.captured = undefined; return { handled: true, render: was }; }
    const hit = hits.at(ev.x, ev.y);
    if (ev.type === "wheel") { hit?.wheel?.(ev.wheelDelta ?? 0); return { handled: true }; }
    if (ev.type === "press" && ev.button === "left" && hit?.press?.(ev)) { this.captured = hit; return { handled: true, capture: true }; }
    if (ev.type === "press" && ev.button === "right") { hit?.right?.(ev); return { handled: true }; }
    if (ev.type !== "click" || ev.button !== "left") return { handled: true, render: false };
    beforeClick?.();
    hit?.click?.(ev);
    return { handled: true };
  }
}

// ---------- input ----------
export type KeyTest = (k: string) => boolean;
export class TextEntry {
  value = "";
  active = false;
  start(keep = false) { this.active = true; if (!keep) this.value = ""; }
  handle(data: string, key: KeyTest): "commit" | "cancel" | "edit" | "ignored" {
    if (key("enter")) { this.active = false; return "commit"; }
    if (key("escape")) { this.active = false; this.value = ""; return "cancel"; }
    if (key("backspace")) { this.value = this.value.slice(0, -1); return "edit"; }
    if (data.length === 1 && data >= " ") { this.value += data; return "edit"; }
    return "ignored";
  }
  clear() { this.value = ""; this.active = false; }
}
export const JUMP_KEYS = "asdfghjklqwertyuiopzxcvbnm";
// Jump mode: items tagged while a frame renders get successive letters; the next key picks one.
export class Jump {
  active = false;
  private map = new Map<string, string>();
  private order: string[] = [];
  start() { this.active = true; this.map.clear(); this.order = []; }
  frame() { if (this.active) { this.map.clear(); this.order = []; } }
  tag(id: string) {
    if (!this.active) return undefined;
    let k = this.map.get(id);
    if (!k && this.order.length < JUMP_KEYS.length) { k = JUMP_KEYS[this.order.length]; this.map.set(id, k); this.order.push(id); }
    return k;
  }
  pick(data: string) { this.active = false; return [...this.map.entries()].find(([, k]) => k === data)?.[0]; }
  cancel() { this.active = false; }
}
// Every space-separated term must appear as a substring.
export const matches = (q: string, s: string) => q.toLowerCase().split(/\s+/).filter(Boolean).every((term) => s.toLowerCase().includes(term));

// ---------- preferences and messages ----------
export const stateRoot = () => join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "pi-viewers");
export class Prefs {
  dir: string;
  constructor(dir: string) { this.dir = dir; }
  get(k: string, d: string) { try { return readFileSync(join(this.dir, k), "utf8").trim() || d; } catch { return d; } }
  set(k: string, v: string) { try { mkdirSync(this.dir, { recursive: true }); writeFileSync(join(this.dir, k), v + "\n"); } catch {} }
}
export class Flash {
  text = "";
  until = 0;
  say(m: string, ms = 2500) { this.text = m; this.until = Date.now() + ms; }
  get current() { return Date.now() < this.until ? this.text : ""; }
}

// ---------- states ----------
// One vocabulary for both viewers' items, so glyphs, colours and sort order agree.
export type State = "starting" | "running" | "stalled" | "done" | "failed" | "cancelled" | "cached" | "abandoned" | "detached" | "waiting";
export const LIVE: ReadonlySet<State> = new Set<State>(["starting", "running", "stalled"]);
export const BAD: ReadonlySet<State> = new Set<State>(["failed", "stalled"]);
export const RANK: Record<State, number> = { failed: 0, stalled: 1, running: 2, starting: 2, detached: 3, waiting: 3, done: 4, cancelled: 4, cached: 5, abandoned: 6 };
export const DENSITIES = ["compact", "normal", "full"] as const;
export type Density = (typeof DENSITIES)[number];

// What to follow when the user has not picked: stay on a live item that acted within `idleMs`,
// else the most recently active live item, else the most recently active one.
export function autoPick<T>(items: T[], current: T | undefined, live: (t: T) => boolean, lastAct: (t: T) => number, idleMs: number, now: number): T | undefined {
  if (current && items.includes(current) && live(current) && now - lastAct(current) < idleMs) return current;
  const running = items.filter(live).sort((a, b) => lastAct(b) - lastAct(a));
  return running[0] ?? items.slice().sort((a, b) => lastAct(b) - lastAct(a))[0];
}

// ---------- text ----------
export function dur(ms: number) {
  const s = Math.max(0, Math.round(ms / 1000));
  return s >= 172800 ? `${Math.floor(s / 86400)}d` : s >= 3600 ? `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, "0")}m`
    : s >= 60 ? `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s` : `${s}s`;
}
export const clock = (ms?: number, seconds = false) => (ms ? new Date(ms).toTimeString().slice(0, seconds ? 8 : 5) : "--:--");
export const kTok = (n?: number) => (n == null ? undefined : n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`);
export const money = (n?: number) => (n == null ? undefined : n < 0.01 ? "<$0.01" : `$${n.toFixed(2)}`);
export const plain = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "");
// A full reset inside a highlighted row would end its background early.
export const keepBg = (s: string) => s.split("\x1b[0m").join("\x1b[22;23;39m");
// Labels like `A-control__metrics-ingestion__02` differ at the end, so cut from the middle.
export const mid = (s: string, w: number) => (s.length <= w || w < 8 ? s : s.slice(0, Math.ceil((w - 1) * 0.55)) + "…" + s.slice(s.length - Math.floor((w - 1) * 0.45)));

// ---------- keymap ----------
// The keys both viewers answer to. A viewer adds its own below these in the help.
export const HELP_BASE: [string, string][] = [
  ["Tab", "focus: list ⇄ transcript"],
  ["j k  ↓ ↑", "move in the focused pane"],
  ["[ ]", "previous / next item, from anywhere"],
  ["'", "jump: a letter appears beside each item; press one"],
  ["Enter", "list: open the item · transcript: toggle the row"],
  ["l →  h ←", "into / out: collapse a row, climb to its section, return to the list"],
  ["{ }", "previous / next section"],
  ["e E", "next / previous problem: items in the list, rows in a transcript"],
  ["/", "list: filter · transcript: search; n / N step through matches"],
  ["g G  f", "top / follow the tail"],
  ["Ctrl-d Ctrl-u", "half page down / up"],
  ["+ - =", "expand all / collapse all / back to automatic folds"],
  ["d", "density: compact → normal → full"],
  ["p", "pin: pinned items stack under the selection, two at most"],
  ["z", "zoom the transcript; Esc or the breadcrumb returns"],
  ["a", "follow whichever item is active"],
  ["o", "move the list: top → bottom → left → right"],
  ["H L", "shrink / grow the list"],
  ["Esc", "step back: help → search → zoom → filter → transcript → list"],
  ["? q", "this help / quit"],
];
