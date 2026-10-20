# Applies to: TCA 1.25+, iOS 16+

# Review Coordinator

## Use When

Use this in review mode for an iOS TCA architecture review.

## Posture

Review mode is read-only. Do not edit files. Produce findings grounded in repository evidence. Prefer incremental fixes over purity rewrites.

## Workflow

1. Load `survey.md`, `finding-format.md`, and `synthesis.md`.
2. Run the repository survey before making findings.
3. Select the focused review passes that match the codebase.
4. If delegation is available and allowed by the active runtime, run focused passes in parallel. Otherwise run them serially.
5. Merge findings, deduplicate overlaps, and resolve disagreements explicitly.
6. Lead with findings ordered by severity.

## Required Inputs

- TCA version and API generation.
- Module/target map.
- Major feature reducers and views.
- Effect-heavy, navigation-heavy, root, and test files.

## Output

Use `synthesis.md` for the final structure and `finding-format.md` for each finding.

## Guardrails

- Do not invent files, symbols, or failure modes.
- Do not recommend modernization only because the code is old.
- Do not hide uncertainty. Mark confidence honestly.
