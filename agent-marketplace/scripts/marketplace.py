from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import tempfile
import tarfile
import tomllib
import yaml

from apm_cli.deps.lockfile import LockFile
from apm_cli.install.cache_pin import CachePinError, verify_marker
from apm_cli.models.dependency.materialization import build_materialization_path
from apm_cli.models.apm_package import APMPackage
from apm_cli.security.content_scanner import ContentScanner
from apm_cli.utils.content_hash import compute_package_hash

from artifact import RECEIPT, contained, digest, source_files, tree_files, validate_artifact


def run_apm(arguments: list[str], cwd: Path, *, timeout: int = 120) -> None:
    process = subprocess.Popen(["apm", *arguments], cwd=cwd, env=git_env(), start_new_session=True)
    try:
        status = process.wait(timeout=timeout)
    except BaseException:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=2)
        raise
    if status:
        raise subprocess.CalledProcessError(status, process.args)


def git_env() -> dict[str, str]:
    environment = dict(os.environ)
    for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
        environment.pop(key, None)
    return environment


def validate_cache_modes(root: Path) -> None:
    tracked = subprocess.run(["git", "ls-files", "--stage", "-z", "--", "packages"],
                             cwd=root, env=git_env(), capture_output=True, timeout=30)
    if tracked.returncode:
        return  # A standalone source export carries the modes from its trusted archive.
    for entry in tracked.stdout.split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        relative = os.fsdecode(name)
        if "/apm_modules/" not in relative:
            continue
        mode, _, stage = metadata.split()
        path = contained(root, relative)
        if mode not in (b"100644", b"100755") or stage != b"0":
            raise ValueError(f"cache must be ordinary resolved Git content: {path}")
        if path.is_file() and bool(path.stat().st_mode & 0o111) != (mode == b"100755"):
            raise ValueError(f"cache executable mode differs from Git: {path}; restore from Git or review and stage the mode change")


def package_inputs(package: Path) -> dict[str, Path]:
    manifest = APMPackage.from_apm_yml(package / "apm.yml", create_config=False)
    declared = {dep.get_unique_key() for dep in manifest.get_all_apm_dependencies()}
    lock_path = package / "apm.lock.yaml"
    if not lock_path.exists():
        if declared:
            raise ValueError(f"missing cache lock: {lock_path}; restore committed files from Git or a complete source export; use fetch only for new, unacquired declarations")
        return {}
    lock = LockFile.read(lock_path)
    if lock is None:
        raise ValueError(f"invalid lock: {lock_path}")
    locked = {dep.get_unique_key(): dep for dep in lock.get_all_dependencies()}
    direct = {key for key, dep in locked.items() if dep.depth == 1}
    if declared != direct:
        raise ValueError(f"declarations and lock differ in {package}; run fetch after reviewing acquisition inputs")
    data = yaml.safe_load(lock_path.read_text())
    if data.get("deployments") or any(dep.get("deployed_files") for dep in data.get("dependencies", [])):
        raise ValueError(f"acquisition lock contains deployment claims: {lock_path}")
    modules = {}
    for key, dependency in locked.items():
        module = build_materialization_path(dependency.to_dependency_ref(), package / "apm_modules")
        contained(package, str(module.relative_to(package)))
        if not module.is_dir():
            raise ValueError(f"missing cache: {module}; restore committed files from Git or a complete source export")
        tree_files(module, skip={"**/__pycache__"})
        if any(path.name == ".git" for path in module.rglob("*")):
            raise ValueError(f"cache must not contain Git repositories: {module}")
        if not dependency.content_hash or compute_package_hash(module) != dependency.content_hash:
            raise ValueError(f"cache does not match accepted lock: {module}; restore committed files from Git or a complete source export")
        try:
            verify_marker(module, dependency.resolved_commit)
        except CachePinError as error:
            raise ValueError(f"invalid cache receipt: {module}; restore committed files from Git or a complete source export") from error
        validate_source_surface(module)
        modules[key] = module
    return modules


def validate_source_surface(module: Path) -> None:
    unsupported = {"mcp", "mcpServers", "servers", "lsp", "monitors", "commands", "prompts"}
    for path in module.rglob("*"):
        if not path.is_dir() or path.name not in unsupported:
            continue
        if path.parent != module and path.parent.name != ".apm":
            continue
        current = path
        while current != module.parent:
            if (current / "SKILL.md").is_file():
                break
            current = current.parent
        else:
            raise ValueError(f"unsupported APM component: {path}")


def selected_inputs(package: Path):
    modules = package_inputs(package)
    selection = package / "publish.toml"
    if not selection.exists():
        return
    data = tomllib.loads(selection.read_text())
    inputs = [(f"skills/{item['name']}", item) for item in data.get("skills", [])]
    inputs.extend((item["target"], item) for item in data.get("payloads", []))
    for target, item in inputs:
        if item["dependency"] not in modules:
            raise ValueError(f"selection has no locked declaration: {item['dependency']}")
        contained(package, target)
        if target.split("/")[0] not in {"skills", "hooks", "evals", "agents", "commands", "licenses", ".mcp.json"}:
            raise ValueError(f"unsupported publication target: {target}")
        for name in item.get("exclude", []):
            if len(Path(name).parts) != 1 or name in {".", ".."}:
                raise ValueError(f"unsafe path in exclude: {name}")
        yield target, contained(modules[item["dependency"]], item["path"]), item.get("exclude", [])


def copy_selection(source: Path, target: Path, excluded: list[str]) -> None:
    if target.exists():
        raise ValueError(f"publication collision: {target}")
    if source.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        return
    ignored = shutil.ignore_patterns(".apm-pin", "__pycache__", "*.pyc", ".git")
    def ignore(directory, names):
        result = set(ignored(directory, names))
        if Path(directory) == source:
            result.update(set(names) & set(excluded))
        return result
    shutil.copytree(source, target, symlinks=True, ignore=ignore)


def apply_patches(package: Path, plugin: Path) -> None:
    patches = sorted(path for path in (package / "patches").glob("*.patch") if path.read_bytes().strip())
    if not patches:
        return
    environment = git_env()
    subprocess.run(["git", "init", "-q", str(plugin)], env=environment, check=True, timeout=30)
    try:
        for patch in patches:
            subprocess.run(["git", "apply", "--check", str(patch)], cwd=plugin, env=environment, check=True, timeout=30)
            subprocess.run(["git", "apply", "--whitespace=nowarn", str(patch)], cwd=plugin, env=environment, check=True, timeout=30)
    finally:
        shutil.rmtree(plugin / ".git")


def scan_content(plugin: Path) -> None:
    findings = []
    for path in sorted(plugin.rglob("*")):
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        findings.extend(f for f in ContentScanner.scan_text(content, str(path.relative_to(plugin)))
                        if f.severity == "critical")
    if findings:
        detail = "; ".join(f"{f.file}:{f.line}: {f.codepoint} {f.category}" for f in findings)
        raise ValueError(f"content scan rejected {plugin.name}: {detail}")


def validate_plugin(plugin: Path, expected_skills: set[str]) -> None:
    manifest = yaml.safe_load((plugin / "apm.yml").read_text())
    codex = json.loads((plugin / ".codex-plugin/plugin.json").read_text())
    if manifest.get("name") != plugin.name or codex.get("name") != plugin.name:
        raise ValueError(f"native names must match package id: {plugin}")
    if not manifest.get("version") or codex.get("version") != manifest["version"]:
        raise ValueError(f"native version mismatch: {plugin}")
    if "dependencies" in manifest or manifest.get("targets") != ["claude"]:
        raise ValueError(f"native source publication requires targets [claude] and no dependencies field: {plugin}")
    hooks = plugin / "hooks"
    if hooks.exists():
        if not (hooks / "hooks.json").is_file():
            raise ValueError(f"hooks payload is missing hooks.json: {hooks}")
        if not isinstance(json.loads((hooks / "hooks.json").read_text()).get("hooks"), dict):
            raise ValueError(f"hooks.json requires a hooks object: {hooks}")
        if codex.get("hooks") != {}:
            raise ValueError(f"Codex skills-only policy requires hooks: {{}}: {plugin}")
    skills = plugin / "skills"
    if skills.exists():
        if not skills.is_dir():
            raise ValueError(f"skills must be a directory of skill roots with SKILL.md: {skills}")
        expected_skills = expected_skills | {skill.name for skill in skills.iterdir()}
    for name in expected_skills:
        skill = skills / name
        if not skill.is_dir() or not (skill / "SKILL.md").is_file():
            raise ValueError(f"skill root must be a directory containing SKILL.md: {skill}")
    names = set()
    for path in skills.rglob("SKILL.md"):
        parts = path.read_text().split("---", 2)
        if len(parts) != 3 or parts[0].strip():
            raise ValueError(f"missing skill frontmatter: {path}")
        meta = yaml.safe_load(parts[1])
        if not isinstance(meta, dict) or not meta.get("name") or not meta.get("description"):
            raise ValueError(f"skill requires name and description: {path}")
        if len(meta["description"]) > 1024:
            raise ValueError(f"description exceeds 1024 chars: {path}")
        if meta["name"] in names:
            raise ValueError(f"ambiguous skill name: {path}")
        names.add(meta["name"])
        sidecar = path.parent / "agents/openai.yaml"
        policy = yaml.safe_load(sidecar.read_text()) if sidecar.exists() else {}
        denied = policy.get("policy", {}).get("allow_implicit_invocation") is False
        if (meta.get("disable-model-invocation") is True) != denied:
            raise ValueError(f"pair disable-model-invocation with policy.allow_implicit_invocation: false: {path}")


def apply_overlays(package: Path, plugin: Path) -> None:
    overlay = package / "overlays"
    if not overlay.exists():
        return
    for relative in tree_files(overlay, skip={"**/__pycache__"}):
        target = contained(plugin, relative)
        if target.exists():
            raise ValueError(f"overlay collision; use a patch for replacements: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(overlay / relative, target)


def build(root: Path) -> Path:
    before = source_files(root)
    validate_cache_modes(root)
    build_root = root / "build"
    if build_root.is_symlink():
        raise ValueError(f"symlink build directory: {build_root}")
    build_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="assemble-", dir=build_root) as staging:
        output = Path(staging) / "marketplace"
        output.mkdir()
        shutil.copy2(root / "apm.yml", output / "apm.yml")
        for package in sorted((root / "packages").iterdir()):
            plugin = output / "plugins" / package.name
            plugin.mkdir(parents=True)
            for name in ("apm.yml", "skills", ".codex-plugin", "hooks", "evals", "agents", "commands", "licenses", ".mcp.json"):
                source = package / name
                if source.is_dir():
                    shutil.copytree(source, plugin / name, symlinks=True,
                                    ignore=shutil.ignore_patterns("__pycache__"))
                elif source.is_file():
                    shutil.copy2(source, plugin / name)
            for target, source, excluded in selected_inputs(package):
                copy_selection(source, plugin / target, excluded)
            skills = plugin / "skills"
            expected_skills = {skill.name for skill in skills.iterdir()} if skills.is_dir() else set()
            apply_patches(package, plugin)
            apply_overlays(package, plugin)
            tree_files(plugin)
            validate_plugin(plugin, expected_skills)
            scan_content(plugin)
            run_apm(["pack", "--offline", "--force"], plugin)
        run_apm(["pack", "--offline"], output)
        if before != source_files(root):
            raise ValueError("source changed during build; retry with stable inputs")
        revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, env=git_env(), text=True, capture_output=True, timeout=30)
        status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all", "--", "."],
                                cwd=root, env=git_env(), text=True, capture_output=True, timeout=30)
        receipt = {"schema": 1, "apm_version": "0.29.1", "source_digest": digest(before),
                   "revision": revision.stdout.strip() if revision.returncode == 0 else None,
                   "dirty": bool(status.stdout) if status.returncode == 0 else None,
                   "files": tree_files(output), "checked": False}
        (output / RECEIPT).write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        validate_artifact(output)
        target = build_root / "marketplace"
        previous = Path(staging) / "previous"
        if target.exists():
            target.rename(previous)
        try:
            output.rename(target)
        except OSError:
            if previous.exists():
                previous.rename(target)
            raise
    return target


def acquire(root: Path, package_id: str | None, update: bool) -> None:
    if not package_id or not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", package_id):
        raise ValueError("PACKAGE must name one package")
    package = contained(root, f"packages/{package_id}")
    if not (package / "apm.yml").is_file():
        raise ValueError(f"unknown package: {package_id}")
    environment = git_env()
    tree_files(package)
    status = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all", "--ignored=matching",
         "--", str(package / "apm.lock.yaml"), str(package / "apm_modules")],
        cwd=root, env=environment, capture_output=True, text=True, timeout=30,
    )
    if status.returncode:
        raise ValueError("fetch/update require a Git checkout for acquisition review")
    if status.stdout:
        raise ValueError(f"{package_id}: unaccepted cache or lock changes; review or restore them before acquisition")
    run_apm(["lock"] + (["--update"] if update else []), package, timeout=300)


def check(root: Path) -> None:
    first = validate_artifact(build(root))
    output = build(root)
    second = validate_artifact(output)
    if first != second:
        raise ValueError("offline builds differ")
    second["checked"] = True
    (output / RECEIPT).write_text(json.dumps(second, indent=2, sort_keys=True) + "\n")


def export(root: Path) -> None:
    output = root / "build/marketplace"
    receipt = validate_artifact(output)
    if not receipt.get("checked"):
        raise ValueError("run make check before export")
    if receipt["source_digest"] != digest(source_files(root)):
        raise ValueError("stale build; run make check before export")
    target = root / "build/marketplace.tar.gz"
    with tarfile.open(target, "w:gz") as archive:
        archive.add(output, arcname="marketplace")
    print(target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["build", "check", "export", "clean", "fetch", "update"])
    parser.add_argument("--package")
    args = parser.parse_args()
    try:
        if args.command == "build":
            print(build(Path.cwd()))
        elif args.command == "check":
            check(Path.cwd())
        elif args.command == "export":
            export(Path.cwd())
        elif args.command == "clean":
            output = contained(Path.cwd(), "build")
            if output.exists():
                shutil.rmtree(output)
        else:
            acquire(Path.cwd(), args.package, args.command == "update")
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"marketplace: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
