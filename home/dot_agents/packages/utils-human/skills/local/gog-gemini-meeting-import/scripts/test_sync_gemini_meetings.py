import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

import sync_gemini_meetings as sync


class TestSyncGeminiMeetings(unittest.TestCase):
    def test_extract_doc_ids(self) -> None:
        text = (
            "Agenda: https://docs.google.com/document/d/abcDEF_123-456/edit\n"
            "Alt: https://docs.google.com/document/d/ZZZ999/view?usp=sharing\n"
            "Query form: https://docs.google.com/open?id=QWERTY_000-111\n"
        )
        ids = sync._extract_doc_ids(text)
        self.assertEqual(
            ids,
            {"abcDEF_123-456", "ZZZ999", "QWERTY_000-111"},
        )

    def test_candidates_from_drive_payload_filters_by_mimetype_and_since(self) -> None:
        since = datetime(2026, 2, 10, tzinfo=timezone.utc)
        payload = {
            "files": [
                {
                    "id": "doc-old",
                    "mimeType": sync.GOOG_DOC_MIMETYPE,
                    "modifiedTime": "2026-02-09T00:00:00Z",
                    "name": "Old - Notes by Gemini",
                },
                {
                    "id": "doc-new",
                    "mimeType": sync.GOOG_DOC_MIMETYPE,
                    "modifiedTime": "2026-02-11T03:41:24.825Z",
                    "name": "New - Notes by Gemini",
                    "webViewLink": "https://docs.google.com/document/d/doc-new/edit",
                },
                {
                    "id": "not-a-doc",
                    "mimeType": "application/pdf",
                    "modifiedTime": "2026-02-11T03:41:24.825Z",
                    "name": "pdf",
                },
            ]
        }
        candidates = sync._candidates_from_drive_payload(payload, since=since)
        self.assertEqual(set(candidates.keys()), {"doc-new"})
        self.assertEqual(candidates["doc-new"].title, "New - Notes by Gemini")
        self.assertIsNotNone(candidates["doc-new"].modified_time)

    def test_candidates_from_calendar_payload_skips_cancelled_and_declined(self) -> None:
        payload = {
            "events": [
                {
                    "status": "cancelled",
                    "summary": "Cancelled",
                    "description": "https://docs.google.com/document/d/CANCELLED/edit",
                },
                {
                    "status": "confirmed",
                    "summary": "Declined",
                    "attendees": [{"self": True, "responseStatus": "declined"}],
                    "description": "https://docs.google.com/document/d/DECLINED/edit",
                },
                {
                    "status": "confirmed",
                    "summary": "Good",
                    "attendees": [{"self": True, "responseStatus": "accepted"}],
                    "description": "Doc: https://docs.google.com/document/d/GOOD/edit",
                    "attachments": [{"fileUrl": "https://docs.google.com/document/d/ATTACH/edit"}],
                },
            ]
        }
        candidates = sync._candidates_from_calendar_payload(payload)
        self.assertEqual(set(candidates.keys()), {"GOOD", "ATTACH"})
        self.assertEqual(candidates["GOOD"].title, "Good")
        self.assertIn("calendar", candidates["GOOD"].sources)

    def test_processed_docids_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / "processed-docids.txt"
            state.write_text("a\n\nb\n", encoding="utf-8")
            self.assertEqual(sync.load_processed_docids(state), {"a", "b"})

            sync.append_processed_docid(state, "c")
            self.assertEqual(sync.load_processed_docids(state), {"a", "b", "c"})
            lines = state.read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.strip()], ["a", "b", "c"])

    def test_prune_run_artifacts_removes_old_leaf_dirs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runs_root = Path(tmp) / "runs"
            old_run = runs_root / "20200101" / "old"
            new_run = runs_root / "20200102" / "new"
            old_run.mkdir(parents=True, exist_ok=True)
            new_run.mkdir(parents=True, exist_ok=True)
            (old_run / "file.txt").write_text("x", encoding="utf-8")
            (new_run / "file.txt").write_text("y", encoding="utf-8")

            old_mtime = (datetime.now(timezone.utc) - timedelta(days=30)).timestamp()
            os.utime(old_run, (old_mtime, old_mtime))

            removed = sync.prune_run_artifacts(runs_root, prune_days=14)
            self.assertGreaterEqual(removed, 1)
            self.assertFalse(old_run.exists())
            self.assertTrue(new_run.exists())


if __name__ == "__main__":
    unittest.main()

