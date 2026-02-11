---
name: gog-gemini-meeting-import
description: 'Import Gemini meeting Google Doc URLs using `gog` to export the doc, extract the Transcript section, write a transcript Markdown file, and generate structured meeting notes (summary/decisions/action items) using the bundled meeting-notes prompt. Use when given a "Notes by Gemini" Google Doc link and asked to save the transcript and produce meeting notes.'
---

# Gemini Meeting Import (gog)

Use this skill to turn a Gemini meeting Google Doc into two files in your notes repo:

- `YYYY-MM-DD-meeting-transcript-<participants>.md` (raw transcript section)
- `YYYY-MM-DD-meeting-notes-<participants>.md` (structured notes generated from the transcript)

## Preconditions

- `gog` is installed and authenticated for Google Docs access.

## Workflow

### 1) Export + extract transcript

Run the helper script (defaults output dir to `/Users/prateek/code/github.com/prateek/personal-notes/20-openai`):

```bash
python3 scripts/import_gemini_meeting.py "<google_doc_url_or_doc_id>"
```

If you want a different destination:

```bash
python3 scripts/import_gemini_meeting.py "<url>" --out-dir "/path/to/notes/dir"
```

The script writes the transcript file and prints the transcript path plus the suggested notes path.

### 2) Generate meeting notes from the transcript

1. Read `references/meeting-notes.md` (the prompt).
2. Read the transcript file created by the script.
3. Produce meeting notes that follow the prompt exactly.
4. Write the notes to the suggested notes path printed by the script.

## Notes

- Transcript extraction starts at the transcript marker (prefers a `📖 Transcript` line; falls back to a `Transcript` line that looks like it’s followed by timecodes).
- Filenames are inferred from the transcript header when possible; otherwise the script falls back to the doc title metadata.
