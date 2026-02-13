# Browser CDP Conventions (Skill-like)

## Purpose

Use this playbook for browser automation and CDP-controlled workflows.

## When to use

- Any task that launches or controls Chrome via CDP.
- Any workflow that depends on existing authenticated browser credentials/cookies.

## Defaults

- Prefer the profile path from `CDP_PROFILE_PATH`.
- Treat `CDP_PROFILE_PATH` as the source of truth for which credentials/profile to use.
- Do not silently switch to another profile when `CDP_PROFILE_PATH` is unavailable.

## Workflow

1. Resolve profile path:
   - Read `CDP_PROFILE_PATH`.
2. Validate path:
   - If the env var is missing, empty, or points to a non-existent directory, prompt the user for which profile path to use.
3. Start/operate browser tooling with that resolved profile path.

## Validation checklist

- `CDP_PROFILE_PATH` is set and non-empty.
- Resolved path exists and is a directory.
- Chosen profile path was explicit (from env var or user prompt).
