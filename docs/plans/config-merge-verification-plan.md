---
status: archived
doc_type: plan
owner: Prateek
created: 2026-09-05
updated: 2026-09-05
closed: 2026-09-05
current_guidance:
  - ../../tests/README.md
  - ../references/chezmoi-architecture.md
related:
  - ../adr/0006-chezmoi-migration-prototype.md
  - ../adr/0021-shared-plist-verification.md
  - ../references/chezmoi-architecture.md
  - test-suite-rebuild-plan.md
status_detail: "Initial implementation record. Subsequent adversarial-review fixes strengthen native type verification and merge equality; see current guidance. Broader test-suite rebuild remains proposed."
---

# Shared Config-Merge Verification Plan

## Scope

Concentrate plist test rendering, serialization, subprocess execution and diagnostics in a shared test module. App scenarios retain independent expected values and ownership assertions. Require every shipped plist modifier to have a scenario or a justified exception, including Tuna.

The shared test-module decision is recorded in [ADR 0021](../adr/0021-shared-plist-verification.md).

Preserve the native preference fragments, tiny modifier adapters and shared production engine described by [ADR 0006](../adr/0006-chezmoi-migration-prototype.md). JSON/TOML merge policies, suite-wide test selection, general fixture isolation and console observation adapters are outside this task. The [test-suite rebuild](test-suite-rebuild-plan.md) remains a separate proposal.

## Approved public seams

- `scripts/macos/plist-merge --bundle-id <id> --desired-b64 <XML>`: current plist bytes on stdin, merged plist bytes on stdout, diagnostics on stderr and exit status.
- The actual `home/Library/private_Preferences/modify_private_*.plist.tmpl` adapters rendered by `chezmoi execute-template`: current plist bytes on stdin and merged plist bytes on stdout.

Tests execute these interfaces as subprocesses without importing or mocking the engine. Desired top-level values replace whole values, including dictionaries; unrelated top-level keys survive. Semantically unchanged input retains its original bytes. Independent app assertions protect intended values and local ownership, including VoiceInk's `KeyboardShortcuts_toggleEnhancement` lifecycle.

## Implementation sequence

1. Reproduce the hyphenated deletion defect through the engine CLI, observe red, and make the smallest passing fix.
2. Extend engine contract coverage one behavior at a time, based on the current executable's serialization and error behavior.
3. During review, consolidate existing plist suites into shared verification and app scenarios; preserve their useful assertions and add Tuna coverage.
4. Add discovery enforcement and wire the focused suite into Make and existing CI.
5. Correct affected documentation, validate locally and record red/green evidence here before closing this plan.

## Validation and completion

Run the consolidated plist suite and retained focused entrypoints, package gating, plist hooks, nvALT color archive checks, docs lifecycle and `git diff --check`. Use `DOTFILES_SKIP_LAUNCHCTL_SYNC=1` for synthetic shell harnesses. Record failures without suppressing them.

Completion leaves a reviewable worktree diff. No commit, push, merge, live apply, app preference mutation, remote CI or Tart validation is part of this task.

## Implementation evidence, 2026-09-05

Started from clean `prateek/config-merge-verification` at `dd8b29f`.

The first command was `DOTFILES_SKIP_LAUNCHCTL_SYNC=1 uv run --quiet --python '>=3.14' python -B tests/config_merge/test_plist_merge.py -v`. Before the production change, the sole regression failed: the CLI exited 0, but decoded stdout was `{'obsolete-key': True, 'unrelated': 'keep'}` instead of `{'unrelated': 'keep'}`. Replacing the directive's hyphen-excluding match with a multiline match ending at the XML comment terminator made that same test pass. This is the only production code change.

Further engine cases were added and run one behavior at a time. They characterize mixed/multiline deletion directives, whole top-level replacement, XML/binary input, unchanged bytes, missing/non-dictionary current input, and invalid-input failures without replacement output.

All seven original plist suites passed before consolidation. Their input fixtures and useful assertions now live in the shared scenarios, with direct Tuna coverage added. Empty-input ownership assertions caught two migration mistakes: cmux's `appearanceMode` and VoiceInk's `KeyboardShortcuts_toggleMiniRecorder2` belong in managed expectations. Tuna's path check also exposed that a temporary chezmoi destination alone does not change `.chezmoi.homeDir`; rendering now receives a temporary `HOME`. These were corrected in test data and support.

The discovery check was challenged with a temporary `modify_private_test.discovery-probe.plist.tmpl` under the real source tree. It exited 1 and named the missing scenario. Removing the probe restored green. All 12 shipped modifiers have scenarios; no exceptions are needed.

| Local validation | Result |
| --- | --- |
| `DOTFILES_SKIP_LAUNCHCTL_SYNC=1 make test-config-merge` | Passed: six engine tests, discovery, and all 12 app scenarios; eight unittest methods including the app table. |
| `DOTFILES_SKIP_LAUNCHCTL_SYNC=1 make test-moom-plist test-thaw-plist test-cmux-plist test-selected-app-plists test-voiceink-plist test-orbstack-plist test-nvalt-plist test-tuna-plist` | All focused entrypoints passed. |
| `DOTFILES_SKIP_LAUNCHCTL_SYNC=1 make test-package-gated-configs test-plist-hooks test-nvalt-colors` | All passed. |
| `DOTFILES_SKIP_LAUNCHCTL_SYNC=1 make test-docs-lifecycle` | Fixture tests and current-tree validation passed, 69 docs against HEAD. |
| `.agents/skills/chezmoi-management/evals/validate.py` | All skill checks passed. |
| `uvx ruff check tests/config_merge` and `uvx ruff format --check tests/config_merge` | Passed. |
| `git diff --check` | Passed. |

Current extension guidance is in the [tests index](../../tests/README.md#plist-merge-verification) and [architecture reference](../references/chezmoi-architecture.md). The scoped implementation is complete locally and left uncommitted for review. CI selection was updated, but remote CI, the full repository suite, Tart and native app adoption were not tested. No live apply or preference mutation occurred.
