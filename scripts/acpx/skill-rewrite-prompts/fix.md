Read `artifacts/draft.patch`, `artifacts/rewrite.report.json`, and
`artifacts/review.report.json`. Resolve every review finding in the assigned
folder. Recheck the entire resulting folder against the writing guidance and
original behavior, including new files and references introduced by the rewrite.
For any finding you reject, give specific evidence. Run applicable local checks.

Complete when every review ID has a resolution, every original file is accounted
for, and the final folder is consistent. The controller generates `final.patch`
relative to `baselineCommit`; it includes the initial rewrite and these fixes.

Report schema:
```json
{"coveredFiles": ["repo-relative/path/to/every/original/file"], "resolutions": [{"id": "R1", "outcome": "fixed or rejected", "evidence": "change or reason"}], "checks": ["command and observed result"], "unresolved": []}
```
