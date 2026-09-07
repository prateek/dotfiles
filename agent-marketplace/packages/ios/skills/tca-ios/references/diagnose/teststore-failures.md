# Applies to: TCA 1.25+, iOS 16+

# TestStore Failures

## Use When

Use this when TestStore reports unexpected state, unhandled received actions, unfinished effects, or missing receives.

## Diagnosis

- Read the exact failure text before changing code.
- Identify whether the failure is state mismatch, unexpected action, missing action, or running effect.
- Check dependency overrides before changing reducer logic.
- Check whether the test is exhaustive or non-exhaustive.
- If state differs, compare expected and actual as domain facts, not line noise.

## Common Causes

- Effect response was not asserted with `receive`.
- A dependency returned a different fixture than the test expected.
- A clock was not advanced.
- A long-lived effect was not cancelled.
- Assertion closure recomputed reducer logic incorrectly.

## Fix

Fix the reducer when behavior is wrong. Fix the test when the test expected the wrong contract. Do not paper over unknown effects with non-exhaustive mode.
