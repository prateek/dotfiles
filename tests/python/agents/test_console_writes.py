from tests.python.agents.console_support import ConsoleRepoCase


class ConsoleWriteTests(ConsoleRepoCase):

    def test_dry_run_leaves_the_worktree_untouched(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git_status, op, sha256, skill_row
        from skill_console import Op
        from skill_console.decisions import plan, stage, validate_staged
        from skill_console.frontmatter import parse

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        self.assertTrue(git_status(repo) == "", "the copy must start clean")
        skill = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
        package_toml = "home/dot_agents/packages/design/package.toml"
        self.assertTrue("default_loaded = false" in (repo / package_toml).read_text(), "fixture: design starts default_loaded = false")
        rows = [skill_row(repo, "core", "code-gardening")]
        doc = decisions(describe("core:code-gardening", "Console test description."), op(Op.SET_DEFAULT_LOADED, "design", value=True))

        before = {path: sha256(repo / path) for path in (skill, package_toml)}
        apply_plan = plan(doc, rows, repo)
        by_path = {edit.relpath: edit for edit in apply_plan.edits}
        self.assertTrue(skill in by_path and package_toml in by_path, f"plan edits {sorted(by_path)}")
        for path in (skill, package_toml):
            edit = by_path[path]
            self.assertTrue(edit.kind == "write" and edit.before_sha256 == before[path], f"{path}: before hash")
            self.assertTrue(edit.after_sha256 == __import__("hashlib").sha256(edit.content.encode()).hexdigest(), f"{path}: after hash")
        self.assertTrue(any(path.startswith("home/.chezmoitemplates/") or path.startswith("home/dot_pi/") for path in by_path), "flipping default_loaded must regenerate the derived templates")
        self.assertTrue(git_status(repo) == "", f"plan must not touch the worktree:\n{git_status(repo)}")

        batch = stage(apply_plan, repo, staging)
        self.assertTrue(batch.root == staging and batch.plan == apply_plan, "staged batch")
        self.assertTrue(git_status(repo) == "", f"stage must not touch the worktree:\n{git_status(repo)}")
        self.assertTrue({path: sha256(repo / path) for path in before} == before, "target files unchanged in the worktree")
        self.assertTrue(parse(staging / skill).values["description"] == "Console test description.", "the staged SKILL.md carries the new description")
        self.assertTrue("default_loaded = true" in (staging / package_toml).read_text(), "the staged package.toml carries the flip")
        self.assertTrue(not (staging / ".git").exists(), "the staging copy must not carry .git")
        ok, detail = validate_staged(batch)
        self.assertTrue(ok, f"set_default_loaded must pass staged validation:\n{detail}")

    def test_dirty_target_refusal(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git, git_status, skill_row
        from skill_console.decisions import commit, plan, stage

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        skill = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
        original = (repo / skill).read_bytes()
        rows = [skill_row(repo, "core", "code-gardening")]
        doc = decisions(describe("core:code-gardening", "Dirty target check."))

        batch = stage(plan(doc, rows, repo), repo, staging / "a")
        with (repo / "README.md").open("a") as handle:
            handle.write("\nunrelated local change\n")
        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.failure is None and report.applied == (skill,) and report.unapplied == (), f"unrelated dirt: {report}")
        self.assertTrue(b"Dirty target check." in (repo / skill).read_bytes(), "the edit landed")
        self.assertTrue(" M README.md" in git_status(repo), "the unrelated change is still there")
        git(repo, "checkout", "--", ".")
        self.assertTrue((repo / skill).read_bytes() == original and git_status(repo) == "", "reset for the next step")

        batch = stage(plan(doc, rows, repo), repo, staging / "b")
        dirty = original + b"\n<!-- local edit -->\n"
        (repo / skill).write_bytes(dirty)
        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.failure and "dirty" in report.failure and skill in report.failure, f"dirty target: {report.failure!r}")
        self.assertTrue(report.applied == () and report.unapplied == (skill,), f"nothing may be applied: {report}")
        self.assertTrue((repo / skill).read_bytes() == dirty, "the dirty file is left exactly as it was")
        git(repo, "checkout", "--", ".")
        self.assertTrue(git_status(repo) == "", "clean again")

    def test_staged_validation_failure(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git_status, skill_row
        from skill_console.decisions import plan, stage, validate_staged

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        rows = [skill_row(repo, "core", "code-gardening")]
        doc = decisions(describe("core:code-gardening", "x" * 1100))
        batch = stage(plan(doc, rows, repo), repo, staging)
        ok, reason = validate_staged(batch)
        self.assertTrue(ok is False, "a 1100-character description must fail validate-agent-packages in the copy")
        self.assertTrue("validate-agent-packages" in reason and "1024" in reason, f"reason must name the failing step: {reason!r}")
        self.assertTrue(git_status(repo) == "", f"the worktree must be untouched:\n{git_status(repo)}")
        self.assertTrue("x" * 1100 in (staging / "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md").read_text(), "the staging copy keeps the failing edit for inspection")

    def test_hash_precondition_at_commit_time(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git, git_status, sha256, skill_row
        from skill_console.decisions import commit, plan, stage

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        first = "home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md"
        second = "home/dot_agents/packages/core/skills/local/decomment/SKILL.md"
        rows = [skill_row(repo, "core", "code-gardening"), skill_row(repo, "core", "decomment")]
        doc = decisions(describe("core:code-gardening", "First edit."), describe("core:decomment", "Second edit."))
        apply_plan = plan(doc, rows, repo)
        self.assertTrue([edit.relpath for edit in apply_plan.edits] == [first, second], f"edit order {[e.relpath for e in apply_plan.edits]}")
        batch = stage(apply_plan, repo, staging)

        # Someone else changes the second target after planning and commits it, so the
        # path is clean in git but its hash no longer matches the plan.
        mutated = (repo / second).read_bytes() + b"\n<!-- edited after planning -->\n"
        (repo / second).write_bytes(mutated)
        git(repo, "commit", "-q", "-am", "concurrent edit")
        self.assertTrue(git_status(repo) == "", "the mutation is committed, so the dirty gate does not fire")

        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.applied == (first,), f"applied {report.applied}")
        self.assertTrue(report.unapplied == (second,), f"unapplied {report.unapplied}")
        self.assertTrue(report.failure and second in report.failure and "changed since planning" in report.failure, f"failure {report.failure!r}")
        self.assertTrue(b"First edit." in (repo / first).read_bytes(), "the first path landed")
        self.assertTrue((repo / second).read_bytes() == mutated, "the refused path is left as the other writer left it")
        self.assertTrue(sha256(staging / second) == apply_plan.edits[1].after_sha256, "the staging copy is kept for retry")
        # The printed recovery command is `git restore -- <applied paths>`; it must be
        # enough to undo the partial batch.
        git(repo, "restore", "--", first)
        self.assertTrue(git_status(repo) == "", "git restore over the applied paths recovers the worktree")

    def test_set_package_enabled_never_writes_a_template_action(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git_status, op
        from skill_console import Op
        from skill_console.decisions import SETTINGS_TEMPLATE, ApplyError, plan

        repo = Path(str(self.repo))
        template = repo / SETTINGS_TEMPLATE
        before = template.read_bytes()
        # Bypasses validate_document on purpose: the planner is the last check before
        # staged validation renders the fragment through chezmoi's template engine.
        doc = decisions(op(Op.SET_PACKAGE_ENABLED, "design@{{ output `touch` `/tmp/x` }}", value=False))
        try:
            plan(doc, [], repo)
        except ApplyError as exc:
            self.assertTrue("Go template" in str(exc) and SETTINGS_TEMPLATE in str(exc), f"the reason must name the template: {exc}")
        else:
            self.assertTrue(False, "a key carrying a template action must not plan")
        self.assertTrue(template.read_bytes() == before and git_status(repo) == "", "the template is untouched")
        try:
            plan(decisions(op(Op.SET_PACKAGE_ENABLED, "design@prateek-local", value=False)), [], repo)
        except ApplyError as exc:
            self.assertTrue("not plain JSON" in str(exc) and SETTINGS_TEMPLATE in str(exc), f"templated settings must explain why they cannot be edited: {exc}")
        else:
            self.assertTrue(False, "the repo's Go template must not be edited as plain JSON")
        self.assertTrue(template.read_bytes() == before, "rejection preserves the source template")

        template.write_text('{"enabledPlugins":{"design@prateek-local":true},"env":{"PRESERVE":"yes"}}\n')
        try:
            accepted = plan(decisions(op(Op.SET_PACKAGE_ENABLED, "design@prateek-local", value=False)), [], repo)
            self.assertTrue([edit.relpath for edit in accepted.edits] == [SETTINGS_TEMPLATE], f"a well-formed key plans the plain JSON fragment edit: {accepted.edits}")
            import json
            self.assertTrue(json.loads(accepted.edits[0].content) == {"enabledPlugins": {"design@prateek-local": False}, "env": {"PRESERVE": "yes"}}, "the selected plugin changes and unrelated settings survive")
        finally:
            template.write_bytes(before)
        self.assertTrue(git_status(repo) == "", "the original template is restored")

    def test_symlinked_skill_md_is_refused_at_plan_and_at_commit(self):
        import os
        import subprocess
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git, git_status, skill_row
        from skill_console.decisions import ApplyError, commit, plan, stage

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
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


        link_skill()
        try:
            plan(doc, rows, repo)
        except ApplyError as exc:
            self.assertTrue("symlink" in str(exc) and skill in str(exc), f"the reason must name the link: {exc}")
        else:
            self.assertTrue(False, "planning an edit to a symlinked SKILL.md must fail")
        git(repo, "reset", "-q", "--hard", head)

        batch = stage(plan(doc, rows, repo), repo, staging)
        link_skill()
        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.applied == () and report.failure and "symlink" in report.failure and skill in report.failure, f"commit report: {report}")
        self.assertTrue((repo / skill).is_symlink() and b"Through the link." not in (repo / real).read_bytes(), "the link and its target are untouched")
        self.assertTrue(git_status(repo) == "", f"nothing left behind:\n{git_status(repo)}")
        git(repo, "reset", "-q", "--hard", head)

    def test_delete_skill_plans_the_tree_apm_yml_and_apm_lock_yaml(self):
        self.add_synthetic_vendor()
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import plan

        repo, skill = Path(str(self.repo)), str(self.synth_skill)
        package = "home/dot_agents/packages/synth"
        skill_rel, manifest, lock = f"{package}/skills/vendor/{skill}", f"{package}/apm.yml", f"{package}/apm.lock.yaml"
        target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(repo / skill_rel))


        def delete(remove_apm_dep):
            return op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=remove_apm_dep)


        apply_plan = plan(decisions(delete(True)), [target], repo)
        by_path = {edit.relpath: edit for edit in apply_plan.edits}
        self.assertTrue(set(by_path) == {skill_rel, manifest, lock}, f"plan paths {sorted(by_path)}")
        self.assertTrue(by_path[skill_rel].kind == "delete-tree" and by_path[skill_rel].after_sha256 is None, "the skill directory goes as a tree")
        manifest_text = by_path[manifest].content
        self.assertTrue(skill not in manifest_text and "    - example/repo/skills/twins\n" in manifest_text, f"apm.yml after:\n{manifest_text}")
        lock_text = by_path[lock].content
        self.assertTrue(skill not in lock_text, f"the lock still mentions {skill}:\n{lock_text}")
        self.assertTrue(lock_text.count("- repo_url: example/repo") == 1 and "virtual_path: skills/twins" in lock_text, "the sibling dependency survives")
        self.assertTrue(lock_text.count("- kind: project-relative") == 1 and "value: .agents/skills/twin-a" in lock_text, "only the deleted dependency's deployments go")
        self.assertTrue(any("docs/synth-note.md" in warning for warning in apply_plan.warnings), f"a docs/ reference only warns: {apply_plan.warnings}")

        kept = plan(decisions(delete(False)), [target], repo)
        self.assertTrue({edit.relpath for edit in kept.edits} == {skill_rel}, f"remove_apm_dep false must leave apm.yml and the lock alone: {[e.relpath for e in kept.edits]}")
        self.assertTrue(any("vendor-agent-package" in warning and "restores the skill" in warning for warning in kept.warnings), f"warnings {kept.warnings}")
        self.assertTrue(git_status(repo) == "", f"planning a deletion writes nothing:\n{git_status(repo)}")

    def test_a_failed_tree_removal_leaves_the_skill_at_its_own_path(self):
        self.add_synthetic_vendor()
        import os
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import commit, plan, stage

        repo, skill, staging = Path(str(self.repo)), str(self.synth_skill), Path(str(self.work / "staging"))
        skill_rel = f"home/dot_agents/packages/synth/skills/vendor/{skill}"
        skill_dir = repo / skill_rel
        target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(skill_dir))
        doc = decisions(op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=True))
        batch = stage(plan(doc, [target], repo), repo, staging)

        # A read-only subdirectory makes one unlink fail partway through the removal.
        (skill_dir / "scripts").chmod(0o555)
        self.assertTrue(not os.access(skill_dir / "scripts", os.W_OK), "fixture: the subdirectory must be read-only")
        try:
            report = commit(batch, repo, allow_dirty=False)
        finally:
            for scripts in skill_dir.parent.glob(f"*{skill}*/scripts"):
                scripts.chmod(0o755)
        self.assertTrue(report.failure and report.failure.startswith(f"{skill_rel}: "), f"the failure names the skill path: {report.failure!r}")
        self.assertTrue(skill_dir.is_dir() and (skill_dir / "scripts/tool.py").is_file(), "what survives stays at its own path")
        self.assertTrue(not [p for p in skill_dir.parent.iterdir() if p.name.startswith(".")], f"no renamed leftover: {sorted(p.name for p in skill_dir.parent.iterdir())}")
        self.assertTrue(all(path == skill_rel for path in report.applied), f"the manifest edits never start: {report}")
        # rmtree's order is the directory's, so whether SKILL.md went first varies.
        if (skill_dir / "SKILL.md").is_file() and (skill_dir / "SOURCE.md").is_file():
            self.assertTrue(report.applied == () and "git restore" not in report.failure, f"an intact tree is not reported as applied: {report}")
        else:
            self.assertTrue(report.applied == (skill_rel,) and "git restore" in report.failure, f"a partly removed tree is reported for recovery: {report}")
        git(repo, "restore", "--", skill_rel)
        self.assertTrue(git_status(repo) == "" and (skill_dir / "SKILL.md").is_file(), f"git restore rebuilds the skill:\n{git_status(repo)}")

    def test_delete_skill_preconditions_are_re_checked_at_commit(self):
        self.add_synthetic_vendor()
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import commit, plan, stage

        repo, skill, staging = Path(str(self.repo)), str(self.synth_skill), Path(str(self.work / "staging"))
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
            self.assertTrue(report.applied == () and (repo / skill_rel / "SKILL.md").is_file(), f"nothing may move: {report}")
            git(repo, "reset", "-q", "--hard", "synth")
            return report.failure or ""


        failure = commit_after(staged("reference"), "tests/uses-synth.zsh", f"source {skill_rel}/scripts/tool.py\n")
        self.assertTrue("tests/uses-synth.zsh" in failure and "re-plan" in failure, f"a new tracked reference must refuse the commit: {failure!r}")
        # A sibling that starts sharing the APM dependency after planning, spelled in
        # another case so the reference scan cannot see it and only the count can.
        sibling = f"{package}/skills/vendor/{skill}-copy/SOURCE.md"
        failure = commit_after(staged("sibling"), sibling, f"# Source\n\n- APM dependency: `example/repo/skills/{skill.upper()}`\n")
        self.assertTrue("owns 2" in failure and "re-plan" in failure, f"a new sibling on the dependency must refuse the commit: {failure!r}")
        report = commit(staged("clean"), repo, allow_dirty=False)
        self.assertTrue(report.failure is None and report.applied == (skill_rel, f"{package}/apm.yml", f"{package}/apm.lock.yaml"), f"an unchanged tree commits: {report}")
        git(repo, "reset", "-q", "--hard", "synth")
        self.assertTrue(git_status(repo) == "", "clean again")
