#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

GOOG_DOC_MIMETYPE = "application/vnd.google-apps.document"

DOC_ID_FROM_URL_RE = re.compile(r"https?://docs\.google\.com/document/d/([a-zA-Z0-9_-]+)")
DOC_ID_FROM_PATH_RE = re.compile(r"document/d/([a-zA-Z0-9_-]+)")
DOC_ID_FROM_QUERY_RE = re.compile(r"[?&]id=([a-zA-Z0-9_-]+)")

CALENDAR_FIELDS = (
    "items("
    "id,"
    "summary,"
    "description,"
    "attachments(fileUrl,title),"
    "conferenceData(entryPoints(uri,entryPointType)),"
    "hangoutLink,"
    "start,"
    "end,"
    "attendees(email,self,responseStatus),"
    "status"
    "),"
    "nextPageToken"
)


@dataclass
class Candidate:
    doc_id: str
    sources: set[str] = field(default_factory=set)
    title: str | None = None
    modified_time: datetime | None = None
    web_view_link: str | None = None

    def merge_from(self, other: "Candidate") -> None:
        self.sources |= other.sources
        if not self.title and other.title:
            self.title = other.title
        if not self.web_view_link and other.web_view_link:
            self.web_view_link = other.web_view_link
        if other.modified_time and (not self.modified_time or other.modified_time > self.modified_time):
            self.modified_time = other.modified_time


def _parse_rfc3339(value: str | None) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    # Example: "2026-02-11T03:41:24.825Z"
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _parse_doc_id(source: str) -> str:
    source = source.strip()
    for pattern in (DOC_ID_FROM_URL_RE, DOC_ID_FROM_PATH_RE, DOC_ID_FROM_QUERY_RE):
        match = pattern.search(source)
        if match:
            return match.group(1)
    return source


def _extract_doc_ids(text: str | None) -> set[str]:
    if not text or not isinstance(text, str):
        return set()
    ids: set[str] = set()
    for pattern in (DOC_ID_FROM_URL_RE, DOC_ID_FROM_PATH_RE, DOC_ID_FROM_QUERY_RE):
        for match in pattern.finditer(text):
            ids.add(match.group(1))
    return ids


def _short_doc_id(doc_id: str, length: int = 10) -> str:
    return doc_id[:length]


def _run(cmd: list[str], *, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, input=input_text, text=True, capture_output=True)


def _run_json(cmd: list[str], *, input_text: str | None = None) -> Any:
    result = _run(cmd, input_text=input_text)
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"Command failed: {' '.join(cmd)}: {details}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON from: {' '.join(cmd)}: {e}") from e


def _gog_base_cmd(account: str | None) -> list[str]:
    cmd = ["gog", "--json"]
    if account:
        cmd.append(f"--account={account}")
    return cmd


def _self_not_declined(event: dict[str, Any]) -> bool:
    attendees = event.get("attendees")
    if not isinstance(attendees, list):
        return True
    for attendee in attendees:
        if not isinstance(attendee, dict):
            continue
        if attendee.get("self") is True:
            return attendee.get("responseStatus") != "declined"
    return True


def _candidates_from_drive_payload(payload: Any, *, since: datetime | None) -> dict[str, Candidate]:
    out: dict[str, Candidate] = {}
    if not isinstance(payload, dict):
        return out
    files = payload.get("files")
    if not isinstance(files, list):
        return out
    for item in files:
        if not isinstance(item, dict):
            continue
        if item.get("mimeType") != GOOG_DOC_MIMETYPE:
            continue
        doc_id = item.get("id")
        if not isinstance(doc_id, str) or not doc_id.strip():
            continue
        modified_time = _parse_rfc3339(item.get("modifiedTime"))
        if since and modified_time and modified_time < since:
            continue
        cand = Candidate(
            doc_id=doc_id,
            sources={"drive"},
            title=(item.get("name") if isinstance(item.get("name"), str) else None),
            modified_time=modified_time,
            web_view_link=(item.get("webViewLink") if isinstance(item.get("webViewLink"), str) else None),
        )
        out[doc_id] = cand
    return out


def discover_drive_candidates(
    *,
    query: str,
    account: str | None,
    since: datetime | None,
    max_pages: int,
    per_page: int,
    run_dir: Path,
) -> dict[str, Candidate]:
    candidates: dict[str, Candidate] = {}
    page_token = ""
    page = 0
    while page < max_pages:
        cmd = _gog_base_cmd(account) + ["drive", "search", query, f"--max={per_page}"]
        if page_token:
            cmd.append(f"--page={page_token}")
        payload = _run_json(cmd)
        (run_dir / f"drive-search-page-{page + 1}.json").write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        page_candidates = _candidates_from_drive_payload(payload, since=since)
        for doc_id, cand in page_candidates.items():
            if doc_id in candidates:
                candidates[doc_id].merge_from(cand)
            else:
                candidates[doc_id] = cand

        page_token = payload.get("nextPageToken") if isinstance(payload, dict) else ""
        if not isinstance(page_token, str) or not page_token:
            break
        page += 1
    return candidates


def _candidates_from_calendar_payload(payload: Any) -> dict[str, Candidate]:
    out: dict[str, Candidate] = {}
    if not isinstance(payload, dict):
        return out
    events = payload.get("events")
    if not isinstance(events, list):
        return out
    for event in events:
        if not isinstance(event, dict):
            continue
        if event.get("status") == "cancelled":
            continue
        if not _self_not_declined(event):
            continue
        doc_ids: set[str] = set()
        doc_ids |= _extract_doc_ids(event.get("description"))
        attachments = event.get("attachments")
        if isinstance(attachments, list):
            for attachment in attachments:
                if not isinstance(attachment, dict):
                    continue
                doc_ids |= _extract_doc_ids(attachment.get("fileUrl"))

        for doc_id in doc_ids:
            cand = out.get(doc_id)
            if not cand:
                cand = Candidate(doc_id=doc_id)
                out[doc_id] = cand
            cand.sources.add("calendar")
            if not cand.title and isinstance(event.get("summary"), str):
                cand.title = event["summary"]
    return out


def discover_calendar_candidates(
    *,
    account: str | None,
    date_from: str,
    date_to: str,
    max_pages: int,
    per_page: int,
    run_dir: Path,
) -> dict[str, Candidate]:
    candidates: dict[str, Candidate] = {}
    page_token = ""
    page = 0
    while page < max_pages:
        cmd = _gog_base_cmd(account) + [
            "calendar",
            "events",
            "--all",
            f"--from={date_from}",
            f"--to={date_to}",
            f"--max={per_page}",
            f"--fields={CALENDAR_FIELDS}",
        ]
        if page_token:
            cmd.append(f"--page={page_token}")
        payload = _run_json(cmd)
        (run_dir / f"calendar-events-page-{page + 1}.json").write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        page_candidates = _candidates_from_calendar_payload(payload)
        for doc_id, cand in page_candidates.items():
            if doc_id in candidates:
                candidates[doc_id].merge_from(cand)
            else:
                candidates[doc_id] = cand

        page_token = payload.get("nextPageToken") if isinstance(payload, dict) else ""
        if not isinstance(page_token, str) or not page_token:
            break
        page += 1
    return candidates


def load_processed_docids(state_file: Path) -> set[str]:
    if not state_file.exists():
        return set()
    docids: set[str] = set()
    for line in state_file.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        docids.add(line)
    return docids


def append_processed_docid(state_file: Path, doc_id: str) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    needs_newline = False
    try:
        if state_file.exists() and state_file.stat().st_size > 0:
            with state_file.open("rb") as f:
                f.seek(-1, os.SEEK_END)
                needs_newline = f.read(1) != b"\n"
    except OSError:
        # Best-effort only; we'll still append safely below.
        needs_newline = True

    with state_file.open("a", encoding="utf-8") as f:
        if needs_newline:
            f.write("\n")
        f.write(doc_id + "\n")


def ensure_state_dir(state_dir: Path) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    readme = state_dir / "README.md"
    if not readme.exists():
        readme.write_text(
            "# Gemini meeting sync state\n\n"
            "This folder intentionally contains only:\n\n"
            "- `processed-docids.txt`: one Google Doc ID per line\n\n"
            "To reprocess a doc, delete its line from `processed-docids.txt` or run the sync script with `--force <docId>`.\n",
            encoding="utf-8",
        )
    processed = state_dir / "processed-docids.txt"
    if not processed.exists():
        processed.write_text("", encoding="utf-8")


def prune_run_artifacts(runs_root: Path, *, prune_days: int) -> int:
    if prune_days <= 0 or not runs_root.exists():
        return 0
    cutoff = datetime.now(timezone.utc) - timedelta(days=prune_days)
    removed = 0
    for path in sorted(runs_root.glob("**/*")):
        if not path.is_dir():
            continue
        # Only consider leaf run directories (contain files).
        try:
            children = list(path.iterdir())
        except OSError:
            continue
        if not children or all(c.is_dir() for c in children):
            continue
        try:
            mtime = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
        except OSError:
            continue
        if mtime < cutoff:
            shutil.rmtree(path, ignore_errors=True)
            removed += 1
    # Clean up empty date directories.
    for date_dir in sorted(runs_root.glob("*")):
        if date_dir.is_dir():
            try:
                next(date_dir.iterdir())
            except StopIteration:
                shutil.rmtree(date_dir, ignore_errors=True)
    return removed


def run_importer(
    *,
    importer_path: Path,
    doc_id: str,
    out_dir: Path,
    run_dir: Path,
    overwrite: bool,
) -> dict[str, Any]:
    cmd = [
        sys.executable,
        str(importer_path),
        doc_id,
        "--json",
        "--allow-existing",
        "--include-doc-id",
        "--out-dir",
        str(out_dir),
    ]
    if overwrite:
        cmd.append("--overwrite")
    result = _run(cmd)
    (run_dir / f"import-{_short_doc_id(doc_id)}.stdout.txt").write_text(result.stdout or "", encoding="utf-8")
    (run_dir / f"import-{_short_doc_id(doc_id)}.stderr.txt").write_text(result.stderr or "", encoding="utf-8")
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"Importer failed for {doc_id}: {details}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Importer did not return valid JSON for {doc_id}: {e}") from e
    if not isinstance(payload, dict):
        raise RuntimeError(f"Importer returned non-object JSON for {doc_id}")
    (run_dir / f"import-{_short_doc_id(doc_id)}.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    return payload


def generate_notes_with_codex(
    *,
    transcript_path: Path,
    notes_path: Path,
    meeting_notes_prompt_path: Path,
    run_dir: Path,
    doc_id: str,
) -> None:
    transcript = transcript_path.read_text(encoding="utf-8", errors="replace")
    meeting_prompt = meeting_notes_prompt_path.read_text(encoding="utf-8", errors="replace")

    schema_path = run_dir / "meeting-notes.schema.json"
    if not schema_path.exists():
        schema_path.write_text(
            json.dumps(
                {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {"notes_markdown": {"type": "string"}},
                    "required": ["notes_markdown"],
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    output_path = run_dir / f"codex-notes-{_short_doc_id(doc_id)}.json"

    prompt = (
        "Return a JSON object with a single key `notes_markdown`.\n"
        "The value of `notes_markdown` must be ONLY the Markdown specified by the meeting-notes prompt.\n"
        "Do not include any other keys or commentary.\n\n"
        "<MEETING_NOTES_PROMPT>\n"
        f"{meeting_prompt}\n"
        "</MEETING_NOTES_PROMPT>\n\n"
        "<TRANSCRIPT>\n"
        f"{transcript}\n"
        "</TRANSCRIPT>\n"
    )

    cmd = [
        "codex",
        "exec",
        "--skip-git-repo-check",
        "--output-schema",
        str(schema_path),
        "--output-last-message",
        str(output_path),
        "-",
    ]
    result = _run(cmd, input_text=prompt)
    (run_dir / f"codex-notes-{_short_doc_id(doc_id)}.stdout.txt").write_text(result.stdout or "", encoding="utf-8")
    (run_dir / f"codex-notes-{_short_doc_id(doc_id)}.stderr.txt").write_text(result.stderr or "", encoding="utf-8")
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"codex exec failed for {doc_id}: {details}")

    raw = output_path.read_text(encoding="utf-8", errors="replace").strip()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"codex output was not valid JSON for {doc_id}: {e}") from e
    if not isinstance(payload, dict) or "notes_markdown" not in payload:
        raise RuntimeError(f"codex output missing notes_markdown for {doc_id}")
    notes = payload["notes_markdown"]
    if not isinstance(notes, str) or not notes.strip():
        raise RuntimeError(f"codex output notes_markdown was empty for {doc_id}")

    notes_path.parent.mkdir(parents=True, exist_ok=True)
    notes_path.write_text(notes.rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Discover and import Gemini meeting Google Docs (transcripts + notes) into a local folder.",
    )
    parser.add_argument(
        "--out-dir",
        default="/Users/prateek/code/github.com/prateek/personal-notes/21-openai-meetings",
        help="Output directory for transcript + notes files (default: your meetings folder in the notes vault).",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=90,
        help="Look back N days for calendar events and filter Drive docs by modifiedTime (default: 90).",
    )
    parser.add_argument(
        "--account",
        default="",
        help="Optional gog account email (defaults to gog's default account).",
    )
    parser.add_argument(
        "--no-drive",
        action="store_true",
        help="Disable Drive discovery (for debugging).",
    )
    parser.add_argument(
        "--no-calendar",
        action="store_true",
        help="Disable Calendar discovery (for debugging).",
    )
    parser.add_argument(
        "--drive-max-pages",
        type=int,
        default=50,
        help="Max pages for Drive search pagination (default: 50).",
    )
    parser.add_argument(
        "--calendar-max-pages",
        type=int,
        default=50,
        help="Max pages for Calendar events pagination (default: 50).",
    )
    parser.add_argument(
        "--per-page",
        type=int,
        default=200,
        help="Max results per API page where supported (default: 200).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Discover and print what would happen, but do not write transcripts/notes/state.",
    )
    parser.add_argument(
        "--prune-days",
        type=int,
        default=14,
        help="Prune temp run artifacts older than N days (default: 14). Use 0 to disable.",
    )
    parser.add_argument(
        "--force",
        action="append",
        default=[],
        help="Doc ID to force reprocessing (repeatable).",
    )
    parser.add_argument(
        "--force-missing-notes",
        action="store_true",
        help="For already-processed docIds, regenerate notes if missing.",
    )
    parser.add_argument(
        "--max-docs",
        type=int,
        default=0,
        help="Process at most N docs (0 = unlimited). Useful for incremental runs.",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Stop at the first error instead of continuing.",
    )
    args = parser.parse_args()

    out_dir = Path(args.out_dir).expanduser()
    state_dir = out_dir / ".gemini-sync"
    state_file = state_dir / "processed-docids.txt"
    processed = load_processed_docids(state_file)
    forced = {_parse_doc_id(x) for x in args.force if x.strip()}

    now = datetime.now().astimezone()
    since = now - timedelta(days=max(args.days, 0))
    since_utc = since.astimezone(timezone.utc)
    date_from = since.date().isoformat()
    date_to = now.date().isoformat()

    tmp_root = Path(tempfile.gettempdir()) / "gemini-meeting-sync"
    runs_root = tmp_root / "runs"
    runs_root.mkdir(parents=True, exist_ok=True)
    pruned = prune_run_artifacts(runs_root, prune_days=args.prune_days)

    run_date = now.strftime("%Y%m%d")
    run_id = f"{now.strftime('%Y%m%dT%H%M%S')}-{os.getpid()}"
    run_dir = runs_root / run_date / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    (run_dir / "run.json").write_text(
        json.dumps(
            {
                "created_at": now.isoformat(),
                "out_dir": str(out_dir),
                "days": args.days,
                "account": (args.account or None),
                "dry_run": args.dry_run,
                "prune_days": args.prune_days,
                "pruned_run_dirs": pruned,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    account = args.account.strip() or None
    candidates: dict[str, Candidate] = {}

    if not args.no_drive:
        drive_candidates = discover_drive_candidates(
            query="Notes by Gemini",
            account=account,
            since=since_utc,
            max_pages=args.drive_max_pages,
            per_page=args.per_page,
            run_dir=run_dir,
        )
        candidates.update(drive_candidates)

    if not args.no_calendar:
        cal_candidates = discover_calendar_candidates(
            account=account,
            date_from=date_from,
            date_to=date_to,
            max_pages=args.calendar_max_pages,
            per_page=args.per_page,
            run_dir=run_dir,
        )
        for doc_id, cand in cal_candidates.items():
            if doc_id in candidates:
                candidates[doc_id].merge_from(cand)
            else:
                candidates[doc_id] = cand

    ordered = sorted(
        candidates.values(),
        key=lambda c: (c.modified_time or datetime.min.replace(tzinfo=timezone.utc), c.doc_id),
        reverse=True,
    )

    summary = {
        "discovered_unique_doc_ids": len(ordered),
        "already_processed": 0,
        "to_process": 0,
        "forced": len(forced),
        "dry_run": args.dry_run,
        "run_dir": str(run_dir),
        "errors": 0,
    }

    def is_processed(doc_id: str) -> bool:
        return doc_id in processed and doc_id not in forced

    for cand in ordered:
        if is_processed(cand.doc_id):
            summary["already_processed"] += 1
        else:
            summary["to_process"] += 1

    (run_dir / "candidates.json").write_text(
        json.dumps(
            [
                {
                    "doc_id": c.doc_id,
                    "sources": sorted(c.sources),
                    "title": c.title,
                    "modified_time": c.modified_time.isoformat() if c.modified_time else None,
                    "web_view_link": c.web_view_link,
                }
                for c in ordered
            ],
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Run dir: {run_dir}")
    print(
        f"Discovered: {summary['discovered_unique_doc_ids']} docs | "
        f"Processed: {summary['already_processed']} | "
        f"To process: {summary['to_process']} | "
        f"Dry-run: {args.dry_run}"
    )

    if args.dry_run:
        return 0

    ensure_state_dir(state_dir)
    importer_path = Path(__file__).resolve().parent / "import_gemini_meeting.py"
    meeting_prompt_path = Path(__file__).resolve().parents[1] / "references" / "meeting-notes.md"

    processed_this_run = 0
    errors: list[str] = []
    remaining = ordered
    if args.max_docs and args.max_docs > 0:
        remaining = ordered[: args.max_docs]

    for cand in remaining:
        doc_id = cand.doc_id
        already_done = doc_id in processed
        if already_done and doc_id not in forced and not args.force_missing_notes:
            continue

        try:
            payload = run_importer(
                importer_path=importer_path,
                doc_id=doc_id,
                out_dir=out_dir,
                run_dir=run_dir,
                overwrite=(doc_id in forced),
            )
            transcript_path = Path(payload["transcript_path"])
            notes_path = Path(payload["notes_path"])
            if not transcript_path.exists():
                raise RuntimeError(f"Transcript missing after import: {transcript_path}")

            if notes_path.exists():
                pass
            elif already_done and args.force_missing_notes:
                generate_notes_with_codex(
                    transcript_path=transcript_path,
                    notes_path=notes_path,
                    meeting_notes_prompt_path=meeting_prompt_path,
                    run_dir=run_dir,
                    doc_id=doc_id,
                )
            else:
                generate_notes_with_codex(
                    transcript_path=transcript_path,
                    notes_path=notes_path,
                    meeting_notes_prompt_path=meeting_prompt_path,
                    run_dir=run_dir,
                    doc_id=doc_id,
                )

            if notes_path.exists() and doc_id not in processed:
                append_processed_docid(state_file, doc_id)
                processed.add(doc_id)
                processed_this_run += 1

            print(
                f"[OK] {doc_id} -> "
                f"{transcript_path.name} | {notes_path.name}{' (forced)' if doc_id in forced else ''}"
            )
        except Exception as e:  # noqa: BLE001 - tool script, keep going unless fail-fast
            errors.append(f"{doc_id}: {e}")
            summary["errors"] += 1
            print(f"[ERROR] {doc_id}: {e}", file=sys.stderr)
            if args.fail_fast:
                break

    summary["processed_this_run"] = processed_this_run
    (run_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    if errors:
        (run_dir / "errors.txt").write_text("\n".join(errors) + "\n", encoding="utf-8")
        print(f"Completed with errors ({len(errors)}). See: {run_dir / 'errors.txt'}", file=sys.stderr)
        return 1

    print(f"Done. Newly processed: {processed_this_run}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
