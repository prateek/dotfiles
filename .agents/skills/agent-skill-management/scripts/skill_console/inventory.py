"""Read-only discovery for the skill console.

Everything the simulation runs over comes from here: the chezmoi package source,
the rendered marketplace, the plugin roots Claude Code actually loads, the
merged settings projection, the built-in listing fixture, and the usage
snapshot. Every root is a parameter so tests can point the same code at
fixtures. Nothing in this module writes.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import subprocess
import unicodedata
from collections.abc import Iterable, Mapping, Sequence
from fnmatch import fnmatch
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from pathlib import Path

import agent_skill_lib
from skill_console import (
    BINARY_SHA256,
    BINARY_VERSION,
    CONSOLE_VERSION,
    DEFAULT_BUDGET_FRACTION,
    DEFAULT_MAX_DESC_CHARS,
    SCHEMA_VERSION,
    BudgetInputs,
    Harness,
    ListingEntry,
    Origin,
    PackageRecord,
    Row,
    SkillRecord,
    Snapshot,
    Tree,
    Usage,
    qualified_name,
)
from skill_console import frontmatter
from skill_console.budget import (
    budget_chars,
    bytes_per_token,
    listing_text,
    parse_env_budget,
    rank,
    utf16_length,
)

PACKAGES_RELPATH = Path("home/dot_agents/packages")
REPO_MARKETPLACE = "prateek-local"
ENV_BUDGET_VAR = "SLASH_COMMAND_TOOL_CHAR_BUDGET"

# The only settings keys the console reads. The file can hold credentials, so
# nothing outside this projection is ever loaded into a value, hashed, or shown.
SETTINGS_PROJECTION = (
    "skillListingBudgetFraction",
    "skillListingMaxDescChars",
    "enabledPlugins",
    "skillOverrides",
    "extraKnownMarketplaces",
    "disableBundledSkills",
)
# `Sy()`: any non-empty value delists the built-ins, exactly like JS truthiness.
ENV_DISABLE_BUNDLED_VAR = "CLAUDE_CODE_DISABLE_BUNDLED_SKILLS"
# Layer order is the binary's merge order; later layers win. The flag layer is
# `--settings` on the claude command line, which the console cannot observe, so
# it is never present. The two policy paths are the macOS/Linux managed roots.
SETTINGS_LAYERS = ("user", "project", "local", "flags", "policy")
MANAGED_SETTINGS_PATHS = (
    Path("/Library/Application Support/ClaudeCode/managed-settings.json"),
    Path("/etc/claude-code/managed-settings.json"),
)

# Bare aliases resolve against live account state the console cannot see.
MODEL_ALIASES = frozenset({"opus", "sonnet", "haiku", "fable", "opusplan", "best"})

# `Fte()`: a skill or command with no usable frontmatter description is
# described by its first non-blank body line, heading marker stripped, cut to
# 97 + "..."; an empty body falls back to the loader's label.
DERIVED_DESCRIPTION_MAX = 100
DERIVED_DESCRIPTION_KEEP = 97
SKILL_DESCRIPTION_FALLBACK = "Skill"
COMMAND_DESCRIPTION_FALLBACK = "Custom command"
_HEADING = re.compile(r"^#+\s+(.+)$")

# ICU root collation as far as skill names exercise it, for the binary's
# `localeCompare` sort of legacy commands: punctuation in DUCET order, then
# digits, then letters; case and accents only break ties, lowercase first.
_COLLATION_PUNCTUATION = " _-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$"


@dataclass(frozen=True, slots=True)
class MergedSettings:
    values: Mapping[str, object]
    layers: tuple[str, ...]
    projection_hash: str


@dataclass(frozen=True, slots=True)
class ListingCapture:
    captured_at: str
    session_id: str
    cwd: str
    text: str
    names: tuple[str, ...]
    full: tuple[str, ...]
    name_only: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Divergence:
    name: str
    kind: str
    detail: str


# --- settings ---------------------------------------------------------------


def _read_json(path: Path) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _merge_projection(base: dict[str, object], layer: Mapping[str, object]) -> None:
    for key in SETTINGS_PROJECTION:
        if key not in layer:
            continue
        value = layer[key]
        current = base.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            base[key] = {**current, **value}
        else:
            base[key] = value


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_settings(
    home: Path,
    project_root: Path,
    *,
    config_dir: Path | None = None,
    managed_paths: Sequence[Path] = MANAGED_SETTINGS_PATHS,
) -> MergedSettings:
    """Five-layer merge of the projection keys only; never the whole file.

    `config_dir` is Claude's CLAUDE_CONFIG_DIR; it defaults to `~/.claude`.
    """
    sources: dict[str, Sequence[Path]] = {
        "user": ((config_dir or home / ".claude") / "settings.json",),
        "project": (project_root / ".claude/settings.json",),
        "local": (project_root / ".claude/settings.local.json",),
        "flags": (),
        "policy": tuple(managed_paths),
    }
    values: dict[str, object] = {}
    layers: list[str] = []
    for layer in SETTINGS_LAYERS:
        contributed = False
        for path in sources[layer]:
            data = _read_json(path)
            if isinstance(data, dict) and any(key in data for key in SETTINGS_PROJECTION):
                _merge_projection(values, data)
                contributed = True
        if contributed:
            layers.append(layer)
    return MergedSettings(
        values=values,
        layers=tuple(layers),
        projection_hash=_sha256_text(_canonical_json(values)),
    )


def bundled_skills_disabled(settings: MergedSettings, env: Mapping[str, str]) -> bool:
    """`Sy()`: the env var (any non-empty value) or `disableBundledSkills: true`."""
    return bool(env.get(ENV_DISABLE_BUNDLED_VAR)) or settings.values.get("disableBundledSkills") is True


# --- plugin load roots ------------------------------------------------------


def _installed_plugins(config_dir: Path) -> list[tuple[str, str, str, Path | None]]:
    """(key, package, marketplace, installPath) per installed plugin, in registry order."""
    data = _read_json(config_dir / "plugins/installed_plugins.json")
    plugins = data.get("plugins") if isinstance(data, dict) else None
    result: list[tuple[str, str, str, Path | None]] = []
    if not isinstance(plugins, dict):
        return result
    for key, installs in plugins.items():
        if "@" not in key:
            continue
        entry = installs[0] if isinstance(installs, list) and installs else installs
        install_path = entry.get("installPath") if isinstance(entry, dict) else None
        package, marketplace = key.split("@", 1)
        result.append((key, package, marketplace, Path(install_path) if install_path else None))
    return result


def _known_marketplaces(config_dir: Path) -> dict[str, tuple[str, Path]]:
    """marketplace name -> (source type, installLocation) from the plugin registry."""
    data = _read_json(config_dir / "plugins/known_marketplaces.json")
    known: dict[str, tuple[str, Path]] = {}
    if not isinstance(data, dict):
        return known
    for name, entry in data.items():
        if not isinstance(entry, dict):
            continue
        source = entry.get("source")
        location = entry.get("installLocation")
        if isinstance(source, dict) and isinstance(source.get("source"), str) and location:
            known[name] = (source["source"], Path(location))
    return known


def _manifest_plugin_sources(marketplace_root: Path) -> dict[str, object]:
    data = _read_json(marketplace_root / ".claude-plugin/marketplace.json")
    sources: dict[str, object] = {}
    plugins = data.get("plugins") if isinstance(data, dict) else None
    for plugin in plugins or []:
        if isinstance(plugin, dict) and "name" in plugin:
            sources[str(plugin["name"])] = plugin.get("source")
    return sources


def resolve_load_roots(
    settings: MergedSettings, home: Path, *, config_dir: Path | None = None
) -> dict[str, Path]:
    """`<pkg>@<marketplace>` -> the directory Claude Code loads that plugin from.

    A directory-sourced marketplace loads straight from its installLocation plus
    the manifest's relative `source`; the versioned cache copy under
    `~/.claude/plugins/cache` is vestigial for it. Every other marketplace loads
    from that cache. An installed plugin whose marketplace manifest no longer
    lists it is an orphan and never loads. Installed-but-disabled plugins are
    included so their rows exist; `build_rows` decides what is listed from
    `enabledPlugins`.
    """
    del settings  # enable state does not change where a plugin loads from
    config = config_dir or home / ".claude"
    marketplaces = _known_marketplaces(config)
    manifests = {name: _manifest_plugin_sources(root) for name, (_, root) in marketplaces.items()}
    roots: dict[str, Path] = {}
    for key, package, marketplace, install_path in _installed_plugins(config):
        if marketplace not in marketplaces or package not in manifests[marketplace]:
            continue
        source_type, location = marketplaces[marketplace]
        source = manifests[marketplace][package]
        root = install_path
        if source_type == "directory" and isinstance(source, str):
            root = (location / source).resolve()
        if root is not None:
            roots[key] = root
    return roots


# --- usage, statusline, built-ins -------------------------------------------


def load_usage(config_path: Path) -> dict[str, Usage]:
    """`skillUsage` from `~/.claude.json`, keyed by the qualified listing name."""
    data = _read_json(config_path)
    records = data.get("skillUsage") if isinstance(data, dict) else None
    usage: dict[str, Usage] = {}
    if not isinstance(records, dict):
        return usage
    for name, record in records.items():
        if not isinstance(record, dict):
            continue
        count = record.get("usageCount")
        last = record.get("lastUsedAt")
        if isinstance(count, (int, float)) and isinstance(last, (int, float)):
            usage[str(name)] = Usage(usage_count=int(count), last_used_at_ms=int(last))
    return usage


def load_statusline_state(state_path: Path) -> tuple[str, int, str] | None:
    """`(model_id, context_window_size, captured_at)` from one statusline state file."""
    data = _read_json(state_path)
    if not isinstance(data, dict):
        return None
    model = data.get("model_id")
    window = data.get("context_window_size")
    captured_at = data.get("captured_at")
    if not isinstance(model, str) or not model or not isinstance(window, int) or window <= 0:
        return None
    return model, window, str(captured_at or "")


def load_builtins(fixture_path: Path, *, binary_sha256: str = BINARY_SHA256) -> list[ListingEntry]:
    """Built-in rows for the binary the constants were read from.

    The fixture is keyed by binary hash so an upgraded executable cannot be
    simulated against another version's built-in text by accident.
    """
    data = _read_json(fixture_path)
    if not isinstance(data, dict):
        raise ValueError(f"built-in listing fixture is unreadable: {fixture_path}")
    binaries = data.get("binaries")
    entry = binaries.get(binary_sha256) if isinstance(binaries, dict) else None
    if not isinstance(entry, dict) or not isinstance(entry.get("entries"), list):
        raise ValueError(
            f"built-in listing fixture has no entries for binary sha256 {binary_sha256[:12]}: {fixture_path}"
        )
    entries: list[ListingEntry] = []
    for item in entry["entries"]:
        entries.append(
            ListingEntry(
                name=str(item["name"]),
                listing_text=listing_text(str(item["description"]), item.get("when_to_use")),
                protected=bool(item.get("protected", False)),
                forced_name_only=False,
                rank=0.0,
            )
        )
    return entries


# --- skills -----------------------------------------------------------------


def _left_out_of_render(rel: Path) -> bool:
    """Whether copy_skill_tree drops this path, so it must not move a content hash."""
    return any(
        fnmatch(part, pattern)
        for part in rel.parts
        for pattern in agent_skill_lib.SKILL_TREE_IGNORE_PATTERNS
    )


def _content_sha256(skill_dir: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(p for p in skill_dir.rglob("*") if p.is_file() or p.is_symlink()):
        rel = path.relative_to(skill_dir)
        if _left_out_of_render(rel):
            continue
        # chezmoi's `literal_` attribute prefix is stripped when a skill is
        # rendered, so the source and rendered trees must hash the same name.
        rel = rel.with_name(rel.name.removeprefix("literal_"))
        digest.update(rel.as_posix().encode("utf-8"))
        digest.update(b"\0")
        if path.is_symlink():
            digest.update(b"symlink:" + os.readlink(path).encode("utf-8"))
        else:
            digest.update(hashlib.sha256(path.read_bytes()).hexdigest().encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def _bool_field(values: Mapping[str, object], key: str, default: bool) -> bool:
    value = values.get(key)
    return value if isinstance(value, bool) else default


def _js_string(value: object) -> str:
    """JS `String(value)` for the scalar types YAML produces."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        if math.isnan(value):
            return "NaN"
        if math.isinf(value):
            return "Infinity" if value > 0 else "-Infinity"
        return str(int(value)) if value.is_integer() else repr(value)
    return value if isinstance(value, str) else str(value)


def _text_field(values: Mapping[str, object], key: str) -> str | None:
    """`e[key] != null ? String(e[key]) : undefined`; nothing is trimmed."""
    value = values.get(key)
    return None if value is None else _js_string(value)


def _description_field(values: Mapping[str, object]) -> str | None:
    """`V$()`: a trimmed string (empty counts as absent) or a stringified number
    or boolean; the binary drops any other type with a warning."""
    value = values.get("description")
    if isinstance(value, str):
        return value.strip() or None
    if isinstance(value, (bool, int, float)):
        return _js_string(value)
    return None


def _body_after(fm: frontmatter.Frontmatter) -> str:
    body_start = fm.text.find("\n", fm.block_end)
    return "" if body_start < 0 else fm.text[body_start + 1 :]


def _skill_record(
    skill_dir: Path,
    *,
    tree: Tree,
    package: str,
    origin: Origin,
    fallback: str = SKILL_DESCRIPTION_FALLBACK,
) -> SkillRecord:
    fm = frontmatter.parse(skill_dir / "SKILL.md")
    values = fm.values
    description = _description_field(values)
    return SkillRecord(
        tree=tree,
        package=package,
        directory=skill_dir.name,
        path=skill_dir,
        origin=origin,
        frontmatter_name=(_text_field(values, "name") or "").strip() or skill_dir.name,
        description=(
            description
            if description is not None
            else derived_description(_body_after(fm), fallback)
        ),
        when_to_use=_text_field(values, "when_to_use"),
        disable_model_invocation=_bool_field(values, "disable-model-invocation", False),
        user_invocable=_bool_field(values, "user-invocable", True),
        content_sha256=_content_sha256(skill_dir),
        description_derived=description is None,
    )


def _skill_dirs(parent: Path) -> list[Path]:
    if not parent.is_dir():
        return []
    return sorted(p for p in parent.iterdir() if p.is_dir() and (p / "SKILL.md").is_file())


def _utf16_prefix(text: str, units: int) -> str:
    encoded = text.encode("utf-16-le", "surrogatepass")
    return encoded[: 2 * units].decode("utf-16-le", "surrogatepass")


def derived_description(body: str, fallback: str) -> str:
    """`Fte()`: the first non-blank body line, heading marker stripped, cut to 97 + `...`."""
    for line in body.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        heading = _HEADING.match(stripped)
        text = heading.group(1) if heading else stripped
        if utf16_length(text) > DERIVED_DESCRIPTION_MAX:
            return _utf16_prefix(text, DERIVED_DESCRIPTION_KEEP) + "..."
        return text
    return fallback


def _command_source(path: Path) -> tuple[Mapping[str, object], str]:
    """Frontmatter values and body of a slash-command file; no frontmatter is fine."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return {}, text
    fm = frontmatter.parse_text(text, path=path)
    body_start = text.find("\n", fm.block_end)
    return fm.values, "" if body_start < 0 else text[body_start + 1 :]


def _command_record(path: Path, *, tree: Tree, name: str) -> SkillRecord:
    values, body = _command_source(path)
    description = _description_field(values)
    return SkillRecord(
        tree=tree,
        package="",
        directory=name,
        path=path,
        origin=Origin.USER_COMMAND,
        frontmatter_name=name,
        description=(
            description
            if description is not None
            else derived_description(body, COMMAND_DESCRIPTION_FALLBACK)
        ),
        when_to_use=_text_field(values, "when_to_use"),
        disable_model_invocation=_bool_field(values, "disable-model-invocation", False),
        user_invocable=_bool_field(values, "user-invocable", True),
        content_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        description_derived=description is None,
    )


def _command_name(path: Path, root: Path) -> str:
    """`nVo()`: the path under the root joined with ":"; a SKILL.md names its directory."""
    rel = path.parent.relative_to(root) if path.name == "SKILL.md" else path.relative_to(root).with_suffix("")
    return ":".join(rel.parts)


def _command_records(root: Path, tree: Tree) -> list[SkillRecord]:
    """`RG()` then `Zqo()`: every `.md` below the root, except that a directory
    holding a SKILL.md contributes that file alone."""
    by_dir: dict[Path, list[Path]] = {}
    for path in sorted(root.rglob("*", recurse_symlinks=True)):
        if path.name.endswith(".md") and path.is_file():
            by_dir.setdefault(path.parent, []).append(path)
    records: list[SkillRecord] = []
    for files in by_dir.values():
        skill_files = [path for path in files if path.name == "SKILL.md"]
        for path in skill_files[:1] or files:
            records.append(_command_record(path, tree=tree, name=_command_name(path, root)))
    return records


def locale_sort_key(name: str) -> tuple[list[tuple[int, object]], list[str], list[bool], str]:
    """A sort key that orders names the way `String.prototype.localeCompare` does."""
    primary: list[tuple[int, object]] = []
    secondary: list[str] = []
    tertiary: list[bool] = []
    for char in name:
        decomposed = unicodedata.normalize("NFD", char)
        base = decomposed[0]
        if base in _COLLATION_PUNCTUATION:
            primary.append((0, _COLLATION_PUNCTUATION.index(base)))
        elif base.isdecimal():
            primary.append((1, unicodedata.decimal(base)))
        else:
            primary.append((2, base.casefold()))
        secondary.append(decomposed[1:])
        tertiary.append(base.isupper())
    return primary, secondary, tertiary, name


def _plugin_manifest(plugin_root: Path) -> Mapping[str, object]:
    data = _read_json(plugin_root / ".claude-plugin/plugin.json")
    return data if isinstance(data, dict) else {}


def _is_plugin_root(path: Path) -> bool:
    return (path / ".claude-plugin/plugin.json").is_file() or (path / "skills").is_dir()


def _plugin_records(plugin_root: Path, tree: Tree) -> list[SkillRecord]:
    manifest = _plugin_manifest(plugin_root)
    package = _text_field(manifest, "name") or plugin_root.name
    declared = manifest.get("skills")
    skill_roots = [plugin_root / "skills"]
    if isinstance(declared, str):
        skill_roots = [plugin_root / declared]
    elif isinstance(declared, list):
        skill_roots = [plugin_root / entry for entry in declared if isinstance(entry, str)]
    records: list[SkillRecord] = []
    for skill_root in skill_roots:
        for skill_dir in _skill_dirs(skill_root):
            # SOURCE.md is the vendoring marker vendor-agent-package leaves in
            # every copied skill; it survives rendering, so it tells local from
            # vendor in trees that have flattened the source layout.
            origin = Origin.REPO_VENDOR if (skill_dir / "SOURCE.md").is_file() else Origin.REPO_LOCAL
            records.append(_skill_record(skill_dir, tree=tree, package=package, origin=origin))
    return records


def _source_records(packages_root: Path) -> list[SkillRecord]:
    records: list[SkillRecord] = []
    for package_dir in sorted(p for p in packages_root.iterdir() if p.is_dir()):
        for skill in agent_skill_lib.iter_package_skills(package_dir):
            origin = Origin.REPO_VENDOR if skill.kind == "vendor" else Origin.REPO_LOCAL
            records.append(
                _skill_record(skill.path, tree=Tree.SOURCE, package=skill.package_id, origin=origin)
            )
    return records


def load_skills(root: Path, tree: Tree, *, origin: Origin | None = None) -> list[SkillRecord]:
    """Every skill under one root, tagged with the tree it was read from.

    The root's shape decides the walk: the chezmoi packages root for SOURCE; a
    single plugin root or a directory of plugin roots for MARKETPLACE and CACHE;
    a flat `<dir>/SKILL.md` root or a `*.md` commands root when `origin` names an
    unmanaged origin. Marketplace and cache records carry a provisional
    local/vendor origin; `build_rows` marks packages the repo does not own as
    third-party.
    """
    if not root.is_dir():
        return []
    if tree is Tree.SOURCE:
        return _source_records(root)
    if origin is Origin.USER_COMMAND:
        return _command_records(root, tree)
    if origin in (Origin.USER_SKILL, Origin.REPO_PROJECT):
        real_root = root.resolve()
        return [
            _skill_record(skill_dir, tree=tree, package="", origin=origin)
            for skill_dir in _skill_dirs(real_root)
        ]
    if origin is not None:
        raise ValueError(f"load_skills cannot walk a {origin.value} root: {root}")
    if _is_plugin_root(root):
        return _plugin_records(root, tree)
    records: list[SkillRecord] = []
    for child in sorted(p for p in root.iterdir() if p.is_dir()):
        if _is_plugin_root(child):
            records.extend(_plugin_records(child, tree))
    return records


def project_claude_dirs(start: Path, project_root: Path | None, home: Path, name: str) -> list[Path]:
    """`Yz()`: existing `<dir>/.claude/<name>` for `start` and each ancestor.

    The walk stops after the project root (the binary uses the git toplevel)
    and never reaches `home`, whose `.claude` is the user root.
    """
    home = home.resolve()
    boundary = project_root.resolve() if project_root is not None else None
    directory = start.resolve()
    found: list[Path] = []
    while directory != home:
        candidate = directory / ".claude" / name
        if candidate.is_dir():
            found.append(candidate)
        if directory == boundary or directory.parent == directory:
            break
        directory = directory.parent
    return found


def load_unmanaged_skills(
    home: Path,
    project_root: Path,
    *,
    cwd: Path | None = None,
    config_dir: Path | None = None,
    main_worktree_root: Path | None = None,
) -> list[SkillRecord]:
    """User skills, project skills, then legacy commands, in listing order.

    Skill directories follow `sVo()`: `<config>/skills`, then `.claude/skills`
    from cwd up to the project root. Commands follow `rVo()` over `Uzr()`:
    `<config>/commands`, the same ancestor walk for `.claude/commands`, plus
    the main worktree's `.claude/commands` when a linked worktree has none of
    its own; the binary then sorts every command by `localeCompare`. These load
    live, outside any package, so they belong to the CACHE tree.
    """
    config = config_dir or home / ".claude"
    start = cwd or project_root
    records = load_skills(config / "skills", Tree.CACHE, origin=Origin.USER_SKILL)
    for directory in project_claude_dirs(start, project_root, home, "skills"):
        records.extend(load_skills(directory, Tree.CACHE, origin=Origin.REPO_PROJECT))
    command_roots = [config / "commands", *project_claude_dirs(start, project_root, home, "commands")]
    own = (project_root / ".claude" / "commands").resolve()
    if (
        main_worktree_root is not None
        and main_worktree_root.resolve() != project_root.resolve()
        and all(root.resolve() != own for root in command_roots)
    ):
        command_roots.append(main_worktree_root / ".claude" / "commands")
    commands = [
        record
        for root in command_roots
        for record in load_skills(root, Tree.CACHE, origin=Origin.USER_COMMAND)
    ]
    commands.sort(key=lambda record: locale_sort_key(record.directory))
    return [*records, *commands]


def load_repo_packages(repo_root: Path) -> list[PackageRecord]:
    """One record per chezmoi package; counts cover the source tree only."""
    return [
        PackageRecord(
            name=package.package_id,
            display_name=package.display_name,
            path=package.path,
            default_loaded=package.default_loaded,
            render_claude=package.render.get("claude", "none"),
            render_codex=package.render.get("codex", "none"),
            marketplace=REPO_MARKETPLACE,
            skill_count={Tree.SOURCE: len(package.skills)},
        )
        for package in agent_skill_lib.load_packages(repo_root / PACKAGES_RELPATH)
    ]


# --- listing capture --------------------------------------------------------

_ROW_START = re.compile(r"^- ([^\s:]+)(: |$)")


def project_slug(cwd: Path) -> str:
    """The `~/.claude/projects/<slug>` directory name for a working directory."""
    return re.sub(r"[^A-Za-z0-9]", "-", str(cwd))


def _row_names(text: str) -> list[str]:
    """Row names for captures that predate the attachment's `names` field."""
    return [match.group(1) for line in text.split("\n") if (match := _ROW_START.match(line))]


def decompose_listing(text: str, names: Sequence[str]) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """Split a rendered listing into (full, name_only) at exact character offsets.

    Descriptions may contain newlines, so rows are located by their known names
    rather than by line breaks.
    """
    full: list[str] = []
    name_only: list[str] = []
    pos = 0
    for index, name in enumerate(names):
        head = f"- {name}"
        if not text.startswith(head, pos):
            raise ValueError(f"listing capture does not contain row {name!r} at offset {pos}")
        pos += len(head)
        if text.startswith(": ", pos):
            full.append(name)
            following = text.find(f"\n- {names[index + 1]}", pos) if index + 1 < len(names) else -1
            pos = len(text) if following < 0 else following
        else:
            name_only.append(name)
        if pos < len(text):
            pos += 1
    return tuple(full), tuple(name_only)


def load_listing_capture(projects_root: Path, cwd: Path) -> ListingCapture | None:
    """The newest initial `skill_listing` attachment recorded for this cwd."""
    project_dir = projects_root / project_slug(cwd)
    if not project_dir.is_dir():
        return None
    newest: dict[str, object] | None = None
    for path in sorted(project_dir.glob("*.jsonl")):
        try:
            handle = path.open(encoding="utf-8", errors="replace")
        except OSError:
            continue
        with handle:
            for line in handle:
                if '"skill_listing"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                attachment = entry.get("attachment") if isinstance(entry, dict) else None
                if not isinstance(attachment, dict) or attachment.get("type") != "skill_listing":
                    continue
                if not attachment.get("isInitial") or entry.get("cwd") != str(cwd):
                    continue
                if newest is None or str(entry.get("timestamp", "")) > str(newest.get("timestamp", "")):
                    newest = entry
    if newest is None:
        return None
    attachment = newest["attachment"]
    text = str(attachment.get("content", ""))
    names = attachment.get("names")
    if not isinstance(names, list):
        names = _row_names(text)
    full, name_only = decompose_listing(text, [str(name) for name in names])
    return ListingCapture(
        captured_at=str(newest.get("timestamp", "")),
        session_id=str(newest.get("sessionId", "")),
        cwd=str(newest.get("cwd", "")),
        text=text,
        names=tuple(str(name) for name in names),
        full=full,
        name_only=name_only,
    )


# --- budget inputs ----------------------------------------------------------


def _positive_number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value) if value > 0 else None


def resolve_budget_inputs(
    settings: MergedSettings,
    *,
    model: str | None,
    context_window: int | None,
    statusline_state: tuple[str, int, str] | None,
    env: Mapping[str, str],
) -> tuple[BudgetInputs, str, list[str]]:
    """Flags, then the statusline state file, then a hard failure.

    Raises ValueError when the model or window is unresolved or the model is a
    bare alias; the CLI maps that to its discovery exit code.
    """
    warnings: list[str] = []
    model_id = model
    window = context_window
    if statusline_state is not None:
        state_model, state_window, state_at = statusline_state
        origin = f"statusline state captured {state_at}" if state_at else "statusline state"
        if model_id is None:
            model_id = state_model
            warnings.append(f"model {state_model!r} taken from {origin}")
        if window is None:
            window = state_window
            warnings.append(f"context window {state_window} taken from {origin}")
    missing = [flag for flag, value in (("--model", model_id), ("--context-window", window)) if value is None]
    if missing:
        raise ValueError(
            f"cannot resolve {' and '.join(missing)}: no statusline state file; pass {' '.join(missing)}"
        )
    assert model_id is not None and window is not None
    if model_id.strip().lower() in MODEL_ALIASES:
        raise ValueError(
            f"model {model_id!r} is a bare alias that resolves against account state the console cannot see; pass the full model id"
        )
    if window <= 0:
        raise ValueError(f"context window must be positive, got {window}")

    values = settings.values
    fraction = DEFAULT_BUDGET_FRACTION
    raw_fraction = values.get("skillListingBudgetFraction")
    if raw_fraction is None:
        warnings.append(f"skillListingBudgetFraction is unset; using the binary default {DEFAULT_BUDGET_FRACTION}")
    elif _positive_number(raw_fraction) is None:
        warnings.append(f"ignoring skillListingBudgetFraction {raw_fraction!r}; using {DEFAULT_BUDGET_FRACTION}")
    else:
        fraction = float(raw_fraction)
        if fraction > 1:
            warnings.append(
                f"skillListingBudgetFraction {raw_fraction!r} is outside the binary's settings schema"
                " (greater than 0, at most 1); the console keeps it, but the binary's handling of an"
                " invalid settings layer is unverified, so treat every number below as suspect"
            )
    max_desc_chars = DEFAULT_MAX_DESC_CHARS
    raw_cap = values.get("skillListingMaxDescChars")
    if raw_cap is not None:
        if _positive_number(raw_cap) is None:
            warnings.append(f"ignoring skillListingMaxDescChars {raw_cap!r}; using {DEFAULT_MAX_DESC_CHARS}")
        else:
            max_desc_chars = int(raw_cap)
    raw_env = env.get(ENV_BUDGET_VAR)
    env_budget = parse_env_budget(raw_env)
    if raw_env is not None:
        if env_budget:
            warnings.append(f"{ENV_BUDGET_VAR}={raw_env!r} overrides the computed budget")
        else:
            warnings.append(f"{ENV_BUDGET_VAR}={raw_env!r} is not a usable budget; ignored like the binary does")
    inputs = BudgetInputs(
        context_window=int(window),
        bytes_per_token=bytes_per_token(model_id),
        fraction=fraction,
        max_desc_chars=max_desc_chars,
        env_budget=env_budget,
    )
    return inputs, model_id, warnings


# --- rows -------------------------------------------------------------------

_UNMANAGED_ORDER = (Origin.USER_SKILL, Origin.REPO_PROJECT, Origin.USER_COMMAND)
_DELISTING_OVERRIDES = frozenset({"off", "user-invocable-only"})
BUILTIN_PATH = Path("<builtin>")


def _override_state(settings: MergedSettings | None, name: str) -> str | None:
    overrides = settings.values.get("skillOverrides") if settings is not None else None
    if not isinstance(overrides, dict):
        return None
    value = overrides.get(name)
    if isinstance(value, dict):
        value = value.get("state")
    return value if isinstance(value, str) else None


def _enabled_key(package: str, repo: Mapping[str, PackageRecord], enabled: Mapping[str, object]) -> str | None:
    """The `<pkg>@<marketplace>` key a package's enable state lives under."""
    if package in repo:
        return f"{package}@{repo[package].marketplace}"
    matches = [key for key in enabled if key.split("@", 1)[0] == package]
    return matches[0] if len(matches) == 1 else None


def _first_by_key(records: Iterable[SkillRecord]) -> dict[tuple[str, str], SkillRecord]:
    index: dict[tuple[str, str], SkillRecord] = {}
    for record in records:
        index.setdefault((record.package, record.directory), record)
    return index


def _row_order(
    packages: Sequence[PackageRecord],
    cache_records: Sequence[SkillRecord],
    keys: Iterable[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Listing order: unmanaged roots, then plugins in load order, then leftovers.

    Within a package the binary lists skill directories in name order; packages
    that never reach the cache (disabled, source-only) follow in repo order so
    their rows still group sensibly.
    """
    package_rank: dict[str, int] = {}
    for record in cache_records:
        if record.package:
            package_rank.setdefault(record.package, len(package_rank))
    for package in packages:
        package_rank.setdefault(package.name, len(package_rank))
    unmanaged_rank = {
        (record.package, record.directory): (index, position)
        for position, record in enumerate(cache_records)
        if not record.package
        for index, origin in enumerate(_UNMANAGED_ORDER)
        if record.origin is origin
    }

    def sort_key(key: tuple[str, str]) -> tuple[int, int, int, str]:
        package, directory = key
        if not package:
            group, position = unmanaged_rank.get(key, (len(_UNMANAGED_ORDER), 0))
            return (0, group, position, directory)
        return (1, package_rank.get(package, len(package_rank)), 0, directory)

    return sorted(dict.fromkeys(keys), key=sort_key)


def _record_divergences(
    name: str,
    repo_owned: bool,
    source: SkillRecord | None,
    marketplace: SkillRecord | None,
    cache: SkillRecord | None,
) -> list[Divergence]:
    if not repo_owned:
        return []
    present = {Tree.SOURCE: source, Tree.MARKETPLACE: marketplace, Tree.CACHE: cache}
    found = [tree.value for tree, record in present.items() if record is not None]
    divergences = [
        Divergence(name, "missing", f"absent from {tree.value}; present in {', '.join(found)}")
        for tree, record in present.items()
        if record is None
    ]
    pairs = ((Tree.SOURCE, source, Tree.MARKETPLACE, marketplace), (Tree.MARKETPLACE, marketplace, Tree.CACHE, cache))
    for left_tree, left, right_tree, right in pairs:
        if left is not None and right is not None and left.content_sha256 != right.content_sha256:
            divergences.append(
                Divergence(name, "content", f"{left_tree.value} content differs from {right_tree.value}")
            )
    return divergences


def _builtin_record(entry: ListingEntry) -> SkillRecord:
    return SkillRecord(
        tree=Tree.CACHE,
        package="",
        directory=entry.name,
        path=BUILTIN_PATH / entry.name,
        origin=Origin.BUILTIN,
        frontmatter_name=entry.name,
        description=entry.listing_text,
        when_to_use=None,
        disable_model_invocation=False,
        user_invocable=True,
        content_sha256=_sha256_text(entry.listing_text),
    )


def build_rows(
    packages: Sequence[PackageRecord],
    by_tree: Mapping[Tree, Sequence[SkillRecord]],
    builtins: Sequence[ListingEntry],
    usage: Mapping[str, Usage],
    settings: MergedSettings,
    now_ms: int,
    *,
    enable_state: Mapping[Harness, Mapping[str, bool]] | None = None,
    disable_bundled: bool = False,
) -> list[Row]:
    """Join the trees into console rows, in listing order, with live state.

    `rendered`, `capped`, and `width_divergent` stay at their unlisted defaults;
    the caller joins the Admission back on. `enable_state` carries per-harness
    `<pkg>@<marketplace>` -> enabled maps for harnesses other than Claude.
    `disable_bundled` is `bundled_skills_disabled()` and delists every built-in.
    """
    repo = {package.name: package for package in packages}
    source = _first_by_key(by_tree.get(Tree.SOURCE, ()))
    marketplace = _first_by_key(by_tree.get(Tree.MARKETPLACE, ()))
    cache_records = list(by_tree.get(Tree.CACHE, ()))
    cache = _first_by_key(cache_records)
    enabled = settings.values.get("enabledPlugins")
    enabled = enabled if isinstance(enabled, dict) else {}
    other_harnesses = enable_state or {}

    rows: list[Row] = []
    listed_names: set[str] = set()
    for key in _row_order(packages, cache_records, [*source, *marketplace, *cache]):
        package, directory = key
        src, mkt, cch = source.get(key), marketplace.get(key), cache.get(key)
        repo_owned = not package or package in repo
        if package and not repo_owned:
            mkt = replace(mkt, origin=Origin.THIRD_PARTY_PLUGIN) if mkt else None
            cch = replace(cch, origin=Origin.THIRD_PARTY_PLUGIN) if cch else None
        primary = src or mkt or cch
        assert primary is not None
        name = qualified_name(package, directory)
        live_enabled: dict[Harness, bool] = {}
        if package:
            enabled_key = _enabled_key(package, repo, enabled)
            live_enabled[Harness.CLAUDE] = enabled_key is not None and enabled.get(enabled_key) is True
            for harness, states in other_harnesses.items():
                if enabled_key is not None and enabled_key in states:
                    live_enabled[harness] = bool(states[enabled_key])
        else:
            live_enabled[Harness.CLAUDE] = True
        # `gpe()`: a plugin-loaded skill is only listed when the author wrote a
        # description or a when_to_use; skill-dir and command rows always are.
        listed = (
            cch is not None
            and live_enabled[Harness.CLAUDE]
            and not cch.disable_model_invocation
            and (not package or not cch.description_derived or bool(cch.when_to_use))
            and _override_state(settings, name) not in _DELISTING_OVERRIDES
            and name not in listed_names
        )
        if listed:
            listed_names.add(name)
        rows.append(
            Row(
                name=name,
                directory=directory,
                package=package,
                origin=primary.origin,
                protected=False,
                source_record=src,
                marketplace_record=mkt,
                cache_record=cch,
                listed=listed,
                repo_default=repo[package].default_loaded if package in repo else False,
                live_enabled=live_enabled,
                usage=usage.get(name),
                rank=rank(usage.get(name), now_ms),
                rendered=None,
                capped=False,
                width_divergent=False,
                derived_description=primary.description_derived,
                divergences=tuple(
                    divergence.detail
                    for divergence in _record_divergences(name, bool(package) and repo_owned, src, mkt, cch)
                ),
            )
        )

    for entry in builtins:
        # A bundled prompt loses its name to any non-bundled row that claimed it
        # first; that is the binary's dedupe, not a divergence.
        listed = (
            not disable_bundled
            and entry.name not in listed_names
            and _override_state(settings, entry.name) not in _DELISTING_OVERRIDES
        )
        if listed:
            listed_names.add(entry.name)
        rows.append(
            Row(
                name=entry.name,
                directory=entry.name,
                package="",
                origin=Origin.BUILTIN,
                protected=entry.protected,
                source_record=None,
                marketplace_record=None,
                cache_record=_builtin_record(entry),
                listed=listed,
                repo_default=False,
                live_enabled={Harness.CLAUDE: True},
                usage=usage.get(entry.name),
                rank=rank(usage.get(entry.name), now_ms),
                rendered=None,
                capped=False,
                width_divergent=False,
                derived_description=False,
                divergences=(),
            )
        )
    return rows


def _loaded_record(row: Row) -> SkillRecord | None:
    return row.cache_record or row.marketplace_record or row.source_record


def entries_for(rows: Sequence[Row], *, settings: MergedSettings | None = None) -> list[ListingEntry]:
    """Listed rows as admission input, in listing order, first name wins.

    `skillOverrides` only reaches command-registry rows (built-ins and unmanaged
    skills); it is inert for plugin skills, so `forced_name_only` is only ever
    set on rows without a package.
    """
    entries: list[ListingEntry] = []
    seen: set[str] = set()
    for row in rows:
        if not row.listed or row.name in seen:
            continue
        seen.add(row.name)
        record = _loaded_record(row)
        text = listing_text(record.description, record.when_to_use) if record else ""
        entries.append(
            ListingEntry(
                name=row.name,
                listing_text=text,
                protected=row.protected,
                forced_name_only=not row.package and _override_state(settings, row.name) == "name-only",
                rank=row.rank,
            )
        )
    return entries


def reconcile(rows: Sequence[Row]) -> list[Divergence]:
    """Three-way drift: per-row missing/content, per-package count and enable state."""
    divergences: list[Divergence] = []
    by_package: dict[str, list[Row]] = {}
    for row in rows:
        if row.origin in (Origin.REPO_LOCAL, Origin.REPO_VENDOR):
            by_package.setdefault(row.package, []).append(row)
            divergences.extend(
                _record_divergences(row.name, True, row.source_record, row.marketplace_record, row.cache_record)
            )
    for package, package_rows in by_package.items():
        counts = {
            Tree.SOURCE: sum(row.source_record is not None for row in package_rows),
            Tree.MARKETPLACE: sum(row.marketplace_record is not None for row in package_rows),
            Tree.CACHE: sum(row.cache_record is not None for row in package_rows),
        }
        if len(set(counts.values())) > 1:
            summary = ", ".join(f"{tree.value} {count}" for tree, count in counts.items())
            divergences.append(Divergence(package, "count", f"{summary} skills"))
        repo_default = package_rows[0].repo_default
        for harness, live in package_rows[0].live_enabled.items():
            if live != repo_default:
                divergences.append(
                    Divergence(
                        package,
                        "enable-state",
                        f"package.toml default_loaded={str(repo_default).lower()} but {harness.value} has it {'enabled' if live else 'disabled'}",
                    )
                )
    return divergences


# --- snapshot ---------------------------------------------------------------


def _tree_hash(records: Iterable[SkillRecord]) -> str:
    lines = sorted(
        f"{record.origin.value}\t{record.package}\t{record.directory}\t{record.content_sha256}"
        for record in records
    )
    return "sha256:" + _sha256_text("\n".join(lines))


def _usage_hash(usage: Mapping[str, Usage]) -> str:
    projection = {name: [record.usage_count, record.last_used_at_ms] for name, record in usage.items()}
    return "sha256:" + _sha256_text(_canonical_json(projection))


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git(repo_root: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_root), *args], capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    return result.stdout if result.returncode == 0 else None


def build_snapshot(
    *,
    inputs: BudgetInputs,
    model: str,
    by_tree: Mapping[Tree, Sequence[SkillRecord]],
    settings: MergedSettings,
    usage: Mapping[str, Usage],
    capture: ListingCapture | None,
    binary_path: Path | None,
    repo_root: Path,
    cwd: Path,
    project_root: Path,
    now_ms: int,
    harness: Harness = Harness.CLAUDE,
) -> Snapshot:
    """Everything `apply` needs to prove it is looking at the same world as `render`."""
    binary_hex = _file_sha256(binary_path) if binary_path is not None and binary_path.is_file() else ""
    rev = _git(repo_root, "rev-parse", "HEAD")
    status = _git(repo_root, "status", "--porcelain")
    return Snapshot(
        schema_version=SCHEMA_VERSION,
        harness=harness,
        console_version=CONSOLE_VERSION,
        binary_version=BINARY_VERSION,
        binary_hash=f"sha256:{binary_hex}" if binary_hex else "",
        binary_hash_matched=binary_hex == BINARY_SHA256,
        source_hash=_tree_hash(by_tree.get(Tree.SOURCE, ())),
        marketplace_hash=_tree_hash(by_tree.get(Tree.MARKETPLACE, ())),
        cache_hash=_tree_hash(by_tree.get(Tree.CACHE, ())),
        settings_hash=f"sha256:{settings.projection_hash}",
        usage_hash=_usage_hash(usage),
        model=model,
        context_window=inputs.context_window,
        bytes_per_token=inputs.bytes_per_token,
        fraction=inputs.fraction,
        max_desc_chars=inputs.max_desc_chars,
        budget_chars=budget_chars(inputs),
        budget_env_override=inputs.env_budget,
        cwd=str(cwd),
        project_root=str(project_root),
        git_rev=(rev or "").strip(),
        git_dirty=bool((status or "").strip()),
        now_ms=now_ms,
        captured_at=datetime.fromtimestamp(now_ms / 1000, UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        listing_capture_at=capture.captured_at if capture is not None else None,
    )
