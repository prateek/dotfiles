from tests.python.agents.console_support import ConsoleCase, ROOT


class ConsoleFrontmatterTests(ConsoleCase):
    def setUp(self):
        super().setUp()
        for style, name in [("|", "literal-clip"), ("|-", "literal-strip"), ("|+", "literal-keep"),
                            (">", "folded-clip"), (">-", "folded-strip"), (">+", "folded-keep")]:
            path = self.fixtures / "chomp" / name / "SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text(f"---\nname: chomp\ndescription: {style}\n  alpha\n  beta\n\n---\n\n# Chomp\n")
        for name, blanks in [("one", "\n"), ("two", "\n\n")]:
            path = self.fixtures / "folded-blank" / name / "SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text(f"---\nname: folded-blank\ndescription: >-\n  first para\n  continues\n{blanks}  second para\n---\n\n# Folded\n")

    def test_block_scalar_chomping(self):
        from pathlib import Path

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
            fm = parse(Path(str(self.fixtures / 'chomp')) / name / "SKILL.md")
            self.assertTrue(fm.values["description"] == scalar, f"{name}: parsed {fm.values['description']!r} != {scalar!r}")
            span = fm.spans["description"]
            self.assertTrue(span.style == name.split("-")[0], f"{name}: style {span.style!r}")
            self.assertTrue(span.chomp == {"clip": "", "strip": "-", "keep": "+"}[name.split("-")[1]], f"{name}: chomp {span.chomp!r}")
            entry = ListingEntry(name="k:chomp", listing_text=scalar, protected=False, forced_name_only=False, rank=0.0)
            self.assertTrue(row_cost(entry, 0, max_desc_chars=1536).full_cost == by_width, f"{name}: width cost")
            self.assertTrue(row_cost(entry, 0, max_desc_chars=1536, measure=utf16_length).full_cost == by_utf16, f"{name}: utf16 cost")

    def test_folded_blank_line(self):
        from pathlib import Path

        from agent_skill_lib import skill_frontmatter
        from skill_console.budget import display_width, utf16_length

        root = Path(str(self.fixtures / 'folded-blank'))
        self.assertTrue(skill_frontmatter(root / "one")["description"] == "first para continues second para", "agent_skill_lib must collapse the blank line")
        one = "first para continues\nsecond para"
        two = "first para continues\n\nsecond para"
        self.assertTrue(display_width(one) == utf16_length(one) - 1, "one newline costs 0 width and 1 UTF-16 unit")
        self.assertTrue(display_width(two) == utf16_length(two) - 2, "two newlines cost 0 width and 2 UTF-16 units")

    def test_folded_blank_line_frontmatter(self):
        from pathlib import Path

        from skill_console.frontmatter import parse

        root = Path(str(self.fixtures / 'folded-blank'))
        one = parse(root / "one/SKILL.md").values["description"]
        self.assertTrue(one == "first para continues\nsecond para", f"one blank line: {one!r}")
        two = parse(root / "two/SKILL.md").values["description"]
        self.assertTrue(two == "first para continues\n\nsecond para", f"two blank lines: {two!r}")

    def test_duplicate_keys(self):
        from skill_console.frontmatter import FrontmatterError, parse_text

        try:
            parse_text("---\nname: dup\ndescription: first\nname: again\n---\n\n# Dup\n")
        except FrontmatterError:
            pass
        else:
            self.assertTrue(False, "a repeated key must raise FrontmatterError")
        self.assertTrue(parse_text("---\nname: ok\ndescription: fine\n---\n").values["name"] == "ok", "a clean file parses")

    def test_yaml_1_1_booleans(self):
        from skill_console.frontmatter import parse_text

        def value(raw):
            return parse_text(f"---\nname: b\ndescription: d\ndisable-model-invocation: {raw}\n---\n").values["disable-model-invocation"]

        self.assertTrue(value("no") is False, f"no -> {value('no')!r}")
        self.assertTrue(value("yes") is True, f"yes -> {value('yes')!r}")
        self.assertTrue(value('"no"') == "no", f'"no" -> {value(chr(34) + "no" + chr(34))!r}')
        self.assertTrue(value("off") is False, f"off -> {value('off')!r}")
        self.assertTrue(value("true") is True and value("false") is False, "plain booleans")

    def test_round_trip_over_the_real_inventory(self):
        from pathlib import Path

        from skill_console.frontmatter import edit, parse

        root = ROOT / "home/dot_agents/packages"
        paths = sorted(root.rglob("SKILL.md"))
        self.assertTrue(paths, "the real skill inventory must be nonempty")
        for path in paths:
            original = path.read_bytes()
            fm = parse(path)
            self.assertTrue(fm.path == path and fm.text.encode("utf-8") == original, f"{path}: parse must keep the whole file text")
            self.assertTrue(edit(fm, {}).encode("utf-8") == original, f"{path}: edit(parse(p), {{}}) is not byte-identical")
            self.assertTrue("description" in fm.spans, f"{path}: description has no span")

    def test_surgical_block_scalar_edit(self):
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
        self.assertTrue(fm.values["description"] == "old text\nsecond line", "fixture parses")
        self.assertTrue(fm.spans["description"].style == "literal" and fm.spans["description"].chomp == "-", "fixture span")
        new = edit(fm, {"description": "new text\nmore of it"})
        self.assertTrue("description: |-\n  new text\n  more of it\nuser-invocable: true\n" in new, f"indicator, indentation, or neighbour lost:\n{new}")
        self.assertTrue("# keep this comment where it is\n" in new, "the adjacent comment must survive")
        self.assertTrue(new.endswith("---\n\n# Surgical\n"), "the body must be untouched")
        self.assertTrue(new.count("old text") == 0, "the old text must be gone")
        self.assertTrue(parse_text(new).values["description"] == "new text\nmore of it", "the edited file re-parses to the new text")

    def test_add_and_delete_keys(self):
        from skill_console.frontmatter import FrontmatterError, edit, parse_text

        crlf = "---\r\nname: crlf\r\ndescription: d\r\n---\r\n\r\n# Body\r\n"
        fm = parse_text(crlf)
        self.assertTrue(fm.line_ending == "\r\n", f"line ending {fm.line_ending!r}")
        added = edit(fm, {"disable-model-invocation": True})
        self.assertTrue(added == "---\r\nname: crlf\r\ndescription: d\r\ndisable-model-invocation: true\r\n---\r\n\r\n# Body\r\n", repr(added))

        block = "---\nname: del\ndescription: |-\n  gone\n  entirely\nuser-invocable: false\n---\n\n# Body\n\n\n"
        fm = parse_text(block)
        deleted = edit(fm, {"description": None})
        self.assertTrue(deleted == "---\nname: del\nuser-invocable: false\n---\n\n# Body\n\n\n", repr(deleted))
        self.assertTrue("description" not in parse_text(deleted).values, "the deleted key must not re-parse")
        self.assertTrue(edit(fm, {}) == block, "trailing newline count survives the round trip")

        flow = "---\nname: flow\ndescription: d\nmetadata: {a: 1}\n---\n"
        try:
            edit(parse_text(flow), {"metadata": "x"})
        except FrontmatterError:
            pass
        else:
            self.assertTrue(False, "editing a flow mapping must raise FrontmatterError")

    def test_unsafe_plain_scalars_are_double_quoted(self):
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
            self.assertTrue(line.startswith('description: "') and line.endswith('"'), f"{value!r} must be double-quoted, got {line!r}")
            self.assertTrue(not raw_unprintable(line), f"{value!r} must be escaped inside the quotes, got {line!r}")
            self.assertTrue(parse_text(written).values["description"] == value, f"{value!r} must read back")
            appended = edit(parse_text("---\nname: q\n---\n"), {"description": value})
            self.assertTrue('description: "' in appended and parse_text(appended).values["description"] == value, f"{value!r} appended: {appended!r}")
        written = edit(base, {"description": "a\x0cb\nc"})
        self.assertTrue('description: "a\\x0cb\\nc"' in written, f"a block scalar cannot carry a form feed either: {written!r}")
        self.assertTrue("description: -x and ?y stay plain\n" in edit(base, {"description": "-x and ?y stay plain"}), "indicators not followed by whitespace stay plain")
