from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tomllib
from functools import lru_cache
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[3]
PACKAGES_ROOT = Path(
    os.environ.get(
        "AGENT_SKILL_PACKAGES_ROOT",
        str(REPO_ROOT / "agent-marketplace/packages"),
    )
)
POLICY_PATH = REPO_ROOT / "home/.chezmoidata/agent_plugins.toml"
sys.path.insert(0, str(REPO_ROOT / "agent-marketplace/scripts"))
from artifact import validate_artifact
GENERATED_README = "README.generated.md"
AGENTS = ("codex", "claude")

PAYLOAD_DIRS = ("agents", "commands", "evals", "hooks", "licenses")
PAYLOAD_FILES = (".mcp.json",)

SKILL_TREE_IGNORE_PATTERNS = (
    "__pycache__", "*.pyc", ".venv", ".cache", ".data", "forkengine"
)


@dataclass(frozen=True)
class SkillSource:
    package_id: str
    kind: str
    skill_id: str
    path: Path
    source_path: Path | None = None
    dependency: str | None = None


@dataclass(frozen=True)
class Package:
    package_id: str
    path: Path
    display_name: str
    render: dict[str, str]
    skills: tuple[SkillSource, ...]
    default_loaded: bool = True
    payloads: tuple[str, ...] = ()
    version: str = ""


def load_policy(path: Path, names: set[str]) -> dict:
    data = tomllib.loads(path.read_text())["agent_plugins"]
    if set(data) != names:
        raise ValueError(f"policy must explicitly cover every published package: {path}")
    for name, entry in data.items():
        if set(entry) != {"default_loaded", "claude", "codex"} or any(type(v) is not bool for v in entry.values()):
            raise ValueError(f"invalid activation policy for {name}: expected explicit boolean default_loaded, claude, codex")
    return data


def load_published_packages(artifact: Path, policy_path: Path = POLICY_PATH) -> list[Package]:
    validate_artifact(artifact)
    catalog = json.loads((artifact / ".agents/plugins/marketplace.json").read_text())
    if catalog["name"] != "prateek-local":
        raise ValueError("consumer only owns prateek-local")
    policy = load_policy(policy_path, {entry["name"] for entry in catalog["plugins"]})
    packages = []
    for entry in catalog["plugins"]:
        name = entry["name"]
        path = artifact / "plugins" / name
        manifest = json.loads((path / ".codex-plugin/plugin.json").read_text())
        packages.append(Package(name, path, manifest.get("interface", {}).get("displayName", name),
                                {agent: "plugin" if policy[name][agent] else "none" for agent in AGENTS},
                                tuple(SkillSource(name, "local", skill.name, skill) for skill in sorted((path / "skills").iterdir())
                                      if (skill / "SKILL.md").is_file()), policy[name]["default_loaded"],
                                tuple(iter_package_payloads(path)), manifest["version"]))
    return packages


@lru_cache(maxsize=None)
def just_binary() -> str:
    # A mise shim resolves its version from the *caller's* directory, and these
    # commands run inside copies whose mise.toml is untrusted at its temp path.
    resolved = shutil.which("just")
    if resolved and f"{os.sep}shims{os.sep}" in resolved:
        try:
            real = subprocess.run(["mise", "which", "just"], cwd=REPO_ROOT, capture_output=True, text=True)
        except OSError:
            return resolved
        if real.returncode == 0 and real.stdout.strip():
            return real.stdout.strip()
    return resolved or "just"


def marketplace_build_command(project: Path) -> list[str]:
    # A project copy can sit outside any justfile search path, so address it explicitly.
    return [just_binary(), "--justfile", str(project / "justfile"),
            "--working-directory", str(project), "build"]


@lru_cache(maxsize=None)
def ensure_marketplace(project: Path) -> Path:
    result = subprocess.run(marketplace_build_command(project), capture_output=True, text=True, timeout=300)
    if result.returncode:
        raise ValueError(f"marketplace build failed:\n{result.stdout}\n{result.stderr}")
    artifact = project / "build/marketplace"
    validate_artifact(artifact)
    return artifact


def load_packages(packages_root: Path = PACKAGES_ROOT) -> list[Package]:
    artifact = ensure_marketplace(packages_root.parent)
    policy_path = packages_root.parent.parent / "home/.chezmoidata/agent_plugins.toml"
    published = load_published_packages(artifact, policy_path)
    return [Package(p.package_id, packages_root / p.package_id, p.display_name, p.render,
                    tuple(iter_package_skills(packages_root / p.package_id)), p.default_loaded,
                    p.payloads, p.version) for p in published]


def iter_package_payloads(package_path: Path) -> Iterable[str]:
    for kind in PAYLOAD_DIRS:
        if (package_path / kind).is_dir():
            yield kind
    for kind in PAYLOAD_FILES:
        if (package_path / kind).is_file():
            yield kind


def iter_package_skills(package_path: Path) -> Iterable[SkillSource]:
    package_id = package_path.name
    published = package_path.parents[1] / "build/marketplace/plugins" / package_id / "skills"
    selection_path = package_path / "publish.toml"
    selections = tomllib.loads(selection_path.read_text()).get("skills", []) if selection_path.exists() else []
    imports = {item["name"]: item["dependency"] for item in selections}
    for path in sorted(published.iterdir()):
        if (path / "SKILL.md").is_file():
            dependency = imports.get(path.name)
            yield SkillSource(package_id, "vendor" if dependency else "local", path.name, path,
                              selection_path if dependency else package_path / "skills" / path.name, dependency)


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
    frontmatter = lines[1:end]
    data: dict[str, str] = {}
    index = 0
    while index < len(frontmatter):
        line = frontmatter[index]
        index += 1
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if value in {">", ">-", ">+", "|", "|-", "|+"}:
            block_lines: list[str] = []
            while index < len(frontmatter):
                block_line = frontmatter[index]
                if block_line and not block_line.startswith((" ", "\t")):
                    break
                block_lines.append(block_line.strip())
                index += 1
            if value.startswith(">"):
                value = " ".join(part for part in block_lines if part)
            else:
                value = "\n".join(block_lines)
        else:
            value = value.strip('"').strip("'")
        data[key.strip()] = value
    if not data.get("name") or not data.get("description"):
        raise ValueError(f"{skill_md} must define name and description")
    return data


def iter_skill_dirs(root: Path) -> Iterable[Path]:
    if (root / "agent-marketplace").is_dir():
        root = ensure_marketplace(root / "agent-marketplace") / "plugins"
    elif (root / "apm.yml").is_file() and (root / "packages").is_dir():
        root = ensure_marketplace(root) / "plugins"
    elif root.name == "packages" and (root.parent / "apm.yml").is_file():
        root = ensure_marketplace(root.parent) / "plugins"
    for skill_md in sorted(root.rglob("SKILL.md")):
        yield skill_md.parent


def iter_skill_metadata(root: Path) -> Iterable[tuple[Path, dict[str, str]]]:
    for skill_dir in iter_skill_dirs(root):
        yield skill_dir, skill_frontmatter(skill_dir)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def write_generated_readme(path: Path, generator: str, detail: str = "") -> None:
    suffix = f"\n\n{detail.strip()}\n" if detail.strip() else "\n"
    write_text(
        path / GENERATED_README,
        (
            "# Generated Directory\n\n"
            f"Generated by `{generator}`.\n\n"
            "Edit `agent-marketplace/packages/` instead, then rebuild the marketplace."
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
