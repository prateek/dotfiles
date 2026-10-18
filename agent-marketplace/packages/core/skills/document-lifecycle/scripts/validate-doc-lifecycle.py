#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Validate docs/ lifecycle frontmatter, retirement ledger, inventory, and locked-doc edit rules."""

from __future__ import annotations

import argparse
import datetime as dt
import io
import posixpath
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


STATUSES = {
    "draft",
    "proposed",
    "accepted",
    "active",
    "current",
    "superseded",
    "rejected",
    "archived",
}
CLOSED_STATUSES = {"archived", "superseded", "rejected"}
ALLOWED_DOC_TYPE_STATUSES = {
    "adr": {"proposed", "active", "accepted", "superseded", "rejected", "archived"},
    "plan": {"draft", "proposed", "accepted", "active", "superseded", "rejected", "archived"},
    "runbook": {"active", "current", "superseded", "archived"},
    "reference": {"active", "current", "superseded", "archived"},
    "research": {"draft", "active", "current", "superseded", "archived"},
    "convention": {"active", "current", "superseded", "archived"},
    "index": {"active", "current"},
}
DOC_TYPES = set(ALLOWED_DOC_TYPE_STATUSES)
ALLOWED_FRONTMATTER_KEYS = {
    "status",
    "doc_type",
    "summary",
    "owner",
    "created",
    "updated",
    "related",
    "superseded_by",
    "current_guidance",
    "closed",
    "status_detail",
}
ALLOWED_DOC_TYPE_TRANSITIONS = {
    ("plan", "reference"),
    ("plan", "runbook"),
}
LEDGER_NAME = "retired.md"
INVENTORY_NAME = "inventory.md"
INVENTORY_COMMAND = "python3 scripts/validate-doc-lifecycle.py --write-inventory"
REJECT_LEGACY_DEV = False
ALLOWED_NON_MARKDOWN: tuple[str, ...] = ()
LEDGER_COLUMNS = ("Closed", "Path", "Doc", "Status", "Where it went")
INDEX_FILES = {"index.md", INVENTORY_NAME, LEDGER_NAME}
PARKED_PREFIX = "parked"
DUE_AFTER_DAYS = 90
BANNER_PATTERN = re.compile(r"^> Superseded by \[[^\]]+\]\(([^)\s]+)\)\.?$")
INVENTORY_GROUPS = (
    ("convention", "Conventions", None),
    ("reference", "References", None),
    ("runbook", "Runbooks", None),
    ("plan", "Plans", "open"),
    ("plan", "Parked plans", "parked"),
    ("adr", "Decision records", None),
    ("research", "Research", None),
    ("index", "Indexes", None),
)


def split_frontmatter(text: str) -> tuple[str | None, str]:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        return None, text

    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "".join(lines[1:index]), "".join(lines[index + 1 :])

    return None, text


def clean_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def parse_inline_list(value: str) -> tuple[list[str], str | None]:
    if not value.endswith("]"):
        return [], "unterminated inline list"

    inner = value[1:-1].strip()
    if not inner:
        return [], None

    items: list[str] = []
    current: list[str] = []
    quote: str | None = None

    for character in inner:
        if quote:
            current.append(character)
            if character == quote:
                quote = None
            continue

        if character in {"'", '"'}:
            quote = character
            current.append(character)
        elif character == ",":
            items.append(clean_scalar("".join(current)))
            current = []
        else:
            current.append(character)

    if quote:
        return [], "unterminated quoted value in inline list"

    items.append(clean_scalar("".join(current)))
    return items, None


def parse_frontmatter(frontmatter: str) -> tuple[dict[str, object], list[str]]:
    data: dict[str, object] = {}
    errors: list[str] = []
    list_key: str | None = None

    for line_number, raw_line in enumerate(frontmatter.splitlines(), start=1):
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        if list_key and line.startswith("  - "):
            items = data.setdefault(list_key, [])
            if isinstance(items, list):
                items.append(clean_scalar(line[4:]))
            continue

        if line.startswith((" ", "\t")):
            errors.append(f"frontmatter line {line_number}: unsupported nested or indented value")
            continue

        list_key = None
        if ":" not in line:
            errors.append(f"frontmatter line {line_number}: expected key: value")
            continue

        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()

        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", key):
            errors.append(f"frontmatter line {line_number}: unsupported key {key!r}")
            continue

        if key in data:
            errors.append(f"frontmatter line {line_number}: duplicate key {key!r}")
            continue

        if not value:
            data[key] = []
            list_key = key
        elif value in {"|", ">"}:
            errors.append(f"frontmatter line {line_number}: block scalars are not supported")
        elif value.startswith("["):
            items, error = parse_inline_list(value)
            if error:
                errors.append(f"frontmatter line {line_number}: {error}")
            else:
                data[key] = items
        else:
            data[key] = clean_scalar(value)

    return data, errors


def markdown_files(docs_root: Path) -> list[Path]:
    return sorted(path for path in docs_root.rglob("*.md") if path.is_file())


def git_check_ignore(root: Path, path: Path) -> bool:
    try:
        rel = path.relative_to(root)
    except ValueError:
        return False

    result = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "-q", "--", rel.as_posix()],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def is_research_data_file(docs_root: Path, path: Path) -> bool:
    parts = path.relative_to(docs_root).parts
    return len(parts) > 3 and parts[0] == "research" and parts[2] == "data"


def non_markdown_content_files(root: Path, docs_root: Path) -> list[Path]:
    allowed = {docs_root / relative for relative in ALLOWED_NON_MARKDOWN}
    return sorted(
        path
        for path in docs_root.rglob("*")
        if path.is_file() and path.suffix != ".md" and path not in allowed
        and not is_research_data_file(docs_root, path)
        and not git_check_ignore(root, path)
    )


def read_doc(path: Path) -> tuple[dict[str, object], str | None, str, list[str]]:
    text = path.read_text(encoding="utf-8")
    frontmatter, body = split_frontmatter(text)
    if frontmatter is None:
        return {}, None, body, []
    meta, errors = parse_frontmatter(frontmatter)
    return meta, frontmatter, body, errors


def git_show(root: Path, base_ref: str, relative_path: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{base_ref}:{relative_path}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def git_ref_exists(root: Path, ref: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def git_merge_base(root: Path, ref: str, head_ref: str = "HEAD") -> str | None:
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", ref, head_ref],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def git_commit_parents(root: Path, ref: str = "HEAD") -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-list", "--parents", "-n", "1", ref],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0:
        return []
    parts = result.stdout.split()
    return parts[1:]


def git_base_markdown_paths(root: Path, docs_root: Path, base_ref: str) -> list[str]:
    docs_rel = docs_root.relative_to(root)
    result = subprocess.run(
        ["git", "-C", str(root), "ls-tree", "-r", "--name-only", base_ref, "--", str(docs_rel)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        return []
    return sorted(line for line in result.stdout.splitlines() if line.endswith(".md"))



def doc_identity_preserved(old_rel: str, new_rel: str) -> bool:
    if posixpath.basename(old_rel) == posixpath.basename(new_rel):
        return True
    old_adr, new_adr = adr_number(old_rel), adr_number(new_rel)
    return bool(old_adr and new_adr and old_adr == new_adr)


def infer_identity_renames(
    changes: list[tuple[str, str | None, str | None]],
) -> list[tuple[str, str | None, str | None]]:
    used: set[int] = set()
    inferred: dict[int, tuple[str, str, str]] = {}
    additions = [
        (index, new_rel)
        for index, (kind, _old_rel, new_rel) in enumerate(changes)
        if kind == "A" and new_rel
    ]

    for delete_index, (kind, old_rel, _new_rel) in enumerate(changes):
        if kind != "D" or not old_rel:
            continue
        matches = [
            (add_index, add_rel)
            for add_index, add_rel in additions
            if add_index not in used and doc_identity_preserved(old_rel, add_rel)
        ]
        if len(matches) != 1:
            continue

        add_index, add_rel = matches[0]
        used.update({delete_index, add_index})
        inferred[delete_index] = ("R", old_rel, add_rel)

    normalized: list[tuple[str, str | None, str | None]] = []
    for index, change in enumerate(changes):
        if index in inferred:
            normalized.append(inferred[index])
        elif index not in used:
            normalized.append(change)
    return normalized


def git_changed_markdown_paths(
    root: Path,
    docs_root: Path,
    old_ref: str,
    new_ref: str | None = None,
) -> list[tuple[str, str | None, str | None]]:
    docs_rel = docs_root.relative_to(root)
    command = [
        "git",
        "-C",
        str(root),
        "diff",
        "--find-renames",
        "--name-status",
        old_ref,
    ]
    if new_ref:
        command.append(new_ref)
    command.extend(["--", str(docs_rel)])
    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        return []

    changes: list[tuple[str, str | None, str | None]] = []
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) == 3 and parts[0].startswith("R"):
            old_rel, new_rel = parts[1], parts[2]
            if old_rel.endswith(".md") and new_rel.endswith(".md"):
                changes.append(("R", old_rel, new_rel))
        elif len(parts) == 2:
            status, rel = parts
            if not rel.endswith(".md"):
                continue
            kind = status[0]
            if kind == "A":
                changes.append((kind, None, rel))
            elif kind == "D":
                changes.append((kind, rel, None))
            else:
                changes.append((kind, rel, rel))
    return infer_identity_renames(changes)


def git_renamed_markdown_paths(
    root: Path,
    docs_root: Path,
    old_ref: str,
    new_ref: str | None = None,
) -> dict[str, str]:
    renames: dict[str, str] = {}
    for kind, old_rel, new_rel in git_changed_markdown_paths(root, root, old_ref, new_ref):
        if kind == "R" and old_rel and new_rel:
            renames[old_rel] = new_rel
    return renames


def git_commits_since(root: Path, base_ref: str, head_ref: str = "HEAD") -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-list", "--reverse", f"{base_ref}..{head_ref}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0:
        return []
    return result.stdout.splitlines()


def validate_tree_at_commit(root: Path, docs_root: Path, commit: str) -> list[str]:
    docs_rel = docs_root.relative_to(root).as_posix()
    result = subprocess.run(
        ["git", "-C", str(root), "archive", "--format=tar", commit],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return [f"{commit[:12]}: unable to read docs tree"]

    with tempfile.TemporaryDirectory(prefix="docs-lifecycle-") as tmp:
        tmp_root = Path(tmp).resolve()
        with tarfile.open(fileobj=io.BytesIO(result.stdout), mode="r:") as archive:
            archive.extractall(tmp_root, filter="data")

        errors = validate_current_tree(tmp_root, tmp_root / docs_rel)
        return [f"{commit[:12]}: {error}" for error in errors]


def body_locked(meta: dict[str, object]) -> bool:
    status = meta.get("status")
    doc_type = meta.get("doc_type")
    return isinstance(status, str) and (
        status in CLOSED_STATUSES or (doc_type == "adr" and status == "accepted")
    )


def as_list(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for item in value if isinstance(item, str)]
    return []


def non_empty_targets(value: object) -> list[str]:
    return [item for item in as_list(value) if item.strip()]


def non_empty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def adr_number(rel: str) -> str | None:
    match = re.search(r"(?:^|/)adr/(\d{4})-[^/]+\.md$", rel)
    return match.group(1) if match else None


def is_parked(meta: dict[str, object]) -> bool:
    detail = scalar(meta.get("status_detail")) or ""
    return (
        meta.get("doc_type") == "plan"
        and meta.get("status") == "draft"
        and detail.strip().lower().startswith(PARKED_PREFIX)
    )


def table_cells(line: str) -> list[str] | None:
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return None
    return [cell.strip() for cell in stripped[1:-1].split("|")]



def ledger_rows(body: str, docs_prefix: str) -> tuple[list[dict[str, str]], list[str]]:
    rows: list[dict[str, str]] = []
    errors: list[str] = []
    header_seen = False
    keys = tuple(column.split()[0].lower() for column in LEDGER_COLUMNS)
    for line_number, line in enumerate(body.splitlines(), start=1):
        cells = table_cells(line)
        if cells is None:
            continue
        if not header_seen:
            if tuple(cells) != LEDGER_COLUMNS:
                errors.append(
                    f"line {line_number}: ledger table must have columns "
                    + " | ".join(LEDGER_COLUMNS)
                )
                return rows, errors
            header_seen = True
            continue
        if all(set(cell) <= {"-", ":"} for cell in cells):
            continue
        if len(cells) != len(LEDGER_COLUMNS):
            errors.append(f"line {line_number}: ledger row must have {len(LEDGER_COLUMNS)} cells")
            continue
        row = dict(zip(keys, cells))
        if not valid_iso_date(row["closed"]):
            errors.append(f"line {line_number}: ledger Closed must be an ISO date: YYYY-MM-DD")
        if row["status"] not in CLOSED_STATUSES:
            errors.append(
                f"line {line_number}: ledger Status must be one of {', '.join(sorted(CLOSED_STATUSES))}"
            )
        path = row["path"].strip("`")
        if not path.endswith(".md") or path.startswith(("/", "../", docs_prefix)):
            errors.append(f"line {line_number}: ledger Path must be relative to {docs_prefix}: {row['path']}")
        row["path"] = path
        rows.append(row)
    if not header_seen:
        errors.append("ledger must contain a table with columns " + " | ".join(LEDGER_COLUMNS))
    return rows, errors



def ledger_rel(root: Path, docs_root: Path) -> str:
    return (docs_root / LEDGER_NAME).relative_to(root).as_posix()


def ledger_state(root: Path, docs_root: Path, ref: str | None) -> tuple[list[dict[str, str]], list[str]]:
    """Rows and row errors of the ledger at a git ref, or in the worktree when ref is None."""
    state = doc_state_for_ref(root, ref, ledger_rel(root, docs_root))
    if state is None:
        return [], []
    _meta, body, _errors = state
    return ledger_rows(body, docs_root.relative_to(root).as_posix() + "/")


def ledger_paths(rows: list[dict[str, str]]) -> set[str]:
    return {row["path"] for row in rows}



def docs_relative(root: Path, docs_root: Path, rel: str) -> str | None:
    docs_rel = docs_root.relative_to(root).as_posix()
    return rel[len(docs_rel) + 1 :] if rel.startswith(docs_rel + "/") else None



def retired_link_target(root: Path, docs_root: Path, doc_path: Path, target: str, retired: set[str]) -> bool:
    repo_rel = repo_relative_link_path(doc_path.relative_to(root).as_posix(), target)
    return repo_rel is not None and docs_relative(root, docs_root, repo_rel) in retired



def deletion_errors(
    root: Path,
    docs_root: Path,
    old_rel: str,
    retired: set[str],
) -> list[str]:
    if adr_number(old_rel):
        return [f"{old_rel}: ADRs cannot be deleted; supersede or archive them instead"]
    docs_path = docs_relative(root, docs_root, old_rel) or old_rel
    if docs_path not in retired:
        return [f"{old_rel}: deleted doc needs a retirement row in {ledger_rel(root, docs_root)} for {docs_path}"]
    return []


def strip_supersession_banner(
    old_body: str,
    new_body: str,
    new_meta: dict[str, object],
) -> str:
    """Drop a newly inserted banner under the H1 whose target matches superseded_by; any other edit stays for the body comparison to reject."""
    if new_meta.get("status") != "superseded":
        return new_body
    successors = non_empty_targets(new_meta.get("superseded_by"))
    old_lines = old_body.splitlines(keepends=True)
    new_lines = new_body.splitlines(keepends=True)
    h1 = next((index for index, line in enumerate(new_lines) if line.startswith("# ")), None)
    if h1 is None or h1 + 2 >= len(new_lines) or new_lines[h1 + 1].strip():
        return new_body
    banner_index = h1 + 2
    match = BANNER_PATTERN.match(new_lines[banner_index].rstrip("\n"))
    if not match or match.group(1) not in successors or new_lines[banner_index] in old_lines:
        return new_body
    stripped = new_lines[:banner_index] + new_lines[banner_index + 1 :]
    if banner_index < len(stripped) and not stripped[banner_index].strip():
        del stripped[banner_index]
    return "".join(stripped)


def doc_title(body: str) -> str:
    for line in body.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def inventory_cell(text: str) -> str:
    return " ".join(text.split()).replace("|", "\\|")



def inventory_links(doc_rel: str, docs_rel: str, targets: list[str]) -> str:
    rendered: list[str] = []
    for target in targets:
        _path_part, anchor = split_link_target(target)
        repo_rel = repo_relative_link_path(doc_rel, target)
        if repo_rel is None:
            rendered.append(f"[{target}]({target})")
            continue
        rendered.append(f"[{repo_rel}]({posixpath.relpath(repo_rel, docs_rel)}{anchor})")
    return ", ".join(rendered)



def read_docs(root: Path, docs_root: Path) -> list[tuple[Path, dict[str, object], str | None, str, list[str]]]:
    return [(path, *read_doc(path)) for path in markdown_files(docs_root)]


def render_inventory(root: Path, docs_root: Path, docs: list[tuple[Path, dict[str, object], str | None, str, list[str]]]) -> str:
    docs_rel = docs_root.relative_to(root).as_posix()
    lines = [
        "---",
        "status: current",
        "doc_type: index",
        f'summary: "Every document under {docs_rel}/ with its status and summary, generated from frontmatter by {INVENTORY_COMMAND}."',
        "---",
        "",
        "# Documentation Inventory",
        "",
        f"Generated by `{INVENTORY_COMMAND}` from each document's frontmatter and title; do not edit by hand.",
    ]
    if (docs_root / LEDGER_NAME).is_file():
        lines.append(f"Retired documents are listed in the [retirement ledger]({LEDGER_NAME}).")

    entries: list[tuple[str, str, dict[str, object], str, str]] = []
    for path, meta, _frontmatter, body, _errors in docs:
        rel = path.relative_to(docs_root).as_posix()
        if rel == INVENTORY_NAME:
            continue
        doc_type = scalar(meta.get("doc_type")) or ""
        bucket = "parked" if is_parked(meta) else "open"
        entries.append((rel, doc_type, meta, bucket, doc_title(body) or rel))

    for doc_type, heading, subset in INVENTORY_GROUPS:
        rows = []
        for rel, entry_type, meta, bucket, title in entries:
            if entry_type != doc_type or subset not in (None, bucket):
                continue
            successors = non_empty_targets(meta.get("superseded_by")) + non_empty_targets(meta.get("current_guidance"))
            cells = (
                f"[{inventory_cell(title)}]({rel})",
                scalar(meta.get("status")) or "",
                inventory_cell(scalar(meta.get("summary")) or ""),
                inventory_links(posixpath.join(docs_rel, rel), docs_rel, successors),
            )
            rows.append("| " + " | ".join(cells) + " |")
        if rows:
            lines.extend(["", f"## {heading}", "", "| Doc | Status | Summary | Successor or guidance |", "| --- | --- | --- | --- |", *rows])
    untyped = [rel for rel, entry_type, *_rest in entries if entry_type not in DOC_TYPES]
    if untyped:
        lines.extend(["", "## Untyped", "", *(f"- [{rel}]({rel})" for rel in untyped)])
    return "\n".join(lines) + "\n"



def git_commit_dates(root: Path, docs_root: Path) -> dict[str, tuple[dt.date, dt.date]]:
    """Per repo-relative path: (date first added, date last changed), from one git log walk."""
    result = subprocess.run(
        ["git", "-C", str(root), "log", "--format=%cs", "--name-only", "--diff-filter=AM", "--no-renames",
         "--", docs_root.relative_to(root).as_posix()],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    dates: dict[str, tuple[dt.date, dt.date]] = {}
    current: dt.date | None = None
    for line in result.stdout.splitlines():
        if valid_iso_date(line):
            current = dt.date.fromisoformat(line)
        elif line and current:
            last = dates[line][1] if line in dates else current
            dates[line] = (current, last)
    return dates



def due_report(root: Path, docs_root: Path, today: dt.date | None = None) -> list[str]:
    today = today or dt.date.today()
    cutoff = today - dt.timedelta(days=DUE_AFTER_DAYS)
    dates = git_commit_dates(root, docs_root)
    states = {path.relative_to(root).as_posix(): meta for path, meta, *_rest in read_docs(root, docs_root)}

    def settled(meta: dict[str, object]) -> bool:
        return meta.get("status") in CLOSED_STATUSES or (
            meta.get("doc_type") == "adr" and meta.get("status") == "accepted"
        )

    parked: list[str] = []
    stale: list[str] = []
    research: list[str] = []
    for rel, meta in sorted(states.items()):
        if meta.get("status") in CLOSED_STATUSES or rel not in dates:
            continue
        added, changed = dates[rel]
        doc_type = scalar(meta.get("doc_type"))
        if doc_type == "plan" and changed <= cutoff:
            if is_parked(meta):
                parked.append(f"{rel}: parked, last commit {changed}; resume it or close it as rejected and retire it")
            else:
                stale.append(f"{rel}: open, last commit {changed}; finish it, park it, or close it")
        elif doc_type == "research":
            consumers = [
                target_rel
                for target in non_empty_targets(meta.get("related"))
                if (target_rel := repo_relative_link_path(rel, target)) in states
                and states[target_rel].get("doc_type") in {"plan", "adr"}
            ]
            if not consumers and added <= cutoff:
                research.append(f"{rel}: no plan or ADR consumer in related, added {added}; name one or retire it")
            elif consumers and all(settled(states[target_rel]) for target_rel in consumers):
                research.append(
                    f"{rel}: every consumer is settled ({', '.join(consumers)}); retire it once they cite what they used"
                )

    lines: list[str] = []
    for heading, items in (
        ("Parked plans past a quarter", parked),
        ("Open plans with no commit in a quarter", stale),
        ("Research due for a decision", research),
    ):
        lines.append(f"{heading}: {len(items)}")
        lines.extend(f"- {item}" for item in items)
    return lines


def target_exists(root: Path, doc_path: Path, value: str) -> bool:
    target = value.split("#", 1)[0].strip()
    if not target:
        return False
    if target.startswith(("http://", "https://", "mailto:", "~", "/")):
        return False
    resolved = (doc_path.parent / target).resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        return False
    return resolved.exists()


def markdown_links_detailed(text: str) -> list[dict[str, object]]:
    links: list[dict[str, object]] = []
    for match in re.finditer(r"(?<!!)\[([^\]]+)\]\(([^)]+)\)", text):
        target = match.group(2).strip()
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1].strip()
        elif " " in target:
            target = target.split(" ", 1)[0].strip()
        links.append(
            {
                "full_span": match.span(0),
                "label_span": match.span(1),
                "target_span": match.span(2),
                "target": target,
            }
        )
    return links


def markdown_links(text: str) -> list[tuple[tuple[int, int], str]]:
    links: list[tuple[tuple[int, int], str]] = []
    for link in markdown_links_detailed(text):
        target_span = link["target_span"]
        target = link["target"]
        if isinstance(target_span, tuple) and isinstance(target, str):
            links.append((target_span, target))
    return links


def markdown_link_targets(text: str) -> list[str]:
    return [target for _span, target in markdown_links(text)]


def without_fenced_code_blocks(text: str) -> str:
    lines: list[str] = []
    fence: str | None = None

    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if fence:
            if stripped.startswith(fence):
                fence = None
            lines.append("\n" if line.endswith("\n") else "")
            continue

        if stripped.startswith(("```", "~~~")):
            fence = stripped[:3]
            lines.append("\n" if line.endswith("\n") else "")
        else:
            lines.append(line)

    return "".join(lines)


def should_validate_repo_link(target: str) -> bool:
    path_part = target.split("#", 1)[0].strip()
    if not path_part:
        return False
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target):
        return False
    return not target.startswith(("~", "/"))


def split_link_target(target: str) -> tuple[str, str]:
    path_part, separator, anchor = target.partition("#")
    return path_part.strip(), f"{separator}{anchor}" if separator else ""


def repo_relative_link_path(doc_rel: str, target: str) -> str | None:
    path_part, _anchor = split_link_target(target)
    if not path_part or not should_validate_repo_link(target):
        return None
    return posixpath.normpath(posixpath.join(posixpath.dirname(doc_rel), path_part))


def markdown_link_label(body: str, link: dict[str, object]) -> str | None:
    label_span = link["label_span"]
    if not isinstance(label_span, tuple):
        return None
    return body[label_span[0] : label_span[1]]


def link_label_path(label: str) -> str:
    label_path = label.strip()
    if len(label_path) >= 2 and label_path[0] == label_path[-1] == "`":
        label_path = label_path[1:-1]
    return label_path


def link_label_matches_target_path(doc_rel: str, target: str, label: str) -> bool:
    target_path, _target_anchor = split_link_target(target)
    candidates = {target_path}
    repo_target = repo_relative_link_path(doc_rel, target)
    if repo_target:
        candidates.add(repo_target)
    return link_label_path(label) in candidates


def link_labels_compatible(
    old_doc_rel: str,
    new_doc_rel: str,
    old_body: str,
    new_body: str,
    old_link: dict[str, object],
    new_link: dict[str, object],
) -> tuple[bool, str]:
    old_label = markdown_link_label(old_body, old_link)
    new_label = markdown_link_label(new_body, new_link)
    old_target = old_link["target"]
    new_target = new_link["target"]
    if (
        old_label is None
        or new_label is None
        or not isinstance(old_target, str)
        or not isinstance(new_target, str)
    ):
        return False, ""

    if old_label == new_label:
        return True, old_label

    if link_label_matches_target_path(
        old_doc_rel,
        old_target,
        old_label,
    ) and link_label_matches_target_path(new_doc_rel, new_target, new_label):
        return True, "<LINK_TARGET_LABEL>"

    return False, ""


def link_targets_preserved(
    old_doc_rel: str,
    new_doc_rel: str,
    old_links: list[dict[str, object]],
    new_links: list[dict[str, object]],
    renamed_paths: dict[str, str],
) -> bool:
    if len(old_links) != len(new_links):
        return False

    for old_link, new_link in zip(old_links, new_links):
        old_target = old_link["target"]
        new_target = new_link["target"]
        if not isinstance(old_target, str) or not isinstance(new_target, str):
            return False

        old_target_rel = repo_relative_link_path(old_doc_rel, old_target)
        new_target_rel = repo_relative_link_path(new_doc_rel, new_target)
        if old_target_rel is None or new_target_rel is None:
            if old_target == new_target:
                continue
            return False

        _old_path, old_anchor = split_link_target(old_target)
        _new_path, new_anchor = split_link_target(new_target)
        if old_anchor != new_anchor:
            return False

        if renamed_paths.get(old_target_rel, old_target_rel) != new_target_rel:
            return False

    return True


def body_change_is_link_target_repair(
    old_doc_rel: str,
    new_doc_rel: str,
    old_body: str,
    new_body: str,
    renamed_paths: dict[str, str],
) -> bool:
    old_links = markdown_links_detailed(old_body)
    new_links = markdown_links_detailed(new_body)
    if len(old_links) != len(new_links):
        return False

    if not link_targets_preserved(
        old_doc_rel,
        new_doc_rel,
        old_links,
        new_links,
        renamed_paths,
    ):
        return False

    old_pieces: list[str] = []
    new_pieces: list[str] = []
    old_end = 0
    new_end = 0

    for old_link, new_link in zip(old_links, new_links):
        old_span = old_link["full_span"]
        new_span = new_link["full_span"]
        if not isinstance(old_span, tuple) or not isinstance(new_span, tuple):
            return False

        labels_compatible, label = link_labels_compatible(
            old_doc_rel,
            new_doc_rel,
            old_body,
            new_body,
            old_link,
            new_link,
        )
        if not labels_compatible:
            return False

        old_pieces.append(old_body[old_end : old_span[0]])
        new_pieces.append(new_body[new_end : new_span[0]])
        old_pieces.append(f"[{label}](<LINK_TARGET>)")
        new_pieces.append(f"[{label}](<LINK_TARGET>)")
        old_end = old_span[1]
        new_end = new_span[1]

    old_pieces.append(old_body[old_end:])
    new_pieces.append(new_body[new_end:])
    return "".join(old_pieces) == "".join(new_pieces)


def committed_closure_preserved_body(
    root: Path,
    docs_root: Path,
    base_ref: str,
    head_ref: str,
    old_rel: str,
    current_rel: str,
    current_body: str,
    old_status: object,
    old_body: str,
    renamed_paths: dict[str, str],
) -> bool:
    prev_rel = old_rel
    prev_status = old_status
    prev_body = old_body
    previous_ref = base_ref

    for commit in git_commits_since(root, base_ref, head_ref):
        changes = git_changed_markdown_paths(root, docs_root, previous_ref, commit)
        step_renames = {
            old: new
            for kind, old, new in changes
            if kind == "R" and old and new
        }
        rel = step_renames.get(prev_rel, prev_rel)
        state: tuple[str, str, str] | None = None

        text = git_show(root, commit, rel)
        if text is not None:
            frontmatter, body = split_frontmatter(text)
            if frontmatter is not None:
                meta, _errors = parse_frontmatter(frontmatter)
                status = scalar(meta.get("status"))
                if status:
                    state = (rel, status, body)

        if state is None:
            previous_ref = commit
            continue

        rel, status, body = state
        if (
            isinstance(prev_status, str)
            and prev_status not in CLOSED_STATUSES
            and status in CLOSED_STATUSES
        ):
            if body == prev_body or body_change_is_link_target_repair(
                prev_rel,
                rel,
                prev_body,
                body,
                step_renames,
            ):
                return current_body == body or body_change_is_link_target_repair(
                    rel,
                    current_rel,
                    body,
                    current_body,
                    renamed_paths,
                )
            return False

        prev_rel = rel
        prev_status = status
        prev_body = body
        previous_ref = commit

    return False


def valid_iso_date(value: object) -> bool:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return False
    try:
        dt.date.fromisoformat(value)
    except ValueError:
        return False
    return True


def validate_doc_type_status(rel: str, status: object, doc_type: object) -> list[str]:
    if not isinstance(status, str) or status not in STATUSES:
        return []
    if not isinstance(doc_type, str) or doc_type not in DOC_TYPES:
        return []
    if status in ALLOWED_DOC_TYPE_STATUSES[doc_type]:
        return []

    if doc_type == "plan" and status == "current":
        return [
            f"{rel}: completed plans must be archived or superseded; "
            "move live guidance to a current reference/runbook"
        ]
    if doc_type == "adr" and status == "current":
        return [
            f"{rel}: ADRs must not use status 'current'; "
            "use an accepted ADR plus a current reference/runbook"
        ]
    if doc_type == "index":
        return [f"{rel}: doc_type index must use status active or current"]

    allowed = ", ".join(sorted(ALLOWED_DOC_TYPE_STATUSES[doc_type]))
    return [
        f"{rel}: doc_type {doc_type!r} cannot use status {status!r}; "
        f"allowed statuses: {allowed}"
    ]



def scalar(value: object) -> str | None:
    return value if isinstance(value, str) else None


def git_doc_state(
    root: Path,
    ref: str,
    rel: str,
) -> tuple[dict[str, object], str, list[str]] | None:
    text = git_show(root, ref, rel)
    if text is None:
        return None
    frontmatter, body = split_frontmatter(text)
    if frontmatter is None:
        return {}, body, ["missing YAML frontmatter"]
    meta, errors = parse_frontmatter(frontmatter)
    return meta, body, errors


def worktree_doc_state(root: Path, rel: str) -> tuple[dict[str, object], str, list[str]] | None:
    path = root / rel
    if not path.is_file():
        return None
    meta, frontmatter, body, errors = read_doc(path)
    if frontmatter is None:
        return {}, body, ["missing YAML frontmatter"]
    return meta, body, errors


def doc_state_for_ref(
    root: Path,
    ref: str | None,
    rel: str,
) -> tuple[dict[str, object], str, list[str]] | None:
    if ref is None:
        return worktree_doc_state(root, rel)
    return git_doc_state(root, ref, rel)


def validate_closed_additions_against_open_deletions(
    root: Path,
    docs_root: Path,
    old_ref: str,
    new_ref: str | None = None,
) -> list[str]:
    changes = git_changed_markdown_paths(root, docs_root, old_ref, new_ref)
    if new_ref is None:
        base_paths = set(git_base_markdown_paths(root, docs_root, old_ref))
        seen_new_paths = {new_rel for _kind, _old_rel, new_rel in changes if new_rel}
        for path in markdown_files(docs_root):
            rel = path.relative_to(root).as_posix()
            if rel not in base_paths and rel not in seen_new_paths:
                changes.append(("A", None, rel))

    deleted_open: list[str] = []
    added_closed: list[str] = []

    for kind, old_rel, new_rel in changes:
        if kind == "D" and old_rel:
            old_state = git_doc_state(root, old_ref, old_rel)
            if old_state is None:
                continue
            old_meta, _old_body, old_errors = old_state
            if old_errors:
                continue
            if not body_locked(old_meta):
                deleted_open.append(old_rel)
        elif kind == "A" and new_rel:
            new_state = doc_state_for_ref(root, new_ref, new_rel)
            if new_state is None:
                continue
            new_meta, _new_body, new_errors = new_state
            if new_errors:
                continue
            if scalar(new_meta.get("status")) in CLOSED_STATUSES:
                added_closed.append(new_rel)

    if not deleted_open or not added_closed:
        return []

    deleted = ", ".join(deleted_open)
    return [
        f"{new_rel}: closed doc added while deleting open doc(s): {deleted}; "
        "use a detected rename so closure body edits can be validated"
        for new_rel in added_closed
    ]


def validate_historical_doc_state(
    rel: str,
    meta: dict[str, object],
    body: str,
    parse_errors: list[str],
) -> list[str]:
    errors = [f"{rel}: {error}" for error in parse_errors]
    if errors:
        return errors

    status = scalar(meta.get("status"))
    doc_type = scalar(meta.get("doc_type"))

    if status not in STATUSES:
        errors.append(f"{rel}: status must be one of {', '.join(sorted(STATUSES))}")

    if "doc_type" in meta and doc_type not in DOC_TYPES:
        errors.append(f"{rel}: doc_type must be one of {', '.join(sorted(DOC_TYPES))}")

    errors.extend(validate_doc_type_status(rel, status, doc_type))

    if status in CLOSED_STATUSES and "closed" not in meta:
        errors.append(f"{rel}: status {status!r} requires closed: YYYY-MM-DD")
    elif status in CLOSED_STATUSES and not valid_iso_date(meta.get("closed")):
        errors.append(f"{rel}: closed must be an ISO date: YYYY-MM-DD")
    elif "closed" in meta and status not in CLOSED_STATUSES:
        errors.append(f"{rel}: closed is only valid for archived, superseded, or rejected docs")

    if status == "superseded" and "superseded_by" not in meta:
        errors.append(f"{rel}: status 'superseded' requires superseded_by")
    elif status == "superseded" and not non_empty_targets(meta.get("superseded_by")):
        errors.append(f"{rel}: status 'superseded' requires non-empty superseded_by")

    if status == "archived" and "current_guidance" not in meta:
        errors.append(f"{rel}: status 'archived' requires current_guidance")
    elif status == "archived" and not non_empty_targets(meta.get("current_guidance")):
        errors.append(f"{rel}: status 'archived' requires non-empty current_guidance")

    if status == "rejected" and not (
        non_empty_targets(meta.get("current_guidance"))
        or non_empty_string(meta.get("status_detail"))
    ):
        errors.append(f"{rel}: status 'rejected' requires current_guidance or status_detail")

    if not body.lstrip().startswith("# "):
        errors.append(f"{rel}: Markdown body must start with an H1 after frontmatter")

    return errors


def validate_historical_doc_change(
    docs_root: Path,
    old_rel: str,
    new_rel: str,
    old_meta: dict[str, object],
    old_body: str,
    new_meta: dict[str, object],
    new_body: str,
    renamed_paths: dict[str, str],
    base_label: str,
    allow_committed_closure: bool = False,
    root: Path | None = None,
    base_ref: str | None = None,
    head_ref: str = "HEAD",
) -> list[str]:
    errors: list[str] = []
    old_status = scalar(old_meta.get("status"))
    new_status = scalar(new_meta.get("status"))
    old_doc_type = scalar(old_meta.get("doc_type"))
    new_doc_type = scalar(new_meta.get("doc_type"))

    if old_status != new_status and old_status in CLOSED_STATUSES and new_status not in CLOSED_STATUSES:
        errors.append(f"{new_rel}: closed docs stay closed; revived work gets a new doc")
    elif old_doc_type == "adr" and old_status == "accepted" and new_status not in {"accepted", *CLOSED_STATUSES}:
        errors.append(f"{new_rel}: accepted ADRs can only remain accepted or close")

    if (
        old_doc_type != new_doc_type
        and isinstance(old_doc_type, str)
        and isinstance(new_doc_type, str)
        and (old_doc_type, new_doc_type) not in ALLOWED_DOC_TYPE_TRANSITIONS
    ):
        errors.append(
            f"{new_rel}: invalid doc_type transition {old_doc_type!r} -> {new_doc_type!r}"
        )

    locked_body = body_locked(old_meta) or new_status in CLOSED_STATUSES
    if locked_body:
        new_body = strip_supersession_banner(old_body, new_body, new_meta)
    if (
        locked_body
        and old_body == new_body
        and old_rel != new_rel
        and not link_targets_preserved(
            old_rel,
            new_rel,
            markdown_links_detailed(old_body),
            markdown_links_detailed(new_body),
            renamed_paths,
        )
    ):
        errors.append(f"{new_rel}: locked doc move must preserve Markdown link targets")

    if locked_body and old_body != new_body:
        link_repair = body_change_is_link_target_repair(
            old_rel,
            new_rel,
            old_body,
            new_body,
            renamed_paths,
        )
        committed_closure = (
            allow_committed_closure
            and root is not None
            and base_ref is not None
            and not body_locked(old_meta)
            and new_status in CLOSED_STATUSES
            and committed_closure_preserved_body(
                root,
                docs_root,
                base_ref,
                head_ref,
                old_rel,
                new_rel,
                new_body,
                old_status,
                old_body,
                renamed_paths,
            )
        )
        if not (link_repair or committed_closure):
            if body_locked(old_meta):
                reason = f"{base_label} has status={old_status!r}"
            else:
                reason = "this change closes the doc"
            errors.append(f"{new_rel}: body edits are blocked because {reason}")

    return errors


def validate_commit_against_parent(
    root: Path,
    docs_root: Path,
    previous_ref: str,
    commit: str,
) -> list[str]:
    errors: list[str] = []
    errors.extend(
        validate_closed_additions_against_open_deletions(
            root,
            docs_root,
            previous_ref,
            commit,
        )
    )

    changes = git_changed_markdown_paths(root, docs_root, previous_ref, commit)
    renamed_paths = git_renamed_markdown_paths(root, docs_root, previous_ref, commit)

    for _kind, old_rel, new_rel in changes:
        old_state = git_doc_state(root, previous_ref, old_rel) if old_rel else None
        new_state = git_doc_state(root, commit, new_rel) if new_rel else None

        if old_state is None:
            if new_rel and new_state is not None:
                new_meta, new_body, new_errors = new_state
                errors.extend(
                    validate_historical_doc_state(
                        new_rel,
                        new_meta,
                        new_body,
                        new_errors,
                    )
                )
            continue
        old_meta, old_body, old_errors = old_state
        if old_errors:
            errors.extend(
                validate_historical_doc_state(
                    old_rel or "",
                    old_meta,
                    old_body,
                    old_errors,
                )
            )
            continue

        if new_state is None or (
            old_rel
            and new_rel
            and old_rel != new_rel
            and body_locked(old_meta)
            and not doc_identity_preserved(old_rel, new_rel)
        ):
            continue

        if new_rel is None:
            continue
        new_meta, new_body, new_errors = new_state
        if new_errors:
            errors.extend(
                validate_historical_doc_state(
                    new_rel,
                    new_meta,
                    new_body,
                    new_errors,
                )
            )
            continue
        errors.extend(validate_historical_doc_state(new_rel, new_meta, new_body, []))
        errors.extend(
            validate_historical_doc_change(
                docs_root,
                old_rel or new_rel,
                new_rel,
                old_meta,
                old_body,
                new_meta,
                new_body,
                renamed_paths,
                previous_ref,
            )
        )

    return errors



def ledger_row_key(row: dict[str, str]) -> tuple[str, str, str]:
    return row["closed"], row["path"], row["status"]


def validate_ledger_append_only(
    root: Path,
    docs_root: Path,
    old_rows: list[dict[str, str]],
    new_rows: list[dict[str, str]],
) -> list[str]:
    kept = {ledger_row_key(row) for row in new_rows}
    return [
        f"{ledger_rel(root, docs_root)}: retirement rows are append-only; restore the row for {row['path']}"
        for row in old_rows
        if ledger_row_key(row) not in kept
    ]



def validate_adr_numbers(base_paths: set[str], head_paths: set[str], renamed_paths: dict[str, str]) -> list[str]:
    taken: dict[str, str] = {}
    for rel in sorted(base_paths - set(renamed_paths)):
        if number := adr_number(rel):
            taken.setdefault(number, rel)
    errors: list[str] = []
    for rel in sorted(head_paths - base_paths - set(renamed_paths.values())):
        number = adr_number(rel)
        if not number:
            continue
        if number in taken:
            errors.append(f"{rel}: ADR number {number} is already used by {taken[number]}")
        else:
            taken[number] = rel
    return errors


def validate_branch_history(
    root: Path,
    docs_root: Path,
    base_ref: str,
    head_ref: str = "HEAD",
) -> list[str]:
    errors: list[str] = []

    for commit in git_commits_since(root, base_ref, head_ref):
        errors.extend(validate_tree_at_commit(root, docs_root, commit))
        parents = git_commit_parents(root, commit) or [base_ref]
        for previous_ref in parents:
            errors.extend(
                validate_commit_against_parent(root, docs_root, previous_ref, commit)
            )

    return errors


def validate_current_tree(root: Path, docs_root: Path) -> list[str]:
    errors: list[str] = []
    default_docs_root = (root / "docs").resolve()
    index_path = docs_root / "index.md"
    if not index_path.is_file():
        try:
            rel = index_path.relative_to(root)
        except ValueError:
            rel = index_path
        errors.append(f"{rel}: docs root must include index.md")

    for path in non_markdown_content_files(root, docs_root):
        rel = path.relative_to(root)
        errors.append(
            f"{rel}: non-Markdown content is not allowed under docs/; "
            "keep research datasets under docs/research/<topic>/data/ and "
            "store captures outside the documentation tree"
        )

    docs = read_docs(root, docs_root)
    ledger_path = docs_root / LEDGER_NAME
    rows, row_errors = ledger_state(root, docs_root, None)
    errors.extend(f"{ledger_rel(root, docs_root)}: {error}" for error in row_errors)
    for row in rows:
        if (docs_root / row["path"]).is_file():
            errors.append(
                f"{ledger_rel(root, docs_root)}: retired path still exists; retired docs come back under a new name: {row['path']}"
            )
    retired = ledger_paths(rows)

    inventory_path = docs_root / INVENTORY_NAME
    inventory_rel = inventory_path.relative_to(root)
    expected_inventory = render_inventory(root, docs_root, docs)
    if not inventory_path.is_file():
        errors.append(f"{inventory_rel}: inventory is missing; run {INVENTORY_COMMAND}")
    elif inventory_path.read_text(encoding="utf-8") != expected_inventory:
        errors.append(f"{inventory_rel}: inventory is stale; run {INVENTORY_COMMAND}")

    for path, meta, frontmatter, body, parse_errors in docs:
        rel = path.relative_to(root)
        status = scalar(meta.get("status"))
        doc_type = scalar(meta.get("doc_type"))
        rel_to_docs = path.relative_to(docs_root).as_posix()

        if REJECT_LEGACY_DEV and docs_root == default_docs_root and rel_to_docs.startswith("dev/"):
            errors.append(
                f"{rel}: docs/dev is retired; route documents under plans/, "
                "references/, runbooks/, research/, or adr/"
            )

        if frontmatter is None:
            errors.append(f"{rel}: missing YAML frontmatter")
            continue

        for error in parse_errors:
            errors.append(f"{rel}: {error}")

        for key in sorted(meta):
            if key not in ALLOWED_FRONTMATTER_KEYS:
                errors.append(f"{rel}: unsupported frontmatter key {key!r}")

        if status not in STATUSES:
            errors.append(f"{rel}: status must be one of {', '.join(sorted(STATUSES))}")

        if "doc_type" in meta and doc_type not in DOC_TYPES:
            errors.append(f"{rel}: doc_type must be one of {', '.join(sorted(DOC_TYPES))}")

        if (doc_type == "index") != (path.parent == docs_root and path.name in INDEX_FILES):
            errors.append(f"{rel}: doc_type index is for exactly {', '.join(sorted(INDEX_FILES))} at the docs root")

        if (doc_type == "adr") != bool(adr_number(rel_to_docs)):
            errors.append(f"{rel}: doc_type adr is for exactly the adr/NNNN-slug.md files")

        if not non_empty_string(meta.get("summary")):
            errors.append(f"{rel}: summary is required: one line saying what the doc covers")

        errors.extend(validate_doc_type_status(rel.as_posix(), status, doc_type))

        for key in ("created", "updated"):
            if key in meta and not valid_iso_date(meta.get(key)):
                errors.append(f"{rel}: {key} must be an ISO date: YYYY-MM-DD")

        if status in CLOSED_STATUSES and "closed" not in meta:
            errors.append(f"{rel}: status {status!r} requires closed: YYYY-MM-DD")
        elif status in CLOSED_STATUSES and not valid_iso_date(meta.get("closed")):
            errors.append(f"{rel}: closed must be an ISO date: YYYY-MM-DD")
        elif "closed" in meta and status not in CLOSED_STATUSES:
            errors.append(
                f"{rel}: closed is only valid for archived, superseded, or rejected docs"
            )

        if status == "superseded" and "superseded_by" not in meta:
            errors.append(f"{rel}: status 'superseded' requires superseded_by")
        elif status == "superseded" and not non_empty_targets(meta.get("superseded_by")):
            errors.append(f"{rel}: status 'superseded' requires non-empty superseded_by")

        if status == "archived" and "current_guidance" not in meta:
            errors.append(f"{rel}: status 'archived' requires current_guidance")
        elif status == "archived" and not non_empty_targets(meta.get("current_guidance")):
            errors.append(f"{rel}: status 'archived' requires non-empty current_guidance")

        if status == "rejected" and not (
            non_empty_targets(meta.get("current_guidance"))
            or non_empty_string(meta.get("status_detail"))
        ):
            errors.append(
                f"{rel}: status 'rejected' requires current_guidance or status_detail"
            )

        # Locked docs cannot repair what they point at, so a retired target is
        # accepted in their frontmatter and body links; everything else repoints.
        retired_ok = body_locked(meta)
        for key in ("related", "superseded_by", "current_guidance"):
            for target in non_empty_targets(meta.get(key)):
                if target_exists(root, path, target):
                    continue
                if retired_ok and retired_link_target(root, docs_root, path, target, retired):
                    continue
                errors.append(
                    f"{rel}: {key} target must be a repo-local relative path that exists: {target}"
                )

        if not body.lstrip().startswith("# "):
            errors.append(f"{rel}: Markdown body must start with an H1 after frontmatter")

        text = without_fenced_code_blocks(path.read_text(encoding="utf-8"))
        stale_patterns = ("docs/" + "dev/", "../" + "dev/", "](" + "dev/")
        if REJECT_LEGACY_DEV and docs_root == default_docs_root and not body_locked(meta):
            for pattern in stale_patterns:
                if pattern in text:
                    errors.append(f"{rel}: stale moved docs path reference: {pattern}")

        # A closed doc is not maintained and may go stale, links included;
        # checking its links would make anything it ever linked undeletable.
        # The ledger's rows are append-only, so its links rot the same way.
        # Accepted ADRs are locked too, but they are live direction and keep
        # the check, with the retired-target allowance above.
        if status not in CLOSED_STATUSES and path != ledger_path:
            for target in markdown_link_targets(without_fenced_code_blocks(body)):
                if not should_validate_repo_link(target) or target_exists(root, path, target):
                    continue
                if retired_ok and retired_link_target(root, docs_root, path, target, retired):
                    continue
                errors.append(f"{rel}: Markdown link target must exist: {target}")

    return errors


def validate_locked_body_edits(
    root: Path,
    docs_root: Path,
    base_ref: str,
    head_ref: str = "HEAD",
) -> list[str]:
    compare_worktree = head_ref == "HEAD"
    new_ref = None if compare_worktree else head_ref
    errors = validate_closed_additions_against_open_deletions(
        root,
        docs_root,
        base_ref,
        new_ref,
    )
    current_paths = (
        {str(path.relative_to(root)): path for path in markdown_files(docs_root)}
        if compare_worktree
        else {}
    )
    current_refs = set() if compare_worktree else set(git_base_markdown_paths(root, docs_root, head_ref))
    base_paths = set(git_base_markdown_paths(root, docs_root, base_ref))
    renamed_paths = git_renamed_markdown_paths(root, docs_root, base_ref, new_ref)
    base_rows, _base_errors = ledger_state(root, docs_root, base_ref)
    head_rows, _head_errors = ledger_state(root, docs_root, new_ref)
    retired = ledger_paths(head_rows)
    errors.extend(validate_ledger_append_only(root, docs_root, base_rows, head_rows))
    head_paths = set(current_paths) if compare_worktree else current_refs
    errors.extend(validate_adr_numbers(base_paths, head_paths, renamed_paths))

    for old_rel in sorted(base_paths):
        old_text = git_show(root, base_ref, old_rel)
        if old_text is None:
            continue

        old_frontmatter, old_body = split_frontmatter(old_text)
        if old_frontmatter is None:
            continue

        old_meta, _old_errors = parse_frontmatter(old_frontmatter)
        path = current_paths.get(old_rel) if compare_worktree else None
        new_rel = old_rel if (compare_worktree and path is not None) or old_rel in current_refs else None
        if new_rel is None:
            new_rel = renamed_paths.get(old_rel)
            if (
                new_rel
                and body_locked(old_meta)
                and not doc_identity_preserved(old_rel, new_rel)
            ):
                new_rel = None
            path = current_paths.get(new_rel) if compare_worktree and new_rel else None
            if new_rel and docs_relative(root, docs_root, new_rel) is None and not body_locked(old_meta):
                continue  # an open doc moved out of docs/ keeps living elsewhere
            if new_rel is None or (compare_worktree and path is None):
                errors.extend(deletion_errors(root, docs_root, old_rel, retired))
                continue

        if compare_worktree:
            if path is None:
                continue
            new_meta, _new_frontmatter, new_body, _new_errors = read_doc(path)
            new_rel = path.relative_to(root).as_posix()
        else:
            new_state = git_doc_state(root, head_ref, new_rel)
            if new_state is None:
                errors.extend(deletion_errors(root, docs_root, old_rel, retired))
                continue
            new_meta, new_body, _new_errors = new_state

        errors.extend(
            validate_historical_doc_change(
                docs_root,
                old_rel,
                new_rel,
                old_meta,
                old_body,
                new_meta,
                new_body,
                renamed_paths,
                base_ref,
                allow_committed_closure=True,
                root=root,
                base_ref=base_ref,
                head_ref=head_ref,
            )
        )

    return errors


def main(*, default_repo_root: Path | None = None,
         inventory_command: str = INVENTORY_COMMAND,
         reject_legacy_dev: bool = False,
         allowed_non_markdown: tuple[str, ...] = ()) -> int:
    global INVENTORY_COMMAND, REJECT_LEGACY_DEV, ALLOWED_NON_MARKDOWN
    INVENTORY_COMMAND = inventory_command
    REJECT_LEGACY_DEV = reject_legacy_dev
    ALLOWED_NON_MARKDOWN = allowed_non_markdown
    parser = argparse.ArgumentParser(
        description="Validate docs/ lifecycle frontmatter, retirement ledger, inventory, and locked-doc edit rules.",
        epilog=(
            "Frontmatter supports scalar key: value entries, inline lists, and "
            "two-space list items only; nested maps and block scalars are rejected."
        ),
    )
    parser.add_argument(
        "--base",
        "--base-ref",
        dest="base",
        help=(
            "Optional git ref to compare against. Body edits to docs already "
            "closed, rejected, superseded, or accepted ADRs at this ref fail."
        ),
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=default_repo_root or Path.cwd(),
        help="Repository root. Defaults to the current directory.",
    )
    parser.add_argument(
        "--docs-root",
        type=Path,
        help="Docs root to validate. Defaults to <repo-root>/docs.",
    )
    parser.add_argument(
        "--write-inventory",
        action="store_true",
        help=f"Regenerate <docs-root>/{INVENTORY_NAME} from frontmatter instead of validating.",
    )
    parser.add_argument(
        "--due",
        action="store_true",
        help=(
            "Report docs that need a decision instead of validating: parked plans "
            f"and open plans with no commit in {DUE_AFTER_DAYS} days, and research whose "
            "consumer is settled or missing."
        ),
    )
    args = parser.parse_args()
    root = args.repo_root.resolve()
    docs_root = (args.docs_root or root / "docs").resolve()

    if not docs_root.is_dir() or not docs_root.is_relative_to(root):
        parser.error("--docs-root must be an existing directory within --repo-root")

    if args.write_inventory:
        inventory_path = docs_root / INVENTORY_NAME
        inventory_path.write_text(render_inventory(root, docs_root, read_docs(root, docs_root)), encoding="utf-8")
        print(f"wrote {inventory_path.relative_to(root)}")
        return 0

    if args.due:
        for line in due_report(root, docs_root):
            print(line)
        return 0

    errors = validate_current_tree(root, docs_root)
    if args.base:
        if not git_ref_exists(root, args.base):
            errors.append(f"base ref does not exist: {args.base}")
        else:
            head_ref = "HEAD"
            branch_base = git_merge_base(root, args.base, head_ref)
            if branch_base is None:
                errors.append(f"unable to find merge base with: {args.base}")
            else:
                errors.extend(validate_branch_history(root, docs_root, branch_base, head_ref))
                errors.extend(
                    validate_locked_body_edits(root, docs_root, branch_base, head_ref)
                )

    if errors:
        print("docs lifecycle validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    checked = len(markdown_files(docs_root))
    suffix = f" against {args.base}" if args.base else ""
    print(f"docs lifecycle validation passed ({checked} docs{suffix})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
