---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-01
updated: 2026-09-02
related:
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../research/skill-invocation-frontmatter-research.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Phases 1-3 built: simulation, HTML console, decisions and apply. Phase 4 (pi and Codex budget projection) is future work."
---

# Skill Management Console

## TL;DR

`skill-console` manages the agent skill collection from the command line and a
standalone HTML page. It lives in the `agent-skill-management` skill and has
three subcommands:

| Subcommand | Does | Writes |
|---|---|---|
| `render` | Reproduces Claude Code's skill-listing admission from live inputs and writes one self-contained HTML console | one HTML file under `$XDG_STATE_HOME/dotfiles/skill-console/` |
| `apply` | Validates a decisions document exported from the page and commits its edits to the chezmoi source tree, staged and validated first | `home/dot_agents/packages/**`, `home/.chezmoitemplates/claude-settings-managed.json.tmpl`, and the three package-derived templates (`agent-codex-plugin-config.toml.tmpl`, `agent-claude-plugin-settings.json.tmpl`, `dot_pi/agent/claude-plugins.json.tmpl`); dry run by default |
| `budget` | Recomputes an admission from a fixture table | nothing |

Claude Code shows the model one `- name: description` row per model-invocable
skill. When the rows exceed a character budget, it keeps full descriptions for
the highest-ranked rows and reduces the rest to a bare name, and a name-only
skill is rarely auto-invoked. The budget depends on the model, the context
window, settings, and the environment, so the console reads those inputs and
never hardcodes a number.

On this machine the budget resolves to 24,000 characters. The
[reference capture](#the-reference-capture) (2026-09-01T18:24Z, Claude Code
2.1.258, this worktree as cwd) had 83 rows: 62 rendered in full and 21
name-only. A later capture (2026-09-02T13:57Z) has 84 rows, 62 full and 22
name-only, and the simulation reproduces it row for row.

The page can stage six operations: shorten a description, set a frontmatter
flag, delete a vendored skill, flip a package's `default_loaded`, toggle a
plugin's `enabledPlugins` entry, and change `skillListingBudgetFraction`. The
browser never writes files; it exports a decisions document. `apply` edits
only the chezmoi source tree, commits path by path (each path atomically, the
batch as a whole not), and stops before `chezmoi apply`.

Phases 1 through 3 (simulation, console, decisions and apply) are built and
tested by `make test-skill-console`. Phase 4, budget projection for pi and
Codex, is future work. [Open items](#open-items) lists what is still loose.

## Why the console exists

Enabling a disabled package is a one-line change to `package.toml`, but the repo
does not show what that change costs or which skill descriptions it displaces.

The repo's 142 skills across 9 packages are not the only rows. Six plugins from
the Chronosphere marketplace, Claude's built-ins, and user or project skill
directories share the same listing budget. Most of those cannot be edited from
this repo, but the simulation has to carry their cost or it is wrong for every
row.

Admission is discrete. Shortening a description by 40 characters may change
nothing, or it may admit a different skill in full. The useful output is the
set difference between the current and proposed listings, not a per-skill
character delta, and only a faithful re-run of the algorithm produces it.

## How a change flows

```text
skill-console render            reads live state, simulates, writes HTML, opens it
  -> browser                    stage operations, watch the listing recompute
  -> Export decisions JSON      snapshot + witness + operations, nothing written
skill-console apply D.json      dry run: validate, stage, validate the copy, print the diff
skill-console apply D.json --commit
  -> git diff -- <paths>        review
  -> chezmoi diff / apply       by hand; the console never runs it
```

Claude Code is the only harness with a simulated budget. pi and Codex read the
same generated marketplace, so their inventory is the same tree, but each one's
listing serialization has to be read from its source before a budget can be
projected. That is Phase 4.

## Claude Code's listing budget

The constants below were read out of the Claude Code 2.1.258 executable and
live in one table in `skill_console/__init__.py`, keyed to that binary's
SHA-256. `render` warns when the live binary's hash differs; `apply` refuses
the snapshot (V10) so a proposal computed with stale constants is never
committed. `tests/skill-console.zsh` re-checks every constant against the
binary whenever the hash still matches.

### Budget formula and inputs

```text
env = Number($SLASH_COMMAND_TOOL_CHAR_BUDGET), unrounded; NaN counts as unset
budget = env                                              if env is truthy (set and not 0)
       = max(1, floor(context_window × bytes_per_token × fraction))   otherwise
```

The environment value is used as the JS number, unrounded: `Infinity` means
everything fits, `0.5` is a half-character budget, digit groups such as
`24,000` are accepted, and `0`, an empty string, or anything that is not a
number means unset. A negative value is used verbatim, because the binary's
truthiness check accepts it; the console mirrors that and warns. JSON output
(`--json` and the page's embedded data) spells infinities as the strings
`"Infinity"` and `"-Infinity"`, since JSON has no literal for them.

| Input | Default | Resolved here | Source |
|---|---:|---:|---|
| `skillListingBudgetFraction` | 0.01 | 0.04 | merged Claude settings |
| `skillListingMaxDescChars` | 1536 | 1536 | merged Claude settings; unset here |
| `bytes_per_token` | 4 | 3 | model family (see below) |
| `context_window` | 200,000 | 200,000 | the harness runtime |

The two settings keys resolve through Claude Code's five-layer merge (user,
project, local, command-line flags, managed policy; later layers win). The
console reads and hashes only a six-key projection of those files
(`skillListingBudgetFraction`, `skillListingMaxDescChars`, `enabledPlugins`,
`skillOverrides`, `extraKnownMarketplaces`, `disableBundledSkills`), never the
whole file, which may hold credentials. The flag layer (`claude --settings`)
is not observable from outside the process.

The binary's settings schema constrains `skillListingBudgetFraction` to
`(0, 1]`. The console keeps a value above 1 and warns that every number
derived from it is suspect, because what the binary does with a settings layer
that fails its schema is unverified.

`bytes_per_token` is 4 when the model id normalizes to one of 14 legacy
families and 3 otherwise. Normalization is a pipeline, not a lookup: alias
resolution, provider region prefix removal, an ordered substring match over the
family list with two regex branches for bare `claude-opus-4` and
`claude-sonnet-4`, a `[1m]` suffix strip, a `-YYYYMMDD` fallback strip, and
`[._]` to `-`. `claude-fable-5-1` normalizes to `claude-fable-5`, which is not
in the legacy set, so this machine gets 3 and a 24,000-character budget. The
same settings on a legacy Claude 4 model give 32,000.

The model id and the context window come from the harness. Resolution order,
first hit wins:

1. `--model` and `--context-window`, for reproducing another machine.
2. The newest statusline state file under
   `$XDG_STATE_HOME/dotfiles/claude/statusline/`, with its capture time
   surfaced as a warning.
3. Hard failure (exit 2) naming the missing flags. There is no default.

`--model` needs a concrete id. Bare aliases (`opus`, `sonnet`, `haiku`,
`fable`, `opusplan`, `best`) resolve against account state the console cannot
see and are rejected with a message saying so.

The console does not read `$CLAUDE_CODE_MAX_CONTEXT_TOKENS`. The binary
consults it only when `DISABLE_COMPACT` is set or the model id does not start
with `claude-`; neither holds here, and including it would only make the
budget wrong.

### Two measures

Two lengths are needed and they are never interchangeable:

| Measure | Definition | Governs |
|---|---|---|
| `utf16_length` | JS `.length`: 2 per astral code point, else 1 | the `skillListingMaxDescChars` cap, because the binary caps with `.length` and `.slice` |
| `display_width` | `Bun.stringWidth(s, {ambiguousIsNarrow: true})`, ported from Bun 1.4.0 (see below) | row cost, because the serializer charges the row's width |

`display_width` is a port of Bun 1.4.0's `stringWidth`, the runtime family
the 2.1.258 executable embeds. It segments text into grapheme clusters (Hangul
jamo, emoji ZWJ and skin-tone sequences, regional-indicator pairs, keycaps,
variation selectors) and charges each cluster the way Bun does; per code point
the width is 0 for controls, marks, and Hangul medial and final jamo, 2 for
East Asian wide and fullwidth, and 1 otherwise, plus Bun's own override
tables. It agrees with Bun on every code point and on every cluster form
tested, with three known exceptions: ANSI escape sequences (Bun strips them;
the console cannot write one), Indic conjuncts followed by a variation
selector or keycap, and anything Bun 1.4.1 or Unicode 17 changed beyond the
seven emoji added in 17.0. `UNICODE_VERSION` and `BUN_STRING_WIDTH_VERSION` in
`skill_console/__init__.py` record where the tables came from.

On read, divergence is informational: each row carries `width_divergent`. The
only live divergence in this inventory is newline characters embedded in
block-scalar descriptions, which cost 0 width and 1 UTF-16 unit each; the
non-ASCII text in descriptions (em dashes, curly quotes, arrows) is all width
1. On write, `set_description` accepts newlines and BMP code points that stand
alone at width one, which covers everything already in the repo, and refuses
the rest: every other control character, astral code points, combining marks
and format characters, East Asian wide characters, and anything Bun draws at
width 0 (Hangul medial and final jamo, the Indic spacing signs). The cost of
written text therefore never depends on grapheme rules, and the console never
writes text whose cost it cannot prove.

### Rows and costs

```text
listing_text  = f"{description} - {when_to_use}" if when_to_use else description
capped        = utf16_length(listing_text) > max_desc_chars
capped_text   = listing_text if not capped else listing_text[:max_desc_chars - 1] + "…"

full_row      = f"- {name}: {capped_text}"
name_only_row = f"- {name}"

full_cost      = measure(full_row)
name_only_cost = measure(name_only_row)          # measure(name) + 2
upgrade_cost   = full_cost - name_only_cost      # measure(capped_text) + 2
```

`when_to_use` is the frontmatter key; Claude Code loads it into an internal
`whenToUse` field and joins with `" - "`. No repo skill sets it today.

`name` is the listing name, not the frontmatter `name`: `<package>:<directory>`
for plugin skills and the bare name for user, project, and built-in rows.
Across the capture that qualification is roughly 600 characters of prefix
overhead. The repo's vendored `orca-stration` directory has frontmatter
`name: orchestration` and lists as `utils-agent:orca-stration`.

Description and `name` are trimmed before use, matching the binary: a
`description: >` block yields a trailing newline from YAML that the rendered
row does not carry. Internal newlines are kept. `when_to_use` is not trimmed.
A description that is a YAML number or boolean is stringified the way JS does
(`true`, `1.5`); any other non-string value is dropped, as the binary drops it.

### Admission

A faithful port of the binary's admission over row indices:

```text
if no rows: empty listing, no attachment

forced    = rows whose skillOverrides state is "name-only"
charged   = name_only_cost for forced rows, full_cost otherwise
demand    = Σ charged + (n - 1)                  # separator charged once

if demand <= budget:
    mode = "fits"; every non-forced row renders full

mode = "priority"
pinned     = forced ∪ protected                 # protected: type == "prompt" and source == "bundled"
candidates = rows not pinned
if no candidates:
    every non-forced row renders full, over budget   # a real third outcome, not an error

baseline = Σ (charged if pinned else name_only_cost) + (n - 1)
headroom = budget - baseline
sort candidates by rank, descending, stable       # equal ranks keep listing order
for each candidate:
    if upgrade_cost <= headroom: admit it; headroom -= upgrade_cost
    # a miss does not stop the walk

rendered_chars = budget - headroom
row renders full  iff  not forced and (pinned or admitted)
```

Points that are easy to get wrong and are all load-bearing:

- The separator term is `(n - 1)`, charged once in `demand` and once in
  `baseline`. It never grows during admission.
- `demand` is what a fully expanded listing would cost; `rendered_chars` is
  what survives. In `priority` mode they differ.
- Sorting is stable over ascending indices. Most rows tie at rank 0, so listing
  order is data the simulation has to carry.
- Forced name-only rows are excluded from candidates and charged name-only
  everywhere. On this machine the set is empty, because `skillOverrides` is
  inert for plugin skills, but the path exists.
- Protection is `type == "prompt" and source == "bundled"`, which is 10 of the
  12 built-ins. `init` and `security-review` are `source: "builtin"`,
  unprotected, and drop to name-only like anything else. Protection is not
  derived from origin.
- In `priority` mode a row is full or name-only. Descriptions are never
  partially trimmed by admission; only the 1536 cap trims text.

### Rank

```text
rank = 0                                             if the name has no skillUsage record
     = usage_count × max(0.5 ** (age_days / 7), 0.1)  otherwise
age_days = (now_ms - last_used_at_ms) / 86_400_000
```

`skillUsage` lives in `~/.claude.json`, keyed by the same qualified name the
listing uses. Usage recorded under a former name (a pre-plugin bare name, a
former package, a former directory) does not count. Decay bottoms out at 0.1
around day 23. Negative ages are not clamped.

`now_ms` is recorded in the snapshot and `apply` recomputes rank with it, not
with the wall clock, so the witness is reproducible. A decisions document older
than 24 hours is refused (V11) unless `--allow-stale`.

### Listing membership and order

A row is listed when its package is enabled, it does not set
`disable-model-invocation`, and its `skillOverrides` state is neither `off` nor
`user-invocable-only`. A plugin skill with no frontmatter description (or a
blank one) is listed only if it sets `when_to_use`; skill-directory rows,
commands, and built-ins have no such rule. Names are deduplicated first-wins.
Order matters for tie-breaking and is the order of the captured attachment:
user skills, project skills, and slash commands first, then plugin skills in
plugin install order with directories sorted by name within a plugin, then
built-ins.

When a skill or command has no frontmatter description, its text is derived
from the first body line (heading marker stripped) and cut to 100 characters,
falling back to `Skill` for a `SKILL.md` and `Custom command` for a legacy
command; those rows carry `derived_description`.

Project skills come from every `.claude/skills` directory from the working
directory up to the git root, nearest first; the binary does not look above
the git root toward `$HOME`, and the console uses `--project-root` as that
boundary. Legacy slash commands come from `~/.claude/commands` and from every
`.claude/commands` on the same walk (plus the main worktree's when a linked
worktree has none of its own), recursively, named `sub:dir:stem`, with a
`SKILL.md` standing in for its sibling `.md` files; user and project commands
are then sorted together by `localeCompare`.

The listing is project-scoped: project settings, the `.claude/skills` walk,
and the transcript directory `~/.claude/projects/<slug>/` all key off the
working directory. The snapshot records `cwd` and `project_root`, `render` and
`apply` take `--project-root`, and `apply` refuses a mismatch (V12).

### The `/context` estimator

A second implementation in the binary feeds `/context` and `/doctor`. Its
admission logic is identical; it differs only in measuring rows with `.length`.
The console has one core and reproduces the estimator by passing
`measure=utf16_length` (`skill-console budget --measure utf16`).

The per-skill cell `/context` prints, for reconciling against a screenshot:

```text
tokens = round_half_up(cost / bytes_per_token)
cell   = "< 20" if tokens < 20 else "~" + str(round_half_up(tokens / 10) * 10)
```

Rounding is half-up, not Python's banker's `round()`. The `< 20` bucket is a
cost boundary at 58 characters (3 bytes per token), not a rendering boundary:
in the reference capture, the `plan-detail` and `do-new-prompt-plan` user
commands (since removed) are full rows that print `< 20`. Do not infer
name-only from `< 20`.

Ground truth is the `skill_listing` attachment in
`~/.claude/projects/<slug>/*.jsonl` (`isInitial: true`, matching `cwd`), which
the console decomposes at exact character offsets and compares against its own
admission. `claude plugin details` is not a cross-check: its denominator is
skills plus agents plus commands, its total is a live `countTokens` call, and
its per-plugin ratio varies between 0.345 and 0.391.

### The reference capture

| Fact | Value |
|---|---|
| Captured | 2026-09-01T18:24Z, Claude Code 2.1.258, cwd this worktree |
| Model, window, bytes/token, fraction | `claude-fable-5-1`, 200,000, 3, 0.04 |
| Budget | 24,000 characters |
| Rows | 83 |
| Rendered listing | 23,917 width (24,001 UTF-16 units; the gap is 84 embedded newlines) |
| Mode | `priority` |
| Full / name-only | 62 / 21 |

The rows come from four populations: this repo's enabled packages, three
Chronosphere plugins that contribute listing rows, user and project skills and
slash commands outside any package, and Claude Code's 12 built-ins. The numbers
move with every `chezmoi apply`, skill invocation, settings change, and Claude
upgrade, which is why the console recomputes them instead of the docs carrying
them.

### Built-in rows

The 12 built-in rows have no `SKILL.md` on disk; their descriptions live only
in the binary, in shapes that change per build. The console carries them in a
hash-keyed fixture, `skill_console/builtins.json`, built from a captured
listing rather than from a `strings` dump. Ten are `source: "bundled"` and
protected. `init` and `security-review` are `source: "builtin"`, unprotected,
and have been name-only in every 2.1.258 capture on this machine, so their text
comes from an earlier capture and is verified byte-for-byte against the 2.1.258
executable. `disableBundledSkills: true` in merged settings, or any non-empty
`CLAUDE_CODE_DISABLE_BUNDLED_SKILLS` (`false` included), delists all twelve;
the settings key is part of the projection the console hashes.

## Listing controls and their limits

| Control | Listing effect | Console operation |
|---|---|---|
| Shorten a description | May change greedy admission | `set_description` |
| `disable-model-invocation: true` | Removes the row | `set_frontmatter` |
| `default_loaded = false` | Removes the package's rows in Claude, pi, and Codex | `set_default_loaded` |
| `enabledPlugins` entry | Removes a plugin's rows in Claude only | `set_package_enabled` |
| Delete a vendored skill | Removes the row and the files | `delete_skill` |
| `skillListingBudgetFraction` | Changes the budget | `set_budget_fraction` |
| `skillOverrides` | Per-skill `name-only` and `off` states | not offered: inert for plugin skills |
| `user-invocable: false` | Keeps the listing row | reported as inventory only |

A fraction of 0.05 resolves to 30,000 characters under the current model and
window. It is the highest-leverage control in the tool.

`skillOverrides` is exactly the per-skill lever the console wants, and it is
unreachable for plugin skills. The resolver returns `"on"` whenever
`source === "plugin"`, before it reads `skillOverrides`, which is why `/skills`
prints "Plugin skills are managed via /plugin". The check is on delivery
mechanism, not authorship: a bare `SKILL.md` directory copied into
`~/.claude/skills/` (without its `.claude-plugin/` marker) would honor the
overrides. Every package skill in this repo reaches Claude through the
generated plugin marketplace, so all 142 hit the early return.

Plugin projection is the deliberate trade. It gives one source tree that
renders to Claude, pi, and Codex, plus versioning and package-level enable
state. It costs per-skill override granularity. `disable-model-invocation`
recovers the useful half of that granularity through a different code path,
and it does apply to plugin skills: the mattpocock plugin has 25 skills, 14
with the flag, and the listing contains the 11 unflagged skills. (`plugin
details` still prices flagged skills; its projection does not model the flag.)

Shortening has discrete effects. Shortening a name-only skill changes nothing
until its full row fits. Shortening an admitted skill may make room for another
full row. Characters above `skillListingMaxDescChars` already cost nothing.
Repo-authored descriptions are capped at 1024 characters by
`validate-agent-packages`, so the 1536 cap only bites on rows from outside the
repo. Every staged control reruns the complete admission and reports
`newly_admitted` and `newly_dropped`.

Package-level `default_loaded` also controls MCP servers, hooks, agents, and
commands, and renders into three harnesses. A package toggle changes more than
Claude's listing, and the page says so.

Claude Code, pi, and cursor-agent honor `disable-model-invocation`. Codex
ignores it unless the skill also has an `agents/openai.yaml` sidecar. The
cross-harness behavior is documented in
[skill-invocation-frontmatter-research.md](../research/skill-invocation-frontmatter-research.md).

`user-invocable: false` is harness-specific and no harness turns it into a
budget lever:

| Harness | Effect of `user-invocable: false` |
|---|---|
| Claude Code | Hides the `/` command, keeps the model listing row |
| pi | Unknown key, ignored; skill stays user- and model-visible |
| cursor-agent | Zero references in the bundle; ignored |
| Codex | No equivalent field |

In Claude Code the flag points the other way on purpose: it makes a skill
model-only, so the row and its full cost stay. The repo's live example is the
`review` package's `crit-cli` skill, a CLI reference the model should read and
the human should not see in the `/` menu.

## Inventory and state sources

Paths written `~/.claude/...` and `~/.claude.json` below are the defaults.
When `CLAUDE_CONFIG_DIR` is set, the console reads settings, plugins, user
skills and commands, the projects directory, and `.claude.json` from inside it,
as Claude Code does.

### Origins

Every row has one of seven origins. The origin decides which operations a row
permits (see the [capability matrix](#capability-matrix)); it does not decide
protection.

| `origin` | Where the skill lives |
|---|---|
| `repo-local` | `home/dot_agents/packages/*/skills/local/*` |
| `repo-vendor` | `home/dot_agents/packages/*/skills/vendor/*` |
| `repo-project` | `.claude/skills/*` from the working directory up to the project root (here `.claude/skills` is a symlink to `.agents/skills/`) |
| `user-skill` | `~/.claude/skills/*`, unmanaged |
| `user-command` | `~/.claude/commands/**/*.md` and `.claude/commands/**/*.md` on the same walk, unmanaged |
| `third-party-plugin` | any marketplace other than `prateek-local` |
| `builtin` | shipped in the executable |

### Three trees

A repo skill exists in up to three trees, and the same skill in three trees is
three records:

| Tree | Path | Role |
|---|---|---|
| `source` | `home/dot_agents/packages/**` | chezmoi source; the only write target |
| `marketplace` | `~/.agents/plugins/plugins/**` | rendered by `chezmoi apply` |
| `cache` | the plugin's resolved load root | what Claude Code loads |

Counts are per tree and never a single number. Reconciliation is three-way and
reports missing copies, content differences (hashed over the skill directory,
with chezmoi's `literal_` prefixes stripped so a source skill and its rendered
copy hash equal), count differences, per-harness enable-state differences, and
orphans. Drift between source and marketplace is closed by `chezmoi apply`
from `~/dotfiles` (chezmoi's configured source), which re-renders
`~/.agents/plugins`. A remote marketplace's cache needs a separate refresh from
Claude Code.

Claude Code registers plugin skills one level deep (`skills/<name>/SKILL.md`).
Nested sub-skills such as trycycle's `subskills/*` never become listing rows,
so a recursive `SKILL.md` count overstates a plugin.

### Where Claude Code loads plugins from

The load root depends on the marketplace type:

| Marketplace source | Load root |
|---|---|
| `directory` (this repo's `prateek-local`) | `installLocation` plus the manifest's relative `source`, i.e. `~/.agents/plugins/plugins/<pkg>` |
| `github`, `git`, `npm`, `url` (Chronosphere) | `~/.claude/plugins/cache/<marketplace>/<pkg>/<version>/` |

`installPath` in `claude plugin list --json` and `installed_plugins.json`
points at the versioned cache even for directory marketplaces and must not be
costed for them. An installed plugin whose marketplace manifest no longer lists
it is an orphan: it never loads, contributes no rows, and is skipped
(`public-config-api-release@chronosphere-claude-plugins` is one today).

### Harness enable state

Claude Code's enable state is the `enabledPlugins` map in merged settings: 15
keys of the form `<pkg>@<marketplace>`, 9 from `prateek-local` and 6 from
`chronosphere-claude-plugins`, all package-scoped. `claude plugin list --json`
exposes the same 15 plugins with nine fields including an `errors` array that
a strict reader has to tolerate.

The six Chronosphere plugins are not fixed overhead. Toggling one is the same
operation as toggling `design@prateek-local`, and the console offers it. Only
three of them contribute listing rows (`git-spice` 1, `programmable-platform`
6, `sleuth` 4 of 8; the rest ship their skills flagged upstream or are
orphaned), so toggling the others reclaims nothing. Their skill files live in
a tool-owned cache that the next marketplace update overwrites, so their
content is never edited.

The repo-managed home for third-party toggles is
`home/.chezmoitemplates/claude-settings-managed.json.tmpl`. It is
hand-authored, merges last in `home/dot_claude/modify_private_settings.json.tmpl`,
and already carries `skillListingBudgetFraction`; `set_package_enabled` and
`set_budget_fraction` write there. The generated fragment
`home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl` carries only
`@prateek-local` entries derived from `package.toml`, which is why a repo
package's enable state is `set_default_loaded` and never a hand-authored
`enabledPlugins` entry that would mask the generated one.

pi reads the generated marketplace but stores its own enable state in
`~/.pi/agent/claude-plugins.json`. Codex stores it under
`[plugins."<id>"] enabled` in `~/.codex/config.toml`; the Codex CLI is not
installed on this machine, and that file is chezmoi-ignored here, so its
contents are not authoritative. The row model carries `live_enabled` per
harness and the reconciler reports disagreement, but the pi and Codex readers
are not built; `build_rows(enable_state=)` is the seam for them.

### Usage snapshot

`priority` needs `skillUsage` from `~/.claude.json`, keyed by listing name.
Usage writes are debounced for 60 seconds, so invoking a skill while the page
is open can change rank. Each render captures usage with the rest of the
snapshot and records `now_ms` and `captured_at`. Usage records successful
invocation, not failed routing or the value of a rarely needed skill; the page
shows it as context, not as a recommendation.

## Implementation

### Files

```text
.agents/skills/agent-skill-management/
  scripts/skill-console                  CLI: argument parsing, orchestration, output
  scripts/skill_console/__init__.py      recovered constants, enums, frozen dataclasses, capability matrix
  scripts/skill_console/budget.py        measures, budget, row costs, admission, rank, /context cell, write_safe
  scripts/skill_console/inventory.py     settings merge, load roots, trees, listing capture, rows, snapshot
  scripts/skill_console/frontmatter.py   strict frontmatter parser and span-preserving editor
  scripts/skill_console/decisions.py     schema validation, planning, staging, staged validation, commit
  scripts/skill_console/builtins.json    hash-keyed built-in listing fixture
  templates/skill-console.html           the page; embeds its data in one JSON slot
tests/skill-console.zsh                  make test-skill-console
```

`scripts/skill-console` is a PEP 723 uv script with the same shebang pattern as
the other scripts in the skill and no dependencies (`dependencies = []`). The
package modules are stdlib plus `agent_skill_lib`; `apm.lock.yaml` is read by
a small line scanner rather than a YAML library. There is no `pyproject.toml`
or `uv.lock` under `.agents/`.

### Data model

Frozen dataclasses in `skill_console/__init__.py`:

| Type | What it is |
|---|---|
| `SkillRecord` | one skill directory in one tree: origin, frontmatter fields, content hash |
| `PackageRecord` | one repo package: `default_loaded`, render policy, per-tree skill counts |
| `ListingEntry` | exactly what admission needs: name, listing text, `protected`, `forced_name_only`, `rank` |
| `BudgetInputs`, `RowCost`, `Admission` | the pure algorithm's inputs and outputs |
| `Row` | one console row joined across trees, with `listed`, `repo_default`, `live_enabled` per harness, `usage`, `rank`, `rendered`, `capped`, `width_divergent`, `derived_description`, and divergences |
| `Snapshot`, `Predicted`, `Operation`, `Decisions`, `Violation` | the decisions document |

`rendered` is two-valued, `full` or `name-only`, and `None` for an unlisted
row. `capped` is a separate boolean. There is no `ambiguous` state: the console
reads the rendered attachment, so nothing is ambiguous.

### Capability matrix

There is no `editable` flag and no read-only rows. Each origin permits a set of
operations, and apply rule V14 is mechanical: reject any operation the target's
origin does not permit.

| origin | `set_description` | `set_frontmatter` | `delete_skill` | `set_default_loaded` [1] | `set_package_enabled` [1] |
|---|:--:|:--:|:--:|:--:|:--:|
| `repo-local` | yes | yes | no | yes | yes |
| `repo-vendor` | yes [2] | yes [2] | yes, 1:1 dependency only | yes | yes |
| `repo-project` | yes | yes | no | n/a | n/a |
| `user-skill` | no | no | no | n/a | n/a |
| `user-command` | no | no | no | n/a | n/a |
| `third-party-plugin` | no | no | no | n/a | yes |
| `builtin` | no | no | no | n/a | no |

1. These describe the row's package. The operation is keyed on the package,
   never on a skill. They stay separate ops because they write different files
   with different key shapes: `set_default_loaded` edits `package.toml` keyed
   `<pkg>`; `set_package_enabled` edits `claude-settings-managed.json.tmpl`
   keyed `<pkg>@<marketplace>`.
2. Vendored edits are not durable. The next `vendor-agent-package <pkg>` run
   for the owning APM dependency reverts them, the same way it restores a
   deleted skill. Apply permits them and prints a warning naming that
   invocation. The overlay or exclusion mechanism that would make them durable
   is the same prerequisite as shared-dependency deletion.

`set_budget_fraction` targets settings and belongs to no origin.

### Frontmatter parsing and editing

Budget arithmetic needs YAML's actual scalar value, and writes must not
reformat the file. `frontmatter.py` is a stdlib scanner for the YAML subset
frontmatter uses, following PyYAML `SafeLoader` semantics (YAML 1.1 implicit
types, PyYAML's block and flow folding rules) and rejecting duplicate keys
outright. It records the span of every top-level scalar so `edit` replaces one
value and leaves every other byte alone: style (`plain`, `single`, `double`,
`literal`, `folded`), chomping indicator, indentation, comments, and line
endings survive. When the original style cannot carry the new value it falls
back through literal and double-quoted, and it accepts a candidate only if the
whole file re-parses to exactly the requested value with nothing else changed.
A value is written as a plain scalar only when PyYAML would read it back as
one: no tab, no character PyYAML's reader refuses (C0 and C1 controls, DEL,
U+FFFE and U+FFFF, surrogates), and no leading `-`, `?`, or `:` followed by
whitespace or the end of the line. Anything else is double-quoted with those
characters escaped, and a multi-line value holding one of them is double-quoted
instead of becoming a block scalar.

The existing `agent_skill_lib.skill_frontmatter` is not reused for measurement
because its scalar handling diverges from what Claude Code measures on a
handful of skills; the console's parser agrees with PyYAML on every `SKILL.md`
in the tree.

### The page

`render` writes one self-contained HTML file with inline CSS and JS and no
network access. The data is injected into a single `<script type="application/json">`
slot. The page shows a budget panel (before and after meters, mode, demand,
rendered, headroom), the inventory grouped by package with each row's origin,
enable state per harness, flags, description length, rendering status, cost,
rank, and usage, a filter bar, a cross-tree divergences group, and a staged
operations panel with the `skillListingBudgetFraction` input, per-operation
problems, and an export button.

The browser does not port the algorithm. It re-runs the greedy loop over the
integer costs Python computed, and that loop is cross-tested under `node`
against the Python fixture tables. The one place it measures anything is a
description preview: text that passes a client-side copy of the write-safe
rule has `width == length - count(control chars)`, so the preview is exact;
text outside that class is refused with the reason shown, never estimated.
Python remains the authority: `apply` recomputes the witness and rejects a
mismatch (V19).

## Decisions document

One JSON object. `schema_version` and `operations` direct behavior; `snapshot`
gates it; `predicted` is a witness that is compared and never trusted as input.

```jsonc
{
  "schema_version": 1,
  "harness": "claude",

  "snapshot": {
    "console_version": "1",
    "binary_version": "2.1.258",
    "binary_hash": "sha256:…", "binary_hash_matched": true,
    "source_hash": "sha256:…", "marketplace_hash": "sha256:…", "cache_hash": "sha256:…",
    "settings_hash": "sha256:…", "usage_hash": "sha256:…",
    "model": "claude-fable-5-1", "context_window": 200000, "bytes_per_token": 3,
    "fraction": 0.04, "max_desc_chars": 1536, "budget_chars": 24000,
    "budget_env_override": null,
    "cwd": "/Users/prungta/code/worktrees/dotfiles/skill-length",
    "project_root": "/Users/prungta/code/worktrees/dotfiles/skill-length",
    "git_rev": "f253499…", "git_dirty": true,
    "now_ms": 1772409840000,
    "captured_at": "2026-09-01T18:24:00Z",
    "listing_capture_at": "2026-09-01T18:24:00Z"
  },

  "predicted": {
    "cap_chars": 24000,
    "mode_before": "priority", "mode_after": "priority",
    "demand_before": 29474,    "demand_after": 26180,
    "rendered_before": 23951,  "rendered_after": 23962,
    "full_before": 62,         "full_after": 66,
    "name_only_before": 21,    "name_only_after": 17,
    "newly_admitted": ["review:ci-autofix-loop", "core:decomment",
                       "utils-agent:orca-cli", "core:testing-philosophy"],
    "newly_dropped": [],
    "added_name_only": 0,
    "removed_name_only": 0
  },

  "operations": [
    { "op": "set_frontmatter", "target": "skill", "key": "utils-agent:shortcut",
      "field": "disable-model-invocation", "value": true },
    { "op": "set_description", "target": "skill", "key": "utils-agent:orca-stration",
      "from_chars": 214, "to_chars": 150, "text": "…" },
    { "op": "delete_skill", "target": "skill", "key": "obsidian-wiki:wiki-lint",
      "apm_dep": "ar9av/obsidian-wiki/.skills/wiki-lint",
      "dep_owns_skills": 1, "remove_apm_dep": true },
    { "op": "set_default_loaded", "target": "package", "key": "design", "value": false },
    { "op": "set_package_enabled", "target": "package",
      "key": "design@prateek-local", "value": false },
    { "op": "set_budget_fraction", "target": "settings", "key": "",
      "from_value": 0.04, "to_value": 0.05 }
  ]
}
```

The example is illustrative; the page generates real documents from a real
snapshot. Per-operation fields are exhaustive and any other field is an error:

| `op` | `target` | `key` | Fields | Writes |
|---|---|---|---|---|
| `set_description` | `skill` | qualified name | `from_chars`, `to_chars`, `text` | that skill's `SKILL.md` |
| `set_frontmatter` | `skill` | qualified name | `field` (`disable-model-invocation` or `user-invocable`), `value` (bool) | that skill's `SKILL.md` |
| `delete_skill` | `skill` | qualified name | `apm_dep`, `dep_owns_skills`, `remove_apm_dep` | removes the skill directory; with `remove_apm_dep`, edits `apm.yml` and `apm.lock.yaml` |
| `set_default_loaded` | `package` | package name | `value` | `package.toml`, plus the three committed templates the renderer derives from it |
| `set_package_enabled` | `package` | `<pkg>@<marketplace>` | `value` | `enabledPlugins` in `claude-settings-managed.json.tmpl` |
| `set_budget_fraction` | `settings` | `""` | `from_value`, `to_value` | `skillListingBudgetFraction` in the same template |

`from_chars` and `to_chars` are witnesses over the source description, the
text apply actually replaces, measured in UTF-16 units; apply recomputes both
and rejects a mismatch.

### Validation

Structural (`validate_document`), before anything live is read:

| Code | Rule |
|---|---|
| V1 | `schema_version == 1` |
| V2 | `harness == "claude"` |
| V3 | exactly the five top-level keys |
| V4 | `snapshot` and `predicted` carry exactly their declared fields, correct types |
| V5 | known `op`, and `target` matches the table |
| V6 | exactly the op's required fields; a `set_package_enabled` key matches `<pkg>@<marketplace>` over `[A-Za-z0-9._-]` |
| V7 | no duplicate `(op, key)` |
| V8 | `set_frontmatter.field` is an allowed field |
| V9 | `set_budget_fraction.to_value` in `(0, 1]` |

Against live state (`validate_against_live`), after the inventory is rebuilt
with the snapshot's model, window, and `now_ms`:

| Code | Rule |
|---|---|
| V10 | every hash and every recorded input matches a fresh one; the binary hash must match on both sides |
| V11 | `now_ms` within 24 hours of the wall clock, unless `--allow-stale` |
| V12 | `cwd` and `project_root` match the invocation |
| V13 | every `key` names something in the snapshot; a repo package's `set_package_enabled` key names `prateek-local`, the only marketplace it is installed from |
| V14 | the capability matrix permits the operation, including the 1:1-dependency rule for deletion |
| V15 | no conflicts: no content edit on a skill whose package is being disabled in the same document; no edit on a skill also being deleted |
| V16 | `from_chars` equals the live length, `to_chars` equals the new text's length, and the text is write-safe |
| V17 | `dep_owns_skills` and `apm_dep` match `SOURCE.md`; `remove_apm_dep` only when the count is 1 |
| V18 | `set_budget_fraction.from_value` equals the live fraction |
| V19 | the recomputed `predicted` equals the witness field for field |

Every generated document satisfies:

```text
name_only_after == name_only_before
                   - removed_name_only + added_name_only
                   - len(newly_admitted) + len(newly_dropped)
```

With `B` the listed set before and `A` after: `newly_admitted` and
`newly_dropped` range over `A ∩ B`; `removed_name_only` counts rows in `B \ A`
that were name-only; `added_name_only` counts rows in `A \ B` that are
name-only after. The two membership terms matter because `delete_skill`,
`set_frontmatter`, and both package toggles change the listed set.

## Apply semantics

Dry run is the default. `apply` runs these steps in order:

1. Load the document and check V1 through V9.
2. Rebuild the live inventory with the snapshot's model, context window, and
   `now_ms`, recompute the witness, and check V10 through V19.
3. Plan the per-path edits. Refuse if any target path is dirty in git. The
   check is scoped to target paths because the worktree is shared and
   unrelated paths are legitimately dirty. `--allow-dirty-targets` overrides it
   loudly, forfeits recovery, and requires `--commit`. Planning also refuses a
   target path that is a symlink (`is a symlink; edit the file it points to
   instead`; skill directories that are symlinks resolve to their real path)
   and any settings key or value containing `{{` or `}}`, because
   `claude-settings-managed.json.tmpl` is a Go template that chezmoi and the
   staged make targets render.
4. Stage: copy the working tree minus `.git` into a temp root under
   `$XDG_STATE_HOME/dotfiles/skill-console/staging/` and apply every edit in
   the copy. The working tree, not `HEAD`, because a `HEAD` copy would validate
   a different tree than the one being edited.
5. Validate the copy: `validate-agent-packages`, then
   `make test-agent-skill-packages test-claude-settings test-codex-config test-pi-settings`
   from inside it. Any failure exits 4 before the worktree is touched.
6. Without `--commit`: print the witness, the operation and path counts, and
   the unified diff, then exit 0. With `--commit`: first re-run every
   `delete_skill` precondition (the tracked-reference scan and the APM
   dependency's skill count, carried on the plan as `guards`) and refuse the
   whole batch with nothing applied if either changed since planning; then
   replace each path with a single atomic rename after re-checking its hash
   against the one read at planning time and that it has not become a
   symlink. A `delete_skill` commits as an in-place directory removal with the
   tree hash checked recursively. The batch as a whole is not atomic.
7. Stop before `chezmoi apply`. Print the changed paths and the
   `git diff -- <paths>` to review them with.

On a mid-commit failure (exit 5) the console names the applied and unapplied
paths, leaves the staging copy in place, and prints the recovery command:
`git restore -- <applied paths>`. A removal that fails partway leaves the
surviving files at their own path and lists the directory among the applied
paths, so the same command rebuilds it; a removal that failed before touching
anything is not listed. Step 3's clean-target precondition makes recovery
safe, because every applied path was tracked and clean before the first write,
so restoring it cannot revert another writer's work. Git is the journal; there
is no bespoke journal file and no `--rollback`. The residual exposure is small
by construction: nothing under `~/.agents` moves and `chezmoi apply` never
runs, so a partial batch is an inert, visible, revertible source-tree diff.

The per-path hash check narrows the overwrite window to the gap between the
check and the rename; a writer landing inside that gap is still lost. Staging
keeps validation failures out of the worktree; it does not make the commit
transactional.

When an operation edits a `package.toml`, the plan also regenerates the three
committed templates the renderer derives from it
(`agent-codex-plugin-config.toml.tmpl`, `agent-claude-plugin-settings.json.tmpl`,
`dot_pi/agent/claude-plugins.json.tmpl`) by running the real
`render-agent-plugin-marketplace` in a scratch copy, so `--check` inside the
staged validation passes and the generator's format is never duplicated.

`--keep-staged` preserves the staging root on success; it is always preserved
on exit 4 or 5.

### Exit codes

| Code | Meaning |
|---:|---|
| 0 | success, including a clean dry run |
| 1 | usage error: unknown flag, missing argument, unreadable file, `--allow-dirty-targets` without `--commit` |
| 2 | discovery failure: model or context window unresolved, built-in fixture or template missing |
| 3 | validation failure: V1 through V19, a dirty target path, or an unplannable operation |
| 4 | staged validation failure: `validate-agent-packages` or a make target failed in the copy |
| 5 | partial commit: some paths applied, some not; recovery command printed |

Every non-zero exit prints one `skill-console: <reason>` line to stderr first.
Under `--json`, stdout still carries a structured payload with
`{"ok": false, "code": N, "violations": [...]}`.

### Vendored-skill deletion

APM dependencies have a many-to-one relationship with vendored skills:

| APM dependency | Skills owned |
|---|---:|
| `mattpocock/skills` | 25 |
| `raintree-technology/apple-hig-skills` | 14 |
| `nextlevelbuilder/ui-ux-pro-max-skill` | 7 |
| `kepano/obsidian-skills` | 5 |

The repo has 107 vendored skills. Four dependencies own 51 of them and 56
dependencies own one each. Deletion follows these rules:

- Only `skills/vendor/*` directories can be deleted; local skills never.
- The owning dependency comes from the skill's `SOURCE.md`. `dep_owns_skills`
  is recomputed and a mismatch is refused (V17).
- `remove_apm_dep` is offered only for a dependency that owns one skill; it
  removes the dependency from `apm.yml` and its block from `apm.lock.yaml`.
- Deleting a skill from a shared dependency is refused (V14) until an exclusion
  mechanism that survives re-vendoring exists. Keeping the dependency without
  one means the next `vendor-agent-package <pkg>` run restores the skill under
  the lockfile's skill id.
- Deletion is refused while a tracked file under `tests/`, `.agents/`, or
  `home/` still references the skill; references under `docs/` only warn.
- The staged copy omits the skill, which is what lets
  `validate-agent-packages` see the post-delete tree. Only the commit action
  differs: a removal rather than a move into place.

## Tests

`tests/skill-console.zsh`, run by `make test-skill-console`, generates its
fixtures into a temp directory in the exact `{inputs, entries}` shape
`skill-console budget --fixture` reads, and never touches the real `~/.claude`,
`~/.agents`, or `~/.claude.json`. It covers:

- the algorithm: `fits` at exactly the budget and `priority` one character
  under, the separator charged once, a miss not stopping the walk, stable
  tie-breaking in both listing orders, every row protected, the empty listing,
  duplicate names, the 1536 cap flipping at 1537 UTF-16 units, the model-id
  normalization pipeline, the environment budget (`Infinity` and fractional
  values included) and the floor of one, rank decay, the `/context` cell's
  half-up rounding, forced name-only rows, and estimator parity through
  `--measure utf16`;
- measurement: six chomping indicators with six different costs, a folded
  scalar keeping a blank line as a newline, the width guard, grapheme-cluster
  widths against Bun's answers, and `when_to_use`;
- loading: derived descriptions, verbatim `when_to_use`, the plugin listing
  rule, ancestor skill and command directories, `localeCompare` order,
  `disableBundledSkills`, the fraction warning, and `CLAUDE_CONFIG_DIR`;
- frontmatter: strict parse of every `SKILL.md` in the tree, surgical edits
  that preserve style, and unsafe plain scalars written double-quoted;
- decisions: the witness invariant on generated documents, every capability
  matrix `no` cell refusing, a negative fixture for every validation code, and
  plan, stage, staged validation, and commit against a throwaway git copy of
  the worktree, including `git restore` recovery after a forced partial
  commit, a template action in a plugin key never reaching the template, a
  symlinked `SKILL.md` refused at plan and at commit, `delete_skill` planning
  and committing the tree, `apm.yml`, and `apm.lock.yaml`, a failed tree
  removal leaving the skill at its own path, and deletion preconditions
  re-checked at commit;
- the browser loop under `node` against the Python tables, the browser's
  `writeSafe` against `write_safe` over the whole BMP, and the constants
  against the live binary when its hash matches;
- the CLI: the budget seam, exit codes, `CLAUDE_CONFIG_DIR` with the built-in
  kill switch, and a dry-run `apply` end to end.

Cases that need `node` or a hash-matching `claude` binary print a notice and
are listed as not executable where those are absent; the suite still exits 0
for them so it can run in CI.

## Phases

| Phase | Scope | State |
|---|---|---|
| 1. Simulation library | constants, measures, budget, admission, rank, estimator, frontmatter reader, built-in fixture | built |
| 2. Console | `render`: inventory across trees and harnesses, budget panel, per-row status, drift, capture comparison | built |
| 3. Decisions and apply | page controls, decisions export, `apply` with staging, validation, path-by-path commit, vendored deletion for 1:1 dependencies | built |
| 4. Cross-harness budget projection | pi and Codex budgets | future work |

Phase 4 will add budget projections for pi and Codex after reading how each
one serializes its listing; Claude Code's algorithm cannot be assumed to carry
over. Both assemble their listings locally (pi is installed here; Codex is a
public repo), and both have a repo-managed enable state to key the projection
to. Phase 2's inventory already covers their trees.

## Open items

- The statusline state file that would supply the model id and context window
  is not written yet, so `--model` and `--context-window` are required on
  every render. The writer is a small addition to
  `home/dot_claude/executable_statusline.sh` (which already binds
  `.context_window.context_window_size`), writing atomically, one file per
  session, with `cwd` so the console can pick the right file instead of the
  newest. A capture taken in plan mode carries a substituted model id and
  must be flagged.
- The pi and Codex enable-state readers (`~/.pi/agent/claude-plugins.json`,
  `~/.codex/config.toml`) are not implemented; until they are, cross-harness
  enable drift is reported only for whatever `build_rows(enable_state=)`
  receives.
- `set_package_enabled` is planned but never committed in the tests, and
  `set_budget_fraction`'s plan and commit paths
  (`claude-settings-managed.json.tmpl`) have no end-to-end coverage; CLI-level
  exits 4 and 5 are exercised only at the module level.
- What the binary does with a `skillListingBudgetFraction` above 1, outside
  its settings schema, is unverified; the console keeps the value and warns.
- A deleted vendored skill's deployed copy under `~/.agents/packages` is not
  pruned. Nothing reads that tree, and `home/.chezmoiremove` is the eventual
  home for the cleanup.
- Vendored edits and shared-dependency deletion both wait on an overlay or
  exclusion mechanism that survives `vendor-agent-package`.
- Usage is shown as context, but the question of how to present it stays open:
  `priority` strips the description from a rarely used skill, which makes
  future routing to it less likely, and usage cannot see failed routing or the
  value of a skill needed once a quarter.

## Non-goals

- Installing skills from upstream. The console covers the 89 skills already in
  the repo's disabled packages (71 vendored, 18 local).
- Editing third-party plugin content. Their enable state is a supported
  toggle; their skill files are a tool-owned cache.
- Projecting a cursor-agent budget. Its agent loop runs server-side, so no
  listing is locally observable and any number would be invented. It still
  honors `disable-model-invocation`, so the flag's effect there is reported as
  inventory.
- Writing from the browser.
- Running `chezmoi apply`, or touching `~/.agents`, `~/.claude`, `~/.codex`,
  `~/.pi`, or any plugin cache. Those are read-only inputs.
- Running a persistent daemon or served application.
