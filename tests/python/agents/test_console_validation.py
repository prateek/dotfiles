from tests.python.agents.console_support import ConsoleCase


class ConsoleValidationTests(ConsoleCase):
    def setUp(self):
        super().setUp()
        self.pkgtree = self.fixtures / "pkgtree/pkg/skills"
        for name in ("local/local", "vendor/vend-a", "vendor/vend-b", "vendor/solo"):
            path = self.pkgtree / name
            path.mkdir(parents=True)
            (path / "SKILL.md").write_text(f"---\nname: {path.name}\ndescription: Local skill.\n---\n\n# Skill\n")
            if name.startswith("vendor/"):
                dependency = "solo" if path.name == "solo" else "shared"
                (path / "SOURCE.md").write_text(f"# Source\n\n- APM dependency: `example/repo/skills/{dependency}`\n- Ref: `abc`\n")

    def test_structural_validation_v1_through_v9(self):
        import copy
        import json
        from tests.python.agents.console_documents import decisions, op
        from skill_console import Op
        from skill_console.decisions import dump, load, validate_document

        base = json.loads(dump(decisions(op(Op.SET_FRONTMATTER, "pkg:local", field="user-invocable", value=True))))
        self.assertTrue(validate_document(base) == [], f"the base document must validate: {validate_document(base)}")


        def mutated(apply):
            doc = copy.deepcopy(base)
            apply(doc)
            return doc


        def budget_op(to_value):
            return {"op": "set_budget_fraction", "target": "settings", "key": "", "from_value": 0.04, "to_value": to_value}


        def plugin_op(key):
            return {"op": "set_package_enabled", "target": "package", "key": key, "value": False}


        self.assertTrue(validate_document(mutated(lambda d: d["operations"].append(plugin_op("design@prateek-local")))) == [], "a well-formed plugin key is structurally valid")
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
            self.assertTrue(codes == {code}, f"{label}: codes {sorted(codes)}, expected only {code}: {[v.message for v in violations]}")
            self.assertTrue(any(v.pointer == pointer for v in violations), f"{label}: pointers {[v.pointer for v in violations]} lack {pointer}")
            self.assertTrue(all(v.pointer and v.message for v in violations), f"{label}: empty pointer or message")
        self.assertTrue(validate_document([]) and validate_document([])[0].code == "V3", "a non-object document is V3")

    def test_live_validation_v10_through_v19(self):
        from tests.python.agents.console_documents import LOCAL_CHARS, NOW_MS, decisions, op, predicted, rows_for, snapshot
        from skill_console import MS_PER_DAY, Op
        from skill_console.decisions import validate_against_live
        from skill_console.inventory import REPO_MARKETPLACE

        rows = rows_for(str(self.pkgtree))
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
        self.assertTrue(run(valid) == [], f"a consistent document must pass: {run(valid)}")

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
            self.assertTrue(matching, f"{label}: expected {code}, got {[(v.code, v.pointer) for v in violations]}")
            self.assertTrue(any(v.pointer == pointer for v in matching), f"{label}: {code} pointers {[v.pointer for v in matching]} lack {pointer}")
            self.assertTrue(all(v.pointer and v.message for v in violations), f"{label}: empty pointer or message")
