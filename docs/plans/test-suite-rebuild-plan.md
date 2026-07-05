---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-07-04
related:
  - ../references/chezmoi-architecture.md
  - chezmoi-migration-plan.md
status_detail: "Proposal to rebuild the test suite from scratch: modular by subsystem, polyglot by fit, on two primitives — assertions derived from source-of-truth, and discovery-based self-enforcing coverage. Not started."
---

# Test-Suite Rebuild Plan

## Context

An audit of the `tests/*.zsh` suite (dispatched one-per-target from a single root
`Makefile`) found it had drifted into testing implementation snapshots rather than
behavior, in three recurring shapes: config-value snapshots (`zed-settings`, the
per-app plist tests), exact call/line transcripts (`mise-install-script`, the
tartelet greps), and count/roster snapshots (`vm-postflight` `passed=22`, `karabiner`
`33 manipulators`). These break on every honest config edit while catching nothing a
behavior test wouldn't.

Two structural problems compound it. `make` defines 60 `test-*` targets but CI runs
32; excluding the VM/external-CLI lanes, ~17 plain zsh tests never run — including
strong ones (`secret-backed-files`, `sudo-keepalive`) — so coverage rots silently.
The central Makefile is the registry, the runner, and the CI entrypoint all at once,
and its hand-maintained target list is exactly what tests fall out of (the `.PHONY`
list is already stale). This exact fix was also done once — branch
`update-tests-phil` (2026-06-23) consolidated the brittle clones, added a `test-fast`
aggregate, and wrote the `testing-philosophy` skill — but only the skill reached
`master`; the suite fixes stranded. Nothing routes an agent to the good pattern, and
the invariant keeps getting re-violated: the just-landed Tuna launcher migration added
`com.brnbw.Tuna` with a plist stub and no test.

Patching file-by-file failed because the incentives were never changed. This plan
rebuilds the suite so the *correct* test is the *cheap* test, coverage polices
itself, and the suite is modular by subsystem and polyglot by fit rather than one
Makefile forcing every test into zsh.

## Principles

Three primitives carry the design:

1. **Assert behavior derived from the rendered source-of-truth, never config-value
   snapshots.** A merge/render test loads the rendered fragment and asserts the
   *transform* — managed keys land, unmanaged/local keys survive, empty input seeds
   only the managed set, re-merge is byte-stable — without naming a value. These
   prove the engine lands the config it is given, not that the values are *correct*.
   The config is its own spec; there is no unit oracle for "is this value right," so
   we do not fake one with a literal. Correctness is validated at apply time and by
   the app (Tiers 3–4).
2. **Coverage is self-enforcing through discovery, not a list.** A runner discovers
   tests by convention and cross-checks them against a per-subsystem manifest; a test
   file with no manifest entry fails the build, and an entry with no file fails too.
   There is no central target list to silently fall out of.
3. **Modular by subsystem, polyglot by fit.** Tests are grouped with the subsystem
   they cover and its fixtures, and each test is written in the language that suits
   its subject — zsh for shell behavior, Python for plist/JSON/TOML structure, node
   for the JS extension. Nothing is forced into zsh by the runner.

## The orthogonal model

A test has three independent axes. Keeping them separate is what makes the suite
modular instead of one flat list:

- **Domain — where the file lives.** Grouped by subsystem, fixtures and helpers
  alongside. Adding a domain touches only that domain.
- **Tier — when it runs.** Static → engine/property → data-table → apply-integration
  → VM. Declared as metadata, filtered by the runner; not a directory.
- **Language — how it is written.** Chosen by fit. The universal contract is the exit
  code (0 pass, non-zero fail); stdout/stderr are captured for reporting. Any
  executable that honors that contract is a valid test.

So a test is a `(domain, tier, language)` triple: layout by domain, run-selection by
tier/CI-safety, implementation by fit.

## Layout and runner

**Discovery-based runner replaces the Makefile registry.** A small `tests/run`
(≈100 lines, itself in whatever language is cleanest) discovers test files by
convention across `tests/**` and `scripts/**` (and the raycast `node --test` lane),
reads a per-domain `manifest.toml`, filters by `--tier` / `--ci-safe` / `--domain`,
invokes each test through its declared runner, and aggregates results. `tests/run
--ci-safe` is the single CI entrypoint. A thin `make test` / `just test` may delegate
to it for muscle memory, but the runner — not a task file — is the source of truth.

**Per-domain manifest is the decentralized wiring guard.** Each
`tests/<domain>/manifest.toml` declares defaults (`runner`, `tier`, `ci_safe`) and
lists its tests with per-file overrides and, for anything intentionally excluded from
CI, a required `reason`. The runner fails if a discovered test has no manifest entry
or a manifest entry has no file. That cross-check is the wiring guard, and it lives
next to the tests instead of in a central list.

**Co-locate where it is safe; centralize where chezmoi forces it.** `scripts/` is not
chezmoi-managed, so a script's unit test co-locates beside it
(`scripts/trace/perfetto-trace.bash` → `scripts/trace/tests/`). `home/` *is* chezmoi
source state with no test-ignore pattern, so a test file placed there would be
applied into `$HOME`; anything testing `home/` templates, data, merges, or apply
therefore lives under `tests/<domain>/`. The runner scans both roots, so co-location
and central grouping coexist under one discovery pass.

Representative domains: `config-merge/` (plist + `modify_` engines), `chezmoi/`
(apply idempotence, gating, resolver), `packages/` (brewfile, brew, forks),
`install-scripts/` (mise, xcode, gh, macos-defaults, sudo), `programs/` (fresh-shell,
trace, repo-index, ghc, karabiner), `vm/` (tart, postflight, tartelet),
`agent-surface/` (claude/codex/crit config, skill packages, secrets). The exact
taxonomy is a Phase-1 decision.

## The shared harness (`tests/lib/`)

The reason brittle tests bred is that copy-pasting a snapshot was the easiest move.
Invert that with shared helpers so the cheapest test is the correct one — polyglot,
since the assertions live in different languages:

- **Python package** (the natural home for the config-merge assertions many current
  tests already reach for via `uv run python`): `assert_merge_invariants(fragment,
  current, local)` derives expectations from the rendered fragment (managed-lands /
  local-preserved / empty-seeds / idempotent); plist/JSON/TOML load helpers.
- **Shell lib**: `render` (`chezmoi execute-template` with isolated config + pinned
  `machine_type`), `assert_gated`, `assert_fails_loud`, `assert_secret_never_leaks`,
  and one PATH-stub harness for `brew`/`mise`/`defaults` instead of each test rolling
  its own.

Same contract across languages; a test picks the lib in its own language.

## Tiers

- **Tier 0 — Static/parse (instant, every push).** `shellcheck`, `plutil -lint` every
  plist fragment, `chezmoi execute-template` compiles every template, TOML/JSON parse
  of `.chezmoidata`, doc-lifecycle. Exhaustive, not a hand-picked subset.
- **Tier 1 — Engine/property (fast, hermetic).** Generic, app-independent logic: one
  property test for `scripts/macos/plist-merge` (deep-merge, managed-overrides,
  local-preserved, empty-seeds, delete directives incl. hyphenated keys,
  array/non-dict root, byte-stable idempotence); one merge-contract test per `modify_`
  engine; behavior/edge tests for the real programs.
- **Tier 2 — Data-driven tables (fast).** Per-item coverage as data rows: a
  plist-merge table (every app fragment × the invariants) and a machine-type matrix
  (each type → group membership, derived from `machines.toml`). The coverage guard
  requires every shipped item to have a row.
- **Tier 3 — Apply integration (fast enough for CI).** `chezmoi apply` into a temp
  `$HOME` per machine type, then assert clean `chezmoi status` (idempotent, no drift).
- **Tier 4 — Real machine / VM (nightly/manual).** Tart apply + peekaboo app-audit —
  the only place "did the setting reach the app" is checked.

## Enforcement and routing

- `tests/run --ci-safe` (Tiers 0–3) is the single CI invocation; `tests/run --all`
  adds Tier 4.
- **Wiring guard**: the manifest↔file cross-check above; a new test cannot be
  silently unrun, and CI exclusions carry a stated reason.
- **Coverage guard** (a test itself, language-agnostic): every
  `modify_private_*.plist.tmpl`, every machine type in `machines.toml`, and every
  secret-backed file maps to a test row or a justified allowlist entry — the check
  that would have caught Tuna.
- **Routing**: `CLAUDE.md`/`AGENTS.md` and the
  [architecture reference](../references/chezmoi-architecture.md) point at the
  `testing-philosophy` skill and this plan, with a worked "add a test" example. The
  migration plan's "assert the merged plist round-trips to the expected dict" line and
  the reference's assertion-less "add the focused plist test" are corrected.

## Non-goals

Deliberately not unit-tested: config *values* (no oracle), presentation/glyphs, exact
call transcripts, magic counts. Those are Tier 3–4 questions. Literals that *are* the
behavior stay literal: input→output parser mappings (`ghc-url`, `vm-install-log-scan`),
routing/contract strings (the `op://` ref, the Jamf deep-link), security invariants,
and ordering that reflects a real dependency.

## Migration

Staged so coverage never dips below what exists:

1. **Spine first.** Build `tests/run`, the manifest convention, and `tests/lib/`
   (python + shell); point CI at `tests/run --ci-safe`. Retire the Makefile as
   registry (keep at most a thin delegating shim). With few ported tests, most live in
   a large, reasoned exclusion set.
2. **Port domain-by-domain.** Write the generic engine/property test, move per-item
   cases into the table, pick the fitting language (config-merge and trace move to
   Python; shell-behavior stays zsh), and delete the old brittle file *in the same
   commit* so net coverage only rises. Preserve the real invariants the current suite
   tangles with snapshots: Moom idempotence, VoiceInk's app-owned `toggleEnhancement`
   guard, nvALT color-archive format, `vm-postflight` drift detection,
   `claude-statusline`'s `--logical` seam, `mise` dependency ordering.
3. **Tighten guards.** Shrink the exclusion/allowlist per port so the guard ratchets.
4. **Cut over.** Remove the old curated CI list; land the routing/doc fixes.

## Disposition of the current suite

Roughly 48 files collapse to ~15–20, redistributed by domain and language:

| Disposition | Members |
| --- | --- |
| Survive ~intact (already behavioral) | `sudo-keepalive`, `plist-hooks`, `chezmoi-script-status`, `chezmoi-local-ignores`, `secret-backed-files`, `kanata-config`, `elevation-render`, `gh-extensions-script`, `chezmoi-config`, `repo-index`, `brew-inventory`, `vm-install-log-scan`, `ghc-url`, `crit-config`, `fork-reconcile`, `xcode-install-script` |
| Fold into engine test + table (→ Python) | `selected-app` (becomes the table), `cmux`, `ice`, `nvalt`, `orbstack`, `moom` |
| Strip snapshot, keep the invariant | `voiceink`, `nvalt-colors`, `vm-postflight`, `karabiner`, `claude-statusline`, `mise-install-script`, `orca-settings`, `codex-config`, `agentsview-config`, `claude-settings`, `tartelet-settings`, `tartelet-softnet-wrapper`, `macos-defaults`, `brew-install-wrapper`, `render-brewfile`, `trace-perfetto`, `machines-features`, `package-gated-configs`, `brew-bundle-script` |
| Delete (pure snapshot, no unique coverage) | `zed-settings` |

## Open questions

- **Runner implementation.** A small zsh or Python script vs a `just` recipe set vs a
  thin wrapper over `pytest`/`bats` discovery. Lean: a ~100-line script owning
  discovery + manifest cross-check, delegating each test to its declared runner.
- **Manifest format.** Per-domain `manifest.toml` (recommended: explicit, supports
  exclusion reasons) vs pure filename/dir convention (less to maintain, no place for a
  reason). Recommend the manifest for the wiring-guard property.
- **Task-runner shim.** Keep a thin `make test` for muscle memory, switch to `just`,
  or drop it and call `tests/run` directly.
- **Verify the alleged engine bug.** GPT's review claimed `scripts/macos/plist-merge`
  uses `([^-]+?)` for the `chezmoi-delete` directive, truncating hyphenated keys. The
  Tier 1 delete test should confirm and fix it.

## Validation

- `tests/run --ci-safe` is green and is the only CI test invocation.
- The wiring guard fails on a deliberately-unmanifested test; the coverage guard fails
  on a deliberately-untested plist stub (the guards actually bite).
- A representative config edit (add a Moom control, add a machine-type group) leaves
  the suite green — the derive-from-source primitive holds.
- No test asserts a config value that also lives verbatim in a source template, and no
  test is forced into zsh where another language fits its subject better.
