#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ctypes
import json
import math
import os
import plistlib
import shutil
import struct
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Iterable, Sequence


FSOPT_NOFOLLOW = 0x00000001
FSOPT_ATTR_CMN_EXTENDED = 0x00000020

ATTR_CMN_FILEID = 0x02000000
ATTR_CMN_RETURNED_ATTRS = 0x80000000
ATTR_VOL_CAPABILITIES = 0x00020000
ATTR_FILE_ALLOCSIZE = 0x00000004
ATTR_FILE_DATALENGTH = 0x00000200
ATTR_CMNEXT_PRIVATESIZE = 0x00000008
ATTR_CMNEXT_CLONEID = 0x00000100
ATTR_CMNEXT_EXT_FLAGS = 0x00000200
ATTR_CMNEXT_CLONE_REFCNT = 0x00001000

VOL_CAPABILITIES_FORMAT = 0
VOL_CAPABILITIES_INTERFACES = 1
VOL_CAP_FMT_CLONE_MAPPING = 0x04000000
VOL_CAP_INT_CLONE = 0x00010000
VOL_CAP_INT_SNAPSHOT = 0x00020000

EF_MAY_SHARE_BLOCKS = 0x00000001
EF_SHARES_ALL_BLOCKS = 0x00000040

FILE_ATTR_STRUCT = struct.Struct("=I5IQqqqQQI")
VOL_CAP_STRUCT = struct.Struct("=I5I4I4I")


class AttrList(ctypes.Structure):
    _fields_ = [
        ("bitmapcount", ctypes.c_ushort),
        ("reserved", ctypes.c_ushort),
        ("commonattr", ctypes.c_uint32),
        ("volattr", ctypes.c_uint32),
        ("dirattr", ctypes.c_uint32),
        ("fileattr", ctypes.c_uint32),
        ("forkattr", ctypes.c_uint32),
    ]


LIBC = ctypes.CDLL(None, use_errno=True)
GETATTRLIST = LIBC.getattrlist
GETATTRLIST.argtypes = [
    ctypes.c_char_p,
    ctypes.POINTER(AttrList),
    ctypes.c_void_p,
    ctypes.c_size_t,
    ctypes.c_ulong,
]
GETATTRLIST.restype = ctypes.c_int


@dataclass
class FileMetrics:
    path: str
    kind: str
    file_id: int
    logical_bytes: int
    allocated_bytes: int
    reclaimable_bytes: int
    clone_id: int
    clone_refcnt: int
    ext_flags: int
    may_share_blocks: bool
    shares_all_blocks: bool


@dataclass
class AggregateStats:
    file_count: int = 0
    dir_count: int = 0
    skipped_paths: int = 0
    logical_bytes: int = 0
    allocated_bytes: int = 0
    reclaimable_bytes: int = 0
    may_share_blocks_files: int = 0
    shares_all_blocks_files: int = 0
    clone_members_by_id: dict[int, int] = field(default_factory=dict)
    clone_refcnt_by_id: dict[int, int] = field(default_factory=dict)

    def add_file(self, metrics: FileMetrics) -> None:
        self.file_count += 1
        self.logical_bytes += metrics.logical_bytes
        self.allocated_bytes += metrics.allocated_bytes
        self.reclaimable_bytes += metrics.reclaimable_bytes
        if metrics.may_share_blocks:
            self.may_share_blocks_files += 1
        if metrics.shares_all_blocks:
            self.shares_all_blocks_files += 1
        if metrics.clone_refcnt > 1:
            self.clone_members_by_id[metrics.clone_id] = self.clone_members_by_id.get(metrics.clone_id, 0) + 1
            self.clone_refcnt_by_id[metrics.clone_id] = max(
                metrics.clone_refcnt,
                self.clone_refcnt_by_id.get(metrics.clone_id, 0),
            )


def format_bytes(value: int) -> str:
    if value == 0:
        return "0 B"
    units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    magnitude = min(int(math.log(value, 1024)), len(units) - 1)
    scaled = value / (1024**magnitude)
    if magnitude == 0:
        return f"{value} B"
    return f"{scaled:.1f} {units[magnitude]}"


def _call_getattrlist(path: os.PathLike[str] | str, attr_list: AttrList, size: int, flags: int) -> bytes:
    buffer = ctypes.create_string_buffer(size)
    result = GETATTRLIST(
        os.fsencode(os.fspath(path)),
        ctypes.byref(attr_list),
        buffer,
        ctypes.sizeof(buffer),
        flags,
    )
    if result != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number), os.fspath(path))
    return buffer.raw


def probe_file(path: os.PathLike[str] | str) -> FileMetrics:
    file_path = Path(path)
    if file_path.is_symlink():
        raise ValueError(f"Symlinks are not supported for clone-aware probing: {file_path}")

    attr_list = AttrList(
        bitmapcount=5,
        reserved=0,
        commonattr=ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_FILEID,
        volattr=0,
        dirattr=0,
        fileattr=ATTR_FILE_ALLOCSIZE | ATTR_FILE_DATALENGTH,
        forkattr=(
            ATTR_CMNEXT_PRIVATESIZE
            | ATTR_CMNEXT_CLONEID
            | ATTR_CMNEXT_EXT_FLAGS
            | ATTR_CMNEXT_CLONE_REFCNT
        ),
    )
    raw = _call_getattrlist(file_path, attr_list, FILE_ATTR_STRUCT.size, FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW)
    (
        _length,
        _returned_common,
        _returned_vol,
        _returned_dir,
        _returned_file,
        _returned_fork,
        file_id,
        allocated_bytes,
        logical_bytes,
        reclaimable_bytes,
        clone_id,
        ext_flags,
        clone_refcnt,
    ) = FILE_ATTR_STRUCT.unpack_from(raw)
    return FileMetrics(
        path=str(file_path),
        kind="file",
        file_id=file_id,
        logical_bytes=max(0, logical_bytes),
        allocated_bytes=max(0, allocated_bytes),
        reclaimable_bytes=max(0, reclaimable_bytes),
        clone_id=clone_id,
        clone_refcnt=clone_refcnt,
        ext_flags=ext_flags,
        may_share_blocks=bool(ext_flags & EF_MAY_SHARE_BLOCKS),
        shares_all_blocks=bool(ext_flags & EF_SHARES_ALL_BLOCKS),
    )


def probe_path(path: os.PathLike[str] | str) -> FileMetrics:
    target = Path(path)
    if target.is_dir():
        raise ValueError(f"probe_path only supports files: {target}")
    return probe_file(target)


def walk_directory(path: os.PathLike[str] | str) -> AggregateStats:
    root = Path(path)
    stats = AggregateStats()
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            with os.scandir(current) as entries:
                for entry in entries:
                    try:
                        if entry.is_symlink():
                            stats.skipped_paths += 1
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            stats.dir_count += 1
                            stack.append(Path(entry.path))
                            continue
                        if entry.is_file(follow_symlinks=False):
                            stats.add_file(probe_file(entry.path))
                            continue
                        stats.skipped_paths += 1
                    except (FileNotFoundError, PermissionError, NotADirectoryError):
                        stats.skipped_paths += 1
        except (FileNotFoundError, PermissionError, NotADirectoryError):
            stats.skipped_paths += 1
    return stats


def summarize_target(path: os.PathLike[str] | str) -> dict[str, Any]:
    target = Path(path)
    if target.is_dir():
        stats = walk_directory(target)
        return finalize_summary(target, "directory", stats)

    metrics = probe_file(target)
    stats = AggregateStats()
    stats.add_file(metrics)
    return finalize_summary(target, "file", stats, file_metrics=metrics)


def finalize_summary(path: Path, kind: str, stats: AggregateStats, *, file_metrics: FileMetrics | None = None) -> dict[str, Any]:
    reclaimable_ratio = (
        stats.reclaimable_bytes / stats.allocated_bytes if stats.allocated_bytes else 0.0
    )
    fully_contained_clone_groups = 0
    external_clone_groups = 0
    for clone_id, member_count in stats.clone_members_by_id.items():
        refcnt = stats.clone_refcnt_by_id.get(clone_id, 0)
        if max(member_count, refcnt) <= 1:
            continue
        if member_count >= refcnt:
            fully_contained_clone_groups += 1
        else:
            external_clone_groups += 1

    notes: list[str] = []
    if stats.allocated_bytes and reclaimable_ratio < 0.25:
        notes.append(
            "Immediate reclaim is a lower-bound because most allocated bytes are shared, snapshot-pinned, or otherwise non-private."
        )
    elif stats.allocated_bytes and reclaimable_ratio > 0.75:
        notes.append(
            "Most allocated bytes appear private, so deletion should reclaim close to the allocated size."
        )
    if external_clone_groups:
        notes.append(
            f"{external_clone_groups} clone group(s) extend outside this path, so shared bytes are unlikely to free immediately."
        )
    if fully_contained_clone_groups:
        notes.append(
            f"{fully_contained_clone_groups} fully contained clone group(s) were found, so whole-path reclaim may be higher than the lower-bound private-byte estimate."
        )
    if stats.skipped_paths:
        notes.append(f"Skipped {stats.skipped_paths} entries because they were symlinks, transient, or unreadable.")

    summary: dict[str, Any] = {
        "path": str(path),
        "kind": kind,
        "file_count": stats.file_count,
        "dir_count": stats.dir_count,
        "skipped_paths": stats.skipped_paths,
        "logical_bytes": stats.logical_bytes,
        "allocated_bytes": stats.allocated_bytes,
        "private_bytes": stats.reclaimable_bytes,
        "immediate_reclaim_bytes": stats.reclaimable_bytes,
        "reclaimable_bytes": stats.reclaimable_bytes,
        "nonreclaimable_bytes": max(0, stats.allocated_bytes - stats.reclaimable_bytes),
        "non_immediate_reclaim_bytes": max(0, stats.allocated_bytes - stats.reclaimable_bytes),
        "reclaimable_ratio": reclaimable_ratio,
        "may_share_blocks_files": stats.may_share_blocks_files,
        "shares_all_blocks_files": stats.shares_all_blocks_files,
        "clone_groups_seen": len(stats.clone_members_by_id),
        "fully_contained_clone_groups": fully_contained_clone_groups,
        "external_clone_groups": external_clone_groups,
        "notes": notes,
    }
    if file_metrics is not None:
        summary["file_metrics"] = asdict(file_metrics)
    return summary


def _run_command(command: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(command),
        check=False,
        capture_output=True,
        text=True,
    )


def _diskutil_info(path: os.PathLike[str] | str) -> dict[str, Any] | None:
    if sys.platform != "darwin":
        return None
    result = _run_command(["diskutil", "info", "-plist", str(path)])
    if result.returncode != 0:
        return None
    return plistlib.loads(result.stdout.encode("utf-8"))


def _snapshot_count(path: os.PathLike[str] | str) -> int | None:
    if sys.platform != "darwin":
        return None
    result = _run_command(["diskutil", "apfs", "listSnapshots", "-plist", str(path)])
    if result.returncode != 0:
        return None
    payload = plistlib.loads(result.stdout.encode("utf-8"))
    return len(payload.get("Snapshots", []))


def _mount_point_for_path(path: os.PathLike[str] | str) -> str | None:
    result = _run_command(["df", "-P", str(path)])
    if result.returncode != 0:
        return None
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if len(lines) < 2:
        return None
    columns = lines[-1].split()
    if len(columns) < 6:
        return None
    return columns[-1]


def _probe_volume_capabilities(path: os.PathLike[str] | str) -> dict[str, bool] | None:
    attr_list = AttrList(
        bitmapcount=5,
        reserved=0,
        commonattr=ATTR_CMN_RETURNED_ATTRS,
        volattr=ATTR_VOL_CAPABILITIES,
        dirattr=0,
        fileattr=0,
        forkattr=0,
    )
    try:
        raw = _call_getattrlist(path, attr_list, VOL_CAP_STRUCT.size, FSOPT_NOFOLLOW)
    except OSError:
        return None

    unpacked = VOL_CAP_STRUCT.unpack_from(raw)
    capabilities = unpacked[6:10]
    valid = unpacked[10:14]
    return {
        "supports_clone_mapping": bool(
            valid[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CLONE_MAPPING
            and capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CLONE_MAPPING
        ),
        "supports_clones": bool(
            valid[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_CLONE
            and capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_CLONE
        ),
        "supports_snapshots": bool(
            valid[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_SNAPSHOT
            and capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_SNAPSHOT
        ),
    }


def volume_summary(path: os.PathLike[str] | str) -> dict[str, Any]:
    target = Path(path).resolve()
    usage = shutil.disk_usage(target)
    payload: dict[str, Any] = {
        "path": str(target),
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
    }

    mount_point = _mount_point_for_path(target) or str(target)
    diskutil_info = _diskutil_info(mount_point)
    if diskutil_info:
        mount_point = diskutil_info.get("MountPoint") or mount_point
        payload["mount_point"] = mount_point
        payload["filesystem_name"] = diskutil_info.get("FilesystemName")
        payload["filesystem_type"] = diskutil_info.get("FilesystemType")
        payload["volume_name"] = diskutil_info.get("VolumeName")
        payload["container_free_bytes"] = diskutil_info.get("APFSContainerFree")
        payload["container_size_bytes"] = diskutil_info.get("APFSContainerSize") or diskutil_info.get("TotalSize")
        payload["snapshot_count"] = _snapshot_count(mount_point)
    return payload


def summarize_targets(paths: Sequence[os.PathLike[str] | str], workers: int) -> list[dict[str, Any]]:
    targets = [os.fspath(path) for path in paths]
    if not targets:
        return []
    worker_count = max(1, min(workers, len(targets)))
    if worker_count == 1:
        return [summarize_target(path) for path in targets]
    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = [executor.submit(summarize_target, path) for path in targets]
        return [future.result() for future in futures]


def _du_command(root: Path, depth: int) -> tuple[str, list[str], int]:
    gnu_du = shutil.which("gdu")
    if gnu_du:
        return ("gdu", [gnu_du, "-B1", "-x", "-d", str(depth), str(root)], 1)
    if sys.platform == "darwin":
        return ("du", ["du", "-k", "-x", "-d", str(depth), str(root)], 1024)
    return ("du", ["du", "-k", "-x", f"--max-depth={depth}", str(root)], 1024)


def _path_is_within(path: str, parent: str) -> bool:
    normalized_path = os.path.normpath(path)
    normalized_parent = os.path.normpath(parent)
    if normalized_path == normalized_parent:
        return True
    return normalized_path.startswith(normalized_parent.rstrip(os.sep) + os.sep)


def _select_non_overlapping_candidates(candidates: Sequence[dict[str, Any]], top: int) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    covered: list[str] = []
    for candidate in candidates:
        path = str(candidate["path"])
        if any(_path_is_within(path, existing) for existing in covered):
            continue
        selected.append(candidate)
        covered.append(path)
        if len(selected) >= top:
            break
    return selected


def discover_logical_candidates(root: os.PathLike[str] | str, depth: int, top: int) -> dict[str, Any]:
    target = Path(root).resolve()
    tool_name, command, multiplier = _du_command(target, depth)
    result = _run_command(command)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "du failed")

    candidates: list[dict[str, Any]] = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        size_part, path_part = line.split("\t", 1)
        resolved_path = str(Path(path_part).resolve())
        if resolved_path == str(target):
            continue
        candidates.append(
            {
                "path": resolved_path,
                "du_bytes": int(size_part) * multiplier,
            }
        )
    candidates.sort(key=lambda item: item["du_bytes"], reverse=True)
    return {
        "tool": tool_name,
        "depth": depth,
        "candidates": _select_non_overlapping_candidates(candidates, top),
    }


def validate_top(root: os.PathLike[str] | str, depth: int, top: int, workers: int) -> dict[str, Any]:
    root_path = Path(root).resolve()
    discovery = discover_logical_candidates(root_path, depth, top)
    logical_candidates = discovery["candidates"]
    validated = summarize_targets([candidate["path"] for candidate in logical_candidates], workers)
    validated_candidates: list[dict[str, Any]] = []
    for candidate, summary in zip(logical_candidates, validated):
        merged = dict(summary)
        merged["du_candidate_bytes"] = candidate["du_bytes"]
        validated_candidates.append(merged)
    return {
        "root": str(root_path),
        "volume": volume_summary(root_path),
        "discovery": {
            "tool": discovery["tool"],
            "depth": discovery["depth"],
            "top": top,
        },
        "logical_candidates": logical_candidates,
        "validated_paths": validated,
        "validated_candidates": validated_candidates,
    }


def _print_volume_summary(summary: dict[str, Any]) -> None:
    print(f"Path: {summary['path']}")
    print(f"Total: {format_bytes(summary['total_bytes'])}")
    print(f"Used: {format_bytes(summary['used_bytes'])}")
    print(f"Free: {format_bytes(summary['free_bytes'])}")
    if summary.get("container_size_bytes") and summary.get("container_free_bytes") is not None:
        print(
            "APFS container: "
            f"{format_bytes(summary['container_size_bytes'])} total, "
            f"{format_bytes(summary['container_free_bytes'])} free"
        )
    if summary.get("filesystem_name"):
        print(f"Filesystem: {summary['filesystem_name']} ({summary.get('filesystem_type')})")
    if "snapshot_count" in summary and summary["snapshot_count"] is not None:
        print(f"Snapshot count: {summary['snapshot_count']}")


def _print_path_summary(summary: dict[str, Any]) -> None:
    print(summary["path"])
    print(
        "  "
        + ", ".join(
            [
                f"logical={format_bytes(summary['logical_bytes'])}",
                f"allocated={format_bytes(summary['allocated_bytes'])}",
                f"reclaimable_lower_bound={format_bytes(summary['reclaimable_bytes'])}",
                f"share_ratio={summary['reclaimable_ratio']:.0%}",
            ]
        )
    )
    print(
        "  "
        + ", ".join(
            [
                f"files={summary['file_count']}",
                f"dirs={summary['dir_count']}",
                f"shared_files={summary['may_share_blocks_files']}",
                f"external_clone_groups={summary['external_clone_groups']}",
                f"fully_contained_clone_groups={summary['fully_contained_clone_groups']}",
            ]
        )
    )
    for note in summary["notes"]:
        print(f"  note: {note}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fast APFS-aware disk usage validation for the disk-usage-audit skill.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    volume_parser = subparsers.add_parser("volume-summary", help="Report true free and used bytes for the relevant volume.")
    volume_parser.add_argument("path", nargs="?", default=".", help="Path used to resolve the backing volume.")
    volume_parser.add_argument("--json", action="store_true", help="Emit structured JSON.")

    path_parser = subparsers.add_parser(
        "path-summary",
        help="Summarize clone-aware reclaimability for one or more files or directories.",
    )
    path_parser.add_argument("paths", nargs="+", help="Paths to summarize.")
    path_parser.add_argument("--json", action="store_true", help="Emit structured JSON.")

    validate_parser = subparsers.add_parser(
        "validate-top",
        help="Use du for fast hotspot discovery, then run clone-aware validation on the top results.",
    )
    validate_parser.add_argument("root", help="Root directory to inspect.")
    validate_parser.add_argument("--depth", type=int, default=1, help="du depth to search before validation.")
    validate_parser.add_argument("--top", type=int, default=5, help="How many logical hotspots to validate.")
    validate_parser.add_argument(
        "--workers",
        type=int,
        default=min(4, os.cpu_count() or 1),
        help="Concurrent validation workers.",
    )
    validate_parser.add_argument("--json", action="store_true", help="Emit structured JSON.")

    path_parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Concurrent workers when summarizing multiple explicit paths.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "volume-summary":
        summary = volume_summary(args.path)
        if args.json:
            print(json.dumps(summary, indent=2, sort_keys=True))
        else:
            _print_volume_summary(summary)
        return 0

    if args.command == "path-summary":
        summaries = summarize_targets(args.paths, args.workers)
        if args.json:
            print(
                json.dumps(
                    {
                        "paths": summaries,
                        "totals": {
                            "logical_bytes": sum(summary["logical_bytes"] for summary in summaries),
                            "allocated_bytes": sum(summary["allocated_bytes"] for summary in summaries),
                            "private_bytes": sum(summary["private_bytes"] for summary in summaries),
                            "immediate_reclaim_bytes": sum(summary["immediate_reclaim_bytes"] for summary in summaries),
                        },
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
        else:
            for summary in summaries:
                _print_path_summary(summary)
        return 0

    if args.command == "validate-top":
        payload = validate_top(args.root, args.depth, args.top, args.workers)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            _print_volume_summary(payload["volume"])
            print()
            print(
                "Discovery: "
                f"{payload['discovery']['tool']} depth={payload['discovery']['depth']} "
                f"top={payload['discovery']['top']}"
            )
            print()
            print("Logical candidates")
            for candidate in payload["logical_candidates"]:
                print(f"  {candidate['path']}: du={format_bytes(candidate['du_bytes'])}")
            print()
            print("Clone-aware validation")
            for summary in payload["validated_candidates"]:
                _print_path_summary(summary)
        return 0

    parser.error("Unknown command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
