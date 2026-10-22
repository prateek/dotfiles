---
status: accepted
doc_type: adr
summary: "The acpx and workflow pi viewers are two Specs on one shared Shell in src/pi-viewers/, launched by pi-viewer, with one keymap and per-viewer preferences; their data models stay separate."
owner: Prateek
created: 2026-10-22
updated: 2026-10-22
related:
  - 0061-acpx-pi-viewer.md
  - 0062-claude-workflow-viewer.md
  - 0063-authored-programs-live-in-src.md
  - ../plans/repo-layout-plan.md
current_guidance: ../../src/pi-viewers/README.md
---

# ADR 0064: The pi viewers share one kit

The acpx viewer ([ADR 0061](0061-acpx-pi-viewer.md)) and the workflow viewer
([ADR 0062](0062-claude-workflow-viewer.md)) live together in `src/pi-viewers/`
as two `Spec`s hosted by one `Shell`. The shell owns the frame (a list beside,
above, below, or instead of the selected item's transcript; two stacked screens
below 100 columns), zoom, pins, the transcript block with its scrollbar and
search, help, the hint bar, filter and jump modes, auto-follow, and one keymap.
A spec supplies its items, its list rows, the head above a transcript, the
transcript rows, and its own keys. `bin/pi-viewer <acpx|workflow>` starts pi
with the extension and one private agent directory; chezmoi links it to
`~/.local/bin` on every machine (`--once` needs only node), and the two skills
call it by name. Placement, list size, density, and each viewer's own choices
(list mode, stream, sort) persist under `~/.local/state/pi-viewers/<viewer>/`.

The two viewers had been the same terminal UI written twice around different
sources. Each carried its own pi bootstrap, text helpers, fold-row cursor and
scroll logic, help overlay, filter input, and two-pane layout, and their
keymaps had drifted into conflict: `L`, `+`/`-`, `p`, `n`, and `1`–`3` did
different things in each. The workflow viewer had the newer interaction engine
(hit regions, hover, a draggable divider, a minimap, search); the acpx viewer
alone had the phone layout and the movable list. The kit takes the engine from
one and the layouts from the other, so both viewers gain what only one had.

What stays separate is the data. The acpx viewer attaches to live sessions
(`acpx sessions watch`, ACP events, permission verdicts, diffs, cost, and one
write: cancel); the workflow viewer tails files and judges states (stalled,
abandoned, cached) at a frame clock that can replay. A single extension with
pluggable sources would need a common item vocabulary, which is either lossy
(no verdicts and diffs, or no phase tree and timeline) or leaky (every renderer
branching on the source). The rosters differ in shape too: a flat list of runs
against a phase tree, table, or timeline.

The code sits in `src/pi-viewers/` under [ADR 0063](0063-authored-programs-live-in-src.md)
rather than inside the marketplace plugin. The plugin publishes `skills/`,
`hooks/`, `evals/`, `agents/`, `commands/`, and `licenses/`, with no shared
library payload, and no skill imports another skill's files; adding either
would have been a mechanism for one consumer. `acpx-pane` already depends on
`orca`, `acpx`, `jq`, and `~/.agents/bin/acpx-routing`, so a program on `PATH`
is not a new kind of coupling for the skill. The package carries its own tests
(`just pi-viewers-test`, in CI) and a typecheck against the installed pi
(`just pi-viewers-typecheck`, local only, because CI has no pi).
