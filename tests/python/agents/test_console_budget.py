from tests.python.agents.console_support import ConsoleCase, ROOT


class ConsoleBudgetTests(ConsoleCase):

    def test_fits_and_priority(self):
        from tests.python.agents.console_support import run_budget as run
        from skill_console import Rendered

        fixtures = str(self.fixtures)
        fits, entries, _ = run(f"{fixtures}/at-budget.json")
        self.assertTrue(fits.budget == 61, f"budget {fits.budget} != 61")
        self.assertTrue(fits.mode == "fits", f"mode {fits.mode!r} at exactly the budget")
        self.assertTrue(fits.demand_chars == 61, f"demand {fits.demand_chars} != 61")
        self.assertTrue(fits.rendered_chars == fits.demand_chars, "fits mode must render the whole demand")
        self.assertTrue(fits.headroom_chars == 0, f"headroom {fits.headroom_chars} != 0")
        self.assertTrue(fits.full == ("a:one", "a:two", "a:three") and fits.name_only == (), "every row full in fits mode")
        self.assertTrue(all(state is Rendered.FULL for state in fits.rendered.values()), "rendered map disagrees with full tuple")
        self.assertTrue([c.full_cost for c in fits.costs] == [19, 19, 21], f"full costs {[c.full_cost for c in fits.costs]}")
        self.assertTrue([c.name_only_cost for c in fits.costs] == [7, 7, 9], "name-only costs")
        self.assertTrue([c.upgrade_cost for c in fits.costs] == [12, 12, 12], "upgrade costs")
        self.assertTrue(not fits.all_pinned and not fits.budget_from_env and fits.capped == (), "flags in fits mode")

        priority, _, _ = run(f"{fixtures}/one-over.json")
        self.assertTrue(priority.mode == "priority", f"mode {priority.mode!r} one character under")
        self.assertTrue(priority.demand_chars == 61, "demand does not depend on the budget")
        self.assertTrue(priority.full == ("a:one", "a:two"), f"full {priority.full}")
        self.assertTrue(priority.name_only == ("a:three",), f"name-only {priority.name_only}")
        self.assertTrue(priority.rendered_chars == 49, f"rendered {priority.rendered_chars} != 49")
        self.assertTrue(priority.headroom_chars == 11, f"headroom {priority.headroom_chars} != 11")
        self.assertTrue(priority.rendered["a:three"] is Rendered.NAME_ONLY, "rendered map for the dropped row")

    def test_separator_charged_once(self):
        from tests.python.agents.console_support import run_budget as run

        admission, _, _ = run(str(self.fixtures / 'separator-once.json'))
        self.assertTrue(admission.mode == "priority", f"mode {admission.mode!r}")
        self.assertTrue(admission.demand_chars == 71, f"demand {admission.demand_chars} != 4*17 + 3")
        self.assertTrue(admission.full == ("p:a", "p:b", "p:c"), f"full {admission.full}; a per-row separator would admit only two")
        self.assertTrue(admission.name_only == ("p:d",), f"name-only {admission.name_only}")
        self.assertTrue(admission.rendered_chars == 59 and admission.headroom_chars == 0, "the admitted rows fill the budget exactly")

    def test_greedy_non_stop(self):
        from tests.python.agents.console_support import run_budget as run

        admission, _, _ = run(str(self.fixtures / 'greedy-non-stop.json'))
        costs = {c.name: c for c in admission.costs}
        self.assertTrue(costs["w:wide"].upgrade_cost == 42 and costs["w:narrow"].upgrade_cost == 7, "fixture upgrade costs")
        self.assertTrue(admission.mode == "priority", f"mode {admission.mode!r}")
        self.assertTrue(admission.full == ("w:narrow",), f"full {admission.full}; the walk must continue past the wide miss")
        self.assertTrue(admission.name_only == ("w:wide",), f"name-only {admission.name_only}")
        self.assertTrue(admission.rendered_chars == 19 + 7, f"rendered {admission.rendered_chars}")

    def test_stable_tie_break(self):
        from tests.python.agents.console_support import run_budget as run

        fixtures = str(self.fixtures)
        forward, _, _ = run(f"{fixtures}/ties-forward.json")
        self.assertTrue(forward.mode == "priority" and forward.headroom_chars == 0, "fixture must admit exactly two rows")
        self.assertTrue(forward.full == ("t:r1", "t:r2"), f"forward full {forward.full}")
        self.assertTrue(forward.name_only == ("t:r3", "t:r4", "t:r5"), f"forward name-only {forward.name_only}")
        reversed_, _, _ = run(f"{fixtures}/ties-reversed.json")
        self.assertTrue(reversed_.full == ("t:r5", "t:r4"), f"reversed full {reversed_.full}; ties must follow listing order")
        self.assertTrue(reversed_.name_only == ("t:r3", "t:r2", "t:r1"), f"reversed name-only {reversed_.name_only}")

    def test_all_pinned(self):
        from tests.python.agents.console_support import run_budget as run
        from skill_console.budget import render_listing

        admission, entries, inputs = run(str(self.fixtures / 'all-pinned.json'))
        self.assertTrue(admission.budget == 1, f"budget {admission.budget}")
        self.assertTrue(admission.mode == "priority", f"mode {admission.mode!r}")
        self.assertTrue(admission.all_pinned, "all_pinned must be set")
        self.assertTrue(admission.full == ("commit", "review", "compact") and admission.name_only == (), "every protected row renders full")
        self.assertTrue(admission.rendered_chars == admission.demand_chars > admission.budget, "rendered equals demand and exceeds the budget")
        self.assertTrue(admission.headroom_chars == admission.budget - admission.rendered_chars < 0, "headroom is negative, not clamped")
        listing = render_listing(entries, inputs)
        self.assertTrue(listing == "- commit: Create a git commit\n- review: Review a pull request\n- compact: Compact the conversation", repr(listing))
        self.assertTrue(len(listing) == admission.rendered_chars, "rendered_chars must equal the emitted text length")

    def test_empty_listing(self):
        from tests.python.agents.console_support import run_budget as run
        from skill_console.budget import render_listing

        admission, entries, inputs = run(str(self.fixtures / 'empty.json'))
        self.assertTrue(render_listing(entries, inputs) == "", "empty listing must render as the empty string")
        self.assertTrue(admission.mode == "fits", f"mode {admission.mode!r}")
        self.assertTrue(admission.demand_chars == 0 and admission.rendered_chars == 0, "zero-cost admission")
        self.assertTrue(admission.headroom_chars == admission.budget == 1000, "headroom is the whole budget")
        self.assertTrue(admission.costs == () and admission.full == () and admission.name_only == () and admission.rendered == {}, "no rows anywhere")
        self.assertTrue(not admission.all_pinned, "an empty listing is not all-pinned")

    def test_duplicate_names_in_admit(self):
        from tests.python.agents.console_support import run_budget as run

        admission, entries, _ = run(str(self.fixtures / 'duplicates.json'))
        self.assertTrue(len(admission.costs) == 2, "both duplicates must be costed")
        self.assertTrue(admission.demand_chars == (10 + 16) + (10 + 25) + 1, f"demand {admission.demand_chars}; both rows charged plus one separator")
        self.assertTrue(admission.full == ("d:same", "d:same"), f"full {admission.full}")
        self.assertTrue(list(admission.rendered) == ["d:same"], "rendered map keys by name")

    def test_cap_boundary(self):
        from tests.python.agents.console_support import run_budget as run, write_fixture
        from skill_console import ELLIPSIS, ListingEntry
        from skill_console.budget import cap_description, row_cost, utf16_length

        name = "c:cap"
        def entry(text):
            return ListingEntry(name=name, listing_text=text, protected=False, forced_name_only=False, rank=0.0)

        for units, expect_capped in ((1535, False), (1536, False), (1537, True)):
            cost = row_cost(entry("x" * units), 0, max_desc_chars=1536)
            self.assertTrue(cost.capped is expect_capped, f"{units} units: capped={cost.capped}")
            expected = (1536 if expect_capped else units) + len(name) + 4
            self.assertTrue(cost.full_cost == expected, f"{units} units: full_cost {cost.full_cost} != {expected}")
            self.assertTrue(cost.name_only_cost == len(name) + 2, "name-only cost ignores the description")

        text, capped = cap_description("x" * 1537, 1536)
        self.assertTrue(capped and text.endswith(ELLIPSIS) and utf16_length(text) == 1536, "capped text is 1535 units plus the ellipsis")
        self.assertTrue(text[:1535] == "x" * 1535, "the cap keeps the first 1535 units")
        # The cap counts UTF-16 units: an astral character is two, so 1535 ASCII + one
        # emoji is over the cap even though Python sees 1536 characters.
        astral = "x" * 1535 + "\U0001F600"
        self.assertTrue(len(astral) == 1536 and utf16_length(astral) == 1537, "fixture: astral text is 1537 units")
        text, capped = cap_description(astral, 1536)
        self.assertTrue(capped and text == "x" * 1535 + ELLIPSIS, "the slice happens in UTF-16 units")

        write_fixture(str(self.fixtures / 'cap-boundary.json'), {"context_window": 100000, "bytes_per_token": 1, "fraction": 1.0, "max_desc_chars": 1536}, [
            {"name": "c:under", "description": "x" * 1535},
            {"name": "c:at", "description": "x" * 1536},
            {"name": "c:over", "description": "x" * 1537},
        ])
        admission, _, _ = run(str(self.fixtures / 'cap-boundary.json'))
        self.assertTrue(admission.capped == ("c:over",), f"capped tuple {admission.capped}")
        self.assertTrue([c.full_cost for c in admission.costs] == [1535 + 11, 1536 + 8, 1536 + 10], "fixture full costs")

    def test_bytes_per_token(self):
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
            self.assertTrue(bytes_per_token(model_id) == value, f"{model_id}: {bytes_per_token(model_id)} != {value}")
        # The divergent forms are exactly the ones a literal lookup gets wrong.
        naive = {model_id for model_id in expected if model_id in LEGACY_BYTES_PER_TOKEN_FAMILIES}
        self.assertTrue(naive == set(), f"fixture ids must not be literal set members: {naive}")
        self.assertTrue(normalize_model_id("claude-opus-4") == "claude-opus-4-0", "regex branch for a bare major")
        self.assertTrue(normalize_model_id("claude-sonnet-4") == "claude-sonnet-4-0", "regex branch for sonnet")
        self.assertTrue(normalize_model_id("claude-opus-4-9") == "claude-opus-4-9", "no literal, no regex, no date suffix")
        self.assertTrue(normalize_model_id("custom-model-20250101") == "custom-model", "date-suffix fallback")
        self.assertTrue(normalize_model_id("claude-opus-4-5[1m]") == "claude-opus-4-5", "[1m] strip")

    def test_env_budget(self):
        from skill_console import BudgetInputs
        from skill_console.budget import admit, budget_chars, parse_env_budget

        computed = 200_000 * 3 * 0.04
        def inputs(raw):
            return BudgetInputs(context_window=200_000, bytes_per_token=3, fraction=0.04, max_desc_chars=1536, env_budget=parse_env_budget(raw))

        self.assertTrue(parse_env_budget(None) is None and budget_chars(inputs(None)) == computed, "unset -> computed")
        self.assertTrue(parse_env_budget("0") == 0 and budget_chars(inputs("0")) == computed, '"0" -> computed')
        self.assertTrue(parse_env_budget("1200") == 1200 and budget_chars(inputs("1200")) == 1200, '"1200" -> 1200')
        self.assertTrue(parse_env_budget("-5") == -5 and budget_chars(inputs("-5")) == -5, '"-5" is used verbatim')
        self.assertTrue(parse_env_budget("banana") is None and budget_chars(inputs("banana")) == computed, "NaN -> computed")
        for raw, from_env in ((None, False), ("0", False), ("1200", True), ("-5", False)):
            admission = admit([], inputs(raw))
            self.assertTrue(admission.budget_from_env is from_env, f"{raw!r}: budget_from_env {admission.budget_from_env}")
        self.assertTrue(admit([], inputs("-5")).budget == -5, "a negative env budget survives into the Admission")

    def test_max_1_floor(self):
        from skill_console import BudgetInputs
        from skill_console.budget import budget_chars

        tiny = BudgetInputs(context_window=1, bytes_per_token=4, fraction=0.0001, max_desc_chars=1536, env_budget=None)
        self.assertTrue(budget_chars(tiny) == 1, f"budget {budget_chars(tiny)} != 1")
        fractional = BudgetInputs(context_window=333, bytes_per_token=3, fraction=0.01, max_desc_chars=1536, env_budget=None)
        self.assertTrue(budget_chars(fractional) == 9, f"floor(9.99) -> {budget_chars(fractional)}")

    def test_env_budget_floats(self):
        import math
        from tests.python.agents.console_support import run_budget as run
        from skill_console.budget import parse_env_budget

        # Zx(): Number() first, grouped digits second; iTe() then uses the number as-is.
        for raw, want in {"Infinity": math.inf, "1e400": math.inf, "0.5": 0.5, "30000": 30000, "-5": -5,
                          "0": 0, "": 0, "-0": 0, "abc": None, "NaN": None, "1_000": 1000, "0x10": 16, " 24,000 ": 24000}.items():
            got = parse_env_budget(raw)
            self.assertTrue(got is None if want is None else got == want, f"parse_env_budget({raw!r}) -> {got!r}")
            self.assertTrue(want is None or type(got) is type(want), f"{raw!r}: integral values are int, others float ({type(got).__name__})")
        inf, _, _ = run(str(self.fixtures / 'env-infinity.json'))
        self.assertTrue(inf.mode == "fits" and inf.budget == math.inf and inf.budget_from_env, f"Infinity: {inf.mode} {inf.budget}")
        self.assertTrue(set(inf.full) == {"e:a", "e:b"} and inf.headroom_chars == math.inf, "Infinity: everything full, infinite headroom")
        half, _, _ = run(str(self.fixtures / 'env-half.json'))
        self.assertTrue(half.mode == "priority" and half.budget == 0.5, f"0.5: {half.mode} {half.budget}")
        self.assertTrue(half.full == ("e:b",) and half.name_only == ("e:a",), "0.5: protected row full, candidate never admitted")
        self.assertTrue(half.rendered_chars == len("- e:b: 0123456789") + len("- e:a") + 1, f"0.5: rendered {half.rendered_chars} stays an exact integer")
        self.assertTrue(half.headroom_chars == 0.5 - half.rendered_chars, "0.5: headroom keeps the fractional budget")

    def test_rank(self):
        import math

        from skill_console import MS_PER_DAY, Usage
        from skill_console.budget import rank

        now = 1_772_409_840_000
        def used(days_ago, count=4):
            return Usage(usage_count=count, last_used_at_ms=now - int(days_ago * MS_PER_DAY))

        self.assertTrue(rank(None, now) == 0.0, "never used")
        self.assertTrue(rank(used(0), now) == 4.0, f"used today: {rank(used(0), now)}")
        self.assertTrue(math.isclose(rank(used(7), now), 2.0), f"seven days: {rank(used(7), now)}")
        self.assertTrue(math.isclose(rank(used(14), now), 1.0), f"fourteen days: {rank(used(14), now)}")
        self.assertTrue(math.isclose(rank(used(60), now), 0.4), f"sixty days hits the floor: {rank(used(60), now)}")
        self.assertTrue(rank(used(23), now) > 0.4 > rank(used(24), now) - 1e-9 and math.isclose(rank(used(24), now), 0.4), "the floor takes over between day 23 and 24")
        self.assertTrue(math.isclose(rank(used(-7), now), 8.0), f"future use is unclamped: {rank(used(-7), now)}")
        self.assertTrue(rank(used(0, count=0), now) == 0.0, "zero count ranks zero even when fresh")

    def test_context_cell(self):
        from skill_console.budget import context_cell

        self.assertTrue(context_cell(58, 3) == "< 20", f"58 chars at 3 b/t: {context_cell(58, 3)!r}")
        self.assertTrue(context_cell(59, 3) == "~20", f"59 chars at 3 b/t: {context_cell(59, 3)!r}")
        # Banker's rounding would print ~20 for both.
        self.assertTrue(context_cell(75, 3) == "~30", f"25 tokens: {context_cell(75, 3)!r}")
        self.assertTrue(context_cell(49, 2) == "~30", f"24.5 tokens: {context_cell(49, 2)!r}")
        self.assertTrue(context_cell(0, 3) == "< 20", "zero cost")

    def test_width_guard(self):
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
            self.assertTrue(utf16_length(text) == utf16, f"{label}: utf16 {utf16_length(text)} != {utf16}")
            self.assertTrue(display_width(text) == width, f"{label}: width {display_width(text)} != {width}")
            cost = row_cost(ListingEntry("g:x", text, False, False, 0.0), 0, max_desc_chars=1536)
            self.assertTrue(cost.width_divergent is divergent, f"{label}: width_divergent {cost.width_divergent}")
            ok, reason = write_safe(text)
            self.assertTrue(ok is safe, f"{label}: write_safe {ok} ({reason})")
            self.assertTrue(ok or reason, f"{label}: a refusal must carry a reason")

    def test_grapheme_clusters(self):
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
            self.assertTrue(utf16_length(text) == utf16, f"{label}: utf16 {utf16_length(text)} != {utf16}")
            self.assertTrue(display_width(text) == width, f"{label}: width {display_width(text)} != {width}")
        self.assertTrue(display_width("- gate-g-emoji: " + "❤️" * 15) == 16 + 30, "gate-g-emoji row cost")

    def test_when_to_use(self):
        from tests.python.agents.console_support import run_budget as run
        from skill_console.budget import listing_text

        self.assertTrue(listing_text("Do the thing", "when asked") == "Do the thing - when asked", "join text")
        admission, entries, _ = run(str(self.fixtures / 'when-to-use.json'))
        texts = {entry.name: entry.listing_text for entry in entries}
        self.assertTrue(texts["u:joined"] == "Do the thing - when asked", texts["u:joined"])
        for name in ("u:null", "u:absent", "u:empty"):
            self.assertTrue(texts[name] == "Do the thing", f"{name}: {texts[name]!r}")
        costs = {cost.name: cost.full_cost for cost in admission.costs}
        self.assertTrue(costs["u:joined"] == len("u:joined") + 4 + len("Do the thing") + 3 + len("when asked"), f"joined cost {costs['u:joined']}")
        self.assertTrue(costs["u:null"] == len("u:null") + 4 + len("Do the thing"), f"null cost {costs['u:null']}")

    def test_forced_name_only(self):
        from tests.python.agents.console_support import run_budget as run

        fixtures = str(self.fixtures)
        fits, _, _ = run(f"{fixtures}/forced-fits.json")
        self.assertTrue(fits.mode == "fits", f"mode {fits.mode!r}")
        self.assertTrue(fits.demand_chars == 10 + 20 + 1, f"demand {fits.demand_chars}; the forced row is charged name-only")
        self.assertTrue(fits.full == ("f:free",) and fits.name_only == ("f:forced",), "forced row stays name-only even when everything fits")
        priority, _, _ = run(f"{fixtures}/forced-priority.json")
        self.assertTrue(priority.mode == "priority", f"mode {priority.mode!r}")
        self.assertTrue(priority.full == (), f"full {priority.full}; upgrades of 12 exceed headroom 11")
        self.assertTrue(priority.rendered_chars == 29, f"rendered {priority.rendered_chars}; the forced row costs name-only in the baseline")

    def test_estimator_parity(self):
        from tests.python.agents.console_support import run_budget as run
        from skill_console.budget import utf16_length

        fixtures = str(self.fixtures)
        by_width, _, _ = run(f"{fixtures}/parity-plain.json")
        by_utf16, _, _ = run(f"{fixtures}/parity-plain.json", measure=utf16_length)
        self.assertTrue(by_width.mode == "priority", "fixture must be in priority mode")
        self.assertTrue((by_width.full, by_width.name_only) == (by_utf16.full, by_utf16.name_only), "same membership without newlines")
        self.assertTrue(by_width.demand_chars == by_utf16.demand_chars, "same demand without newlines")

        by_width, _, _ = run(f"{fixtures}/parity-newline.json")
        by_utf16, _, _ = run(f"{fixtures}/parity-newline.json", measure=utf16_length)
        self.assertTrue(by_utf16.demand_chars == by_width.demand_chars + 1, f"utf16 demand {by_utf16.demand_chars} vs width {by_width.demand_chars}")
        self.assertTrue([cost.width_divergent for cost in by_width.costs] == [True, False, False], "divergence is flagged on the newline row only")
        self.assertTrue([cost.width_divergent for cost in by_utf16.costs] == [True, False, False], "width_divergent does not depend on the measure")

    def test_predicted_invariant(self):
        from tests.python.agents.console_support import fixture_entry, write_fixture, run_budget as run
        from skill_console import BudgetInputs
        from skill_console.budget import diff_admissions

        fixtures = str(self.fixtures)
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
        self.assertTrue(before.full == ("x:A", "x:D") and before.name_only == ("x:B", "x:C"), f"before {before.full} / {before.name_only}")
        self.assertTrue(after.full == ("x:A", "x:B", "x:F") and after.name_only == ("x:E",), f"after {after.full} / {after.name_only}")

        predicted = diff_admissions(before, after)
        self.assertTrue(predicted.cap_chars == 59, f"cap_chars {predicted.cap_chars}")
        self.assertTrue(predicted.newly_admitted == ("x:B",), f"newly_admitted {predicted.newly_admitted}")
        self.assertTrue(predicted.newly_dropped == (), f"newly_dropped {predicted.newly_dropped}")
        self.assertTrue(predicted.removed_name_only == 1, f"removed_name_only {predicted.removed_name_only}; C left name-only, D left full")
        self.assertTrue(predicted.added_name_only == 1, f"added_name_only {predicted.added_name_only}; E joined name-only, F joined full")
        self.assertTrue((predicted.full_before, predicted.full_after, predicted.name_only_before, predicted.name_only_after) == (2, 3, 2, 1), "counts")
        self.assertTrue((predicted.demand_before, predicted.demand_after) == (before.demand_chars, after.demand_chars), "demand fields")
        self.assertTrue((predicted.rendered_before, predicted.rendered_after) == (before.rendered_chars, after.rendered_chars), "rendered fields")
        self.assertTrue((predicted.mode_before, predicted.mode_after) == ("priority", "priority"), "modes")
        corrected = (predicted.name_only_before - predicted.removed_name_only + predicted.added_name_only
                     - len(predicted.newly_admitted) + len(predicted.newly_dropped))
        self.assertTrue(predicted.name_only_after == corrected, f"corrected invariant: {predicted.name_only_after} != {corrected}")
        plan_version = predicted.name_only_before - predicted.removed_name_only + predicted.added_name_only
        self.assertTrue(predicted.name_only_after != plan_version, "this table must distinguish the corrected invariant from the plan's")
