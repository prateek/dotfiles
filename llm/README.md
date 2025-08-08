## LLM Prompt Files

- Storage: Each step uses  (1, 2, 3, ...). Numbering continues across slices.
- Source of truth: Do not inline prompts in  or ; link to these files.
- Final wire-up: The last prompt is the E2E wire-up prompt ().

References:
- In : e.g., see .
- In : e.g., [ ] Run  (token refresh).

Each prompt file should include context, tests-first, files to change, acceptance criteria, run commands, and integration notes.
