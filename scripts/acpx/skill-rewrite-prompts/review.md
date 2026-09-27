Review the rewrite independently. Read `artifacts/draft.patch`, the complete
changed files, and their original versions at `baselineCommit`. Inspect every
original file, including files the author retained. Review for lost requirements,
incorrect commands, broken pointers, changed behavior, weak completion criteria,
frontmatter/interface mismatches, test coverage loss, and misuse of the writing
guidance. Confirm the whole folder works together.

Leave the checkout unchanged. Write findings only to `report`; each finding
needs a stable ID, severity, file, evidence, consequence, and concrete correction.
An empty findings list is valid after completing the review. Findings describe
the author's defects; `unresolved` describes any limitation preventing you from
completing the review, such as an unreadable file.

Report schema:
```json
{"coveredFiles": ["repo-relative/path/to/every/original/file"], "findings": [{"id": "R1", "severity": "high", "file": "path", "evidence": "specific defect", "consequence": "impact", "correction": "required fix"}], "unresolved": []}
```
