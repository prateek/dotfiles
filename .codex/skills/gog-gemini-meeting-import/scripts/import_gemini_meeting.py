#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory

DEFAULT_OUT_DIR = Path("/Users/prateek/code/github.com/prateek/personal-notes/21-openai-meetings")

DOC_ID_FROM_URL_RE = re.compile(r"https?://docs\.google\.com/document/d/([a-zA-Z0-9_-]+)")
DOC_ID_FROM_PATH_RE = re.compile(r"document/d/([a-zA-Z0-9_-]+)")
DOC_ID_FROM_QUERY_RE = re.compile(r"[?&]id=([a-zA-Z0-9_-]+)")
ISO_DATE_RE = re.compile(r"\b(20\d{2})[-/](\d{2})[-/](\d{2})\b")
TIME_CODE_RE = re.compile(r"^\d{2}:\d{2}:\d{2}$")


@dataclass(frozen=True)
class DocInfo:
    title: str | None


def _slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    value = re.sub(r"-{2,}", "-", value)
    return value


def _parse_doc_id(source: str) -> str:
    source = source.strip()
    for pattern in (DOC_ID_FROM_URL_RE, DOC_ID_FROM_PATH_RE, DOC_ID_FROM_QUERY_RE):
        match = pattern.search(source)
        if match:
            return match.group(1)
    return source


def _default_source_url(doc_id: str) -> str:
    return f"https://docs.google.com/document/d/{doc_id}/edit"


def _short_doc_id(doc_id: str, length: int = 10) -> str:
    # Doc IDs are URL-safe and file-name-safe (letters, digits, - and _).
    return doc_id[:length]


def _run_gog_export(doc_id: str, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["gog", "docs", "export", doc_id, "--format=txt", "--out", str(out_path)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"gog export failed: {details}")
    if not out_path.exists() or out_path.stat().st_size == 0:
        stdout = (result.stdout or "").strip()
        stderr = (result.stderr or "").strip()
        details = stderr or stdout or "export produced empty output"
        raise RuntimeError(f"gog export produced no data at {out_path}: {details}")


def _read_text(path: Path) -> str:
    # Use utf-8-sig to handle BOM.
    return path.read_bytes().decode("utf-8-sig", errors="replace")


def _find_transcript_start_line(lines: list[str]) -> int | None:
    def normalize(line: str) -> str:
        # Strip whitespace + common invisible chars for matching only.
        return line.strip().lstrip("\ufeff").replace("\u200b", "").strip()

    for idx, line in enumerate(lines):
        normalized = normalize(line)
        if normalized in ("📖 Transcript", "Transcript"):
            return idx

    def window_has_timecode(start: int) -> bool:
        end = min(start + 40, len(lines))
        for line in lines[start:end]:
            if TIME_CODE_RE.match(normalize(line)):
                return True
        return False

    for idx, line in enumerate(lines):
        normalized = normalize(line)
        if "Transcript" in normalized and window_has_timecode(idx):
            return idx

    return None


def _extract_transcript(export_text: str) -> str:
    lines = export_text.splitlines(keepends=True)
    start_idx = _find_transcript_start_line(lines)
    if start_idx is None:
        raise RuntimeError("No transcript section found (missing Transcript marker).")
    transcript = "".join(lines[start_idx:])
    if transcript and not transcript.endswith("\n"):
        transcript += "\n"
    return transcript


def _parse_date_from_line(line: str) -> datetime | None:
    candidate = line.strip().lstrip("\ufeff").replace("\u200b", "").strip()
    if not candidate:
        return None

    # Common Gemini transcript format: "Feb 10, 2026"
    for fmt in ("%b %d, %Y", "%B %d, %Y", "%b %d %Y", "%B %d %Y"):
        try:
            return datetime.strptime(candidate, fmt)
        except ValueError:
            pass

    # ISO-ish formats.
    for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(candidate, fmt)
        except ValueError:
            pass

    match = ISO_DATE_RE.search(candidate)
    if match:
        year, month, day = match.groups()
        try:
            return datetime(int(year), int(month), int(day))
        except ValueError:
            return None

    return None


def _infer_date_from_transcript(transcript_text: str) -> datetime | None:
    lines = transcript_text.splitlines()
    # Look at the first ~20 non-empty lines after the marker.
    for line in lines[1:25]:
        parsed = _parse_date_from_line(line)
        if parsed:
            return parsed
    return None


def _infer_participants_from_transcript(transcript_text: str) -> str | None:
    lines = transcript_text.splitlines()
    for line in lines[:30]:
        stripped = line.strip()
        if "Transcript" not in stripped or "/" not in stripped:
            continue
        cleaned = re.sub(r"\s*-\s*Transcript\s*$", "", stripped, flags=re.IGNORECASE).strip()
        cleaned = re.sub(r"\s+Transcript\s*$", "", cleaned, flags=re.IGNORECASE).strip()
        parts = [p.strip() for p in cleaned.split("/") if p.strip()]
        if len(parts) < 2:
            continue
        slugs = [_slugify(p) for p in parts[:4]]
        joined = "-".join([s for s in slugs if s])
        if joined:
            return joined
    return None


def _fetch_doc_info(doc_id: str) -> DocInfo:
    cmd = ["gog", "docs", "info", doc_id, "--json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return DocInfo(title=None)
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return DocInfo(title=None)
    title = None
    if isinstance(payload, dict):
        doc = payload.get("document")
        if isinstance(doc, dict):
            t = doc.get("title")
            if isinstance(t, str) and t.strip():
                title = t.strip()
    return DocInfo(title=title)


def _infer_date_from_title(title: str) -> datetime | None:
    match = ISO_DATE_RE.search(title)
    if match:
        year, month, day = match.groups()
        try:
            return datetime(int(year), int(month), int(day))
        except ValueError:
            return None
    # Try month-name format embedded in title.
    for token in re.split(r"\s{2,}|\s-\s", title):
        parsed = _parse_date_from_line(token)
        if parsed:
            return parsed
    return None


def _infer_participants_from_title(title: str) -> str | None:
    # Example: "Steven / Prateek - 2026/02/10 15:55 EST - Notes by Gemini"
    match = ISO_DATE_RE.search(title)
    prefix = title
    if match:
        prefix = title[: match.start()].strip()
    if "/" not in prefix:
        return None
    parts = [p.strip() for p in prefix.split("/") if p.strip()]
    if len(parts) < 2:
        return None
    slugs = [_slugify(p) for p in parts[:4]]
    joined = "-".join([s for s in slugs if s])
    return joined or None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export a Gemini meeting Google Doc via gog and extract the Transcript section.",
    )
    parser.add_argument(
        "source",
        help="Google Doc URL (docs.google.com/document/...) or a raw docId.",
    )
    parser.add_argument(
        "--out-dir",
        default=str(DEFAULT_OUT_DIR),
        help=f"Output directory (default: {DEFAULT_OUT_DIR})",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing transcript file if present.",
    )
    parser.add_argument(
        "--allow-existing",
        action="store_true",
        help="If transcript already exists, do not error; still print paths (useful for sync).",
    )
    parser.add_argument(
        "--include-doc-id",
        action="store_true",
        help="Append a short docId suffix to output filenames to avoid collisions.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output.",
    )
    args = parser.parse_args()

    doc_id = _parse_doc_id(args.source)
    source_url = args.source if args.source.startswith("http") else _default_source_url(doc_id)

    out_dir = Path(args.out_dir).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)

    with TemporaryDirectory(prefix="gog-gemini-meeting-") as tmp_dir:
        export_path = Path(tmp_dir) / "export.txt"
        _run_gog_export(doc_id, export_path)
        export_text = _read_text(export_path)

    transcript_text = _extract_transcript(export_text)

    inferred_date = _infer_date_from_transcript(transcript_text)
    inferred_participants = _infer_participants_from_transcript(transcript_text)

    doc_info: DocInfo | None = None
    if inferred_date is None or inferred_participants is None:
        doc_info = _fetch_doc_info(doc_id)
        if doc_info.title:
            if inferred_date is None:
                inferred_date = _infer_date_from_title(doc_info.title)
            if inferred_participants is None:
                inferred_participants = _infer_participants_from_title(doc_info.title)

    date_slug = inferred_date.strftime("%Y-%m-%d") if inferred_date else "unknown-date"
    participants_slug = inferred_participants or "unknown-attendees"

    doc_id_suffix = f"-{_short_doc_id(doc_id)}" if args.include_doc_id else ""
    transcript_path = out_dir / f"{date_slug}-meeting-transcript-{participants_slug}{doc_id_suffix}.md"
    notes_path = out_dir / f"{date_slug}-meeting-notes-{participants_slug}{doc_id_suffix}.md"

    transcript_existed = transcript_path.exists()
    transcript_written = False
    if transcript_existed and not args.overwrite:
        if not args.allow_existing:
            print(f"[ERROR] Transcript already exists: {transcript_path}", file=sys.stderr)
            return 2
    else:
        transcript_path.write_text(transcript_text, encoding="utf-8")
        transcript_written = True

    payload = {
        "doc_id": doc_id,
        "source_url": source_url,
        "title": (doc_info.title if doc_info else None),
        "date": (date_slug if inferred_date else None),
        "participants": (participants_slug if inferred_participants else None),
        "transcript_path": str(transcript_path),
        "notes_path": str(notes_path),
        "transcript_existed": transcript_existed,
        "transcript_written": transcript_written,
    }

    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"Transcript: {transcript_path}")
    print(f"Notes: {notes_path}")
    print(f"Doc ID: {doc_id}")
    print(f"Source: {source_url}")
    if payload["title"]:
        print(f"Title: {payload['title']}")
    if not inferred_date:
        print("Warning: could not infer date; used 'unknown-date'.", file=sys.stderr)
    if not inferred_participants:
        print("Warning: could not infer participants; used 'unknown-attendees'.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
