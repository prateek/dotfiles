#!/usr/bin/env python3
"""Resolve landing preferences; only explicit save/reset requests write configuration."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import tempfile


BUILTINS = {"review_gate": "auto", "deploy": False, "tests": "run"}
REVIEW_MODES = ("auto", "skip", "confirm")
TEST_MODES = ("run", "skip")


class Once(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if getattr(namespace, self.dest) is not None:
            parser.error(f"duplicate option: {option_string}")
        setattr(namespace, self.dest, self.const if self.nargs == 0 else values)


def arguments():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--repo-id", required=True, action=Once)
    parser.add_argument("--target", required=True, action=Once)
    parser.add_argument("--review-gate", choices=REVIEW_MODES, action=Once)
    parser.add_argument("--deploy", choices=("true", "false"), action=Once)
    parser.add_argument("--tests", choices=TEST_MODES, action=Once)
    mode = parser.add_mutually_exclusive_group()
    for flag in ("--save-defaults", "--show-defaults", "--reset-defaults"):
        mode.add_argument(flag, action=Once, nargs=0, const=True)
    args = parser.parse_args()
    explicit = {}
    if args.review_gate is not None:
        explicit["review_gate"] = args.review_gate
    if args.deploy is not None:
        explicit["deploy"] = args.deploy == "true"
    if args.tests is not None:
        explicit["tests"] = args.tests
    if args.save_defaults and not explicit:
        parser.error("--save-defaults requires an explicit --review-gate, --deploy, or --tests")
    if (args.show_defaults or args.reset_defaults) and explicit:
        parser.error("cannot combine --show-defaults/--reset-defaults with landing options")
    if ("/" not in args.repo_id or "://" in args.repo_id or "@" in args.repo_id
            or any(part in ("", ".", "..") for part in args.repo_id.split("/"))):
        parser.error("--repo-id must be the canonical host/repository-path, not a remote URL")
    if any(not value or any(c.isspace() or ord(c) < 32 for c in value)
           for value in (args.repo_id, args.target)):
        parser.error("repository identity and target must be nonempty and contain no whitespace")
    return parser, args, explicit


def defaults_path(repo_id, target):
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    if not base.is_absolute():
        raise ValueError("XDG_CONFIG_HOME must be absolute")
    identity = json.dumps([repo_id, target], ensure_ascii=True, separators=(",", ":"))
    key = hashlib.sha256(identity.encode()).hexdigest()
    return base / "land-changes" / "repos" / f"{key}.json"


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_defaults(path, repo_id, target):
    try:
        if path.is_symlink():
            raise ValueError("symlinked defaults file")
        data = json.loads(path.read_text(), object_pairs_hook=unique_object)
        if (not isinstance(data, dict) or set(data) != {"version", "repo_id", "target", "defaults"}
                or type(data["version"]) is not int or data["version"] != 1
                or data["repo_id"] != repo_id or data["target"] != target):
            raise ValueError("schema or repository/target mismatch")
        settings = data["defaults"]
        if not isinstance(settings, dict) or set(settings) - BUILTINS.keys():
            raise ValueError("unsupported preferences")
        if "deploy" in settings and type(settings["deploy"]) is not bool:
            raise ValueError("deploy must be a boolean")
        if "review_gate" in settings and settings["review_gate"] not in REVIEW_MODES:
            raise ValueError("unsupported review gate")
        if "tests" in settings and settings["tests"] not in TEST_MODES:
            raise ValueError("unsupported test mode")
        return settings
    except FileNotFoundError:
        return {}
    except (ValueError, UnicodeError) as error:
        raise ValueError(f"invalid defaults at {path}: {error}; use --reset-defaults to clear") from error


def write_defaults(path, repo_id, target, settings):
    data = {"version": 1, "repo_id": repo_id, "target": target, "defaults": settings}
    fd, temporary = tempfile.mkstemp(prefix=f".{path.stem}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def resolve(args, explicit):
    path = defaults_path(args.repo_id, args.target)
    if args.save_defaults or args.reset_defaults:
        for directory in (path.parent.parent, path.parent):
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        descriptor = os.open(path.with_suffix(".lock"), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.reset_defaults:
                path.unlink(missing_ok=True)
                saved = {}
            else:
                saved = read_defaults(path, args.repo_id, args.target) | explicit
                write_defaults(path, args.repo_id, args.target, saved)
    else:
        saved = read_defaults(path, args.repo_id, args.target)
    settings = BUILTINS | saved | explicit
    return {
        "repo_id": args.repo_id,
        "target": args.target,
        "settings": settings,
        "sources": {key: "argument" if key in explicit else "saved" if key in saved else "builtin"
                    for key in BUILTINS},
        "saved_defaults": saved,
        "defaults_path": str(path),
        "defaults_saved": bool(args.save_defaults),
        "action": "show_defaults" if args.show_defaults else "reset_defaults" if args.reset_defaults else "land",
    }


def main():
    parser, args, explicit = arguments()
    try:
        print(json.dumps(resolve(args, explicit), indent=2))
    except (OSError, ValueError) as error:
        parser.exit(1, f"options: {error}\n")


if __name__ == "__main__":
    main()
