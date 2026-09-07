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
        row("pkg:local", "pkg", "local", Origin.REPO_LOCAL, f"{pkgtree}/local"),
        row("pkg:vend-a", "pkg", "vend-a", Origin.REPO_VENDOR, f"{pkgtree}/vend-a"),
        row("pkg:vend-b", "pkg", "vend-b", Origin.REPO_VENDOR, f"{pkgtree}/vend-b"),
        row("pkg:solo", "pkg", "solo", Origin.REPO_VENDOR, f"{pkgtree}/solo"),
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

import hashlib
import subprocess
from pathlib import Path

from skill_console import Op, Origin
from skill_console.frontmatter import parse


def git_status(repo):
    return subprocess.run(["git", "-C", str(repo), "status", "--porcelain"], capture_output=True, text=True, check=True, timeout=30).stdout


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.invalid", *args], check=True, capture_output=True, timeout=30)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def skill_row(repo, package, directory):
    skill_dir = Path(repo) / "agent-marketplace/packages" / package / "skills" / directory
    description = parse(skill_dir / "SKILL.md").values["description"]
    return row(f"{package}:{directory}", package, directory, Origin.REPO_LOCAL, str(skill_dir), description=description)


def describe(name, text):
    return op(Op.SET_DESCRIPTION, name, from_chars=0, to_chars=len(text), text=text)
