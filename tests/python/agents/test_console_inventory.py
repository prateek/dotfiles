from tests.python.agents.console_support import ConsoleCase, ROOT


class ConsoleInventoryTests(ConsoleCase):

    def test_duplicate_names_deduped_by_entries_for(self):
        from pathlib import Path


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
        self.assertTrue([entry.name for entry in entries] == ["d:same"], f"entries_for must dedupe by name: {[e.name for e in entries]}")
        self.assertTrue(entries[0].listing_text == "first occurrence", f"first occurrence must win, got {entries[0].listing_text!r}")

    def test_capability_matrix(self):
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
        self.assertTrue(set(CAPABILITIES) == set(Origin), "every origin has a capability row")
        for origin, ops in refused.items():
            for op in ops:
                self.assertTrue(not capability_allows(origin, op), f"{origin.value} must refuse {op.value}")
        for origin in Origin:
            self.assertTrue(CAPABILITIES[origin] == allowed.get(origin, frozenset()), f"{origin.value}: {sorted(CAPABILITIES[origin])}")
            self.assertTrue(not capability_allows(origin, Op.SET_BUDGET_FRACTION), f"{origin.value}: set_budget_fraction belongs to no origin")

    def test_loader_semantics(self):
        from pathlib import Path

        from skill_console import ListingEntry, Origin, Tree
        from skill_console import inventory as inv
        from skill_console.budget import budget_chars

        root = Path(str(self.work / 'loader'))


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
        self.assertTrue(recs["nodesc"].description == "Heading line here" and recs["nodesc"].description_derived, "missing description derives from the first body line")
        self.assertTrue(recs["blank"].description == "Skill" and recs["blank"].description_derived, "blank description + empty body -> 'Skill'")
        self.assertTrue(recs["wtu"].when_to_use == "  spaced  ", f"when_to_use kept verbatim: {recs['wtu'].when_to_use!r}")
        self.assertTrue(recs["boolean"].description == "true", "boolean description is JS String(true)")
        self.assertTrue(recs["longline"].description == "z" * 97 + "...", "derived description cut to 97 + '...'")
        self.assertTrue(recs["emptywtu"].when_to_use == "", "empty when_to_use stays empty")
        settings = inv.MergedSettings(values={"enabledPlugins": {"pkg@mkt": True}}, layers=("user",), projection_hash="x")
        rows = {r.name: r for r in inv.build_rows([], {Tree.CACHE: list(recs.values())}, [], {}, settings, 0)}
        # gpe(): a plugin-loaded skill needs hasUserSpecifiedDescription || whenToUse to be listed.
        self.assertTrue(not rows["pkg:nodesc"].listed and not rows["pkg:blank"].listed and not rows["pkg:longline"].listed, "plugin skills with only a derived description are not listed")
        self.assertTrue(rows["pkg:wtu"].listed and rows["pkg:boolean"].listed and rows["pkg:emptywtu"].listed, "a user description or when_to_use lists a plugin skill")
        self.assertTrue(rows["pkg:nodesc"].derived_description and not rows["pkg:boolean"].derived_description, "Row.derived_description follows the record")

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
        self.assertTrue(names == ["mine", "subskill", "projskill", "apple", "deploy", "empty", "frontend:deploy", "pack", "Zoo"], f"unmanaged order: {names}")
        by = {r.directory: r for r in unmanaged}
        self.assertTrue(by["empty"].description == "Custom command" and by["empty"].description_derived, "empty command -> 'Custom command'")
        self.assertTrue(by["apple"].description == "Apple heading" and by["mine"].description == "My body line", "derived descriptions for a command and a user skill")
        self.assertTrue(by["pack"].when_to_use == "now" and by["pack"].path.name == "SKILL.md", "a SKILL.md in a commands dir replaces its sibling .md files")
        self.assertTrue(by["deploy"].origin is Origin.USER_COMMAND and by["deploy"].path.resolve().is_relative_to(proj.resolve()), "project commands load as legacy commands")
        self.assertTrue("mainonly" not in names, "main-worktree commands are skipped when the project has its own")
        self.assertTrue(all(r.listed for r in inv.build_rows([], {Tree.CACHE: unmanaged}, [], {}, inv.MergedSettings({}, (), "x"), 0)), "skill-dir and command rows are listed even with derived descriptions")
        (proj / ".claude/commands/deploy.md").unlink()
        (proj / ".claude/commands").rmdir()
        names = [r.directory for r in inv.load_unmanaged_skills(home, proj, cwd=proj / "sub", main_worktree_root=main)]
        self.assertTrue("mainonly" in names and "deploy" not in names, f"main-worktree fallback when the worktree has no .claude/commands: {names}")
        self.assertTrue("subskill" not in [r.directory for r in inv.load_unmanaged_skills(home, proj)], "positional call walks from the project root only")

        # Sy(): disableBundledSkills (settings) or CLAUDE_CODE_DISABLE_BUNDLED_SKILLS (env, JS truthiness).
        write(home / ".claude/settings.json", '{"disableBundledSkills": true}')
        on = inv.load_settings(home, proj)
        off = inv.load_settings(root / "nohome", root / "noproj")
        self.assertTrue(on.projection_hash != off.projection_hash and on.values.get("disableBundledSkills") is True, "disableBundledSkills is projected and moves the settings hash")
        self.assertTrue(inv.bundled_skills_disabled(on, {}) and not inv.bundled_skills_disabled(off, {}), "settings flag")
        self.assertTrue(inv.bundled_skills_disabled(off, {"CLAUDE_CODE_DISABLE_BUNDLED_SKILLS": "false"}), "env 'false' still disables (non-empty string)")
        self.assertTrue(not inv.bundled_skills_disabled(off, {"CLAUDE_CODE_DISABLE_BUNDLED_SKILLS": ""}), "env '' does not")
        builtins = [ListingEntry("init", "Init.", False, False, 0.0), ListingEntry("commit", "Commit.", True, False, 0.0)]
        self.assertTrue(not any(r.listed for r in inv.build_rows([], {}, builtins, {}, off, 0, disable_bundled=True)), "disable_bundled delists every built-in")
        self.assertTrue(all(r.listed for r in inv.build_rows([], {}, builtins, {}, off, 0)), "built-ins listed by default")

        # skillListingBudgetFraction outside (0, 1]: kept, with a loud warning (the binary's handling is unverified).
        write(home / ".claude/settings.json", '{"skillListingBudgetFraction": 5}')
        inputs, _, warnings = inv.resolve_budget_inputs(inv.load_settings(home, proj), model="claude-fable-5-1", context_window=200_000, statusline_state=None, env={})
        self.assertTrue(inputs.fraction == 5.0 and budget_chars(inputs) == 3_000_000, "fraction 5 is kept")
        self.assertTrue(any("outside the binary's settings schema" in w for w in warnings), f"loud warning: {warnings}")

        cfg = root / "cfg"
        write(cfg / "settings.json", '{"skillListingBudgetFraction": 0.02}')
        self.assertTrue(inv.load_settings(root / "nohome", proj, config_dir=cfg).values["skillListingBudgetFraction"] == 0.02, "settings from config_dir")
        write(cfg / "skills/cfgskill/SKILL.md", "---\nname: cfgskill\ndescription: from the config dir\n---\n")
        self.assertTrue([r.directory for r in inv.load_unmanaged_skills(root / "nohome", root / "noproj", config_dir=cfg)] == ["cfgskill"], "user skills from config_dir")
