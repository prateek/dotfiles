Rewrite the entire assigned skill folder using the guidance. Inventory all files
tracked under the assigned root at `baselineCommit`; inspect each one's purpose
before deciding what to rewrite, restructure, or retain. Follow context pointers
that are necessary to preserve behavior. Prefer clear execution steps and
checkable, exhaustive completion criteria. Keep a meaning in one authoritative
place and expose branch-specific material through precise pointers.

Complete when every original file has been accounted for, the resulting folder
is internally consistent, and applicable local checks pass. The controller will
capture your complete working-tree changes as `draft.patch`, including added,
deleted, binary, and executable-mode changes.

Report schema:
```json
{"coveredFiles": ["repo-relative/path/to/every/original/file"], "changes": ["what changed and why"], "checks": ["command and observed result"], "unresolved": []}
```
