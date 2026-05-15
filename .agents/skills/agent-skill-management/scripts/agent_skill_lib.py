from __future__ import annotations

import hashlib
import json
import os
import shutil
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[3]
PACKAGES_ROOT = Path(
    os.environ.get(
        "AGENT_SKILL_PACKAGES_ROOT",
        str(REPO_ROOT / "home/dot_agents/packages"),
    )
)
CODEX_PLUGIN_CONFIG_TEMPLATE = (
    REPO_ROOT / "home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl"
)
CLAUDE_PLUGIN_SETTINGS_TEMPLATE = (
    REPO_ROOT / "home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl"
)

GENERATED_README = "README.generated.md"
VALID_RENDER_VALUES = {"root", "plugin", "none"}
AGENTS = ("codex", "claude")


@dataclass(frozen=True)
class SkillSource:
    package_id: str
    kind: str
    skill_id: str
    path: Path


@dataclass(frozen=True)
class Package:
    package_id: str
    path: Path
    display_name: str
    render: dict[str, str]
    skills: tuple[SkillSource, ...]
    default_loaded: bool = True


def load_packages() -> list[Package]:
    packages: list[Package] = []
    if not PACKAGES_ROOT.exists():
        return packages
    for path in sorted(p for p in PACKAGES_ROOT.iterdir() if p.is_dir()):
        manifest = path / "package.toml"
        if not manifest.exists():
            raise ValueError(f"missing package manifest: {manifest}")
        data = tomllib.loads(manifest.read_text())
        render = {
            agent: str(data.get("render", {}).get(agent, "none"))
            for agent in AGENTS
        }
        default_loaded = data.get("default_loaded", True)
        if not isinstance(default_loaded, bool):
            raise ValueError(
                f"{manifest}: default_loaded must be a TOML boolean, "
                f"got {type(default_loaded).__name__} {default_loaded!r}"
            )
        packages.append(
            Package(
                package_id=path.name,
                path=path,
                display_name=str(data.get("display_name", path.name)),
                render=render,
                skills=tuple(iter_package_skills(path)),
                default_loaded=default_loaded,
            )
        )
    return packages


def iter_package_skills(package_path: Path) -> Iterable[SkillSource]:
    package_id = package_path.name
    for kind in ("local", "vendor"):
        root = package_path / "skills" / kind
        if not root.exists():
            continue
        for path in sorted(p for p in root.iterdir() if p.is_dir()):
            if (path / "SKILL.md").exists():
                yield SkillSource(package_id, kind, path.name, path)


def skill_frontmatter(path: Path) -> dict[str, str]:
    skill_md = path / "SKILL.md"
    lines = skill_md.read_text(errors="replace").splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{skill_md} missing YAML frontmatter")
    end = None
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            end = index
            break
    if end is None:
        raise ValueError(f"{skill_md} missing closing YAML frontmatter")
    data: dict[str, str] = {}
    for line in lines[1:end]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip().strip('"').strip("'")
        data[key.strip()] = value
    if not data.get("name") or not data.get("description"):
        raise ValueError(f"{skill_md} must define name and description")
    return data


def iter_skill_dirs(root: Path) -> Iterable[Path]:
    for skill_md in sorted(root.rglob("SKILL.md")):
        yield skill_md.parent


def iter_skill_metadata(root: Path) -> Iterable[tuple[Path, dict[str, str]]]:
    for skill_dir in iter_skill_dirs(root):
        yield skill_dir, skill_frontmatter(skill_dir)


def package_skills_by_name(
    packages: Iterable[Package],
) -> tuple[dict[str, SkillSource], dict[str, list[SkillSource]]]:
    skills: dict[str, SkillSource] = {}
    duplicates: dict[str, list[SkillSource]] = {}
    for package in packages:
        for skill in package.skills:
            name = skill_frontmatter(skill.path)["name"]
            if name in skills:
                duplicates.setdefault(name, [skills[name]]).append(skill)
                continue
            skills[name] = skill
    return skills, duplicates


def copy_skill_tree(source: Path, target: Path) -> None:
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        shutil.rmtree(target)
    shutil.copytree(
        source,
        target,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        copy_function=_copy_stripping_literal_prefix,
    )


def _copy_stripping_literal_prefix(src: str, dst: str) -> None:
    # Mirror chezmoi's `literal_` attribute prefix so vendored files that collide
    # with chezmoi script prefixes (e.g. `run_*.py`) land at their real names in
    # the rendered tree, matching the names chezmoi materializes from the source.
    # `shutil.copytree` hands `copy_function` os.path.join'd strings, hence str args.
    dst_path = Path(dst)
    if dst_path.name.startswith("literal_"):
        stripped = dst_path.with_name(dst_path.name.removeprefix("literal_"))
        if stripped.exists():
            raise FileExistsError(
                f"literal_-stripped target already exists: {stripped}"
            )
        dst_path = stripped
    shutil.copy2(src, dst_path)


def reset_dir(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")


def write_generated_readme(path: Path, generator: str, detail: str = "") -> None:
    suffix = f"\n\n{detail.strip()}\n" if detail.strip() else "\n"
    write_text(
        path / GENERATED_README,
        (
            "# Generated Directory\n\n"
            f"Generated by `{generator}`.\n\n"
            "Edit `home/dot_agents/packages/` instead, then rerun the generator."
            f"{suffix}"
        ),
    )


def write_skills_gitignore(path: Path) -> None:
    write_text(
        path / ".gitignore",
        (
            "# Codex writes runtime system skills here via the ~/.codex/skills symlink.\n"
            "# These change with Codex versions and should not be version-controlled.\n"
            ".system/\n"
        ),
    )


def relative_files(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    if not root.exists():
        return result
    for path in sorted(p for p in root.rglob("*") if p.is_file() or p.is_symlink()):
        rel = path.relative_to(root).as_posix()
        if path.is_symlink():
            result[rel] = f"symlink:{os.readlink(path)}"
        else:
            result[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def compare_dirs(expected: Path, actual: Path) -> list[str]:
    expected_files = relative_files(expected)
    actual_files = relative_files(actual)
    diffs: list[str] = []
    for rel in sorted(expected_files.keys() - actual_files.keys()):
        diffs.append(f"missing {rel}")
    for rel in sorted(actual_files.keys() - expected_files.keys()):
        diffs.append(f"extra {rel}")
    for rel in sorted(expected_files.keys() & actual_files.keys()):
        if expected_files[rel] != actual_files[rel]:
            diffs.append(f"changed {rel}")
    return diffs


def require_no_drift(expected: Path, actual: Path, label: str) -> None:
    diffs = compare_dirs(expected, actual)
    if diffs:
        preview = "\n".join(f"  - {diff}" for diff in diffs[:20])
        more = "" if len(diffs) <= 20 else f"\n  ... {len(diffs) - 20} more"
        raise SystemExit(f"{label} is stale:\n{preview}{more}")


def require_file_text(expected: Path, actual: Path, label: str) -> None:
    if not actual.exists():
        raise SystemExit(f"{label} is stale:\n  - missing {actual}")
    if expected.read_text() != actual.read_text():
        raise SystemExit(f"{label} is stale:\n  - changed {actual}")
