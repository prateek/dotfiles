#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

cd "$REPO_ROOT"

scripts_dir="$REPO_ROOT/.agents/skills/agent-skill-management/scripts"
console_dir="$scripts_dir/skill_console"
template="$REPO_ROOT/.agents/skills/agent-skill-management/templates/skill-console.html"
fixtures="$tmp_root/fixtures"
isolated_home="$tmp_root/home"
mkdir -p "$fixtures" "$isolated_home" "$tmp_root/state"

# Modules still being written land as files; a case that needs one is reported
# as not executable while the file is absent. A module that exists but fails to
# import is a real failure and must not be mistaken for "not landed yet".
module_present() { [[ -f "$console_dir/$1.py" ]] }
frontmatter_ready=0; module_present frontmatter && frontmatter_ready=1
inventory_ready=0; module_present inventory && inventory_ready=1
cli_ready=$(( frontmatter_ready && inventory_ready ))
builtins_ready=0; [[ -f "$console_dir/builtins.json" ]] && builtins_ready=1

typeset -a not_executable
skip() {
  not_executable+=("$1")
  print -u2 -- "skill-console: not executable: $1 ($2)"
}

# Tests never read the real ~/.claude, ~/.agents, or ~/.claude.json, and never
# write staging state under the real XDG_STATE_HOME.
py() {
  PYTHONPATH="$scripts_dir:$tmp_root" HOME="$isolated_home" XDG_STATE_HOME="$tmp_root/state" \
    uv run --quiet --no-project --python '>=3.14' python - "$@"
}
console() {
  HOME="$isolated_home" XDG_STATE_HOME="$tmp_root/state" "$scripts_dir/skill-console" "$@"
}

# The fixture reader mirrors `skill-console budget --fixture` exactly, so the
# same JSON tables drive the algorithm today and the CLI once it imports.
cat >"$tmp_root/sc_harness.py" <<'PY'
import json
import sys
from pathlib import Path

from skill_console import BudgetInputs, ListingEntry
from skill_console.budget import admit, display_width, listing_text

CASE = sys.argv[1] if len(sys.argv) > 1 else "?"


def check(condition, message):
    if not condition:
        sys.exit(f"skill-console test failed [{CASE}]: {message}")


def fixture_entry(item):
    if "listing_text" in item:
        text = str(item["listing_text"])
    else:
        when_to_use = item.get("when_to_use")
        text = listing_text(str(item["description"]), None if when_to_use is None else str(when_to_use))
    return ListingEntry(
        name=str(item["name"]),
        listing_text=text,
        protected=bool(item.get("protected", False)),
        forced_name_only=bool(item.get("forced_name_only", False)),
        rank=float(item.get("rank", 0.0)),
    )


def load_fixture(path):
    fixture = json.loads(Path(path).read_text())
    inputs = BudgetInputs(**{"env_budget": None, **fixture["inputs"]})
    return inputs, [fixture_entry(item) for item in fixture["entries"]]


def run(path, measure=display_width):
    inputs, entries = load_fixture(path)
    return admit(entries, inputs, measure=measure), entries, inputs


def write_fixture(path, inputs, entries):
    Path(path).write_text(json.dumps({"inputs": inputs, "entries": entries}, ensure_ascii=False, indent=1))
PY

# Budgets below come from the computed path (window * bytes/token * fraction)
# unless a case is about the env override, so every number is traceable.
budget_inputs() {
  print -- "{\"context_window\": $1, \"bytes_per_token\": 1, \"fraction\": 1.0, \"max_desc_chars\": 1536}"
}

# --- 1. fits at exactly the budget, priority one character under ------------
cat >"$fixtures/at-budget.json" <<JSON
{"inputs": $(budget_inputs 61), "entries": [
  {"name": "a:one", "description": "0123456789"},
  {"name": "a:two", "description": "0123456789"},
  {"name": "a:three", "description": "0123456789"}
]}
JSON
cat >"$fixtures/one-over.json" <<JSON
{"inputs": $(budget_inputs 60), "entries": [
  {"name": "a:one", "description": "0123456789"},
  {"name": "a:two", "description": "0123456789"},
  {"name": "a:three", "description": "0123456789"}
]}
JSON
py "01 fits and priority" "$fixtures" <<'PY'
import sys
from sc_harness import check, run
from skill_console import Rendered

fixtures = sys.argv[2]
fits, entries, _ = run(f"{fixtures}/at-budget.json")
check(fits.budget == 61, f"budget {fits.budget} != 61")
check(fits.mode == "fits", f"mode {fits.mode!r} at exactly the budget")
check(fits.demand_chars == 61, f"demand {fits.demand_chars} != 61")
check(fits.rendered_chars == fits.demand_chars, "fits mode must render the whole demand")
check(fits.headroom_chars == 0, f"headroom {fits.headroom_chars} != 0")
check(fits.full == ("a:one", "a:two", "a:three") and fits.name_only == (), "every row full in fits mode")
check(all(state is Rendered.FULL for state in fits.rendered.values()), "rendered map disagrees with full tuple")
check([c.full_cost for c in fits.costs] == [19, 19, 21], f"full costs {[c.full_cost for c in fits.costs]}")
check([c.name_only_cost for c in fits.costs] == [7, 7, 9], "name-only costs")
check([c.upgrade_cost for c in fits.costs] == [12, 12, 12], "upgrade costs")
check(not fits.all_pinned and not fits.budget_from_env and fits.capped == (), "flags in fits mode")

priority, _, _ = run(f"{fixtures}/one-over.json")
check(priority.mode == "priority", f"mode {priority.mode!r} one character under")
check(priority.demand_chars == 61, "demand does not depend on the budget")
check(priority.full == ("a:one", "a:two"), f"full {priority.full}")
check(priority.name_only == ("a:three",), f"name-only {priority.name_only}")
check(priority.rendered_chars == 49, f"rendered {priority.rendered_chars} != 49")
check(priority.headroom_chars == 11, f"headroom {priority.headroom_chars} != 11")
check(priority.rendered["a:three"] is Rendered.NAME_ONLY, "rendered map for the dropped row")
PY

# --- 6. the separator is charged once, not per admitted row -----------------
# Headroom is exactly three upgrades; charging a separator per admission would
# stop at two.
cat >"$fixtures/separator-once.json" <<JSON
{"inputs": $(budget_inputs 59), "entries": [
  {"name": "p:a", "description": "0123456789"},
  {"name": "p:b", "description": "0123456789"},
  {"name": "p:c", "description": "0123456789"},
  {"name": "p:d", "description": "0123456789"}
]}
JSON
py "06 separator charged once" "$fixtures/separator-once.json" <<'PY'
import sys
from sc_harness import check, run

admission, _, _ = run(sys.argv[2])
check(admission.mode == "priority", f"mode {admission.mode!r}")
check(admission.demand_chars == 71, f"demand {admission.demand_chars} != 4*17 + 3")
check(admission.full == ("p:a", "p:b", "p:c"), f"full {admission.full}; a per-row separator would admit only two")
check(admission.name_only == ("p:d",), f"name-only {admission.name_only}")
check(admission.rendered_chars == 59 and admission.headroom_chars == 0, "the admitted rows fill the budget exactly")
PY

# --- 7. a miss does not stop the walk ---------------------------------------
cat >"$fixtures/greedy-non-stop.json" <<JSON
{"inputs": $(budget_inputs 39), "entries": [
  {"name": "w:wide", "description": "$(printf '%*s' 40 '' | tr ' ' x)", "rank": 1.0},
  {"name": "w:narrow", "description": "short", "rank": 0.5}
]}
JSON
py "07 greedy non-stop" "$fixtures/greedy-non-stop.json" <<'PY'
import sys
from sc_harness import check, run

admission, _, _ = run(sys.argv[2])
costs = {c.name: c for c in admission.costs}
check(costs["w:wide"].upgrade_cost == 42 and costs["w:narrow"].upgrade_cost == 7, "fixture upgrade costs")
check(admission.mode == "priority", f"mode {admission.mode!r}")
check(admission.full == ("w:narrow",), f"full {admission.full}; the walk must continue past the wide miss")
check(admission.name_only == ("w:wide",), f"name-only {admission.name_only}")
check(admission.rendered_chars == 19 + 7, f"rendered {admission.rendered_chars}")
PY

# --- 8. equal ranks keep listing order, in both directions -------------------
rows_forward='{"name": "t:r1", "description": "0123456789"}, {"name": "t:r2", "description": "0123456789"}, {"name": "t:r3", "description": "0123456789"}, {"name": "t:r4", "description": "0123456789"}, {"name": "t:r5", "description": "0123456789"}'
rows_reversed='{"name": "t:r5", "description": "0123456789"}, {"name": "t:r4", "description": "0123456789"}, {"name": "t:r3", "description": "0123456789"}, {"name": "t:r2", "description": "0123456789"}, {"name": "t:r1", "description": "0123456789"}'
print -- "{\"inputs\": $(budget_inputs 58), \"entries\": [$rows_forward]}" >"$fixtures/ties-forward.json"
print -- "{\"inputs\": $(budget_inputs 58), \"entries\": [$rows_reversed]}" >"$fixtures/ties-reversed.json"
py "08 stable tie-break" "$fixtures" <<'PY'
import sys
from sc_harness import check, run

fixtures = sys.argv[2]
forward, _, _ = run(f"{fixtures}/ties-forward.json")
check(forward.mode == "priority" and forward.headroom_chars == 0, "fixture must admit exactly two rows")
check(forward.full == ("t:r1", "t:r2"), f"forward full {forward.full}")
check(forward.name_only == ("t:r3", "t:r4", "t:r5"), f"forward name-only {forward.name_only}")
reversed_, _, _ = run(f"{fixtures}/ties-reversed.json")
check(reversed_.full == ("t:r5", "t:r4"), f"reversed full {reversed_.full}; ties must follow listing order")
check(reversed_.name_only == ("t:r3", "t:r2", "t:r1"), f"reversed name-only {reversed_.name_only}")
PY

# --- 9. every row protected: full, over budget, no exception -----------------
cat >"$fixtures/all-pinned.json" <<JSON
{"inputs": $(budget_inputs 1), "entries": [
  {"name": "commit", "description": "Create a git commit", "protected": true},
  {"name": "review", "description": "Review a pull request", "protected": true},
  {"name": "compact", "description": "Compact the conversation", "protected": true}
]}
JSON
py "09 all pinned" "$fixtures/all-pinned.json" <<'PY'
import sys
from sc_harness import check, run
from skill_console.budget import render_listing

admission, entries, inputs = run(sys.argv[2])
check(admission.budget == 1, f"budget {admission.budget}")
check(admission.mode == "priority", f"mode {admission.mode!r}")
check(admission.all_pinned, "all_pinned must be set")
check(admission.full == ("commit", "review", "compact") and admission.name_only == (), "every protected row renders full")
check(admission.rendered_chars == admission.demand_chars > admission.budget, "rendered equals demand and exceeds the budget")
check(admission.headroom_chars == admission.budget - admission.rendered_chars < 0, "headroom is negative, not clamped")
listing = render_listing(entries, inputs)
check(listing == "- commit: Create a git commit\n- review: Review a pull request\n- compact: Compact the conversation", repr(listing))
check(len(listing) == admission.rendered_chars, "rendered_chars must equal the emitted text length")
PY

# --- 10. empty listing ------------------------------------------------------
cat >"$fixtures/empty.json" <<JSON
{"inputs": $(budget_inputs 1000), "entries": []}
JSON
py "10 empty listing" "$fixtures/empty.json" <<'PY'
import sys
from sc_harness import check, run
from skill_console.budget import render_listing

admission, entries, inputs = run(sys.argv[2])
check(render_listing(entries, inputs) == "", "empty listing must render as the empty string")
check(admission.mode == "fits", f"mode {admission.mode!r}")
check(admission.demand_chars == 0 and admission.rendered_chars == 0, "zero-cost admission")
check(admission.headroom_chars == admission.budget == 1000, "headroom is the whole budget")
check(admission.costs == () and admission.full == () and admission.name_only == () and admission.rendered == {}, "no rows anywhere")
check(not admission.all_pinned, "an empty listing is not all-pinned")
PY

# --- 11. duplicate names are charged twice by admit; dedupe is inventory's ---
cat >"$fixtures/duplicates.json" <<JSON
{"inputs": $(budget_inputs 1000), "entries": [
  {"name": "d:same", "description": "first occurrence"},
  {"name": "d:same", "description": "second occurrence, longer"}
]}
JSON
py "11 duplicate names in admit" "$fixtures/duplicates.json" <<'PY'
import sys
from sc_harness import check, run

admission, entries, _ = run(sys.argv[2])
check(len(admission.costs) == 2, "both duplicates must be costed")
check(admission.demand_chars == (10 + 16) + (10 + 25) + 1, f"demand {admission.demand_chars}; both rows charged plus one separator")
check(admission.full == ("d:same", "d:same"), f"full {admission.full}")
check(list(admission.rendered) == ["d:same"], "rendered map keys by name")
PY
if (( inventory_ready )); then
  py "11 duplicate names deduped by entries_for" <<'PY'
from pathlib import Path

from sc_harness import check
from skill_console import Origin, Row, SkillRecord, Tree
from skill_console.inventory import entries_for


def record(description):
    return SkillRecord(
        tree=Tree.SOURCE, package="d", directory="same", path=Path("/nonexistent/d/skills/local/same"),
        origin=Origin.REPO_LOCAL, frontmatter_name="same", description=description, when_to_use=None,
        disable_model_invocation=False, user_invocable=True, content_sha256="0" * 64,
    )


def row(description):
    rec = record(description)
    return Row(
        name="d:same", directory="same", package="d", origin=Origin.REPO_LOCAL, protected=False,
        source_record=rec, marketplace_record=rec, cache_record=rec, listed=True, repo_default=True,
        live_enabled={}, usage=None, rank=0.0, rendered=None, capped=False, width_divergent=False,
        derived_description=False, divergences=(),
    )


entries = entries_for([row("first occurrence"), row("second occurrence")])
check([entry.name for entry in entries] == ["d:same"], f"entries_for must dedupe by name: {[e.name for e in entries]}")
check(entries[0].listing_text == "first occurrence", f"first occurrence must win, got {entries[0].listing_text!r}")
PY
else
  skip "11 duplicate names deduped by entries_for" "skill_console/inventory.py not on disk"
fi

# --- 12. the 1536 cap flips at 1537 UTF-16 units ----------------------------
py "12 cap boundary" "$fixtures/cap-boundary.json" <<'PY'
import sys
from sc_harness import check, run, write_fixture
from skill_console import ELLIPSIS, ListingEntry
from skill_console.budget import cap_description, row_cost, utf16_length

name = "c:cap"
def entry(text):
    return ListingEntry(name=name, listing_text=text, protected=False, forced_name_only=False, rank=0.0)

for units, expect_capped in ((1535, False), (1536, False), (1537, True)):
    cost = row_cost(entry("x" * units), 0, max_desc_chars=1536)
    check(cost.capped is expect_capped, f"{units} units: capped={cost.capped}")
    expected = (1536 if expect_capped else units) + len(name) + 4
    check(cost.full_cost == expected, f"{units} units: full_cost {cost.full_cost} != {expected}")
    check(cost.name_only_cost == len(name) + 2, "name-only cost ignores the description")

text, capped = cap_description("x" * 1537, 1536)
check(capped and text.endswith(ELLIPSIS) and utf16_length(text) == 1536, "capped text is 1535 units plus the ellipsis")
check(text[:1535] == "x" * 1535, "the cap keeps the first 1535 units")
# The cap counts UTF-16 units: an astral character is two, so 1535 ASCII + one
# emoji is over the cap even though Python sees 1536 characters.
astral = "x" * 1535 + "\U0001F600"
check(len(astral) == 1536 and utf16_length(astral) == 1537, "fixture: astral text is 1537 units")
text, capped = cap_description(astral, 1536)
check(capped and text == "x" * 1535 + ELLIPSIS, "the slice happens in UTF-16 units")

write_fixture(sys.argv[2], {"context_window": 100000, "bytes_per_token": 1, "fraction": 1.0, "max_desc_chars": 1536}, [
    {"name": "c:under", "description": "x" * 1535},
    {"name": "c:at", "description": "x" * 1536},
    {"name": "c:over", "description": "x" * 1537},
])
admission, _, _ = run(sys.argv[2])
check(admission.capped == ("c:over",), f"capped tuple {admission.capped}")
check([c.full_cost for c in admission.costs] == [1535 + 11, 1536 + 8, 1536 + 10], "fixture full costs")
PY

# --- 13. bytes_per_token needs the whole normalization pipeline -------------
py "13 bytes_per_token" <<'PY'
from sc_harness import check
from skill_console import LEGACY_BYTES_PER_TOKEN_FAMILIES
from skill_console.budget import bytes_per_token, normalize_model_id

expected = {
    "claude-fable-5-1": 3,
    "claude-opus-5": 3,
    "claude-haiku-4-5-20251001": 4,
    "claude-haiku-4-5@20251001": 4,
    "claude-opus-4-5[1m]": 4,
    "us.anthropic.claude-opus-4-5-v1:0": 4,
    "eu.anthropic.claude-sonnet-4-5": 4,
    "claude-opus-4": 4,
    "claude-opus-4-9": 3,
}
for model_id, value in expected.items():
    check(bytes_per_token(model_id) == value, f"{model_id}: {bytes_per_token(model_id)} != {value}")
# The divergent forms are exactly the ones a literal lookup gets wrong.
naive = {model_id for model_id in expected if model_id in LEGACY_BYTES_PER_TOKEN_FAMILIES}
check(naive == set(), f"fixture ids must not be literal set members: {naive}")
check(normalize_model_id("claude-opus-4") == "claude-opus-4-0", "regex branch for a bare major")
check(normalize_model_id("claude-sonnet-4") == "claude-sonnet-4-0", "regex branch for sonnet")
check(normalize_model_id("claude-opus-4-9") == "claude-opus-4-9", "no literal, no regex, no date suffix")
check(normalize_model_id("custom-model-20250101") == "custom-model", "date-suffix fallback")
check(normalize_model_id("claude-opus-4-5[1m]") == "claude-opus-4-5", "[1m] strip")
PY

# --- 14/15. env budget and the floor of one ---------------------------------
py "14 env budget" <<'PY'
from sc_harness import check
from skill_console import BudgetInputs
from skill_console.budget import admit, budget_chars, parse_env_budget

computed = 200_000 * 3 * 0.04
def inputs(raw):
    return BudgetInputs(context_window=200_000, bytes_per_token=3, fraction=0.04, max_desc_chars=1536, env_budget=parse_env_budget(raw))

check(parse_env_budget(None) is None and budget_chars(inputs(None)) == computed, "unset -> computed")
check(parse_env_budget("0") == 0 and budget_chars(inputs("0")) == computed, '"0" -> computed')
check(parse_env_budget("1200") == 1200 and budget_chars(inputs("1200")) == 1200, '"1200" -> 1200')
check(parse_env_budget("-5") == -5 and budget_chars(inputs("-5")) == -5, '"-5" is used verbatim')
check(parse_env_budget("banana") is None and budget_chars(inputs("banana")) == computed, "NaN -> computed")
for raw, from_env in ((None, False), ("0", False), ("1200", True), ("-5", False)):
    admission = admit([], inputs(raw))
    check(admission.budget_from_env is from_env, f"{raw!r}: budget_from_env {admission.budget_from_env}")
check(admit([], inputs("-5")).budget == -5, "a negative env budget survives into the Admission")
PY
py "15 max(1, floor)" <<'PY'
from sc_harness import check
from skill_console import BudgetInputs
from skill_console.budget import budget_chars

tiny = BudgetInputs(context_window=1, bytes_per_token=4, fraction=0.0001, max_desc_chars=1536, env_budget=None)
check(budget_chars(tiny) == 1, f"budget {budget_chars(tiny)} != 1")
fractional = BudgetInputs(context_window=333, bytes_per_token=3, fraction=0.01, max_desc_chars=1536, env_budget=None)
check(budget_chars(fractional) == 9, f"floor(9.99) -> {budget_chars(fractional)}")
PY

# --- 14b. env budget: the JS number is used unrounded -----------------------
cat >"$fixtures/env-infinity.json" <<JSON
{"inputs": {"context_window": 1000, "bytes_per_token": 1, "fraction": 1.0, "max_desc_chars": 1536, "env_budget": Infinity}, "entries": [
  {"name": "e:a", "description": "0123456789"},
  {"name": "e:b", "description": "0123456789", "protected": true}
]}
JSON
cat >"$fixtures/env-half.json" <<JSON
{"inputs": {"context_window": 1000, "bytes_per_token": 1, "fraction": 1.0, "max_desc_chars": 1536, "env_budget": 0.5}, "entries": [
  {"name": "e:a", "description": "0123456789"},
  {"name": "e:b", "description": "0123456789", "protected": true}
]}
JSON
py "14b env budget floats" "$fixtures/env-infinity.json" "$fixtures/env-half.json" <<'PY'
import math
import sys
from sc_harness import check, run
from skill_console.budget import parse_env_budget

# Zx(): Number() first, grouped digits second; iTe() then uses the number as-is.
for raw, want in {"Infinity": math.inf, "1e400": math.inf, "0.5": 0.5, "30000": 30000, "-5": -5,
                  "0": 0, "": 0, "-0": 0, "abc": None, "NaN": None, "1_000": 1000, "0x10": 16, " 24,000 ": 24000}.items():
    got = parse_env_budget(raw)
    check(got is None if want is None else got == want, f"parse_env_budget({raw!r}) -> {got!r}")
    check(want is None or type(got) is type(want), f"{raw!r}: integral values are int, others float ({type(got).__name__})")
inf, _, _ = run(sys.argv[2])
check(inf.mode == "fits" and inf.budget == math.inf and inf.budget_from_env, f"Infinity: {inf.mode} {inf.budget}")
check(set(inf.full) == {"e:a", "e:b"} and inf.headroom_chars == math.inf, "Infinity: everything full, infinite headroom")
half, _, _ = run(sys.argv[3])
check(half.mode == "priority" and half.budget == 0.5, f"0.5: {half.mode} {half.budget}")
check(half.full == ("e:b",) and half.name_only == ("e:a",), "0.5: protected row full, candidate never admitted")
check(half.rendered_chars == len("- e:b: 0123456789") + len("- e:a") + 1, f"0.5: rendered {half.rendered_chars} stays an exact integer")
check(half.headroom_chars == 0.5 - half.rendered_chars, "0.5: headroom keeps the fractional budget")
PY
console budget --fixture "$fixtures/env-infinity.json" --json >"$tmp_root/env-infinity.out"
py "14b env budget CLI" "$tmp_root/env-infinity.out" <<'PY'
import json
import sys
from sc_harness import check

payload = json.load(open(sys.argv[2]))
# JSON has no Infinity literal, so the CLI spells it as a string; the page turns it back into a Number.
check(payload["budget"] == "Infinity" and payload["mode"] == "fits", payload["budget"])
check(payload["listing"] == "- e:a: 0123456789\n- e:b: 0123456789", payload["listing"])
PY

# --- 16. rank: half-life seven days, floor 0.1, no clamp on future use ------
py "16 rank" <<'PY'
import math
from sc_harness import check
from skill_console import MS_PER_DAY, Usage
from skill_console.budget import rank

now = 1_772_409_840_000
def used(days_ago, count=4):
    return Usage(usage_count=count, last_used_at_ms=now - int(days_ago * MS_PER_DAY))

check(rank(None, now) == 0.0, "never used")
check(rank(used(0), now) == 4.0, f"used today: {rank(used(0), now)}")
check(math.isclose(rank(used(7), now), 2.0), f"seven days: {rank(used(7), now)}")
check(math.isclose(rank(used(14), now), 1.0), f"fourteen days: {rank(used(14), now)}")
check(math.isclose(rank(used(60), now), 0.4), f"sixty days hits the floor: {rank(used(60), now)}")
check(rank(used(23), now) > 0.4 > rank(used(24), now) - 1e-9 and math.isclose(rank(used(24), now), 0.4), "the floor takes over between day 23 and 24")
check(math.isclose(rank(used(-7), now), 8.0), f"future use is unclamped: {rank(used(-7), now)}")
check(rank(used(0, count=0), now) == 0.0, "zero count ranks zero even when fresh")
PY

# --- 17. the /context cell rounds half-up, twice ----------------------------
py "17 context_cell" <<'PY'
from sc_harness import check
from skill_console.budget import context_cell

check(context_cell(58, 3) == "< 20", f"58 chars at 3 b/t: {context_cell(58, 3)!r}")
check(context_cell(59, 3) == "~20", f"59 chars at 3 b/t: {context_cell(59, 3)!r}")
# Banker's rounding would print ~20 for both.
check(context_cell(75, 3) == "~30", f"25 tokens: {context_cell(75, 3)!r}")
check(context_cell(49, 2) == "~30", f"24.5 tokens: {context_cell(49, 2)!r}")
check(context_cell(0, 3) == "< 20", "zero cost")
PY

# --- 2. block scalars: six chomping indicators, six different costs ---------
# Each sibling keeps the blank line before the closing fence, which is what the
# "+" and "" chomps disagree about.
for style in '|' '|-' '|+' '>' '>-' '>+'; do
  case "$style" in
    '|') dir=literal-clip ;; '|-') dir=literal-strip ;; '|+') dir=literal-keep ;;
    '>') dir=folded-clip ;; '>-') dir=folded-strip ;; '>+') dir=folded-keep ;;
  esac
  mkdir -p "$fixtures/chomp/$dir"
  {
    print -- '---'
    print -- 'name: chomp'
    print -- "description: $style"
    print -- '  alpha'
    print -- '  beta'
    print -- ''
    print -- '---'
    print -- ''
    print -- '# Chomp'
  } >"$fixtures/chomp/$dir/SKILL.md"
done
if (( frontmatter_ready )); then
  py "02 block scalar chomping" "$fixtures/chomp" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from skill_console import ListingEntry
from skill_console.budget import display_width, row_cost, utf16_length
from skill_console.frontmatter import parse

# (parsed scalar, full_cost by width, full_cost by UTF-16) for "- k:chomp: <text>".
expected = {
    "literal-clip": ("alpha\nbeta\n", 20, 22),
    "literal-strip": ("alpha\nbeta", 20, 21),
    "literal-keep": ("alpha\nbeta\n\n", 20, 23),
    "folded-clip": ("alpha beta\n", 21, 22),
    "folded-strip": ("alpha beta", 21, 21),
    "folded-keep": ("alpha beta\n\n", 21, 23),
}
for name, (scalar, by_width, by_utf16) in expected.items():
    fm = parse(Path(sys.argv[2]) / name / "SKILL.md")
    check(fm.values["description"] == scalar, f"{name}: parsed {fm.values['description']!r} != {scalar!r}")
    span = fm.spans["description"]
    check(span.style == name.split("-")[0], f"{name}: style {span.style!r}")
    check(span.chomp == {"clip": "", "strip": "-", "keep": "+"}[name.split("-")[1]], f"{name}: chomp {span.chomp!r}")
    entry = ListingEntry(name="k:chomp", listing_text=scalar, protected=False, forced_name_only=False, rank=0.0)
    check(row_cost(entry, 0, max_desc_chars=1536).full_cost == by_width, f"{name}: width cost")
    check(row_cost(entry, 0, max_desc_chars=1536, measure=utf16_length).full_cost == by_utf16, f"{name}: utf16 cost")
PY
else
  skip "02 block scalar chomping" "skill_console/frontmatter.py not on disk"
fi

# --- 3. a folded scalar keeps a blank line as a newline ---------------------
mkdir -p "$fixtures/folded-blank/one" "$fixtures/folded-blank/two"
cat >"$fixtures/folded-blank/one/SKILL.md" <<'SKILL'
---
name: folded-blank
description: >-
  first para
  continues

  second para
---

# Folded
SKILL
cat >"$fixtures/folded-blank/two/SKILL.md" <<'SKILL'
---
name: folded-blank
description: >-
  first para
  continues


  second para
---

# Folded
SKILL
py "03 folded blank line" "$fixtures/folded-blank" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from agent_skill_lib import skill_frontmatter
from skill_console.budget import display_width, utf16_length

root = Path(sys.argv[2])
check(skill_frontmatter(root / "one")["description"] == "first para continues second para", "agent_skill_lib must collapse the blank line")
one = "first para continues\nsecond para"
two = "first para continues\n\nsecond para"
check(display_width(one) == utf16_length(one) - 1, "one newline costs 0 width and 1 UTF-16 unit")
check(display_width(two) == utf16_length(two) - 2, "two newlines cost 0 width and 2 UTF-16 units")
PY
if (( frontmatter_ready )); then
  py "03 folded blank line (frontmatter)" "$fixtures/folded-blank" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from skill_console.frontmatter import parse

root = Path(sys.argv[2])
one = parse(root / "one/SKILL.md").values["description"]
check(one == "first para continues\nsecond para", f"one blank line: {one!r}")
two = parse(root / "two/SKILL.md").values["description"]
check(two == "first para continues\n\nsecond para", f"two blank lines: {two!r}")
PY
else
  skip "03 folded blank line (frontmatter)" "skill_console/frontmatter.py not on disk"
fi

# --- 4. the width guard: divergence is informational, write_safe is strict --
py "04 width guard" <<'PY'
from sc_harness import check
from skill_console import ListingEntry
from skill_console.budget import display_width, row_cost, utf16_length, write_safe

# (text, utf16, width, divergent, write_safe)
cases = [
    ("bare astral emoji", "\U0001F600", 2, 2, False, False),
    ("emoji with U+FE0F", "☺️", 2, 2, False, False),
    ("CJK", "中", 1, 2, True, False),
    ("em dash", "—", 1, 1, False, True),
    ("curly quote", "’", 1, 1, False, True),
    ("rightwards arrow", "→", 1, 1, False, True),
    ("newline", "a\nb", 3, 2, True, True),
    ("tab", "a\tb", 3, 2, True, False),
    ("form feed", "a\x0cb", 3, 2, True, False),
    ("NUL", "a\x00b", 3, 2, True, False),
    ("carriage return", "a\rb", 3, 2, True, False),
    ("lone escape", "\x1b", 1, 0, True, False),
    ("Hangul jungseong", "ᅡ", 1, 0, True, False),
    ("Devanagari vowel sign AA", "ा", 1, 0, True, False),
    ("keycap alone (joins the preceding space, so the row is not divergent)", "⃣", 1, 2, False, False),
    ("Thai sara am (spacing mark, width 1)", "ำ", 1, 1, False, True),
]
for label, text, utf16, width, divergent, safe in cases:
    check(utf16_length(text) == utf16, f"{label}: utf16 {utf16_length(text)} != {utf16}")
    check(display_width(text) == width, f"{label}: width {display_width(text)} != {width}")
    cost = row_cost(ListingEntry("g:x", text, False, False, 0.0), 0, max_desc_chars=1536)
    check(cost.width_divergent is divergent, f"{label}: width_divergent {cost.width_divergent}")
    ok, reason = write_safe(text)
    check(ok is safe, f"{label}: write_safe {ok} ({reason})")
    check(ok or reason, f"{label}: a refusal must carry a reason")
PY

# --- 04b. width: grapheme clusters cost what Bun charges --------------------
py "04b grapheme clusters" <<'PY'
from sc_harness import check
from skill_console.budget import display_width, utf16_length

# (label, text, utf16, width); width is Bun 1.4.0's answer.
cases = [
    ("heart + VS16", "❤️", 2, 2),
    ("heart + VS16 x15", "❤️" * 15, 30, 30),
    ("smile + VS16 x75", "☺️" * 75, 150, 150),
    ("warning + VS16", "⚠️", 2, 2),
    ("check + VS16", "✔️", 2, 2),
    ("arrow + VS16", "➡️", 2, 2),
    ("info + VS16", "ℹ️", 2, 2),
    ("copyright + VS16", "©️", 2, 2),
    ("hash + VS16 (no emoji bit below U+203C)", "#️", 2, 1),
    ("digit + VS16", "1️", 2, 1),
    ("keycap one", "1️⃣", 3, 2),
    ("keycap hash", "#⃣", 2, 2),
    ("thumbs up + skin tone", "👍🏽", 4, 2),
    ("index + skin tone, narrow base", "☝🏽", 3, 2),
    ("family ZWJ sequence", "👨‍👩‍👧", 8, 2),
    ("heart ZWJ fire", "❤‍🔥", 4, 2),
    ("star ZWJ fire (star has no emoji bit)", "★‍🔥", 4, 3),
    ("flag pair", "🇺🇸", 4, 2),
    ("flag pair + lone RI", "🇺🇸🇺", 6, 3),
    ("lone regional indicator", "🇦", 2, 1),
    ("Hangul syllable", "각", 1, 2),
    ("Hangul jamo L V T", "\u1100\u1161\u11a8", 3, 2),
    ("combining acute", "e\u0301", 2, 1),
    ("ZWJ between letters", "a‍b", 3, 2),
    ("lone high surrogate", "\ud83d", 1, 0),
    ("cap cut inside a surrogate pair", "x\ud83d…", 3, 2),
    ("CJK", "日本語", 3, 6),
    ("halfwidth katakana", "ｱ", 1, 1),
    ("ambiguous section sign (narrow)", "§", 1, 1),
    ("Unicode 16 emoji", "\U0001FA89", 2, 2),
    ("banana x375", "\U0001F34C" * 375, 750, 750),
    ("repo punctuation", "—“”…→", 5, 5),
    ("newline and tab", "a\n\tb", 4, 2),
]
for label, text, utf16, width in cases:
    check(utf16_length(text) == utf16, f"{label}: utf16 {utf16_length(text)} != {utf16}")
    check(display_width(text) == width, f"{label}: width {display_width(text)} != {width}")
check(display_width("- gate-g-emoji: " + "❤️" * 15) == 16 + 30, "gate-g-emoji row cost")
PY

# --- 5. when_to_use joins with " - " and null/absent/empty leave it alone ---
cat >"$fixtures/when-to-use.json" <<JSON
{"inputs": $(budget_inputs 10000), "entries": [
  {"name": "u:joined", "description": "Do the thing", "when_to_use": "when asked"},
  {"name": "u:null", "description": "Do the thing", "when_to_use": null},
  {"name": "u:absent", "description": "Do the thing"},
  {"name": "u:empty", "description": "Do the thing", "when_to_use": ""}
]}
JSON
py "05 when_to_use" "$fixtures/when-to-use.json" <<'PY'
import sys
from sc_harness import check, run
from skill_console.budget import listing_text

check(listing_text("Do the thing", "when asked") == "Do the thing - when asked", "join text")
admission, entries, _ = run(sys.argv[2])
texts = {entry.name: entry.listing_text for entry in entries}
check(texts["u:joined"] == "Do the thing - when asked", texts["u:joined"])
for name in ("u:null", "u:absent", "u:empty"):
    check(texts[name] == "Do the thing", f"{name}: {texts[name]!r}")
costs = {cost.name: cost.full_cost for cost in admission.costs}
check(costs["u:joined"] == len("u:joined") + 4 + len("Do the thing") + 3 + len("when asked"), f"joined cost {costs['u:joined']}")
check(costs["u:null"] == len("u:null") + 4 + len("Do the thing"), f"null cost {costs['u:null']}")
PY

# --- 9b. forced name-only rows never expand and are charged name-only -------
cat >"$fixtures/forced-fits.json" <<JSON
{"inputs": $(budget_inputs 1000), "entries": [
  {"name": "f:forced", "description": "0123456789", "forced_name_only": true},
  {"name": "f:free", "description": "0123456789"}
]}
JSON
cat >"$fixtures/forced-priority.json" <<JSON
{"inputs": $(budget_inputs 40), "entries": [
  {"name": "f:forced", "description": "0123456789", "forced_name_only": true, "rank": 9.0},
  {"name": "f:free", "description": "0123456789"},
  {"name": "f:other", "description": "0123456789"}
]}
JSON
py "09b forced name-only" "$fixtures" <<'PY'
import sys
from sc_harness import check, run

fixtures = sys.argv[2]
fits, _, _ = run(f"{fixtures}/forced-fits.json")
check(fits.mode == "fits", f"mode {fits.mode!r}")
check(fits.demand_chars == 10 + 20 + 1, f"demand {fits.demand_chars}; the forced row is charged name-only")
check(fits.full == ("f:free",) and fits.name_only == ("f:forced",), "forced row stays name-only even when everything fits")
priority, _, _ = run(f"{fixtures}/forced-priority.json")
check(priority.mode == "priority", f"mode {priority.mode!r}")
check(priority.full == (), f"full {priority.full}; upgrades of 12 exceed headroom 11")
check(priority.rendered_chars == 29, f"rendered {priority.rendered_chars}; the forced row costs name-only in the baseline")
PY

# --- 18. one core, two measures: the /context estimator ---------------------
cat >"$fixtures/parity-plain.json" <<JSON
{"inputs": $(budget_inputs 50), "entries": [
  {"name": "m:one", "description": "0123456789"},
  {"name": "m:two", "description": "0123456789"},
  {"name": "m:three", "description": "0123456789"}
]}
JSON
cat >"$fixtures/parity-newline.json" <<JSON
{"inputs": $(budget_inputs 50), "entries": [
  {"name": "m:one", "description": "01234\n5678"},
  {"name": "m:two", "description": "0123456789"},
  {"name": "m:three", "description": "0123456789"}
]}
JSON
py "18 estimator parity" "$fixtures" <<'PY'
import sys
from sc_harness import check, run
from skill_console.budget import utf16_length

fixtures = sys.argv[2]
by_width, _, _ = run(f"{fixtures}/parity-plain.json")
by_utf16, _, _ = run(f"{fixtures}/parity-plain.json", measure=utf16_length)
check(by_width.mode == "priority", "fixture must be in priority mode")
check((by_width.full, by_width.name_only) == (by_utf16.full, by_utf16.name_only), "same membership without newlines")
check(by_width.demand_chars == by_utf16.demand_chars, "same demand without newlines")

by_width, _, _ = run(f"{fixtures}/parity-newline.json")
by_utf16, _, _ = run(f"{fixtures}/parity-newline.json", measure=utf16_length)
check(by_utf16.demand_chars == by_width.demand_chars + 1, f"utf16 demand {by_utf16.demand_chars} vs width {by_width.demand_chars}")
check([cost.width_divergent for cost in by_width.costs] == [True, False, False], "divergence is flagged on the newline row only")
check([cost.width_divergent for cost in by_utf16.costs] == [True, False, False], "width_divergent does not depend on the measure")
PY

# --- 25. the witness invariant, generated rather than hand-written ----------
py "25 predicted invariant" "$fixtures" <<'PY'
import sys
from sc_harness import check, fixture_entry, write_fixture, run
from skill_console import BudgetInputs
from skill_console.budget import diff_admissions

fixtures = sys.argv[2]
before_rows = [
    {"name": "x:A", "description": "0123456789", "rank": 2.0},
    {"name": "x:B", "description": "0123456789", "rank": 1.0},
    {"name": "x:C", "description": "0123456789", "rank": 0.0},
    {"name": "x:D", "description": "0123456789", "rank": 1.5},
]
after_rows = [
    {"name": "x:A", "description": "0123456789", "rank": 2.0},
    {"name": "x:B", "description": "0123456789", "rank": 1.0},
    {"name": "x:E", "description": "0123456789", "rank": 0.0},
    {"name": "x:F", "description": "0123456789", "rank": 3.0},
]
inputs = {"context_window": 47, "bytes_per_token": 1, "fraction": 1.0, "max_desc_chars": 1536}
write_fixture(f"{fixtures}/invariant-before.json", inputs, before_rows)
write_fixture(f"{fixtures}/invariant-after.json", {**inputs, "context_window": 59}, after_rows)
before, _, _ = run(f"{fixtures}/invariant-before.json")
after, _, _ = run(f"{fixtures}/invariant-after.json")
check(before.full == ("x:A", "x:D") and before.name_only == ("x:B", "x:C"), f"before {before.full} / {before.name_only}")
check(after.full == ("x:A", "x:B", "x:F") and after.name_only == ("x:E",), f"after {after.full} / {after.name_only}")

predicted = diff_admissions(before, after)
check(predicted.cap_chars == 59, f"cap_chars {predicted.cap_chars}")
check(predicted.newly_admitted == ("x:B",), f"newly_admitted {predicted.newly_admitted}")
check(predicted.newly_dropped == (), f"newly_dropped {predicted.newly_dropped}")
check(predicted.removed_name_only == 1, f"removed_name_only {predicted.removed_name_only}; C left name-only, D left full")
check(predicted.added_name_only == 1, f"added_name_only {predicted.added_name_only}; E joined name-only, F joined full")
check((predicted.full_before, predicted.full_after, predicted.name_only_before, predicted.name_only_after) == (2, 3, 2, 1), "counts")
check((predicted.demand_before, predicted.demand_after) == (before.demand_chars, after.demand_chars), "demand fields")
check((predicted.rendered_before, predicted.rendered_after) == (before.rendered_chars, after.rendered_chars), "rendered fields")
check((predicted.mode_before, predicted.mode_after) == ("priority", "priority"), "modes")
corrected = (predicted.name_only_before - predicted.removed_name_only + predicted.added_name_only
             - len(predicted.newly_admitted) + len(predicted.newly_dropped))
check(predicted.name_only_after == corrected, f"corrected invariant: {predicted.name_only_after} != {corrected}")
plan_version = predicted.name_only_before - predicted.removed_name_only + predicted.added_name_only
check(predicted.name_only_after != plan_version, "this table must distinguish the corrected invariant from the plan's")
PY

# --- 30a. capability matrix: every "no" cell refuses --------------------------
py "30a capability matrix" <<'PY'
from sc_harness import check
from skill_console import CAPABILITIES, Op, Origin, capability_allows

refused = {
    Origin.REPO_LOCAL: [Op.DELETE_SKILL],
    Origin.REPO_PROJECT: [Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED],
    Origin.USER_SKILL: [Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED],
    Origin.USER_COMMAND: [Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED],
    Origin.THIRD_PARTY_PLUGIN: [Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED],
    Origin.BUILTIN: [Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED],
}
allowed = {
    Origin.REPO_LOCAL: {Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED},
    Origin.REPO_VENDOR: {Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL, Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED},
    Origin.REPO_PROJECT: {Op.SET_DESCRIPTION, Op.SET_FRONTMATTER},
    Origin.THIRD_PARTY_PLUGIN: {Op.SET_PACKAGE_ENABLED},
}
check(set(CAPABILITIES) == set(Origin), "every origin has a capability row")
for origin, ops in refused.items():
    for op in ops:
        check(not capability_allows(origin, op), f"{origin.value} must refuse {op.value}")
for origin in Origin:
    check(CAPABILITIES[origin] == allowed.get(origin, frozenset()), f"{origin.value}: {sorted(CAPABILITIES[origin])}")
    check(not capability_allows(origin, Op.SET_BUDGET_FRACTION), f"{origin.value}: set_budget_fraction belongs to no origin")
PY

# --- 31. the browser re-runs the greedy loop over Python's integer costs ----
if command -v node >/dev/null 2>&1; then
  [[ "$(grep -c 'skill-console:admit-begin' "$template")" == 1 ]]
  sed -n '/skill-console:admit-begin/,/skill-console:admit-end/p' "$template" >"$tmp_root/admit.js"
  [[ "$(grep -c '^function ' "$tmp_root/admit.js")" == 1 ]]
  if grep -Eiq 'stringWidth|max_desc|1536|\\u2026|yaml|normalize|bytes_per_token|listing_text|description' "$tmp_root/admit.js"; then
    echo "the browser admission loop must not measure, cap, parse YAML, or normalize models" >&2
    exit 1
  fi
  py "31 browser parity (python side)" "$fixtures" "$tmp_root/js-cases.json" <<'PY'
import json
import sys
from sc_harness import check, run

fixtures, out = sys.argv[2], sys.argv[3]
cases = []
for name in ("at-budget", "one-over", "separator-once", "greedy-non-stop", "ties-forward", "ties-reversed",
             "all-pinned", "empty", "duplicates", "forced-fits", "forced-priority", "when-to-use"):
    admission, entries, _ = run(f"{fixtures}/{name}.json")
    cases.append({
        "name": name,
        "budget": admission.budget,
        "entries": [
            {"name": e.name, "protected": e.protected, "forced_name_only": e.forced_name_only, "rank": e.rank,
             "name_only_cost": c.name_only_cost, "full_cost": c.full_cost, "upgrade_cost": c.upgrade_cost}
            for e, c in zip(entries, admission.costs, strict=True)
        ],
        "expected": {
            "mode": admission.mode, "demand_chars": admission.demand_chars, "rendered_chars": admission.rendered_chars,
            "headroom_chars": admission.headroom_chars, "all_pinned": admission.all_pinned,
            "full": list(admission.full), "name_only": list(admission.name_only),
        },
    })
check(len(cases) == 12, "fixture table")
open(out, "w").write(json.dumps(cases))
PY
  cat >"$tmp_root/admit-check.js" <<'JS'
const fs = require("fs");
const [fnPath, casesPath] = process.argv.slice(2);
const admit = new Function(fs.readFileSync(fnPath, "utf8") + "\nreturn admit;")();
let failures = 0;
for (const c of JSON.parse(fs.readFileSync(casesPath, "utf8"))) {
  const got = admit(c.entries, c.budget);
  const actual = {
    mode: got.mode, demand_chars: got.demand_chars, rendered_chars: got.rendered_chars,
    headroom_chars: got.headroom_chars, all_pinned: got.all_pinned, full: got.full, name_only: got.name_only,
  };
  if (JSON.stringify(actual) !== JSON.stringify(c.expected)) {
    failures += 1;
    console.error(`browser admit disagrees on ${c.name}:\n  js ${JSON.stringify(actual)}\n  py ${JSON.stringify(c.expected)}`);
  }
}
process.exit(failures ? 1 : 0);
JS
  node "$tmp_root/admit-check.js" "$tmp_root/admit.js" "$tmp_root/js-cases.json"

  # --- 31b. the browser's writeSafe agrees with write_safe over the BMP --------
  py "31b writeSafe table (python side)" "$tmp_root/py-writesafe.json" <<'PY'
import json
import sys
from skill_console.budget import write_safe

json.dump([None if 0xD800 <= cp <= 0xDFFF else write_safe("a" + chr(cp) + "b")[0] for cp in range(0x10000)], open(sys.argv[2], "w"))
PY
  cat >"$tmp_root/writesafe-check.js" <<'JS'
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const start = html.indexOf("const WIDE_RE = ");
const end = html.indexOf("function safeWidth");
const writeSafe = new Function(html.slice(start, end) + "\nreturn writeSafe;")();
const py = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
let failures = 0;
for (let cp = 0; cp < 0x10000; cp++) {
  if (py[cp] === null) continue;
  if (writeSafe("a" + String.fromCodePoint(cp) + "b")[0] !== py[cp]) {
    failures += 1;
    if (failures <= 10) console.error(`writeSafe disagrees at U+${cp.toString(16).toUpperCase()}: py ${py[cp]}`);
  }
}
process.exit(failures ? 1 : 0);
JS
  node "$tmp_root/writesafe-check.js" "$template" "$tmp_root/py-writesafe.json"
else
  skip "31 browser parity" "node is not on PATH"
fi

# --- 32. constants are keyed to the binary hash -----------------------------
recorded_sha="$(py "32 constants provenance" <<'PY'
from skill_console import BINARY_SHA256
print(BINARY_SHA256)
PY
)"
claude_bin="$(command -v claude 2>/dev/null || true)"
if [[ -z "$claude_bin" ]]; then
  skip "32 constants provenance" "no claude executable on PATH"
else
  claude_bin="$(readlink -f "$claude_bin")"
  live_sha="$(shasum -a 256 "$claude_bin" | cut -d' ' -f1)"
  if [[ "$live_sha" != "$recorded_sha" ]]; then
    print -- "skill-console: constants recorded for $recorded_sha, live binary is $live_sha; re-verify"
    skip "32 constants provenance" "binary hash mismatch"
  else
    py "32 constants provenance" "$claude_bin" <<'PY'
import sys
from sc_harness import check
from skill_console import BINARY_PROVENANCE, BINARY_VERSION, DECAY_FLOOR, DECAY_HALF_LIFE_DAYS, DEFAULT_BUDGET_FRACTION, DEFAULT_BYTES_PER_TOKEN, DEFAULT_CONTEXT_WINDOW, DEFAULT_MAX_DESC_CHARS, LEGACY_BYTES_PER_TOKEN_FAMILIES, MODEL_FAMILIES, MS_PER_DAY

data = open(sys.argv[2], "rb").read()
names = {p.name for p in BINARY_PROVENANCE}
for required in ("DEFAULT_BUDGET_FRACTION", "DEFAULT_BYTES_PER_TOKEN", "DEFAULT_CONTEXT_WINDOW", "DEFAULT_MAX_DESC_CHARS",
                 "DECAY_HALF_LIFE_DAYS", "DECAY_FLOOR", "LEGACY_BYTES_PER_TOKEN_FAMILIES", "MODEL_FAMILIES", "BINARY_VERSION"):
    check(required in names, f"no provenance recorded for {required}")
for p in BINARY_PROVENANCE:
    check(p.source.encode("utf-8") in data, f"{p.name} ({p.symbol}): source fragment not found in the binary: {p.source[:80]!r}")
# The fragments must also agree with the Python values they vouch for.
by_name = {p.name: p.source for p in BINARY_PROVENANCE}
check(f"x2o={DEFAULT_BUDGET_FRACTION}" == by_name["DEFAULT_BUDGET_FRACTION"], "fraction literal")
check(f"Q1n={DEFAULT_BYTES_PER_TOKEN}" == by_name["DEFAULT_BYTES_PER_TOKEN"], "bytes/token literal")
check(f"A2o={DEFAULT_CONTEXT_WINDOW}" == by_name["DEFAULT_CONTEXT_WINDOW"], "context window literal")
check(f"R2o={DEFAULT_MAX_DESC_CHARS}" == by_name["DEFAULT_MAX_DESC_CHARS"], "max desc literal")
check(f"o/{DECAY_HALF_LIFE_DAYS:g})" in by_name["DECAY_HALF_LIFE_DAYS"], "half-life literal")
check(f",{DECAY_FLOOR})" in by_name["DECAY_FLOOR"], "decay floor literal")
check(f"/{MS_PER_DAY}" in by_name["MS_PER_DAY"], "ms per day literal")
check(f'VERSION:"{BINARY_VERSION}"' == by_name["BINARY_VERSION"], "version literal")
check(all(f'"{family}"' in by_name["LEGACY_BYTES_PER_TOKEN_FAMILIES"] for family in LEGACY_BYTES_PER_TOKEN_FAMILIES), "Pne members")
check(by_name["LEGACY_BYTES_PER_TOKEN_FAMILIES"].count('"') == 2 * len(LEGACY_BYTES_PER_TOKEN_FAMILIES), "Pne has exactly the recorded members")
check(all(f'includes("{family}")' in by_name["MODEL_FAMILIES"] for family in MODEL_FAMILIES), "s_ chain members")
PY
  fi
fi

# --- 33. loader semantics: derived descriptions, verbatim when_to_use, -------
# ---     ancestor skill dirs, project commands, localeCompare, built-ins ------
py "33 loader semantics" "$tmp_root/loader" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from skill_console import ListingEntry, Origin, Tree
from skill_console import inventory as inv
from skill_console.budget import budget_chars

root = Path(sys.argv[2])


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


plug = root / "plug"
write(plug / ".claude-plugin/plugin.json", '{"name": "pkg"}')
write(plug / "skills/nodesc/SKILL.md", "---\nname: nodesc\n---\n\n# Heading line here\nbody\n")
write(plug / "skills/blank/SKILL.md", "---\nname: blank\ndescription: '   '\n---\n")
write(plug / "skills/wtu/SKILL.md", "---\nname: wtu\nwhen_to_use: \"  spaced  \"\n---\nBody first line\n")
write(plug / "skills/boolean/SKILL.md", "---\nname: boolean\ndescription: true\n---\n")
write(plug / "skills/longline/SKILL.md", "---\nname: longline\n---\n" + "z" * 120 + "\n")
write(plug / "skills/emptywtu/SKILL.md", "---\nname: emptywtu\ndescription: ok\nwhen_to_use: ''\n---\n")
recs = {r.directory: r for r in inv.load_skills(plug, Tree.CACHE)}
# qHe(): description = V$(fm.description) ?? Fte(body, "Skill"); whenToUse = String(fm.when_to_use), untrimmed.
check(recs["nodesc"].description == "Heading line here" and recs["nodesc"].description_derived, "missing description derives from the first body line")
check(recs["blank"].description == "Skill" and recs["blank"].description_derived, "blank description + empty body -> 'Skill'")
check(recs["wtu"].when_to_use == "  spaced  ", f"when_to_use kept verbatim: {recs['wtu'].when_to_use!r}")
check(recs["boolean"].description == "true", "boolean description is JS String(true)")
check(recs["longline"].description == "z" * 97 + "...", "derived description cut to 97 + '...'")
check(recs["emptywtu"].when_to_use == "", "empty when_to_use stays empty")
settings = inv.MergedSettings(values={"enabledPlugins": {"pkg@mkt": True}}, layers=("user",), projection_hash="x")
rows = {r.name: r for r in inv.build_rows([], {Tree.CACHE: list(recs.values())}, [], {}, settings, 0)}
# gpe(): a plugin-loaded skill needs hasUserSpecifiedDescription || whenToUse to be listed.
check(not rows["pkg:nodesc"].listed and not rows["pkg:blank"].listed and not rows["pkg:longline"].listed, "plugin skills with only a derived description are not listed")
check(rows["pkg:wtu"].listed and rows["pkg:boolean"].listed and rows["pkg:emptywtu"].listed, "a user description or when_to_use lists a plugin skill")
check(rows["pkg:nodesc"].derived_description and not rows["pkg:boolean"].derived_description, "Row.derived_description follows the record")

home = root / "home"
write(home / ".claude/skills/mine/SKILL.md", "---\nname: mine\n---\nMy body line\n")
write(home / ".claude/commands/empty.md", "")
write(home / ".claude/commands/Zoo.md", "---\ndescription: zoo\n---\n")
write(home / ".claude/commands/apple.md", "# Apple heading\n")
write(home / ".claude/commands/frontend/deploy.md", "deploy it\n")
write(home / ".claude/commands/pack/SKILL.md", "---\nwhen_to_use: now\n---\n")
write(home / ".claude/commands/pack/other.md", "ignored: SKILL.md wins in its directory\n")
proj = home / "work/proj"
write(proj / "sub/.claude/skills/subskill/SKILL.md", "---\nname: subskill\ndescription: sub\n---\n")
write(proj / ".claude/skills/projskill/SKILL.md", "---\nname: projskill\ndescription: proj\n---\n")
write(home / "work/.claude/skills/above/SKILL.md", "---\nname: above\ndescription: above the git root\n---\n")
write(proj / ".claude/commands/deploy.md", "---\ndescription: project deploy\n---\n")
main = root / "main"
write(main / ".claude/commands/mainonly.md", "from the main worktree\n")
unmanaged = inv.load_unmanaged_skills(home, proj, cwd=proj / "sub", main_worktree_root=main)
names = [r.directory for r in unmanaged]
# sVo(): user skills, then Yz() dirs from cwd up to the git root (never above it, never $HOME);
# rVo(): user + project commands together, sorted by localeCompare (apple < Zoo).
check(names == ["mine", "subskill", "projskill", "apple", "deploy", "empty", "frontend:deploy", "pack", "Zoo"], f"unmanaged order: {names}")
by = {r.directory: r for r in unmanaged}
check(by["empty"].description == "Custom command" and by["empty"].description_derived, "empty command -> 'Custom command'")
check(by["apple"].description == "Apple heading" and by["mine"].description == "My body line", "derived descriptions for a command and a user skill")
check(by["pack"].when_to_use == "now" and by["pack"].path.name == "SKILL.md", "a SKILL.md in a commands dir replaces its sibling .md files")
check(by["deploy"].origin is Origin.USER_COMMAND and by["deploy"].path.resolve().is_relative_to(proj.resolve()), "project commands load as legacy commands")
check("mainonly" not in names, "main-worktree commands are skipped when the project has its own")
check(all(r.listed for r in inv.build_rows([], {Tree.CACHE: unmanaged}, [], {}, inv.MergedSettings({}, (), "x"), 0)), "skill-dir and command rows are listed even with derived descriptions")
(proj / ".claude/commands/deploy.md").unlink()
(proj / ".claude/commands").rmdir()
names = [r.directory for r in inv.load_unmanaged_skills(home, proj, cwd=proj / "sub", main_worktree_root=main)]
check("mainonly" in names and "deploy" not in names, f"main-worktree fallback when the worktree has no .claude/commands: {names}")
check("subskill" not in [r.directory for r in inv.load_unmanaged_skills(home, proj)], "positional call walks from the project root only")

# Sy(): disableBundledSkills (settings) or CLAUDE_CODE_DISABLE_BUNDLED_SKILLS (env, JS truthiness).
write(home / ".claude/settings.json", '{"disableBundledSkills": true}')
on = inv.load_settings(home, proj)
off = inv.load_settings(root / "nohome", root / "noproj")
check(on.projection_hash != off.projection_hash and on.values.get("disableBundledSkills") is True, "disableBundledSkills is projected and moves the settings hash")
check(inv.bundled_skills_disabled(on, {}) and not inv.bundled_skills_disabled(off, {}), "settings flag")
check(inv.bundled_skills_disabled(off, {"CLAUDE_CODE_DISABLE_BUNDLED_SKILLS": "false"}), "env 'false' still disables (non-empty string)")
check(not inv.bundled_skills_disabled(off, {"CLAUDE_CODE_DISABLE_BUNDLED_SKILLS": ""}), "env '' does not")
builtins = [ListingEntry("init", "Init.", False, False, 0.0), ListingEntry("commit", "Commit.", True, False, 0.0)]
check(not any(r.listed for r in inv.build_rows([], {}, builtins, {}, off, 0, disable_bundled=True)), "disable_bundled delists every built-in")
check(all(r.listed for r in inv.build_rows([], {}, builtins, {}, off, 0)), "built-ins listed by default")

# skillListingBudgetFraction outside (0, 1]: kept, with a loud warning (the binary's handling is unverified).
write(home / ".claude/settings.json", '{"skillListingBudgetFraction": 5}')
inputs, _, warnings = inv.resolve_budget_inputs(inv.load_settings(home, proj), model="claude-fable-5-1", context_window=200_000, statusline_state=None, env={})
check(inputs.fraction == 5.0 and budget_chars(inputs) == 3_000_000, "fraction 5 is kept")
check(any("outside the binary's settings schema" in w for w in warnings), f"loud warning: {warnings}")

# CLAUDE_CONFIG_DIR relocates settings, plugins, skills, commands.
cfg = root / "cfg"
write(cfg / "settings.json", '{"skillListingBudgetFraction": 0.02}')
check(inv.load_settings(root / "nohome", proj, config_dir=cfg).values["skillListingBudgetFraction"] == 0.02, "settings from config_dir")
write(cfg / "skills/cfgskill/SKILL.md", "---\nname: cfgskill\ndescription: from the config dir\n---\n")
check([r.directory for r in inv.load_unmanaged_skills(root / "nohome", root / "noproj", config_dir=cfg)] == ["cfgskill"], "user skills from config_dir")
PY

# --- 19-23. frontmatter: strict parse, surgical edit --------------------------
skill_md_count="$(find home/dot_agents/packages -name SKILL.md | wc -l | tr -d ' ')"
if (( frontmatter_ready )); then
  py "19 duplicate keys" <<'PY'
from sc_harness import check
from skill_console.frontmatter import FrontmatterError, parse_text

try:
    parse_text("---\nname: dup\ndescription: first\nname: again\n---\n\n# Dup\n")
except FrontmatterError:
    pass
else:
    check(False, "a repeated key must raise FrontmatterError")
check(parse_text("---\nname: ok\ndescription: fine\n---\n").values["name"] == "ok", "a clean file parses")
PY
  py "20 YAML 1.1 booleans" <<'PY'
from sc_harness import check
from skill_console.frontmatter import parse_text

def value(raw):
    return parse_text(f"---\nname: b\ndescription: d\ndisable-model-invocation: {raw}\n---\n").values["disable-model-invocation"]

check(value("no") is False, f"no -> {value('no')!r}")
check(value("yes") is True, f"yes -> {value('yes')!r}")
check(value('"no"') == "no", f'"no" -> {value(chr(34) + "no" + chr(34))!r}')
check(value("off") is False, f"off -> {value('off')!r}")
check(value("true") is True and value("false") is False, "plain booleans")
PY
  py "21 round-trip over the real inventory" "$REPO_ROOT/home/dot_agents/packages" "$skill_md_count" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from skill_console.frontmatter import edit, parse

root, expected_count = Path(sys.argv[2]), int(sys.argv[3])
paths = sorted(root.rglob("SKILL.md"))
check(len(paths) == expected_count > 0, f"visited {len(paths)} SKILL.md files, find saw {expected_count}")
for path in paths:
    original = path.read_bytes()
    fm = parse(path)
    check(fm.path == path and fm.text.encode("utf-8") == original, f"{path}: parse must keep the whole file text")
    check(edit(fm, {}).encode("utf-8") == original, f"{path}: edit(parse(p), {{}}) is not byte-identical")
    check("description" in fm.spans, f"{path}: description has no span")
PY
  py "22 surgical block-scalar edit" <<'PY'
from sc_harness import check
from skill_console.frontmatter import edit, parse_text

text = (
    "---\n"
    "name: surgical\n"
    "# keep this comment where it is\n"
    "description: |-\n"
    "  old text\n"
    "  second line\n"
    "user-invocable: true\n"
    "---\n"
    "\n"
    "# Surgical\n"
)
fm = parse_text(text)
check(fm.values["description"] == "old text\nsecond line", "fixture parses")
check(fm.spans["description"].style == "literal" and fm.spans["description"].chomp == "-", "fixture span")
new = edit(fm, {"description": "new text\nmore of it"})
check("description: |-\n  new text\n  more of it\nuser-invocable: true\n" in new, f"indicator, indentation, or neighbour lost:\n{new}")
check("# keep this comment where it is\n" in new, "the adjacent comment must survive")
check(new.endswith("---\n\n# Surgical\n"), "the body must be untouched")
check(new.count("old text") == 0, "the old text must be gone")
check(parse_text(new).values["description"] == "new text\nmore of it", "the edited file re-parses to the new text")
PY
  py "23 add and delete keys" <<'PY'
from sc_harness import check
from skill_console.frontmatter import FrontmatterError, edit, parse_text

crlf = "---\r\nname: crlf\r\ndescription: d\r\n---\r\n\r\n# Body\r\n"
fm = parse_text(crlf)
check(fm.line_ending == "\r\n", f"line ending {fm.line_ending!r}")
added = edit(fm, {"disable-model-invocation": True})
check(added == "---\r\nname: crlf\r\ndescription: d\r\ndisable-model-invocation: true\r\n---\r\n\r\n# Body\r\n", repr(added))

block = "---\nname: del\ndescription: |-\n  gone\n  entirely\nuser-invocable: false\n---\n\n# Body\n\n\n"
fm = parse_text(block)
deleted = edit(fm, {"description": None})
check(deleted == "---\nname: del\nuser-invocable: false\n---\n\n# Body\n\n\n", repr(deleted))
check("description" not in parse_text(deleted).values, "the deleted key must not re-parse")
check(edit(fm, {}) == block, "trailing newline count survives the round trip")

flow = "---\nname: flow\ndescription: d\nmetadata: {a: 1}\n---\n"
try:
    edit(parse_text(flow), {"metadata": "x"})
except FrontmatterError:
    pass
else:
    check(False, "editing a flow mapping must raise FrontmatterError")
PY
  py "unsafe plain scalars are double-quoted" <<'PY'
from sc_harness import check
from skill_console.frontmatter import edit, parse_text

base = parse_text("---\nname: q\ndescription: Old.\n---\n\n# Body\n")
# PyYAML refuses each of these as a plain scalar: a leading indicator, a tab,
# and characters its reader rejects anywhere in the stream (C0, DEL, C1, U+FFFE).
unsafe = ["- item", "? x", "-", "a\tb", "a\x0cb", "a\x00b", "a\x7fb", "a\x9fb", "a\ufffeb", "a\x1bb"]


def raw_unprintable(line):
    return any(ord(ch) < 0x20 or 0x7f <= ord(ch) <= 0x9f or ch == "\ufffe" for ch in line)


for value in unsafe:
    written = edit(base, {"description": value})
    line = written.split("\n")[2]
    check(line.startswith('description: "') and line.endswith('"'), f"{value!r} must be double-quoted, got {line!r}")
    check(not raw_unprintable(line), f"{value!r} must be escaped inside the quotes, got {line!r}")
    check(parse_text(written).values["description"] == value, f"{value!r} must read back")
    appended = edit(parse_text("---\nname: q\n---\n"), {"description": value})
    check('description: "' in appended and parse_text(appended).values["description"] == value, f"{value!r} appended: {appended!r}")
written = edit(base, {"description": "a\x0cb\nc"})
check('description: "a\\x0cb\\nc"' in written, f"a block scalar cannot carry a form feed either: {written!r}")
check("description: -x and ?y stay plain\n" in edit(base, {"description": "-x and ?y stay plain"}), "indicators not followed by whitespace stay plain")
PY
else
  for name in "19 duplicate keys" "20 YAML 1.1 booleans" "21 round-trip over the real inventory" \
    "22 surgical block-scalar edit" "23 add and delete keys"; do
    skip "$name" "skill_console/frontmatter.py not on disk"
  done
fi

# --- 24. every validation code has a negative fixture -----------------------
# Synthetic package tree for the live checks: one repo-local skill, one APM
# dependency owning two vendored skills, and one owning a single skill.
pkgtree="$fixtures/pkgtree/pkg/skills"
mkdir -p "$pkgtree/local/local" "$pkgtree/vendor/vend-a" "$pkgtree/vendor/vend-b" "$pkgtree/vendor/solo"
for dir in local/local vendor/vend-a vendor/vend-b vendor/solo; do
  printf -- '---\nname: %s\ndescription: Local skill.\n---\n\n# Skill\n' "${dir:t}" >"$pkgtree/$dir/SKILL.md"
done
for dir in vend-a vend-b; do
  printf -- '# Source\n\n- APM dependency: `example/repo/skills/shared`\n- Ref: `abc`\n' >"$pkgtree/vendor/$dir/SOURCE.md"
done
printf -- '# Source\n\n- APM dependency: `example/repo/skills/solo`\n- Ref: `abc`\n' >"$pkgtree/vendor/solo/SOURCE.md"

cat >"$tmp_root/sc_decisions.py" <<'PY'
import time
from pathlib import Path

from skill_console import (
    BINARY_SHA256, BINARY_VERSION, CONSOLE_VERSION, Decisions, Harness, Op, Operation, Origin, Predicted, Row,
    SkillRecord, Snapshot, Tree,
)

NOW_MS = int(time.time() * 1000)


def snapshot(**over):
    base = dict(
        schema_version=1, harness=Harness.CLAUDE, console_version=CONSOLE_VERSION, binary_version=BINARY_VERSION,
        binary_hash=f"sha256:{BINARY_SHA256}", binary_hash_matched=True, source_hash="sha256:aa",
        marketplace_hash="sha256:bb", cache_hash="sha256:cc", settings_hash="sha256:dd", usage_hash="sha256:ee",
        model="claude-fable-5-1", context_window=200_000, bytes_per_token=3, fraction=0.04, max_desc_chars=1536,
        budget_chars=24_000, budget_env_override=None, cwd="/work/tree", project_root="/work/tree", git_rev="abc1234",
        git_dirty=False, now_ms=NOW_MS, captured_at="2026-09-02T00:00:00Z", listing_capture_at=None,
    )
    base.update(over)
    return Snapshot(**base)


def predicted(**over):
    base = dict(
        cap_chars=24_000, mode_before="fits", mode_after="fits", demand_before=0, demand_after=0, rendered_before=0,
        rendered_after=0, full_before=0, full_after=0, name_only_before=0, name_only_after=0, newly_admitted=(),
        newly_dropped=(), added_name_only=0, removed_name_only=0,
    )
    base.update(over)
    return Predicted(**base)


def record(package, directory, path, origin, description="Local skill."):
    return SkillRecord(
        tree=Tree.SOURCE, package=package, directory=directory, path=Path(path), origin=origin,
        frontmatter_name=directory, description=description, when_to_use=None, disable_model_invocation=False,
        user_invocable=True, content_sha256="0" * 64,
    )


def row(name, package, directory, origin, path=None, protected=False, description="Local skill."):
    rec = record(package, directory, path, origin, description) if path else None
    return Row(
        name=name, directory=directory, package=package, origin=origin, protected=protected, source_record=rec,
        marketplace_record=rec, cache_record=rec, listed=True, repo_default=True, live_enabled={}, usage=None,
        rank=0.0, rendered=None, capped=False, width_divergent=False, derived_description=False, divergences=(),
    )


def rows_for(pkgtree):
    return [
        row("pkg:local", "pkg", "local", Origin.REPO_LOCAL, f"{pkgtree}/local/local"),
        row("pkg:vend-a", "pkg", "vend-a", Origin.REPO_VENDOR, f"{pkgtree}/vendor/vend-a"),
        row("pkg:vend-b", "pkg", "vend-b", Origin.REPO_VENDOR, f"{pkgtree}/vendor/vend-b"),
        row("pkg:solo", "pkg", "solo", Origin.REPO_VENDOR, f"{pkgtree}/vendor/solo"),
        row("proj-skill", "", "proj-skill", Origin.REPO_PROJECT, "/work/tree/.claude/skills/proj-skill"),
        row("my-skill", "", "my-skill", Origin.USER_SKILL),
        row("my-cmd", "", "my-cmd", Origin.USER_COMMAND),
        row("tp:skill", "tp", "skill", Origin.THIRD_PARTY_PLUGIN),
        row("commit", "", "commit", Origin.BUILTIN, protected=True),
    ]


def op(kind, key, **fields):
    target = {"skill": (Op.SET_DESCRIPTION, Op.SET_FRONTMATTER, Op.DELETE_SKILL)}
    return Operation(
        op=kind,
        target="skill" if kind in target["skill"] else "settings" if kind is Op.SET_BUDGET_FRACTION else "package",
        key=key,
        fields=fields,
    )


def decisions(*operations, snap=None, pred=None):
    return Decisions(
        schema_version=1, harness=Harness.CLAUDE, snapshot=snap or snapshot(), predicted=pred or predicted(),
        operations=tuple(operations),
    )


LOCAL_CHARS = len("Local skill.")
PY

if (( frontmatter_ready )); then
  py "24a structural validation V1-V9" <<'PY'
import copy
import json
from sc_harness import check
from sc_decisions import decisions, op
from skill_console import Op
from skill_console.decisions import dump, load, validate_document

base = json.loads(dump(decisions(op(Op.SET_FRONTMATTER, "pkg:local", field="user-invocable", value=True))))
check(validate_document(base) == [], f"the base document must validate: {validate_document(base)}")


def mutated(apply):
    doc = copy.deepcopy(base)
    apply(doc)
    return doc


def budget_op(to_value):
    return {"op": "set_budget_fraction", "target": "settings", "key": "", "from_value": 0.04, "to_value": to_value}


def plugin_op(key):
    return {"op": "set_package_enabled", "target": "package", "key": key, "value": False}


check(validate_document(mutated(lambda d: d["operations"].append(plugin_op("design@prateek-local")))) == [], "a well-formed plugin key is structurally valid")
cases = {
    "V1": (mutated(lambda d: d.update(schema_version=2)), "/schema_version"),
    "V2": (mutated(lambda d: d.update(harness="codex")), "/harness"),
    "V3": (mutated(lambda d: d.update(notes="extra")), "/notes"),
    "V4": (mutated(lambda d: d["snapshot"].pop("now_ms")), "/snapshot/now_ms"),
    "V4 type": (mutated(lambda d: d["predicted"].update(full_after="66")), "/predicted/full_after"),
    "V5": (mutated(lambda d: d["operations"][0].update(op="rename_skill")), "/operations/0/op"),
    "V5 target": (mutated(lambda d: d["operations"][0].update(target="package")), "/operations/0/target"),
    "V6 missing": (mutated(lambda d: d["operations"][0].pop("value")), "/operations/0/value"),
    "V6 extra": (mutated(lambda d: d["operations"][0].update(text="no")), "/operations/0/text"),
    "V7": (mutated(lambda d: d["operations"].append(dict(d["operations"][0]))), "/operations/1"),
    "V8": (mutated(lambda d: d["operations"][0].update(field="name")), "/operations/0/field"),
    "V9 zero": (mutated(lambda d: d["operations"].append(budget_op(0.0))), "/operations/1/to_value"),
    "V9 over": (mutated(lambda d: d["operations"].append(budget_op(1.5))), "/operations/1/to_value"),
    # The key lands in a Go-template file; a template action or a raw newline must never reach it.
    "V6 plugin action": (mutated(lambda d: d["operations"].append(plugin_op("design@{{ output `touch` `/tmp/x` }}"))), "/operations/1/key"),
    "V6 plugin newline": (mutated(lambda d: d["operations"].append(plugin_op('design@a"b\nc'))), "/operations/1/key"),
    "V6 plugin suffix": (mutated(lambda d: d["operations"].append(plugin_op("design@"))), "/operations/1/key"),
}
for label, (doc, pointer) in cases.items():
    code = label.split()[0]
    violations = validate_document(doc)
    codes = {v.code for v in violations}
    check(codes == {code}, f"{label}: codes {sorted(codes)}, expected only {code}: {[v.message for v in violations]}")
    check(any(v.pointer == pointer for v in violations), f"{label}: pointers {[v.pointer for v in violations]} lack {pointer}")
    check(all(v.pointer and v.message for v in violations), f"{label}: empty pointer or message")
check(validate_document([]) and validate_document([])[0].code == "V3", "a non-object document is V3")
PY

  py "24b live validation V10-V19 and the capability matrix" "$pkgtree" <<'PY'
import sys
from sc_harness import check
from sc_decisions import LOCAL_CHARS, NOW_MS, decisions, op, predicted, rows_for, snapshot
from skill_console import MS_PER_DAY, Op
from skill_console.decisions import validate_against_live
from skill_console.inventory import REPO_MARKETPLACE

rows = rows_for(sys.argv[2])
live = snapshot()


def run(doc, live_snapshot=live, pred=None):
    return validate_against_live(doc, live_snapshot, rows, pred or predicted())


def set_desc(key="pkg:local", from_chars=LOCAL_CHARS, text="Console text."):
    return op(Op.SET_DESCRIPTION, key, from_chars=from_chars, to_chars=len(text), text=text)


def delete(key="pkg:vend-a", apm_dep="example/repo/skills/shared", dep_owns_skills=2, remove_apm_dep=False):
    return op(Op.DELETE_SKILL, key, apm_dep=apm_dep, dep_owns_skills=dep_owns_skills, remove_apm_dep=remove_apm_dep)


valid = decisions(
    set_desc(),
    delete("pkg:solo", "example/repo/skills/solo", 1, True),
    op(Op.SET_BUDGET_FRACTION, "", from_value=0.04, to_value=0.05),
    op(Op.SET_PACKAGE_ENABLED, "tp@third-party", value=False),
    op(Op.SET_PACKAGE_ENABLED, f"pkg@{REPO_MARKETPLACE}", value=True),
)
check(run(valid) == [], f"a consistent document must pass: {run(valid)}")

cases = {
    "V10 hash": (decisions(snap=snapshot(source_hash="sha256:changed")), "/snapshot/source_hash"),
    "V10 binary": (decisions(snap=snapshot(binary_hash_matched=False)), "/snapshot/binary_hash_matched"),
    "V10 input": (decisions(snap=snapshot(fraction=0.05)), "/snapshot/fraction"),
    "V11": (decisions(snap=snapshot(now_ms=NOW_MS - 2 * MS_PER_DAY)), "/snapshot/now_ms"),
    "V12": (decisions(snap=snapshot(cwd="/elsewhere")), "/snapshot/cwd"),
    "V13 skill": (decisions(set_desc("ghost:none")), "/operations/0/key"),
    "V13 package": (decisions(op(Op.SET_DEFAULT_LOADED, "ghost", value=False)), "/operations/0/key"),
    "V13 key shape": (decisions(op(Op.SET_PACKAGE_ENABLED, "pkg", value=False)), "/operations/0/key"),
    "V13 key chars": (decisions(op(Op.SET_PACKAGE_ENABLED, "pkg@{{ fail }}", value=False)), "/operations/0/key"),
    "V13 marketplace": (decisions(op(Op.SET_PACKAGE_ENABLED, "pkg@nope", value=False)), "/operations/0/key"),
    "V15 disable": (decisions(set_desc(), op(Op.SET_DEFAULT_LOADED, "pkg", value=False)), "/operations/0"),
    "V15 delete": (decisions(set_desc("pkg:vend-a"), delete()), "/operations/0"),
    "V16 from": (decisions(set_desc(from_chars=LOCAL_CHARS + 1)), "/operations/0/from_chars"),
    "V16 to": (decisions(op(Op.SET_DESCRIPTION, "pkg:local", from_chars=LOCAL_CHARS, to_chars=1, text="Console text.")), "/operations/0/to_chars"),
    "V16 unsafe": (decisions(set_desc(text="中")), "/operations/0/text"),
    "V17 count": (decisions(delete(dep_owns_skills=1)), "/operations/0/dep_owns_skills"),
    "V17 remove": (decisions(delete(remove_apm_dep=True)), "/operations/0/remove_apm_dep"),
    "V17 dep": (decisions(delete(apm_dep="example/repo/skills/other")), "/operations/0/apm_dep"),
    "V18": (decisions(op(Op.SET_BUDGET_FRACTION, "", from_value=0.02, to_value=0.05)), "/operations/0/from_value"),
    "V19": (decisions(pred=predicted(full_after=1)), "/predicted/full_after"),
}
# One refused operation per "no" cell of the capability matrix, seven origins.
refusals = {
    "repo-local": op(Op.DELETE_SKILL, "pkg:local", apm_dep="x", dep_owns_skills=1, remove_apm_dep=False),
    "repo-vendor": delete(),
    "repo-project": op(Op.DELETE_SKILL, "proj-skill", apm_dep="x", dep_owns_skills=1, remove_apm_dep=False),
    "user-skill": set_desc("my-skill"),
    "user-command": op(Op.SET_FRONTMATTER, "my-cmd", field="user-invocable", value=False),
    "third-party-plugin": set_desc("tp:skill"),
    "third-party package": op(Op.SET_DEFAULT_LOADED, "tp", value=False),
    "builtin": op(Op.SET_FRONTMATTER, "commit", field="disable-model-invocation", value=True),
}
for origin, refused in refusals.items():
    cases[f"V14 {origin}"] = (decisions(refused), "/operations/0")

for label, (doc, pointer) in cases.items():
    code = label.split()[0]
    violations = run(doc)
    matching = [v for v in violations if v.code == code]
    check(matching, f"{label}: expected {code}, got {[(v.code, v.pointer) for v in violations]}")
    check(any(v.pointer == pointer for v in matching), f"{label}: {code} pointers {[v.pointer for v in matching]} lack {pointer}")
    check(all(v.pointer and v.message for v in violations), f"{label}: empty pointer or message")
PY
else
  skip "24a structural validation V1-V9" "skill_console/frontmatter.py not on disk (decisions imports it)"
  skip "24b live validation V10-V19 and the capability matrix" "skill_console/frontmatter.py not on disk (decisions imports it)"
fi

# --- 26-29. plan, stage, commit against a throwaway copy of the repo ---------
# The copy is a real git repo so the dirty-target gate and `git status` have
# something to read; nothing here touches the checkout under test.
repo_copy="$tmp_root/repo"
make_repo_copy() {
  rsync -a --exclude=.git --exclude=.ruff_cache --exclude=__pycache__ "$REPO_ROOT/" "$1/"
  git -C "$1" -c init.defaultBranch=main init -q
  git -C "$1" -c user.name=skill-console-test -c user.email=test@example.invalid add -A
  git -C "$1" -c user.name=skill-console-test -c user.email=test@example.invalid commit -q -m 'skill-console fixture'
  git -C "$1" tag fixture
}
if (( frontmatter_ready )); then
  make_repo_copy "$repo_copy"
  cat >"$tmp_root/sc_repo.py" <<'PY'
import hashlib
import subprocess
from pathlib import Path

from sc_decisions import decisions, op, row
from skill_console import Op, Origin
from skill_console.frontmatter import parse


def git_status(repo):
    return subprocess.run(["git", "-C", str(repo), "status", "--porcelain"], capture_output=True, text=True, check=True).stdout


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.invalid", *args], check=True, capture_output=True)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def skill_row(repo, package, directory):
    skill_dir = Path(repo) / "home/dot_agents/packages" / package / "skills/local" / directory
    description = parse(skill_dir / "SKILL.md").values["description"]
    return row(f"{package}:{directory}", package, directory, Origin.REPO_LOCAL, str(skill_dir), description=description)


def describe(name, text):
    return op(Op.SET_DESCRIPTION, name, from_chars=0, to_chars=len(text), text=text)
PY

  py "26 dry run leaves the worktree untouched" "$repo_copy" "$tmp_root/staging-26" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, describe, git_status, op, sha256, skill_row
from skill_console import Op
from skill_console.decisions import plan, stage, validate_staged
from skill_console.frontmatter import parse

repo, staging = Path(sys.argv[2]), Path(sys.argv[3])
check(git_status(repo) == "", "the copy must start clean")
skill = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
package_toml = "home/dot_agents/packages/design/package.toml"
check("default_loaded = false" in (repo / package_toml).read_text(), "fixture: design starts default_loaded = false")
rows = [skill_row(repo, "core", "code-gardening")]
doc = decisions(describe("core:code-gardening", "Console test description."), op(Op.SET_DEFAULT_LOADED, "design", value=True))

before = {path: sha256(repo / path) for path in (skill, package_toml)}
apply_plan = plan(doc, rows, repo)
by_path = {edit.relpath: edit for edit in apply_plan.edits}
check(skill in by_path and package_toml in by_path, f"plan edits {sorted(by_path)}")
for path in (skill, package_toml):
    edit = by_path[path]
    check(edit.kind == "write" and edit.before_sha256 == before[path], f"{path}: before hash")
    check(edit.after_sha256 == __import__("hashlib").sha256(edit.content.encode()).hexdigest(), f"{path}: after hash")
check(any(path.startswith("home/.chezmoitemplates/") or path.startswith("home/dot_pi/") for path in by_path), "flipping default_loaded must regenerate the derived templates")
check(git_status(repo) == "", f"plan must not touch the worktree:\n{git_status(repo)}")

batch = stage(apply_plan, repo, staging)
check(batch.root == staging and batch.plan == apply_plan, "staged batch")
check(git_status(repo) == "", f"stage must not touch the worktree:\n{git_status(repo)}")
check({path: sha256(repo / path) for path in before} == before, "target files unchanged in the worktree")
check(parse(staging / skill).values["description"] == "Console test description.", "the staged SKILL.md carries the new description")
check("default_loaded = true" in (staging / package_toml).read_text(), "the staged package.toml carries the flip")
check(not (staging / ".git").exists(), "the staging copy must not carry .git")
# The flip only survives staged validation because tests/agent-skill-packages.zsh
# derives its default_loaded expectations from package.toml instead of pinning them.
ok, detail = validate_staged(batch)
check(ok, f"set_default_loaded must pass staged validation:\n{detail}")
PY

  py "27 dirty-target refusal" "$repo_copy" "$tmp_root/staging-27" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, describe, git, git_status, skill_row
from skill_console.decisions import commit, plan, stage

repo, staging = Path(sys.argv[2]), Path(sys.argv[3])
skill = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
original = (repo / skill).read_bytes()
rows = [skill_row(repo, "core", "code-gardening")]
doc = decisions(describe("core:code-gardening", "Dirty target check."))

# An unrelated dirty path does not block the commit.
batch = stage(plan(doc, rows, repo), repo, staging / "a")
with (repo / "README.md").open("a") as handle:
    handle.write("\nunrelated local change\n")
report = commit(batch, repo, allow_dirty=False)
check(report.failure is None and report.applied == (skill,) and report.unapplied == (), f"unrelated dirt: {report}")
check(b"Dirty target check." in (repo / skill).read_bytes(), "the edit landed")
check(" M README.md" in git_status(repo), "the unrelated change is still there")
git(repo, "checkout", "--", ".")
check((repo / skill).read_bytes() == original and git_status(repo) == "", "reset for the next step")

# A dirty target path is refused before anything moves.
batch = stage(plan(doc, rows, repo), repo, staging / "b")
dirty = original + b"\n<!-- local edit -->\n"
(repo / skill).write_bytes(dirty)
report = commit(batch, repo, allow_dirty=False)
check(report.failure and "dirty" in report.failure and skill in report.failure, f"dirty target: {report.failure!r}")
check(report.applied == () and report.unapplied == (skill,), f"nothing may be applied: {report}")
check((repo / skill).read_bytes() == dirty, "the dirty file is left exactly as it was")
git(repo, "checkout", "--", ".")
check(git_status(repo) == "", "clean again")
PY

  py "28 staged validation failure" "$repo_copy" "$tmp_root/staging-28" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, describe, git_status, skill_row
from skill_console.decisions import plan, stage, validate_staged

repo, staging = Path(sys.argv[2]), Path(sys.argv[3])
rows = [skill_row(repo, "core", "code-gardening")]
doc = decisions(describe("core:code-gardening", "x" * 1100))
batch = stage(plan(doc, rows, repo), repo, staging)
ok, reason = validate_staged(batch)
check(ok is False, "a 1100-character description must fail validate-agent-packages in the copy")
check("validate-agent-packages" in reason and "1024" in reason, f"reason must name the failing step: {reason!r}")
check(git_status(repo) == "", f"the worktree must be untouched:\n{git_status(repo)}")
check("x" * 1100 in (staging / "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md").read_text(), "the staging copy keeps the failing edit for inspection")
PY

  py "29 hash precondition at commit time" "$repo_copy" "$tmp_root/staging-29" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, describe, git, git_status, sha256, skill_row
from skill_console.decisions import commit, plan, stage

repo, staging = Path(sys.argv[2]), Path(sys.argv[3])
first = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
second = "home/dot_agents/packages/core/skills/local/decomment/SKILL.md"
rows = [skill_row(repo, "core", "code-gardening"), skill_row(repo, "core", "decomment")]
doc = decisions(describe("core:code-gardening", "First edit."), describe("core:decomment", "Second edit."))
apply_plan = plan(doc, rows, repo)
check([edit.relpath for edit in apply_plan.edits] == [first, second], f"edit order {[e.relpath for e in apply_plan.edits]}")
batch = stage(apply_plan, repo, staging)

# Someone else changes the second target after planning and commits it, so the
# path is clean in git but its hash no longer matches the plan.
mutated = (repo / second).read_bytes() + b"\n<!-- edited after planning -->\n"
(repo / second).write_bytes(mutated)
git(repo, "commit", "-q", "-am", "concurrent edit")
check(git_status(repo) == "", "the mutation is committed, so the dirty gate does not fire")

report = commit(batch, repo, allow_dirty=False)
check(report.applied == (first,), f"applied {report.applied}")
check(report.unapplied == (second,), f"unapplied {report.unapplied}")
check(report.failure and second in report.failure and "changed since planning" in report.failure, f"failure {report.failure!r}")
check(b"First edit." in (repo / first).read_bytes(), "the first path landed")
check((repo / second).read_bytes() == mutated, "the refused path is left as the other writer left it")
check(sha256(staging / second) == apply_plan.edits[1].after_sha256, "the staging copy is kept for retry")
# The printed recovery command is `git restore -- <applied paths>`; it must be
# enough to undo the partial batch.
git(repo, "restore", "--", first)
check(git_status(repo) == "", "git restore over the applied paths recovers the worktree")
PY

  py "set_package_enabled never writes a template action" "$repo_copy" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, git_status, op
from skill_console import Op
from skill_console.decisions import SETTINGS_TEMPLATE, ApplyError, plan

repo = Path(sys.argv[2])
template = repo / SETTINGS_TEMPLATE
before = template.read_bytes()
# Bypasses validate_document on purpose: the planner is the last check before
# staged validation renders the fragment through chezmoi's template engine.
doc = decisions(op(Op.SET_PACKAGE_ENABLED, "design@{{ output `touch` `/tmp/x` }}", value=False))
try:
    plan(doc, [], repo)
except ApplyError as exc:
    check("Go template" in str(exc) and SETTINGS_TEMPLATE in str(exc), f"the reason must name the template: {exc}")
else:
    check(False, "a key carrying a template action must not plan")
check(template.read_bytes() == before and git_status(repo) == "", "the template is untouched")
accepted = plan(decisions(op(Op.SET_PACKAGE_ENABLED, "design@prateek-local", value=False)), [], repo)
check([edit.relpath for edit in accepted.edits] == [SETTINGS_TEMPLATE], f"a well-formed key plans the fragment edit: {accepted.edits}")
check('"design@prateek-local": false' in accepted.edits[0].content, "the key lands as a plain JSON member")
PY

  py "symlinked SKILL.md is refused at plan and at commit" "$repo_copy" "$tmp_root/staging-symlink" <<'PY'
import os
import subprocess
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, describe, git, git_status, skill_row
from skill_console.decisions import ApplyError, commit, plan, stage

repo, staging = Path(sys.argv[2]), Path(sys.argv[3])
head = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
skill = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
real = "docs/code-gardening-SKILL.md"
rows = [skill_row(repo, "core", "code-gardening")]
doc = decisions(describe("core:code-gardening", "Through the link."))


def link_skill():
    (repo / skill).rename(repo / real)
    os.symlink(os.path.relpath(repo / real, (repo / skill).parent), repo / skill)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "symlink SKILL.md")


# Already a symlink when planning: refused before anything is staged.
link_skill()
try:
    plan(doc, rows, repo)
except ApplyError as exc:
    check("symlink" in str(exc) and skill in str(exc), f"the reason must name the link: {exc}")
else:
    check(False, "planning an edit to a symlinked SKILL.md must fail")
git(repo, "reset", "-q", "--hard", head)

# Becomes a symlink between plan and commit: refused by the per-path check.
batch = stage(plan(doc, rows, repo), repo, staging)
link_skill()
report = commit(batch, repo, allow_dirty=False)
check(report.applied == () and report.failure and "symlink" in report.failure and skill in report.failure, f"commit report: {report}")
check((repo / skill).is_symlink() and b"Through the link." not in (repo / real).read_bytes(), "the link and its target are untouched")
check(git_status(repo) == "", f"nothing left behind:\n{git_status(repo)}")
git(repo, "reset", "-q", "--hard", head)
PY

  # delete_skill against a synthetic vendored package committed into the copy.
  # The skill name is generated at runtime so the tracked-reference scan never
  # trips on this test file, and the fixture stays independent of which real
  # skills docs and tests happen to mention.
  synth="$repo_copy/home/dot_agents/packages/synth"
  synth_skill="lone-$RANDOM"
  mkdir -p "$synth/skills/vendor/$synth_skill/scripts" "$synth/skills/vendor/twin-a" "$synth/skills/vendor/twin-b"
  printf -- 'print("tool")\n' >"$synth/skills/vendor/$synth_skill/scripts/tool.py"
  printf -- 'display_name = "Synth"\n\n[render]\nclaude = "plugin"\ncodex = "plugin"\n' >"$synth/package.toml"
  printf -- 'name: synth\nversion: 1.0.0\ntargets:\n  - agent-skills\n\ndependencies:\n  apm:\n    - example/repo/skills/%s\n    - example/repo/skills/twins\n' "$synth_skill" >"$synth/apm.yml"
  lock_dependency() {
    printf -- '- repo_url: example/repo\n  name: %s\n  host: github.com\n  resolved_commit: %s\n  version: unknown\n  virtual_path: skills/%s\n  is_virtual: true\n  package_type: claude_skill\n  deployed_files:\n' "$1" "$2" "$1"
    shift 2
    for deployed in "$@"; do printf -- '  - %s\n' "$deployed"; done
    printf -- '  deployed_file_hashes:\n    %s/SKILL.md: sha256:aa\n  content_hash: sha256:bb\n' "$1"
  }
  lock_deployment() {
    printf -- '- kind: project-relative\n  target: agent-skills\n  value: %s\n  runtime: null\n  scope: project\n  owners:\n  - %s\n  active_owner: %s\n' "$1" "$2" "$2"
  }
  {
    printf -- "lockfile_version: '1'\ngenerated_at: '2026-09-02T00:00:00+00:00'\napm_version: 0.28.0\ndependencies:\n"
    lock_dependency "$synth_skill" 0000000000000000000000000000000000000001 ".agents/skills/$synth_skill" ".agents/skills/$synth_skill/SKILL.md"
    lock_dependency twins 0000000000000000000000000000000000000002 .agents/skills/twin-a .agents/skills/twin-b
    printf -- 'deployments:\n'
    lock_deployment ".agents/skills/$synth_skill" "example/repo/skills/$synth_skill"
    lock_deployment ".agents/skills/$synth_skill/SKILL.md" "example/repo/skills/$synth_skill"
    lock_deployment .agents/skills/twin-a example/repo/skills/twins
  } >"$synth/apm.lock.yaml"
  for dir in "$synth_skill" twin-a twin-b; do
    printf -- '---\nname: %s\ndescription: Synthetic vendored skill.\n---\n\n# %s\n' "$dir" "$dir" >"$synth/skills/vendor/$dir/SKILL.md"
  done
  printf -- '# Source\n\n- APM dependency: `example/repo/skills/%s`\n' "$synth_skill" >"$synth/skills/vendor/$synth_skill/SOURCE.md"
  for dir in twin-a twin-b; do
    printf -- '# Source\n\n- APM dependency: `example/repo/skills/twins`\n' >"$synth/skills/vendor/$dir/SOURCE.md"
  done
  printf -- '# Notes\n\nThe synth:%s skill is mentioned here.\n' "$synth_skill" >"$repo_copy/docs/synth-note.md"
  git -C "$repo_copy" -c user.name=t -c user.email=t@example.invalid add -A
  git -C "$repo_copy" -c user.name=t -c user.email=t@example.invalid commit -q -m 'synthetic vendored package'
  git -C "$repo_copy" tag synth

  py "delete_skill plans the tree, apm.yml, and apm.lock.yaml" "$repo_copy" "$synth_skill" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, git_status, op, row
from skill_console import Op, Origin
from skill_console.decisions import plan

repo, skill = Path(sys.argv[2]), sys.argv[3]
package = "home/dot_agents/packages/synth"
skill_rel, manifest, lock = f"{package}/skills/vendor/{skill}", f"{package}/apm.yml", f"{package}/apm.lock.yaml"
target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(repo / skill_rel))


def delete(remove_apm_dep):
    return op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=remove_apm_dep)


apply_plan = plan(decisions(delete(True)), [target], repo)
by_path = {edit.relpath: edit for edit in apply_plan.edits}
check(set(by_path) == {skill_rel, manifest, lock}, f"plan paths {sorted(by_path)}")
check(by_path[skill_rel].kind == "delete-tree" and by_path[skill_rel].after_sha256 is None, "the skill directory goes as a tree")
manifest_text = by_path[manifest].content
check(skill not in manifest_text and "    - example/repo/skills/twins\n" in manifest_text, f"apm.yml after:\n{manifest_text}")
lock_text = by_path[lock].content
check(skill not in lock_text, f"the lock still mentions {skill}:\n{lock_text}")
check(lock_text.count("- repo_url: example/repo") == 1 and "virtual_path: skills/twins" in lock_text, "the sibling dependency survives")
check(lock_text.count("- kind: project-relative") == 1 and "value: .agents/skills/twin-a" in lock_text, "only the deleted dependency's deployments go")
check(any("docs/synth-note.md" in warning for warning in apply_plan.warnings), f"a docs/ reference only warns: {apply_plan.warnings}")

kept = plan(decisions(delete(False)), [target], repo)
check({edit.relpath for edit in kept.edits} == {skill_rel}, f"remove_apm_dep false must leave apm.yml and the lock alone: {[e.relpath for e in kept.edits]}")
check(any("vendor-agent-package" in warning and "restores the skill" in warning for warning in kept.warnings), f"warnings {kept.warnings}")
check(git_status(repo) == "", f"planning a deletion writes nothing:\n{git_status(repo)}")
PY

  py "a failed tree removal leaves the skill at its own path" "$repo_copy" "$synth_skill" "$tmp_root/staging-rmtree" <<'PY'
import os
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, git, git_status, op, row
from skill_console import Op, Origin
from skill_console.decisions import commit, plan, stage

repo, skill, staging = Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
skill_rel = f"home/dot_agents/packages/synth/skills/vendor/{skill}"
skill_dir = repo / skill_rel
target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(skill_dir))
doc = decisions(op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=True))
batch = stage(plan(doc, [target], repo), repo, staging)

# A read-only subdirectory makes one unlink fail partway through the removal.
(skill_dir / "scripts").chmod(0o555)
check(not os.access(skill_dir / "scripts", os.W_OK), "fixture: the subdirectory must be read-only")
try:
    report = commit(batch, repo, allow_dirty=False)
finally:
    for scripts in skill_dir.parent.glob(f"*{skill}*/scripts"):
        scripts.chmod(0o755)
check(report.failure and report.failure.startswith(f"{skill_rel}: "), f"the failure names the skill path: {report.failure!r}")
check(skill_dir.is_dir() and (skill_dir / "scripts/tool.py").is_file(), "what survives stays at its own path")
check(not [p for p in skill_dir.parent.iterdir() if p.name.startswith(".")], f"no renamed leftover: {sorted(p.name for p in skill_dir.parent.iterdir())}")
check(all(path == skill_rel for path in report.applied), f"the manifest edits never start: {report}")
# rmtree's order is the directory's, so whether SKILL.md went first varies.
if (skill_dir / "SKILL.md").is_file() and (skill_dir / "SOURCE.md").is_file():
    check(report.applied == () and "git restore" not in report.failure, f"an intact tree is not reported as applied: {report}")
else:
    check(report.applied == (skill_rel,) and "git restore" in report.failure, f"a partly removed tree is reported for recovery: {report}")
git(repo, "restore", "--", skill_rel)
check(git_status(repo) == "" and (skill_dir / "SKILL.md").is_file(), f"git restore rebuilds the skill:\n{git_status(repo)}")
PY

  py "delete_skill preconditions are re-checked at commit" "$repo_copy" "$synth_skill" "$tmp_root/staging-guards" <<'PY'
import sys
from pathlib import Path
from sc_harness import check
from sc_repo import decisions, git, git_status, op, row
from skill_console import Op, Origin
from skill_console.decisions import commit, plan, stage

repo, skill, staging = Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
package = "home/dot_agents/packages/synth"
skill_rel = f"{package}/skills/vendor/{skill}"
target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(repo / skill_rel))
doc = decisions(op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=True))


def staged(name):
    return stage(plan(doc, [target], repo), repo, staging / name)


def commit_after(batch, path, text):
    (repo / path).parent.mkdir(parents=True, exist_ok=True)
    (repo / path).write_text(text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "concurrent change")
    report = commit(batch, repo, allow_dirty=False)
    check(report.applied == () and (repo / skill_rel / "SKILL.md").is_file(), f"nothing may move: {report}")
    git(repo, "reset", "-q", "--hard", "synth")
    return report.failure or ""


# A test that starts referencing the skill after planning.
failure = commit_after(staged("reference"), "tests/uses-synth.zsh", f"source {skill_rel}/scripts/tool.py\n")
check("tests/uses-synth.zsh" in failure and "re-plan" in failure, f"a new tracked reference must refuse the commit: {failure!r}")
# A sibling that starts sharing the APM dependency after planning, spelled in
# another case so the reference scan cannot see it and only the count can.
sibling = f"{package}/skills/vendor/{skill}-copy/SOURCE.md"
failure = commit_after(staged("sibling"), sibling, f"# Source\n\n- APM dependency: `example/repo/skills/{skill.upper()}`\n")
check("owns 2" in failure and "re-plan" in failure, f"a new sibling on the dependency must refuse the commit: {failure!r}")
# With nothing changed the same batch still lands whole.
report = commit(staged("clean"), repo, allow_dirty=False)
check(report.failure is None and report.applied == (skill_rel, f"{package}/apm.yml", f"{package}/apm.lock.yaml"), f"an unchanged tree commits: {report}")
git(repo, "reset", "-q", "--hard", "synth")
check(git_status(repo) == "", "clean again")
PY
else
  for name in "26 dry run leaves the worktree untouched" "27 dirty-target refusal" \
    "28 staged validation failure" "29 hash precondition at commit time"; do
    skip "$name" "skill_console/frontmatter.py not on disk (decisions imports it)"
  done
fi

# --- CLI: the budget seam, exit codes, and a dry run end to end --------------
if (( cli_ready )); then
  py "CLI budget seam parity" "$fixtures" "$scripts_dir/skill-console" "$isolated_home" "$tmp_root/state" <<'PY'
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from sc_harness import check, run
from skill_console.budget import utf16_length

fixtures, console, home, state = sys.argv[2:6]
env = {**os.environ, "HOME": home, "XDG_STATE_HOME": state}


def number(value):
    # JSON has no infinity literal, so the CLI spells one as a string.
    return {"Infinity": math.inf, "-Infinity": -math.inf}.get(value, value)


def cli(path, measure):
    result = subprocess.run([console, "budget", "--fixture", path, "--json", "--measure", measure], capture_output=True, text=True, env=env)
    check(result.returncode == 0, f"{path} ({measure}): exit {result.returncode}: {result.stderr.strip()}")
    return json.loads(result.stdout)


paths = sorted(path for path in Path(fixtures).glob("*.json") if {"inputs", "entries"} <= set(json.loads(path.read_text())))
required = {"at-budget", "one-over", "separator-once", "greedy-non-stop", "ties-forward", "ties-reversed", "all-pinned",
            "empty", "duplicates", "cap-boundary", "when-to-use", "forced-fits", "forced-priority", "parity-plain",
            "parity-newline", "invariant-before", "invariant-after"}
check(required <= {path.stem for path in paths}, f"fixture tables missing: {sorted(required - {p.stem for p in paths})}")
# Every table under the serializer's measure; the estimator's measure only where
# the two can differ, to keep script launches down.
for path in paths:
    measures = [("width", None)] + ([("utf16", utf16_length)] if path.stem.startswith("parity-") else [])
    for measure, fn in measures:
        expected, entries, _ = run(str(path), **({"measure": fn} if fn else {}))
        got = cli(str(path), measure)
        for field in ("mode", "budget", "budget_from_env", "demand_chars", "rendered_chars", "headroom_chars", "all_pinned"):
            check(number(got[field]) == getattr(expected, field), f"{path.name} ({measure}): {field} {got[field]!r} != {getattr(expected, field)!r}")
        for field in ("full", "name_only", "capped"):
            check(got[field] == list(getattr(expected, field)), f"{path.name} ({measure}): {field} {got[field]} != {list(getattr(expected, field))}")
        check(got["rendered"] == {name: state.value for name, state in expected.rendered.items()}, f"{path.name} ({measure}): rendered map")
        check(len(got["costs"]) == len(expected.costs), f"{path.name} ({measure}): cost rows")
        for got_cost, cost in zip(got["costs"], expected.costs, strict=True):
            for field in ("name", "index", "name_only_cost", "full_cost", "upgrade_cost", "capped", "width_divergent"):
                check(got_cost[field] == getattr(cost, field), f"{path.name} ({measure}): costs[{cost.index}].{field} {got_cost[field]!r} != {getattr(cost, field)!r}")
PY

  py "CLI exit codes (fixture)" "$fixtures/v1-broken.json" <<'PY'
import sys
from sc_decisions import decisions, op
from skill_console import Op
from skill_console.decisions import dump

text = dump(decisions(op(Op.SET_FRONTMATTER, "pkg:local", field="user-invocable", value=True)))
open(sys.argv[2], "w").write(text.replace('"schema_version": 1', '"schema_version": 2', 1))
PY
  print -- '{"inputs": {}}' >"$fixtures/malformed.json"
  console budget --fixture "$fixtures/does-not-exist.json" >/dev/null 2>"$tmp_root/exit1a.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 1 ]] || { echo "missing fixture must exit 1, got $exit_code" >&2; exit 1; }
  grep -q '^skill-console: ' "$tmp_root/exit1a.err"
  console budget --fixture "$fixtures/malformed.json" >/dev/null 2>"$tmp_root/exit1b.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 1 ]] || { echo "malformed fixture must exit 1, got $exit_code" >&2; exit 1; }
  grep -q 'malformed fixture' "$tmp_root/exit1b.err"
  console apply "$fixtures/v1-broken.json" --allow-dirty-targets >/dev/null 2>"$tmp_root/exit1c.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 1 ]] || { echo "--allow-dirty-targets without --commit must exit 1, got $exit_code" >&2; exit 1; }
  grep -q -- '--commit' "$tmp_root/exit1c.err"
  console apply "$fixtures/v1-broken.json" --json >"$tmp_root/exit3.out" 2>"$tmp_root/exit3.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 3 ]] || { echo "a V1 document must exit 3, got $exit_code" >&2; exit 1; }
  grep -q '^skill-console: .*V1' "$tmp_root/exit3.err"
  python3 - "$tmp_root/exit3.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
assert payload["ok"] is False and payload["code"] == 3, payload
assert payload["violations"] and payload["violations"][0]["code"] == "V1", payload["violations"]
assert payload["violations"][0]["pointer"] == "/schema_version", payload["violations"][0]
PY
  # Discovery failure: no --model, no statusline state in the isolated state dir.
  console render --no-open --out "$tmp_root/never-written.html" >/dev/null 2>"$tmp_root/exit2.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 2 ]] || { echo "render without a model must exit 2, got $exit_code" >&2; exit 1; }
  grep -q -- '--model' "$tmp_root/exit2.err" && grep -q -- '--context-window' "$tmp_root/exit2.err"
  [[ ! -e "$tmp_root/never-written.html" ]]
  # A bare alias is a discovery failure too, not a silent guess.
  console render --no-open --model opus --context-window 200000 --out "$tmp_root/never-written.html" \
    >/dev/null 2>"$tmp_root/exit2b.err" && exit_code=0 || exit_code=$?
  [[ "$exit_code" == 2 ]] || { echo "a bare alias must exit 2, got $exit_code" >&2; exit 1; }
  grep -qi 'alias' "$tmp_root/exit2b.err"

  # --- CLI: CLAUDE_CONFIG_DIR and the built-in kill switch end to end ----------
  cfg="$tmp_root/claude-config"
  mkdir -p "$cfg/skills/cfgskill" "$tmp_root/emptyproj"
  print -- '{"skillListingBudgetFraction": 0.02}' >"$cfg/settings.json"
  print -- '{"skillUsage": {"init": {"usageCount": 7, "lastUsedAt": 1756800000000}}}' >"$cfg/.claude.json"
  printf -- '---\nname: cfgskill\ndescription: from the config dir\n---\n' >"$cfg/skills/cfgskill/SKILL.md"
  CLAUDE_CONFIG_DIR="$cfg" console render --no-open --json --model claude-fable-5-1 --context-window 200000 \
    --project-root "$tmp_root/emptyproj" --now-ms 1756800000000 --out "$tmp_root/cfg-render.html" >"$tmp_root/cfg-render.json"
  CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1 CLAUDE_CONFIG_DIR="$cfg" console render --no-open --json --model claude-fable-5-1 \
    --context-window 200000 --project-root "$tmp_root/emptyproj" --out "$tmp_root/cfg-render-nobundled.html" >"$tmp_root/cfg-render-nobundled.json"
  py "CLI CLAUDE_CONFIG_DIR" "$tmp_root/cfg-render.json" "$tmp_root/cfg-render-nobundled.json" <<'PY'
import json
import sys
from sc_harness import check

out = json.load(open(sys.argv[2]))
rows = {row["name"]: row for row in out["rows"]}
check(out["snapshot"]["budget_chars"] == 12000 and out["snapshot"]["fraction"] == 0.02, "settings.json read from CLAUDE_CONFIG_DIR")
check(rows["init"]["usage"] == {"usage_count": 7, "last_used_at_ms": 1756800000000} and rows["init"]["rank"] == 7.0, ".claude.json read from inside CLAUDE_CONFIG_DIR")
check(rows["cfgskill"]["origin"] == "user-skill" and rows["cfgskill"]["listed"], "user skills read from <CLAUDE_CONFIG_DIR>/skills")
out = json.load(open(sys.argv[3]))
check(not any(row["listed"] for row in out["rows"] if row["origin"] == "builtin"), "CLAUDE_CODE_DISABLE_BUNDLED_SKILLS delists the built-ins")
names = [cost["name"] for cost in out["admission"]["costs"]]
# The lane runs from the repo root, whose .claude/skills symlink adds a project row; only the built-ins must be gone.
check("cfgskill" in names and not {"init", "commit", "security-review"} & set(names), f"user skill listed, built-ins gone: {names}")
PY
else
  skip "CLI budget seam parity" "skill-console imports inventory.py and frontmatter.py; one is not on disk"
  skip "CLI exit codes" "skill-console imports inventory.py and frontmatter.py; one is not on disk"
fi

if (( cli_ready && builtins_ready )); then
  # Render and apply run from the copy, whose CLI resolves REPO_ROOT to the copy.
  git -C "$repo_copy" reset -q --hard fixture
  copy_console="$repo_copy/.agents/skills/agent-skill-management/scripts/skill-console"
  (
    cd "$repo_copy"
    HOME="$isolated_home" XDG_STATE_HOME="$tmp_root/state" "$copy_console" render --no-open --json \
      --model claude-fable-5-1 --context-window 200000 --out "$tmp_root/render.html" \
      >"$tmp_root/render.json" 2>"$tmp_root/render.err"
  )
  [[ -s "$tmp_root/render.html" ]]
  # The isolated HOME has no settings, so the fraction falls back to the binary default and says so.
  grep -q 'skillListingBudgetFraction is unset' "$tmp_root/render.err"
  py "26 CLI dry run (decisions from the render)" "$tmp_root/render.json" "$fixtures/dry-run.json" <<'PY'
import json
import sys
from sc_harness import check

render = json.load(open(sys.argv[2]))
check(render["ok"] is True, "render --json must report ok")
snapshot, admission = render["snapshot"], render["admission"]
check(snapshot["model"] == "claude-fable-5-1" and snapshot["bytes_per_token"] == 3, f"snapshot inputs {snapshot['model']} / {snapshot['bytes_per_token']}")
check(snapshot["budget_chars"] == admission["budget"], "snapshot budget agrees with the admission")
check(len(admission["full"]) + len(admission["name_only"]) == len(admission["costs"]) > 0, "the copy's inventory must produce rows")
predicted = {
    "cap_chars": admission["budget"],
    "mode_before": admission["mode"], "mode_after": admission["mode"],
    "demand_before": admission["demand_chars"], "demand_after": admission["demand_chars"],
    "rendered_before": admission["rendered_chars"], "rendered_after": admission["rendered_chars"],
    "full_before": len(admission["full"]), "full_after": len(admission["full"]),
    "name_only_before": len(admission["name_only"]), "name_only_after": len(admission["name_only"]),
    "newly_admitted": [], "newly_dropped": [], "added_name_only": 0, "removed_name_only": 0,
}
doc = {"schema_version": 1, "harness": "claude", "snapshot": snapshot, "predicted": predicted, "operations": []}
json.dump(doc, open(sys.argv[3], "w"), indent=1)
PY
  status_before="$(git -C "$repo_copy" status --porcelain)"
  (
    cd "$repo_copy"
    HOME="$isolated_home" XDG_STATE_HOME="$tmp_root/state" "$copy_console" apply "$fixtures/dry-run.json" --json \
      >"$tmp_root/dry-run.out" 2>"$tmp_root/dry-run.err"
  ) && exit_code=0 || exit_code=$?
  if [[ "$exit_code" != 0 ]]; then
    echo "dry run must exit 0, got $exit_code:" >&2
    cat "$tmp_root/dry-run.err" >&2
    exit 1
  fi
  [[ "$(git -C "$repo_copy" status --porcelain)" == "$status_before" ]]
  python3 - "$tmp_root/dry-run.out" "$tmp_root/state" <<'PY'
import json
import pathlib
import sys

payload = json.load(open(sys.argv[1]))
assert payload["ok"] is True and payload["dry_run"] is True, payload
assert payload["edits"] == [] and payload["applied"] == [] and payload["unapplied"] == [], payload
assert payload["staging_root"] is None, payload["staging_root"]
staging = pathlib.Path(sys.argv[2]) / "dotfiles/skill-console/staging"
assert not any(staging.iterdir()) if staging.exists() else True, list(staging.iterdir())
PY
else
  skip "26 CLI dry run (decisions from the render)" "needs skill-console importable and skill_console/builtins.json"
fi

# --- end of cases -----------------------------------------------------------

if (( ${#not_executable} )); then
  print -u2 -- "skill-console: ${#not_executable} case(s) not executable yet:"
  for name in "${not_executable[@]}"; do
    print -u2 -- "  - $name"
  done
fi
