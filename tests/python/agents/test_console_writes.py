from tests.python.agents.console_support import ConsoleRepoCase

# console_support puts the console scripts on sys.path.
from agent_skill_lib import marketplace_build_command


class ConsoleWriteTests(ConsoleRepoCase):

    def test_imported_edits_apply_after_arbitrary_patch_names_and_preserve_missing_final_newlines(self):
        from tests.python.agents.console_documents import decisions, describe, row
        from skill_console import Origin
        from skill_console.decisions import plan, stage
        from skill_console.frontmatter import parse

        self.add_synthetic_vendor()
        project = self.repo / "agent-marketplace"
        package = project / "packages/synth"
        patches = package / "patches"
        patches.mkdir()
        published = project / "build/marketplace/plugins/synth/skills" / self.synth_skill
        identity = f"synth:{self.synth_skill}"
        for filename, newline in (("z-reviewed.patch", True), ("z" * 235 + ".patch", True),
                                  ("001-reviewed.patch", False)):
            with self.subTest(filename=filename, final_newline=newline):
                baseline = patches / filename
                tail = " Original.\n" if newline else "-Original.\n+Original.\n\\ No newline at end of file\n"
                baseline.write_text(f"--- a/skills/{self.synth_skill}/SKILL.md\n+++ b/skills/{self.synth_skill}/SKILL.md\n"
                    f"@@ -1,6 +1,6 @@\n ---\n name: {self.synth_skill}\n"
                    "-description: Synthetic imported skill.\n+description: Reviewed baseline.\n ---\n \n" + tail)
                try:
                    self.command(marketplace_build_command(project))
                    self.assertEqual((published / "SKILL.md").read_text().endswith("\n"), newline)
                    planned = plan(decisions(describe(identity, "Console-approved description.")),
                        [row(identity, "synth", self.synth_skill, Origin.REPO_VENDOR, str(published))], self.repo)
                    batch = stage(planned, self.repo, self.work / filename)
                    self.command(marketplace_build_command(batch.root / "agent-marketplace"))
                    result = batch.root / published.relative_to(self.repo) / "SKILL.md"
                    self.assertEqual(parse(result).values["description"], "Console-approved description.")
                    self.assertEqual(result.read_text().endswith("\n"), newline)
                    self.assertEqual((batch.root / baseline.relative_to(self.repo)).read_bytes(), baseline.read_bytes())
                finally:
                    baseline.unlink()

    def test_imported_commit_refuses_changed_marketplace_inputs_before_any_write(self):
        import difflib
        from tests.python.agents.console_documents import decisions, describe, row
        from skill_console import Origin
        from skill_console.decisions import commit, plan, stage
        from skill_console.frontmatter import parse

        self.add_synthetic_vendor()
        project = self.repo / "agent-marketplace"
        package = project / "packages/synth"
        source = project / "apm_modules/example/repo/skills" / self.synth_skill / "skills" / self.synth_skill / "SKILL.md"
        original = source.read_text()
        patch = package / "patches/001-reviewed.patch"
        patch.parent.mkdir()
        patch.write_text("".join(difflib.unified_diff(original.splitlines(True),
            original.replace("Synthetic imported skill.", "Reviewed baseline.").splitlines(True),
            fromfile=f"a/skills/{self.synth_skill}/SKILL.md", tofile=f"b/skills/{self.synth_skill}/SKILL.md")))
        self.git("add", "agent-marketplace")
        self.git("commit", "-q", "-m", "reviewed imported baseline")
        self.command(marketplace_build_command(project))
        published = project / "build/marketplace/plugins/synth/skills" / self.synth_skill
        identity = f"synth:{self.synth_skill}"
        planned = plan(decisions(describe(identity, "Console-approved description.")),
                       [row(identity, "synth", self.synth_skill, Origin.REPO_VENDOR, str(published))], self.repo)
        batch = stage(planned, self.repo, self.work / "staged-import")
        self.command(marketplace_build_command(batch.root / "agent-marketplace"))
        targets = {edit.relpath: (self.repo / edit.relpath).read_bytes()
                   if (self.repo / edit.relpath).exists() else None for edit in planned.edits}
        mutations = (
            (patch, patch.read_bytes().replace(b"Reviewed baseline.", b"Concurrent baseline.")),
            (package / "overlays/extra.md", b"A new marketplace input.\n"),
            (project / "scripts/marketplace.py", (project / "scripts/marketplace.py").read_bytes() + b"\n"),
        )
        for path, changed in mutations:
            before = path.read_bytes() if path.exists() else None
            try:
                path.write_bytes(changed)
                for allow_dirty in (False, True):
                    with self.subTest(path=path.relative_to(self.repo), allow_dirty=allow_dirty):
                        report = commit(batch, self.repo, allow_dirty=allow_dirty)
                        self.assertEqual(report.applied, ())
                        self.assertEqual(report.unapplied, tuple(targets))
                        self.assertIn("marketplace inputs changed since planning", report.failure or "")
                        for relative, accepted in targets.items():
                            target = self.repo / relative
                            self.assertEqual(target.read_bytes() if target.exists() else None, accepted)
            finally:
                if before is None:
                    path.unlink()
                else:
                    path.write_bytes(before)
        note = self.repo / "README.md"
        note.write_text(note.read_text() + "\nUnrelated edit.\n")
        report = commit(batch, self.repo, allow_dirty=False)
        self.assertIsNone(report.failure)
        self.assertEqual(report.applied, tuple(targets))
        self.command(marketplace_build_command(project))
        self.assertEqual(parse(published / "SKILL.md").values["description"], "Console-approved description.")
        self.assertEqual(source.read_text(), original)
        self.assertTrue(note.read_text().endswith("Unrelated edit.\n"))

    def test_imported_edits_stage_patches_overlay_policy_and_matching_versions(self):
        import json
        import subprocess
        from tests.python.agents.console_documents import decisions, describe, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import plan, stage
        from skill_console.frontmatter import parse

        self.add_synthetic_vendor()
        project = self.repo / "agent-marketplace"
        package = project / "packages/synth"
        sidecar = package / "overlays/skills" / self.synth_skill / "agents/openai.yaml"
        sidecar.parent.mkdir()
        sidecar.write_text("interface:\n  display_name: Preserve me\npolicy:\n  allow_implicit_invocation: true\n")
        self.command(marketplace_build_command(project))
        published = project / "build/marketplace/plugins/synth/skills" / self.synth_skill
        source = project / "apm_modules/example/repo/skills" / self.synth_skill / "skills" / self.synth_skill / "SKILL.md"
        original = source.read_bytes()
        identity = f"synth:{self.synth_skill}"
        document = decisions(describe(identity, "Reviewed imported description."),
            op(Op.SET_FRONTMATTER, identity, field="disable-model-invocation", value=True),
            op(Op.SET_FRONTMATTER, "synth:twin-a", field="disable-model-invocation", value=True))
        planned = plan(document, [row(identity, "synth", self.synth_skill, Origin.REPO_VENDOR, str(published)),
            row("synth:twin-a", "synth", "twin-a", Origin.REPO_VENDOR, str(published.parent / "twin-a"))], self.repo)
        self.assertFalse(any("/apm_modules/" in edit.relpath for edit in planned.edits))
        staged = self.work / "staged-import"
        stage(planned, self.repo, staged)
        result = subprocess.run(marketplace_build_command(staged / "agent-marketplace"),
                                env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = staged / "agent-marketplace/build/marketplace/plugins/synth"
        meta = parse(output / "skills" / self.synth_skill / "SKILL.md").values
        self.assertEqual(meta["description"], "Reviewed imported description.")
        self.assertTrue(meta["disable-model-invocation"])
        policy_text = (output / "skills" / self.synth_skill / "agents/openai.yaml").read_text()
        self.assertIn("allow_implicit_invocation: false", policy_text)
        self.assertIn("display_name: Preserve me", policy_text)
        self.assertTrue(parse(output / "skills/twin-a/SKILL.md").values["disable-model-invocation"])
        self.assertIn("allow_implicit_invocation: false", (output / "skills/twin-a/agents/openai.yaml").read_text())
        for native in ("claude", "codex"):
            self.assertEqual(json.loads((output / f".{native}-plugin/plugin.json").read_text())["version"], "1.0.1")
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual((staged / source.relative_to(self.repo)).read_bytes(), original)

    def test_dry_run_leaves_the_worktree_untouched(self):
        from pathlib import Path
        import tomllib
        from tests.python.agents.console_documents import decisions, describe, git_status, op, sha256, skill_row
        from skill_console import Op
        from skill_console.decisions import plan, stage, validate_staged
        from skill_console.frontmatter import parse

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        self.assertTrue(git_status(repo) == "", "the copy must start clean")
        skill = "agent-marketplace/packages/core/skills/code-gardening/SKILL.md"
        package_toml = "home/.chezmoidata/agent_plugins.toml"
        self.assertFalse(tomllib.loads((repo / package_toml).read_text())["agent_plugins"]["design"]["default_loaded"])
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
        self.assertIn("agent-marketplace/packages/core/.codex-plugin/plugin.json", by_path)
        self.assertNotIn("home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl", by_path)
        self.assertTrue(git_status(repo) == "", f"plan must not touch the worktree:\n{git_status(repo)}")

        batch = stage(apply_plan, repo, staging)
        self.assertTrue(batch.root == staging and batch.plan == apply_plan, "staged batch")
        self.assertTrue(git_status(repo) == "", f"stage must not touch the worktree:\n{git_status(repo)}")
        self.assertTrue({path: sha256(repo / path) for path in before} == before, "target files unchanged in the worktree")
        self.assertTrue(parse(staging / skill).values["description"] == "Console test description.", "the staged SKILL.md carries the new description")
        self.assertTrue(tomllib.loads((staging / package_toml).read_text())["agent_plugins"]["design"]["default_loaded"])
        self.assertTrue(not (staging / ".git").exists(), "the staging copy must not carry .git")
        ok, detail = validate_staged(batch)
        self.assertTrue(ok, f"set_default_loaded must pass staged validation:\n{detail}")

    def test_dirty_target_refusal(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git, git_status, skill_row
        from skill_console.decisions import commit, plan, stage

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        skill = "agent-marketplace/packages/core/skills/code-gardening/SKILL.md"
        original = (repo / skill).read_bytes()
        rows = [skill_row(repo, "core", "code-gardening")]
        doc = decisions(describe("core:code-gardening", "Dirty target check."))

        batch = stage(plan(doc, rows, repo), repo, staging / "a")
        with (repo / "README.md").open("a") as handle:
            handle.write("\nunrelated local change\n")
        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.failure is None and report.applied == tuple(edit.relpath for edit in batch.plan.edits) and report.unapplied == (), f"unrelated dirt: {report}")
        self.assertTrue(b"Dirty target check." in (repo / skill).read_bytes(), "the edit landed")
        self.assertTrue(" M README.md" in git_status(repo), "the unrelated change is still there")
        git(repo, "checkout", "--", ".")
        self.assertTrue((repo / skill).read_bytes() == original and git_status(repo) == "", "reset for the next step")

        batch = stage(plan(doc, rows, repo), repo, staging / "b")
        dirty = original + b"\n<!-- local edit -->\n"
        (repo / skill).write_bytes(dirty)
        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.failure and "dirty" in report.failure and skill in report.failure, f"dirty target: {report.failure!r}")
        self.assertTrue(report.applied == () and report.unapplied == tuple(edit.relpath for edit in batch.plan.edits), f"nothing may be applied: {report}")
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
        self.assertTrue("x" * 1100 in (staging / "agent-marketplace/packages/core/skills/code-gardening/SKILL.md").read_text(), "the staging copy keeps the failing edit for inspection")

    def test_hash_precondition_at_commit_time(self):
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, describe, git, git_status, sha256, skill_row
        from skill_console.decisions import commit, plan, stage

        repo, staging = Path(str(self.repo)), Path(str(self.work / "staging"))
        first = "agent-marketplace/packages/core/skills/code-gardening/SKILL.md"
        second = "agent-marketplace/packages/core/skills/decomment/SKILL.md"
        rows = [skill_row(repo, "core", "code-gardening"), skill_row(repo, "core", "decomment")]
        doc = decisions(describe("core:code-gardening", "First edit."), describe("core:decomment", "Second edit."))
        apply_plan = plan(doc, rows, repo)
        self.assertTrue([edit.relpath for edit in apply_plan.edits][:2] == [first, second], f"edit order {[e.relpath for e in apply_plan.edits]}")
        batch = stage(apply_plan, repo, staging)

        # Someone else changes the second target after planning and commits it, so the
        # path is clean in git but its hash no longer matches the plan.
        mutated = (repo / second).read_bytes() + b"\n<!-- edited after planning -->\n"
        (repo / second).write_bytes(mutated)
        git(repo, "commit", "-q", "-am", "concurrent edit")
        self.assertTrue(git_status(repo) == "", "the mutation is committed, so the dirty gate does not fire")

        report = commit(batch, repo, allow_dirty=False)
        self.assertTrue(report.applied == (first,), f"applied {report.applied}")
        self.assertTrue(report.unapplied == tuple(edit.relpath for edit in apply_plan.edits[1:]), f"unapplied {report.unapplied}")
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
        skill = "agent-marketplace/packages/core/skills/code-gardening/SKILL.md"
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

    def test_delete_skill_plans_selection_native_lock_and_version_without_editing_cache(self):
        self.add_synthetic_vendor()
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import plan
        from artifact import tree_files
        repo, skill = self.repo, self.synth_skill
        package = "agent-marketplace/packages/synth"
        manifest, lock = "agent-marketplace/apm.yml", "agent-marketplace/apm.lock.yaml"
        selection = f"{package}/publish.toml"
        overlay = f"{package}/overlays/skills/{skill}"
        codex = f"{package}/.codex-plugin/plugin.json"
        target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(repo / package / "skills" / skill))
        before = tree_files(repo / "agent-marketplace/apm_modules")
        def delete(remove):
            return decisions(op(Op.DELETE_SKILL, f"synth:{skill}", apm_dep=f"example/repo/skills/{skill}", dep_owns_skills=1, remove_apm_dep=remove))
        edits = {edit.relpath: edit for edit in plan(delete(True), [target], repo).edits}
        self.assertEqual(set(edits), {selection, overlay, manifest, lock, codex})
        self.assertEqual(edits[overlay].kind, "delete-tree")
        self.assertNotIn(skill, edits[selection].content)
        self.assertIn('name = "twin-a"', edits[selection].content)
        self.assertNotIn(skill, edits[manifest].content)
        self.assertIn("example/repo/skills/twins", edits[manifest].content)
        self.assertNotIn(skill, edits[lock].content)
        self.assertIn("virtual_path: skills/twins", edits[lock].content)
        self.assertIn("deployments: []", edits[lock].content)
        self.assertIn('"version": "1.0.1"', edits[codex].content)
        kept = {edit.relpath: edit for edit in plan(delete(False), [target], repo).edits}
        self.assertEqual(set(kept), {selection, overlay, codex})
        self.assertIn(f"example/repo/skills/{skill}", (repo / manifest).read_text())
        self.assertEqual(tree_files(repo / "agent-marketplace/apm_modules"), before)
        self.assertEqual(git_status(repo), "")

    def test_a_failed_tree_removal_leaves_the_skill_at_its_own_path(self):
        self.add_synthetic_vendor()
        import os
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import commit, plan, stage

        repo, skill, staging = Path(str(self.repo)), str(self.synth_skill), Path(str(self.work / "staging"))
        skill_rel = f"agent-marketplace/packages/synth/overlays/skills/{skill}"
        skill_dir = repo / skill_rel
        target = row(f"synth:{skill}", "synth", skill, Origin.REPO_VENDOR, str(repo / "agent-marketplace/packages/synth/skills" / skill))
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
        if (skill_dir / "extra.md").is_file():
            self.assertTrue(report.applied == () and "git restore" not in report.failure, f"an intact tree is not reported as applied: {report}")
        else:
            self.assertTrue(report.applied == (skill_rel,) and "git restore" in report.failure, f"a partly removed tree is reported for recovery: {report}")
        git(repo, "restore", "--", skill_rel)
        self.assertTrue(git_status(repo) == "" and (skill_dir / "extra.md").is_file(), f"git restore rebuilds the local additions:\n{git_status(repo)}")

    def test_delete_skill_preconditions_are_re_checked_at_commit(self):
        self.add_synthetic_vendor()
        from pathlib import Path
        from tests.python.agents.console_documents import decisions, git, git_status, op, row
        from skill_console import Op, Origin
        from skill_console.decisions import commit, plan, stage

        repo, skill, staging = Path(str(self.repo)), str(self.synth_skill), Path(str(self.work / "staging"))
        package = "agent-marketplace/packages/synth"
        skill_rel = f"{package}/skills/{skill}"
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
            self.assertTrue(report.applied == () and skill in (repo / package / "publish.toml").read_text(), f"nothing may move: {report}")
            git(repo, "reset", "-q", "--hard", "synth")
            return report.failure or ""


        failure = commit_after(staged("reference"), "tests/uses-synth.zsh", f"source {skill_rel}/scripts/tool.py\n")
        self.assertTrue("tests/uses-synth.zsh" in failure and "re-plan" in failure, f"a new tracked reference must refuse the commit: {failure!r}")
        for sibling in (f"{package}/publish.toml", "agent-marketplace/packages/core/publish.toml"):
            with self.subTest(sibling=sibling):
                text = (repo / sibling).read_text() + f'\n[[skills]]\nname = "new-sibling"\ndependency = "example/repo/skills/{skill.upper()}"\npath = "."\n'
                failure = commit_after(staged(sibling), sibling, text)
                self.assertIn("owns 2", failure)
                self.assertIn("re-plan", failure)
        payload = "agent-marketplace/packages/core/publish.toml"
        text = (repo / payload).read_text() + f'\n[[payloads]]\ndependency = "example/repo/skills/{skill.upper()}"\npath = "scripts"\ntarget = "shared-tools"\n'
        failure = commit_after(staged("payload"), payload, text)
        self.assertIn("supporting payload", failure)
        self.assertIn("re-plan", failure)
        from skill_console.decisions import ApplyError
        (repo / payload).write_text(text)
        with self.assertRaisesRegex(ApplyError, "supporting payload"):
            plan(doc, [target], repo)
        git(repo, "restore", "--", payload)
        report = commit(staged("clean"), repo, allow_dirty=False)
        self.assertTrue(report.failure is None and f"{package}/publish.toml" in report.applied and "agent-marketplace/apm.lock.yaml" in report.applied, f"an unchanged tree commits: {report}")
        git(repo, "reset", "-q", "--hard", "synth")
        self.assertTrue(git_status(repo) == "", "clean again")
