---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-05
related:
  - ../plans/config-merge-verification-plan.md
  - ../references/chezmoi-architecture.md
  - 0006-chezmoi-migration-prototype.md
---

# ADR 0021 - Shared Plist Verification

## Context

Per-app plist suites repeat rendering and subprocess setup while checking different subsets of the shared merge contract. Tuna had package-gating coverage without a merge scenario. The engine also silently ignored deletion directives containing hyphenated keys.

## Decision

Use a shared Python test module under `tests/config_merge/` to execute the real merge CLI and chezmoi-rendered modifier adapters. Scenarios describe managed input overrides, app-owned local state and independently expected values. Optional assertions decode app-specific payloads. Common checks cover empty input, XML/binary input, local preservation and unchanged bytes.

Discover shipped plist modifiers and require each to have a scenario or an explicit exception with a reason. Keep existing focused Make targets as entrypoints; `make test-config-merge` runs the engine contracts, discovery and every app scenario in CI.

The production design from [ADR 0006](0006-chezmoi-migration-prototype.md) stays intact: native preference fragments and tiny adapters delegate to `scripts/macos/plist-merge`. Its selected top-level values replace whole values, including nested dictionaries. JSON and TOML retain their own policies.

## Alternatives and consequences

Keeping separate test scripts leaves each app responsible for setup and common guarantees. Testing imported engine helpers would miss rendering and adapter failures. Deriving every assertion from desired fragments would allow accidental ownership changes to pass.

The shared checks remove that repeated setup while retaining independent app assertions, including VoiceInk's recorder shortcut ownership. New apps usually need one scenario. Tests still require real chezmoi, uv and macOS `plutil`; they do not establish that a running app adopted its preferences.

Implementation evidence is in the [scoped plan](../plans/config-merge-verification-plan.md). Current commands and extension guidance live in the [tests index](../../tests/README.md) and [architecture reference](../references/chezmoi-architecture.md).
