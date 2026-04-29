## Execute the Prompt Plan

Inputs:
- Plan: `@prompt_plan.md`
- TODO tracker: `@TODO.md`
- Step prompts: files under `@llm/` (e.g., `@llm/prompt-1.md`)
- Project log: `@project_log.md`
- Spec (if present): `@spec.md`

Preflight & Gating:
1) Verify required files exist. If plan or step prompts are missing, reply "I don't know" and specify what you need.
2) Check `@prompt_plan.md` for any open gating questions. If unresolved, pause and ask the smallest set of blocking questions before proceeding.
3) Read `@TODO.md`. Identify the next unchecked step and its exact prompt file path (e.g., `@llm/prompt-X.md`). If TODO is unclear, use ordering in `@prompt_plan.md`.

Operating Loop (per step):
1) Open the step prompt `@llm/prompt-X.md`. Follow it exactly. Do not inline prompt contents in other files.
2) Tests-first:
   - Create/modify tests as specified.
   - Run the project's standard test command(s) from the prompt.
   - Confirm tests fail for the right reasons.
3) Implement minimally to satisfy tests and acceptance criteria in the prompt:
   - Write just enough code to pass tests.
   - Run lint/format.
   - Run tests again until green.
   - Run any build/e2e/verification commands listed in the prompt.
   - Confirm "real vs mock" requirements: use real implementations where specified.
4) Commit & branch:
   - Create a short-lived branch: `step-X-<short-name>`.
   - Commit with message:
     ```
     feat(step X): <short description> [prompt: llm/prompt-X.md]
     - Summary of changes
     - Deviations: <yes/no + brief note>
     - Risks/Follow-ups: <optional>
     ```
   - Push branch. Optionally open a PR and include the link below.
5) Update artifacts (no inlining of prompt contents):
   - `@project_log.md`: Append an entry:
     ```
     ## [YYYY-MM-DD HH:MM] Step X – <step name>
     - Prompt(s) run: `llm/prompt-X.md`
     - Commit/PR: <hash or link>
     - Result: <pass/fail/partial>; tests: <summary>
     - Decisions: <what/why/alternatives>
     - Deviations from plan: <what changed>
     - Issues/risks: <new or ongoing>
     - Next step: `llm/prompt-Y.md`
     ```
   - `@TODO.md`: Mark the item done; add/adjust the next items with exact `llm/prompt-Y.md` path.
   - `@prompt_plan.md`: Under the relevant step, add a one-line completion annotation with date and deviation flag. Only revise plan content if the plan itself changed; log such changes in `@project_log.md`.
   - `@spec.md` (if present): If requirements changed or clarified, update spec and reference the change in `@project_log.md`.
6) Pause for review unless explicitly authorized to continue automatically.

Quality & Completion Checks (per step):
- All tests pass (unit/integration/e2e as specified by the step).
- Lint/format clean.
- End-to-end outcome verified where required (not just code compiles).
- Real implementations used where the step requires them (no mocks where "real" is specified).
- Pre-Completion Review answered “yes” for the step:
  1. Does this step deliver the exact stated outcome?
  2. Are specified technologies/models implemented exactly as documented?
  3. Can a user achieve the promised value end-to-end?
  4. No mocks remain where real ones were required?
  5. Validated with actual end-to-end testing when required?

When Blocked:
- If missing credentials, environment, or unclear requirements: pause and ask targeted, minimal questions.
- If the step appears already complete: verify by running tests/build. If satisfied, skip implementation, mark done with a note and link to confirming commit/PR.

Final Wire-Up:
- After the last planned step, execute the final “Wire-Up & End-to-End” prompt (`@llm/prompt-<N>.md`) to ensure no orphaned code remains and the full workflow passes end-to-end. Run the same updates and quality checks above.

Notes:
- Never inline prompt contents in `@prompt_plan.md` or `@TODO.md`; always reference exact `@llm/prompt-X.md` paths.
- Keep changes minimal and reversible; prefer small, passing increments.
- If deviations from plan are needed, call them out in both the commit message and `@project_log.md`, and add a brief completion annotation in `@prompt_plan.md`.
