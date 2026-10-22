import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";

import {
  Hits, Jump, Pointer, Prefs, TextEntry, autoPick, layout, matches, moveCursor, newView, setOpen, settle, stepRows, toggleRow,
} from "../lib/core.ts";

const base = { W: 160, H: 50, top: 2, bottom: 1, size: 0, narrow: false, screen: "list", zoom: false };

test("layout: a side list, a strip, zoom, narrow screens and the tail", () => {
  const left = layout({ ...base, placement: "left" });
  assert.equal(left.side, true);
  assert.deepEqual(left.list, { x: 0, y: 2, w: 67, h: 47 });
  assert.deepEqual(left.sep, { x: 67, y: 2, w: 1, h: 47 });
  assert.deepEqual(left.detail, { x: 68, y: 2, w: 92, h: 47 });
  const right = layout({ ...base, placement: "right", size: 40 });
  assert.deepEqual(right.list, { x: 120, y: 2, w: 40, h: 47 });
  assert.deepEqual(right.detail, { x: 0, y: 2, w: 119, h: 47 });

  const top = layout({ ...base, placement: "top", listRows: 3 });
  assert.equal(top.side, false);
  assert.deepEqual(top.list, { x: 0, y: 2, w: 160, h: 3 }); // a strip shrinks to its rows
  assert.deepEqual(top.sep, { x: 0, y: 5, w: 160, h: 1 });
  assert.deepEqual(top.detail, { x: 0, y: 6, w: 160, h: 43 });
  const bottom = layout({ ...base, placement: "bottom", size: 10 });
  assert.deepEqual(bottom.list, { x: 0, y: 39, w: 160, h: 10 });
  assert.deepEqual(bottom.detail, { x: 0, y: 2, w: 160, h: 36 });
  assert.equal(layout({ ...base, placement: "top", size: 100 }).list.h, 41); // capped so the detail keeps six rows

  const zoom = layout({ ...base, placement: "left", zoom: true });
  assert.equal(zoom.list, undefined);
  assert.deepEqual(zoom.detail, { x: 0, y: 2, w: 160, h: 47 });

  const phoneList = layout({ ...base, W: 80, narrow: true, placement: "left" });
  assert.deepEqual(phoneList.list, { x: 0, y: 2, w: 80, h: 47 });
  assert.equal(phoneList.detail, undefined);
  const phoneDetail = layout({ ...base, W: 80, narrow: true, placement: "left", screen: "detail" });
  assert.equal(phoneDetail.list, undefined);
  assert.deepEqual(phoneDetail.detail, { x: 0, y: 2, w: 80, h: 47 });

  const tailed = layout({ ...base, placement: "left", tailRows: 12 });
  assert.deepEqual(tailed.tail, { x: 0, y: 37, w: 160, h: 12 });
  assert.equal(tailed.list.h, 35);
  assert.equal(layout({ ...base, placement: "left", tailRows: 12, zoom: true }).tail, undefined);
});

const rows = (spec) => spec.split("").map((c, i) => (c === "k" ? { text: `row ${i}`, key: `k${i}` } : c === "p" ? { text: `bad ${i}`, key: `k${i}`, problem: true } : c === "_" ? { text: "" } : { text: `plain ${i}` }));

test("settle follows the tail from a block boundary and clamps a paused view", () => {
  const v = newView();
  const list = rows("k....k....k....");
  assert.equal(settle(v, list, 10), 5);
  assert.equal(v.scroll, 5); // the keyed row at 5 is within three rows of the largest scroll
  v.follow = false; v.scroll = 99;
  settle(v, list, 10);
  assert.equal(v.scroll, 5);
  const blank = rows("k...._.........");
  const w = newView();
  settle(w, blank, 10);
  assert.equal(w.scroll, 6); // the row after a blank line
});

test("moveCursor starts from the visible rows and keeps the cursor on screen", () => {
  const list = rows("k..k..k..k..k..k..");
  const v = newView();
  v.follow = false; v.scroll = 6;
  moveCursor(v, list, 1, 6);
  assert.equal(v.cursor, "k6"); // first keyed row at or below the top of the view
  const u = newView();
  u.follow = false; u.scroll = 6;
  moveCursor(u, list, -1, 6);
  assert.equal(u.cursor, "k9"); // last keyed row within the view
  moveCursor(u, list, 1, 6);
  moveCursor(u, list, 1, 6);
  assert.equal(u.cursor, "k15");
  assert.equal(u.scroll, 10); // scrolled so row 15 is the last visible
  for (let i = 0; i < 10; i++) moveCursor(u, list, -1, 6);
  assert.equal(u.cursor, "k0");
  assert.equal(u.scroll, 0);
});

test("stepRows wraps and counts matches", () => {
  const list = rows("k.p..k.p.k");
  const v = newView();
  const bad = (r) => r.problem;
  assert.deepEqual(stepRows(v, list, 1, bad, 4).n, 1);
  assert.equal(v.cursor, "k2");
  assert.equal(stepRows(v, list, 1, bad, 4).n, 2);
  assert.equal(v.cursor, "k7");
  assert.equal(stepRows(v, list, 1, bad, 4).n, 1); // wraps
  assert.equal(stepRows(v, list, -1, bad, 4).of, 2);
  assert.equal(v.cursor, "k7");
  assert.equal(stepRows(v, list, 1, (r) => r.text === "nope", 4), undefined);
});

test("toggleRow and setOpen edit the overrides against what the row shows", () => {
  const v = newView();
  const list = [{ text: "a", key: "a", open: true }, { text: "b", key: "b", open: false }, { text: "c" }];
  toggleRow(v, list, "a");
  toggleRow(v, list, "b");
  assert.deepEqual([...v.overrides], [["a", false], ["b", true]]);
  setOpen(v, list, true);
  assert.deepEqual([...v.overrides], [["a", true], ["b", true]]);
  setOpen(v, list);
  assert.equal(v.overrides.size, 0);
});

test("Pointer routes wheel, right-click, press-capture-drag-release and click through the hit list", () => {
  const hits = new Hits(), p = new Pointer(), log = [];
  hits.rect({ x: 0, y: 0, w: 10, h: 5 }, { click: (e) => log.push(`click ${e.y}`), wheel: (d) => log.push(`wheel ${d}`), right: () => log.push("right") });
  hits.add({ x0: 10, x1: 11, y0: 0, y1: 5, press: () => true, drag: (e) => log.push(`drag ${e.x}`) });
  hits.front({ x0: 0, x1: 2, y0: 0, y1: 1, click: () => log.push("overlay") });
  assert.deepEqual(p.dispatch({ type: "move", button: "none", x: 3, y: 3 }, hits), { handled: true, render: true });
  assert.deepEqual(p.dispatch({ type: "move", button: "none", x: 3, y: 3 }, hits), { handled: true, render: false });
  assert.equal(p.over(3, 0, 10), true);
  p.dispatch({ type: "wheel", button: "none", x: 3, y: 3, wheelDelta: -2 }, hits);
  p.dispatch({ type: "press", button: "right", x: 3, y: 3 }, hits);
  assert.deepEqual(p.dispatch({ type: "press", button: "left", x: 10, y: 1 }, hits), { handled: true, capture: true });
  p.dispatch({ type: "drag", button: "left", x: 14, y: 1 }, hits);
  assert.deepEqual(p.dispatch({ type: "release", button: "left", x: 14, y: 1 }, hits), { handled: true, render: true });
  assert.equal(p.captured, undefined);
  p.dispatch({ type: "click", button: "left", x: 3, y: 3 }, hits, () => log.push("before"));
  p.dispatch({ type: "click", button: "left", x: 1, y: 0 }, hits);
  assert.deepEqual(p.dispatch({ type: "click", button: "middle", x: 3, y: 3 }, hits), { handled: true, render: false });
  assert.deepEqual(log, ["wheel -2", "right", "drag 14", "before", "click 3", "overlay"]);
});

test("TextEntry edits, commits and cancels by key", () => {
  const key = (data) => (k) => (k === "enter" && data === "\r") || (k === "escape" && data === "\x1b") || (k === "backspace" && data === "\x7f");
  const t = new TextEntry();
  t.start();
  assert.equal(t.handle("a", key("a")), "edit");
  assert.equal(t.handle("b", key("b")), "edit");
  assert.equal(t.handle("\x7f", key("\x7f")), "edit");
  assert.equal(t.value, "a");
  assert.equal(t.handle("\x01", key("\x01")), "ignored");
  assert.equal(t.handle("\r", key("\r")), "commit");
  assert.equal(t.active, false);
  assert.equal(t.value, "a");
  t.start(true);
  assert.equal(t.value, "a");
  assert.equal(t.handle("\x1b", key("\x1b")), "cancel");
  assert.equal(t.value, "");
});

test("Jump hands out letters in render order and picks by letter", () => {
  const j = new Jump();
  assert.equal(j.tag("x"), undefined);
  j.start();
  j.frame();
  assert.equal(j.tag("first"), "a");
  assert.equal(j.tag("second"), "s");
  assert.equal(j.tag("first"), "a");
  assert.equal(j.pick("s"), "second");
  assert.equal(j.active, false);
});

test("autoPick keeps a recently active live item, else the most recently active", () => {
  const items = [{ id: "a", live: true, t: 100 }, { id: "b", live: true, t: 50 }, { id: "c", live: false, t: 500 }];
  const pick = (cur, now) => autoPick(items, cur, (x) => x.live, (x) => x.t, 30, now)?.id;
  assert.equal(pick(items[1], 70), "b"); // live and active 20 ago
  assert.equal(pick(items[1], 100), "a"); // idle past the threshold: the most recently active live one
  assert.equal(pick(undefined, 100), "a");
  assert.equal(pick(items[2], 100), "a"); // a finished item is left for a live one
  assert.equal(autoPick([items[2]], undefined, (x) => x.live, (x) => x.t, 30, 100)?.id, "c");
  assert.equal(matches("ab  cd", "xxcdxxabxx"), true);
  assert.equal(matches("ab ef", "xxcdxxabxx"), false);
});

const tmp = mkdtempSync(join(tmpdir(), "pi-viewers-core-"));
after(() => rmSync(tmp, { recursive: true, force: true }));

test("Prefs round-trip through the state directory and fall back to defaults", () => {
  const p = new Prefs(join(tmp, "nested", "acpx"));
  assert.equal(p.get("placement", "top"), "top");
  p.set("placement", "left");
  assert.equal(new Prefs(p.dir).get("placement", "top"), "left");
  p.set("placement", "");
  assert.equal(p.get("placement", "top"), "top");
});
