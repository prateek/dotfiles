#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    tomllib = None


IGNORE_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".venv",
    "venv",
    "node_modules",
    "dist",
    "build",
    "target",
    ".next",
    ".turbo",
    ".cache",
    "__pycache__",
}

MEDIA_EXTS = {
    ".gif",
    ".png",
    ".jpg",
    ".jpeg",
    ".svg",
    ".webp",
    ".mp4",
    ".webm",
    ".mov",
}

DOC_HINTS = (
    "docs/",
    "website/",
    "guide/",
    "guides/",
    "examples/",
    "README",
    "CHANGELOG",
    "CONTRIBUTING",
)


def resolve_repo_root(path_str: str) -> Path:
    path = Path(path_str).resolve()
    if path.is_file():
        path = path.parent

    try:
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return Path(result.stdout.strip())
    except FileNotFoundError:
        pass

    return path


def walk_repo(root: Path, max_files: int = 8000) -> list[str]:
    relpaths: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            name for name in dirnames if name not in IGNORE_DIRS and not name.startswith(".mypy_cache")
        ]
        for filename in filenames:
            path = Path(dirpath, filename)
            relpaths.append(path.relative_to(root).as_posix())
            if len(relpaths) >= max_files:
                return sorted(relpaths)
    return sorted(relpaths)


def safe_read(path: Path, max_chars: int = 12000) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")[:max_chars]
    except OSError:
        return ""


def read_readme(root: Path, files: list[str]) -> tuple[str | None, str, str]:
    for name in ("README.md", "README", "readme.md", "Readme.md"):
        if name in files:
            path = root / name
            text = safe_read(path)
            title = extract_title(text) or path.stem
            summary = extract_summary(text)
            return name, title, summary
    return None, root.name, ""


def extract_title(text: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            return html.unescape(re.sub(r"^#+\s*", "", stripped).strip()).replace("\xa0", " ").strip()
        html_match = re.search(r"<h1[^>]*>(.*?)</h1>", stripped, re.IGNORECASE)
        if html_match:
            inner = re.sub(r"<[^>]+>", "", html_match.group(1))
            return " ".join(html.unescape(inner).replace("\xa0", " ").split()).strip()
    return ""


def extract_summary(text: str) -> str:
    lines = []
    started = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            if started:
                break
            continue
        if line.startswith("#") or line.startswith("[![") or line.startswith("!["):
            continue
        if line.startswith("<!--") or line.startswith("<img ") or line.startswith("<p>"):
            continue
        started = True
        cleaned = html.unescape(re.sub(r"<[^>]+>", "", line)).replace("\xa0", " ").strip()
        if not cleaned:
            continue
        lines.append(cleaned)
        if len(" ".join(lines)) > 240:
            break
    return " ".join(lines).strip()


def detect_manifests(files: list[str]) -> list[str]:
    manifest_names = [
        "Cargo.toml",
        "package.json",
        "pnpm-lock.yaml",
        "pyproject.toml",
        "requirements.txt",
        "go.mod",
        "mkdocs.yml",
        "mkdocs.yaml",
        "docusaurus.config.ts",
        "docusaurus.config.js",
        "astro.config.mjs",
        "astro.config.ts",
        "next.config.js",
        "next.config.mjs",
        "book.toml",
        "Taskfile.yml",
        "Taskfile.yaml",
        "Justfile",
        "Dockerfile",
    ]
    return [name for name in manifest_names if name in files]


def detect_languages(files: list[str]) -> list[str]:
    languages = set()
    if "Cargo.toml" in files:
        languages.add("rust")
    if "go.mod" in files:
        languages.add("go")
    if "pyproject.toml" in files or "requirements.txt" in files:
        languages.add("python")
    if "package.json" in files:
        languages.add("javascript-or-typescript")
    if any(path.endswith(".rs") for path in files):
        languages.add("rust")
    if any(path.endswith(".py") for path in files):
        languages.add("python")
    if any(path.endswith(".go") for path in files):
        languages.add("go")
    if any(path.endswith(".ts") or path.endswith(".tsx") for path in files):
        languages.add("typescript")
    if any(path.endswith(".js") or path.endswith(".jsx") for path in files):
        languages.add("javascript")
    return sorted(languages)


def detect_site_stacks(root: Path, files: list[str]) -> list[str]:
    stacks = set()
    if "docs/config.toml" in files:
        config_text = safe_read(root / "docs/config.toml")
        if "base_url" in config_text or "compile_sass" in config_text:
            stacks.add("zola")
    if "mkdocs.yml" in files or "mkdocs.yaml" in files:
        stacks.add("mkdocs")
    if "docusaurus.config.ts" in files or "docusaurus.config.js" in files:
        stacks.add("docusaurus")
    if "astro.config.mjs" in files or "astro.config.ts" in files:
        stacks.add("astro")
    if "next.config.js" in files or "next.config.mjs" in files:
        stacks.add("nextjs")
    if "book.toml" in files:
        stacks.add("mdbook")
    return sorted(stacks)


def detect_doc_paths(files: list[str], limit: int = 25) -> list[str]:
    candidates = [path for path in files if any(hint in path or path.startswith(hint) for hint in DOC_HINTS)]
    return candidates[:limit]


def detect_media_paths(files: list[str], limit: int = 25) -> list[str]:
    candidates = [path for path in files if Path(path).suffix.lower() in MEDIA_EXTS]
    return candidates[:limit]


def detect_example_paths(files: list[str], limit: int = 25) -> list[str]:
    exampleish = []
    for path in files:
        lower = path.lower()
        if any(part in lower for part in ("examples/", "fixtures/", "demos/", "tapes/", "snapshots/")):
            exampleish.append(path)
    return exampleish[:limit]


def detect_generated_docs_signals(root: Path, files: list[str]) -> list[str]:
    signals = []
    for path in files:
        if not path.endswith((".md", ".rs", ".py", ".go", ".toml")):
            continue
        text = safe_read(root / path, max_chars=4000)
        if "--help-page" in text:
            signals.append(f"{path}: uses CLI help-page generation markers")
        if "AUTO-GENERATED" in text:
            signals.append(f"{path}: contains auto-generated content markers")
        if len(signals) >= 12:
            break
    return signals


def detect_surface_signals(root: Path, files: list[str], readme_text: str) -> dict[str, list[str]]:
    signals = {
        "cli": [],
        "browser_ui": [],
        "config": [],
        "automation": [],
    }

    lowered_readme = readme_text.lower()
    if " cli " in f" {lowered_readme} " or "command line" in lowered_readme:
        signals["cli"].append("README describes the product as a CLI or command-line tool")
    if "terminal" in lowered_readme:
        signals["cli"].append("README references terminal usage")
    if "screenshot" in lowered_readme or "dashboard" in lowered_readme or "browser" in lowered_readme:
        signals["browser_ui"].append("README references a browser or visual UI")
    if "config" in lowered_readme or "toml" in lowered_readme or "yaml" in lowered_readme:
        signals["config"].append("README references configuration files or settings")

    if "Cargo.toml" in files and tomllib is not None:
        cargo_text = safe_read(root / "Cargo.toml")
        try:
            cargo_data = tomllib.loads(cargo_text)
            if "bin" in cargo_data or (root / "src/main.rs").exists():
                signals["cli"].append("Cargo project exposes a binary entry point")
        except tomllib.TOMLDecodeError:
            pass

    if "package.json" in files:
        try:
            package_data = json.loads(safe_read(root / "package.json"))
            if package_data.get("bin"):
                signals["cli"].append("package.json declares CLI bin entries")
            scripts = package_data.get("scripts", {})
            if any(key in scripts for key in ("dev", "start", "build")):
                signals["browser_ui"].append("package.json has dev/build scripts that may back a web UI")
        except json.JSONDecodeError:
            pass

    if "go.mod" in files and any(path.endswith("main.go") for path in files):
        signals["cli"].append("Go module contains main.go entry points")

    if any(path.endswith((".toml", ".yaml", ".yml", ".json")) for path in files):
        signals["config"].append("Repository contains explicit config file surfaces")

    if any("demos/" in path or "tapes/" in path or "snapshots/" in path for path in files):
        signals["automation"].append("Repository contains demo or snapshot automation assets")
    if any(path.endswith(".tape") for path in files):
        signals["automation"].append("Repository contains VHS tape sources")
    if any(path.endswith((".github/workflows", "ci.yaml", "ci.yml")) for path in files):
        signals["automation"].append("Repository contains CI workflow definitions")

    return {key: value for key, value in signals.items() if value}


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan a repository for site-generation signals.")
    parser.add_argument("repo", nargs="?", default=".", help="Path to the target repository")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    args = parser.parse_args()

    repo_root = resolve_repo_root(args.repo)
    files = walk_repo(repo_root)
    readme_path, readme_title, readme_summary = read_readme(repo_root, files)
    readme_text = safe_read(repo_root / readme_path) if readme_path else ""

    inventory = {
        "repo_root": str(repo_root),
        "repo_name": repo_root.name,
        "readme_path": readme_path,
        "readme_title": readme_title,
        "readme_summary": readme_summary,
        "manifests": detect_manifests(files),
        "languages": detect_languages(files),
        "site_stacks": detect_site_stacks(repo_root, files),
        "doc_paths": detect_doc_paths(files),
        "example_paths": detect_example_paths(files),
        "media_paths": detect_media_paths(files),
        "generated_docs_signals": detect_generated_docs_signals(repo_root, files),
        "surface_signals": detect_surface_signals(repo_root, files, readme_text),
    }

    json.dump(inventory, sys.stdout, indent=2 if args.pretty else None, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
