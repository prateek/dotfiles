---
status: active
doc_type: research
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - ../plans/goku-karabiner-migration-plan.md
  - nocfree-lite-firmware.md
status_detail: "Programmatic sweep of 2,023 public Go60 layouts fetched on 2026-10-05, plus hand reads of the layouts cited. Two points are unverified and marked as such."
---

# Go60 Layout Patterns: Navigation Layers And How People Leave Them

Background for the left-hand modal navigation layer in
`home/dot_config/karabiner.edn.tmpl`. The open question is how to leave a
toggled layer. This doc reports what public MoErgo Go60 layouts do, then ranks
options for Karabiner.

Counts are given per creator unless stated, because most layouts are forks:
2,023 layouts reduce to 1,871 distinct configurations from 1,028 creators, and
344 creators still carry a navigation layer identical to one MoErgo ships.

## Summary

**How people leave a locked layer.** They press a key that says "leave". Of
the 683 creators who have a lockable navigation layer:

| Exit from a locked navigation layer | Creators | Share |
| --- | ---: | ---: |
| Same key that entered, with an explicit binding on the layer (`&to 0` in 539 of them, else `&tog` or `&to` another layer) | 560 | 82% |
| A different, dedicated key (`&to 0` almost always) | 221 | 32% |
| Same key, left `&trans` over MoErgo's `&layer` key (exit unverified, see [Exit](#3-exit-from-locked-layers)) | 151 | 22% |
| A combo (the entry combo again, or a combo bound to `&to 0`) | 17 | 2% |
| Nothing on the layer itself | 17 | 2% |
| Only through another held layer (for example `&to 0` on Magic) | 9 | 1% |
| Auto-exit when some other key is pressed | 0 | 0% |
| Timeout | 0 | 0% |

Rows overlap: a creator with two exits is counted in both. 421 creators have
only the explicit same-key exit.

**How people enter a navigation layer** (959 creators have one; share is of
all 1,028):

| Activation | Creators | Share |
| --- | ---: | ---: |
| MoErgo `&layer`: hold is momentary, double-tap locks | 622 | 60.5% |
| Momentary hold, `&mo` | 505 | 49.1% |
| Layer-tap: hold is the layer, tap is a key (`&lt` or a custom hold-tap) | 465 | 45.2% |
| `&to` (lock) | 56 | 5.4% |
| `&tog` (toggle) | 28 | 2.7% |
| Sticky (one-shot) layer, `&sl` | 13 | 1.3% |
| Combo that toggles | 9 | 0.9% |
| Custom tap-dance | 3 | 0.3% |

The activating key is on a thumb for 861 creators and on a finger for 693.

The most common patterns:

1. **Hold to use, release to leave.** 565 creators have a navigation layer
   they can only hold. Nothing to exit.
2. **Hold, or double-tap to lock; the same key leaves.** This is the factory
   default and 646 creators have it.
3. **A dedicated "back to base" key** (`&to 0`) somewhere on the layer, usually
   in addition to pattern 2.
4. **A two-key combo toggles the layer on and off.** Rare for navigation, but
   it is how 224 of 298 creators reach a gaming layer.
5. **Lock-only layers** (no hold path) exist for 60 creators and leave the same
   ways: same key or a dedicated key.

Outliers worth reading:

- [rednaz's vim emulation](https://my.moergo.com/go60/#/layout/user/bd8c7cff-203e-46f0-9c1e-868f4452af8e):
  a toggled `vim` layer where unmapped keys are `&none`, `i`/`a`/`o` leave it,
  and a `vim_v` layer holds Shift down until an action key releases it. The
  closest thing in the corpus to our design.
- [johnjake78's "Go60 Left Hand Only"](https://my.moergo.com/go60/#/layout/user/c6dc3c7f-6ae8-4204-9b13-7009072b1a7e):
  the right half is entirely `&none`; left-hand ESDF navigation layer with
  sticky modifiers, and three `&to 0` keys to leave.
- The touchpad **temporary layer** (`&zip_temp_layer`), used by 308 creators,
  is the only widely used auto-exit: the layer turns on while the touchpad
  reports movement and off after a timeout. It is almost always a Mouse layer.

**Evidence on the auto-exit proposal.** No layout implements it, but the
corpus cannot show it either way: the editor builds against MoErgo's firmware,
and core ZMK has no auto-exit layer. That behaviour lives in an external module
([urob/zmk-auto-layer](https://github.com/urob/zmk-auto-layer)) that the
editor cannot load. What the corpus does show is that a thousand people live
with an explicit exit key, and that 164 of them (16%) use `&caps_word`, the one
built-in behaviour with auto-exit semantics.

## Method And Coverage

**Source.** The editor at <https://my.moergo.com/go60/> is a JavaScript app
over an unauthenticated JSON API. Endpoints were read from its bundle
(`assets/Tag-*.js`):

- `GET https://my.moergo.com/api/go60/layouts/v1` lists layout UUIDs. The UI
  labels this "Recent Layouts" and says only layouts whose firmware built are
  shown. It returned 949 UUIDs, newest first.
- `GET .../layouts/v1/?tags=a,b` searches by tag. Multiple tags are ANDed. It
  is capped at 949 too; only `qwerty` hit the cap.
- `GET .../layouts/v1/<uuid>/config` and `/meta` return one layout.
- A layout opens in the editor at
  `https://my.moergo.com/go60/#/layout/user/<uuid>`.

There is no like, download, or usage count in the metadata, so "most used"
sampling is impossible. It was not needed.

**Enumeration.** Starting from the 949 recent layouts, every tag seen was
searched and the tags of each new layout were searched in turn (232 tags, three
rounds). Then every unknown `parent_uuid` was fetched.

| Step | Layouts |
| --- | ---: |
| Recent listing | 949 |
| After the tag crawl | 2,118 |
| Added by walking parent links | 7 |
| Total fetched | 2,125 |
| Marked `unlisted` (excluded) | 102 |
| **Analysed** | **2,023** |

Of 1,508 parents not found by the tag crawl, 1,041 were unlisted, 247 never
compiled, 213 returned 404, and 7 were listed. Of the 368 listed layouts that
are someone's parent, the tag crawl had already found 361 (98%), so the corpus
is close to every listed, compiled, tagged Go60 layout. What is missing:
untagged layouts and layouts tagged only `qwerty` that are older than both
949-item windows. The corpus holds 63 untagged and 460 `qwerty`-only layouts,
so the missing set is probably in the low hundreds; the true total is not
knowable from this API. Dates run from 2025-05 to 2026-10-05, with 136 layouts
in 2025-12 and 179 to 263 a month after that.

All 2,023 were analysed by script. The layouts cited by name below were also
read by hand.

**MoErgo's own layouts** are bundled in the editor, not stored as UUIDs. All
ten were fetched from the bundle: five factory-default files (Windows and
macOS, wireless and wired, plus a generic default), Miryoku in two, a ZSA
Voyager-like layout, a mouse emulation example, and a per-layer RGB example. The front page
also links [TailorKey for Go60](https://my.moergo.com/go60/#/layout/user/76ff46d9-69f5-4357-846e-1e258e6a4f85).

**Families** by creator: 460 derive from the factory default, 261 from
TailorKey, 43 from Miryoku, 16 Voyager-like, 9 Glorious Engrammer ports, and
281 other.

**Classification.** A navigation layer is a non-base layer with all four
arrows in a home-block cluster, reached by some key. Arrow positions are named
by the QWERTY key at that physical position. Activation was resolved through
MoErgo's pseudo-behaviours, custom hold-taps, macros, combos, and custom
devicetree text. For each layer reachable by `&to`, `&tog`, or `&layer`, the
script looked on that layer for `&to` another layer, `&tog` itself, or `&trans`
at the entry position.

Limits: regex parsing of custom devicetree can miss exotic definitions.
Content flags such as "has Enter" mean a matching keycode appears on the
layer, including modified forms.

**Glove80 supplement.** The same API for the Glove80 returned 947 layouts from
704 creators. These were only searched for auto-exit patterns, not analysed in
full. Findings from them are labelled Glove80.

**ZMK semantics** come from zmk.dev:
[layers](https://zmk.dev/docs/keymaps/behaviors/layers),
[sticky layer](https://zmk.dev/docs/keymaps/behaviors/sticky-layer),
[sticky key](https://zmk.dev/docs/keymaps/behaviors/sticky-key),
[key toggle](https://zmk.dev/docs/keymaps/behaviors/key-toggle),
[caps word](https://zmk.dev/docs/keymaps/behaviors/caps-word), and
[temp-layer](https://zmk.dev/docs/keymaps/input-processors/temp-layer).
MoErgo's pseudo-behaviours are described in its
[layout editing guide](https://docs.moergo.com/layout-editor-guide/layout-editing/).

## 1. Navigation And Editing Layers

**Where the arrows are.** Creators with a navigation layer that differs from
every MoErgo-bundled layer (795):

| Arrow cluster | Hand | Creators | Share |
| --- | --- | ---: | ---: |
| ESDF inverted T | left | 519 | 65% |
| IJKL inverted T | right | 264 | 33% |
| HJKL row (vim) | right | 232 | 29% |
| Other right-hand row or inverted T (mostly TailorKey's J K L ; as ← ↑ ↓ →) | right | 218 | 27% |
| JKL; shifted vim row | right | 38 | 5% |
| Other left-hand row or inverted T | left | 25 | 3% |
| WASD | left | 8 | 1% |

429 of those creators have arrows on both hands, 253 right only, 113 left
only. ESDF is the factory default, which explains its lead; WASD is nearly
absent. On the base layer, 299 creators also keep arrows on the bottom row.

**The factory default** ([macOS variant](https://my.moergo.com/go60/#/layout/go60-macos))
puts this left-hand editing block on its Keypad layer:

```text
        W Home   E ↑      R End    T PgUp
A Redo  S ←      D ↓      F →      G PgDn
Z Undo  X Cut    C Copy   V Paste
```

SymbolNav has the same arrows, Home/End, and paging on the left (with symbols
in place of the clipboard row) and repeats the arrows on IJKL. The Keypad block
is our draft shifted one column right, with Home/End where we put word moves.
The bundled layouts are linked by the editor's `#/layout/<name>` route, which I
read from the bundle but could not open without a browser.

**What else sits on a left-hand navigation layer** (share of all creators):
Home/End 68%, Page Up/Down 68%, Tab 59%, Enter 58%, clipboard 58%, undo 57%,
Backspace 40%, Delete 6%, mouse keys 4%, word moves (Alt or Ctrl with an
arrow) 3%. Word-move keys are rare because most layers keep modifiers
reachable instead: 718 creators (70%) have a plain Shift on a navigation layer.

TailorKey's Cursor layer is the main alternative design: arrows in a row on
the right hand, the four modifiers on the left home row, and clipboard, undo,
find, and select macros around them.

## 2. Layer Activation

The summary table covers navigation layers. Across every non-base layer the
order is the same with two additions: `&to` reaches some layer for 375
creators (36.5%), mostly alternate base layers, and a toggling combo for 239
(23.2%), mostly TailorKey's gaming layer.

**MoErgo's `&layer`** is the dominant lock mechanism. The editor generates a
tap-dance for it:

```c
#define ZMK_TD_LAYER(name, layer) \
    ZMK_TAP_DANCE(name, \
        tapping-term-ms = <200>; \
        bindings = <&mo layer>, <&to layer>; \
)
```

One press or hold is `&mo`; two presses within 200 ms is `&to`. The factory
default binds it on the left inner thumb (SymbolNav) and the right outer
pinky (Keypad).

**Sticky layers** are a minority taste: 54 creators use `&sl` anywhere, 13 for
a navigation layer. A sticky layer drops after the next key press, so it suits
one symbol, not a run of arrow presses. A few wrap `&mo` in a sticky key to
tune it, for example
[hyperdeath666](https://my.moergo.com/go60/#/layout/user/5562501a-42d1-4e4e-a270-b01a59a9dee6):

```c
sli: sticky_layer_ignore_modifiers {
    compatible = "zmk,behavior-sticky-key";
    #binding-cells = <1>;
    bindings = <&mo>;
    release-after-ms = <2000>;
    quick-release;
    ignore-modifiers;
};
```

[jgaddis's "Minimal Key Hold Strain"](https://my.moergo.com/go60/#/layout/user/335b49a5-5f50-44ba-924d-a8025e63a03d)
stacks three entries on one navigation layer: hold a thumb key for momentary,
tap it for one-shot, or press a combo to toggle.

**Tap-dance beyond `&layer`** is rare (6 creators reach any layer with a
custom one). [lozy93](https://my.moergo.com/go60/#/layout/user/c859faa1-aac5-4b07-876f-3c38c30a697e)
shows the style: hold for a layer, tap for sticky Shift, double-tap for caps
word.

## 3. Exit From Locked Layers

The summary table has the counts. Details:

**Same key, explicit.** The factory default puts `&to 0` on the locked layer
at the position of the key that entered it, and its notes say "You can single
tap LH T1 to get back to the Layer 0". 539 creators have this.

**Same key, transparent (unverified).** 151 creators leave `&trans` at that
position, so a tap there runs the base layer's `&layer` key again: `&mo`
press and release. Whether that clears a layer locked by `&to` depends on the
firmware. Current ZMK documents layer locking: a layer turned on by `&to` or
`&tog` is "prevent[ed] ... from being deactivated by any behavior which is not
a `&to` or a `&tog`". I could not determine whether MoErgo's firmware has that
change, and MoErgo's docs do not say how to leave a `&layer` lock. Treat these
151 as "intends same-key exit".

**Dedicated key.** 207 creators have `&to 0` on a key other than the entry
key. johnjake78's left-hand layout puts it on three bottom-row keys of every
layer, described as "tap a row-5 key on the layer = back to base".

**Toggles.** Among the 35 creators whose navigation layer is entered with
`&tog` or a toggling combo: 9 repeat `&tog` at the same position, 8 leave
`&trans` there (which reaches the base `&tog`, so it works), 9 press the same
combo, 9 use a separate `&to 0` key, and 7 put `&to 0` on the entry key.
None auto-exit. Example:
[kk13777's toggled WASD layer](https://my.moergo.com/go60/#/layout/user/f102d40b-655f-4984-8d51-273a7a086228).

**Gaming layers** (298 creators): 218 leave with the same combo that entered,
41 with a `&to 0` key, 19 with a `&tog` key. TailorKey's is a two-key combo bound to
`&tog`, active on every layer.

**No exit on the layer.** 17 creators have a lockable navigation layer with no
exit on it. Some rely on a Magic-layer `&to 0`; some look like mistakes.

**Esc as exit.** One creator binds a macro that sends Esc and then leaves,
`&kp ESC &to 0` ([driftwood](https://my.moergo.com/go60/#/layout/user/a8ae0e76-e410-43c4-9d30-a1f02a0401d6)).
Nobody else ties exit to Esc; a plain ZMK key cannot do both.

**Auto-exit and timeouts.** A search of all 2,023 Go60 layouts and the 947
Glove80 layouts for `num_word`, `auto-layer`, and smart-layer definitions
found none. The related things that do exist:

- `&caps_word`, used by 164 Go60 creators. ZMK: it "will automatically
  deactivate when any key not in a continue list is pressed, or if the caps
  word key is pressed again". 17 Go60 creators and 108 Glove80 creators
  customise the list, for example
  [jmatth](https://my.moergo.com/go60/#/layout/user/d2b0fda8-fe40-40f1-aead-cb5b1e63b773):

  ```c
  &caps_word {
      continue-list = <MOD_LSFT BSPC UNDERSCORE>;
  };
  ```

- `&zip_temp_layer <layer> <timeoutMs>`, used by 308 creators. ZMK: it enables
  a layer "when input events are received, and automatically disable[s] it
  when no further events are received in the given timeout duration"; an
  `excluded-positions` property lists keys that do not deactivate it. Typical
  timeouts are 250 ms and 2000 ms. It is driven by the touchpad, not by keys,
  and nearly always targets a Mouse layer; about 8 creators point it at a
  navigation or keypad layer.
- `release-after-ms` on sticky keys and sticky layers (default one second).
- rednaz's vim layout, where exits are chained into action keys by macro:

  ```text
  &kp_tog RIGHT 12   "a": move right, then toggle the vim layer off
  &vim_o             &kp END &kp RET &tog 12
  &vim_v             &macro_press &kp LSHFT &macro_tap &tog 13
  &vim_v_exit X      &macro_release &kp LSHFT &macro_tap &kp X &tog 13
  ```

  Each exit is an explicit choice per key. Everything unmapped is `&none`.

## 4. Selection Without Holding Shift

| Mechanism | Creators | Share |
| --- | ---: | ---: |
| Plain Shift key on a navigation layer (hold it) | 718 | 69.8% |
| One-shot Shift, `&sk LSHFT`, anywhere | 293 | 28.5% |
| One-shot Shift on a navigation layer | 228 | 22.2% |
| Select-word, select-line, or extend macros | 268 | 26.1% |
| `&caps_word` | 164 | 16.0% |
| Pre-shifted arrow, Home, or End keys on a navigation layer | 24 | 2.3% |
| Toggled Shift, `&kt LSHFT` | 5 | 0.5% |

One-shot Shift covers one move, so people who select a lot either hold Shift
or use macros. The macros are nearly all TailorKey's:

```text
cur_SELECT_WORD   &kp LC(LEFT) &kp LC(LS(RIGHT))
cur_SELECT_LINE   &kp HOME &kp LS(END)
cur_EXTEND_WORD   &kp LC(LS(RIGHT))
cur_EXTEND_LINE   &kp LS(END)
cur_SELECT_NONE   &kp DOWN &kp UP &kp RIGHT &kp LEFT
```

A persistent select mode, which is what our Shift tap does, is rare. The five:

- [dkloecker](https://my.moergo.com/go60/#/layout/user/6915bcbd-d3ac-4adc-9e55-0fec10859219)
  has `&kt LCTRL`, `&kt LSHFT`, `&kt LALT`, `&kt LGUI` under the left hand on
  the Nav layer, with held modifiers on the row above. This is our select mode
  generalised to all four modifiers.
- rednaz uses `&kt LSHFT` on an emacs layer and the held-Shift `vim_v` layer
  above. Both end selection when a cut or copy runs, as ours does.
- The others toggle Shift on a base or gaming layer.

## 5. Layer Indication

- **Stock:** `&magic` is a hold-tap: hold for the Magic layer, tap to show
  status on the RGB LEDs. MoErgo's docs describe the tap as showing "RGB
  indicators". There is no per-layer colour in stock firmware.
- **Per-layer and per-key RGB** needs MoErgo's "PR36" community firmware and
  the `EXPERIMENTAL_RGB_LAYER` flag. 111 creators (10.8%) set it, and 107
  define a `zmk,underglow-layer` node with one colour grid per layer, for
  example [dieyen](https://my.moergo.com/go60/#/layout/user/aad04aa3-18c1-4bab-a911-f019972dd97f).
  MoErgo bundles a [PR36 RGB example](https://my.moergo.com/go60/#/layout/community-pr36-rgb-example).
- **Host-side indicators:** none found. A layout file cannot express one.

One in nine creators went to experimental firmware to see which layer is
active. Our banner does that job on the host.

## 6. One-Handed And Gaming Layers

**One-handed.** Eight creators have a layer named for mirroring or one-handed
use. Most are a held Mirror layer that sends the other hand's keys, for example
[tectual](https://my.moergo.com/go60/#/layout/user/e5d01b1c-1a19-44ae-a305-e21814c0d12f).
johnjake78's is the only layout built for the left hand alone. Its navigation
layer:

```text
              W PgUp   E ↑      R PgDn
A Home        S ←      D ↓      F →       G End
Z sticky ⇧    X sticky ⌘        C sticky ⌥   V sticky ⌃
bottom row: &to 0   &to 0   &to 0
```

Entry is `&layer` on a bottom-row key. Selection is sticky Shift then a move.

**Left-hand navigation in general** is common: 710 creators have a reachable
ESDF navigation layer, and 609 can lock one.

**Gaming.** 298 creators have a reachable gaming-named layer (310 counting
layers that no key reaches). It is a second
base layer with WASD-position letters untouched and arrows, if any, on the
bottom row. Entry is a combo toggle for 224, `&to` for 54, `&tog` for 28.
These are the layers people stay in longest, and they leave them by repeating
the entry.

## Implications For A Karabiner Modal Nav Layer

The current rules already match the majority pattern: Control-Space toggles,
Control-Space or Esc leaves, and unmapped left-hand keys are inert.

What ZMK has that Karabiner-Elements lacks natively: one-shot layers (`&sl`),
tap-dance, caps word with a continue-list, and the input-driven temporary
layer. What Karabiner has that covers the same ground, per its docs:
variables with `variable_if`, `to_if_alone`, `to_delayed_action`,
[`from.any`](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/from/any/)
(match every key code; its documented example is an "Arrow Only Mode" toggle),
[`to.sticky_modifier`](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/sticky-modifier/),
`from.simultaneous`, and `set_notification_message`. I did not check which
Karabiner version introduced `from.any` or whether goku can emit it.

Options, simplest first:

1. **Explicit exit only (what exists).** Same chord or Esc leaves; right-hand
   keys type normally or are inert. 82% of creators with a lockable navigation
   layer leave this way and none auto-exit. No timing, fewest rules. The cost
   is the stray keystroke when you forget the layer is on, which the banner is
   there to prevent.
2. **Add a one-key exit under the left hand.** A spare layer key (`3`, `4`,
   `5`, or the backtick) leaves, as `&to 0` does for 207 creators and for the
   one left-hand-only layout. One more rule. Worth it if Control-Space feels
   heavy as an exit.
3. **Hold or lock on one key.** MoErgo's `&layer`: hold for the layer while
   held, tap to lock, tap to leave. 60% of creators enter this way, and 565
   have a navigation layer with no lock at all. In Karabiner: set the variable on key down, clear it on
   key up unless `to_if_alone` set a lock flag. Short hops need no exit; the
   cost is a timing threshold and a dedicated key that can be held
   comfortably, which a chord is not.
4. **Caps-word-style auto-exit.** One rule shape: a continue-list (the layer's
   keys, modifiers, Enter, Backspace, arrows) and a `from.any` rule that clears
   the variable and passes the key through for everything else. This is the
   current proposal with the "inert left-hand keys" category removed, or kept
   as a second small list. No Go60 layout does it, because the firmware cannot;
   caps word at 16% shows the idea is liked where it exists. Most rules, and
   the layer can drop when you did not mean it to.
5. **Idle timeout.** The touchpad temporary layer is the precedent (308
   creators). In Karabiner each layer key could carry a `to_delayed_action`
   that clears the variable if nothing follows. Nobody in the corpus does this
   for a key-driven navigation layer; a layer that disappears while you read
   is worse than one that stays.
6. **One-shot layer.** Wrong tool: navigation is repeated presses.

For select mode, the corpus supports the toggle. One-shot Shift
(`to.sticky_modifier`) is the common ZMK choice at 22% but covers one move;
the people who built modal layers (rednaz, dkloecker) chose a held or toggled
Shift that ends on cut or copy, which is what the current rules do.

Open items:

- Whether a tap of MoErgo's `&layer` key clears its own lock on current
  firmware. This only affects how the 151 "transparent" creators are counted.
- Layouts with no tag or only the `qwerty` tag that predate the two 949-item
  windows were not reachable.
