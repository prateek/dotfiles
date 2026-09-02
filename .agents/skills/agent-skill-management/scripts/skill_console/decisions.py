"""Decisions documents: schema, validation, planning, staging, and commit.

This is the only console module that writes to the repository, so the apply
procedure is deliberately staged: plan every edit against the working tree,
copy the tree, apply the edits in the copy, validate the copy, and only then
move each path into place behind a per-path hash check. The batch as a whole
is not atomic; git is the recovery mechanism, which is safe because commit
refuses to touch a target path that is dirty.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import types
import typing
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, fields
from pathlib import Path

import tomllib

from skill_console import (
    BINARY_VERSION,
    MS_PER_DAY,
    SCHEMA_VERSION,
    Decisions,
    Harness,
    Op,
    Operation,
    Origin,
    Predicted,
    Row,
    SkillRecord,
    Snapshot,
    Violation,
    capability_allows,
    frontmatter,
)
from skill_console.budget import listing_text, utf16_length, write_safe
from skill_console.inventory import REPO_MARKETPLACE

PACKAGES_DIR = "home/dot_agents/packages"
SETTINGS_TEMPLATE = "home/.chezmoitemplates/claude-settings-managed.json.tmpl"
SCRIPTS_DIR = ".agents/skills/agent-skill-management/scripts"
VALIDATE_SCRIPT = f"{SCRIPTS_DIR}/validate-agent-packages"
VENDOR_SCRIPT = f"{SCRIPTS_DIR}/vendor-agent-package"
RENDER_SCRIPT = f"{SCRIPTS_DIR}/render-agent-plugin-marketplace"
# Committed files the renderer derives from package.toml; a default_loaded
# change is incomplete until they are regenerated.
GENERATED_TEMPLATES = (
    "home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl",
    "home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl",
    "home/dot_pi/agent/claude-plugins.json.tmpl",
)
STAGED_MAKE_TARGETS = (
    "test-agent-skill-packages",
    "test-claude-settings",
    "test-codex-config",
    "test-pi-settings",
)
STAGED_STEP_TIMEOUT_S = 600
FRONTMATTER_FIELDS = frozenset({"disable-model-invocation", "user-invocable"})
BUDGET_FRACTION_KEY = "skillListingBudgetFraction"
ENABLED_PLUGINS_KEY = "enabledPlugins"

# Tracked references to a skill under these roots block its deletion; under
# docs/ they only warn, because prose goes stale without breaking anything.
REFERENCE_REFUSE_ROOTS = ("tests", ".agents", "home")
REFERENCE_WARN_ROOTS = ("docs",)

_TOP_LEVEL_KEYS = ("schema_version", "harness", "snapshot", "predicted", "operations")
_OP_KEYS = ("op", "target", "key")
_SKILL, _PACKAGE, _SETTINGS = "skill", "package", "settings"
_OP_SCHEMA: Mapping[Op, tuple[str, Mapping[str, type]]] = {
    Op.SET_DESCRIPTION: (_SKILL, {"from_chars": int, "to_chars": int, "text": str}),
    Op.SET_FRONTMATTER: (_SKILL, {"field": str, "value": bool}),
    Op.DELETE_SKILL: (
        _SKILL,
        {"apm_dep": str, "dep_owns_skills": int, "remove_apm_dep": bool},
    ),
    Op.SET_DEFAULT_LOADED: (_PACKAGE, {"value": bool}),
    Op.SET_PACKAGE_ENABLED: (_PACKAGE, {"value": bool}),
    Op.SET_BUDGET_FRACTION: (_SETTINGS, {"from_value": float, "to_value": float}),
}
_SNAPSHOT_HINTS = typing.get_type_hints(Snapshot)
_PREDICTED_HINTS = typing.get_type_hints(Predicted)
# The document carries schema_version and harness once, at the top level.
_SNAPSHOT_TOP_LEVEL = ("schema_version", "harness")
_SNAPSHOT_FIELDS = tuple(
    field.name for field in fields(Snapshot) if field.name not in _SNAPSHOT_TOP_LEVEL
)
_PREDICTED_FIELDS = tuple(field.name for field in fields(Predicted))
_HASH_FIELDS = (
    "binary_hash",
    "source_hash",
    "marketplace_hash",
    "cache_hash",
    "settings_hash",
    "usage_hash",
)
_INPUT_FIELDS = (
    "binary_version",
    "model",
    "context_window",
    "bytes_per_token",
    "fraction",
    "max_desc_chars",
    "budget_chars",
    "budget_env_override",
)

_APM_DEPENDENCY_LINE = re.compile(r"^- APM dependency: `([^`]+)`\s*$", re.MULTILINE)
# A plugin key lands verbatim in a Go-template file that chezmoi renders, so
# both segments are limited to characters that cannot open a template action.
_PLUGIN_KEY = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9._-]*")
_REPO_ORIGINS = (Origin.REPO_LOCAL, Origin.REPO_VENDOR)
_TOML_TABLE_HEADER = re.compile(r"^\s*\[")
_ERE_METACHARS = re.compile(r"([.^$*+?()\[\]{}|\\])")
_OUTPUT_TAIL_LINES = 30


class ApplyError(Exception):
    """A decisions document cannot be loaded, planned, staged, or committed."""


class _PartialDeletion(ApplyError):
    """A tree removal stopped partway; the path needs `git restore` like an applied edit."""


@dataclass(frozen=True, slots=True)
class PathEdit:
    relpath: str
    kind: str
    before_sha256: str | None
    after_sha256: str | None
    content: str | None


@dataclass(frozen=True, slots=True)
class DeletionGuard:
    """delete_skill preconditions whose inputs are not the edited paths.

    Per-path hashes cannot see a new tracked reference or a new sibling naming
    the same APM dependency, so commit re-runs these before moving anything.
    """

    name: str
    directory: str
    package: str
    skill_relpath: str
    dependency: str
    excluded: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class ApplyPlan:
    edits: tuple[PathEdit, ...]
    warnings: tuple[str, ...]
    guards: tuple[DeletionGuard, ...] = ()


@dataclass(frozen=True, slots=True)
class StagedBatch:
    root: Path
    plan: ApplyPlan


@dataclass(frozen=True, slots=True)
class CommitReport:
    applied: tuple[str, ...]
    unapplied: tuple[str, ...]
    failure: str | None


# --- document -----------------------------------------------------------------


def _type_ok(value: object, hint: object) -> bool:
    if hint is bool:
        return isinstance(value, bool)
    if hint is int:
        return isinstance(value, int) and not isinstance(value, bool)
    if hint is float:
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if hint is str:
        return isinstance(value, str)
    if hint is type(None):
        return value is None
    if hint is Harness:
        return isinstance(value, str) and value in {member.value for member in Harness}
    origin = typing.get_origin(hint)
    if origin is types.UnionType or origin is typing.Union:
        return any(_type_ok(value, arg) for arg in typing.get_args(hint))
    if origin is tuple:
        item_hint = typing.get_args(hint)[0]
        return isinstance(value, list) and all(_type_ok(item, item_hint) for item in value)
    return False


def _hint_name(hint: object) -> str:
    return getattr(hint, "__name__", str(hint))


def _check_section(
    doc: Mapping[str, object],
    name: str,
    declared: Sequence[str],
    hints: Mapping[str, object],
    violations: list[Violation],
) -> None:
    section = doc.get(name)
    if not isinstance(section, Mapping):
        violations.append(Violation("V4", f"{name} must be a JSON object", f"/{name}"))
        return
    for key in section:
        if key not in declared and not (name == "snapshot" and key in _SNAPSHOT_TOP_LEVEL):
            violations.append(Violation("V4", f"unknown {name} field {key!r}", f"/{name}/{key}"))
    for key in declared:
        if key not in section:
            violations.append(Violation("V4", f"{name} is missing {key!r}", f"/{name}/{key}"))
        elif not _type_ok(section[key], hints[key]):
            violations.append(
                Violation(
                    "V4",
                    f"{name}.{key} must be {_hint_name(hints[key])}, got {type(section[key]).__name__}",
                    f"/{name}/{key}",
                )
            )
    if name == "snapshot":
        for key in _SNAPSHOT_TOP_LEVEL:
            if key in section and section[key] != doc.get(key):
                violations.append(
                    Violation("V4", f"snapshot.{key} disagrees with the top-level {key}", f"/snapshot/{key}")
                )


def _check_operation(index: int, op: object, seen: dict[tuple[str, str], int], violations: list[Violation]) -> None:
    pointer = f"/operations/{index}"
    if not isinstance(op, Mapping):
        violations.append(Violation("V5", "operation must be a JSON object", pointer))
        return
    op_name = op.get("op")
    if not isinstance(op_name, str) or op_name not in {member.value for member in Op}:
        violations.append(Violation("V5", f"unknown op {op_name!r}", f"{pointer}/op"))
        return
    target, required = _OP_SCHEMA[Op(op_name)]
    if op.get("target") != target:
        violations.append(
            Violation("V5", f"{op_name} targets {target!r}, got {op.get('target')!r}", f"{pointer}/target")
        )
    key = op.get("key")
    if not isinstance(key, str):
        violations.append(Violation("V6", "key must be a string", f"{pointer}/key"))
    elif target == _SETTINGS and key != "":
        violations.append(Violation("V6", f"{op_name} key must be \"\"", f"{pointer}/key"))
    elif target != _SETTINGS and key == "":
        violations.append(Violation("V6", f"{op_name} key must name a {target}", f"{pointer}/key"))
    elif op_name == Op.SET_PACKAGE_ENABLED and not _PLUGIN_KEY.fullmatch(key):
        violations.append(
            Violation("V6", f"set_package_enabled key must be <pkg>@<marketplace> over [A-Za-z0-9._-], got {key!r}", f"{pointer}/key")
        )
    for field in op:
        if field not in _OP_KEYS and field not in required:
            violations.append(Violation("V6", f"{op_name} does not take {field!r}", f"{pointer}/{field}"))
    for field, hint in required.items():
        if field not in op:
            violations.append(Violation("V6", f"{op_name} requires {field!r}", f"{pointer}/{field}"))
        elif not _type_ok(op[field], hint):
            violations.append(
                Violation(
                    "V6",
                    f"{op_name}.{field} must be {_hint_name(hint)}, got {type(op[field]).__name__}",
                    f"{pointer}/{field}",
                )
            )
    if isinstance(key, str):
        earlier = seen.setdefault((op_name, key), index)
        if earlier != index:
            violations.append(
                Violation("V7", f"duplicate {op_name} on {key!r} (first at /operations/{earlier})", pointer)
            )
    if op_name == Op.SET_FRONTMATTER and isinstance(op.get("field"), str) and op["field"] not in FRONTMATTER_FIELDS:
        violations.append(
            Violation("V8", f"set_frontmatter.field must be one of {sorted(FRONTMATTER_FIELDS)}", f"{pointer}/field")
        )
    if op_name == Op.SET_BUDGET_FRACTION and _type_ok(op.get("to_value"), float) and not 0.0 < op["to_value"] <= 1.0:
        violations.append(Violation("V9", "set_budget_fraction.to_value must be in (0.0, 1.0]", f"{pointer}/to_value"))


def validate_document(doc: Mapping[str, object]) -> list[Violation]:
    """Structural checks V1-V9. An empty list is success."""
    if not isinstance(doc, Mapping):
        return [Violation("V3", "decisions document must be a JSON object", "/")]
    violations: list[Violation] = []
    schema_version = doc.get("schema_version")
    if not _type_ok(schema_version, int) or schema_version != SCHEMA_VERSION:
        violations.append(Violation("V1", f"schema_version must be {SCHEMA_VERSION}, got {schema_version!r}", "/schema_version"))
    if doc.get("harness") != Harness.CLAUDE.value:
        violations.append(Violation("V2", f"harness must be {Harness.CLAUDE.value!r}, got {doc.get('harness')!r}", "/harness"))
    for key in doc:
        if key not in _TOP_LEVEL_KEYS:
            violations.append(Violation("V3", f"unknown top-level key {key!r}", f"/{key}"))
    _check_section(doc, "snapshot", _SNAPSHOT_FIELDS, _SNAPSHOT_HINTS, violations)
    _check_section(doc, "predicted", _PREDICTED_FIELDS, _PREDICTED_HINTS, violations)
    operations = doc.get("operations")
    if not isinstance(operations, list):
        violations.append(Violation("V3", "operations must be a JSON array", "/operations"))
        return violations
    seen: dict[tuple[str, str], int] = {}
    for index, op in enumerate(operations):
        _check_operation(index, op, seen, violations)
    return violations


def _coerce(value: object, hint: object) -> object:
    if hint is float and isinstance(value, int):
        return float(value)
    if typing.get_origin(hint) is tuple and isinstance(value, list):
        return tuple(value)
    if typing.get_origin(hint) in (types.UnionType, typing.Union) and value is not None:
        for arg in typing.get_args(hint):
            if arg is not type(None) and _type_ok(value, arg):
                return _coerce(value, arg)
    return value


def _from_document(doc: Mapping[str, object]) -> Decisions:
    snapshot_doc = typing.cast(Mapping[str, object], doc["snapshot"])
    predicted_doc = typing.cast(Mapping[str, object], doc["predicted"])
    snapshot = Snapshot(
        schema_version=typing.cast(int, doc["schema_version"]),
        harness=Harness(typing.cast(str, doc["harness"])),
        **{name: _coerce(snapshot_doc[name], _SNAPSHOT_HINTS[name]) for name in _SNAPSHOT_FIELDS},  # type: ignore[arg-type]
    )
    predicted = Predicted(
        **{name: _coerce(predicted_doc[name], _PREDICTED_HINTS[name]) for name in _PREDICTED_FIELDS}  # type: ignore[arg-type]
    )
    operations = []
    for raw in typing.cast(list[Mapping[str, object]], doc["operations"]):
        op = Op(typing.cast(str, raw["op"]))
        required = _OP_SCHEMA[op][1]
        operations.append(
            Operation(
                op=op,
                target=typing.cast(str, raw["target"]),
                key=typing.cast(str, raw["key"]),
                fields={name: _coerce(raw[name], required[name]) for name in required},
            )
        )
    return Decisions(
        schema_version=snapshot.schema_version,
        harness=snapshot.harness,
        snapshot=snapshot,
        predicted=predicted,
        operations=tuple(operations),
    )


def load(path: Path) -> Decisions:
    """Read and structurally validate a decisions document."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ApplyError(f"cannot read {path}: {exc.strerror or exc}") from exc
    try:
        raw = json.loads(text)
    except ValueError as exc:
        raise ApplyError(f"{path}: invalid JSON: {exc}") from exc
    violations = validate_document(raw)
    if violations:
        shown = "; ".join(f"{v.code} {v.pointer}: {v.message}" for v in violations[:5])
        more = f" (+{len(violations) - 5} more)" if len(violations) > 5 else ""
        raise ApplyError(f"{path}: {shown}{more}")
    return _from_document(raw)


def _plain(value: object) -> object:
    if isinstance(value, tuple):
        return list(value)
    if isinstance(value, (Harness, Op)):
        return value.value
    return value


def dump(decisions: Decisions) -> str:
    """Serialize to the document shape `load` reads; `load(dump(d)) == d`."""
    doc = {
        "schema_version": decisions.schema_version,
        "harness": decisions.harness.value,
        "snapshot": {name: _plain(getattr(decisions.snapshot, name)) for name in _SNAPSHOT_FIELDS},
        "predicted": {name: _plain(getattr(decisions.predicted, name)) for name in _PREDICTED_FIELDS},
        "operations": [
            {"op": op.op.value, "target": op.target, "key": op.key, **{k: _plain(v) for k, v in op.fields.items()}}
            for op in decisions.operations
        ],
    }
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


# --- live validation ------------------------------------------------------------


def _skill_dir(record: SkillRecord) -> Path:
    return record.path.parent if record.path.name == "SKILL.md" else record.path


def _source_record(row: Row) -> SkillRecord | None:
    return row.source_record or row.marketplace_record or row.cache_record


def _dep_key(dependency: str) -> str:
    """The APM dependency identity, ignoring case and a `#ref` pin."""
    return dependency.strip().strip("`").split("#", 1)[0].strip("/").lower()


def _apm_dependency_of(skill_dir: Path) -> str | None:
    source_md = skill_dir / "SOURCE.md"
    if not source_md.is_file():
        return None
    match = _APM_DEPENDENCY_LINE.search(source_md.read_text(encoding="utf-8", errors="replace"))
    return match.group(1).strip() if match else None


def _dependency_skill_count(skill_dir: Path, dependency: str) -> int:
    wanted = _dep_key(dependency)
    return sum(
        1
        for sibling in skill_dir.parent.iterdir()
        if sibling.is_dir() and (dep := _apm_dependency_of(sibling)) is not None and _dep_key(dep) == wanted
    )


def _package_of(key: str) -> str:
    return key.split("@", 1)[0]


def _validate_skill_operation(
    index: int,
    op: Operation,
    row: Row,
    disabled_packages: set[str],
    deleted: set[str],
    violations: list[Violation],
) -> None:
    pointer = f"/operations/{index}"
    if not capability_allows(row.origin, op.op):
        violations.append(Violation("V14", f"{op.op.value} is not permitted for {row.origin.value} rows ({op.key})", pointer))
        return
    if op.op in (Op.SET_DESCRIPTION, Op.SET_FRONTMATTER):
        if row.package in disabled_packages:
            violations.append(
                Violation("V15", f"{op.op.value} on {op.key} conflicts with disabling its package {row.package}", pointer)
            )
        if op.key in deleted:
            violations.append(Violation("V15", f"{op.op.value} on {op.key} conflicts with deleting it", pointer))
    if op.op is Op.SET_DESCRIPTION:
        record = _source_record(row)
        if record is None:
            violations.append(Violation("V16", f"{op.key} has no skill record to compare against", pointer))
            return
        live_chars = utf16_length(listing_text(record.description, record.when_to_use))
        if op.fields["from_chars"] != live_chars:
            violations.append(
                Violation("V16", f"from_chars {op.fields['from_chars']} != live listing text length {live_chars}", f"{pointer}/from_chars")
            )
        text = str(op.fields["text"])
        if op.fields["to_chars"] != utf16_length(text):
            violations.append(
                Violation("V16", f"to_chars {op.fields['to_chars']} != utf16_length(text) {utf16_length(text)}", f"{pointer}/to_chars")
            )
        ok, reason = write_safe(text)
        if not ok:
            violations.append(Violation("V16", f"text is not write-safe: {reason}", f"{pointer}/text"))
    if op.op is Op.DELETE_SKILL:
        if row.source_record is None:
            violations.append(Violation("V13", f"{op.key} is listed but has no source-tree record", f"{pointer}/key"))
            return
        skill_dir = _skill_dir(row.source_record)
        own_dependency = _apm_dependency_of(skill_dir)
        if own_dependency is None:
            violations.append(Violation("V17", f"{skill_dir / 'SOURCE.md'} names no APM dependency", f"{pointer}/apm_dep"))
            return
        if _dep_key(str(op.fields["apm_dep"])) != _dep_key(own_dependency):
            violations.append(
                Violation("V17", f"apm_dep {op.fields['apm_dep']!r} != SOURCE.md dependency {own_dependency!r}", f"{pointer}/apm_dep")
            )
            return
        count = _dependency_skill_count(skill_dir, own_dependency)
        if op.fields["dep_owns_skills"] != count:
            violations.append(
                Violation("V17", f"dep_owns_skills {op.fields['dep_owns_skills']} != recomputed {count}", f"{pointer}/dep_owns_skills")
            )
        if op.fields["remove_apm_dep"] and count != 1:
            violations.append(
                Violation("V17", f"remove_apm_dep requires a dependency owning one skill; {own_dependency} owns {count}", f"{pointer}/remove_apm_dep")
            )
        if count > 1:
            violations.append(
                Violation(
                    "V14",
                    f"delete_skill is permitted only when the APM dependency owns that one skill; {own_dependency} owns {count}",
                    pointer,
                )
            )


def _validate_package_operation(
    index: int, op: Operation, rows_by_package: Mapping[str, Sequence[Row]], violations: list[Violation]
) -> None:
    pointer = f"/operations/{index}"
    package = _package_of(op.key)
    if op.op is Op.SET_PACKAGE_ENABLED and not _PLUGIN_KEY.fullmatch(op.key):
        violations.append(Violation("V13", f"set_package_enabled key must be <pkg>@<marketplace> over [A-Za-z0-9._-], got {op.key!r}", f"{pointer}/key"))
        return
    if op.op is Op.SET_DEFAULT_LOADED and "@" in op.key:
        violations.append(Violation("V13", f"set_default_loaded key must be a bare package name, got {op.key!r}", f"{pointer}/key"))
        return
    package_rows = rows_by_package.get(package)
    if not package_rows:
        violations.append(Violation("V13", f"unknown package {package!r}", f"{pointer}/key"))
        return
    if op.op is Op.SET_PACKAGE_ENABLED and any(row.origin in _REPO_ORIGINS for row in package_rows):
        marketplace = op.key.split("@", 1)[1]
        if marketplace != REPO_MARKETPLACE:
            violations.append(
                Violation("V13", f"repo package {package} is installed from {REPO_MARKETPLACE!r}, not {marketplace!r}", f"{pointer}/key")
            )
            return
    for origin in sorted({row.origin for row in package_rows}, key=str):
        if not capability_allows(origin, op.op):
            violations.append(Violation("V14", f"{op.op.value} is not permitted for {origin.value} package {package}", pointer))


def validate_against_live(
    decisions: Decisions, snapshot: Snapshot, rows: Sequence[Row], predicted: Predicted
) -> list[Violation]:
    """Checks V10-V19 against freshly rebuilt inventory and a recomputed witness."""
    violations: list[Violation] = []
    recorded = decisions.snapshot
    for name in _HASH_FIELDS:
        if getattr(recorded, name) != getattr(snapshot, name):
            note = "; the constants may be stale, re-render" if name == "binary_hash" else ""
            violations.append(Violation("V10", f"{name} changed since render{note}", f"/snapshot/{name}"))
    if not (recorded.binary_hash_matched and snapshot.binary_hash_matched):
        violations.append(
            Violation(
                "V10",
                f"the claude binary is not the {BINARY_VERSION} build the constants were read from; refusing to apply a simulation that may be wrong",
                "/snapshot/binary_hash_matched",
            )
        )
    for name in _INPUT_FIELDS:
        if getattr(recorded, name) != getattr(snapshot, name):
            violations.append(
                Violation("V10", f"{name} changed since render: recorded {getattr(recorded, name)!r}, live {getattr(snapshot, name)!r}", f"/snapshot/{name}")
            )
    age_ms = int(time.time() * 1000) - recorded.now_ms
    if abs(age_ms) > MS_PER_DAY:
        violations.append(
            Violation("V11", f"snapshot is {age_ms / MS_PER_DAY:.1f} days from the wall clock; re-render or pass --allow-stale", "/snapshot/now_ms")
        )
    for name in ("cwd", "project_root"):
        if getattr(recorded, name) != getattr(snapshot, name):
            violations.append(
                Violation("V12", f"{name} {getattr(recorded, name)!r} does not match the current {getattr(snapshot, name)!r}", f"/snapshot/{name}")
            )

    rows_by_name = {row.name: row for row in rows}
    rows_by_package: dict[str, list[Row]] = {}
    for row in rows:
        if row.package:
            rows_by_package.setdefault(row.package, []).append(row)
    disabled_packages = {
        _package_of(op.key)
        for op in decisions.operations
        if op.op in (Op.SET_DEFAULT_LOADED, Op.SET_PACKAGE_ENABLED) and op.fields["value"] is False
    }
    deleted = {op.key for op in decisions.operations if op.op is Op.DELETE_SKILL}

    for index, op in enumerate(decisions.operations):
        pointer = f"/operations/{index}"
        if op.target == _SKILL:
            row = rows_by_name.get(op.key)
            if row is None:
                violations.append(Violation("V13", f"unknown skill {op.key!r}", f"{pointer}/key"))
                continue
            _validate_skill_operation(index, op, row, disabled_packages, deleted, violations)
        elif op.target == _PACKAGE:
            _validate_package_operation(index, op, rows_by_package, violations)
        elif op.op is Op.SET_BUDGET_FRACTION and op.fields["from_value"] != snapshot.fraction:
            violations.append(
                Violation("V18", f"from_value {op.fields['from_value']} != live fraction {snapshot.fraction}", f"{pointer}/from_value")
            )

    for name in _PREDICTED_FIELDS:
        if getattr(decisions.predicted, name) != getattr(predicted, name):
            violations.append(
                Violation("V19", f"predicted.{name} {getattr(decisions.predicted, name)!r} != recomputed {getattr(predicted, name)!r}", f"/predicted/{name}")
            )
    return violations


# --- planning -------------------------------------------------------------------


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _file_sha256(path: Path) -> str | None:
    return _sha256(path.read_bytes()) if path.is_file() else None


def _tree_sha256(root: Path) -> str:
    """Content hash of a directory: files and symlinks, sorted by relative path."""
    digest = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_symlink() or p.is_file()):
        payload = f"symlink:{os.readlink(path)}" if path.is_symlink() else _sha256(path.read_bytes())
        digest.update(f"{path.relative_to(root).as_posix()}\0{payload}\n".encode())
    return digest.hexdigest()


def _set_toml_bool(text: str, key: str, value: bool) -> str:
    """Replace or add a top-level `key = bool` line without disturbing the rest."""
    literal = "true" if value else "false"
    lines = text.splitlines(keepends=True)
    header = next((i for i, line in enumerate(lines) if _TOML_TABLE_HEADER.match(line)), len(lines))
    assignment = re.compile(rf"^\s*{re.escape(key)}\s*=")
    for i in range(header):
        if assignment.match(lines[i]):
            ending = "\r\n" if lines[i].endswith("\r\n") else "\n"
            lines[i] = f"{key} = {literal}{ending}"
            break
    else:
        last = next((i for i in range(header - 1, -1, -1) if lines[i].strip()), -1)
        if last >= 0 and not lines[last].endswith("\n"):
            lines[last] += "\n"
        lines.insert(last + 1, f"{key} = {literal}\n")
    result = "".join(lines)
    if tomllib.loads(result).get(key) is not value:
        raise ApplyError(f"could not set {key} = {literal} in package.toml")
    return result


def _set_setting(text: str, key: str, subkey: str | None, value: object) -> str:
    """Set `key` (or `key[subkey]`) in the managed settings fragment, kept as plain JSON."""
    # chezmoi renders the fragment as a Go template on every apply and inside
    # staged validation, so an action delimiter written here would execute.
    for token in (key, subkey, value):
        if isinstance(token, str) and ("{{" in token or "}}" in token):
            raise ApplyError(f"{SETTINGS_TEMPLATE} is a Go template; refusing to write {token!r} into it")
    try:
        data = json.loads(text)
    except ValueError as exc:
        raise ApplyError(f"{SETTINGS_TEMPLATE} is not plain JSON ({exc}); edit it by hand") from exc
    if not isinstance(data, dict):
        raise ApplyError(f"{SETTINGS_TEMPLATE} must hold a JSON object")
    if subkey is None:
        data[key] = value
    else:
        section = data.setdefault(key, {})
        if not isinstance(section, dict):
            raise ApplyError(f"{SETTINGS_TEMPLATE}: {key} must be a JSON object")
        section[subkey] = value
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def _remove_apm_manifest_dependency(text: str, dependency: str, relpath: str) -> str:
    """Drop one `- <dep>` item from apm.yml's `dependencies.apm` list."""
    wanted = _dep_key(dependency)
    lines = text.splitlines(keepends=True)
    in_dependencies = in_apm = False
    apm_line: int | None = None
    matched: int | None = None
    remaining = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "dependencies:":
            in_dependencies, in_apm = True, False
            continue
        if not in_dependencies:
            continue
        if stripped and not line.startswith(" "):
            break
        if stripped == "apm:":
            in_apm, apm_line = True, i
            continue
        if in_apm and stripped.startswith("- "):
            if _dep_key(stripped.removeprefix("- ")) == wanted and matched is None:
                matched = i
            else:
                remaining += 1
    if matched is None:
        raise ApplyError(f"{relpath} has no APM dependency {dependency!r}")
    del lines[matched]
    if remaining == 0 and apm_line is not None:
        lines[apm_line] = lines[apm_line].replace("apm:", "apm: []", 1)
    return "".join(lines)


def _yaml_items(lines: Sequence[str], start: int) -> list[tuple[int, int]]:
    """(first, end) line spans of the `- ` items under the top-level key at `start`."""
    items: list[tuple[int, int]] = []
    i = start + 1
    while i < len(lines):
        line = lines[i]
        if line.strip() and not line[0].isspace() and not line.startswith("- "):
            break
        if line.startswith("- "):
            j = i + 1
            while j < len(lines) and not lines[j].startswith("- ") and not (lines[j].strip() and not lines[j][0].isspace()):
                j += 1
            items.append((i, j))
            i = j
        else:
            i += 1
    return items


def _lock_scalar(raw: str) -> str | None:
    value = raw.strip()
    if value in ("", "~", "null"):
        return None
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def _lock_items(lines: Sequence[str], start: int, relpath: str) -> list[tuple[tuple[int, int], dict[str, object]]]:
    """Each `- ` item under the top-level key at `start`: its line span and fields.

    apm writes the lock in one fixed shape: two-space indents, one scalar or one
    list of scalars per key, and nested maps (deployed_file_hashes) the console
    never reads. A line scanner covers that without a YAML parser, which keeps
    the console free of third-party dependencies like every sibling script.
    """
    items: list[tuple[tuple[int, int], dict[str, object]]] = []
    for first, end in _yaml_items(lines, start):
        fields: dict[str, object] = {}
        open_key: str | None = None
        for number in range(first, end):
            line = lines[number].rstrip("\r\n")
            body = f"  {line[2:]}" if number == first else line
            if not body.strip() or body.lstrip().startswith("#"):
                continue
            indent = len(body) - len(body.lstrip(" "))
            content = body.strip()
            if indent == 2 and content.startswith("- ") and open_key is not None:
                if fields.get(open_key) is None:
                    fields[open_key] = []
                if not isinstance(fields[open_key], list):
                    raise ApplyError(f"{relpath}:{number + 1}: list item under a mapping key; layout not understood")
                fields[open_key].append(_lock_scalar(content[2:]))
                continue
            if indent == 2 and ":" in content:
                key, _, value = content.partition(":")
                if value and not value.startswith(" "):
                    raise ApplyError(f"{relpath}:{number + 1}: unquoted scalar with a colon; layout not understood")
                fields[key.strip()] = _lock_scalar(value)
                open_key = key.strip() if not value.strip() else None
                continue
            if indent >= 4 and open_key is not None and ":" in content:
                if fields.get(open_key) is None:
                    fields[open_key] = {}
                nested = fields[open_key]
                if not isinstance(nested, dict):
                    raise ApplyError(f"{relpath}:{number + 1}: mapping under a list key; layout not understood")
                key, _, value = content.partition(":")
                nested[key.strip()] = _lock_scalar(value)
                continue
            raise ApplyError(f"{relpath}:{number + 1}: unexpected line {line!r}; layout not understood")
        items.append(((first, end), fields))
    return items


def _lock_dependency_key(record: Mapping[str, object]) -> str:
    repo = str(record.get("materialization_repo_url") or record.get("repo_url") or "")
    virtual_path = str(record.get("virtual_path") or "").strip("/")
    return _dep_key(f"{repo}/{virtual_path}" if virtual_path else repo)


def _lock_section(lines: Sequence[str], key: str, relpath: str) -> list[tuple[tuple[int, int], Mapping[str, object]]]:
    """Each item of a top-level list section paired with its line span."""
    start = next((i for i, line in enumerate(lines) if line.startswith(f"{key}:")), None)
    return [] if start is None else _lock_items(lines, start, relpath)


def _remove_apm_lock_dependency(text: str, dependency: str, relpath: str) -> tuple[str, str | None]:
    """Drop the dependency's lock entry and the deployments it owned.

    Returns the new text and a warning when the lock had no entry to drop.
    """
    wanted = _dep_key(dependency)
    lines = text.splitlines(keepends=True)
    if not any(line.startswith("dependencies:") for line in lines):
        return text, f"{relpath} has no dependencies section; leaving it untouched"
    dependencies = _lock_section(lines, "dependencies", relpath)
    matched = [(span, record) for span, record in dependencies if _lock_dependency_key(record) == wanted]
    if not matched:
        return text, f"{relpath} has no entry for {dependency!r}; run `{VENDOR_SCRIPT}` to regenerate it"
    span, record = matched[0]
    deployed = {str(path) for path in record.get("deployed_files") or ()}
    deployments = _lock_section(lines, "deployments", relpath)
    doomed = [span]
    for dep_span, entry in deployments:
        if str(entry.get("value")) in deployed or _dep_key(str(entry.get("active_owner") or "")) == wanted:
            doomed.append(dep_span)
    for first, end in sorted(doomed, reverse=True):
        del lines[first:end]
    for key in ("dependencies", "deployments"):
        index = next((i for i, line in enumerate(lines) if line.startswith(f"{key}:")), None)
        if index is not None and not _yaml_items(lines, index):
            lines[index] = f"{key}: []\n"
    result = "".join(lines)
    expected = (len(dependencies) - 1, len(deployments) - (len(doomed) - 1))
    remaining = tuple(len(_lock_section(result.splitlines(keepends=True), key, relpath)) for key in ("dependencies", "deployments"))
    if remaining != expected:
        raise ApplyError(f"{relpath} would not scan cleanly after removing {dependency!r}: {remaining} items left, expected {expected}")
    return result, None


def _ere_escape(text: str) -> str:
    return _ERE_METACHARS.sub(r"\\\1", text)


def _tracked_references(repo_root: Path, directory: str, package: str, excluded: Sequence[str]) -> dict[str, list[str]]:
    """Tracked files that reference the skill, grouped by top-level directory."""
    name = _ere_escape(directory)
    boundary_before, boundary_after = "(^|[^A-Za-z0-9_-])", "([^A-Za-z0-9_-]|$)"
    patterns = [
        f"{boundary_before}skills/([^/ ]+/)?{name}{boundary_after}",
        f"`{name}`",
    ]
    if package:
        patterns.append(f"{boundary_before}{_ere_escape(package)}:{name}{boundary_after}")
    command = ["git", "-C", str(repo_root), "grep", "-I", "-l", "-E"]
    for pattern in patterns:
        command += ["-e", pattern]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise ApplyError(f"cannot scan tracked references to {directory}: {result.stderr.strip()}")
    grouped: dict[str, list[str]] = {}
    for path in result.stdout.splitlines():
        if any(path == prefix or path.startswith(f"{prefix}/") for prefix in excluded):
            continue
        grouped.setdefault(path.split("/", 1)[0], []).append(path)
    return grouped


def _blocking_references(repo_root: Path, guard: DeletionGuard) -> tuple[list[str], list[str]]:
    """(refusing, warning) tracked references to the skill a guard describes."""
    references = _tracked_references(repo_root, guard.directory, guard.package, guard.excluded)
    refusing = [path for root in REFERENCE_REFUSE_ROOTS for path in references.get(root, ())]
    warning = [path for root in REFERENCE_WARN_ROOTS for path in references.get(root, ())]
    return refusing, warning


def _subprocess_env() -> dict[str, str]:
    """Environment for scripts run inside a copy of the tree.

    Either variable would silently point the copy's scripts back at the real tree.
    """
    return {key: value for key, value in os.environ.items() if key not in ("REPO_ROOT", "AGENT_SKILL_PACKAGES_ROOT")}


def _copy_working_tree(repo_root: Path, dest: Path) -> None:
    """Mirror the working tree (not HEAD) minus .git into `dest`."""
    if shutil.which("rsync") is None:
        raise ApplyError("rsync is required to copy the working tree")
    dest.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["rsync", "-a", "--delete", "--exclude=.git", f"{repo_root}/", f"{dest}/"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ApplyError(f"rsync into {dest} failed ({result.returncode}): {result.stderr.strip()}")


def _output_tail(result: subprocess.CompletedProcess[str]) -> str:
    lines = (result.stdout + result.stderr).splitlines()
    return "\n".join(lines[-_OUTPUT_TAIL_LINES:])


@dataclass(slots=True)
class _Workspace:
    """Per-path text as the operations rewrite it, in first-touch order."""

    repo_root: Path
    texts: dict[str, str]
    originals: dict[str, bytes | None]
    deletions: dict[str, str]
    order: list[str]
    warnings: list[str]
    guards: list[DeletionGuard]

    def _touch(self, relpath: str) -> None:
        if relpath not in self.order:
            self.order.append(relpath)

    def read(self, relpath: str) -> str:
        if relpath in self.texts:
            return self.texts[relpath]
        path = self.repo_root / relpath
        _refuse_symlink(path, relpath)
        if not path.is_file():
            raise ApplyError(f"{relpath} does not exist in the working tree")
        data = path.read_bytes()
        self.originals[relpath] = data
        try:
            self.texts[relpath] = data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ApplyError(f"{relpath} is not UTF-8 text: {exc}") from exc
        self._touch(relpath)
        return self.texts[relpath]

    def write(self, relpath: str, text: str) -> None:
        if relpath not in self.originals:
            path = self.repo_root / relpath
            _refuse_symlink(path, relpath)
            self.originals[relpath] = path.read_bytes() if path.is_file() else None
        self.texts[relpath] = text
        self._touch(relpath)

    def delete_tree(self, relpath: str) -> None:
        path = self.repo_root / relpath
        if not path.is_dir():
            raise ApplyError(f"{relpath} is not a directory in the working tree")
        self.deletions[relpath] = _tree_sha256(path)
        self._touch(relpath)

    def warn(self, message: str) -> None:
        if message not in self.warnings:
            self.warnings.append(message)


def _refuse_symlink(path: Path, relpath: str) -> None:
    # Commit replaces the path atomically, which would swap the link for a
    # regular file and leave the linked file carrying the old content.
    if path.is_symlink():
        raise ApplyError(f"{relpath} is a symlink; edit the file it points to instead")


def _source_relpath(row: Row, repo_root: Path) -> str:
    if row.source_record is None:
        raise ApplyError(f"{row.name} has no source-tree record; nothing to edit")
    skill_dir = _skill_dir(row.source_record).resolve()
    try:
        return skill_dir.relative_to(repo_root).as_posix()
    except ValueError as exc:
        raise ApplyError(f"{row.name} lives outside the repository at {skill_dir}") from exc


def _vendor_warning(relpath: str, package: str) -> str:
    return f"{relpath}: vendored edit; the next `{VENDOR_SCRIPT} {package}` run reverts it"


def _plan_frontmatter_edit(ws: _Workspace, row: Row, changes: Mapping[str, str | bool | None]) -> None:
    skill_md = f"{_source_relpath(row, ws.repo_root)}/SKILL.md"
    text = ws.read(skill_md)
    try:
        fm = frontmatter.parse_text(text, path=ws.repo_root / skill_md)
        ws.write(skill_md, frontmatter.edit(fm, changes))
    except frontmatter.FrontmatterError as exc:
        raise ApplyError(f"{skill_md}: {exc}") from exc
    if row.origin is Origin.REPO_VENDOR:
        ws.warn(_vendor_warning(skill_md, row.package))


def _plan_deletion(ws: _Workspace, row: Row, op: Operation) -> None:
    skill_rel = _source_relpath(row, ws.repo_root)
    skill_path = Path(skill_rel)
    if skill_path.parent.name != "vendor" or skill_path.parent.parent.name != "skills":
        raise ApplyError(f"{skill_rel} is not a vendored skill directory; only skills/vendor/* can be deleted")
    package_rel = skill_path.parent.parent.parent.as_posix()
    manifest_rel, lock_rel = f"{package_rel}/apm.yml", f"{package_rel}/apm.lock.yaml"
    dependency = str(op.fields["apm_dep"])
    guard = DeletionGuard(row.name, row.directory, row.package, skill_rel, dependency, (skill_rel, manifest_rel, lock_rel))

    blocking, mentions = _blocking_references(ws.repo_root, guard)
    if blocking:
        raise ApplyError(f"{row.name} is still referenced by tracked files; remove the references first: {', '.join(blocking)}")
    for path in mentions:
        ws.warn(f"{path} still mentions {row.directory}; update it after the deletion")

    ws.guards.append(guard)
    ws.delete_tree(skill_rel)
    if op.fields["remove_apm_dep"]:
        ws.write(manifest_rel, _remove_apm_manifest_dependency(ws.read(manifest_rel), dependency, manifest_rel))
        if (ws.repo_root / lock_rel).is_file():
            new_lock, warning = _remove_apm_lock_dependency(ws.read(lock_rel), dependency, lock_rel)
            ws.write(lock_rel, new_lock)
            if warning:
                ws.warn(warning)
    else:
        ws.warn(f"{skill_rel}: {dependency} stays in {manifest_rel}; the next `{VENDOR_SCRIPT} {row.package}` run restores the skill")


def _plan_generated_templates(ws: _Workspace) -> None:
    """Regenerate the package-derived templates by running the real renderer.

    It runs in a scratch copy of the working tree carrying the edited
    package.toml files, so the plan stays complete and the generator's format
    is never duplicated here.
    """
    with tempfile.TemporaryDirectory(prefix="skill-console-render-") as tmp:
        scratch = Path(tmp) / "tree"
        _copy_working_tree(ws.repo_root, scratch)
        for relpath, text in ws.texts.items():
            if relpath.endswith("/package.toml"):
                (scratch / relpath).write_bytes(text.encode("utf-8"))
        result = subprocess.run(
            [str(scratch / RENDER_SCRIPT), "--plugins-root", str(Path(tmp) / "plugins")],
            cwd=scratch,
            env=_subprocess_env(),
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise ApplyError(f"{RENDER_SCRIPT} failed in the scratch copy ({result.returncode}):\n{_output_tail(result)}")
        for relpath in GENERATED_TEMPLATES:
            ws.write(relpath, (scratch / relpath).read_text(encoding="utf-8"))


def plan(decisions: Decisions, rows: Sequence[Row], repo_root: Path) -> ApplyPlan:
    """Turn operations into per-path edits against the working tree. Reads only."""
    repo_root = repo_root.resolve()
    rows_by_name = {row.name: row for row in rows}
    ws = _Workspace(repo_root, {}, {}, {}, [], [], [])

    def row_for(op: Operation) -> Row:
        row = rows_by_name.get(op.key)
        if row is None:
            raise ApplyError(f"unknown skill {op.key!r}")
        return row

    for op in decisions.operations:
        match op.op:
            case Op.SET_DESCRIPTION:
                _plan_frontmatter_edit(ws, row_for(op), {"description": str(op.fields["text"])})
            case Op.SET_FRONTMATTER:
                _plan_frontmatter_edit(ws, row_for(op), {str(op.fields["field"]): bool(op.fields["value"])})
            case Op.DELETE_SKILL:
                _plan_deletion(ws, row_for(op), op)
            case Op.SET_DEFAULT_LOADED:
                relpath = f"{PACKAGES_DIR}/{op.key}/package.toml"
                ws.write(relpath, _set_toml_bool(ws.read(relpath), "default_loaded", bool(op.fields["value"])))
            case Op.SET_PACKAGE_ENABLED:
                ws.write(SETTINGS_TEMPLATE, _set_setting(ws.read(SETTINGS_TEMPLATE), ENABLED_PLUGINS_KEY, op.key, bool(op.fields["value"])))
            case Op.SET_BUDGET_FRACTION:
                ws.write(SETTINGS_TEMPLATE, _set_setting(ws.read(SETTINGS_TEMPLATE), BUDGET_FRACTION_KEY, None, float(op.fields["to_value"])))

    if any(relpath.endswith("/package.toml") for relpath in ws.order):
        _plan_generated_templates(ws)

    edits: list[PathEdit] = []
    for relpath in ws.order:
        if relpath in ws.deletions:
            edits.append(PathEdit(relpath, "delete-tree", ws.deletions[relpath], None, None))
            continue
        if any(relpath.startswith(f"{deleted}/") for deleted in ws.deletions):
            raise ApplyError(f"{relpath} is edited and deleted in the same document")
        before = ws.originals.get(relpath)
        content = ws.texts[relpath]
        encoded = content.encode("utf-8")
        if before is not None and encoded == before:
            continue
        edits.append(PathEdit(relpath, "write", _sha256(before) if before is not None else None, _sha256(encoded), content))
    return ApplyPlan(edits=tuple(edits), warnings=tuple(ws.warnings), guards=tuple(ws.guards))


# --- staging --------------------------------------------------------------------


def _default_mode() -> int:
    umask = os.umask(0)
    os.umask(umask)
    return 0o666 & ~umask


def _write_bytes_preserving_mode(target: Path, data: bytes, fallback_mode: int | None = None) -> None:
    """Atomic replace via a same-directory temp file; keeps the existing mode bits."""
    if target.is_file():
        mode = target.stat().st_mode
    else:
        mode = fallback_mode if fallback_mode is not None else _default_mode()
    target.parent.mkdir(parents=True, exist_ok=True)
    handle = tempfile.NamedTemporaryFile(dir=target.parent, prefix=f".{target.name}.", suffix=".skill-console", delete=False)
    try:
        with handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(handle.name, mode & 0o7777)
        os.replace(handle.name, target)
    except BaseException:
        Path(handle.name).unlink(missing_ok=True)
        raise


def stage(plan: ApplyPlan, repo_root: Path, staging_root: Path) -> StagedBatch:
    """Copy the working tree (minus .git) and apply the plan inside the copy."""
    repo_root = repo_root.resolve()
    _copy_working_tree(repo_root, staging_root)
    for edit in plan.edits:
        target = staging_root / edit.relpath
        if edit.kind == "delete-tree":
            if not target.is_dir():
                raise ApplyError(f"{edit.relpath} is missing from the staging copy")
            shutil.rmtree(target)
            continue
        if edit.content is None:
            raise ApplyError(f"{edit.relpath}: write edit carries no content")
        _write_bytes_preserving_mode(target, edit.content.encode("utf-8"))
        written = _file_sha256(target)
        if written != edit.after_sha256:
            raise ApplyError(f"{edit.relpath}: staged hash {written} != planned {edit.after_sha256}")
    return StagedBatch(root=staging_root, plan=plan)


def validate_staged(batch: StagedBatch) -> tuple[bool, str]:
    """Run validate-agent-packages and the four make targets inside the copy."""
    root = batch.root
    env = _subprocess_env()
    steps = [("validate-agent-packages", [str(root / VALIDATE_SCRIPT)])]
    steps += [(f"make {target}", ["make", "-C", str(root), target]) for target in STAGED_MAKE_TARGETS]
    for label, command in steps:
        try:
            result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=STAGED_STEP_TIMEOUT_S)
        except FileNotFoundError as exc:
            return False, f"{label}: {exc}"
        except subprocess.TimeoutExpired:
            return False, f"{label} timed out after {STAGED_STEP_TIMEOUT_S}s"
        if result.returncode != 0:
            return False, f"{label} exited {result.returncode}:\n{_output_tail(result)}"
    return True, ""


# --- commit ---------------------------------------------------------------------


def _dirty_paths(repo_root: Path, relpaths: Sequence[str]) -> list[str]:
    if not relpaths:
        return []
    result = subprocess.run(
        ["git", "-C", str(repo_root), "status", "--porcelain=v1", "--untracked-files=all", "--", *relpaths],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ApplyError(f"git status failed: {result.stderr.strip()}")
    return [line[3:] for line in result.stdout.splitlines() if line.strip()]


def _commit_write(staged: Path, target: Path, edit: PathEdit) -> None:
    if target.is_symlink():
        raise ApplyError("became a symlink since planning; refusing to replace the link with a file")
    current = _file_sha256(target)
    if current != edit.before_sha256:
        raise ApplyError(f"changed since planning (expected {edit.before_sha256}, found {current})")
    if not staged.is_file():
        raise ApplyError(f"missing from the staging copy at {staged}")
    data = staged.read_bytes()
    if _sha256(data) != edit.after_sha256:
        raise ApplyError("the staging copy was modified after validation")
    _write_bytes_preserving_mode(target, data, fallback_mode=staged.stat().st_mode)


def _tree_intact(target: Path, expected: str | None) -> bool:
    try:
        return target.is_dir() and _tree_sha256(target) == expected
    except OSError:
        return False


def _commit_deletion(target: Path, edit: PathEdit) -> None:
    if target.is_symlink():
        raise ApplyError("became a symlink since planning")
    if not target.is_dir():
        raise ApplyError("no longer a directory")
    current = _tree_sha256(target)
    if current != edit.before_sha256:
        raise ApplyError(f"changed since planning (expected {edit.before_sha256}, found {current})")
    # Removed in place so that a failure leaves whatever survives at its own
    # path, where `git restore` rebuilds the rest.
    try:
        shutil.rmtree(target)
    except OSError as exc:
        if _tree_intact(target, edit.before_sha256):
            raise ApplyError(f"could not remove it: {exc}") from exc
        raise _PartialDeletion(f"partly removed before failing ({exc}); `git restore` rebuilds it") from exc


def commit(batch: StagedBatch, repo_root: Path, *, allow_dirty: bool) -> CommitReport:
    """Move each validated path into place behind its hash check; not atomic as a batch.

    Stops at the first failure and reports what landed. The staging copy is left
    for the caller, and `git restore -- <applied>` reverts the applied subset.
    """
    repo_root = repo_root.resolve()
    targets = [edit.relpath for edit in batch.plan.edits]
    applied: list[str] = []

    def report(failure: str | None) -> CommitReport:
        return CommitReport(tuple(applied), tuple(path for path in targets if path not in applied), failure)

    for guard in batch.plan.guards:
        try:
            failure = _guard_failure(repo_root, guard)
        except (ApplyError, OSError) as exc:
            return report(str(exc))
        if failure:
            return report(failure)
    if not allow_dirty:
        try:
            dirty = _dirty_paths(repo_root, targets)
        except ApplyError as exc:
            return report(str(exc))
        if dirty:
            return report(f"target paths are dirty in git, refusing to overwrite: {', '.join(dirty)}")
    for edit in batch.plan.edits:
        target = repo_root / edit.relpath
        try:
            if edit.kind == "delete-tree":
                _commit_deletion(target, edit)
            else:
                _commit_write(batch.root / edit.relpath, target, edit)
        except _PartialDeletion as exc:
            applied.append(edit.relpath)
            return report(f"{edit.relpath}: {exc}")
        except (ApplyError, OSError) as exc:
            return report(f"{edit.relpath}: {exc}")
        applied.append(edit.relpath)
    return report(None)


def _guard_failure(repo_root: Path, guard: DeletionGuard) -> str | None:
    """Why a staged delete_skill no longer holds against the working tree, if it does not."""
    blocking, _ = _blocking_references(repo_root, guard)
    if blocking:
        return f"{guard.name} is referenced by tracked files since planning; re-plan after removing them: {', '.join(blocking)}"
    skill_dir = repo_root / guard.skill_relpath
    if skill_dir.is_dir() and (count := _dependency_skill_count(skill_dir, guard.dependency)) != 1:
        return f"{guard.dependency} owns {count} vendored skills since planning, not 1; re-plan"
    return None
