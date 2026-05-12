# ABOUTME: Coordinates worktree-local Tuist, Xcode, Fastlane, and simulator execution for __APP_NAME__.
# ABOUTME: Owns worktree locks, repo-local build artifacts, deterministic simulator reuse, and cleanup commands.

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from urllib import error as urllib_error
from urllib import request as urllib_request
import uuid


WRAPPER_NAMES = {"make", "gmake", "python", "python3", "ruby", "env", "sh", "bash", "zsh"}
SHELL_NAMES = {"bash", "zsh", "fish", "sh"}
AGENT_HINTS = ("codex", "claude")
SIMULATOR_PREFIX = "__APP_SLUG__-"
TAG_KEY_PATTERN = re.compile(r"^[^:]+:(?P<key>[^:]+):(?P<value>.+)$")


class WorktreeError(RuntimeError):
    pass


@dataclass(frozen=True)
class Runtime:
    identifier: str
    version: str


@dataclass(frozen=True)
class DeviceType:
    name: str
    identifier: str


@dataclass(frozen=True)
class RuntimeClass:
    name: str
    policy: str
    preferred_identifiers: tuple[str, ...]


@dataclass(frozen=True)
class Owner:
    pid: int
    start_time: str
    command: str
    uid: int
    owner_id: str

    def to_metadata(self) -> dict[str, object]:
        return {
            "owner_pid": self.pid,
            "owner_process_start_time": self.start_time,
            "owner_command": self.command,
            "owner_uid": self.uid,
            "owner_id": self.owner_id,
            "updated_at": now_utc(),
        }


@dataclass(frozen=True)
class AppTarget:
    target_name: str
    scheme_name: str
    runtime_class: str


@dataclass(frozen=True)
class SuiteTarget:
    target_name: str
    scheme_name: str
    kind: str
    device_support: str
    data_mode: str
    runtime_class: str


@dataclass(frozen=True)
class Task:
    task_id: str
    action: str
    device_family: str | None = None
    suite_kind: str | None = None
    scheme_name: str | None = None
    target_name: str | None = None
    data_mode: str | None = None
    runtime_class: str | None = None
    record_snapshots: bool = False


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def repo_root() -> Path:
    return Path(
        subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True,
        ).strip()
    )


def sanitize_component(value: str) -> str:
    lowered = value.lower()
    replaced = re.sub(r"[^a-z0-9]+", "-", lowered)
    return replaced.strip("-") or "worktree"


def worktree_hash(path: str | Path) -> str:
    normalized = str(Path(path).resolve())
    return hashlib.sha1(normalized.encode("utf-8")).hexdigest()[:10]


def simulator_name(repo_root: str | Path, family: str) -> str:
    root = Path(repo_root).resolve()
    return f"{SIMULATOR_PREFIX}{sanitize_component(root.name)}-{worktree_hash(root)}-{family}"


def unique_temp_path(stable_path: Path) -> Path:
    return stable_path.with_name(f".{stable_path.name}.{uuid.uuid4().hex}.tmp")


def simulator_marker_path(device_dir: Path) -> Path:
    return device_dir / "__APP_SLUG__-worktree.json"


def run(command: list[str], *, env: dict[str, str] | None = None, capture_output: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=False,
        text=True,
        capture_output=capture_output,
        env=env,
    )


def checked(command: list[str], *, env: dict[str, str] | None = None) -> str:
    completed = run(command, env=env)
    if completed.returncode != 0:
        raise WorktreeError(
            f"Command failed ({completed.returncode}): {' '.join(command)}\n{completed.stderr.strip()}"
        )
    return completed.stdout


def process_info(pid: int) -> tuple[int | None, str | None, str | None]:
    meta = run(["ps", "-p", str(pid), "-o", "ppid=", "-o", "lstart="])
    command = run(["ps", "-p", str(pid), "-o", "command="])
    if (
        meta.returncode != 0
        or command.returncode != 0
        or not meta.stdout.strip()
        or not command.stdout.strip()
    ):
        return None, None, None
    meta_parts = meta.stdout.strip().split()
    if len(meta_parts) < 6:
        return None, None, None
    parent = int(meta_parts[0])
    start = " ".join(meta_parts[1:6])
    normalized_command = " ".join(command.stdout.split())
    return parent, start, normalized_command


def process_start_time(pid: int) -> str | None:
    _, start, _ = process_info(pid)
    return start


def is_process_alive(pid: int, expected_start_time: str) -> bool:
    actual = process_start_time(pid)
    return actual == expected_start_time


def current_operation_metadata(owner: Owner) -> dict[str, object]:
    pid = os.getpid()
    start_time = process_start_time(pid) or now_utc()
    return {
        "operation_pid": pid,
        "operation_process_start_time": start_time,
        "operation_command": " ".join(sys.argv),
        "owner_id": owner.owner_id,
        "updated_at": now_utc(),
    }


def detect_owner() -> Owner:
    explicit_owner = os.environ.get("IOS_WORKTREE_OWNER_ID")
    current_pid = os.getpid()
    parent_pid, _, _ = process_info(current_pid)
    pid = parent_pid or current_pid

    ancestry: list[tuple[int, str, str]] = []
    seen: set[int] = set()
    while pid and pid not in seen and pid > 1:
        seen.add(pid)
        parent, start, command = process_info(pid)
        if start is None or command is None:
            break
        ancestry.append((pid, start, command))
        pid = parent or 0

    def command_basename(command: str) -> str:
        return Path(command.split()[0]).name

    for candidate_pid, start, command in ancestry:
        base = command_basename(command).lower()
        if any(hint in base for hint in AGENT_HINTS):
            owner_id = explicit_owner or f"{candidate_pid}-{hashlib.sha1(start.encode('utf-8')).hexdigest()[:8]}"
            return Owner(candidate_pid, start, command, os.getuid(), owner_id)

    for candidate_pid, start, command in ancestry:
        base = command_basename(command).lower()
        if base in SHELL_NAMES:
            owner_id = explicit_owner or f"{candidate_pid}-{hashlib.sha1(start.encode('utf-8')).hexdigest()[:8]}"
            return Owner(candidate_pid, start, command, os.getuid(), owner_id)

    for candidate_pid, start, command in ancestry:
        base = command_basename(command).lower()
        if base not in WRAPPER_NAMES:
            owner_id = explicit_owner or f"{candidate_pid}-{hashlib.sha1(start.encode('utf-8')).hexdigest()[:8]}"
            return Owner(candidate_pid, start, command, os.getuid(), owner_id)

    start = process_start_time(current_pid) or now_utc()
    owner_id = explicit_owner or f"{current_pid}-{hashlib.sha1(start.encode('utf-8')).hexdigest()[:8]}"
    return Owner(current_pid, start, "python3", os.getuid(), owner_id)


class LockDirectory:
    def __init__(self, path: Path, metadata_path: Path):
        self.path = path
        self.metadata_path = metadata_path
        self.reap_root = self.path.parent / "reap"

    def read_metadata(self) -> dict[str, object]:
        if not self.metadata_path.exists():
            return {}
        try:
            return json.loads(self.metadata_path.read_text())
        except json.JSONDecodeError:
            return {}

    def write_metadata(self, payload: dict[str, object]) -> None:
        self.path.mkdir(parents=True, exist_ok=True)
        temp_path = self.metadata_path.with_name(f".{self.metadata_path.name}.{os.getpid()}.tmp")
        temp_path.write_text(json.dumps(payload, indent=2, sort_keys=True))
        os.replace(temp_path, self.metadata_path)

    def has_pending_metadata(self, grace_period_seconds: float = 1.0) -> bool:
        if self.metadata_path.exists():
            return False
        try:
            created_at = self.path.stat().st_mtime
        except FileNotFoundError:
            return False
        return (time.time() - created_at) < grace_period_seconds

    def same_owner(self, owner: Owner) -> bool:
        metadata = self.read_metadata()
        return metadata.get("owner_id") == owner.owner_id

    def is_stale(self) -> bool:
        metadata = self.read_metadata()
        pid = metadata.get("operation_pid", metadata.get("owner_pid"))
        start_time = metadata.get("operation_process_start_time", metadata.get("owner_process_start_time"))
        if not isinstance(pid, int) or not isinstance(start_time, str):
            return True
        return not is_process_alive(pid, start_time)

    def acquire_owner(self, owner: Owner) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        while True:
            try:
                self.path.mkdir()
                self.write_metadata(owner.to_metadata())
                return
            except FileExistsError:
                if self.has_pending_metadata():
                    time.sleep(0.05)
                    continue
                metadata = self.read_metadata()
                if metadata.get("owner_id") == owner.owner_id and is_process_alive(owner.pid, owner.start_time):
                    self.write_metadata(owner.to_metadata())
                    return
                if self.is_stale():
                    self.reap_stale(owner.owner_id)
                    continue
                owner_pid = metadata.get("owner_pid")
                owner_command = metadata.get("owner_command")
                raise WorktreeError(
                    f"Worktree is owned by {owner_command} (pid {owner_pid}). "
                    f"Use a separate worktree or run make release-owner if the lock is stale."
                )

    def acquire_build(self, owner: Owner) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        operation = current_operation_metadata(owner)
        while True:
            try:
                self.path.mkdir()
                self.write_metadata(operation)
                return
            except FileExistsError:
                if self.has_pending_metadata():
                    time.sleep(0.05)
                    continue
                if self.is_stale():
                    self.reap_stale(owner.owner_id)
                    continue
                metadata = self.read_metadata()
                operation_pid = metadata.get("operation_pid")
                operation_command = metadata.get("operation_command")
                raise WorktreeError(
                    f"Build lock is held by {operation_command} (pid {operation_pid}). Wait for the current Xcode/Tuist/Fastlane operation to finish."
                )

    def reap_stale(self, candidate_id: str) -> None:
        self.reap_root.mkdir(parents=True, exist_ok=True)
        candidate_path = self.reap_root / f"{self.path.name}.{candidate_id}.lock"
        if candidate_path.exists():
            shutil.rmtree(candidate_path)
        try:
            os.replace(self.path, candidate_path)
        except FileNotFoundError:
            return
        except OSError:
            return
        shutil.rmtree(candidate_path, ignore_errors=True)

    def release_if_owner(self, owner: Owner) -> None:
        if not self.path.exists():
            return
        metadata = self.read_metadata()
        if metadata.get("owner_id") != owner.owner_id:
            raise WorktreeError("Refusing to release a lock held by a different live owner.")
        shutil.rmtree(self.path, ignore_errors=True)

    def release_if_stale(self, owner: Owner) -> None:
        if not self.path.exists():
            return
        metadata = self.read_metadata()
        if metadata.get("owner_id") == owner.owner_id:
            shutil.rmtree(self.path, ignore_errors=True)
            return
        if self.is_stale():
            self.reap_stale(owner.owner_id)
            return
        raise WorktreeError("Refusing to release a lock held by a different live owner.")


def load_config(root: Path) -> dict[str, object]:
    config_path = root / "TestPlans" / "__APP_NAME__.simprofile.toml"
    return tomllib.loads(config_path.read_text())


def device_config(config: dict[str, object], family: str) -> dict[str, object]:
    devices = config.get("devices", {})
    if not isinstance(devices, dict) or family not in devices:
        raise WorktreeError(f"Unknown device family: {family}")
    value = devices[family]
    if not isinstance(value, dict):
        raise WorktreeError(f"Invalid device config for {family}")
    resolved = dict(value)
    if "type_identifiers" not in resolved and "type_identifier" in resolved:
        resolved["type_identifiers"] = [resolved["type_identifier"]]
    if not isinstance(resolved.get("type_identifiers"), list) or not resolved["type_identifiers"]:
        raise WorktreeError(f"Device config for {family} must declare at least one type identifier")
    return resolved


def runtime_class_config(config: dict[str, object], runtime_class_name: str) -> RuntimeClass:
    runtime_classes = config.get("runtime_classes", {})
    if not isinstance(runtime_classes, dict) or runtime_class_name not in runtime_classes:
        runtime_classes = config.get("runtimes", {})
    if not isinstance(runtime_classes, dict) or runtime_class_name not in runtime_classes:
        raise WorktreeError(f"Unknown runtime class: {runtime_class_name}")
    payload = runtime_classes[runtime_class_name]
    if not isinstance(payload, dict):
        raise WorktreeError(f"Invalid runtime class config for {runtime_class_name}")
    preferred_identifiers = payload.get("preferred_identifiers")
    if preferred_identifiers is None and isinstance(payload.get("preferred_identifier"), str):
        preferred_identifiers = [payload["preferred_identifier"]]
    if not isinstance(preferred_identifiers, list) or not all(isinstance(item, str) for item in preferred_identifiers):
        raise WorktreeError(f"Runtime class {runtime_class_name} must define preferred identifiers as strings")
    policy = payload.get("policy")
    if not isinstance(policy, str):
        policy = payload.get("runtime_policy")
    if not isinstance(policy, str):
        raise WorktreeError(f"Runtime class {runtime_class_name} must define a policy")
    return RuntimeClass(
        name=runtime_class_name,
        policy=policy,
        preferred_identifiers=tuple(preferred_identifiers),
    )


def load_project_dump(root: Path) -> dict[str, object]:
    completed = run(["tuist", "dump", "project"], capture_output=True)
    if completed.returncode != 0:
        raise WorktreeError(f"Failed to inspect Tuist project:\n{completed.stderr.strip()}")
    try:
        payload = completed.stdout
        start = payload.find("{")
        if start == -1:
            raise json.JSONDecodeError("No JSON object found in tuist dump output", payload, 0)
        decoded, _ = json.JSONDecoder().raw_decode(payload[start:])
        if not isinstance(decoded, dict):
            raise WorktreeError("`tuist dump project` did not return a JSON object")
        return decoded
    except json.JSONDecodeError as error:
        raise WorktreeError(f"Failed to parse `tuist dump project` output: {error}") from error


def tag_value(tags: list[str], key: str) -> str | None:
    for tag in tags:
        match = TAG_KEY_PATTERN.match(tag)
        if match and match.group("key") == key:
            return match.group("value")
    return None


def scheme_names(project_dump: dict[str, object]) -> set[str]:
    value = project_dump.get("schemes", [])
    if not isinstance(value, list):
        return set()
    names: set[str] = set()
    for entry in value:
        if isinstance(entry, dict):
            name = entry.get("name")
            if isinstance(name, str):
                names.add(name)
    return names


def suite_kind_for_target(name: str, product: str) -> str | None:
    if product == "app" and name == "__APP_NAME__":
        return "app"
    if name.endswith("VisualFidelityTests"):
        return "visual"
    if name.endswith("SnapshotTests"):
        return "snapshot"
    if name.endswith("UITests"):
        return "ui"
    if name.endswith("Tests"):
        return "unit"
    return None


def catalog_project_topology(project_dump: dict[str, object]) -> dict[str, dict[str, str]]:
    app_target = discover_app_target(project_dump)
    suites = discover_suites(project_dump)
    payload = {
        "app": {
            "target": app_target.target_name,
            "scheme": app_target.scheme_name,
            "runtime_class": app_target.runtime_class,
        }
    }
    for kind, suite in suites.items():
        payload[kind] = {
            "target": suite.target_name,
            "scheme": suite.scheme_name,
            "runtime_class": suite.runtime_class,
            "device_support": suite.device_support,
            "data_mode": suite.data_mode,
        }
    return payload


def discover_app_target(project_dump: dict[str, object]) -> AppTarget:
    available_schemes = scheme_names(project_dump)
    targets = project_dump.get("targets", [])
    if not isinstance(targets, list):
        raise WorktreeError("Tuist project dump does not include targets")
    for target in targets:
        if not isinstance(target, dict):
            continue
        name = target.get("name")
        product = target.get("product")
        if not isinstance(name, str) or not isinstance(product, str):
            continue
        metadata = target.get("metadata", {})
        tags = metadata.get("tags", []) if isinstance(metadata, dict) else []
        string_tags = [tag for tag in tags if isinstance(tag, str)]
        role = tag_value(string_tags, "role")
        runtime_class_name = tag_value(string_tags, "runtime-class")
        if role is None and suite_kind_for_target(name, product) == "app":
            role = "app"
        if role != "app":
            continue
        scheme_name = name if name in available_schemes else name
        return AppTarget(
            target_name=name,
            scheme_name=scheme_name,
            runtime_class=runtime_class_name or "flexible",
        )
    raise WorktreeError("Could not discover the __APP_NAME__ app target from Tuist metadata")


def discover_suites(project_dump: dict[str, object]) -> dict[str, SuiteTarget]:
    available_schemes = scheme_names(project_dump)
    targets = project_dump.get("targets", [])
    if not isinstance(targets, list):
        raise WorktreeError("Tuist project dump does not include targets")
    suites: dict[str, SuiteTarget] = {}
    for target in targets:
        if not isinstance(target, dict):
            continue
        name = target.get("name")
        product = target.get("product")
        if not isinstance(name, str) or not isinstance(product, str):
            continue
        metadata = target.get("metadata", {})
        tags = metadata.get("tags", []) if isinstance(metadata, dict) else []
        string_tags = [tag for tag in tags if isinstance(tag, str)]
        role = tag_value(string_tags, "role")
        kind = tag_value(string_tags, "suite")
        device_support = tag_value(string_tags, "device-support")
        data_mode = tag_value(string_tags, "data-mode")
        runtime_class_name = tag_value(string_tags, "runtime-class")
        if role is None:
            inferred_kind = suite_kind_for_target(name, product)
            if inferred_kind in {None, "app"}:
                continue
            role = "suite"
            kind = inferred_kind
            device_support = device_support or "both"
            data_mode = data_mode or ("audit" if inferred_kind == "visual" else "deterministic")
            runtime_class_name = runtime_class_name or ("exact" if inferred_kind in {"snapshot", "visual"} else "flexible")
        if role != "suite" or not isinstance(kind, str):
            continue
        scheme_name = name if name in available_schemes else name
        suites[kind] = SuiteTarget(
            target_name=name,
            scheme_name=scheme_name,
            kind=kind,
            device_support=device_support or "both",
            data_mode=data_mode or "deterministic",
            runtime_class=runtime_class_name or "flexible",
        )
    if not suites:
        raise WorktreeError("Could not discover any __APP_NAME__ test suites from Tuist metadata")
    return suites


def parse_task(task_id: str, project_dump: dict[str, object]) -> Task:
    if task_id == "generate":
        return Task(task_id=task_id, action="generate")
    if task_id == "archive":
        app_target = discover_app_target(project_dump)
        return Task(
            task_id=task_id,
            action="archive",
            scheme_name=app_target.scheme_name,
            target_name=app_target.target_name,
            data_mode="live",
            runtime_class=app_target.runtime_class,
        )

    direct_actions = ("build", "run", "screenshot")
    for action in direct_actions:
        match = re.fullmatch(rf"{action}-(iphone|ipad)", task_id)
        if match:
            app_target = discover_app_target(project_dump)
            family = match.group(1)
            return Task(
                task_id=task_id,
                action=action,
                device_family=family,
                scheme_name=app_target.scheme_name,
                target_name=app_target.target_name,
                data_mode="live",
                runtime_class=app_target.runtime_class,
            )

    match = re.fullmatch(r"test-(unit|ui|snapshot|visual)-(iphone|ipad)", task_id)
    if match:
        suites = discover_suites(project_dump)
        suite_kind, family = match.groups()
        suite = suites.get(suite_kind)
        if suite is None:
            raise WorktreeError(f"Tuist metadata does not define a suite for kind `{suite_kind}`")
        return Task(
            task_id=task_id,
            action="test",
            device_family=family,
            suite_kind=suite_kind,
            scheme_name=suite.scheme_name,
            target_name=suite.target_name,
            data_mode=suite.data_mode,
            runtime_class=suite.runtime_class,
        )

    match = re.fullmatch(r"record-snapshots-(iphone|ipad)", task_id)
    if match:
        suites = discover_suites(project_dump)
        family = match.group(1)
        suite = suites.get("snapshot")
        if suite is None:
            raise WorktreeError("Tuist metadata does not define the snapshot suite")
        return Task(
            task_id=task_id,
            action="record",
            device_family=family,
            suite_kind="snapshot",
            scheme_name=suite.scheme_name,
            target_name=suite.target_name,
            data_mode=suite.data_mode,
            runtime_class=suite.runtime_class,
            record_snapshots=True,
        )

    raise WorktreeError(f"Unknown task: {task_id}")


def parse_simctl_json(*args: str) -> dict[str, object]:
    output = checked(["xcrun", "simctl", *args, "-j"])
    return json.loads(output)


def available_runtimes() -> list[Runtime]:
    payload = parse_simctl_json("list", "runtimes", "available")
    runtimes: list[Runtime] = []
    for entry in payload.get("runtimes", []):
        if not isinstance(entry, dict):
            continue
        identifier = entry.get("identifier")
        version = entry.get("version")
        platform = entry.get("platform")
        if platform == "iOS" and isinstance(identifier, str) and isinstance(version, str):
            runtimes.append(Runtime(identifier=identifier, version=version))
    return runtimes


def version_tuple(version: str) -> tuple[int, ...]:
    return tuple(int(piece) for piece in re.findall(r"\d+", version))


def choose_runtime(runtime_class: RuntimeClass, runtimes: list[Runtime]) -> Runtime:
    for preferred_identifier in runtime_class.preferred_identifiers:
        for runtime in runtimes:
            if runtime.identifier == preferred_identifier:
                return runtime
    if runtime_class.policy == "exact":
        joined = ", ".join(runtime_class.preferred_identifiers) or "(none)"
        raise WorktreeError(f"Preferred runtime(s) {joined} are not installed")
    if not runtimes:
        raise WorktreeError("No available iOS simulator runtimes are installed")
    return max(runtimes, key=lambda runtime: version_tuple(runtime.version))


def simctl_device_directory(udid: str) -> Path:
    return Path.home() / "Library" / "Developer" / "CoreSimulator" / "Devices" / udid


def is_project_worktree(path: Path) -> bool:
    return (
        (path / "Project.swift").exists()
        and (path / "AGENTS.md").exists()
        and (path / "TestPlans" / "__APP_NAME__.simprofile.toml").exists()
    )


def is_orphaned_marker(marker: dict[str, object]) -> bool:
    worktree_path = marker.get("worktree_path")
    if not isinstance(worktree_path, str):
        return True
    path = Path(worktree_path)
    if not path.exists():
        return True
    if not is_project_worktree(path):
        return True
    family = marker.get("family")
    if not isinstance(family, str):
        return True
    metadata_path = path / "build" / "simulators" / f"{family}.json"
    return not metadata_path.exists()


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True))


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text())


def list_available_devices() -> dict[str, dict[str, object]]:
    payload = parse_simctl_json("list", "devices", "available")
    devices: dict[str, dict[str, object]] = {}
    for runtime_identifier, entries in payload.get("devices", {}).items():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            udid = entry.get("udid")
            if isinstance(udid, str):
                enriched = dict(entry)
                enriched["runtimeIdentifier"] = runtime_identifier
                devices[udid] = enriched
    return devices


def available_device_types() -> list[DeviceType]:
    payload = parse_simctl_json("list", "devicetypes")
    device_types: list[DeviceType] = []
    for entry in payload.get("devicetypes", []):
        if not isinstance(entry, dict):
            continue
        name = entry.get("name")
        identifier = entry.get("identifier")
        if isinstance(name, str) and isinstance(identifier, str):
            device_types.append(DeviceType(name=name, identifier=identifier))
    return device_types


def available_device_type_identifiers() -> set[str]:
    return {device_type.identifier for device_type in available_device_types()}


def resolve_device_type_identifier(device: dict[str, object], available_identifiers: set[str]) -> str:
    candidates = device.get("type_identifiers", [])
    if not isinstance(candidates, list) or not candidates:
        raise WorktreeError("Device config must include a non-empty type_identifiers list")
    for candidate in candidates:
        if isinstance(candidate, str) and candidate in available_identifiers:
            return candidate
    raise WorktreeError(
        f"None of the configured device types are installed: {', '.join(str(candidate) for candidate in candidates)}"
    )


def numeric_tokens(value: str) -> tuple[int, ...]:
    return tuple(int(piece) for piece in re.findall(r"\d+", value))


def iphone_device_score(device_type: DeviceType) -> tuple[int, int, int]:
    name = device_type.name
    generation = max(numeric_tokens(name), default=-1)
    if " Pro" in name and "Pro Max" not in name:
        category = 5
    elif re.fullmatch(r"iPhone \d+", name):
        category = 4
    elif " Pro Max" in name:
        category = 3
    elif " Plus" in name:
        category = 2
    else:
        category = 1
    memory_preference = 0 if "16GB" in name else 1
    return (generation, category, memory_preference)


def ipad_device_score(device_type: DeviceType) -> tuple[int, int, int]:
    name = device_type.name
    chip_or_generation = max(numeric_tokens(name), default=-1)
    if name.startswith("iPad Pro 13-inch"):
        category = 6
    elif name.startswith("iPad Pro (12.9-inch)") or name.startswith("iPad Pro 12.9-inch"):
        category = 5
    elif name.startswith("iPad Air 13-inch"):
        category = 4
    elif name.startswith("iPad Pro 11-inch") or name.startswith("iPad Pro (11-inch)"):
        category = 3
    elif name.startswith("iPad Air"):
        category = 2
    else:
        category = 1
    memory_preference = 0 if "16GB" in name else 1
    return (category, chip_or_generation, memory_preference)


def pick_device_type_for_family(family: str, device_types: list[DeviceType]) -> DeviceType:
    filtered = [device_type for device_type in device_types if device_type.name.startswith("iPhone" if family == "iphone" else "iPad")]
    if not filtered:
        raise WorktreeError(f"No installed simulator device types match family `{family}`")
    if family == "iphone":
        return max(filtered, key=iphone_device_score)
    if family == "ipad":
        return max(filtered, key=ipad_device_score)
    raise WorktreeError(f"Unknown device family: {family}")


def create_simulator(name: str, device_type: str, runtime_identifier: str) -> str:
    return checked(["xcrun", "simctl", "create", name, device_type, runtime_identifier]).strip()


def boot_simulator(udid: str) -> None:
    run(["xcrun", "simctl", "boot", udid], capture_output=True)
    completed = run(["xcrun", "simctl", "bootstatus", udid, "-b"], capture_output=True)
    if completed.returncode != 0:
        raise WorktreeError(f"Failed to boot simulator {udid}: {completed.stderr.strip()}")


def shutdown_delete_simulator(udid: str) -> None:
    run(["xcrun", "simctl", "shutdown", udid], capture_output=True)
    run(["xcrun", "simctl", "delete", udid], capture_output=True)


def erase_simulator(udid: str) -> None:
    run(["xcrun", "simctl", "shutdown", udid], capture_output=True)
    checked(["xcrun", "simctl", "erase", udid])


def ensure_simulator(
    root: Path,
    config: dict[str, object],
    family: str,
    runtime_class_name: str,
    *,
    reset_policy: str | None = None,
) -> dict[str, object]:
    explicit_device: dict[str, object] | None = None
    try:
        explicit_device = device_config(config, family)
    except WorktreeError:
        explicit_device = None

    if explicit_device is not None:
        device_type_identifier = resolve_device_type_identifier(explicit_device, available_device_type_identifiers())
        chosen_device_name = str(explicit_device.get("name", family))
    else:
        chosen_device = pick_device_type_for_family(family, available_device_types())
        device_type_identifier = chosen_device.identifier
        chosen_device_name = chosen_device.name

    runtime = choose_runtime(runtime_class_config(config, runtime_class_name), available_runtimes())
    runtime_identifier = runtime.identifier
    simulator_state_path = root / "build" / "simulators" / f"{family}.json"
    wanted_name = simulator_name(root, family)
    devices = list_available_devices()

    metadata: dict[str, object] | None = None
    if simulator_state_path.exists():
        metadata = read_json(simulator_state_path)
        udid = metadata.get("udid")
        if isinstance(udid, str) and udid in devices:
            entry = devices[udid]
            if metadata.get("runtime_identifier") == runtime_identifier and metadata.get("device_type_identifier") == device_type_identifier:
                metadata["last_used_at"] = now_utc()
                write_json(simulator_state_path, metadata)
                write_json(
                    simulator_marker_path(simctl_device_directory(udid)),
                    {
                        "worktree_path": str(root),
                        "repo_identifier": "__APP_SLUG__",
                        "worktree_hash": worktree_hash(root),
                        "family": family,
                        "created_at": metadata.get("created_at", now_utc()),
                        "last_used_at": metadata["last_used_at"],
                    },
                )
                if reset_policy == "erase_before_run":
                    erase_simulator(udid)
                boot_simulator(udid)
                return metadata
            shutdown_delete_simulator(udid)
        metadata = None

    for udid, entry in devices.items():
        if entry.get("name") == wanted_name:
            if entry.get("runtimeIdentifier") != runtime_identifier:
                shutdown_delete_simulator(udid)
                continue
            if entry.get("deviceTypeIdentifier") != device_type_identifier:
                shutdown_delete_simulator(udid)
                continue
            metadata = {
                "simulator_name": wanted_name,
                "udid": udid,
                "device_name": chosen_device_name,
                "device_type_identifier": device_type_identifier,
                "runtime_identifier": runtime_identifier,
                "runtime_version": runtime.version,
                "worktree_path": str(root),
                "repo_identifier": "__APP_SLUG__",
                "worktree_hash": worktree_hash(root),
                "created_at": now_utc(),
                "last_used_at": now_utc(),
                "last_known_health_state": "healthy",
            }
            write_json(simulator_state_path, metadata)
            write_json(
                simulator_marker_path(simctl_device_directory(udid)),
                {
                    "worktree_path": str(root),
                    "repo_identifier": "__APP_SLUG__",
                    "worktree_hash": worktree_hash(root),
                    "family": family,
                    "created_at": metadata["created_at"],
                    "last_used_at": metadata["last_used_at"],
                },
            )
            if reset_policy == "erase_before_run":
                erase_simulator(udid)
            boot_simulator(udid)
            return metadata

    udid = create_simulator(wanted_name, device_type_identifier, runtime_identifier)
    metadata = {
        "simulator_name": wanted_name,
        "udid": udid,
        "device_name": chosen_device_name,
        "device_type_identifier": device_type_identifier,
        "runtime_identifier": runtime_identifier,
        "runtime_version": runtime.version,
        "worktree_path": str(root),
        "repo_identifier": "__APP_SLUG__",
        "worktree_hash": worktree_hash(root),
        "created_at": now_utc(),
        "last_used_at": now_utc(),
        "last_known_health_state": "healthy",
    }
    write_json(simulator_state_path, metadata)
    write_json(
        simulator_marker_path(simctl_device_directory(udid)),
        {
            "worktree_path": str(root),
            "repo_identifier": "__APP_SLUG__",
            "worktree_hash": worktree_hash(root),
            "family": family,
            "created_at": metadata["created_at"],
            "last_used_at": metadata["last_used_at"],
        },
    )
    if reset_policy == "erase_before_run":
        erase_simulator(udid)
    boot_simulator(udid)
    return metadata


def stable_path(root: Path, relative_path: str | None) -> Path | None:
    if not relative_path:
        return None
    return root / relative_path


def materialized_artifact_path(path: Path) -> Path:
    if path.is_symlink():
        return Path(os.path.realpath(path))
    return path


def finalize_artifact(stable: Path | None, temp: Path | None) -> None:
    if stable is None or temp is None or not temp.exists():
        return
    materialized_temp = materialized_artifact_path(temp)
    if stable.exists():
        if stable.is_symlink():
            stable.unlink()
        elif stable.is_dir():
            shutil.rmtree(stable)
        else:
            stable.unlink()
    temp.parent.mkdir(parents=True, exist_ok=True)
    os.replace(materialized_temp, stable)
    if temp.is_symlink():
        temp.unlink(missing_ok=True)


def cleanup_failed_temp(temp: Path | None) -> None:
    if temp is None or not temp.exists():
        return
    materialized_temp = materialized_artifact_path(temp)
    if temp.is_symlink():
        temp.unlink(missing_ok=True)
    if materialized_temp.exists():
        if materialized_temp.is_dir():
            shutil.rmtree(materialized_temp, ignore_errors=True)
        else:
            materialized_temp.unlink(missing_ok=True)
    elif temp.is_dir():
        shutil.rmtree(temp, ignore_errors=True)
    else:
        temp.unlink(missing_ok=True)


def export_task_environment(root: Path, config: dict[str, object], task: Task, owner: Owner) -> dict[str, str]:
    env: dict[str, str] = {
        "IOS_WORKTREE_OWNER_ID": owner.owner_id,
        "IOS_WORKTREE_OWNER_PID": str(owner.pid),
        "IOS_WORKTREE_OWNER_START_TIME": owner.start_time,
        "IOS_WORKTREE_EXECUTION_MODE": os.environ.get("IOS_WORKTREE_EXECUTION_MODE", "local"),
        "IOS_WORKTREE_TASK_ID": task.task_id,
    }
    if task.record_snapshots:
        env["IOS_WORKTREE_SNAPSHOT_RECORD"] = "1"

    if task.scheme_name is not None:
        env["IOS_WORKTREE_SCHEME"] = task.scheme_name
    if task.target_name is not None:
        env["IOS_WORKTREE_TARGET_NAME"] = task.target_name
    if task.runtime_class is not None:
        env["IOS_WORKTREE_RUNTIME_CLASS"] = task.runtime_class
    if task.data_mode is not None:
        env["IOS_WORKTREE_DATA_MODE"] = task.data_mode

    derived_root: Path | None = None
    if task.action == "archive":
        derived_root = root / "build" / "derived" / "archive"
    elif task.device_family is not None:
        derived_root = root / "build" / "derived" / task.device_family
    if derived_root is not None:
        derived_root.mkdir(parents=True, exist_ok=True)
        env["IOS_WORKTREE_DERIVED_DATA_PATH"] = str(derived_root)

    if task.action == "build" and task.device_family is not None:
        build_output = root / "build" / "products" / task.device_family
        build_output.mkdir(parents=True, exist_ok=True)
        env["IOS_WORKTREE_BUILD_OUTPUT_PATH"] = str(build_output)

    if task.action in {"test", "record"}:
        result_bundle = root / "build" / "results" / f"{task.task_id}.xcresult"
        temp = unique_temp_path(result_bundle)
        cleanup_failed_temp(temp)
        env["IOS_WORKTREE_RESULT_BUNDLE_PATH"] = str(result_bundle)
        env["IOS_WORKTREE_RESULT_BUNDLE_TEMP_PATH"] = str(temp)

    if task.action == "archive":
        archive_path = root / "build" / "archives" / "__APP_NAME__.xcarchive"
        temp_archive = unique_temp_path(archive_path)
        cleanup_failed_temp(temp_archive)
        env["IOS_WORKTREE_ARCHIVE_PATH"] = str(archive_path)
        env["IOS_WORKTREE_ARCHIVE_TEMP_PATH"] = str(temp_archive)

        export_path = root / "build" / "exports" / "__APP_NAME__.ipa"
        temp_export = unique_temp_path(export_path)
        cleanup_failed_temp(temp_export)
        env["IOS_WORKTREE_EXPORT_PATH"] = str(export_path)
        env["IOS_WORKTREE_EXPORT_TEMP_PATH"] = str(temp_export)

    family = task.device_family
    if isinstance(family, str):
        metadata = ensure_simulator(
            root,
            config,
            family,
            task.runtime_class or "flexible",
            reset_policy="erase_before_run" if task.record_snapshots else None,
        )
        env["IOS_WORKTREE_DEVICE_FAMILY"] = family
        env["IOS_WORKTREE_DEVICE_NAME"] = str(metadata.get("device_name", metadata["simulator_name"]))
        env["IOS_WORKTREE_DEVICE_TYPE_IDENTIFIER"] = str(metadata["device_type_identifier"])
        env["IOS_WORKTREE_SIMULATOR_UDID"] = str(metadata["udid"])
        env["IOS_WORKTREE_SIMULATOR_NAME"] = str(metadata["simulator_name"])
        env["IOS_WORKTREE_RUNTIME_IDENTIFIER"] = str(metadata["runtime_identifier"])
        env["IOS_WORKTREE_RUNTIME_VERSION"] = str(metadata.get("runtime_version", metadata["runtime_identifier"]).split(".iOS-")[-1].replace("-", "."))
        env["IOS_WORKTREE_SCREENSHOT_DIR"] = str(root / f"build/screenshots/{task.task_id}")

    return env


def launch_fixture_server(root: Path) -> tuple[subprocess.Popen[str], dict[str, str]]:
    logs_dir = root / "build" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    ready_dir = Path(tempfile.mkdtemp(prefix="fixture-server-", dir=logs_dir))
    ready_file = ready_dir / "ready.json"
    script_path = root / "scripts" / "__APP_SLUG___fixture_server.py"
    process = subprocess.Popen(
        [
            sys.executable,
            str(script_path),
            "--port",
            "0",
            "--ready-file",
            str(ready_file),
        ],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    deadline = time.time() + 10
    try:
        while time.time() < deadline:
            if ready_file.exists():
                payload = json.loads(ready_file.read_text())
                wait_for_fixture_server_health(str(payload["server_url"]), process, deadline)
                return process, {
                    "IOS_WORKTREE_FIXTURE_SERVER_URL": str(payload["server_url"]),
                    "IOS_WORKTREE_API_BASE_URL": str(payload["base_url"]),
                    "IOS_WORKTREE_JUSTWATCH_GRAPHQL_URL": str(payload["justwatch_graphql_url"]),
                    "TEST_RUNNER_IOS_WORKTREE_FIXTURE_SERVER_URL": str(payload["server_url"]),
                    "TEST_RUNNER_IOS_WORKTREE_API_BASE_URL": str(payload["base_url"]),
                    "TEST_RUNNER_IOS_WORKTREE_JUSTWATCH_GRAPHQL_URL": str(payload["justwatch_graphql_url"]),
                    "TEST_RUNNER_MOVIES_DO_TEST_USERNAME": str(payload["username"]),
                    "TEST_RUNNER_MOVIES_DO_TEST_PASSWORD": str(payload["password"]),
                    "IOS_WORKTREE_DATA_MODE": "deterministic",
                    "TEST_RUNNER_IOS_WORKTREE_DATA_MODE": "deterministic",
                }
            if process.poll() is not None:
                stdout, stderr = process.communicate()
                raise WorktreeError(
                    "Fixture server exited before becoming ready.\n"
                    f"STDOUT:\n{stdout.strip()}\nSTDERR:\n{stderr.strip()}"
                )
            time.sleep(0.05)
        raise WorktreeError("Fixture server did not become ready within 10 seconds")
    except Exception:
        stop_fixture_server(process)
        raise
    finally:
        shutil.rmtree(ready_dir, ignore_errors=True)


def stop_fixture_server(process: subprocess.Popen[str] | None) -> None:
    if process is None:
        return
    try:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    finally:
        if process.stdout is not None:
            process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()


def wait_for_fixture_server_health(
    server_url: str,
    process: subprocess.Popen[str],
    deadline: float,
) -> None:
    health_url = f"{server_url}/healthz"
    while time.time() < deadline:
        if process.poll() is not None:
            stdout, stderr = process.communicate()
            raise WorktreeError(
                "Fixture server exited before passing the health check.\n"
                f"STDOUT:\n{stdout.strip()}\nSTDERR:\n{stderr.strip()}"
            )
        try:
            with urllib_request.urlopen(health_url, timeout=1) as response:
                if response.status == 200:
                    return
        except (urllib_error.URLError, TimeoutError):
            time.sleep(0.05)
    raise WorktreeError("Fixture server did not pass the health check within 10 seconds")


def authorize_state_change(root: Path, owner_lock: LockDirectory, owner: Owner) -> None:
    if not owner_lock.path.exists():
        return
    metadata = owner_lock.read_metadata()
    if metadata.get("owner_id") == owner.owner_id:
        return
    if owner_lock.is_stale():
        owner_lock.reap_stale(owner.owner_id)
        return
    raise WorktreeError("Refusing to mutate worktree state while a different live owner holds the worktree.")


def ensure_no_live_build_operation(root: Path, owner: Owner) -> None:
    b_lock = build_lock(root)
    if not b_lock.path.exists():
        return
    if b_lock.is_stale():
        b_lock.reap_stale(owner.owner_id)
        return
    metadata = b_lock.read_metadata()
    operation_pid = metadata.get("operation_pid")
    operation_command = metadata.get("operation_command")
    raise WorktreeError(
        f"Refusing to mutate worktree state while a build operation is active ({operation_command}, pid {operation_pid})."
    )


def remove_worktree_simulators(root: Path, include_orphans: bool = False) -> None:
    simulator_state_dir = root / "build" / "simulators"
    for family in ("iphone", "ipad"):
        metadata_path = simulator_state_dir / f"{family}.json"
        if metadata_path.exists():
            metadata = read_json(metadata_path)
            udid = metadata.get("udid")
            if isinstance(udid, str):
                shutdown_delete_simulator(udid)
            metadata_path.unlink(missing_ok=True)
    if include_orphans:
        reap_orphan_simulators()


def reap_orphan_simulators() -> None:
    devices = list_available_devices()
    for udid, entry in devices.items():
        name = entry.get("name")
        if not isinstance(name, str) or not name.startswith(SIMULATOR_PREFIX):
            continue
        marker_path = simulator_marker_path(simctl_device_directory(udid))
        if not marker_path.exists():
            continue
        marker = read_json(marker_path)
        if is_orphaned_marker(marker):
            shutdown_delete_simulator(udid)


def owner_lock(root: Path) -> LockDirectory:
    return LockDirectory(root / "build" / "state" / "owner.lock", root / "build" / "state" / "owner.lock" / "metadata.json")


def build_lock(root: Path) -> LockDirectory:
    return LockDirectory(root / "build" / "state" / "buildsystem.lock", root / "build" / "state" / "buildsystem.lock" / "metadata.json")


def command_exec(args: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    o_lock = owner_lock(root)
    b_lock = build_lock(root)
    o_lock.acquire_owner(owner)
    b_lock.acquire_build(owner)

    fixture_process: subprocess.Popen[str] | None = None
    try:
        if args.task == "generate":
            task = Task(task_id=args.task, action="generate")
            config: dict[str, object] = {}
        else:
            config = load_config(root)
            project_dump = load_project_dump(root)
            task = parse_task(args.task, project_dump)
        env = os.environ.copy()
        exported = export_task_environment(root, config, task, owner)
        env.update(exported)
        fixture_script = root / "scripts" / "__APP_SLUG___fixture_server.py"
        if (
            task.data_mode == "deterministic"
            and task.suite_kind in {"ui", "visual"}
            and fixture_script.exists()
        ):
            fixture_process, fixture_env = launch_fixture_server(root)
            env.update(fixture_env)

        stable_result = Path(env["IOS_WORKTREE_RESULT_BUNDLE_PATH"]) if "IOS_WORKTREE_RESULT_BUNDLE_PATH" in env else None
        temp_result = Path(env["IOS_WORKTREE_RESULT_BUNDLE_TEMP_PATH"]) if "IOS_WORKTREE_RESULT_BUNDLE_TEMP_PATH" in env else None
        stable_archive = Path(env["IOS_WORKTREE_ARCHIVE_PATH"]) if "IOS_WORKTREE_ARCHIVE_PATH" in env else None
        temp_archive = Path(env["IOS_WORKTREE_ARCHIVE_TEMP_PATH"]) if "IOS_WORKTREE_ARCHIVE_TEMP_PATH" in env else None
        stable_export = Path(env["IOS_WORKTREE_EXPORT_PATH"]) if "IOS_WORKTREE_EXPORT_PATH" in env else None
        temp_export = Path(env["IOS_WORKTREE_EXPORT_TEMP_PATH"]) if "IOS_WORKTREE_EXPORT_TEMP_PATH" in env else None

        completed = subprocess.run(args.child_command, env=env, cwd=root)
        if completed.returncode == 0:
            finalize_artifact(stable_result, temp_result)
            finalize_artifact(stable_archive, temp_archive)
            finalize_artifact(stable_export, temp_export)
        else:
            cleanup_failed_temp(temp_result)
            cleanup_failed_temp(temp_archive)
            cleanup_failed_temp(temp_export)
        return completed.returncode
    finally:
        stop_fixture_server(fixture_process)
        try:
            b_lock.release_if_stale(owner)
        except WorktreeError:
            pass


def command_doctor_state(_: argparse.Namespace) -> int:
    root = repo_root()
    payload = {
        "repo_root": str(root),
        "owner_lock": owner_lock(root).read_metadata(),
        "build_lock": build_lock(root).read_metadata(),
        "simulators": {},
    }
    for family in ("iphone", "ipad"):
        path = root / "build" / "simulators" / f"{family}.json"
        if path.exists():
            payload["simulators"][family] = read_json(path)
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_release_owner(_: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    ensure_no_live_build_operation(root, owner)
    owner_lock(root).release_if_stale(owner)
    return 0


def command_clean_build(_: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    authorize_state_change(root, owner_lock(root), owner)
    ensure_no_live_build_operation(root, owner)
    for relative in (
        "build/derived",
        "build/results",
        "build/screenshots",
        "build/archives",
        "build/exports",
        "build/logs",
        "build/traces",
    ):
        shutil.rmtree(root / relative, ignore_errors=True)
    return 0


def command_clean_simulators(_: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    authorize_state_change(root, owner_lock(root), owner)
    ensure_no_live_build_operation(root, owner)
    remove_worktree_simulators(root)
    return 0


def command_reap_orphan_simulators(_: argparse.Namespace) -> int:
    reap_orphan_simulators()
    return 0


def command_reset_simulators(_: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    authorize_state_change(root, owner_lock(root), owner)
    ensure_no_live_build_operation(root, owner)
    remove_worktree_simulators(root)
    config = load_config(root)
    for family in ("iphone", "ipad"):
        ensure_simulator(root, config, family, "flexible")
    return 0


def command_clean(_: argparse.Namespace) -> int:
    root = repo_root()
    owner = detect_owner()
    o_lock = owner_lock(root)
    authorize_state_change(root, o_lock, owner)
    ensure_no_live_build_operation(root, owner)
    remove_worktree_simulators(root)
    build_root = root / "build"
    state_root = build_root / "state"

    for child in build_root.iterdir() if build_root.exists() else []:
        if child == state_root:
            continue
        if child.is_dir():
            shutil.rmtree(child, ignore_errors=True)
        else:
            child.unlink(missing_ok=True)

    if state_root.exists():
        for child in state_root.iterdir():
            if child == o_lock.path:
                continue
            if child.is_dir():
                shutil.rmtree(child, ignore_errors=True)
            else:
                child.unlink(missing_ok=True)

    o_lock.release_if_stale(owner)
    if state_root.exists() and not any(state_root.iterdir()):
        state_root.rmdir()
    if build_root.exists() and not any(build_root.iterdir()):
        build_root.rmdir()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    exec_parser = subparsers.add_parser("exec")
    exec_parser.add_argument("--task", required=True)
    exec_parser.add_argument("child_command", nargs=argparse.REMAINDER)
    exec_parser.set_defaults(handler=command_exec)

    for name, handler in (
        ("doctor-state", command_doctor_state),
        ("release-owner", command_release_owner),
        ("clean-build", command_clean_build),
        ("clean-simulators", command_clean_simulators),
        ("reap-orphan-simulators", command_reap_orphan_simulators),
        ("reset-simulators", command_reset_simulators),
        ("clean", command_clean),
    ):
        command_parser = subparsers.add_parser(name)
        command_parser.set_defaults(handler=handler)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.subcommand == "exec" and args.child_command[:1] == ["--"]:
        args.child_command = args.child_command[1:]
    if args.subcommand == "exec" and not args.child_command:
        parser.error("exec requires a command after --")
    return args.handler(args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except WorktreeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
