# /ios-ux-scorecard $TASKS="comma,separated,goals"
**Goal**: Run a focused UX pass per task with evidence + HIG citations.

## Steps
- If not already running, ensure build & launch via XcodeBuildMCP.
- For each task in $TASKS: walk the happy path, then one edge case.
- After each step: screenshot to `/evidence/scorecard/TASK-N/step-XX.png`.
- Fill the Scorecard:
  Task success (0–3) | Steps | Frictions | Affordance clarity (0–3) | A11y (pass/fail) | HIG refs (title+URL).
- Append results to `Findings.md` under “UX Scorecards”.
