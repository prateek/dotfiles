# Applies to: TCA 1.25+, iOS 16+

# Review Synthesis

## Use When

Use this to merge survey and focused review outputs into the final review.

## Structure

```markdown
# TCA Architecture Review

## Findings by Severity

## Repository Map

## Feature-by-Feature Review

## Cross-Cutting Concerns

## Testing Plan

## Refactor Plan

## Summary
- Overall grade: Excellent / Good / Mixed / Risky / Poor
- Main strengths
- Main risks
- Top 3 improvements
```

## Synthesis Rules

- Deduplicate overlapping findings and keep the strongest evidence.
- Resolve conflicts directly.
- Separate correctness risks from style preferences.
- Keep optional modernization separate from required bug fixes.
- Preserve product behavior unless recommending a deliberate behavior change.

## Competing Concerns

Balance explicitness against boilerplate, centralized state against local UI state, composition against fragmentation, effect control against pragmatism, modernization against stability, and test precision against brittleness.
